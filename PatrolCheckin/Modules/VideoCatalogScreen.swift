import AVKit
import SwiftUI

struct VideoCatalogScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var query = ""
    @State private var rows: [GenericRow] = []
    @State private var page = 0
    @State private var hasMore = true
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        List {
            HStack {
                TextField("摄像头名称", text: $query).onSubmit { Task { await load(first: true) } }
                Button("搜索") { Task { await load(first: true) } }.disabled(busy)
            }
            if let error = error { Text(error).foregroundColor(.red) }
            ForEach(rows) { camera in
                NavigationLink(camera.title) { CameraDetail(row: camera) }
            }
            if busy { ProgressView() }
            else if rows.isEmpty && error == nil { Text("暂无摄像头") }
            if hasMore && !rows.isEmpty {
                Button("加载更多") { Task { await load(first: false) } }.disabled(busy)
            }
        }
        .navigationTitle("视频监控")
        .task { await load(first: true) }
    }

    private func load(first: Bool) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        error = nil
        if first { page = 0; rows = []; hasMore = false }
        let next = page + 1
        do {
            let raw = try await Net.shared.post("SIPAIIS_Visual/work/camera/getStatusList.do",
                ["unitId": app.unit, "page": String(next), "rows": "30",
                 "sort": "unit_id", "order": "asc", "search_name": query])
            let response = Net.dict(raw)
            guard response["rows"] != nil else { throw APIError.message("服务未返回摄像头列表") }
            let data = Net.array(response, key: "rows")
            let seen = Set(rows.map(\.id))
            let newRows = data.enumerated().map { GenericRow.from($0.element, index: (next-1)*30+$0.offset) }
            rows += newRows.filter { !seen.contains($0.id) }
            page = next
            hasMore = response["total"] == nil ? data.count == 30 : next*30 < Net.int(response, "total")
        } catch { self.error = error.localizedDescription }
    }
}

private struct CameraDetail: View {
    let row: GenericRow
    @State private var player: AVPlayer?

    private var supportedURL: URL? {
        guard let url = URL(string: Net.str(row.raw, "url")),
              url.scheme?.lowercased() == "https",
              ["m3u8", "mp4", "mov"].contains(url.pathExtension.lowercased()) else { return nil }
        return url
    }

    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player).aspectRatio(16/9, contentMode: .fit)
            } else if let url = supportedURL {
                Button("播放") {
                    let newPlayer = AVPlayer(url: url)
                    player = newPlayer
                    newPlayer.play()
                }
            } else {
                Text("此摄像头需要厂商播放器。当前版本支持 HTTPS 的 HLS、MP4 和 MOV 视频。")
                    .foregroundColor(.secondary).padding()
            }
            Spacer()
        }
        .navigationTitle(row.title)
        .onDisappear { player?.pause(); player = nil }
    }
}
