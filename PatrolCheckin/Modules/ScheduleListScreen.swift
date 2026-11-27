import SwiftUI

// MARK: - 排班列表（照 activity_schedule_sheet_list.xml + item_schedule_sheet.xml）

@MainActor
final class ScheduleListStore: ObservableObject {
    @Published var rows: [[String: Any]] = []
    @Published var loading = false
    @Published var error: String?

    func load(unit: String, keyword: String) async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processAdjustment/getlist.do",
                ["unitId": unit, "page": "1", "rows": "50",
                 "sort": "insdt", "order": "desc", "searchName": keyword])
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { arr = a }
                else if let r = d["result"] as? [String: Any],
                        let a = r["rows"] as? [[String: Any]] { arr = a }
            } else if let a = raw as? [[String: Any]] { arr = a }
            rows = arr
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct ScheduleListScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = ScheduleListStore()
    @State private var keyword = ""

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("排班管理").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            // 搜索框 36dp（bg_white_all 圆角 6）
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Color.white)
                HStack(spacing: 0) {
                    Image("moudle_search")
                        .resizable().scaledToFit()
                        .padding(8).frame(width: 36, height: 36)
                    TextField("", text: $keyword)
                        .font(.system(size: 14))
                        .padding(.leading, 9).padding(.trailing, 8)
                        .onSubmit { Task { await store.load(unit: app.unit, keyword: keyword) } }
                }
            }
            .frame(height: 36)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if store.loading && store.rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.rows.isEmpty {
                EmptyHint(text: store.error ?? "暂无排班")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.rows.enumerated()), id: \.offset) { _, d in
                            NavigationLink {
                                ScheduleDetailScreen(scheduleId: Net.str(d, "id"))
                                    .environmentObject(app)
                            } label: {
                                card(d)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .background(C.bg)
            }
        }
        .navigationBarHidden(true)
        .task { await store.load(unit: app.unit, keyword: "") }
    }

    /// item_schedule_sheet.xml
    private func card(_ d: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Image("moudle_flow")
                    .resizable().scaledToFit()
                    .padding(.leading, 10).padding(.vertical, 6)
                    .frame(width: 28, height: 28)
                Text(Net.str(d, "typeName").isEmpty ? "排班" : Net.str(d, "typeName"))
                    .font(.system(size: 14)).foregroundColor(.black)
                    .padding(.leading, 8).padding(.trailing, 8)
                    .padding(.vertical, 5)
                    .frame(height: 30, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Net.str(d, "status"))
                    .font(.system(size: 14)).foregroundColor(.black)
                    .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 5)
            }
            Text(Net.str(Net.dict(d["targetCompany"]), "sname"))
                .font(.system(size: 14)).foregroundColor(.black)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Net.str(d, "contents"))
                .font(.system(size: 16)).foregroundColor(.black)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(Net.str(d, "insdt"))
                .font(.system(size: 14)).foregroundColor(.black)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: 0x2E59F7), lineWidth: 0.5))
        .padding(.horizontal, 5).padding(.vertical, 3)
    }
}
