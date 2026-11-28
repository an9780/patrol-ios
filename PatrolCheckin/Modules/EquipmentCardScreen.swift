import SwiftUI

struct EquipmentCardScreen: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let equipment: [String: Any]

    @State private var tab = 0
    @State private var detail: [String: Any] = [:]
    @State private var detailError: String?
    @State private var loadingDetail = true
    @State private var records: [[String: Any]] = []
    @State private var recordsError: String?
    @State private var loadingRecords = true

    private let equipmentStatuses = ["0": "停用", "1": "在用", "2": "封存", "3": "报废待处理"]
    private let runningStatuses = ["0": "停止", "1": "运行", "2": "故障", "3": "检修"]

    private var equipmentId: String { Net.str(equipment, "id") }

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: "设备详情", back: { dismiss() })
            MonitoringTabs(titles: ["设备详情", "维修记录", "测量点"], selection: $tab)

            ScrollView {
                LazyVStack(spacing: 0) {
                    switch tab {
                    case 0: detailTab
                    case 1: recordTab
                    default: pointTab
                    }
                }
                .padding(.bottom, 20)
            }
            .refreshable { await reload() }
            .background(C.bg)
        }
        .navigationBarHidden(true)
        .task(id: equipmentId) { await reload() }
    }

    private var detailTab: some View {
        let status = field("equipmentstatus")
        let running = field("runningStatus")
        let model = field("equipmentmodelname")
        let configuredType = field("equipmentTypeNumber", "name")
        let properties = equipmentRows("equipmentCardPropList")
        return VStack(spacing: 0) {
            detailRow("设备名称", field("equipmentname"))
            detailRow("设备编号", field("equipmentcardid"))
            detailRow("设备状态", equipmentStatuses[status] ?? status)
            detailRow("运行状态", runningStatuses[running] ?? running)
            detailRow("规格型号", model.isEmpty ? "暂未配置" : model)
            detailRow("ABC分类", field("equipmentLevel", "levelname"))
            detailRow("设备类型", configuredType.isEmpty ? field("equipmentClass", "name") : configuredType)
            detailRow("工艺位置", field("processSection", "name"))
            detailRow("所属厂区", field("unit", "name"))
            ForEach(Array(properties.enumerated()), id: \.offset) { _, property in
                let name = value(property, "propName")
                let reading = value(property, "propValue")
                let unit = value(property, "propUnit")
                if !name.isEmpty {
                    readingRow(name) {
                        Text(reading.isEmpty || unit.isEmpty ? reading + unit : reading + " " + unit)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(label)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 82, alignment: .leading)
                Text(value.isEmpty ? "—" : value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 15))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            Divider().padding(.leading, 14)
        }
        .background(Color.white)
    }

    private var recordTab: some View {
        Group {
            if records.isEmpty {
                listStatus(loading: loadingRecords, error: recordsError, empty: "暂无维修记录")
            } else {
                ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                    VStack(alignment: .leading, spacing: 6) {
                        let problem = value(record, "problemcontent")
                        let result = value(record, "problemresult")
                        Text(problem.isEmpty ? value(record, "contents") : problem)
                        if !result.isEmpty { Text(result).foregroundColor(.secondary) }
                        Text(value(record, "insdt")).font(.caption).foregroundColor(.secondary)
                    }
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.white)
                    Divider().padding(.leading, 14)
                }
            }
        }
    }

    private var pointTab: some View {
        let points = equipmentRows("mPoint4APP").filter { !value($0, "parmname").isEmpty }
        return Group {
            if points.isEmpty {
                listStatus(loading: loadingDetail, error: detailError, empty: "暂无测量点")
            } else {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    let name = value(point, "parmname")
                    let id = value(point, "id")
                    let configuredSignal = value(point, "signalType")
                    let signal = (configuredSignal.isEmpty ? value(point, "signaltype") : configuredSignal).uppercased()
                    let digital = signal == "DI" || signal == "DO"
                    let reading = value(point, "parmvalue")
                    let display = digital || reading.isEmpty ? reading : reading + value(point, "unit")
                    let row = readingRow(name) {
                        PlantReadingValue(name: name, value: display, digital: digital)
                    }
                    if id.isEmpty {
                        row
                    } else {
                        NavigationLink {
                            PointHistoryScreen(pointId: id, pointName: name)
                        } label: {
                            row
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("查看历史曲线")
                    }
                }
            }
        }
    }

    private func readingRow<Reading: View>(_ name: String, @ViewBuilder reading: () -> Reading) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                PlantReadingIcon(name: name)
                Text(name).frame(maxWidth: .infinity, alignment: .leading)
                reading()
            }
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            Divider().padding(.leading, 53)
        }
        .background(Color.white)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func listStatus(loading: Bool, error: String?, empty: String) -> some View {
        if loading {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 36)
        } else {
            EmptyHint(text: error ?? empty)
        }
    }

    private func value(_ row: [String: Any], _ key: String) -> String {
        PlantReadingValue.clean(Net.str(row, key))
    }

    private func field(_ key: String, _ nestedKey: String? = nil) -> String {
        if let nestedKey {
            let updated = value(Net.dict(detail[key]), nestedKey)
            return updated.isEmpty ? value(Net.dict(equipment[key]), nestedKey) : updated
        }
        let updated = value(detail, key)
        return updated.isEmpty ? value(equipment, key) : updated
    }

    private func equipmentRows(_ key: String) -> [[String: Any]] {
        let updated = Net.array(detail, key: key)
        return updated.isEmpty ? Net.array(equipment, key: key) : updated
    }

    private func reload() async {
        async let card: Void = loadDetail()
        async let repair: Void = loadRecords()
        _ = await (card, repair)
    }

    private func loadDetail() async {
        loadingDetail = true
        detailError = nil
        defer { loadingDetail = false }
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/equipment/doview4Id.do", ["id": equipmentId])
            try Task.checkCancellation()
            let root = Net.dict(raw)
            let result = Net.dict(root["result"])
            let payloads: [Any?] = [root["rows"], result["rows"], root["result"], root["data"], raw]
            for payload in payloads {
                let row = Net.array(payload).first ?? Net.dict(payload)
                let returnedId = value(row, "id")
                if returnedId == equipmentId && !returnedId.isEmpty
                    || returnedId.isEmpty && !value(row, "equipmentname").isEmpty {
                    detail = row
                    return
                }
            }
            throw APIError.message(Net.message(raw))
        } catch {
            if !Task.isCancelled { detailError = "测量点加载失败，可下拉重试" }
        }
    }

    private func loadRecords() async {
        loadingRecords = true
        recordsError = nil
        defer { loadingRecords = false }
        do {
            let unitId = value(Net.dict(equipment["unit"]), "id")
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/maintenance/getMaintenanceDetailList.do",
                ["page": "1", "rows": "50", "sort": "id", "type": "2", "order": "desc",
                 "unitId": unitId.isEmpty ? app.unit : unitId, "equipmentId": equipmentId])
            try Task.checkCancellation()
            let root = Net.dict(raw)
            let result = Net.dict(root["result"])
            guard let rows = root["rows"] ?? result["rows"], !(rows is NSNull) else {
                throw APIError.message(Net.message(raw))
            }
            records = Net.array(rows)
        } catch {
            if !Task.isCancelled { recordsError = "维修记录加载失败，可下拉重试" }
        }
    }
}
