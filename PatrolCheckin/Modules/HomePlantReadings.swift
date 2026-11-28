import SwiftUI

struct HomePlantReadings: View {
    let unit: String

    private struct Reading: Identifiable {
        let id = UUID()
        let pointId: String
        let name: String
        let value: String
        let digital: Bool
    }

    private enum Category: String, CaseIterable {
        case quality, flow, instrument, equipment

        var title: String {
            switch self {
            case .quality: return "水质"
            case .flow: return "水量"
            case .instrument: return "仪表"
            case .equipment: return "设备"
            }
        }
    }

    @State private var history: Reading?
    @State private var selection = 0
    @State private var readings: [Category: [Reading]] = [:]
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonitoringTabs(titles: Category.allCases.map(\.title), selection: $selection)
            if loading {
                ProgressView("读取厂区指标").padding(16)
            } else if let error = error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).foregroundColor(.secondary)
                    Button("重试") { Task { await load() } }
                }
                .padding(16)
            } else if let rows = readings[Category.allCases[selection]], !rows.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        Button { history = row } label: {
                            HStack(spacing: 9) {
                                PlantReadingIcon(name: row.name)
                                Text(row.name).foregroundColor(C.text)
                                Spacer(minLength: 12)
                                PlantReadingValue(name: row.name, value: row.value, digital: row.digital)
                            }
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 38)
                    }
                }
                .padding(.horizontal, 14)
            } else {
                Text("暂无指标").foregroundColor(.secondary).padding(16)
            }
        }
        .background(Color.white)
        .task(id: unit) { await load() }
        .fullScreenCover(item: $history) { row in
            PointHistoryScreen(pointId: row.pointId, pointName: row.name)
        }
    }

    private func load() async {
        guard !unit.isEmpty else { return }
        loading = true
        error = nil
        defer { if !Task.isCancelled { loading = false } }
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/zone/getBizWaterDataByFile4GY.do",
                ["unitId": unit, "ng": ""])
            try Task.checkCancellation()
            guard let fields = Net.array(raw).first else {
                throw APIError.message("服务器未返回厂区指标配置")
            }
            var next: [Category: [Reading]] = [:]
            for category in Category.allCases {
                let entries = Net.array(fields, key: category.rawValue)
                let rows: [Reading]
                switch category {
                case .equipment:
                    rows = entries.flatMap { item -> [Reading] in
                        let name = Net.str(item, "name")
                        guard !name.isEmpty else { return [] }
                        return [Reading(pointId: Net.str(item, "runMPointId"), name: name + "运行", value: PlantReadingValue.clean(Net.str(item, "runStatus")), digital: true),
                                Reading(pointId: Net.str(item, "faultMPointId"), name: name + "故障", value: PlantReadingValue.clean(Net.str(item, "faultStatus")), digital: true)]
                    }
                case .instrument:
                    rows = entries.flatMap { item -> [Reading] in
                        let options = Net.array(item, key: "option")
                        if options.isEmpty { return reading(item).map { [$0] } ?? [] }
                        return options.compactMap { reading($0, group: Net.str(item, "name")) }
                    }
                case .quality, .flow:
                    let readings = entries.flatMap { group in
                        let options = Net.array(group, key: "option")
                        return options.compactMap { reading($0, group: Net.str(group, "name")) }
                    }
                    let outflow = readings.filter { $0.name.hasPrefix("出水") }
                    let inflow = readings.filter { $0.name.hasPrefix("进水") }
                    let other = readings.filter { !$0.name.hasPrefix("出水") && !$0.name.hasPrefix("进水") }
                    rows = outflow + inflow + other
                }
                next[category] = rows.filter { !$0.value.isEmpty } + rows.filter { $0.value.isEmpty }
            }
            readings = next
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    private func reading(_ item: [String: Any], group: String = "") -> Reading? {
        let name = PlantReadingValue.clean(Net.str(item, "name"))
        guard !name.isEmpty else { return nil }
        let groupName = PlantReadingValue.clean(group).replacingOccurrences(of: "入水", with: "进水")
        let directions = ["进水", "出水"].filter { groupName.contains($0) }
        let prefix = directions.count == 1 ? directions[0] : groupName
        let nameWithDirection = name.replacingOccurrences(of: "入水", with: "进水")
        let hasDirection = nameWithDirection.contains("进水") || nameWithDirection.contains("出水")
        let title = prefix.isEmpty || nameWithDirection.hasPrefix(prefix) || hasDirection
            ? nameWithDirection : prefix + nameWithDirection
        let raw = PlantReadingValue.clean(Net.str(item, "value"))
        let signal = Net.str(item, "signaltype").uppercased()
        let digital = signal == "DI" || signal == "DO"
        let unit = PlantReadingValue.clean(Net.str(item, "unit"))
        return Reading(pointId: Net.str(item, "mpointId"), name: title, value: digital || raw.isEmpty ? raw : raw + unit, digital: digital)
    }

}

struct PlantReadingValue: View {
    let name: String
    let value: String
    let digital: Bool

    static func clean(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let missing = ["", "-", "--", "—", "null", "<null>", "nan", "n/a"]
        return missing.contains(trimmed.lowercased()) ? "" : trimmed
    }

    private var lamp: Color {
        let alarm = ["故障", "警告", "需维护", "过载", "超时"].contains { name.contains($0) }
        let code = Double(value)
        if alarm { return code == 1 ? .yellow : .gray }
        if code == nil { return .gray }
        return code == 0 || code == -1 ? .red : .green
    }

    var body: some View {
        if digital {
            Circle().fill(lamp).frame(width: 22, height: 22)
                .accessibilityLabel(Text(value.isEmpty ? "无状态" : "状态 " + value))
        } else {
            Text(value.isEmpty ? "—" : value).monospacedDigit().foregroundColor(.secondary)
        }
    }
}

struct PlantReadingIcon: View {
    let name: String

    private var asset: String {
        let text = name.lowercased()
        let types: [(String, [String])] = [
            ("iv_temp", ["温度"]), ("iv_nh3", ["氨氮", "nh3"]),
            ("iv_cod", ["cod"]), ("iv_ph", ["ph"]),
            ("iv_tp", ["总磷", "tp"]), ("iv_tn", ["总氮", "tn"]),
            ("iv_mlss", ["污泥浓度", "mlss"]), ("iv_do", ["溶解氧", "do1", "do2"]),
            ("iv_hz", ["频率", "hz"]), ("iv_airflow", ["风量"]),
            ("iv_flow", ["流量"]), ("iv_liqu", ["液位"]),
            ("iv_ele", ["电流", "电压", "电度表"]), ("iv_pa", ["压力"])
        ]
        return types.first { type in type.1.contains { text.contains($0) } }?.0 ?? "iv_eqp"
    }

    var body: some View {
        Image(asset).resizable().scaledToFit()
            .frame(width: 29, height: 29)
            .accessibilityHidden(true)
    }
}
