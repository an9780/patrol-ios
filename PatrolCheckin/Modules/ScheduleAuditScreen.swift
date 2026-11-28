import SwiftUI
import UIKit
import PhotosUI

struct ScheduleAuditScreen: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let taskId: String
    let businessId: String
    var previewContents = ""
    var onSubmitted: () -> Void = {}

    @State private var order: [String: Any] = [:]
    @State private var task: [String: Any] = [:]
    @State private var workTasks: [[String: Any]] = []
    @State private var users: [FormOption] = []
    @State private var recipients: Set<String> = []
    @State private var copies: Set<String> = []
    @State private var pass = true
    @State private var opinion = ""
    @State private var route = ""
    @State private var photos: [UIImage] = []
    @State private var uploaded = false
    @State private var loading = true
    @State private var busy = false
    @State private var loadError: String?
    @State private var submitError: String?
    @State private var showSources = false
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var selecting: UserSelection?
    @State private var preview: AttachmentPreview?

    private enum UserSelection: String, Identifiable {
        case recipients = "接收人"
        case copies = "抄送人"
        var id: Self { self }
    }

    private struct AttachmentPreview: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private var routes: [FormOption] {
        workTasks.enumerated().compactMap { index, item in
            let flag = Net.str(item, "passFlag").lowercased()
            if ["true", "1", "false", "0"].contains(flag), (flag == "true" || flag == "1") != pass {
                return nil
            }
            let title = Net.str(item, "text")
            let name = title.isEmpty ? Net.str(item, "name") : title
            guard !name.isEmpty else { return nil }
            return FormOption(id: String(index), name: name)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: "调度审核", back: { if !busy { dismiss() } })
            ScrollView {
                VStack(spacing: 14) {
                    details
                    if loading {
                        ProgressView("正在加载审核信息").padding(16)
                    } else if let error = loadError {
                        Text(error).foregroundColor(.red)
                        Button("重试") { Task { await load() } }
                    } else {
                        approval
                        if let error = submitError {
                            Text(error).font(.footnote).foregroundColor(.red)
                        }
                        Button {
                            Task { await submit() }
                        } label: {
                            Text(busy ? "提交中…" : "提交")
                                .font(.system(size: 16, weight: .medium))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundColor(.white)
                                .background(busy ? C.sub : C.blue)
                                .cornerRadius(3)
                        }
                        .disabled(busy)
                    }
                }
                .padding(9)
            }
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .interactiveDismissDisabled(busy)
        .task { await load() }
        .confirmationDialog("添加附件", isPresented: $showSources, titleVisibility: .visible) {
            Button("从相册选择") { showLibrary = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍照") { showCamera = true }
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showLibrary) { DispatchPhotoLibrary(images: $photos) }
        .sheet(isPresented: $showCamera) { CameraPicker(images: $photos, useCamera: true) }
        .fullScreenCover(item: $preview) { item in
            VStack(spacing: 0) {
                BlueHeader(title: "附件预览", back: { preview = nil })
                Image(uiImage: item.image).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fullScreenCover(item: $selecting) { selection in
            userPicker(selection, selected: selection == .recipients ? $recipients : $copies)
        }
    }

    private var details: some View {
        let company = Net.dict(order["targetCompany"])
        let companyName = Net.str(company, "name")
        let start = String(Net.str(order, "stdt").prefix(10))
        let end = String(Net.str(order, "eddt").prefix(10))
        let content = Net.str(order, "contents")
        return VStack(alignment: .leading, spacing: 0) {
            Text("*详情").foregroundColor(C.sub).padding(.bottom, 8)
            detailRow("调度厂区", companyName.isEmpty ? Net.str(company, "sname") : companyName)
            detailRow("调度类型", Net.str(order, "typeName"))
            detailRow("调度等级", Net.str(order, "adjustmentLevel"))
            detailRow("调度日期", [start, end].filter { !$0.isEmpty }.joined(separator: " --- "))
            Text("调度内容：").foregroundColor(C.sub).padding(.vertical, 9)
            Text(content.isEmpty ? previewContents : content)
                .frame(maxWidth: .infinity, alignment: .leading).padding(7)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.25), lineWidth: 0.5))
        }
        .font(.system(size: 14))
        .padding(12)
        .overlay(Rectangle().stroke(C.bar.opacity(0.45), lineWidth: 0.6))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                Text(label + "：").foregroundColor(C.sub).frame(width: 90, alignment: .leading)
                Text(value).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 11)
            Divider()
        }
    }

    private var approval: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("*请审批工单").foregroundColor(C.sub)
            HStack {
                Text("*审核结果").frame(width: 85, alignment: .leading)
                Picker("审核结果", selection: $pass) {
                    Text("通过").tag(true)
                    Text("驳回").tag(false)
                }.pickerStyle(.menu).background(C.bg)
            }
            HStack {
                Text("*下一节点").frame(width: 85, alignment: .leading)
                Picker("下一节点", selection: $route) {
                    if routes.isEmpty { Text("无").tag("") }
                    ForEach(routes) { Text($0.name).tag($0.id) }
                }.pickerStyle(.menu).background(C.bg)
            }
            HStack {
                personRow("*接收人", .recipients, recipients)
                Button("选本人") { recipients = [Net.shared.userid] }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .foregroundColor(.white).background(C.blue).cornerRadius(3)
                    .disabled(Net.shared.userid.isEmpty)
            }
            personRow("抄送人", .copies, copies)
            if !pass {
                TextField("填写驳回意见", text: $opinion)
                    .textFieldStyle(.roundedBorder)
            }
            Text(uploaded ? "附件已上传" : "点击查看附件，长按删除")
                .foregroundColor(C.sub).padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.25), lineWidth: 0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos.indices, id: \.self) { index in
                        Button { preview = AttachmentPreview(image: photos[index]) } label: {
                            Image(uiImage: photos[index]).resizable().scaledToFill()
                                .frame(width: 62, height: 62).clipped()
                        }
                        .contextMenu {
                            if !uploaded {
                                Button("删除附件", role: .destructive) {
                                    if photos.indices.contains(index) { photos.remove(at: index) }
                                }
                            }
                        }
                    }
                    if !uploaded {
                        Button { showSources = true } label: {
                            Image(systemName: "plus").font(.system(size: 30, weight: .light))
                                .frame(width: 62, height: 62)
                        }
                        .accessibilityLabel("添加附件")
                        Button("从相册选择") { showLibrary = true }
                    }
                }
            }
        }
        .font(.system(size: 14))
        .padding(12)
        .overlay(Rectangle().stroke(Color.red.opacity(0.4), lineWidth: 0.6))
        .disabled(busy)
        .onChange(of: pass) { _ in route = routes.first?.id ?? "" }
    }

    private func personRow(_ title: String, _ selection: UserSelection, _ ids: Set<String>) -> some View {
        let names = ids.sorted().map { id in
            id == Net.shared.userid ? app.caption : users.first { $0.id == id }?.name ?? id
        }
        return HStack {
            Text(title + "：").frame(width: 85, alignment: .leading)
            Button(names.isEmpty ? "点击选择" + selection.rawValue : names.joined(separator: "、")) {
                selecting = selection
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 30)
    }

    private func userPicker(_ selection: UserSelection, selected: Binding<Set<String>>) -> some View {
        VStack(spacing: 0) {
            BlueHeader(title: "选择" + selection.rawValue, back: { selecting = nil })
            List {
                if users.isEmpty {
                    Button("加载人员") { Task { await loadUsers() } }
                    if let error = submitError { Text(error) }
                }
                ForEach(users) { user in
                    Button {
                        if selected.wrappedValue.contains(user.id) { selected.wrappedValue.remove(user.id) }
                        else { selected.wrappedValue.insert(user.id) }
                    } label: {
                        HStack {
                            Text(user.name)
                            Spacer()
                            if selected.wrappedValue.contains(user.id) { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
            Button("完成") { selecting = nil }.padding()
        }
        .task { if users.isEmpty { await loadUsers() } }
    }

    private func load() async {
        loading = true
        loadError = nil
        defer { loading = false }
        do {
            let raw = try await Net.shared.get(
                "SIPAIIS_DataCenter/work/processAdjustment/showActCommDetail.do", ["taskId": taskId])
            let envelope = Net.dict(raw)
            var result = Net.dict(envelope["result"])
            if result.isEmpty, let json = envelope["result"] as? String {
                result = Net.dict(try JSONSerialization.jsonObject(with: Data(json.utf8)))
            }
            if result.isEmpty { result = envelope }
            let metadata = Net.dict(result["task"])
            let entity = Net.dict(result["businessEntity"])
            guard Net.str(metadata, "id") == taskId, Net.str(entity, "id") == businessId,
                  !Net.str(metadata, "taskDefinitionKey").isEmpty,
                  !Net.str(metadata, "processInstanceId").isEmpty,
                  !Net.str(metadata, "processDefinitionId").isEmpty else {
                throw APIError.message("后台未返回这张调度单的可办理审核信息。")
            }
            task = metadata
            order = entity
            workTasks = Net.array(result, key: "workTasks")
            route = routes.first?.id ?? ""
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func loadUsers() async {
        do {
            submitError = nil
            let raw = try await Net.shared.post("SIPAIIS_Base/user/getUnitForTree_User.do")
            users = FormOption.treeOptions(from: raw, users: true)
            if users.isEmpty { submitError = "后台未返回可选人员。" }
        } catch { submitError = error.localizedDescription }
    }

    private func submit() async {
        guard !busy else { return }
        if !routes.isEmpty && route.isEmpty {
            submitError = "请选择下一节点。"
            return
        }
        if !routes.isEmpty && recipients.isEmpty {
            submitError = "请选择接收人。"
            return
        }
        let reason = opinion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pass && reason.isEmpty {
            submitError = "请填写驳回意见。"
            return
        }
        busy = true
        submitError = nil
        defer { busy = false }
        do {
            if !uploaded && !photos.isEmpty {
                let files = try photos.enumerated().map { index, image -> Net.UploadFile in
                    guard let data = image.resized(maxSide: 1600).jpegData(compressionQuality: 0.75) else {
                        throw APIError.message("第 \(index + 1) 张照片无法读取。")
                    }
                    return Net.UploadFile(field: "filelist", filename: "\(UUID().uuidString).jpg",
                                          mime: "image/jpeg", data: data)
                }
                let response = try await Net.shared.upload(
                    "SIPAIIS_Base/base/updateFile.do",
                    fields: ["masterId": taskId, "tbName": "tb_common_file", "nameSpace": "taskmaterial"],
                    files: files, acceptsPlainSuccess: true)
                guard Net.isOK(response) || Net.str(Net.dict(response), "suc") == "1"
                        || (response as? String) == "suc" else {
                    throw APIError.message("附件上传失败。\(Net.message(response))")
                }
                uploaded = true
            }
            var fields: [String: Any] = [
                "taskid": taskId, "taskdefinitionkey": Net.str(task, "taskDefinitionKey"),
                "taskCopyUserIds": copies.sorted().joined(separator: ","),
                "targetusers": recipients.sorted().joined(separator: ","),
                "processid": Net.str(task, "processInstanceId"),
                "processDefId": Net.str(task, "processDefinitionId"),
                "passstatus": pass, "businessid": businessId,
                "fieldList": "[]", "fieldName": "", "fieldValue": ""
            ]
            if !pass { fields["auditopinion"] = reason }
            let response = try await Net.shared.postJSON(
                "SIPAIIS_DataCenter/work/processAdjustment/doAuditDetail.do",
                fields, acceptsPlainSuccess: true)
            guard Net.isOK(response) || Net.str(Net.dict(response), "suc") == "1"
                    || (response as? String) == "suc" else {
                throw APIError.message(Net.message(response))
            }
            app.show("调度审核已提交")
            onSubmitted()
            dismiss()
        } catch {
            submitError = uploaded ? "附件已上传，审核未提交。\(error.localizedDescription)" : error.localizedDescription
        }
    }
}

private struct DispatchPhotoLibrary: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: DispatchPhotoLibrary
        init(parent: DispatchPhotoLibrary) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            Task { @MainActor in
                for item in results where item.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    let image: UIImage? = await withCheckedContinuation { continuation in
                        _ = item.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                            continuation.resume(returning: object as? UIImage)
                        }
                    }
                    if let image = image { parent.images.append(image.resized(maxSide: 1600)) }
                }
                parent.dismiss()
            }
        }
    }
}
