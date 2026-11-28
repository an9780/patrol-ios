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
    @State private var description = ""
    @State private var photos: [UIImage] = []
    @State private var busy = false
    @State private var message: String?
    @State private var showSectionPicker = false
    @State private var showEquPicker = false

    private let blue = Color(hex: 0x419DE4)

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("异常上报").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

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
                                .font(.system(size: 16))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(app.caption)
                                .font(.system(size: 16))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(3)
                        }

                        divider

                        // *工艺段：
                        Button { showSectionPicker = true } label: {
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
                                if description.isEmpty {
                                    Text("填写异常描述")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: 0xC7C7CD))
                                        .padding(.leading, 10).padding(.top, 8)
                                }
                                TextEditor(text: $description)
                                    .font(.system(size: 16))
                                    .padding(.leading, 4)
                                    .frame(height: 100)
                            }
                        }
                        .frame(height: 135, alignment: .top)

                        divider
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
                                            Image(uiImage: img)
                                                .resizable().scaledToFill()
                                                .frame(width: 80, height: 100).clipped()
                                                .cornerRadius(4)
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

                            Button { showCameraPicker() } label: {
                                Image("moudle_add")
                                    .resizable().scaledToFit()
                                    .padding(15)
                                    .frame(width: 60, height: 100)
                            }
                            .buttonStyle(.plain)
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
                        Button { showEquPicker = true } label: {
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
                            Text("")
                                .padding(.leading, 10)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(3)
                        }
                    }
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
                            Text(busy ? "提交中…" : "提 交")
                                .font(.system(size: 19)).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(blue).cornerRadius(3)
                    }
                    .disabled(busy || description.isEmpty)
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
        .sheet(isPresented: $showSectionPicker) {
            OptionPicker(title: "选择工艺段", options: sections) { o in
                sectionId = o.id
                Task { await loadEquipments(section: o.id) }
            }
        }
        .sheet(isPresented: $showEquPicker) {
            OptionPicker(title: "选择设备", options: equipments) { o in
                equipmentId = o.id
            }
        }
        .sheet(isPresented: $showPickerCamera) {
            CameraPicker(images: $photos, useCamera: true)
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
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getlist.do",
                ["unitId": app.unit, "page": "1", "rows": "200"])
            sections = Net.array(raw, key: "rows").compactMap {
                let id = Net.str($0, "id"), n = Net.str($0, "name")
                guard !id.isEmpty else { return nil }
                return FormOption(id: id, name: n.isEmpty ? id : n)
            }
        } catch { sections = [] }
    }

    private func loadEquipments(section: String) async {
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/equipment/getList.do",
                ["unitId": app.unit, "pSectionId": section, "page": "1", "rows": "200"])
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { arr = a }
                else if let sub = d["result"] as? [String: Any],
                        let a = sub["rows"] as? [[String: Any]] { arr = a }
            }
            equipments = arr.compactMap {
                let id = Net.str($0, "id"), n = Net.str($0, "name")
                guard !id.isEmpty else { return nil }
                return FormOption(id: id, name: n.isEmpty ? id : n)
            }
        } catch { equipments = [] }
    }

    private func submit() async {
        busy = true
        message = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/maintenance/abnormity/dosave.do",
                ["unitId": app.unit,
                 "abnormityDescription": description,
                 "equipmentIds": equipmentId,
                 "patrolRecordId": patrolRecordID,
                 "patrolPointId": "",
                 "processSectionId": sectionId,
                 "remark": ""])
            let d = Net.dict(raw)
            var newId = Net.str(d, "id")
            if newId.isEmpty { newId = Net.str(Net.dict(d["result"]), "id") }
            if newId.isEmpty, let s = d["result"] as? String { newId = s }
            guard !newId.isEmpty else {
                message = Net.message(raw)
                busy = false
                return
            }
            if !photos.isEmpty {
                var files: [Net.UploadFile] = []
                for (i, img) in photos.enumerated() {
                    guard let data = img.jpegData(compressionQuality: 0.72) else { continue }
                    files.append(Net.UploadFile(field: "filelist",
                                                filename: "IMG_\(Int(Date().timeIntervalSince1970))_\(i).jpg",
                                                mime: "image/jpeg", data: data))
                }
                _ = try await Net.shared.upload(
                    "SIPAIIS_DataCenter/base/updateFile.do",
                    fields: ["masterId": newId,
                             "tbName": "tb_maintenance_problem_fille",
                             "nameSpace": "maintenanceproblemfile",
                             "recordId": newId],
                    files: files)
            }
            app.show("异常上报成功 ✓")
            busy = false
            presentation.wrappedValue.dismiss()
        } catch {
            message = error.localizedDescription
            busy = false
        }
    }
}

// MARK: - 通用单选弹窗

struct OptionPicker: View {
    let title: String
    let options: [FormOption]
    var onPick: (FormOption) -> Void
    @Environment(\.presentationMode) private var presentation

    var body: some View {
        NavigationView {
            List(options) { o in
                Button {
                    onPick(o)
                    presentation.wrappedValue.dismiss()
                } label: {
                    HStack {
                        Text(o.name).foregroundColor(.black)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12)).foregroundColor(C.sub)
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
