import SwiftUI

// MARK: - 设备卡（照 activity_equ_card.xml + fragment_equ_detail.xml 还原）

struct EquipmentCardScreen: View {
    @EnvironmentObject var app: AppState
    let equipmentId: String
    let equipmentName: String

    @StateObject private var store = DetailStore()
    @State private var tab = 0

    private let gray08 = Color(hex: 0x646363)
    private let grayT = Color(hex: 0xE5E5E5)
    private let tabs = ["设备信息"]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("设备卡").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

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
                    if store.fields.isEmpty {
                        ProgressView().padding(.vertical, 40)
                    } else {
                        ForEach(Array(store.fields.prefix(12).enumerated()), id: \.offset) { _, f in
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
                    Spacer(minLength: 20)
                }
                .padding(.top, 8)
            }
            .background(Color(hex: 0xF9F9F9))
        }
        .navigationBarHidden(true)
        .task {
            await store.load(
                path: "SIPAIIS_Equipment/equipment/getEquipmentById.do",
                params: ["id": equipmentId, "unitId": app.unit])
        }
    }
}
