import SwiftUI

struct PatrolPointDataScreen: View {
    let point: Point
    let shiftID: String
    let unit: String
    @State private var equipment: [Row] = []
    @State private var contents: [Row] = []
    @State private var readings: [Row] = []
    @State private var busy = true

    private struct Row: Identifiable {
        let id: Int
        let title: String
        let detail: String
    }

    var body: some View {
        List {
            Section {
                Text(point.name)
                if !point.area.isEmpty { Text(point.area) }
                Text(point.dateLine)
            }
            if busy { ProgressView("正在读取点位数据") }
            else {
                section("设备与测点", equipment)
                section("巡检内容", contents)
                section("自动采集测点", readings)
            }
        }
        .navigationTitle("巡检点详情")
        .task { await load() }
        .refreshable { await load() }
    }

    private func section(_ title: String, _ rows: [Row]) -> some View {
        Section(header: Text(title)) {
            if rows.isEmpty { Text("暂无数据").foregroundColor(.secondary) }
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                    if !row.detail.isEmpty {
                        Text(row.detail).font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func load() async {
        busy = true
        defer { busy = false }
        let reference = ["patrolRecordId": shiftID, "patrolPointId": point.id]
        let group = "SIPAIIS_Patrol/timeEfficiency/"
        async let devices = fetch(group + "patrolRecord/getEquipmentByPatrolPoint4APP.do",
                                  reference.merging(["unitId": unit]) { original, _ in original },
                                  name: "equipmentName") { item in
            Net.array(item, key: "measurePoints").map {
                [Net.str($0, "parmName"), Net.str($0, "parmValue"), Net.str($0, "unit")]
                    .filter { !$0.isEmpty }.joined(separator: " ")
            }.joined(separator: "\n")
        }
        async let checks = fetch(group + "patrolContentsRecord/getPatrolContents4APP.do",
                                 reference.merging(["type": point.kind ?? "", "equipmentId": ""]) { original, _ in original },
                                 name: "contents") { item in
            [Net.str(item, "contentsDetail"), Net.str(item, "status")].filter { !$0.isEmpty }.joined(separator: " · ")
        }
        async let sensors = fetch(group + "patrolPoint/getMPoint4APP.do",
                                  ["patrolPointId": point.id, "unitId": unit, "type": "auto"],
                                  name: "parmname") { item in
            [Net.str(item, "parmvalue"), Net.str(item, "unit")].filter { !$0.isEmpty }.joined(separator: " ")
        }
        (equipment, contents, readings) = await (devices, checks, sensors)
    }

    private func fetch(_ path: String, _ params: [String: String], name: String,
                       details: ([String: Any]) -> String) async -> [Row] {
        do {
            let raw = try await Net.shared.post(path, params)
            guard let result = Net.dict(raw)["result"], !(result is NSNull) else {
                throw APIError.message("服务没有返回此类数据")
            }
            return Net.array(result).enumerated().map { index, item in
                let title = Net.str(item, name)
                return Row(id: index, title: title.isEmpty ? "第 \(index + 1) 项" : title, detail: details(item))
            }
        } catch {
            return [Row(id: -1, title: "读取失败", detail: error.localizedDescription)]
        }
    }
}

