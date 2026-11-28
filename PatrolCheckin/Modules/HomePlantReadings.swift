import SwiftUI

struct HomePlantReadings: View {
    let unit: String

    private struct Reading {
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

    @State private var selection = 0
    @State private var readings: [Category: [Reading]] = [:]
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonitoringTabs(titles: Category.allCases.map(\.title), selection: $selection)
            if loading {
                ProgressView("读取厂区指标")
            } else if let error = error {
                Text(error).foregroundColor(.secondary)
                Button("重试") { Task { await load() } }
            } else if let rows = readings[Category.allCases[selection]], !rows.isEmpty {
                ForEach(rows.indices, id: \.self) { index in
                    HStack(spacing: 9) {
                        PlantReadingIcon(name: rows[index].name)
                        Text(rows[index].name)
                        Spacer(minLength: 12)
                        PlantReadingValue(name: rows[index].name, value: rows[index].value, digital: rows[index].digital)
                    }
                    Divider()
                }
            } else {
                Text("暂无指标").foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.white)
        .task(id: unit) { await load() }
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
                next[category] = entries.flatMap { entry -> [Reading] in
                    if category == .equipment {
                        let name = Net.str(entry, "name")
                        guard !name.isEmpty else { return [] }
                        return [Reading(name: name + "运行", value: Net.str(entry, "runStatus"), digital: true),
                                Reading(name: name + "故障", value: Net.str(entry, "faultStatus"), digital: true)]
                    }
                    return Net.array(entry, key: "option").compactMap { item in
                        let name = Net.str(item, "name")
                        guard !name.isEmpty else { return nil }
                        let value = Net.str(item, "value")
                        let digital = Net.str(item, "signaltype") == "DI"
                        return Reading(name: name, value: digital || value.isEmpty ? value : value + Net.str(item, "unit"),
                                       digital: digital)
                    }
                }
            }
            readings = next
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

}

struct PlantReadingValue: View {
    let name: String
    let value: String
    let digital: Bool

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
