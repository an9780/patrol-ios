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

                    rowText("*选择设备：", equipmentName.isEmpty ? "请选择设备" : equipmentName)
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
    @State private var typeIndex = 0
    @State private var levelIndex = 0
    @State private var start = Date()
    @State private var end = Date()
    @State private var content = ""
    @State private var receiver = ""
    @State private var busy = false
    @State private var msg: String?
    @Environment(\.presentationMode) private var presentation

    private let types = ["其他调度", "生产调度", "设备调度", "安全调度"]
    private let levels = ["一级", "二级", "三级"]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("新建调度").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            ScrollView {
                VStack(spacing: 0) {
                    // 调度厂区
                    HStack(spacing: 0) {
                        Text("调度厂区：")
                            .font(.system(size: 15)).foregroundColor(.black)
                            .frame(height: 40, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(app.unit)
                            .font(.system(size: 15)).foregroundColor(Color(hex: 0x646363))
                            .frame(height: 40, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(2.5)
                        Image("arrow_right")
                            .resizable().scaledToFit()
                            .padding(9).frame(width: 40, height: 40)
                            .layoutPriority(0.5)
                    }
                    .frame(height: 40)
                    .padding(.horizontal, 10)
                    .background(Color.white)

                    // 类型 / 等级
                    VStack(spacing: 0) {
                        pickerRow("调度类型：", types, $typeIndex)
                        thin
                        pickerRow("调度等级：", levels, $levelIndex)
                        thin
                        dateRow("开始日期：", $start)
                        thin
                        dateRow("结束日期：", $end)
                        thin
                        HStack(spacing: 0) {
                            Text("接收人员：")
                                .font(.system(size: 15)).foregroundColor(.black)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(receiver.isEmpty ? "点击选择" : receiver)
                                .font(.system(size: 15)).foregroundColor(Color(hex: 0x646363))
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(3)
                        }
                        .frame(height: 40)
                        thin
                    }
                    .padding(.horizontal, 10)
                    .background(Color.white)
                    .padding(.top, 8)

                    // 调度内容
                    VStack(alignment: .leading, spacing: 0) {
                        Text("调度内容：")
                            .font(.system(size: 15)).foregroundColor(.black)
                            .frame(height: 35, alignment: .center)
                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("请填写调度内容")
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: 0xC7C7CD))
                                    .padding(6)
                            }
                            TextEditor(text: $content)
                                .font(.system(size: 15))
                                .padding(2)
                                .frame(height: 110)
                        }
                        .overlay(Rectangle().stroke(Color(hex: 0xE9E9E9), lineWidth: 1))
                    }
                    .padding(10)
                    .background(Color.white)
                    .padding(.top, 8)

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
                    .padding(.horizontal, 10).padding(.top, 14)

                    if let m = msg {
                        Text(m).font(.system(size: 12)).foregroundColor(.red)
                            .padding(.top, 8)
                    }

                    Spacer(minLength: 20)
                }
            }
            .background(Color(hex: 0xF9F9F9))
        }
        .navigationBarHidden(true)
    }

    private var thin: some View {
        Rectangle().fill(Color(hex: 0xE5E5E5)).frame(height: 0.3)
    }

    private func pickerRow(_ label: String, _ options: [String],
                           _ index: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 15)).foregroundColor(.black)
                .frame(height: 40, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                    Button(o) { index.wrappedValue = i }
                }
            } label: {
                HStack {
                    Text(options[index.wrappedValue])
                        .font(.system(size: 15)).foregroundColor(Color(hex: 0x646363))
                    Spacer()
                    Image("arrow_right").resizable().scaledToFit()
                        .frame(width: 12, height: 12).rotationEffect(.degrees(90))
                }
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(3)
        }
        .frame(height: 40)
    }

    private func dateRow(_ label: String, _ binding: Binding<Date>) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 15)).foregroundColor(.black)
                .frame(height: 40, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
            DatePicker("", selection: binding, displayedComponents: [.date])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(3)
        }
        .frame(height: 40)
    }

    private func submit() async {
        busy = true
        msg = nil
        do {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processAdjustment/dostart.do",
                ["unitId": app.unit,
                 "targetCompanyId": app.unit,
                 "typeName": types[typeIndex],
                 "adjustmentLevel": "\(levelIndex + 1)",
                 "stdt": f.string(from: start),
                 "eddt": f.string(from: end),
                 "contents": content,
                 "targetuser": receiver])
            if Net.isOK(raw) {
                app.show("调度已创建 ✓")
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
