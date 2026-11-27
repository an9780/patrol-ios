import SwiftUI

// MARK: - 通用列表引擎
// 其余模块的返回结构未逐一实测，这里按常见字段名做容错渲染。
// 字段优先级：name / describe / title / content / problemcontent / label

struct GenericRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let status: String
    let raw: [String: Any]

    static func from(_ d: [String: Any], index: Int) -> GenericRow {
        func pick(_ keys: [String]) -> String {
            for k in keys where !Net.str(d, k).isEmpty { return Net.str(d, k) }
            return ""
        }
        let title = pick(["name", "describe", "title", "problemcontent", "content",
                          "mpointName", "partsName", "label", "cameraName", "dictLabel"])
        let sub = pick(["unitName", "pSectionName", "processSectionName", "equipmentName",
                        "insdt", "begin_time", "stdt", "createTime", "remark"])
        let st = pick(["status", "state", "alarmLevel", "passstatus"])
        let rid = pick(["id", "taskId", "maintenanceId", "alarmId", "recordId"])
        return GenericRow(id: rid.isEmpty ? "row-\(index)" : rid,
                          title: title.isEmpty ? "记录 \(index + 1)" : title,
                          subtitle: sub, status: st, raw: d)
    }
}

@MainActor
final class GenericListStore: ObservableObject {
    @Published var rows: [GenericRow] = []
    @Published var loading = false
    @Published var error: String?

    func load(path: String, params: [String: String], resultKeys: [String]) async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(path, params)
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                for k in resultKeys {
                    if let a = d[k] as? [[String: Any]] { arr = a; break }
                }
                if arr.isEmpty, let a = d["rows"] as? [[String: Any]] { arr = a }
            } else if let a = raw as? [[String: Any]] {
                arr = a
            }
            rows = arr.enumerated().map { GenericRow.from($0.element, index: $0.offset) }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct GenericListScreen: View {
    let title: String
    let path: String
    var buildParams: () -> [String: String]
    var resultKeys: [String] = ["content1", "result", "rows", "list", "data"]

    @EnvironmentObject var app: AppState
    @StateObject private var store = GenericListStore()

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: title,
                       subtitle: app.caption,
                       trailing: AnyView(Button {
                           Task { await reload() }
                       } label: {
                           Image(systemName: "arrow.clockwise").foregroundColor(.white)
                       }))
            if store.loading {
                ProgressView().padding(.top, 60); Spacer()
            } else if let e = store.error, store.rows.isEmpty {
                EmptyHint(text: e)
            } else {
                LoadableList(items: store.rows, empty: "暂无数据") { r in
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle().fill(C.cyan).frame(width: 4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.title).font(.system(size: 15, weight: .medium))
                                .foregroundColor(C.text).lineLimit(2)
                            if !r.subtitle.isEmpty {
                                Text(r.subtitle).font(.system(size: 12)).foregroundColor(C.sub)
                            }
                        }
                        Spacer()
                        if !r.status.isEmpty { StatusPill(text: "状态 \(r.status)", color: C.sub) }
                    }
                    .padding(11)
                    .background(Color.white).cornerRadius(6)
                }
            }
        }
        .navigationBarHidden(true)
        .task { await reload() }
    }

    private func reload() async {
        await store.load(path: path, params: buildParams(), resultKeys: resultKeys)
    }
}

// MARK: - 维保模块

struct MaintainScreen: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationView {
            GenericListScreen(
                title: "设备维保",
                path: "SIPAIIS_Equipment/maintenance/getMaintenanceTaskList.do",
                buildParams: {
                    ["page": "1", "rows": "50", "sort": "insdt", "order": "desc"]
                }
            )
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 报警模块


// MARK: - 更多

struct MoreEntry: Identifiable {
    let title: String
    let icon: String
    let path: String
    var id: String { title }
}

struct MoreScreen: View {
    @EnvironmentObject var app: AppState

    private let items: [MoreEntry] = [
        MoreEntry(title: "设备查询", icon: "magnifyingglass",
                  path: "SIPAIIS_Equipment/equipment/getList.do"),
        MoreEntry(title: "排班管理", icon: "calendar",
                  path: "SIPAIIS_DataCenter/work/processAdjustment/getlist.do"),
        MoreEntry(title: "知识库", icon: "book",
                  path: "SIPAIIS_LIBRARY/knowledgeType/tree"),
        MoreEntry(title: "设备台账", icon: "square.stack.3d.up",
                  path: "SIPAIIS_Equipment/equipment/getList.do"),
        MoreEntry(title: "测点历史", icon: "chart.line.uptrend.xyaxis",
                  path: "SIPAIIS_DataCenter/work/mpoint/getlist.do"),
        MoreEntry(title: "工艺段", icon: "point.3.connected.trianglepath.dotted",
                  path: "SIPAIIS_DataCenter/work/processSection/getlist.do"),
        MoreEntry(title: "历史任务", icon: "clock.arrow.circlepath",
                  path: "SIPAIIS_Equipment/maintenance/getMDetailList.do"),
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                BlueHeader(title: "更多", subtitle: "\(app.caption) · \(app.unit)")
                List {
                    Section(header: Text("业务模块")) {
                        ForEach(items) { item in
                            NavigationLink {
                                if item.title == "设备查询" {
                                    EquipmentSearchScreen()
                                } else if item.title == "知识库" {
                                    KnowledgeTreeScreen()
                                } else if item.title == "工艺段" {
                                    SectionTreeScreen()
                                } else {
                                    GenericListScreen(
                                        title: item.title, path: item.path,
                                        buildParams: {
                                            ["unitId": app.unit, "page": "1", "rows": "50"]
                                        }
                                    )
                                }
                            } label: {
                                Label(item.title, systemImage: item.icon)
                            }
                        }
                    }
                    Section(header: Text("系统")) {
                        NavigationLink {
                            SettingsScreen()
                        } label: {
                            Label("设置", systemImage: "gearshape")
                        }
                        NavigationLink {
                            ScheduleCreateScreen()
                        } label: {
                            Label("新建调度", systemImage: "plus.circle")
                        }
                    }
                    Section(header: Text("接口总览")) {
                        NavigationLink("已接入 \(Endpoints.all.count) 个接口") {
                            EndpointListScreen()
                        }
                    }
                    Section {
                        Button("退出登录", role: .destructive) { app.logout() }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

struct EndpointListScreen: View {
    var body: some View {
        List {
            ForEach(Endpoints.grouped) { group in
                Section(header: Text("\(group.title)（\(group.items.count)）")) {
                    ForEach(group.items, id: \.path) { e in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(e.path.split(separator: "/").last.map(String.init) ?? e.path)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(C.text)
                                if e.verified {
                                    Text("已验证").font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Color.green.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                            if !e.params.isEmpty {
                                Text(e.params.joined(separator: ", "))
                                    .font(.system(size: 10)).foregroundColor(C.sub)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("接口清单")
    }
}
