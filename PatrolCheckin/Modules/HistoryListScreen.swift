import SwiftUI

// MARK: - 历史任务（照 item_history_task_log.xml 还原）

@MainActor
final class HistoryStore: ObservableObject {
    @Published var rows: [[String: Any]] = []
    @Published var loading = false
    @Published var error: String?
    @Published private(set) var hasMore = false
    private var page = 0
    private let pageSize = 20

    func load(unit: String, abnormal: Bool, nextPage: Bool = false) async {
        guard !loading else { return }
        loading = true
        error = nil
        defer { loading = false }
        let requestedPage = nextPage ? page + 1 : 1
        var parameters = ["page": String(requestedPage), "rows": String(pageSize), "search_name": ""]
        let path: String
        if abnormal {
            path = "SIPAIIS_DataCenter/maintenance/abnormity/getList.do"
            parameters["unitId"] = unit
            parameters["pSectionId"] = ""
            parameters["status"] = "0"
        } else {
            path = "SIPAIIS_Equipment/maintenance/getMDetailList.do"
            parameters["type"] = "3"
            parameters["search_code"] = unit
            parameters["status"] = "1"
        }
        do {
            let raw = try await Net.shared.post(path, parameters)
            try Task.checkCancellation()
            let root = Net.dict(raw)
            let nested = Net.dict(root["result"])
            guard let result = root["rows"] ?? nested["rows"] ?? (raw as? [[String: Any]]) else {
                throw APIError.message("服务未返回历史记录")
            }
            let received = Net.array(result)
            if nextPage { rows.append(contentsOf: received) }
            else { rows = received }
            page = requestedPage
            let total = max(Net.int(root, "total"), Net.int(nested, "total"))
            hasMore = !received.isEmpty && (total > 0 ? page * pageSize < total : received.count == pageSize)
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}

struct HistoryListScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = HistoryStore()
    @Environment(\.dismiss) private var dismiss
    let abnormal: Bool

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: abnormal ? "异常记录" : "缺陷记录", back: { dismiss() })

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
                                HistoryDetailScreen(recordId: Net.str(d, "id"), abnormal: abnormal)
                                    .environmentObject(app)
                            } label: {
                                HistoryTaskRow(
                                    id: displayNumber(d),
                                    status: abnormal ? statusText(Net.str(d, "status")) : "已完成",
                                    fields: fields(d))
                            }
                            .buttonStyle(.plain)
                            .disabled(Net.str(d, "id").isEmpty)
                        }
                        if store.loading { ProgressView().padding() }
                        if let error = store.error {
                            Text(error).font(.footnote).foregroundColor(C.sub)
                        }
                        if store.hasMore && !store.loading {
                            Button("加载更多") { Task { await reload(nextPage: true) } }
                                .padding(10)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(C.bg)
                .refreshable { await reload() }
            }
        }
        .navigationBarHidden(true)
        .task { await reload() }
    }

    private func reload(nextPage: Bool = false) async {
        await store.load(unit: app.unit, abnormal: abnormal, nextPage: nextPage)
    }

    private func displayNumber(_ row: [String: Any]) -> String {
        let number = Net.str(row, "detailNumber")
        return number.isEmpty ? Net.str(row, "id") : number
    }

    private func fields(_ row: [String: Any]) -> [(String, String)] {
        let content = Net.str(row, abnormal ? "abnormityDescription" : "problemcontent")
        let time = Net.str(row, "insdt").replacingOccurrences(of: "T", with: " ")
        let company = Net.str(Net.dict(row["company"]), "name")
        let result = Net.str(row, abnormal ? "remark" : "problemresult")
        return [
            ("所属单位", company.isEmpty ? app.unitName : company),
            ("发起时间", String(time.prefix(16))),
            ("问题描述", content),
            ("处理内容", result.isEmpty && !abnormal ? content : result)
        ].filter { !$0.1.isEmpty }
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
