import SwiftUI

// MARK: - 维保列表（严格照 res/layout/item_maintenance.xml 还原）

@MainActor
final class MaintainStore: ObservableObject {
    @Published var rows: [GenericRow] = []
    @Published var loading = false
    @Published var error: String?

    func load(unit: String) async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/maintenance/getListMaintenance.do",
                ["page": "1", "rows": "20", "sort": "insdt", "order": "desc",
                 "companyid": unit, "begin_time": "", "end_time": "", "status": ""])
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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(colors: [C.gradStart, C.gradEnd],
                                   startPoint: .leading, endPoint: .trailing)
                    Text("维保工单").font(.system(size: 15)).foregroundColor(.white)
                }
                .frame(height: 50)

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
            .task { await store.load(unit: app.unit) }
        }
        .navigationViewStyle(.stack)
    }

    /// 严格照 item_maintenance.xml
    private func maintainCard(_ r: GenericRow) -> some View {
        VStack(spacing: 0) {
            // 状态 14sp 黑
            HStack(spacing: 0) {
                Text(r.status.isEmpty ? "待处理" : statusText(r.status))
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .padding(.leading, 14).padding(.trailing, 14)
                    .padding(.top, 5).padding(.bottom, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 分隔线 0.2 #A3A1A1
            Rectangle().fill(Color(hex: 0xA3A1A1)).frame(height: 0.2)

            // 问题描述
            VStack(alignment: .leading, spacing: 0) {
                Text("问题描述")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0x858585))
                    .padding(.leading, 5).padding(.trailing, 5).padding(.top, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(r.title)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 9).padding(.trailing, 9)

            // 维修结果
            VStack(alignment: .leading, spacing: 0) {
                Text("维修结果")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0x858585))
                    .padding(.leading, 5).padding(.trailing, 5).padding(.top, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(r.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, 9).padding(.trailing, 9)
        }
        .background(
            RoundedRectangle(cornerRadius: 3).fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        )
        .padding(5)
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
