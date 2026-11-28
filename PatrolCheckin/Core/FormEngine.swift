import SwiftUI
import UIKit

// MARK: - 通用表单引擎
// 用声明式字段描述生成表单，避免每个模块手写一遍布局。

enum FieldKind {
    case text              // 单行
    case multiline         // 多行
    case picker            // 单选（从接口拉选项）
    case date              // 日期
}

struct FormField: Identifiable {
    let key: String
    let label: String
    let kind: FieldKind
    var placeholder: String = ""
    var required: Bool = false
    var options: [FormOption] = []

    var id: String { key }
}

struct FormOption: Identifiable, Hashable {
    let id: String
    let name: String

    static func treeOptions(from data: Any, users: Bool) -> [FormOption] {
        let roots = Net.array(data, key: "result")
        var found = Set<String>()
        func walk(_ nodes: [[String: Any]]) -> [FormOption] {
            nodes.flatMap { node -> [FormOption] in
                let children = Net.array(node, key: "children")
                let id = Net.str(node, "id")
                let name = Net.str(node, "label")
                let selectable = users ? Net.str(node, "type") == "U" : children.isEmpty
                if selectable && !id.isEmpty && !name.isEmpty && found.insert(id).inserted {
                    return [FormOption(id: id, name: name)]
                }
                return walk(children)
            }
        }
        return walk(roots.isEmpty ? Net.array(data) : roots)
    }
}

@MainActor
final class FormStore: ObservableObject {
    @Published var values: [String: String] = [:]
    @Published var photos: [UIImage] = []
    @Published var options: [String: [FormOption]] = [:]
    @Published var loading = false
    @Published var submitting = false
    @Published var error: String?
    @Published var done = false

    /// 加载某个 picker 字段的选项
    func loadOptions(field: String, path: String, params: [String: String],
                     idKey: String = "id", nameKey: String = "name") async {
        do {
            let raw = try await Net.shared.post(path, params)
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                for k in ["rows", "result", "content1", "list", "data"] {
                    if let a = d[k] as? [[String: Any]] { arr = a; break }
                    if let sub = d[k] as? [String: Any], let a = sub["rows"] as? [[String: Any]] {
                        arr = a; break
                    }
                }
            }
            options[field] = arr.compactMap { d in
                let id = Net.str(d, idKey)
                let name = Net.str(d, nameKey)
                guard !id.isEmpty else { return nil }
                return FormOption(id: id, name: name.isEmpty ? id : name)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func value(_ k: String) -> String { values[k] ?? "" }
    func set(_ k: String, _ v: String) { values[k] = v }

    func validate(_ fields: [FormField]) -> Bool {
        for f in fields where f.required {
            if value(f.key).trimmingCharacters(in: .whitespaces).isEmpty {
                error = "请填写「\(f.label)」"
                return false
            }
        }
        return true
    }
}

struct FormView: View {
    let fields: [FormField]
    @ObservedObject var store: FormStore
    var submitTitle: String = "提交"
    var allowPhotos: Bool = true
    var onSubmit: () async -> Bool

    @State private var showCamera = false
    @State private var showLibrary = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(fields) { f in
                    fieldView(f)
                }

                if allowPhotos {
                    photoBlock
                }

                VStack(spacing: 8) {
                    Button {
                        Task {
                            guard store.validate(fields) else { return }
                            store.submitting = true
                            let ok = await onSubmit()
                            store.submitting = false
                            if ok { store.done = true }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if store.submitting { ProgressView().tint(.white) }
                            Text(store.submitting ? "提交中…" : submitTitle)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(C.blue).foregroundColor(.white).cornerRadius(10)
                    }
                    .disabled(store.submitting)

                    if let e = store.error {
                        Text(e).font(.caption).foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)
            }
            .padding(12)
        }
        .background(C.bg)
        .sheet(isPresented: $showCamera) { CameraPicker(images: $store.photos, useCamera: true) }
        .sheet(isPresented: $showLibrary) { CameraPicker(images: $store.photos, useCamera: false) }
    }

    @ViewBuilder
    private func fieldView(_ f: FormField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(f.label).font(.system(size: 12)).foregroundColor(C.sub)
                if f.required { Text("*").font(.system(size: 12)).foregroundColor(.red) }
            }

            switch f.kind {
            case .text:
                TextField(f.placeholder.isEmpty ? f.label : f.placeholder,
                          text: Binding(get: { store.value(f.key) },
                                        set: { store.set(f.key, $0) }))
                    .font(.system(size: 15)).padding(10)
                    .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                    .cornerRadius(7)

            case .multiline:
                ZStack(alignment: .topLeading) {
                    if store.value(f.key).isEmpty {
                        Text(f.placeholder).font(.system(size: 15))
                            .foregroundColor(C.sub.opacity(0.6))
                            .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    TextEditor(text: Binding(get: { store.value(f.key) },
                                             set: { store.set(f.key, $0) }))
                        .font(.system(size: 15)).frame(minHeight: 92)
                        .padding(8).background(Color.clear)
                }
                .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                .cornerRadius(7)

            case .picker:
                let opts = store.options[f.key] ?? []
                Menu {
                    ForEach(opts) { o in
                        Button(o.name) { store.set(f.key, o.id); store.set(f.key + "_name", o.name) }
                    }
                } label: {
                    HStack {
                        Text(store.value(f.key + "_name").isEmpty
                             ? (opts.isEmpty ? "加载中…" : "请选择")
                             : store.value(f.key + "_name"))
                            .font(.system(size: 15))
                            .foregroundColor(store.value(f.key + "_name").isEmpty ? C.sub : C.text)
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 12)).foregroundColor(C.sub)
                    }
                    .padding(11)
                    .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                    .cornerRadius(7)
                }

            case .date:
                DatePicker("",
                           selection: Binding(
                            get: { FormView.parseDate(store.value(f.key)) },
                            set: { store.set(f.key, FormView.formatDate($0)) }),
                           displayedComponents: [.date])
                    .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Color.white).cornerRadius(10)
    }

    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("现场照片").font(.system(size: 12)).foregroundColor(C.sub)
            if store.photos.isEmpty {
                HStack(spacing: 10) {
                    Button { showCamera = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill").font(.system(size: 20))
                            Text("拍照").font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(C.cardBg).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(C.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }
                    .buttonStyle(.plain)

                    Button { showLibrary = true } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle").font(.system(size: 20))
                            Text("相册").font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(C.cardBg).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(C.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(store.photos.enumerated()), id: \.offset) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 84, height: 84).clipped().cornerRadius(6)
                                Button { store.photos.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                        Button { showCamera = true } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20)).foregroundColor(C.blue)
                                .frame(width: 84, height: 84)
                                .background(C.cardBg).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(C.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("共 \(store.photos.count) 张").font(.system(size: 11)).foregroundColor(C.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Color.white).cornerRadius(10)
    }

    static func parseDate(_ s: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s) ?? Date()
    }
    static func formatDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}
