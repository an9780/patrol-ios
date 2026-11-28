import SwiftUI

struct ProductionMonitoringScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var tab = 0
    @State private var sectionCode = ""
    @State private var signal = ""
    @State private var sections: [FormOption] = []
    @State private var points: [Reading] = []
    @State private var page = 0
    @State private var more = false
    @State private var loading = false
    @State private var error: String?

    private struct Reading: Identifiable {
        let id: String
        let name: String
        let value: String
        let digital: Bool
    }

    var body: some View {
        NavigationView {
            VStack {
                MonitoringTabs(titles: ["集控监视", "所有点"], selection: $tab)
                if tab == 0 {
                    SectionTreeScreen()
                } else {
                    HStack {
                        Picker("工艺段", selection: $sectionCode) {
                            Text("全部工艺段").tag("")
                            ForEach(sections) { section in Text(section.name).tag(section.id) }
                        }
                        .accessibilityLabel("工艺段")
                        Spacer()
                        Picker("信号类型", selection: $signal) {
                            Text("全部信号").tag("")
                            Text("模拟量").tag("AI")
                            Text("开关量").tag("DI")
                        }
                        .accessibilityLabel("信号类型")
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(Color(uiColor: .systemGray6))
                    .disabled(loading)
                    List {
                        if let error = error {
                            Text(error).foregroundColor(.red)
                            Button("重试") { Task { await load(page: 1) } }
                        } else if points.isEmpty && !loading {
                            Text("暂无测点").foregroundColor(.secondary)
                        }
                        ForEach(points) { point in
                            NavigationLink {
                                PointHistoryScreen(pointId: point.id, pointName: point.name)
                            } label: {
                                HStack {
                                    Text(point.name)
                                    Spacer()
                                    PlantReadingValue(name: point.name, value: point.value, digital: point.digital)
                                }
                            }
                        }
                        if loading { ProgressView() }
                        if more && !loading {
                            Button("加载更多") { Task { await load(page: page + 1) } }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await load(page: 1) }
                    .onChange(of: sectionCode) { _ in Task { await load(page: 1) } }
                    .onChange(of: signal) { _ in Task { await load(page: 1) } }
                    .task { if page == 0 { await load(page: 1) } }
                }
            }
            .task { await loadSections() }
            .navigationTitle("生产监视")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private func load(page requestedPage: Int) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getMPointByProcessSection4APP.do",
                ["bizid": app.unit, "processSectionCode": sectionCode,
                 "page": String(requestedPage), "rows": "20", "sort": "ParmName", "signaltype": signal])
            try Task.checkCancellation()
            let root = Net.dict(raw)
            let result = Net.dict(root["result"])
            guard let records = root["rows"] ?? result["rows"] ?? root["result"], !(records is NSNull) else {
                throw APIError.message("服务未返回测点列表")
            }
            let rows = Net.array(records)
            if requestedPage == 1 { points = [] }
            var ids = Set(points.map(\.id))
            for row in rows {
                let id = Net.str(row, "id")
                guard !id.isEmpty, ids.insert(id).inserted else { continue }
                let name = Net.str(row, "parmname")
                let value = Net.str(row, "parmvalue")
                let digital = Net.str(row, "signaltype") == "DI"
                points.append(Reading(id: id, name: name.isEmpty ? id : name,
                                      value: digital || value.isEmpty ? value : value + Net.str(row, "unit"),
                                      digital: digital))
            }
            page = requestedPage
            more = rows.count == 20
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    private func loadSections() async {
        do {
            let raw = try await Net.shared.post("SIPAIIS_DataCenter/work/processSection/getlist.do",
                ["unitId": app.unit, "page": "1", "rows": "1000"])
            sections = Net.array(raw, key: "rows").compactMap { row in
                let code = Net.str(row, "code")
                let name = Net.str(row, "name")
                guard !code.isEmpty, !name.isEmpty else { return nil }
                return FormOption(id: code, name: name)
            }
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}



struct MonitoringTabs: View {
    let titles: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(titles.indices, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    VStack(spacing: 0) {
                        Text(titles[index])
                            .foregroundColor(index == selection ? C.blue : .secondary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                        Capsule()
                            .fill(index == selection ? C.blue : Color.clear)
                            .frame(height: 3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(index == selection ? .isSelected : [])
            }
        }
        .background(Color.white)
    }
}
