import SwiftUI

// MARK: - 异常处理（对接原版 5 个工单页签）

enum FaultTab: String, CaseIterable, Identifiable {
    case abnormity = "异常上报"
    case repairTask = "检修工单"
    case maintainTask = "维修工单"
    case dispose = "异常处置"
    case dispatch = "调度单"

    var id: String { rawValue }

    var path: String {
        switch self {
        case .abnormity:   return "SIPAIIS_DataCenter/maintenance/abnormity/getList.do"
        case .repairTask:  return "SIPAIIS_Equipment/maintenance/getTaskList.do"
        case .maintainTask: return "SIPAIIS_Equipment/maintenance/getMaintenanceTaskList.do"
        case .dispose:     return "SIPAIIS_Equipment/maintenance/getMDetailList.do"
        case .dispatch:    return "SIPAIIS_DataCenter/work/processAdjustment/getlist.do"
        }
    }

    func params(unit: String, search: String) -> [String: String] {
        var p: [String: String] = ["unitId": unit, "page": "1", "rows": "50"]
        if !search.isEmpty {
            p["search_name"] = search
            p["search_code"] = search
        }
        switch self {
        case .abnormity:
            p["status"] = ""
        case .repairTask:
            p["sort"] = "insdt"; p["order"] = "desc"
        case .maintainTask:
            p["sort"] = "insdt"; p["order"] = "desc"
        case .dispose:
            p["type"] = "3"
        case .dispatch:
            p["sort"] = "insdt"; p["order"] = "desc"
        }
        return p
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
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                for k in ["content1", "result", "rows", "list", "data"] {
                    if let a = d[k] as? [[String: Any]], !a.isEmpty { arr = a; break }
                }
            } else if let a = raw as? [[String: Any]] {
                arr = a
            }
            rows = arr.enumerated().map { GenericRow.from($0.element, index: $0.offset) }
        } catch {
            self.error = error.localizedDescription
            rows = []
        }
        loading = false
        loaded = true
    }
}

struct FaultScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = FaultStore()
    @State private var tab: FaultTab = .abnormity
    @State private var search = ""
    @State private var showHistory = false
    @State private var showReport = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 蓝色标题栏
                HStack {
                    Spacer()
                    Text("异常处理")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button("历史记录") { showHistory = true }
                        .font(.system(size: 13)).foregroundColor(.white)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(C.blue)

                // 搜索 + 上报
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(C.sub).font(.system(size: 14))
                        TextField("搜索工单", text: $search)
                            .font(.system(size: 14))
                            .onSubmit { Task { await reload() } }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.white).cornerRadius(6)

                    Button("异常上报") { showReport = true }
                        .font(.system(size: 13)).foregroundColor(C.blue)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white).cornerRadius(6)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(C.blue)

                // 页签
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FaultTab.allCases) { t in
                            Button {
                                tab = t
                                Task { await reload() }
                            } label: {
                                Text(t.rawValue)
                                    .font(.system(size: 13, weight: tab == t ? .semibold : .regular))
                                    .foregroundColor(tab == t ? .white : C.blue)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(tab == t ? C.blue : Color.white)
                                    .cornerRadius(15)
                            }
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                }
                .background(C.bg)

                // 列表
                if tab == .dispatch {
                    DispatchScreen()
                        .environmentObject(app)
                } else if store.loading {
                    ProgressView().padding(.top, 80)
                    Spacer()
                } else if store.rows.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray.circle")
                            .font(.system(size: 54))
                            .foregroundColor(C.blue.opacity(0.25))
                        Text("暂无工单")
                            .font(.system(size: 15)).foregroundColor(C.blue.opacity(0.6))
                        if let e = store.error {
                            Text(e).font(.caption).foregroundColor(.red)
                                .padding(.horizontal, 30).multilineTextAlignment(.center)
                        }                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(C.bg)
                } else {
                    LoadableList(items: store.rows, empty: "暂无工单") { r in
                        NavigationLink {
                            destination(for: r)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Rectangle().fill(C.blue).frame(width: 4)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(r.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(C.text).lineLimit(2)
                                    if !r.subtitle.isEmpty {
                                        Text(r.subtitle)
                                            .font(.system(size: 12)).foregroundColor(C.sub)
                                    }
                                }
                                Spacer()
                                if !r.status.isEmpty {
                                    StatusPill(text: r.status, color: C.sub)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11)).foregroundColor(C.sub)
                            }
                            .padding(11).background(Color.white).cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showReport) {
                NavigationView {
                    FaultReportScreen().environmentObject(app)
                }
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
