import SwiftUI
import UIKit

// MARK: - 调度单（上方下发 → 拍照 → 上传 → 完成）
//
// 接口链路（实测）：
//   getlist.do             拉本单位的调度单（服务端不认 targetuser 过滤，需客户端筛）
//   showView.do            拉详情：contents + businessUnitRecords（含 files 附件）
//   base/updateFile.do     multipart 上传照片
//                            masterId  = 当前待办步骤的 taskid
//                            tbName    = tb_common_file
//                            nameSpace = taskmaterial
//                            filelist  = 图片
//   processAdjustment/doAuditDetail.do   JSON 提交
//                            taskid / taskdefinitionkey / processid /
//                            businessid / passstatus=true / auditopinion

struct DispatchOrder: Identifiable {
    let id: String
    let businessId: String
    let taskId: String
    let contents: String
    let statusText: String
    let company: String
    let insdt: String

    init?(_ row: [String: Any]) {
        let task = Net.dict(row["task"])
        let business = Net.dict(row["businessEntity"])
        let company = Net.dict(business["targetCompany"])
        let businessId = Net.str(row, "businessId")
        let entityId = Net.str(business, "id")
        self.businessId = businessId.isEmpty ? entityId : businessId
        guard !self.businessId.isEmpty else { return nil }
        taskId = Net.str(task, "id")
        id = taskId.isEmpty ? self.businessId : taskId
        contents = Net.str(business, "contents")
        let taskName = Net.str(task, "name")
        statusText = taskName.isEmpty ? Net.str(row, "name") : taskName
        let companyName = Net.str(company, "name")
        self.company = companyName.isEmpty ? Net.str(company, "sname") : companyName
        insdt = Net.str(task, "createTime")
    }
}

struct FlowFileItem: Identifiable {
    let id: String
    let filename: String
    let filepath: String
}

struct FlowStep: Identifiable {
    let id: String
    let taskName: String
    let record: String
    let userName: String
    let time: String
    let processid: String
    let taskid: String
    let taskdefinitionkey: String
    let type: String
    var files: [FlowFileItem] = []

    var isActionable: Bool {
        !taskid.isEmpty && taskid != "null" && taskid != "<null>"
    }
}

@MainActor
final class DispatchStore: ObservableObject {
    @Published var orders: [DispatchOrder] = []
    @Published var loading = false
    @Published var listError: String?

    @Published var contents = ""
    @Published var status = ""
    @Published var detailRows: [(String, String)] = []
    @Published var steps: [FlowStep] = []
    @Published var detailError: String?
    @Published var uploading = false
    @Published var submitting = false

    // MARK: 列表
    /// 照 j5/a.smali：调度单页签走 processAdjustment/getTaskList.do
    /// 参数 page / rows / sort / order / taskIds
    func loadList() async {
        loading = true
        listError = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processAdjustment/getTaskList.do",
                ["page": "1", "rows": "50", "sort": "insdt",
                 "order": "desc", "taskIds": ""])

