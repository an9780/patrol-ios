import SwiftUI
import UIKit

// MARK: - 故障上报（严格照 res/layout/activity_new_fault.xml 还原）

struct FaultReportScreen: View {
    var patrolRecordID = ""
    @EnvironmentObject var app: AppState
    @Environment(\.presentationMode) private var presentation

    @State private var sections: [FormOption] = []
    @State private var equipments: [FormOption] = []
    @State private var sectionId = ""
    @State private var equipmentId = ""
    @State private var equipmentCodes: [String: String] = [:]
    @State private var reportId = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(16))
    @State private var saved = false
    @State private var preview: UIImage?
    @State private var showPreview = false
    @State private var showPhotoLibrary = false
    @State private var sectionsError: String?
    @State private var equipmentError: String?
    @State private var description = ""
    @State private var photos: [UIImage] = []
    @State private var busy = false
    @State private var message: String?
    @State private var showSectionPicker = false
    @State private var showEquPicker = false

    private let blue = Color(hex: 0x419DE4)

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: "异常上报", back: {
                if !busy { presentation.wrappedValue.dismiss() }
            })

            ScrollView {
                VStack(spacing: 0) {
                    // 表单卡
                    VStack(alignment: .leading, spacing: 0) {
                        // * 所属厂区
                        HStack(spacing: 0) {
                            Text("* 所属厂区")
                                .font(.system(size: 16))
                                .padding(.leading, 10).padding(.trailing, 3)
                                .frame(height: 35, alignment: .center)
                            Text(app.unitName)
                                .font(.system(size: 16))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        divider

                        // * 上报人
                        HStack(spacing: 0) {
                            Text("* 上报人")
                                .frame(width: 100, alignment: .leading)
                            Text(app.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(size: 16))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 35)

                        divider

                        // *工艺段：
                        Button {
                            if sections.isEmpty { Task { await loadSections() } }
                            showSectionPicker = true
                        } label: {
                            HStack(spacing: 0) {
                                Text("*工艺段：")
                                    .font(.system(size: 16))
                                    .padding(.leading, 10)
                                    .frame(width: 110, height: 40, alignment: .leading)
                                Text(sections.first { $0.id == sectionId }?.name ?? "请选择")
                                    .font(.system(size: 16))
                                    .foregroundColor(sectionId.isEmpty ? C.sub : .black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image("iv_down")
                                    .resizable().scaledToFit()
                                    .padding(8)
                                    .frame(width: 30, height: 40)
                                    .padding(.trailing, 30)
                            }
                        }
                        .buttonStyle(.plain)

                        divider

                        // 异常描述（高 135，输入框 100）
                        VStack(alignment: .leading, spacing: 0) {
                            Text("* 异常描述")
                                .font(.system(size: 16))
                                .padding(.leading, 10).padding(.trailing, 10)
                                .frame(height: 35, alignment: .center)
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $description)
                                    .font(.system(size: 16))
                                    .padding(.leading, 4)
                                    .frame(height: 100)
                                    .accessibilityLabel("异常描述")
                                if description.isEmpty {
                                    Text("填写异常描述")
                                        .font(.system(size: 16))
                                        .foregroundColor(C.sub)
                                        .padding(.leading, 10).padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .frame(height: 135, alignment: .top)

                        divider

                        // 附件提示
                        Text("点击查看附件，长按删除")
                            .font(.system(size: 14))
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().stroke(Color(hex: 0xE9E9E9), lineWidth: 1))
                            .padding(.horizontal, 5)

                        // 附件区（高 105）
                        HStack(alignment: .center, spacing: 0) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(Array(photos.enumerated()), id: \.offset) { idx, img in
                                        ZStack(alignment: .topTrailing) {
                                            Button {
                                                preview = img
                                                showPreview = true
                                            } label: {
                                                Image(uiImage: img)
                                                    .resizable().scaledToFill()
                                                    .frame(width: 80, height: 100).clipped()
                                                    .cornerRadius(4)
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button("删除附件", role: .destructive) {
                                                    if photos.indices.contains(idx) { photos.remove(at: idx) }
                                                }
                                            }
                                            .accessibilityLabel("查看附件 \(idx + 1)")
                                            Button { photos.remove(at: idx) } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                            }
                                            .offset(x: 3, y: -3)
                                        }
                                    }
                                }
                                .padding(.leading, 5)
                            }
                            .frame(height: 100)

                            Button { showPhotoLibrary = true } label: {
                                Image("moudle_add")
                                    .resizable().scaledToFit()
                                    .padding(15)
                                    .frame(width: 60, height: 100)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("从相册选择附件")
                        }
                        .frame(height: 105)

                        // 拍照按钮 65×30
                        HStack(spacing: 0) {
                            Button { showCameraPicker() } label: {
                                Text("拍照")
                                    .font(.system(size: 16)).foregroundColor(.white)
                                    .frame(width: 65, height: 30)
                                    .background(blue).cornerRadius(3)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 10).padding(.trailing, 10)
                            .padding(.vertical, 5)
                            Spacer()
                        }

                        divider

                        // 故障设备
                        Button {
                            showEquPicker = true
                            if equipments.isEmpty { Task { await loadEquipments(section: sectionId) } }
                        } label: {
                            Text("故障设备(点击选择)")
                                .font(.system(size: 16)).foregroundColor(blue)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 35)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 0) {
                            Text("设备名称：")
                                .padding(.leading, 10)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(equipments.first { $0.id == equipmentId }?.name ?? "")
                                .padding(.leading, 10)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(3)
                        }

                        HStack(spacing: 0) {
                            Text("设备编号：")
                                .padding(.leading, 10)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(equipmentCodes[equipmentId] ?? "")
                                .padding(.leading, 10)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(3)
                        }
                    }
                    .disabled(busy || saved)
                    .padding(5)
                    .background(Color.white)
                    .overlay(Rectangle().stroke(Color(hex: 0xE5E5E5), lineWidth: 1))
                    .padding(5)

                    // 提交 19sp 高 40
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if busy { ProgressView().tint(.white) }
                            Text(busy ? "提交中…" : saved ? "重试上传附件" : "提 交")
                                .font(.system(size: 19)).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(blue).cornerRadius(3)
                    }
                    .disabled(busy || (!saved && (description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sectionId.isEmpty)))
                    .padding(20).padding(.top, 10)

                    if let m = message {
                        Text(m).font(.system(size: 12)).foregroundColor(.red)
                            .padding(.horizontal, 20).padding(.bottom, 20)
                    }
                }
            }
            .background(C.bg)
        }
        .navigationBarHidden(true)
        .interactiveDismissDisabled(busy)
        .fullScreenCover(isPresented: $showSectionPicker) {
            OptionPicker(title: "选择工艺段", options: sections, emptyMessage: sectionsError) { o in
                guard sectionId != o.id else { return }
                sectionId = o.id
                equipmentId = ""
                equipments = []
                equipmentCodes = [:]
            }
        }
        .fullScreenCover(isPresented: $showEquPicker) {
            OptionPicker(title: "选择设备", options: equipments, emptyMessage: equipmentError) { o in
                equipmentId = o.id
            }
        }
        .sheet(isPresented: $showPickerCamera) {
            CameraPicker(images: $photos, useCamera: true)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            CameraPicker(images: $photos, useCamera: false)
        }
        .fullScreenCover(isPresented: $showPreview) {
            VStack {
                BlueHeader(title: "附件预览", back: { showPreview = false })
                if let image = preview {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task { await loadSections() }
    }

    @State private var showPickerCamera = false

    private func showCameraPicker() { showPickerCamera = true }

    private var divider: some View {
        Rectangle().fill(blue).frame(height: 0.3)
    }

    // MARK: 数据

    private func loadSections() async {
        sectionsError = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getlist.do",
                ["unitId": app.unit, "page": "1", "rows": "1000"])
            let root = Net.dict(raw)
            let entries = root["rows"] ?? Net.dict(root["result"])["rows"] ?? raw
            sections = Net.array(entries).compactMap {
                let id = Net.str($0, "id"), name = Net.str($0, "name")
                guard !id.isEmpty, !name.isEmpty else { return nil }
                return FormOption(id: id, name: name)
            }
            if sectionId.isEmpty { sectionId = sections.first?.id ?? "" }
        } catch {
            sectionsError = error.localizedDescription
        }
    }

    private func loadEquipments(section: String) async {
        equipmentError = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/equipment/getList.do",
                ["unitId": app.unit, "pSectionId": section, "page": "1", "rows": "200",
                 "search_name": "", "equipmentCardClass": "", "sort": "insdt", "order": "desc"])
            guard sectionId == section else { return }
            let root = Net.dict(raw)
            let entries = root["rows"] ?? Net.dict(root["result"])["rows"] ?? raw
            var codes: [String: String] = [:]
            equipments = Net.array(entries).compactMap {
                let id = Net.str($0, "id")
                let name = Net.str($0, "equipmentname")
                guard !id.isEmpty, !name.isEmpty, codes[id] == nil else { return nil }
                codes[id] = Net.str($0, "equipmentcardid")
                return FormOption(id: id, name: name)
            }
            equipmentCodes = codes
        } catch {
            if sectionId == section { equipmentError = error.localizedDescription }
        }
    }

    private func submit() async {
        guard !busy else { return }
        busy = true
        message = nil
        defer { busy = false }
        do {
            if !saved {
                let raw = try await Net.shared.post(
                    "SIPAIIS_DataCenter/maintenance/abnormity/dosave.do",
                    ["id": reportId, "status": "2", "unitId": app.unit, "bizId": app.unit,
                     "sumitMan": Net.shared.userid,
                     "abnormityDescription": description.trimmingCharacters(in: .whitespacesAndNewlines),
                     "equipmentIds": equipmentId, "patrolRecordId": patrolRecordID,
                     "patrolPointId": "", "processSectionId": sectionId, "remark": ""])
                let response = Net.dict(raw)
                guard Net.str(response, "res") == "1" || Net.isOK(raw) else {
                    throw APIError.message(Net.message(raw))
                }
                let returnedId = Net.str(response, "id")
                if !returnedId.isEmpty { reportId = returnedId }
                saved = true
            }
            if !photos.isEmpty {
                var files: [Net.UploadFile] = []
                for (index, photo) in photos.enumerated() {
                    guard let data = photo.jpegData(compressionQuality: 0.72) else {
                        throw APIError.message("第 \(index + 1) 张照片无法读取")
                    }
                    files.append(Net.UploadFile(field: "filelist",
                                                filename: "\(reportId)_\(index + 1).jpg",
                                                mime: "image/jpeg", data: data))
                }
                let response = try await Net.shared.upload(
                    "SIPAIIS_DataCenter/base/updateFile.do",
                    fields: ["masterId": reportId, "nameSpace": "maintenanceproblemfile"],
                    files: files, acceptsPlainSuccess: true)
                let result = Net.dict(response)
                guard Net.isOK(response) || Net.str(result, "suc") == "1" || (response as? String) == "suc" else {
                    throw APIError.message(Net.message(response))
                }
            }
            app.show("异常上报成功")
            presentation.wrappedValue.dismiss()
        } catch {
            message = saved ? "工单已保存，附件上传失败。\(error.localizedDescription)" : error.localizedDescription
        }
    }
}

// MARK: - 通用单选弹窗

struct OptionPicker: View {
    let title: String
    let options: [FormOption]
    var emptyMessage: String? = nil
    var onPick: (FormOption) -> Void
    @Environment(\.presentationMode) private var presentation

    var body: some View {
        NavigationView {
            List {
                if options.isEmpty { Text(emptyMessage ?? "暂无可选项").foregroundColor(C.sub) }
                ForEach(options) { option in
                    Button {
                        onPick(option)
                        presentation.wrappedValue.dismiss()
                    } label: {
                        HStack {
                            Text(option.name).foregroundColor(.black)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12)).foregroundColor(C.sub)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentation.wrappedValue.dismiss() }
                }
            }
        }
    }
}
