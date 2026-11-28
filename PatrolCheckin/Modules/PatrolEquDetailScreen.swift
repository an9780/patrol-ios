import SwiftUI

// MARK: - 设备巡检卡（照 activity_patrol_equ_detail.xml 三段落还原）
// 段落：手工抄录项 / 巡检内容 / 抄表

@MainActor
final class PatrolEquStore: ObservableObject {
    @Published var handItems: [[String: Any]] = []
    @Published var contentItems: [[String: Any]] = []
    @Published var meterItems: [[String: Any]] = []
    @Published var loading = false
    @Published var error: String?

    func load(equipmentId: String) async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getEquPointByEquId.do",
                ["equipmentId": equipmentId])
            var arr: [[String: Any]] = []
            if let a = raw as? [[String: Any]] { arr = a }
            else if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { arr = a }
                else if let r = d["result"] as? [String: Any],
                        let a = r["rows"] as? [[String: Any]] { arr = a }
            }
            // 按 type 分流：1 手工抄录 / 2 巡检内容 / 3 抄表（无 type 默认归巡检内容）
            handItems = []
            meterItems = []
            contentItems = []
            for d in arr {
                switch Net.str(d, "type") {
                case "1": handItems.append(d)
                case "3": meterItems.append(d)
                default:  contentItems.append(d)
                }
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
                    if store.loading && store.contentItems.isEmpty && store.handItems.isEmpty && store.meterItems.isEmpty {
                        ProgressView().padding(.vertical, 40)
                    } else if store.contentItems.isEmpty && store.handItems.isEmpty && store.meterItems.isEmpty {
                        Text(store.error ?? "暂无巡检项")
                            .font(.system(size: 14)).foregroundColor(C.grayText)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else {
                        // 段落一：手工抄录项
                        if !store.handItems.isEmpty {
                            section("手工抄录项", store.handItems)
                        }
                        // 段落二：巡检内容
                        if !store.contentItems.isEmpty {
                            section("巡检内容", store.contentItems)
                        }
                        // 段落三：抄表
                        if !store.meterItems.isEmpty {
                            section("抄表", store.meterItems)
                        }
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

    /// 段落标题 15sp 黑、高 40；内容白卡
    private func section(_ title: String, _ items: [[String: Any]]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 15)).foregroundColor(.black)
                    .frame(height: 40, alignment: .center)
                Spacer()
            }
            .padding(.horizontal, 10)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, d in
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text(Net.str(d, "pointName").isEmpty
                                 ? Net.str(d, "name") : Net.str(d, "pointName"))
                                .font(.system(size: 15)).foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(Net.str(d, "value").isEmpty
                                 ? Net.str(d, "status") : Net.str(d, "value"))
                                .font(.system(size: 13)).foregroundColor(C.grayText)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 10)
                        Rectangle().fill(Color(hex: 0x9FA2A3)).frame(height: 0.3)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(3)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }
}
