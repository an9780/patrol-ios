import SwiftUI
import UIKit

// MARK: - 流程节点选择（转下一节点）
// 接口：SIPAIIS_Base/activiti/workflow/getRoutesForSelect2.do { id, taskId, passFlag }

struct RouteOption: Identifiable {
    let id: String
    let name: String
}

struct RoutePickerSheet: View {
    let taskId: String
    let businessId: String
    let pass: Bool
    var onConfirm: (RouteOption?, [FormOption]) -> Void

    @Environment(\.presentationMode) private var presentation
    @State private var routes: [RouteOption] = []
    @State private var users: [FormOption] = []
    @State private var selectedRoute: RouteOption?
    @State private var selectedUsers: Set<String> = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if loading {
                    ProgressView().padding(.top, 50); Spacer()
                } else if routes.isEmpty {
                    EmptyHint(text: error ?? "没有可选节点，可直接提交")
                    Spacer()
                } else {
                    List {
                        Section(header: Text("下一节点")) {
                            ForEach(routes) { r in
                                Button {
                                    selectedRoute = r
                                    Task { await loadUsers(route: r) }
                                } label: {
                                    HStack {
                                        Text(r.name).foregroundColor(C.text)
                                        Spacer()
                                        if selectedRoute?.id == r.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(C.blue)
                                        }
                                    }
                                }
                            }
                        }
                        if !users.isEmpty {
                            Section(header: Text("选择处理人")) {
                                ForEach(users) { u in
                                    Button {
                                        if selectedUsers.contains(u.id) { selectedUsers.remove(u.id) }
                                        else { selectedUsers.insert(u.id) }
                                    } label: {
                                        HStack {
                                            Text(u.name).foregroundColor(C.text)
                                            Spacer()
                                            if selectedUsers.contains(u.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(C.blue)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }

                Button {
                    onConfirm(selectedRoute, users.filter { selectedUsers.contains($0.id) })
                    presentation.wrappedValue.dismiss()
                } label: {
                    Text(selectedRoute == nil ? "不指定节点，直接提交" : "确认转交")
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(C.blue).foregroundColor(.white)
                }
            }
            .background(C.bg)
            .navigationTitle(pass ? "通过并转交" : "驳回并转交")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { presentation.wrappedValue.dismiss() }
                }
            }
            .task { await loadRoutes() }
        }
    }

    private func loadRoutes() async {
        loading = true
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Base/activiti/workflow/getRoutesForSelect2.do",
                ["id": businessId, "taskId": taskId, "passFlag": pass ? "true" : "false"])
            var arr: [[String: Any]] = []
            if let a = raw as? [[String: Any]] { arr = a }
            else if let d = raw as? [String: Any] {
                for k in ["result", "rows", "data", "list"] {
                    if let a = d[k] as? [[String: Any]] { arr = a; break }
                    if let sub = d[k] as? [String: Any],
                       let a = sub["rows"] as? [[String: Any]] { arr = a; break }
                }
            }
            routes = arr.compactMap {
                let id = Net.str($0, "id")
                let name = Net.str($0, "name")
                guard !id.isEmpty else { return nil }
                return RouteOption(id: id, name: name.isEmpty ? id : name)
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func loadUsers(route: RouteOption) async {
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Base/user/getUnitForTree_User.do",
                ["taskId": taskId, "processInstanceId": "", "unitId": ""])
            var arr: [[String: Any]] = []
            if let a = raw as? [[String: Any]] { arr = a }
            else if let d = raw as? [String: Any] {
                for k in ["result", "rows", "data"] {
                    if let a = d[k] as? [[String: Any]] { arr = a; break }
                }
            }
            users = flattenUsers(arr)
        } catch {
            users = []
        }
    }

    /// 树形结果拍平，只取 type == "U" 的节点
    private func flattenUsers(_ nodes: [[String: Any]]) -> [FormOption] {
        var out: [FormOption] = []
        func walk(_ list: [[String: Any]]) {
            for n in list {
                if Net.str(n, "type") == "U" {
                    let id = Net.str(n, "id")
                    let label = Net.str(n, "label")
                    if !id.isEmpty {
                        out.append(FormOption(id: id, name: label.isEmpty ? id : label))
                    }
                }
                if let ch = n["children"] as? [[String: Any]] { walk(ch) }
            }
        }
        walk(nodes)
        return out
    }
}

// MARK: - 维保填报
// 接口：SIPAIIS_Equipment/maintenance/insetMaintenanceDetailNoFlow.do

struct MaintainFillScreen: View {
    @EnvironmentObject var app: AppState
    let maintenanceId: String

    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var requirement = ""
    @State private var equipmentName = ""
    @State private var showGoods = false
    @State private var manName = ""
    @State private var cost = ""
    @State private var busy = false
    @State private var msg: String?
    @Environment(\.presentationMode) private var presentation

