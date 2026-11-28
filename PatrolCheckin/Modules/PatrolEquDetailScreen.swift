import SwiftUI

// MARK: - 设备巡检卡（照 res/layout/activity_patrol_equ_detail.xml 结构还原）

@MainActor
final class PatrolEquStore: ObservableObject {
    @Published var items: [[String: Any]] = []
    @Published var loading = false
    @Published var error: String?

    func load(equipmentId: String) async {
        loading = true
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getEquPointByEquId.do",
                ["equipmentId": equipmentId])
            if let a = raw as? [[String: Any]] { items = a }
            else if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { items = a }
                else if let r = d["result"] as? [String: Any],
                        let a = r["rows"] as? [[String: Any]] { items = a }
            }
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct PatrolEquDetailScreen: View {
    @EnvironmentObject var app: AppState
    let equipmentId: String
    let equipmentName: String

    @StateObject private var store = PatrolEquStore()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text(equipmentName.isEmpty ? "设备巡检卡" : equipmentName)
                    .font(.system(size: 15)).foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(height: 50)

            ScrollView {
                VStack(spacing: 0) {
                    // 巡检内容（标题 15sp 黑，40dp）
                    HStack(spacing: 0) {
                        Text("巡检内容")
                            .font(.system(size: 15)).foregroundColor(.black)
                            .frame(height: 40, alignment: .center)
                        Spacer()
                    }
                    .padding(.horizontal, 10)

                    if store.loading && store.items.isEmpty {
                        ProgressView().padding(.vertical, 40)
                    } else if store.items.isEmpty {
                        Text(store.error ?? "暂无巡检项")
                            .font(.system(size: 14)).foregroundColor(C.grayText)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.items.enumerated()), id: \.offset) { _, d in
                                itemRow(d)
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(3)
                        .padding(.horizontal, 10)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 6)
            }
            .background(Color(hex: 0xF9F9F9))
        }
        .navigationBarHidden(true)
        .task { await store.load(equipmentId: equipmentId) }
    }

    /// 巡检项行：名称 15sp 黑 + 状态
    private func itemRow(_ d: [String: Any]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(Net.str(d, "pointName").isEmpty
                     ? Net.str(d, "name") : Net.str(d, "pointName"))
                    .font(.system(size: 15)).foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Net.str(d, "status"))
                    .font(.system(size: 13)).foregroundColor(C.grayText)
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
            Rectangle().fill(Color(hex: 0x9FA2A3)).frame(height: 0.3)
        }
    }
}
