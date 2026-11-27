import SwiftUI
import UIKit

// MARK: - 故障上报（NewFaultActivity）
//
// 流程（从 smali 提取）：
//   1) POST SIPAIIS_DataCenter/maintenance/abnormity/dosave.do
//        abnormityDescription, equipmentIds, patrolRecordId,
//        patrolPointId, processSectionId, remark
//      → 返回新记录 id
//   2) POST SIPAIIS_DataCenter/base/updateFile.do   multipart
//        masterId = 上一步的 id
//        nameSpace = maintenanceproblemfile
//        filelist = 照片

struct FaultReportScreen: View {
    @EnvironmentObject var app: AppState
    @Environment(\.presentationMode) private var presentation

    @StateObject private var store = FormStore()
    @State private var sectionOptions: [FormOption] = []
    @State private var equipmentOptions: [FormOption] = []
    @State private var sectionId = ""
    @State private var equipmentId = ""
    @State private var description = ""
    @State private var remark = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 工艺段
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 3) {
                        Text("工艺段").font(.system(size: 12)).foregroundColor(C.sub)
                        Text("*").font(.system(size: 12)).foregroundColor(.red)
                    }
                    Menu {
                        ForEach(sectionOptions) { o in
                            Button(o.name) {
                                sectionId = o.id
                                equipmentId = ""
                                Task { await loadEquipment(section: o.id) }
                            }
                        }
                    } label: {
                        pickerLabel(sectionOptions.first { $0.id == sectionId }?.name ?? "请选择工艺段")
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)

                // 设备
                VStack(alignment: .leading, spacing: 6) {
                    Text("设备（可不选）").font(.system(size: 12)).foregroundColor(C.sub)
                    Menu {
                        Button("不指定设备") { equipmentId = "" }
                        ForEach(equipmentOptions) { o in
                            Button(o.name) { equipmentId = o.id }
                        }
                    } label: {
                        pickerLabel(equipmentOptions.first { $0.id == equipmentId }?.name ?? "不指定设备")
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)

                // 描述
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 3) {
                        Text("异常描述").font(.system(size: 12)).foregroundColor(C.sub)
                        Text("*").font(.system(size: 12)).foregroundColor(.red)
                    }
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("描述发现的问题…").font(.system(size: 15))
                                .foregroundColor(C.sub.opacity(0.6))
                                .padding(.horizontal, 14).padding(.vertical, 12)
                        }
                        TextEditor(text: $description)
                            .font(.system(size: 15)).frame(minHeight: 110).padding(8)
                    }
                    .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                    .cornerRadius(7)
                }
                .padding(14).background(Color.white).cornerRadius(10)

                // 备注
                VStack(alignment: .leading, spacing: 6) {
                    Text("备注").font(.system(size: 12)).foregroundColor(C.sub)
                    TextField("可选", text: $remark)
                        .font(.system(size: 15)).padding(10)
                        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                        .cornerRadius(7)
                }
                .padding(14).background(Color.white).cornerRadius(10)

                // 照片
                PhotoStrip(photos: $store.photos)

                // 提交
                VStack(spacing: 8) {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if busy { ProgressView().tint(.white) }
                            Text(busy ? "提交中…" : "上报")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(sectionId.isEmpty || description.isEmpty ? C.sub.opacity(0.4) : C.blue)
                        .foregroundColor(.white).cornerRadius(10)
                    }
                    .disabled(busy || sectionId.isEmpty || description.isEmpty)

                    if let m = message {
                        Text(m).font(.caption).foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)
            }
            .padding(12)
        }
        .background(C.bg)
        .navigationTitle("异常上报")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadSections() }
    }

    private func pickerLabel(_ text: String) -> some View {
        HStack {
            Text(text).font(.system(size: 15))
                .foregroundColor(text.hasPrefix("请选择") || text.hasPrefix("不指定") ? C.sub : C.text)
            Spacer()
            Image(systemName: "chevron.down").font(.system(size: 12)).foregroundColor(C.sub)
        }
        .padding(11)
        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
        .overlay(RoundedRectangle(cornerRadius: 7)
            .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
        .cornerRadius(7)
    }

    private func loadSections() async {
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getlist.do",
                ["unitId": app.unit, "page": "1", "rows": "200"])
            let arr = Net.array(raw, key: "rows")
            sectionOptions = arr.compactMap {
                let id = Net.str($0, "id")
                let name = Net.str($0, "name")
                guard !id.isEmpty else { return nil }
                return FormOption(id: id, name: name.isEmpty ? id : name)
            }
        } catch {
            message = "工艺段加载失败：\(error.localizedDescription)"
        }
    }

    private func loadEquipment(section: String) async {
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
            equipmentOptions = arr.compactMap {
                let id = Net.str($0, "id")
                let name = Net.str($0, "name")
                guard !id.isEmpty else { return nil }
                return FormOption(id: id, name: name.isEmpty ? id : name)
            }
        } catch {
            equipmentOptions = []
        }
    }

    private func submit() async {
        busy = true
        message = nil
        do {
            // 1) 建单
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/maintenance/abnormity/dosave.do",
                ["unitId": app.unit,
                 "abnormityDescription": description,
                 "equipmentIds": equipmentId,
                 "patrolRecordId": "",
                 "patrolPointId": "",
                 "processSectionId": sectionId,
                 "remark": remark])
            let d = Net.dict(raw)
            // 兼容：id 可能在顶层、result 或 data
            var newId = Net.str(d, "id")
            if newId.isEmpty { newId = Net.str(Net.dict(d["result"]), "id") }
            if newId.isEmpty { newId = Net.str(Net.dict(d["data"]), "id") }
            if newId.isEmpty {
                // 有些实现返回 code:1 且把 id 放在字符串里
                if Net.int(d, "code") == 1, let s = d["result"] as? String, !s.isEmpty {
                    newId = s
                }
            }
            guard !newId.isEmpty else {
                message = "建单返回：\(String(describing: raw).prefix(200))"
                busy = false
                return
            }

            // 2) 传照片
            if !store.photos.isEmpty {
                var files: [Net.UploadFile] = []
                for (i, img) in store.photos.enumerated() {
                    guard let data = img.jpegData(compressionQuality: 0.72) else { continue }
                    files.append(Net.UploadFile(
                        field: "filelist",
                        filename: "IMG_\(Int(Date().timeIntervalSince1970))_\(i).jpg",
                        mime: "image/jpeg",
                        data: data))
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
            message = "提交失败：\(error.localizedDescription)"
            busy = false
        }
    }
}

// MARK: - 照片条

struct PhotoStrip: View {
    @Binding var photos: [UIImage]
    @State private var showCamera = false
    @State private var showLibrary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("现场照片").font(.system(size: 12)).foregroundColor(C.sub)
            if photos.isEmpty {
                HStack(spacing: 10) {
                    pickerButton("拍照", "camera.fill") { showCamera = true }
                    pickerButton("相册", "photo.on.rectangle") { showLibrary = true }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 86, height: 86).clipped().cornerRadius(6)
                                Button { photos.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                        Button { showCamera = true } label: {
                            Image(systemName: "camera.fill").font(.system(size: 20))
                                .foregroundColor(C.blue)
                                .frame(width: 86, height: 86)
                                .background(C.cardBg).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(C.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("共 \(photos.count) 张").font(.system(size: 11)).foregroundColor(C.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Color.white).cornerRadius(10)
        .sheet(isPresented: $showCamera) { CameraPicker(images: $photos, useCamera: true) }
        .sheet(isPresented: $showLibrary) { CameraPicker(images: $photos, useCamera: false) }
    }

    private func pickerButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20))
                Text(title).font(.system(size: 11))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(C.cardBg).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(C.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
        .buttonStyle(.plain)
    }
}
