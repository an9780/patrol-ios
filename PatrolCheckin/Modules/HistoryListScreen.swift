import SwiftUI

private enum AbnormalHistoryStatus: String, CaseIterable, Identifiable {
    case all = ""
    case processing = "0"
    case completed = "1"
    case pending = "2"
    case closed = "3"
    case returned = "4"

    var id: Self { self }
    var title: String {
        switch self {
        case .all: return "全部"
        case .processing: return "工单处理中"
        case .completed: return "已完成"
        case .pending: return "待处理"
        case .closed: return "已关闭"
        case .returned: return "已退回"
        }
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published var rows: [[String: Any]] = []
    @Published var loading = false
    @Published var error: String?
    @Published private(set) var hasMore = false
    private var page = 0
    private var requestNumber = 0
    private let pageSize = 20

    func load(unit: String, abnormal: Bool, status: String, nextPage: Bool = false) async {
        guard !nextPage || !loading else { return }
        requestNumber += 1
        let request = requestNumber
        if !nextPage {
            rows = []
            page = 0
            hasMore = false
        }
        loading = true
        error = nil
        defer { if request == requestNumber { loading = false } }
        let requestedPage = nextPage ? page + 1 : 1
        var parameters = ["page": String(requestedPage), "rows": String(pageSize), "search_name": ""]
        let path: String
        if abnormal {
            path = "SIPAIIS_DataCenter/maintenance/abnormity/getList.do"
            parameters["unitId"] = unit
            parameters["pSectionId"] = ""
            parameters["status"] = status
        } else {
            path = "SIPAIIS_Equipment/maintenance/getMDetailList.do"
            parameters["type"] = "3"
            parameters["search_code"] = unit
            parameters["status"] = "1"
        }
        do {
            let raw = try await Net.shared.post(path, parameters)
            try Task.checkCancellation()
            guard request == requestNumber else { return }
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
            if !Task.isCancelled && request == requestNumber { self.error = error.localizedDescription }
        }
    }
}

struct HistoryListScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = HistoryStore()
    @Environment(\.dismiss) private var dismiss
    let abnormal: Bool
    @State private var status: AbnormalHistoryStatus = .all
    @State private var showingStatuses = false

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: abnormal ? "异常记录" : "缺陷记录", back: { dismiss() })

            if abnormal {
                Button {
                    showingStatuses.toggle()
                } label: {
                    Text(status.title)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .overlay(alignment: .trailing) {
                            Image(systemName: showingStatuses ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12)).padding(.trailing, 14)
                        }
                        .foregroundColor(C.text)
                        .background(Color.white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("记录状态")
                .accessibilityValue(status.title)
            }

            ZStack(alignment: .top) {
                records
                if showingStatuses {
                    Color.black.opacity(0.001)
                        .onTapGesture { showingStatuses = false }
                        .accessibilityHidden(true)
                    VStack(spacing: 0) {
                        ForEach(AbnormalHistoryStatus.allCases) { option in
                            Button {
                                showingStatuses = false
                                status = option
                            } label: {
                                Text(option.title)
                                    .foregroundColor(C.text)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(status == option ? .isSelected : [])
                        }
                    }
                    .background(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                }
            }
        }
        .background(C.bg)
        .navigationBarHidden(true)
        .task(id: status) { await reload() }
    }

    @ViewBuilder
    private var records: some View {
        if store.loading && store.rows.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.rows.isEmpty {
            VStack {
                EmptyHint(text: store.error ?? "暂无历史记录")
                if store.error != nil {
                    Button("重试") { Task { await reload() } }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.rows.enumerated()), id: \.offset) { _, d in
                        NavigationLink {
                            HistoryDetailScreen(recordId: Net.str(d, "id"), abnormal: abnormal)
                                .environmentObject(app)
                        } label: {
                            if abnormal {
                                abnormalCard(d)
                            } else {
                                HistoryTaskRow(id: displayNumber(d), status: "已完成", fields: fields(d))
                            }
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

    private func reload(nextPage: Bool = false) async {
        await store.load(unit: app.unit, abnormal: abnormal, status: status.rawValue, nextPage: nextPage)
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

    private func abnormalCard(_ row: [String: Any]) -> some View {
        let unit = Net.str(Net.dict(row["unit"]), "name")
        let section = Net.dict(row["processSection"])
        let shortSection = Net.str(section, "sname")
        let location = shortSection.isEmpty ? Net.str(section, "name") : shortSection
        let reporter = Net.str(Net.dict(row["insertUser"]), "caption")
        let name = reporter.isEmpty ? Net.str(Net.dict(row["submitUser"]), "caption") : reporter
        let time = Net.str(row, "insdt").replacingOccurrences(of: "T", with: " ")
        let displayTime = time.count >= 16 ? String(time.dropFirst(5).prefix(11)) : time
        let description = Net.str(row, "abnormityDescription")
        let remark = Net.str(row, "remark")
        let content = [unit.isEmpty ? app.unitName : unit, location, Net.str(row, "equipmentNames"),
                       description, remark].filter { !$0.isEmpty && $0 != "null" }
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(content.enumerated()), id: \.offset) { _, value in
                    Text(value).foregroundColor(C.text)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)

            HStack {
                Text(displayTime).foregroundColor(C.sub)
                Spacer()
                Text(name).foregroundColor(C.bar)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(Color(hex: 0xEDEDED))
        }
        .font(.system(size: 15))
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
