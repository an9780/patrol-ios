import SwiftUI

// MARK: - 维保列表（严格照 res/layout/item_maintenance.xml 还原）

@MainActor
final class MaintainStore: ObservableObject {
    @Published var rows: [GenericRow] = []
    @Published var loading = false
    @Published var error: String?

    func load(unit: String, start: Date, end: Date, status: String) async {
        guard !loading else { return }
        guard start <= end else { error = "开始日期应早于结束日期"; return }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd"
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/maintenance/getListMaintenance.do",
                ["page": "1", "rows": "20", "sort": "insdt", "order": "desc",
                 "companyid": unit, "begin_time": format.string(from: start), "end_time": format.string(from: end), "status": status])
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { arr = a }
                else if let r = d["result"] as? [String: Any],
                        let a = r["rows"] as? [[String: Any]] { arr = a }
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

struct MaintainScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = MaintainStore()
    @Environment(\.dismiss) private var dismiss
    @State private var status = ""
    @State private var start = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var end = Date()

    private func reload() async {
        await store.load(unit: app.unit, start: start, end: end, status: status)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(colors: [C.gradStart, C.gradEnd],
                                   startPoint: .leading, endPoint: .trailing)
                    Text("保养工单").font(.system(size: 15)).foregroundColor(.white)
                }
                .frame(height: 50)
                .overlay(alignment: .leading) {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left").foregroundColor(.white).padding(.horizontal)
                    }.accessibilityLabel("返回")
                }
                HStack {
                    DatePicker("开始日期", selection: $start, displayedComponents: .date).labelsHidden()
                    Text("至").foregroundColor(.secondary)
                    DatePicker("结束日期", selection: $end, displayedComponents: .date).labelsHidden()
                }.padding(.vertical, 8)
                Picker("工单状态", selection: $status) {
                    Text("全部").tag("")
                    ForEach(["1", "2", "3"], id: \.self) { value in
                        Text(statusText(value)).tag(value)
                    }
                }.pickerStyle(.menu)
                Button("查询") { Task { await reload() } }.disabled(store.loading)
                if let error = store.error, !store.rows.isEmpty {
                    Text(error).font(.footnote).foregroundColor(.red)
                }

                if store.loading && store.rows.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.rows.isEmpty {
                    EmptyHint(text: store.error ?? "暂无维保工单")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.rows) { r in
                                NavigationLink {
                                    MaintainDetailScreen(maintenanceId: r.id)
                                } label: {
                                    maintainCard(r)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .background(C.bg)
            .navigationBarHidden(true)
            .task { await reload() }
        }
        .navigationViewStyle(.stack)
    }

    private func maintainCard(_ row: GenericRow) -> some View {
        let company = Net.dict(row.raw["company"])
        let name = Net.str(company, "name")
        let date = Net.str(row.raw, "insdt")
        return VStack(alignment: .leading, spacing: 8) {
            Text("编号：" + row.id)
            HStack {
                Text(name.isEmpty ? row.subtitle : name)
                Spacer()
                Text(statusText(row.status)).font(.subheadline)
                    .padding(5).background(C.doingBg).cornerRadius(4)
            }
            if !date.isEmpty { Text("月份：" + String(date.prefix(10))) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func statusText(_ s: String) -> String {
        switch s {
        case "1": return "待处理"
        case "2": return "处理中"
        case "3": return "已完成"
        default:  return s
        }
    }
}
