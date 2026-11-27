import SwiftUI

// MARK: - 异常处理（严格照 res/layout/fragment_fault.xml 还原）

enum FaultTab: String, CaseIterable, Identifiable {
    case abnormity    = "异常上报"
    case repairTask   = "检修工单"
    case maintainTask = "维修工单"
    case dispose      = "异常处置"
    case dispatch     = "调度单"

    var id: String { rawValue }

    var path: String {
        switch self {
        case .abnormity:    return "SIPAIIS_DataCenter/maintenance/abnormity/getList.do"
        case .repairTask:   return "SIPAIIS_Equipment/maintenance/getTaskList.do"
        case .maintainTask: return "SIPAIIS_Equipment/maintenance/getTaskList.do"
        case .dispose:      return "SIPAIIS_Equipment/maintenance/getTaskList.do"
        case .dispatch:     return "SIPAIIS_DataCenter/work/processAdjustment/getTaskList.do"
        }
    }

    /// 照 j5/a.smali 里的真实参数
    func params(unit: String, search: String) -> [String: String] {
        switch self {
        case .abnormity:
            return ["unitId": unit, "page": "1", "rows": "20"]
        case .repairTask:
            return ["page": "1", "rows": "20", "searchName": search,
                    "sort": "insdt", "order": "desc", "searchType": "1"]
        case .maintainTask:
            return ["page": "1", "rows": "20", "searchName": search,
                    "sort": "insdt", "order": "desc", "searchType": "2"]
        case .dispose:
            return ["page": "1", "rows": "20", "searchName": search,
                    "sort": "insdt", "order": "desc", "searchType": "3"]
        case .dispatch:
            return ["page": "1", "rows": "20", "sort": "insdt",
                    "order": "desc", "taskIds": ""]
        }
    }
}

@MainActor
final class FaultStore: ObservableObject {
    @Published var rows: [GenericRow] = []
    @Published var loading = false
    @Published var error: String?
    @Published var loaded = false

    func load(tab: FaultTab, unit: String, search: String) async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(tab.path, tab.params(unit: unit, search: search))
            rows = FaultStore.rows(from: raw)
        } catch {
            self.error = error.localizedDescription
            rows = []
        }
        loading = false
        loaded = true
    }

    static func rows(from raw: Any) -> [GenericRow] {
        var arr: [[String: Any]] = []
        if let a = raw as? [[String: Any]] {
            arr = a
        } else if let d = raw as? [String: Any] {
            for k in ["content1", "result", "rows", "list", "data"] {
                if let a = d[k] as? [[String: Any]] { arr = a; break }
                if let sub = d[k] as? [String: Any],
                   let a = sub["rows"] as? [[String: Any]] { arr = a; break }
            }
        }
        return arr.enumerated().map { GenericRow.from($0.element, index: $0.offset) }
    }
}

struct FaultScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = FaultStore()
    @State private var tab: FaultTab = .abnormity
    @State private var search = ""
    @State private var showHistory = false
    @State private var showReport = false

    private let grad = LinearGradient(colors: [C.gradStart, C.gradEnd],
                                      startPoint: .leading, endPoint: .trailing)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ── 标题栏：bg_title 渐变，50dp ──
                ZStack {
                    grad
                    HStack(spacing: 0) {
                        Color.clear.frame(maxWidth: .infinity)
                        Text("异常处理")
                            .font(.system(size: 15)).foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                        Button("历史记录") { showHistory = true }
                            .font(.system(size: 13)).foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 50)

                // ── 搜索行：padding 16 ──
                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(Color.white)
                        HStack(spacing: 0) {
                            Spacer().frame(width: 12)
                            Image("moudle_search")
                                .resizable().scaledToFit()
                                .padding(8)
                                .frame(width: 36, height: 36)
                            TextField("", text: $search)
                                .font(.system(size: 14))
                                .padding(.leading, 9)
                                .padding(.trailing, 8)
                                .onSubmit { Task { await reload() } }
                        }
                    }
                    .frame(height: 36)
                    .padding(.trailing, 28)

                    Button("异常上报") { showReport = true }
                        .font(.system(size: 12)).foregroundColor(C.bar)
                        .frame(width: 90, height: 32)
                        .background(Color(hex: 0xEBF5FE))
                        .cornerRadius(4)
                }
                .padding(16)

                // ── 5 个页签：横向滚动，34dp 白色胶囊 ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FaultTab.allCases) { t in
                            Button {
                                tab = t
                                Task { await reload() }
                            } label: {
                                Text(t.rawValue)
                                    .font(.system(size: 14))
                                    .foregroundColor(tab == t ? .white : Color(hex: 0x6179FF))
                                    .padding(.horizontal, 18)
                                    .frame(height: 34)
                                    .background(tab == t ? Color(hex: 0x6179FF) : Color.white)
                                    .cornerRadius(17)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 35)

                // ── 列表区：左右 9，上 8 ──
                if tab == .dispatch {
                    DispatchScreen().environmentObject(app)
                } else if store.loading && store.rows.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(C.bg)
                } else if store.rows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray").font(.largeTitle)
                            .foregroundColor(C.grayText.opacity(0.6))
                        Text(store.error ?? "暂无工单")
                            .font(.system(size: 14)).foregroundColor(C.grayText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(C.bg)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(store.rows) { r in
                                NavigationLink {
                                    destination(for: r)
                                } label: {
                                    faultRow(r)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 9)
                        .padding(.trailing, 9)
                        .padding(.top, 8)
                    }
                    .background(C.bg)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showReport) {
                NavigationView { FaultReportScreen().environmentObject(app) }
            }
            .sheet(isPresented: $showHistory) {
                NavigationView {
                    GenericListScreen(
                        title: "历史记录",
                        path: "SIPAIIS_Equipment/maintenance/getMDetailList.do",
                        buildParams: { ["unitId": app.unit, "page": "1", "rows": "50", "type": "3"] }
                    )
                    .environmentObject(app)
                    .navigationTitle("历史记录")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { showHistory = false }
                        }
                    }
                }
            }
            .task { await reload() }
        }
        .navigationViewStyle(.stack)
    }

    private func faultRow(_ r: GenericRow) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(r.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(C.text).lineLimit(2)
                if !r.subtitle.isEmpty {
                    Text(r.subtitle).font(.system(size: 12)).foregroundColor(C.sub)
                }
            }
            Spacer()
            if !r.status.isEmpty {
                Text(statusText(r.status))
                    .font(.system(size: 12)).foregroundColor(C.bar)
                    .padding(.horizontal, 10).frame(height: 22)
                    .background(C.doingBg).cornerRadius(11)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
    }

    private func statusText(_ s: String) -> String {
        switch s {
        case "1": return "进行中"
        case "2": return "已完成"
        case "3": return "已关闭"
        default:  return s
        }
    }

    @ViewBuilder
    private func destination(for r: GenericRow) -> some View {
        switch tab {
        case .abnormity:
            FaultDetailScreen(abnormalId: r.id)
        case .dispose, .repairTask, .maintainTask:
            FaultAuditScreen(taskId: r.id, businessId: r.id)
        default:
            FaultDetailScreen(abnormalId: r.id)
        }
    }

    private func reload() async {
        await store.load(tab: tab, unit: app.unit, search: search)
    }
}