            let result = Net.dict(Net.dict(raw)["result"])
            guard let records = result["rows"] ?? Net.dict(raw)["rows"], !(records is NSNull) else {
                throw APIError.message(Net.message(raw))
            }
            orders = Net.array(records).compactMap(DispatchOrder.init)
        } catch {
            listError = error.localizedDescription
        }
        loading = false
    }

    // MARK: 详情
    func loadDetail(_ id: String) async {
        loading = true
        detailError = nil
        do {
            let raw = try await Net.shared.get(
                "SIPAIIS_DataCenter/work/processAdjustment/showView.do", ["id": id])
            let res = Net.dict(Net.dict(raw)["result"])
            let be = Net.dict(res["businessEntity"])
            guard !be.isEmpty else { throw APIError.message(Net.message(raw)) }
            contents = Net.str(be, "contents")
            status = Net.str(be, "status")

            let comp = Net.dict(be["targetCompany"])
            let lvl: String = {
                switch Net.str(be, "adjustmentLevel") {
                case "1": return "一级"
                case "2": return "二级"
                case "3": return "三级"
                default:  return Net.str(be, "adjustmentLevel")
                }
            }()
            let s0 = Net.str(be, "stdt"), e0 = Net.str(be, "eddt")
            let d0: String = {
                let a = s0.count >= 10 ? String(s0.prefix(10)) : s0
                let b = e0.count >= 10 ? String(e0.prefix(10)) : e0
                if a.isEmpty && b.isEmpty { return "" }
                return a == b ? a : "\(a) 至 \(b)"
            }()
            detailRows = [
                ("调度厂区：", Net.str(comp, "name").isEmpty ? Net.str(comp, "sname") : Net.str(comp, "name")),
                ("调度类型：", Net.str(be, "typeName")),
                ("调度等级：", lvl),
                ("调度日期：", d0),
            ]

            var out: [FlowStep] = []
            for r in Net.array(res["businessUnitRecords"]) {
                let u = Net.dict(r["user"])
                var s = FlowStep(
                    id: Net.str(r, "id"),
                    taskName: Net.str(r, "taskName"),
                    record: Net.str(r, "record"),
                    userName: Net.str(u, "caption"),
                    time: Net.str(r, "insdt"),
                    processid: Net.str(r, "processid"),
                    taskid: Net.str(r, "taskid"),
                    taskdefinitionkey: Net.str(r, "taskdefinitionkey"),
                    type: Net.str(r, "type"))
                if let fs = r["files"] as? [[String: Any]] {
                    s.files = fs.map {
                        FlowFileItem(id: Net.str($0, "id"),
                                     filename: Net.str($0, "filename"),
                                     filepath: Net.str($0, "filepath"))
                    }
                }
                out.append(s)
            }
            steps = out
        } catch {
            detailError = error.localizedDescription
        }
        loading = false
    }

    /// 当前可操作的步骤（最后一条带 taskid 的）
    func currentStep(taskId: String?) -> FlowStep? {
        guard let taskId = taskId, !taskId.isEmpty else { return nil }
        return steps.last { $0.isActionable && $0.taskid == taskId }
    }

    // MARK: 上传
    func uploadPhotos(_ images: [UIImage], orderId: String, taskId: String?) async -> Bool {
        guard let step = currentStep(taskId: taskId) else {
            detailError = "没有待办步骤，无法上传"
            return false
        }
        uploading = true
        defer { uploading = false }

        var files: [Net.UploadFile] = []
        for (i, img) in images.enumerated() {
            guard let data = img.jpegData(compressionQuality: 0.72) else { continue }
            files.append(Net.UploadFile(
                field: "filelist",
                filename: "IMG_\(Int(Date().timeIntervalSince1970))_\(i).jpg",
                mime: "image/jpeg",
                data: data))
        }
        guard !files.isEmpty else { detailError = "没有图片"; return false }

        do {
            let raw = try await Net.shared.upload(
                "SIPAIIS_Base/base/updateFile.do",
                fields: [
                    "masterId": step.taskid,
                    "tbName": "tb_common_file",
                    "nameSpace": "taskmaterial",
                    "recordId": orderId,
                ],
                files: files)
            let ok = Net.isOK(raw)
            if !ok {
                detailError = "上传返回：\(Net.message(raw))"
            }
            return ok
        } catch {
            detailError = "上传失败：\(error.localizedDescription)"
            return false
        }
    }

    // MARK: 提交
    func submit(orderId: String, taskId: String?, opinion: String) async -> Bool {
        guard let step = currentStep(taskId: taskId) else {
            detailError = "没有待办步骤"
            return false
        }
        submitting = true
        defer { submitting = false }

        let body: [String: Any] = [
            "taskid": step.taskid,
            "taskdefinitionkey": step.taskdefinitionkey,
            "taskCopyUserIds": "",
            "targetusers": "",
            "processid": step.processid,
            "processDefId": "",
            "passstatus": true,
            "businessid": orderId,
            "fieldValue": "",
            "fieldName": "",
            "fieldList": "[]",
            "auditopinion": opinion,
        ]
        do {
            var req = URLRequest(url: URL(string: Net.shared.base
                + "/SIPAIIS_DataCenter/work/processAdjustment/doAuditDetail.do")!)
            req.httpMethod = "POST"
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            if !Net.shared.token.isEmpty {
                req.setValue(Net.shared.token, forHTTPHeaderField: "token")
            }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                detailError = "提交 HTTP 异常"
                return false
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let ok = Net.int(obj, "code") == 1
                if !ok { detailError = Net.str(obj, "msg") }
                return ok
            }
            detailError = String((String(data: data, encoding: .utf8) ?? "").prefix(160))
            return false
        } catch {
            detailError = "提交失败：\(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - 调度单列表

struct DispatchScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = DispatchStore()
    let keyword: String

    private var visibleOrders: [DispatchOrder] {
        let query = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.orders.filter { order in
            query.isEmpty || [order.statusText, order.contents, order.company].contains {
                $0.localizedCaseInsensitiveContains(query)
            }
        }
    }

    var body: some View {
        ScrollView {
            if store.loading && store.orders.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 50)
            } else if visibleOrders.isEmpty {
                EmptyHint(text: store.listError ?? "暂无工单")
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(visibleOrders) { order in
                        NavigationLink {
                            DispatchDetailScreen(orderId: order.businessId, previewContents: order.contents, taskId: order.taskId)
                        } label: {
                            card(order)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
        }
        .background(C.bg)
        .task(id: app.unit) { await store.loadList() }
        .refreshable { await store.loadList() }
    }

    private func card(_ order: DispatchOrder) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image("moudle_flow").resizable().scaledToFit().frame(width: 18, height: 18)
                Text(order.statusText).font(.system(size: 15))
            }
            Text(order.contents).font(.system(size: 16))
            HStack {
                Text(order.insdt).foregroundColor(C.grayText)
                Spacer()
                Text(order.company).foregroundColor(C.bar)
            }
            .font(.system(size: 14))
        }
        .foregroundColor(.black)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(C.bar, lineWidth: 0.5))
    }
}

