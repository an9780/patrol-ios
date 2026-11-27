import SwiftUI

// MARK: - 历史任务（照 item_history_task_log.xml 还原）

@MainActor
final class HistoryStore: ObservableObject {
    @Published var rows: [[String: Any]] = []
    @Published var loading = false
    @Published var error: String?

    func load(unit: String) async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/maintenance/getMDetailList.do",
                ["unitId": unit, "page": "1", "rows": "50", "type": "3"])
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { arr = a }
                else if let r = d["result"] as? [String: Any],
                        let a = r["rows"] as? [[String: Any]] { arr = a }
            } else if let a = raw as? [[String: Any]] {
                arr = a
            }
            rows = arr
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct HistoryListScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = HistoryStore()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("历史任务").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            if store.loading && store.rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.rows.isEmpty {
                EmptyHint(text: store.error ?? "暂无历史任务")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.rows.enumerated()), id: \.offset) { _, d in
                            HistoryTaskRow(
                                id: Net.str(d, "id"),
                                status: statusText(Net.str(d, "status")),
                                fields: fields(d))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(C.bg)
            }
        }
        .navigationBarHidden(true)
        .task { await store.load(unit: app.unit) }
    }

    private func fields(_ d: [String: Any]) -> [(String, String)] {
        var out: [(String, String)] = []
        let ps = Net.str(Net.dict(d["processSection"]), "name")
        if !ps.isEmpty { out.append(("所属点位", ps)) }
        let eq = Net.str(d, "equipmentName")
        if !eq.isEmpty { out.append(("设备名称", eq)) }
        let content = Net.str(d, "problemcontent")
        if !content.isEmpty { out.append(("问题内容", content)) }
        let result = Net.str(d, "problemresult")
        if !result.isEmpty { out.append(("处理结果", result)) }
        let t = Net.str(d, "insdt")
        if !t.isEmpty { out.append(("提交时间", t)) }
        return out
    }

    private func statusText(_ s: String) -> String {
        switch s {
        case "1": return "待处理"
        case "2": return "处理中"
        case "3": return "已完成"
        default:  return s.isEmpty ? "已完成" : s
        }
    }
}
