import QuickLook
import SwiftUI

struct KnowledgeAttachmentScreen: View {
    let documentID: String
    let title: String
    @State private var attachments: [Attachment] = []
    @State private var loading = true
    @State private var downloading = false
    @State private var error: String?
    @State private var preview: URL?

    private struct Attachment: Identifiable {
        let id: Int
        let name: String
        let path: String
    }

    var body: some View {
        List {
            if loading { ProgressView("正在读取附件") }
            if let error = error { Text(error).foregroundColor(.red) }
            if !loading && error == nil && attachments.isEmpty {
                Text("暂无附件").foregroundColor(.secondary)
            }
            ForEach(attachments) { file in
                Button {
                    Task { await open(file) }
                } label: {
                    Label(file.name, systemImage: "doc")
                }
                .disabled(downloading)
            }
            if downloading { ProgressView("正在下载") }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .quickLookPreview($preview)
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let raw = try await Net.shared.get("SIPAIIS_LIBRARY/knowledge/browse", ["id": documentID])
            let root = Net.dict(raw)
            guard Net.isOK(raw), let result = root["result"] else {
                throw APIError.message("读取文档附件失败")
            }
            var document = Net.dict(result)
            if let encoded = result as? String {
                document = Net.dict(try JSONSerialization.jsonObject(with: Data(encoded.utf8)))
            }
            guard !document.isEmpty else { throw APIError.message("服务未返回文档详情") }
            attachments = Net.array(document, key: "_files").enumerated().compactMap { index, row in
                let path = Net.str(row, "filepath")
                guard !path.isEmpty else { return nil }
                let name = Net.str(row, "filename")
                return Attachment(id: index, name: name.isEmpty ? "附件 \(index + 1)" : name, path: path)
            }
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    private func open(_ file: Attachment) async {
        guard !downloading else { return }
        downloading = true
        error = nil
        defer { downloading = false }
        do {
            let url = try await Net.shared.downloadKnowledgeFile(path: file.path, displayName: file.name)
            guard QLPreviewController.canPreview(url as NSURL) else {
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
                throw APIError.message("此附件格式无法在 iPhone 预览")
            }
            preview = url
        } catch {
            self.error = error.localizedDescription
        }
    }
}