    private let grayT = Color(hex: 0xE5E5E5)

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("维保填报").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            ScrollView {
                VStack(spacing: 0) {
                    rowDate("*开始时间：", $startTime)
                    thin
                    rowDate("*预计完成：", $endTime)
                    thin

                    // 工作要求
                    VStack(alignment: .leading, spacing: 0) {
                        Text("工作要求")
                            .font(.system(size: 15)).foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ZStack(alignment: .topLeading) {
                            if requirement.isEmpty {
                                Text("请填写工作要求")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: 0xC7C7CD))
                                    .padding(5)
                            }
                            TextEditor(text: $requirement)
                                .font(.system(size: 15))
                                .padding(2)
                                .frame(height: 100)
                        }
                        .overlay(Rectangle().stroke(Color(hex: 0xE9E9E9), lineWidth: 1))
                    }
                    .padding(.vertical, 6)

                    Button { showGoods = true } label: {
                        rowText("*选择设备：", equipmentName.isEmpty ? "请选择设备" : equipmentName)
                    }
                    .buttonStyle(.plain)
                    rowText("*维保人：", manName.isEmpty ? "请选择维保人" : manName)

                    HStack(spacing: 0) {
                        Text("*计划费用：")
                            .font(.system(size: 15)).foregroundColor(.black)
                            .frame(height: 40, alignment: .center)
                        TextField("单位：元", text: $cost)
                            .font(.system(size: 15))
                            .keyboardType(.decimalPad)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .layoutPriority(3)
                    }
                    .frame(height: 40)

                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if busy { ProgressView().tint(.white) }
                            Text(busy ? "提交中…" : "提 交")
                                .font(.system(size: 19)).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(C.blue).cornerRadius(3)
                    }
                    .padding(.top, 14)

                    if let m = msg {
                        Text(m).font(.system(size: 12)).foregroundColor(.red)
                            .padding(.top, 8)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
            }
            .background(Color(hex: 0xF9F9F9))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showGoods) {
            GoodsPickerScreen { g in
                equipmentName = g.name
            }
            .environmentObject(app)
        }
        .task { manName = app.caption }
    }

    private var thin: some View {
        Rectangle().fill(grayT).frame(height: 0.3)
    }

    private func rowDate(_ label: String, _ binding: Binding<Date>) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 15)).foregroundColor(.black)
                .frame(height: 40, alignment: .center)
            DatePicker("", selection: binding, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(3)
        }
        .frame(height: 40)
    }

    private func rowText(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 15)).foregroundColor(.black)
                .frame(height: 40, alignment: .center)
            Text(value)
                .font(.system(size: 15)).foregroundColor(Color(hex: 0x646363))
                .frame(height: 40, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(3)
        }
        .frame(height: 40)
    }

    private func submit() async {
        busy = true
        msg = nil
        do {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/maintenance/saveMaintenanceChild.do",
                ["maintenanceId": maintenanceId,
                 "unitId": app.unit,
                 "startTime": f.string(from: startTime),
                 "endTime": f.string(from: endTime),
                 "requirement": requirement,
                 "cost": cost,
                 "maintenanceMan": manName])
            if Net.isOK(raw) {
                app.show("维保填报成功 ✓")
                presentation.wrappedValue.dismiss()
            } else {
                msg = Net.message(raw)
            }
        } catch {
            msg = error.localizedDescription
        }
        busy = false
    }
}



// MARK: - 新建排班
// 接口：processAdjustment/dostart.do { id }

