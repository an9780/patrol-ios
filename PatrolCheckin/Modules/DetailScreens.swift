import SwiftUI
import UIKit

// MARK: - 通用详情渲染
// 各模块详情接口返回的字段名差异很大，这里统一按「字段名 → 值」渲染，
// 再叠加模块自己的操作按钮。

struct DetailField: Identifiable {
    let key: String
    let label: String
    let value: String
    var id: String { key }
}

/// 把 JSON 字典转成可读行：已知字段翻译成中文，其余原样显示
func makeDetailFields(_ d: [String: Any], order: [String: String] = [:]) -> [DetailField] {
    let labels: [String: String] = order.merging([
        "id": "编号",
        "name": "名称",
        "contents": "内容",
        "content": "内容",
        "describe": "描述",
        "abnormityDescription": "异常描述",
        "problemcontent": "问题内容",
        "problemresult": "处理结果",
        "remark": "备注",
        "status": "状态",
        "type": "类型",
        "typeName": "类型",
        "insdt": "创建时间",
        "insuserName": "创建人",
        "stdt": "开始时间",
        "eddt": "结束时间",
        "finishDt": "完成时间",
        "maintenanceMan": "维保人",
        "equipmentName": "设备",
        "pSectionName": "工艺段",
        "processSectionName": "工艺段",
        "alarmLevel": "报警级别",
        "alarmType": "报警类型",
        "mpointName": "测点",
        "unitName": "单位",
        "work_evaluate": "工作评价",
        "auditopinion": "审核意见",
        "passstatus": "审核结果",
    ]) { a, _ in a }

    var out: [DetailField] = []
    var used = Set<String>()

    // 先按顺序输出已知字段
    for (k, label) in labels {
        guard !used.contains(k), let v = d[k] else { continue }
        let s = stringify(v)
        if s.isEmpty || s == "null" || s == "<null>" { continue }
        out.append(DetailField(key: k, label: label, value: s))
        used.insert(k)
    }
    // 其余标量字段
    for (k, v) in d.sorted(by: { $0.key < $1.key }) {
        if used.contains(k) { continue }
        if v is [String: Any] || v is [[String: Any]] { continue }
        let s = stringify(v)
        if s.isEmpty || s == "null" || s == "<null>" || s == "0" || s == "false" { continue }
        if k.hasPrefix("_") { continue }
        out.append(DetailField(key: k, label: k, value: s))
    }
    return out
}

func stringify(_ v: Any) -> String {
    if let s = v as? String { return s }
    if let b = v as? Bool { return b ? "是" : "否" }
    if let n = v as? NSNumber { return n.stringValue }
    return String(describing: v)
}

struct DetailFieldList: View {
    let fields: [DetailField]
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(fields.enumerated()), id: \.element.id) { idx, f in
                HStack(alignment: .top, spacing: 10) {
                    Text(f.label)
                        .font(.system(size: 13)).foregroundColor(C.sub)
                        .frame(width: 84, alignment: .leading)
                    Text(f.value)
                        .font(.system(size: 14)).foregroundColor(C.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 9)
                if idx < fields.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
        .padding(14).background(Color.white).cornerRadius(10)
    }
}

// MARK: - 通用详情加载器

@MainActor
final class DetailStore: ObservableObject {
    @Published var raw: [String: Any] = [:]
    @Published var fields: [DetailField] = []
    @Published var loading = false
    @Published var error: String?
    @Published var acting = false
    @Published var actMessage: String?

