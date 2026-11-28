import SwiftUI

// MARK: - 设备卡（照 activity_equ_card.xml + fragment_equ_detail.xml 还原）
// 页签取自 EquCardActivity 构造函数：设备详情 / 维修记录 / 测量点

struct EquipmentCardScreen: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let equipmentId: String
    let equipmentName: String

    @StateObject private var store = DetailStore()
    @State private var tab = 0
    @State private var recordsError: String?
    @State private var records: [[String: Any]] = []
    @State private var points: [[String: Any]] = []
    @State private var loadingOthers = false

    private let gray08 = Color(hex: 0x646363)
    private let grayT = Color(hex: 0xE5E5E5)
    private let tabs = ["设备详情", "维修记录", "测量点"]

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: "设备卡", back: { dismiss() })

            // NavigationTabStrip 40dp
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                    Button { tab = i } label: {
                        VStack(spacing: 0) {
                            Text(t)
                                .font(.system(size: 14))
                                .foregroundColor(tab == i ? C.bar : C.grayText)
                                .frame(maxWidth: .infinity).frame(height: 38)
                            Rectangle()
                                .fill(tab == i ? C.bar : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 40)
            .background(Color.white)

            ScrollView {
                VStack(spacing: 0) {
                    switch tab {
                    case 0:
                        detailTab
                    case 1:
                        recordTab
                    default:
                        pointTab
                    }
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .background(Color(hex: 0xF9F9F9))
        }
        .navigationBarHidden(true)
        .task {
            await store.load(
                path: "SIPAIIS_Equipment/equipment/doview4Id.do",
                params: ["id": equipmentId])
            await loadOthers()
        }
    }

    // 设备详情：15sp 标签 : 15sp 值，40dp 行，0.3dp 分隔线
    private var detailTab: some View {
        Group {
            if store.loading {
                ProgressView().padding(.vertical, 40)
            } else if store.fields.isEmpty {
                EmptyHint(text: store.error ?? "暂无设备详情")
            } else {
                ForEach(Array(store.fields.prefix(14).enumerated()), id: \.offset) { _, f in
                    HStack(spacing: 0) {
                        Text(f.label)
                            .font(.system(size: 15)).foregroundColor(.black)
                            .frame(height: 40, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(f.value)
                            .font(.system(size: 15)).foregroundColor(gray08)
                            .frame(height: 40, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(3)
                    }
                    .padding(.horizontal, 10)
                    .background(Color.white)
                    Rectangle().fill(grayT).frame(height: 0.3)
                }
            }
        }
    }

    // 维修记录
    private var recordTab: some View {
        Group {
            if records.isEmpty {
                Text(loadingOthers ? "加载中…" : (recordsError ?? "暂无维修记录"))
                    .font(.system(size: 14)).foregroundColor(C.grayText)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                ForEach(Array(records.prefix(30).enumerated()), id: \.offset) { _, d in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Net.str(d, "problemcontent").isEmpty
                             ? Net.str(d, "contents") : Net.str(d, "problemcontent"))
                            .font(.system(size: 15)).foregroundColor(.black)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Net.str(d, "insdt"))
                            .font(.system(size: 12)).foregroundColor(C.grayText)
                            .padding(.horizontal, 10).padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.white)
                    .padding(.bottom, 0.3)
                }
            }
        }
    }

    // 测量点
    private var pointTab: some View {
        Group {
            if points.isEmpty {
                Text(loadingOthers ? "加载中…" : "暂无测量点")
                    .font(.system(size: 14)).foregroundColor(C.grayText)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                ForEach(Array(points.enumerated()), id: \.offset) { _, d in
                    MeasurePointRow(
                        name: Net.str(d, "parmname").isEmpty ? Net.str(d, "name") : Net.str(d, "parmname"),
                        value: Net.str(d, "parmvalue"))
                }
            }
        }
    }

    private func loadOthers() async {
        loadingOthers = true
        points = Net.array(store.raw, key: "mPoint4APP")
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/maintenance/getMaintenanceDetailList.do",
                ["page": "1", "rows": "50", "sort": "id", "type": "2",
                 "order": "desc", "unitId": app.unit, "equipmentId": equipmentId])
            records = Net.array(raw, key: "rows")
        } catch {
            recordsError = error.localizedDescription
        }
        loadingOthers = false
    }
}
