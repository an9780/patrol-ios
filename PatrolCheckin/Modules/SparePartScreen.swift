import SwiftUI

// MARK: - 备件（照 res/layout/item_equ_part.xml 还原）

struct SparePartRow: View {
    let name: String
    @Binding var quantity: String
    @Binding var checked: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("名称：")
                        .font(.system(size: 13)).foregroundColor(Color(hex: 0x858585))
                    Text(name)
                        .font(.system(size: 14)).foregroundColor(.black)
                        .padding(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 0) {
                    Text("数量：")
                        .font(.system(size: 13)).foregroundColor(Color(hex: 0x858585))
                    VStack(spacing: 0) {
                        TextField("", text: $quantity)
                            .font(.system(size: 14))
                            .keyboardType(.numberPad)
                            .padding(5)
                            .frame(height: 28)
                        Rectangle().fill(C.grayText).frame(height: 1)
                    }
                    .frame(height: 29)
                }
                .frame(maxWidth: .infinity)

                Toggle("", isOn: $checked)
                    .labelsHidden()
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
    }
}

@MainActor
final class SparePartStore: ObservableObject {
    @Published var rows: [[String: Any]] = []
    @Published var loading = false
    @Published var error: String?

    func load(unit: String) async {
        loading = true
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/sparepart/goodsClass/search.do",
                ["unit_id": unit, "name": "", "page": "1", "rows": "100"])
            if let a = raw as? [[String: Any]] { rows = a }
            else if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { rows = a }
                else if let r = d["result"] as? [String: Any],
                        let a = r["rows"] as? [[String: Any]] { rows = a }
            }
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

struct SparePartScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = SparePartStore()
    @State private var qty: [Int: String] = [:]
    @State private var picked: Set<Int> = []

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("备件").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            if store.loading && store.rows.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.rows.isEmpty {
                EmptyHint(text: store.error ?? "暂无备件")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(store.rows.enumerated()), id: \.offset) { idx, d in
                            SparePartRow(
                                name: Net.str(d, "name"),
                                quantity: Binding(
                                    get: { qty[idx] ?? "" },
                                    set: { qty[idx] = $0 }),
                                checked: Binding(
                                    get: { picked.contains(idx) },
                                    set: { if $0 { picked.insert(idx) } else { picked.remove(idx) } }))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(C.bg)
            }
        }
        .navigationBarHidden(true)
        .task { await store.load(unit: app.unit) }
    }
}