struct DispatchDetailScreen: View {
    @State private var showAudit = false
    @EnvironmentObject var app: AppState
    let orderId: String
    var previewContents: String = ""
    var taskId: String? = nil

    @StateObject private var store = DispatchStore()
    @State private var picked: [UIImage] = []
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var opinion = "已完成"

    private var canAct: Bool {
        store.currentStep(taskId: taskId) != nil && !store.uploading && !store.submitting
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // ── 详情卡：严格照 activity_schedule_sheet_detail.xml ──
                VStack(alignment: .leading, spacing: 0) {
                    Text("*详情")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0xA3A1A1))
                        .padding(.leading, 10)
                        .padding(.top, 10)

                    VStack(spacing: 0) {
                        // 四行：label 14sp #757778（宽 1.3 : 3），value 14sp 黑，下划 0.3 #DADDE2
                        ForEach(Array(store.detailRows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 0) {
                                Text(row.0)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: 0x757778))
                                    .padding(.leading, 10)
                                    .frame(height: 40, alignment: .leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .layoutPriority(1.3)
                                VStack(spacing: 0) {
                                    Text(row.1)
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                        .padding(.leading, 8)
                                        .frame(height: 34.5, alignment: .leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Rectangle().fill(Color(hex: 0xDADDE2)).frame(height: 0.3)
                                }
                                .padding(.trailing, 10)
                                .layoutPriority(3)
                            }
                        }

                        // 调度内容
                        VStack(alignment: .leading, spacing: 0) {
                            Text("调度内容:")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: 0x757778))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(store.contents.isEmpty ? previewContents : store.contents)
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                                .overlay(Rectangle().stroke(Color(hex: 0xE9E9E9), lineWidth: 1))
                                .padding(.horizontal, 8)
                        }

                        // 审核人
                        VStack(alignment: .leading, spacing: 0) {
                            Text("审核人:")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: 0x757778))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(store.steps.last?.userName ?? "")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                                .overlay(Rectangle().stroke(Color(hex: 0xE9E9E9), lineWidth: 1))
                                .padding(.horizontal, 8)
                        }
                        .padding(.bottom, 4)
                    }
                    .padding(5)
                    .padding(8)
                }
                .padding(.horizontal, 8)
                .overlay(
                    Rectangle().stroke(Color(hex: 0x43B3FF), lineWidth: 1)
                )
                .padding(8)

                if let taskId = taskId, !taskId.isEmpty {
                    // 拍照区
                    VStack(spacing: 10) {
                        if picked.isEmpty {
                            Button {
                                showCamera = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill").font(.system(size: 30))
                                    Text("拍照").font(.system(size: 15, weight: .medium))
                                    Text("拍完点下面「上传并完成」").font(.system(size: 11))
                                        .foregroundColor(C.sub)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 26)
                                .background(C.cardBg).cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(C.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [5])))
                            }
                            .buttonStyle(.plain)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(picked.enumerated()), id: \.offset) { idx, img in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: img)
                                                .resizable().scaledToFill()
                                                .frame(width: 92, height: 92).clipped()
                                                .cornerRadius(8)
                                            Button {
                                                picked.remove(at: idx)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                    Button {
                                        showCamera = true
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: "camera.fill")
                                            Text("继续拍").font(.system(size: 10))
                                        }
                                        .frame(width: 92, height: 92)
                                        .background(C.cardBg).cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8)
                                            .stroke(C.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            HStack {
                                Text("已拍 \(picked.count) 张").font(.system(size: 12)).foregroundColor(C.sub)
                                Spacer()
                                Button("从相册选") { showLibrary = true }
                                    .font(.system(size: 12)).foregroundColor(C.blue)
                            }
                        }
                    }
                    .padding(14).background(Color.white).cornerRadius(10)

                    // 提交
                    VStack(spacing: 10) {
                        Button {
                            Task {
                                if !picked.isEmpty {
                                    let up = await store.uploadPhotos(picked, orderId: orderId, taskId: taskId)
                                    guard up else { return }
                                }
                                let ok = await store.submit(orderId: orderId, taskId: taskId, opinion: opinion)
                                if ok {
                                    app.show("调度单已完成 ✓")
                                    picked = []
                                    await store.loadDetail(orderId)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if store.uploading || store.submitting {
                                    ProgressView().tint(.white)
                                }
                                Text(store.uploading ? "上传中…"
                                     : store.submitting ? "提交中…"
                                     : "上传并完成")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 15)
                            .background(canAct ? C.blue : C.sub.opacity(0.4))
                            .foregroundColor(.white).cornerRadius(10)
                        }
                        .disabled(!canAct)

                        if store.currentStep(taskId: taskId) == nil && !store.loading {
                            Text("这张单没有待办步骤，可能已处理完毕")
                                .font(.caption).foregroundColor(.orange)
                        }

                    }
                    .padding(14).background(Color.white).cornerRadius(10)
                }
                if let error = store.detailError {
                    Text(error).font(.caption).foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // 流程记录
                if !store.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("流程记录").font(.caption).foregroundColor(C.sub)
                        ForEach(store.steps) { s in
                            HStack(alignment: .top, spacing: 9) {
                                Circle().fill(C.blue.opacity(0.7))
                                    .frame(width: 7, height: 7).padding(.top, 5)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.taskName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(C.text)
                                    Text(s.record)
                                        .font(.system(size: 12)).foregroundColor(C.sub)
                                    Text("\(s.userName)  \(s.time)")
                                        .font(.system(size: 10)).foregroundColor(C.sub.opacity(0.75))
                                    ForEach(s.files) { f in
                                        HStack(spacing: 4) {
                                            Image(systemName: "photo")
                                                .font(.system(size: 10))
                                            Text(f.filename).font(.system(size: 10))
                                        }
                                        .foregroundColor(C.blue)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14).background(Color.white).cornerRadius(10)
                }
            }
            .padding(12)
        }
        .background(C.bg)
        .navigationTitle("调度单")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCamera) {
            CameraPicker(images: $picked, useCamera: true)
        }
        .sheet(isPresented: $showLibrary) {
            CameraPicker(images: $picked, useCamera: false)
        }
        .task { await store.loadDetail(orderId) }
        .sheet(isPresented: $showAudit) {
            NavigationView {
                ScheduleAuditScreen(taskId: taskId ?? "", businessId: orderId)
                    .environmentObject(app)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if store.currentStep(taskId: taskId) != nil {
                    Button("审核") { showAudit = true }
                }
            }
        }
    }
}

// MARK: - 相机 / 相册

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    var useCamera: Bool
    @Environment(\.presentationMode) private var presentation

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        if useCamera && UIImagePickerController.isSourceTypeAvailable(.camera) {
            p.sourceType = .camera
        } else {
            p.sourceType = .photoLibrary
        }
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                // 压到最长边 1600，避免上传过大
                parent.images.append(img.resized(maxSide: 1600))
            }
            parent.presentation.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentation.wrappedValue.dismiss()
        }
    }
}

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let m = max(w, h)
        guard m > maxSide else { return self }
        let scale = maxSide / m
        let newSize = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        draw(in: CGRect(origin: .zero, size: newSize))
        let out = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return out
    }
}
