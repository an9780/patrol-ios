import SwiftUI

// MARK: - 报警列表（严格照 res/layout/item_alarm.xml 还原）

@MainActor
final class AlarmStore: ObservableObject {
    @Published var rows: [[String: Any]] = []
    @Published var loading = false
    @Published var error: String?

    func load(unit: String) async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/scadaAlarm/getAlarmListByCache.do",
                ["unitId": unit, "page": "1", "rows": "50",
                 "sort": "insdt", "order": "desc",
                 "stdt": "", "eddt": "", "alarmLevel": "",
                 "alarmType": "", "subscription": "", "describe": ""])
            if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { rows = a }
                else if let r = d["result"] as? [String: Any],
                        let a = r["rows"] as? [[String: Any]] { rows = a }
                else { rows = [] }
            } else if let a = raw as? [[String: Any]] {
                rows = a
            } else {
                rows = []
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct AlarmScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = AlarmStore()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(colors: [C.gradStart, C.gradEnd],
                                   startPoint: .leading, endPoint: .trailing)
                    Text("实时报警").font(.system(size: 15)).foregroundColor(.white)
                }
                .frame(height: 50)

                if store.loading && store.rows.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.rows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash").font(.largeTitle)
                            .foregroundColor(C.grayText.opacity(0.6))
                        Text(store.error ?? "暂无报警").font(.system(size: 14))
                            .foregroundColor(C.grayText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.rows.enumerated()), id: \.offset) { _, d in
                                alarmRow(d)
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

    /// 严格照 item_alarm.xml：白底圆角 3、外边距 8/3/8/2、图标 50dp
    private func alarmRow(_ d: [String: Any]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Image("moudle_alarm_logo")
                .resizable().scaledToFit()
                .padding(8)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 0) {
                // 时间 + 状态
                HStack(spacing: 0) {
                    Text(Net.str(d, "insdt"))
                        .font(.system(size: 13))
                        .foregroundColor(C.grayText)
                        .padding(.leading, 8).padding(.trailing, 8)
                        .padding(.top, 8).padding(.bottom, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Net.str(d, "status"))
                        .font(.system(size: 13))
                        .foregroundColor(C.grayText)
                        .padding(.leading, 8).padding(.trailing, 8)
                        .padding(.top, 8).padding(.bottom, 3)
                }

                // 级别 + 类型
                HStack(spacing: 0) {
                    Text(Net.str(d, "alarmLevel"))
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0xE0796C))
                        .padding(.leading, 8).padding(.trailing, 8)
                        .padding(.top, 3).padding(.bottom, 3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Net.str(d, "alarmType"))
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: 0x67686C))
                        .padding(.leading, 8).padding(.trailing, 8)
                        .padding(.top, 3).padding(.bottom, 3)
                }

                // 内容
                Text(Net.str(d, "describe").isEmpty
                     ? Net.str(d, "content") : Net.str(d, "describe"))
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: 0x67686C))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 3).fill(Color.white)
        )
        .padding(.leading, 8).padding(.trailing, 8)
        .padding(.top, 3).padding(.bottom, 2)
    }
}
