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
    @Environment(\.presentationMode) private var presentation

    let maintenanceId: String

    @State private var equipmentName = ""
    @State private var man = ""
    @State private var startDate = Date()
    @State private var plannedEnd = Date()
    @State private var money = ""
    @State private var problem = ""
    @State private var photos: [UIImage] = []
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                field("设备名称", $equipmentName, "必填")
                field("维保人", $man, app.caption)
                dateField("开始日期", $startDate)
                dateField("计划完成", $plannedEnd)
                field("计划费用", $money, "元")
                multiline("问题内容", $problem)
                PhotoStrip(photos: $photos)

                VStack(spacing: 8) {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if busy { ProgressView().tint(.white) }
                            Text(busy ? "提交中…" : "提交")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(problem.isEmpty ? C.sub.opacity(0.4) : C.blue)
                        .foregroundColor(.white).cornerRadius(10)
                    }
                    .disabled(busy || problem.isEmpty)
                    if let m = message {
                        Text(m).font(.caption).foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)
            }
            .padding(12)
        }
        .background(C.bg)
        .navigationTitle("维保填报")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    @ViewBuilder
    private func field(_ label: String, _ text: Binding<String>, _ hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundColor(C.sub)
            TextField(hint, text: text)
                .font(.system(size: 15)).padding(10)
                .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                .cornerRadius(7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Color.white).cornerRadius(10)
    }

    @ViewBuilder
    private func dateField(_ label: String, _ date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundColor(C.sub)
            DatePicker("", selection: date, displayedComponents: [.date])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Color.white).cornerRadius(10)
    }

    @ViewBuilder
    private func multiline(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundColor(C.sub)
            TextEditor(text: text)
                .font(.system(size: 15)).frame(minHeight: 100).padding(8)
                .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                .cornerRadius(7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Color.white).cornerRadius(10)
    }

    private func submit() async {
        busy = true
        message = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/maintenance/insetMaintenanceDetailNoFlow.do",
                ["maintenanceId": maintenanceId,
                 "equipmentId": "",
                 "maintenanceMan": man.isEmpty ? app.caption : man,
                 "startDate": fmt(startDate),
                 "plannedenddt": fmt(plannedEnd),
                 "planMoney": money,
                 "problemcontent": problem])
            let d = Net.dict(raw)
            let ok = Net.isOK(raw)
            if ok {
                app.show("维保已填报 ✓")
                presentation.wrappedValue.dismiss()
            } else {
                message = Net.str(d, "msg").isEmpty
                    ? String(describing: raw).prefix(180).description
                    : Net.str(d, "msg")
            }
        } catch {
            message = error.localizedDescription
        }
        busy = false
    }
}

// MARK: - 新建排班
// 接口：processAdjustment/dostart.do { id }

struct ScheduleCreateScreen: View {
    @EnvironmentObject var app: AppState
    @Environment(\.presentationMode) private var presentation

    @State private var types: [FormOption] = []
    @State private var typeId = ""
    @State private var content = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("调度类型").font(.system(size: 12)).foregroundColor(C.sub)
                    Menu {
                        ForEach(types) { t in
                            Button(t.name) { typeId = t.id }
                        }
                    } label: {
                        HStack {
                            Text(types.first { $0.id == typeId }?.name ?? "请选择")
                                .font(.system(size: 15))
                                .foregroundColor(typeId.isEmpty ? C.sub : C.text)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12)).foregroundColor(C.sub)
                        }
                        .padding(11)
                        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                        .cornerRadius(7)
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)

                VStack(alignment: .leading, spacing: 6) {
                    Text("调度内容").font(.system(size: 12)).foregroundColor(C.sub)
                    TextEditor(text: $content)
                        .font(.system(size: 15)).frame(minHeight: 100).padding(8)
                        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                        .cornerRadius(7)
                }
                .padding(14).background(Color.white).cornerRadius(10)

                VStack(alignment: .leading, spacing: 6) {
                    Text("起止日期").font(.system(size: 12)).foregroundColor(C.sub)
                    DatePicker("开始", selection: $start, displayedComponents: [.date])
                    DatePicker("结束", selection: $end, displayedComponents: [.date])
                }
                .padding(14).background(Color.white).cornerRadius(10)

                VStack(spacing: 8) {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if busy { ProgressView().tint(.white) }
                            Text(busy ? "提交中…" : "发起调度")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(content.isEmpty ? C.sub.opacity(0.4) : C.blue)
                        .foregroundColor(.white).cornerRadius(10)
                    }
                    .disabled(busy || content.isEmpty)
                    if let m = message {
                        Text(m).font(.caption).foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)
            }
            .padding(12)
        }
        .background(C.bg)
        .navigationTitle("新建调度")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTypes() }
    }

    private func loadTypes() async {
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Base/base/dict/data.do",
                ["dictType": "Business_ProcessAdjustment"])
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                for k in ["result", "rows", "data", "list"] {
                    if let a = d[k] as? [[String: Any]] { arr = a; break }
                }
            } else if let a = raw as? [[String: Any]] { arr = a }
            types = arr.compactMap {
                let id = Net.str($0, "id")
                let name = Net.str($0, "dictLabel").isEmpty
                    ? Net.str($0, "name") : Net.str($0, "dictLabel")
                guard !id.isEmpty else { return nil }
                return FormOption(id: id, name: name.isEmpty ? id : name)
            }
        } catch {
            types = []
        }
    }

    private func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private func submit() async {
        busy = true
        message = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processAdjustment/dostart.do",
                ["id": typeId,
                 "contents": content,
                 "unitId": app.unit,
                 "targetcompanyid": app.unit,
                 "stdt": fmt(start),
                 "eddt": fmt(end)])
            let d = Net.dict(raw)
            let ok = Net.isOK(raw)
            if ok {
                app.show("调度已发起 ✓")
                presentation.wrappedValue.dismiss()
            } else {
                message = Net.str(d, "msg").isEmpty
                    ? String(describing: raw).prefix(180).description
                    : Net.str(d, "msg")
            }
        } catch {
            message = error.localizedDescription
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
