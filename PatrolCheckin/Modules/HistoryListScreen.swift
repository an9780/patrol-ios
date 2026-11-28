import SwiftUI

// MARK: - 历史任务（照 item_history_task_log.xml 还原）

@MainActor
final class HistoryStore: ObservableObject {
    @Published var rows: [[String: Any]] = []
    @Published var loading = false
    @Published var error: String?

    func load(unit: String, abnormal: Bool, keyword: String) async {
        loading = true
        error = nil
        rows = []
        defer { if !Task.isCancelled { loading = false } }
        do {
            let path = abnormal ? "SIPAIIS_DataCenter/maintenance/abnormity/getList.do"
                : "SIPAIIS_Equipment/maintenance/getMDetailList.do"
            var parameters = ["unitId": unit, "page": "1", "rows": "50", "search_name": keyword,
                              "pSectionId": ""]
            if abnormal {
                parameters["status"] = "0"
            } else {
                parameters["type"] = "3"
                parameters["search_code"] = ""
            }
            let raw = try await Net.shared.post(path, parameters)
            try Task.checkCancellation()
            let root = Net.dict(raw)
            let nested = Net.dict(root["result"])
            guard let result = root["rows"] ?? nested["rows"] ?? (raw as? [[String: Any]]) else {
                throw APIError.message("服务未返回历史记录")
            }
            rows = Net.array(result)
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}

struct HistoryListScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = HistoryStore()
    @Environment(\.dismiss) private var dismiss
    @State private var category = 0
    @State private var query = ""
    @State private var submittedQuery = ""

    private struct Request: Equatable {
        let unit: String
        let category: Int
        let query: String
    }

    private var request: Request {
        Request(unit: app.unit, category: category, query: submittedQuery)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("历史记录").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)
            .overlay(alignment: .leading) {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left").foregroundColor(.white).frame(width: 44, height: 44)
                }.accessibilityLabel("返回")
            }
            HStack {
                TextField("搜索历史记录", text: $query)
                    .submitLabel(.search)
                    .onSubmit { submittedQuery = query }
                Button("搜索") { submittedQuery = query }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            MonitoringTabs(titles: ["维修记录", "异常记录"], selection: $category)

            if store.loading && store.rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.rows.isEmpty {
                EmptyHint(text: store.error ?? "暂无历史任务")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.rows.enumerated()), id: \.offset) { _, d in
                            NavigationLink {
                                HistoryDetailScreen(recordId: Net.str(d, "id"), abnormal: category == 1)
                                    .environmentObject(app)
                            } label: {
                                HistoryTaskRow(
                                    id: Net.str(d, "id"),
                                    status: statusText(Net.str(d, "status")),
                                    fields: fields(d))
                            }
                            .buttonStyle(.plain)
                            .disabled(Net.str(d, "id").isEmpty)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(C.bg)
            }
        }
        .navigationBarHidden(true)
        .task(id: request) {
            let current = request
            await store.load(unit: current.unit, abnormal: current.category == 1, keyword: current.query)
        }
    }

    private func fields(_ d: [String: Any]) -> [(String, String)] {
        var out: [(String, String)] = []
        let ps = Net.str(Net.dict(d["processSection"]), "name")
        if !ps.isEmpty { out.append(("所属点位", ps)) }
        let eq = Net.str(d, "equipmentNames").isEmpty ? Net.str(d, "equipmentName") : Net.str(d, "equipmentNames")
        if !eq.isEmpty { out.append(("设备名称", eq)) }
        let content = Net.str(d, category == 1 ? "abnormityDescription" : "problemcontent")
        if !content.isEmpty { out.append(("问题内容", content)) }
        let result = Net.str(d, category == 1 ? "remark" : "problemresult")
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