    func load(path: String, params: [String: String], labelOrder: [String: String] = [:]) async {
        loading = true
        error = nil
        do {
            let any = try await Net.shared.post(path, params)
            var d = Net.dict(any)
            // 常见包裹：result / data
            if let row = Net.array(d, key: "result").first { d = row }
            else if let r = d["result"] as? [String: Any] { d = r }
            else if let r = d["data"] as? [String: Any] { d = r }
            raw = d
            fields = makeDetailFields(d, order: labelOrder)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func rawString(_ key: String) -> String {
        guard let v = raw[key] else { return "" }
        return stringify(v)
    }

    func act(path: String, params: [String: String], json: Bool = false) async -> Bool {
        acting = true
        actMessage = nil
        defer { acting = false }
        do {
            let any = json ? try await Net.shared.postJSON(path, params)
                            : try await Net.shared.post(path, params)
            let d = Net.dict(any)
            let ok = Net.isOK(any)
            if !ok {
                let m = Net.str(d, "msg")
                actMessage = m.isEmpty ? String(describing: any).prefix(160).description : m
            }
            return ok
        } catch {
            actMessage = error.localizedDescription
            return false
        }
    }
}

// MARK: - 故障详情 / 处理

struct FaultDetailScreen: View {
    @EnvironmentObject var app: AppState
    let abnormalId: String

    @StateObject private var store = DetailStore()
    @State private var planMoney = ""
    @State private var planDate = Date()
    @State private var receiver = ""
    @State private var pickedUserId = ""
    @State private var faultType = ""
    @State private var handleWay = ""
    @State private var busy = false
    @State private var msg: String?
    @State private var showUserPicker = false

    private let gray01 = Color(hex: 0xDADDE2)
    private let blue = Color(hex: 0x419DE4)

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("异常详情").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            ScrollView {
                VStack(spacing: 0) {
                    // ── 详情区：左右 10，上下 5 ──
                    VStack(spacing: 0) {
                        // 所属厂区（带定位图标，权重 1.2 : 3）
                        HStack(spacing: 0) {
                            Text("所属厂区:")
                                .font(.system(size: 16))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(1.2)
                            Text(store.rawString("companyName"))
                                .font(.system(size: 16))
                                .padding(.leading, 15)
                                .frame(height: 35, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(3)
                            Image("moudle_location")
                                .resizable().scaledToFit()
                                .frame(width: 30, height: 35)
                                .padding(.trailing, 10)
                        }
                        thinDivider(inset: false)

                        row("工 艺 段:", store.rawString("processSectionName"))
                        thinDivider(inset: false)

                        row("上报时间:", store.rawString("insdt"))
                        row("上报人:", store.rawString("insuserName"))
                        thinDivider(inset: false)

                        // 异常描述
                        VStack(alignment: .leading, spacing: 0) {
                            Text("异常描述")
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 30)
                            Text(store.rawString("abnormityDescription"))
                                .font(.system(size: 15))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Rectangle().fill(gray01).frame(height: 0.3)
                            .padding(.horizontal, 20)

                        // 备注
                        VStack(alignment: .leading, spacing: 0) {
                            Text("备注")
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 30)
                            Text(store.rawString("remark"))
                                .font(.system(size: 15))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 故障设备
                        VStack(alignment: .leading, spacing: 0) {
                            Text("故障设备")
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 30)
                            Rectangle().fill(gray01).frame(height: 0.3)
                                .padding(.horizontal, 20)
                            Text(store.rawString("equipmentName"))
                                .font(.system(size: 16))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.leading, 10).padding(.trailing, 10)
                    .padding(.vertical, 5)

                    // ── 待办区：生成缺陷 ──
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            Text("生成缺陷")
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 35)
                            Rectangle().fill(gray01).frame(height: 0.3)
                        }

                        // 处理方式
                        HStack(spacing: 0) {
                            Text("处理方式:")
                                .font(.system(size: 16))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(1.5)
                            Button { } label: {
                                HStack {
                                    Text(handleWay.isEmpty ? "请选择" : handleWay)
                                        .font(.system(size: 16))
                                        .foregroundColor(handleWay.isEmpty ? C.sub : .black)
                                    Spacer()
                                    Image("iv_down").resizable().scaledToFit()
                                        .padding(8).frame(width: 30, height: 35)
                                        .padding(.trailing, 30)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .layoutPriority(3)
                        }
                        Rectangle().fill(gray01).frame(height: 0.3).padding(.horizontal, 20)

                        // 计划完成日期
                        HStack(spacing: 0) {
                            Text("计划完成日期:")
                                .font(.system(size: 16))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(1.5)
                            DatePicker("", selection: $planDate, displayedComponents: [.date])
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(3)
                        }
                        Rectangle().fill(gray01).frame(height: 0.3).padding(.horizontal, 20)

                        // 计划费用
                        HStack(spacing: 0) {
                            Text("计划费用:")
                                .font(.system(size: 16))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(1.5)
                            TextField("0.0", text: $planMoney)
                                .font(.system(size: 16))
                                .keyboardType(.decimalPad)
                                .padding(.leading, 15)
                                .frame(height: 35)
                                .frame(maxWidth: .infinity)
                                .layoutPriority(3)
                        }
                        Rectangle().fill(gray01).frame(height: 0.3).padding(.horizontal, 20)

                        // 接收人员 + 选本人
                        HStack(spacing: 0) {
                            Text("接收人员:")
                                .font(.system(size: 16))
                                .padding(.leading, 10)
                                .frame(height: 35, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(1.5)
                            Button {
                                showUserPicker = true
                            } label: {
                                Text(receiver.isEmpty ? "点击选择" : receiver)
                                    .font(.system(size: 16))
                                    .foregroundColor(receiver.isEmpty ? C.sub : .black)
                                    .padding(.leading, 15)
                                    .frame(height: 35, alignment: .center)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .layoutPriority(3)
                            Button("选本人") { receiver = app.caption }
                                .font(.system(size: 14)).foregroundColor(.white)
                                .frame(width: 80, height: 30)
                                .background(blue).cornerRadius(3)
                                .padding(.trailing, 15)
                        }
                        Rectangle().fill(gray01).frame(height: 0.3).padding(.horizontal, 20)

                        // 故障类型
                        VStack(alignment: .leading, spacing: 0) {
                            Text("故障类型")
                                .font(.system(size: 16))
                                .padding(.leading, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 30)
                            Rectangle().fill(gray01).frame(height: 0.3).padding(.horizontal, 20)
                            Text(faultType.isEmpty ? "点击选择故障条目" : faultType)
                                .font(.system(size: 16))
                                .foregroundColor(faultType.isEmpty ? C.sub : .black)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.bottom, 10)

                        // 提交
                        Button {
                            Task { await submit() }
                        } label: {
                            HStack(spacing: 8) {
                                if busy { ProgressView().tint(.white) }
                                Text(busy ? "提交中…" : "提 交")
                                    .font(.system(size: 19)).foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(blue).cornerRadius(3)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 20)

                        if let m = msg {
                            Text(m).font(.system(size: 12)).foregroundColor(.red)
                                .padding(.horizontal, 10).padding(.bottom, 10)
                        }
                    }
                    .padding(.leading, 10).padding(.trailing, 10)
                    .padding(.vertical, 5)
                }
            }
            .background(C.bg)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showUserPicker) {
            UserPickerScreen(multiple: false) { picked in
                if let u = picked.first { receiver = u.name; pickedUserId = u.id }
            }
            .environmentObject(app)
        }
        .task {
            if !abnormalId.isEmpty {
                await store.load(
                    path: "SIPAIIS_Equipment/maintenance/getMaintenanceDetailsByAbnormal.do",
                    params: ["abnormalId": abnormalId])
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 16))
                .padding(.leading, 10)
                .frame(height: 35, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 16))
                .padding(.leading, 15)
                .frame(height: 35, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(3)
        }
    }

    private func thinDivider(inset: Bool) -> some View {
        Rectangle().fill(gray01).frame(height: 0.3)
    }

    private func submit() async {
        busy = true
        msg = nil
        let ok = await store.act(
            path: "SIPAIIS_Equipment/maintenance/updateDetailNoFlow.do",
            params: ["id": abnormalId,
                     "status": "1",
                     "problemresult": store.rawString("abnormityDescription"),
                     "solvetime": DateFormatter.localizedString(
                        from: Date(), dateStyle: .short, timeStyle: .short)])
        busy = false
        if ok { app.show("处理已提交 ✓") }
        else { msg = store.actMessage }
    }
}

struct FaultAuditScreen: View {
    @Environment(\.dismiss) private var dismiss
    let taskId: String
    let processInstanceId: String
    let title: String

    @State private var fields: [(String, String)] = []
    @State private var error: String?
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            BlueHeader(title: title, back: { dismiss() })
            ScrollView {
                VStack(spacing: 12) {
                    if loading {
                        ProgressView().padding(32)
                    } else if let error = error {
                        EmptyHint(text: error)
                        Button("重试") { Task { await load() } }
                    } else {
                        ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                            HStack(alignment: .top) {
                                Text(field.0).foregroundColor(C.sub).frame(width: 90, alignment: .leading)
                                Text(field.1).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(10)
                            .background(Color.white)
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(C.bg)
        .navigationBarHidden(true)
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/maintenance/showHandleDetail.do",
                ["taskId": taskId, "processInstanceId": processInstanceId])
            let root = Net.dict(raw)
            let result = Net.dict(root["result"])
            let detail = result.isEmpty ? root : result
            let maintenance = Net.dict(detail["maintenanceDetail"])
            guard !maintenance.isEmpty else { throw APIError.message(Net.message(raw)) }
            fields = [
                ("当前节点", Net.str(detail, "taskName")),
                ("所属工艺段", Net.str(Net.dict(maintenance["processSection"]), "name")),
                ("设备名称", Net.str(maintenance, "equipmentNames")),
                ("问题描述", Net.str(maintenance, "problemcontent")),
                ("发起时间", Net.str(maintenance, "insdt")),
                ("计划完成时间", Net.str(maintenance, "plannedenddt")),
                ("处理人", Net.str(detail, "targetUsersName"))
            ].filter { !$0.1.isEmpty }
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}

// MARK: - 维保详情

struct MaintainDetailScreen: View {
    @EnvironmentObject var app: AppState
    let maintenanceId: String

    @StateObject private var store = DetailStore()
    @State private var showFill = false
    @State private var maintenanceRows: [GenericRow] = []
    @State private var entriesError: String?

    private let gray08 = Color(hex: 0x646363)
    private let grayT = Color(hex: 0xE5E5E5)

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("维保详情").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            ScrollView {
                VStack(spacing: 0) {
                    // 维保单号
                    HStack(spacing: 0) {
                        Text("维保单号：")
                            .font(.system(size: 15)).foregroundColor(.black)
                            .frame(height: 50, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(store.rawString("id"))
                            .font(.system(size: 15)).foregroundColor(gray08)
                            .frame(height: 50, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(3)
                    }
                    .padding(.horizontal, 10)
                    .background(Color.white)

                    // 维保厂商 / 月份
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Text("维保厂商：")
                                .font(.system(size: 15)).foregroundColor(.black)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(store.rawString("companyName"))
                                .font(.system(size: 15)).foregroundColor(gray08)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(3)
                        }
                        Rectangle().fill(grayT).frame(height: 0.3)
                        HStack(spacing: 0) {
                            Text("月份：")
                                .font(.system(size: 15)).foregroundColor(.black)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(store.rawString("month"))
                                .font(.system(size: 15)).foregroundColor(gray08)
                                .frame(height: 40, alignment: .center)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .layoutPriority(3)
                        }
                        Rectangle().fill(grayT).frame(height: 0.3)
                    }
                    .padding(.horizontal, 10)
                    .background(Color.white)
                    .padding(.top, 8)

                    // 子单列表
                    HStack(spacing: 0) {
                        Text("子单列表")
                            .font(.system(size: 15)).foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                    if store.fields.isEmpty {
                        EmptyHint(text: store.error ?? "暂无子单")
                            .frame(height: 200)
                    } else {
                        DetailFieldList(fields: store.fields)
                            .padding(.horizontal, 10)
                    }

                    // 填报入口
                    Button {
                        showFill = true
                    } label: {
                        Label("填报维保内容", systemImage: "square.and.pencil")
                            .font(.system(size: 15)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(C.blue).cornerRadius(3)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 14)

                    if let entriesError = entriesError {
                        Text(entriesError).foregroundColor(.red).padding()
                    }
                    ForEach(maintenanceRows) { row in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(Net.str(row.raw, "equipmentNames")).font(.headline)
                            Text(row.title)
                            Text(Net.str(row.raw, "problemresult")).foregroundColor(C.sub)
                            Text(Net.str(row.raw, "solvetime")).font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.white)
                    }
                    Spacer(minLength: 0)
                }
            }
            .background(Color(hex: 0xF9F9F9))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showFill) {
            NavigationView {
                MaintainFillScreen(maintenanceId: maintenanceId).environmentObject(app)
            }
        }
        .task {
            await loadEntries()
            await store.load(
                path: "SIPAIIS_Equipment/maintenance/showMaintenanceDetailView.do",
                params: ["id": maintenanceId, "unitId": app.unit,
                         "taskId": maintenanceId, "processInstanceId": ""])
        }
    }
    private func loadEntries() async {
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/maintenance/getListMaintenanceDetail.do",
                ["maintenanceId": maintenanceId, "page": "1", "rows": "50",
                 "sort": "insdt", "order": "desc"])
            let payload = Net.dict(raw)
            let envelope = Net.dict(payload["result"])
            guard payload["rows"] != nil || envelope["rows"] != nil else {
                throw APIError.message("服务未返回维保明细")
            }
            let rows = Net.array(payload["rows"] ?? envelope["rows"])
            maintenanceRows = rows.enumerated().map { GenericRow.from($0.element, index: $0.offset) }
        } catch {
            entriesError = error.localizedDescription
        }
    }
}



// MARK: - 排班详情 / 审核

// MARK: - 历史任务详情

struct HistoryDetailScreen: View {
    let recordId: String
    var abnormal = false
    @StateObject private var store = DetailStore()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if store.loading {
                    ProgressView().padding(.top, 60)
                } else if !store.fields.isEmpty {
                    DetailFieldList(fields: store.fields)
                } else {
                    EmptyHint(text: store.error ?? "没有详情数据")
                }
            }
            .padding(12)
        }
        .background(C.bg)
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load(
                path: abnormal ? "SIPAIIS_Equipment/maintenance/getMaintenanceDetailsByAbnormal.do"
                    : "SIPAIIS_Equipment/maintenance/showMaintenanceDetailView.do",
                params: [abnormal ? "abnormalId" : "id": recordId])
        }
    }
}