struct ScheduleCreateScreen: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var plants: [FormOption] = []
    @State private var reviewers: [FormOption] = []
    @State private var types: [FormOption] = []
    @State private var plant = ""
    @State private var reviewer = ""
    @State private var type = ""
    @State private var level = "1"
    @State private var start: Date?
    @State private var end: Date?
    @State private var content = ""
    @State private var loadingOptions = true
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: "调度单申请", back: { if !busy { dismiss() } })
            ScrollView {
                VStack(spacing: 8) {
                    optionsRow("调度厂区", options: plants, selection: $plant)
                        .background(Color.white)
                    VStack(spacing: 0) {
                        optionsRow("调度类型", options: types, selection: $type)
                        Divider()
                        optionsRow("调度等级", options: (1...3).map {
                            FormOption(id: String($0), name: "\($0)级")
                        }, selection: $level)
                        Divider()
                        dateRow("开始日期", selection: $start)
                        Divider()
                        dateRow("结束日期", selection: $end)
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("调度内容：")
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $content)
                                    .frame(minHeight: 92)
                                    .accessibilityLabel("调度内容")
                                if content.isEmpty {
                                    Text("填写调度内容").foregroundColor(C.sub)
                                        .padding(.leading, 5).padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .padding(12)
                        Divider()
                        optionsRow("审核人", options: reviewers, selection: $reviewer)
                    }
                    .background(Color.white)
                    Button {
                        Task { await submit() }
                    } label: {
                        Text(busy ? "提交中…" : "提 交")
                            .font(.system(size: 19)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(C.blue).cornerRadius(4)
                    }
                    .disabled(busy || loadingOptions)
                    .padding(.horizontal, 12).padding(.top, 14)
                    if loadingOptions { ProgressView() }
                    if let message = message {
                        Text(message).font(.footnote).foregroundColor(.red)
                    }
                }
                .font(.system(size: 15))
                .padding(8)
            }
        }
        .background(C.bg)
        .navigationBarHidden(true)
        .interactiveDismissDisabled(busy)
        .task { await loadOptions() }
    }

    private func optionsRow(_ title: String, options: [FormOption], selection: Binding<String>) -> some View {
        HStack {
            Text(title + "：").frame(width: 104, alignment: .leading)
            Menu {
                ForEach(options) { option in
                    Button(option.name) { selection.wrappedValue = option.id }
                }
            } label: {
                HStack {
                    Text(options.first { $0.id == selection.wrappedValue }?.name ?? "点击选择")
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12))
                }
                .foregroundColor(C.sub)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .disabled(options.isEmpty)
        }
        .padding(.horizontal, 12)
    }

    private func dateRow(_ title: String, selection: Binding<Date?>) -> some View {
        HStack {
            Text(title + "：").frame(width: 104, alignment: .leading)
            DatePicker(title, selection: Binding(
                get: { selection.wrappedValue ?? Date() },
                set: { selection.wrappedValue = $0 }
            ), displayedComponents: .date)
            .labelsHidden()
            .overlay {
                if selection.wrappedValue == nil {
                    Text("点击选择").foregroundColor(C.sub)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                        .allowsHitTesting(false)
                }
            }
            Spacer()
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 12)
    }

    private func loadOptions() async {
        loadingOptions = true
        defer { loadingOptions = false }
        do {
            async let plantData = Net.shared.get("SIPAIIS_Base/user/getUnitForTree_Workshop.do", [:])
            async let reviewerData = Net.shared.post("SIPAIIS_Base/user/getUnitForTree_User.do", [:])
            async let typeData = Net.shared.post("SIPAIIS_Base/base/dict/data.do",
                                                ["dictType": "Business_ProcessAdjustment", "unitId": app.unit])
            plants = try FormOption.treeOptions(from: await plantData, users: false)
            reviewers = try FormOption.treeOptions(from: await reviewerData, users: true)
            types = try Net.array(await typeData, key: "result").compactMap { row in
                let id = Net.str(row, "value")
                let name = Net.str(row, "label")
                guard !id.isEmpty, !name.isEmpty else { return nil }
                return FormOption(id: id, name: name)
            }
            type = types.first?.id ?? ""
            if plants.isEmpty || reviewers.isEmpty || types.isEmpty {
                message = "厂区、审核人或调度类型未返回，请重新打开申请页重试。"
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func submit() async {
        guard !busy else { return }
        let description = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plant.isEmpty, !reviewer.isEmpty, !type.isEmpty,
              let start = start, let end = end, !description.isEmpty else {
            message = "请填写调度厂区、类型、日期、内容和审核人。"
            return
        }
        guard Calendar.current.startOfDay(for: end) >= Calendar.current.startOfDay(for: start) else {
            message = "结束日期不能早于开始日期。"
            return
        }
        busy = true
        message = nil
        defer { busy = false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        do {
            let raw = try await Net.shared.get(
                "SIPAIIS_DataCenter/work/processAdjustment/dostart.do",
                ["id": "", "unitId": app.unit, "targetcompanyid": plant,
                 "type": type, "status": "0", "adjustmentLevel": level,
                 "stdt": formatter.string(from: start) + " 00:00:00",
                 "eddt": formatter.string(from: end) + " 00:00:00",
                 "contents": description, "targetuser": reviewer])
            guard Net.isOK(raw) else {
                message = Net.message(raw)
                return
            }
            app.show("调度已创建")
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - 测点趋势（简单折线，兼容 iOS 15）


struct LineChart: View {
    let samples: [(Date, Double)]

    var body: some View {
        GeometryReader { geo in
            let vals = samples.map { $0.1 }
            let lo = vals.min() ?? 0
            let hi = vals.max() ?? 1
            let span = max(hi - lo, 0.0001)
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // 网格
                ForEach(0..<4) { i in
                    Path { p in
                        let y = h * CGFloat(i) / 3
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.gray.opacity(0.12), lineWidth: 1)
                }
                // 折线
                Path { p in
                    for (i, s) in samples.enumerated() {
                        let x = samples.count <= 1 ? 0 : w * CGFloat(i) / CGFloat(samples.count - 1)
                        let y = h - h * CGFloat((s.1 - lo) / span)
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(C.blue, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        }
    }
}
