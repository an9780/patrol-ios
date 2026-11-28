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
    let contents: String
    let status: String
    let typeName: String
    let targetuser: String
    let targetName: String
    let targetcompanyid: String
    let company: String
    let insdt: String
    let stdt: String
    let eddt: String

    var isMine: Bool { targetuser == Net.shared.userid }

    var statusText: String {
        switch status {
        case "1": return "进行中"
        case "2": return "已完成"
        case "3": return "已关闭"
        default:  return status.isEmpty ? "进行中" : status
        }
    }

    var manText: String { targetName.isEmpty ? targetuser : targetName }

    var dateText: String {
        let s = stdt.count >= 10 ? String(stdt.prefix(10)) : stdt
        let e = eddt.count >= 10 ? String(eddt.prefix(10)) : eddt
        if s.isEmpty && e.isEmpty { return insdt }
        return s == e ? s : "\(s) 至 \(e)"
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
    func loadList(unit: String) async {
        loading = true
        listError = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processAdjustment/getTaskList.do",
                ["page": "1", "rows": "50", "sort": "insdt",
                 "order": "desc", "taskIds": ""])

            // 返回是 {code,msg,result:{total,rows}}，每行是 {id, task:{}, businessEntity:{}}
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                if let r = d["result"] as? [String: Any],
                   let rows = r["rows"] as? [[String: Any]] {
                    arr = rows
                } else if let rows = d["rows"] as? [[String: Any]] {
                    arr = rows
                }
            }

            orders = arr.map { d in
                let task = Net.dict(d["task"])
                let be = Net.dict(d["businessEntity"])
                let company = Net.dict(be["targetCompany"])
                return DispatchOrder(
                    id: Net.str(d, "id").isEmpty ? Net.str(task, "id") : Net.str(d, "id"),
                    contents: Net.str(be, "contents"),
                    status: Net.str(be, "status"),
                    typeName: Net.str(be, "typeName"),
                    targetuser: Net.str(be, "targetuser"),
                    targetName: Net.str(be, "targetUserName"),
                    targetcompanyid: Net.str(be, "targetcompanyid"),
                    company: Net.str(company, "sname"),
                    insdt: Net.str(task, "createTime"),
                    stdt: Net.str(be, "stdt"),
                    eddt: Net.str(be, "eddt"))
            }
        } catch {
            listError = error.localizedDescription
        }
        loading = false
    }

    var mine: [DispatchOrder] { orders.filter { $0.isMine && $0.status == "1" } }
    var others: [DispatchOrder] { orders.filter { !($0.isMine && $0.status == "1") } }

    // MARK: 详情
    func loadDetail(_ id: String) async {
        loading = true
        detailError = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processAdjustment/showView.do", ["id": id])
            let res = Net.dict(Net.dict(raw)["result"])
            let be = Net.dict(res["businessEntity"])
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
                ("调度厂区：", Net.str(comp, "sname")),
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
    var currentStep: FlowStep? {
        steps.last { $0.isActionable }
    }

    // MARK: 上传
    func uploadPhotos(_ images: [UIImage], orderId: String) async -> Bool {
        guard let step = currentStep else {
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
    func submit(orderId: String, opinion: String) async -> Bool {
        guard let step = currentStep else {
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
    @State private var lastRefresh = ""
    @State private var autoRefresh = true

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: "调度单",
                       subtitle: "\(app.caption) · \(app.unit)",
                       trailing: AnyView(Button {
                           Task { await reload() }
                       } label: {
                           Image(systemName: "arrow.clockwise").foregroundColor(.white)
                       }))

            // 待办提示条
            if !store.mine.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 13))
                    Text("有 \(store.mine.count) 条调度单待你拍照完成")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Color(red: 0.85, green: 0.47, blue: 0.02))
            }

            if store.loading && store.orders.isEmpty {
                ProgressView().padding(.top, 60); Spacer()
            } else if store.orders.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.circle").font(.system(size: 56))
                        .foregroundColor(C.blue.opacity(0.22))
                    Text("暂无工单").font(.system(size: 15))
                        .foregroundColor(C.blue.opacity(0.6))
                    if let e = store.listError {
                        Text(e).font(.caption).foregroundColor(.red)
                            .multilineTextAlignment(.center).padding(.horizontal, 30)
                    }
                    Button("刷新") { Task { await reload() } }
                        .font(.system(size: 13)).padding(.top, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(C.bg)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if !store.mine.isEmpty {
                            Text("待我处理（\(store.mine.count)）")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(C.blue)
                                .padding(.horizontal, 4)
                            ForEach(store.mine) { o in card(o, highlight: true) }
                        }
                        if !store.others.isEmpty {
                            Text("全部调度单（\(store.others.count)）")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(C.sub)
                                .padding(.horizontal, 4).padding(.top, 6)
                            ForEach(store.others) { o in card(o, highlight: false) }
                        }
                        HStack {
                            Text(lastRefresh.isEmpty ? "" : "上次刷新 \(lastRefresh)")
                                .font(.system(size: 10)).foregroundColor(C.sub)
                            Spacer()
                            Button("刷新") { Task { await reload() } }
                                .font(.system(size: 11)).foregroundColor(C.blue)
                        }
                        .padding(.horizontal, 4).padding(.top, 4)
                    }
                    .padding(12)
                }
                .background(C.bg)
            }
        }
        .navigationBarHidden(true)
        .task { await reload() }
        .onReceive(timer) { _ in
            guard autoRefresh else { return }
            Task { await reload() }
        }
    }

    private func reload() async {
        await store.loadList(unit: app.unit)
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        lastRefresh = f.string(from: Date())
    }

    /// 严格照 item_schedule_sheet.xml
    /// 外层：左右 5、上下 3；内层：白底圆角 5、蓝色 0.5 描边、padding 5
    private func card(_ o: DispatchOrder, highlight: Bool) -> some View {
        NavigationLink {
            DispatchDetailScreen(orderId: o.id, previewContents: o.contents)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // 第一行：流程图标 28×28 + 类型 + 状态
                HStack(spacing: 0) {
                    Image("moudle_flow")
                        .resizable().scaledToFit()
                        .padding(.leading, 10)
                        .padding(.vertical, 6)
                        .frame(width: 28, height: 28)

                    Text(o.typeName.isEmpty ? "调度单" : o.typeName)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .padding(.leading, 8).padding(.trailing, 8)
                        .padding(.vertical, 5)
                        .frame(height: 30, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(o.statusText)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .padding(.leading, 10).padding(.trailing, 8)
                        .padding(.vertical, 5)
                }

                // 第二行：目标公司 14sp
                Text(o.company)
                    .font(.system(size: 14)).foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 第三行：调度内容 16sp
                Text(o.contents)
                    .font(.system(size: 16)).foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // 第四行：目标人 14sp
                Text(o.manText)
                    .font(.system(size: 14)).foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 第五行：日期 14sp
                Text(o.dateText)
                    .font(.system(size: 14)).foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(hex: 0x2E59F7), lineWidth: 0.5)
            )
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 调度单详情（拍照 → 上传 → 完成）

struct DispatchDetailScreen: View {
    @State private var showAudit = false
    @State private var auditTaskId = ""
    @EnvironmentObject var app: AppState
    let orderId: String
    var previewContents: String = ""

    @StateObject private var store = DispatchStore()
    @State private var picked: [UIImage] = []
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var opinion = "已完成"

    private var canAct: Bool {
        store.currentStep != nil && !store.uploading && !store.submitting
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
                                let up = await store.uploadPhotos(picked, orderId: orderId)
                                guard up else { return }
                            }
                            let ok = await store.submit(orderId: orderId, opinion: opinion)
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

                    if store.currentStep == nil && !store.loading {
                        Text("这张单没有待办步骤，可能已处理完毕")
                            .font(.caption).foregroundColor(.orange)
                    }
                    if let e = store.detailError {
                        Text(e).font(.caption).foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)

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
