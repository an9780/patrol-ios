import SwiftUI

struct ProductionMonitoringScreen: View {
    @EnvironmentObject private var app: AppState
    @State private var tab = 0
    @State private var groups: [FormOption] = []
    @State private var group = ""
    @State private var centralPoints: [Reading] = []
    @State private var centralLoading = false
    @State private var centralError: String?
    @State private var sectionCode = ""
    @State private var signal = ""
    @State private var sections: [FormOption] = []
    @State private var points: [Reading] = []
    @State private var page = 0
    @State private var more = false
    @State private var loading = false
    @State private var error: String?
    @State private var sectionError: String?
    @State private var requestNumber = 0
    @State private var sectionsLoaded = false

    private struct PointFilter: Equatable {
        let unit: String
        let section: String
        let signal: String
    }

    private var filter: PointFilter {
        PointFilter(unit: app.unit, section: sectionCode, signal: signal)
    }

    private struct Reading: Identifiable {
        let id: String
        let name: String
        let value: String
        let digital: Bool
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                BlueHeader(title: "生产监视")
                MonitoringTabs(titles: ["集控监视", "所有点"], selection: $tab)
                if tab == 0 {
                    centralMonitoring
                } else {
                    HStack(spacing: 0) {
                        Picker("工艺段", selection: $sectionCode) {
                            if sections.isEmpty { Text("工艺段").tag("") }
                            ForEach(sections) { section in Text(section.name).tag(section.id) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .accessibilityLabel("工艺段")
                        .frame(maxWidth: .infinity)
                        Divider().frame(height: 22)
                        Picker("信号类型", selection: $signal) {
                            Text("全部信号").tag("")
                            ForEach(["AI", "DI", "AO", "DO"], id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .accessibilityLabel("信号类型")
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(Color(uiColor: .systemGray6))
                    .disabled(!sectionsLoaded)
                    List {
                        if let sectionError = sectionError {
                            Text(sectionError).foregroundColor(.red)
                            Button("重试读取工艺段") { Task { await loadSections() } }
                        }
                        if let error = error {
                            Text(error).foregroundColor(.red)
                            Button("重试") { Task { await load(page: 1) } }
                        } else if sectionsLoaded && points.isEmpty && !loading {
                            Text("暂无测点").foregroundColor(.secondary)
                        }
                        ForEach(points) { point in
                            readingLink(point)
                        }
                        if loading { ProgressView() }
                        if more && !loading {
                            Button("加载更多") { Task { await load(page: page + 1) } }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await load(page: 1) }
                    .task(id: filter) { await load(page: 1) }
                }
            }
            .task(id: app.unit) {
                async let allPointOptions: Void = loadSections()
                async let centralOptions: Void = loadGroups()
                _ = await (allPointOptions, centralOptions)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private var centralMonitoring: some View {
        VStack(spacing: 0) {
            Picker("监视范围", selection: $group) {
                if groups.isEmpty { Text("暂无监视范围").tag("") }
                ForEach(groups) { item in Text(item.name).tag(item.id) }
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(Color(uiColor: .systemGray6))
            List {
                if centralLoading { ProgressView() }
                if let error = centralError {
                    Text(error).foregroundColor(.secondary)
                    Button("重试") { Task { await loadGroups() } }
                } else if !centralLoading && centralPoints.isEmpty {
                    Text("暂无测点").foregroundColor(.secondary)
                }
                ForEach(centralPoints) { readingLink($0) }
            }
            .listStyle(.plain)
            .refreshable { await loadGroupPoints() }
        }
        .task(id: group) { await loadGroupPoints() }
    }

    private func readingLink(_ point: Reading) -> some View {
        NavigationLink {
            PointHistoryScreen(pointId: point.id, pointName: point.name)
        } label: {
            HStack(spacing: 9) {
                PlantReadingIcon(name: point.name)
                Text(point.name)
                Spacer()
                PlantReadingValue(name: point.name, value: point.value, digital: point.digital)
            }
            .frame(minHeight: 38)
        }
    }

    private func loadGroups() async {
        centralError = nil
        do {
            let response = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/scadaPic/getlist4Combo.do",
                ["companyId": app.unit, "type": "1"])
            try Task.checkCancellation()
            groups = Net.array(response).compactMap { item in
                let id = Net.str(item, "id")
                let name = Net.str(item, "text")
                guard !id.isEmpty, !name.isEmpty else { return nil }
                return FormOption(id: id, name: name)
            }
            let newGroup = groups.contains { $0.id == group } ? group : groups.first?.id ?? ""
            if group == newGroup { await loadGroupPoints() }
            else { group = newGroup }
        } catch {
            if !Task.isCancelled { centralError = error.localizedDescription }
        }
    }

    private func loadGroupPoints() async {
        let requestedGroup = group
        guard !requestedGroup.isEmpty else {
            centralPoints = []
            centralLoading = false
            return
        }
        centralLoading = true
        centralError = nil
        defer { if requestedGroup == group { centralLoading = false } }
        do {
            let response = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/scadaPic/getMPointList.do",
                ["companyId": app.unit, "pid": requestedGroup])
            try Task.checkCancellation()
            guard requestedGroup == group else { return }
            centralPoints = Net.array(response).compactMap { item in
                makeReading(Net.dict(item["mPoint"]))
            }
        } catch {
            if !Task.isCancelled { centralError = error.localizedDescription }
        }
    }

    private func makeReading(_ row: [String: Any], sectionName: String = "") -> Reading? {
        let id = Net.str(row, "id")
        guard !id.isEmpty else { return nil }
        let name = Net.str(row, "parmname").replacingOccurrences(of: "入水", with: "进水")
        let location = sectionName.replacingOccurrences(of: "入水", with: "进水")
        let direction = ["进水", "出水"].filter { location.contains($0) }
        let label = direction.count == 1 && !name.contains("进水") && !name.contains("出水") && !name.isEmpty
            ? direction[0] + name : name
        let value = PlantReadingValue.clean(Net.str(row, "parmvalue"))
        let kind = Net.str(row, "signaltype")
        let signalType = (kind.isEmpty ? Net.str(row, "signalType") : kind).uppercased()
        let digital = signalType == "DI" || signalType == "DO"
        return Reading(id: id, name: label.isEmpty ? id : label,
                       value: digital || value.isEmpty ? value : value + PlantReadingValue.clean(Net.str(row, "unit")),
                       digital: digital)
    }

    private func load(page requestedPage: Int) async {
        let current = filter
        guard !current.section.isEmpty, requestedPage == 1 || !loading else { return }
        requestNumber += 1
        let request = requestNumber
        if requestedPage == 1 {
            points = []
            page = 0
            more = false
        }
        loading = true
        defer { if requestNumber == request { loading = false } }
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getMPointByProcessSection4APP.do",
                ["bizid": current.unit, "processSectionCode": current.section,
                 "page": String(requestedPage), "rows": "20", "sort": "ParmName", "signaltype": current.signal])
            try Task.checkCancellation()
            guard requestNumber == request, filter == current else { return }
            let root = Net.dict(raw)
            let result = Net.dict(root["result"])
            let payload = result["list"] ?? result["rows"] ?? root["rows"] ?? root["result"] ?? raw
            guard let rows = Net.objectRows(payload) else {
                throw APIError.message("服务未返回测点列表")
            }
            let sectionName = sections.first { $0.id == current.section }?.name ?? ""
            var ids = Set(points.map(\.id))
            let decoded = rows.compactMap { makeReading($0, sectionName: sectionName) }
            for point in decoded where ids.insert(point.id).inserted {
                points.append(point)
            }
            page = requestedPage
            let total = Net.int(result, "total")
            more = !rows.isEmpty && (total > 0 ? requestedPage * 20 < total : rows.count == 20)
        } catch {
            if !Task.isCancelled && requestNumber == request { self.error = error.localizedDescription }
        }
    }

    private func loadSections() async {
        sectionError = nil
        sectionsLoaded = false
        do {
            let raw = try await Net.shared.post("SIPAIIS_DataCenter/work/processSection/getlist.do",
                ["unitId": app.unit, "page": "1", "rows": "1000"])
            try Task.checkCancellation()
            let root = Net.dict(raw)
            let records = root["rows"] ?? Net.dict(root["result"])["rows"] ?? root["result"] ?? raw
            guard let rows = Net.objectRows(records) else {
                throw APIError.message("服务未返回工艺段列表")
            }
            sections = rows.compactMap { row in
                let code = Net.str(row, "code")
                let name = Net.str(row, "name")
                guard !code.isEmpty, !name.isEmpty else { return nil }
                return FormOption(id: code, name: name)
            }
            if !sections.contains(where: { $0.id == sectionCode }) {
                sectionCode = sections.first?.id ?? ""
            }
            sectionsLoaded = true
            if sections.isEmpty { sectionError = "后台未返回可用工艺段。" }
        } catch {
            if !Task.isCancelled { sectionError = error.localizedDescription }
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
