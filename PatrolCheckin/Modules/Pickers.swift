import SwiftUI
import UIKit

// MARK: - 备件选择（GoodsSelActivity）

struct GoodsPickerScreen: View {
    @EnvironmentObject var app: AppState
    @Environment(\.presentationMode) private var presentation

    let onPick: (FormOption) -> Void

    @State private var keyword = ""
    @State private var rows: [FormOption] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(C.sub)
                    TextField("备件名称", text: $keyword)
                        .font(.system(size: 15))
                        .onSubmit { Task { await search() } }
                    Button("搜索") { Task { await search() } }
                        .font(.system(size: 13)).foregroundColor(C.blue)
                }
                .padding(10).background(Color.white).cornerRadius(8)
                .padding(12)

                if loading {
                    ProgressView().padding(.top, 50); Spacer()
                } else if rows.isEmpty {
                    EmptyHint(text: error ?? "输入备件名搜索")
                } else {
                    List(rows) { o in
                        Button {
                            onPick(o)
                            presentation.wrappedValue.dismiss()
                        } label: {
                            SelectableGreenRow(title: o.name, checked: false)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .background(C.bg)
            .navigationTitle("选择备件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { presentation.wrappedValue.dismiss() }
                }
            }
            .task { await search() }
        }
    }

    private func search() async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/sparepart/goodsClass/search.do",
                ["unit_id": app.unit, "name": keyword, "page": "1", "rows": "100"])
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { arr = a }
                else if let sub = d["result"] as? [String: Any],
                        let a = sub["rows"] as? [[String: Any]] { arr = a }
            }
            rows = arr.compactMap {
                let id = Net.str($0, "id")
                let name = Net.str($0, "name")
                guard !id.isEmpty else { return nil }
                return FormOption(id: id, name: name.isEmpty ? id : name)
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - 人员选择（PersonSelectorActivity）

struct UserPickerScreen: View {
    @EnvironmentObject var app: AppState
    @Environment(\.presentationMode) private var presentation

    let multiple: Bool
    let onPick: ([FormOption]) -> Void

    @State private var keyword = ""
    @State private var users: [FormOption] = []
    @State private var selected: Set<String> = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(C.sub)
                    TextField("姓名", text: $keyword)
                        .font(.system(size: 15))
                    if !keyword.isEmpty {
                        Button {
                            keyword = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(C.sub)
                        }
                    }
                }
                .padding(10).background(Color.white).cornerRadius(8)
                .padding(12)

                if loading {
                    ProgressView().padding(.top, 50); Spacer()
                } else if filtered.isEmpty {
                    EmptyHint(text: error ?? "没有人员")
                } else {
                    List {
                        ForEach(filtered) { u in
                            Button {
                                if multiple {
                                    if selected.contains(u.id) { selected.remove(u.id) }
                                    else { selected.insert(u.id) }
                                } else {
                                    onPick([u])
                                    presentation.wrappedValue.dismiss()
                                }
                            } label: {
                                SelectableGreenRow(title: u.name,
                                                   checked: selected.contains(u.id))
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                }

                if multiple {
                    Button {
                        onPick(users.filter { selected.contains($0.id) })
                        presentation.wrappedValue.dismiss()
                    } label: {
                        Text("确定（\(selected.count)）")
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(C.blue).foregroundColor(.white)
                    }
                }
            }
            .background(C.bg)
            .navigationTitle("选择人员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { presentation.wrappedValue.dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private var filtered: [FormOption] {
        keyword.isEmpty ? users : users.filter { $0.name.contains(keyword) }
    }

    private func load() async {
        loading = true
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Base/user/getUsers.do", ["unitId": app.unit])
            var arr: [[String: Any]] = []
            if let a = raw as? [[String: Any]] {
                arr = a
            } else if let d = raw as? [String: Any] {
                for k in ["rows", "result", "data", "list"] {
                    if let a = d[k] as? [[String: Any]] { arr = a; break }
                    if let sub = d[k] as? [String: Any],
                       let a = sub["rows"] as? [[String: Any]] { arr = a; break }
                }
            }
            users = arr.compactMap {
                let id = Net.str($0, "id")
                let cap = Net.str($0, "caption")
                let name = Net.str($0, "name")
                guard !id.isEmpty else { return nil }
                return FormOption(id: id, name: cap.isEmpty ? name : cap)
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - 工艺段树（NodesActivity）

struct SectionTreeScreen: View {
    @EnvironmentObject var app: AppState

    @State private var sections: [FormOption] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sections.isEmpty {
                EmptyHint(text: error ?? "暂无工艺段")
            } else {
                List(sections) { s in
                    NavigationLink {
                        PointListBySection(sectionId: s.id, sectionName: s.name)
                    } label: {
                        TreeRow(title: s.name)
                    }
                    .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
            }
        }
        .background(C.bg)
        .navigationTitle("工艺段")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getlist.do",
                ["unitId": app.unit, "page": "1", "rows": "200"])
            let arr = Net.array(raw, key: "rows")
            sections = arr.compactMap {
                let id = Net.str($0, "id")
                let name = Net.str($0, "name")
                guard !id.isEmpty else { return nil }
                return FormOption(id: id, name: name.isEmpty ? id : name)
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct PointListBySection: View {
    @EnvironmentObject var app: AppState
    let sectionId: String
    let sectionName: String

    @State private var rows: [GenericRow] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty {
                EmptyHint(text: error ?? "该工艺段下暂无测点")
            } else {
                LoadableList(items: rows, empty: "暂无测点") { r in
                    NavigationLink {
                        PointHistoryScreen(pointId: r.id, pointName: r.title)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "dot.radiowaves.left.and.right").foregroundColor(C.blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.title).font(.system(size: 14)).foregroundColor(C.text)
                                if !r.subtitle.isEmpty {
                                    Text(r.subtitle).font(.system(size: 11)).foregroundColor(C.sub)
                                }
                            }
                            Spacer()
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 12)).foregroundColor(C.sub)
                        }
                        .padding(11).background(Color.white).cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(C.bg)
        .navigationTitle(sectionName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getMPointByProcessSection4APP.do",
                ["pSectionId": sectionId])
            var arr: [[String: Any]] = []
            if let a = raw as? [[String: Any]] {
                arr = a
            } else if let d = raw as? [String: Any] {
                for k in ["result", "rows", "data"] {
                    if let a = d[k] as? [[String: Any]] { arr = a; break }
                    if let sub = d[k] as? [String: Any],
                       let a = sub["rows"] as? [[String: Any]] { arr = a; break }
                }
            }
            rows = arr.enumerated().map { GenericRow.from($0.element, index: $0.offset) }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - 图片补充（AddRemarkImageActivity）

struct RemarkImageScreen: View {
    @EnvironmentObject var app: AppState
    let recordId: String
    let pointId: String

    @State private var photos: [UIImage] = []
    @State private var busy = false
    @Environment(\.presentationMode) private var presentation

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("补充图片").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            // 「点击图片」提示条（#E9E9E9 描边，padding 6）
            Text("点击图片")
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .overlay(Rectangle().stroke(Color(hex: 0xE9E9E9), lineWidth: 1))

            // 图片网格区 120dp
            PhotoGrid(photos: $photos)
                .frame(height: 120)

            // 提交按钮 16sp 白，高 30
            Button {
                Task { await submit() }
            } label: {
                HStack(spacing: 6) {
                    if busy { ProgressView().tint(.white).scaleEffect(0.7) }
                    Text(busy ? "提交中…" : "提交")
                        .font(.system(size: 16)).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity).frame(height: 30)
                .background(C.blue).cornerRadius(3)
            }
            .disabled(busy || photos.isEmpty)
            .padding(10)

            Spacer()
        }
        .background(C.bg)
        .navigationBarHidden(true)
    }

    private func submit() async {
        busy = true
        var files: [Net.UploadFile] = []
        for (i, img) in photos.enumerated() {
            guard let data = img.jpegData(compressionQuality: 0.72) else { continue }
            files.append(Net.UploadFile(field: "filelist",
                                        filename: "IMG_\(Int(Date().timeIntervalSince1970))_\(i).jpg",
                                        mime: "image/jpeg", data: data))
        }
        _ = try? await Net.shared.upload(
            "SIPAIIS_DataCenter/base/updateFile.do",
            fields: ["masterId": pointId,
                     "tbName": "tb_patrol_point_file",
                     "nameSpace": "patrolpointfile",
                     "recordId": recordId],
            files: files)
        busy = false
        app.show("图片已补充 ✓")
        presentation.wrappedValue.dismiss()
    }
}

/// 120dp 高的图片网格（对应 GridView）
struct PhotoGrid: View {
    @Binding var photos: [UIImage]
    @State private var showCamera = false
    @State private var showLibrary = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.offset) { idx, img in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 100, height: 100).clipped().cornerRadius(4)
                        Button { photos.remove(at: idx) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 3, y: -3)
                    }
                }
                Button { showCamera = true } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24)).foregroundColor(C.blue)
                        .frame(width: 100, height: 100)
                        .background(Color.white).cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(hex: 0xE9E9E9), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .sheet(isPresented: $showCamera) { CameraPicker(images: $photos, useCamera: true) }
        .sheet(isPresented: $showLibrary) { CameraPicker(images: $photos, useCamera: false) }
    }
}


