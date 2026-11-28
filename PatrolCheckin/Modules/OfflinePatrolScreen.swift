import Foundation
import SwiftUI

struct OfflinePatrolScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var snapshot: Snapshot?
    @State private var saving = false
    @State private var error: String?

    private struct Snapshot: Codable {
        let date: String
        let saved: Date
        let shifts: [Shift]
    }

    private func file() throws -> URL {
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                              appropriateFor: nil, create: true)
        let owner = Net.shared.userid
        guard !owner.isEmpty, !app.unit.isEmpty else { throw APIError.message("当前账号缺少单位信息") }
        let identity = try JSONEncoder().encode([owner, app.unit])
        let name = identity.base64EncodedString().replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("patrol-" + name + ".json")
    }

    var body: some View {
        List {
            Section {
                Button(saving ? "正在保存…" : "下载今日任务和点位") { Task { await download() } }
                    .disabled(saving)
                if let error = error { Text(error).foregroundColor(.red) }
                if let value = snapshot {
                    Text("任务日期 " + value.date)
                    Text(value.saved, style: .time)
                }
            }
            if let value = snapshot {
                if value.shifts.isEmpty { Text("该日没有任务") }
                ForEach(value.shifts) { shift in
                    NavigationLink(shift.name) {
                        List(shift.points) { point in
                            VStack(alignment: .leading) { Text(point.name); Text(point.dateLine).font(.caption) }
                        }.navigationTitle(shift.name)
                    }
                }
            } else { Text("本机尚无该账号的任务副本") }
        }
        .navigationTitle("离线巡检")
        .task {
            do {
                let url = try file()
                if FileManager.default.fileExists(atPath: url.path) {
                    snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
                }
            } catch { self.error = error.localizedDescription }
        }
    }

    @MainActor private func download() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        error = nil
        do {
            let destination = try file()
            let date = AppState.today()
            let store = PatrolStore(demonstration: false)
            await store.load(unit: app.unit, date: date)
            if let failure = store.error { throw APIError.message(failure) }
            for id in store.shifts.map(\.id) {
                try Task.checkCancellation()
                try await store.loadDetail(id)
            }
            let value = Snapshot(date: date, saved: Date(), shifts: store.shifts)
            let data = try JSONEncoder().encode(value)
            try data.write(to: destination, options: [.atomic, .completeFileProtection])
            snapshot = value
        } catch { self.error = error.localizedDescription }
    }
}
