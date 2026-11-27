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
            if let r = d["result"] as? [String: Any] { d = r }
            else if let r = d["data"] as? [String: Any] { d = r }
            raw = d
            fields = makeDetailFields(d, order: labelOrder)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
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
    @State private var result = ""
    @State private var photos: [UIImage] = []

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

                // 处理
                VStack(alignment: .leading, spacing: 8) {
                    Text("处理结果").font(.system(size: 12)).foregroundColor(C.sub)
                    TextEditor(text: $result)
                        .font(.system(size: 15)).frame(minHeight: 90).padding(8)
                        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                        .cornerRadius(7)
                    PhotoStrip(photos: $photos)
                    Button {
                        Task { await handle() }
                    } label: {
                        HStack(spacing: 8) {
                            if store.acting { ProgressView().tint(.white) }
                            Text(store.acting ? "提交中…" : "提交处理")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(C.blue).foregroundColor(.white).cornerRadius(9)
                    }
                    .disabled(store.acting || result.isEmpty || abnormalId.isEmpty)

                    if let m = store.actMessage {
                        Text(m).font(.caption).foregroundColor(.red)
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)
            }
            .padding(12)
        }
        .background(C.bg)
        .navigationTitle("故障详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !abnormalId.isEmpty {
                await store.load(
                    path: "SIPAIIS_Equipment/maintenance/getMaintenanceDetailsByAbnormal.do",
                    params: ["abnormalId": abnormalId])
            }
        }
    }

    private func handle() async {
        let ok = await store.act(
            path: "SIPAIIS_Equipment/maintenance/updateDetailNoFlow.do",
            params: ["id": abnormalId,
                     "status": "1",
                     "problemresult": result,
                     "solvetime": DateFormatter.localizedString(
                        from: Date(), dateStyle: .short, timeStyle: .short)])
        if ok {
            app.show("处理已提交 ✓")
            await store.load(
                path: "SIPAIIS_Equipment/maintenance/getMaintenanceDetailsByAbnormal.do",
                params: ["abnormalId": abnormalId])
        }
    }
}

// MARK: - 故障审核

struct FaultAuditScreen: View {
    @EnvironmentObject var app: AppState
    let taskId: String
    let businessId: String

    @StateObject private var store = DetailStore()
    @State private var opinion = ""
    @State private var showRoute = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if store.loading {
                    ProgressView().padding(.top, 60)
                } else if !store.fields.isEmpty {
                    DetailFieldList(fields: store.fields)
                } else {
                    EmptyHint(text: store.error ?? "没有审核数据")
                }

                if let msg = store.actMessage {
                    Text(msg).font(.caption).foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14).background(Color.white).cornerRadius(10)
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await audit(pass: false) }
                    } label: {
                        Text("驳回").frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(Color.white).foregroundColor(.red)
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.red.opacity(0.5)))
                            .cornerRadius(9)
                    }
                    Button {
                        Task { await audit(pass: true) }
                    } label: {
                        Text("通过").frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(C.blue).foregroundColor(.white).cornerRadius(9)
                    }
                }
                .disabled(store.acting)
                .padding(14).background(Color.white).cornerRadius(10)

                Button {
                    showRoute = true
                } label: {
                    Label("转下一节点", systemImage: "arrow.turn.down.right")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.white).foregroundColor(C.blue)
                        .overlay(RoundedRectangle(cornerRadius: 9)
                            .stroke(C.blue.opacity(0.4))).cornerRadius(9)
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
            }
            .padding(12)
        }
        .background(C.bg)
        .navigationTitle("审核")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRoute) {
            RoutePickerSheet(taskId: taskId, businessId: businessId, pass: true) { route, users in
                Task {
                    let ok = await store.act(
                        path: "SIPAIIS_Equipment/maintenance/doAuditDetail.do",
                        params: ["id": businessId,
                                 "taskid": taskId,
                                 "businessid": businessId,
                                 "unitid": app.unit,
                                 "passstatus": "true",
                                 "audit": opinion,
                                 "routeNum": route?.id ?? "",
                                 "targetusers": users.map { $0.id }.joined(separator: ","),
                                 "type": "1"])
                    if ok { app.show("已转交 ✓") }
                }
            }
        }
        .task {
            await store.load(
                path: "SIPAIIS_Equipment/maintenance/showAuditDetail.do",
                params: ["taskId": taskId, "unitId": app.unit,
                         "id": businessId, "masterId": businessId])
        }
    }

    private func audit(pass: Bool) async {
        let ok = await store.act(
            path: "SIPAIIS_Equipment/maintenance/doAuditDetail.do",
            params: ["id": businessId,
                     "taskid": taskId,
                     "businessid": businessId,
                     "unitid": app.unit,
                     "passstatus": pass ? "true" : "false",
                     "audit": opinion,
                     "type": "1"])
        if ok {
            app.show(pass ? "已通过 ✓" : "已驳回")
            store.actMessage = nil
        }
    }
}

// MARK: - 维保详情

struct MaintainDetailScreen: View {
    @EnvironmentObject var app: AppState
    let maintenanceId: String

    @StateObject private var store = DetailStore()
    @State private var showFill = false

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

                Button {
                    showFill = true
                } label: {
                    Label("填报维保内容", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(C.blue).foregroundColor(.white).cornerRadius(9)
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
            }
            .padding(12)
        }
        .background(C.bg)
        .navigationTitle("维保详情")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFill) {
            NavigationView {
                MaintainFillScreen(maintenanceId: maintenanceId).environmentObject(app)
            }
        }
        .task {
            await store.load(
                path: "SIPAIIS_Equipment/maintenance/showMaintenanceDetailView.do",
                params: ["id": maintenanceId, "unitId": app.unit,
                         "taskId": maintenanceId, "processInstanceId": ""])
        }
    }
}

// MARK: - 排班详情 / 审核

struct ScheduleDetailScreen: View {
    @EnvironmentObject var app: AppState
    let scheduleId: String

    @StateObject private var store = DetailStore()
    @State private var opinion = ""

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

                VStack(alignment: .leading, spacing: 8) {
                    Text("审核意见").font(.system(size: 12)).foregroundColor(C.sub)
                    TextField("可留空", text: $opinion)
                        .font(.system(size: 15)).padding(10)
                        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
                        .overlay(RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
                        .cornerRadius(7)

                    HStack(spacing: 10) {
                        Button {
                            Task { await submit(pass: false) }
                        } label: {
                            Text("驳回").frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(Color.white).foregroundColor(.red)
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .stroke(Color.red.opacity(0.5))).cornerRadius(9)
                        }
                        Button {
                            Task { await submit(pass: true) }
                        } label: {
                            Text("通过").frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(C.blue).foregroundColor(.white).cornerRadius(9)
                        }
                    }
                    .disabled(store.acting)

                    if let m = store.actMessage {
                        Text(m).font(.caption).foregroundColor(.red)
                    }
                }
                .padding(14).background(Color.white).cornerRadius(10)
            }
            .padding(12)
        }
        .background(C.bg)
        .navigationTitle("排班详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load(
                path: "SIPAIIS_DataCenter/work/processAdjustment/showView.do",
                params: ["id": scheduleId])
        }
    }

    private func submit(pass: Bool) async {
        let ok = await store.act(
            path: "SIPAIIS_DataCenter/work/processAdjustment/doAuditDetail.do",
            params: ["id": scheduleId,
                     "businessid": scheduleId,
                     "passstatus": pass ? "true" : "false",
                     "auditopinion": opinion])
        if ok { app.show(pass ? "已通过 ✓" : "已驳回") }
    }
}

// MARK: - 历史任务详情

struct HistoryDetailScreen: View {
    let recordId: String
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
                path: "SIPAIIS_Equipment/maintenance/getMaintenanceDetailList.do",
                params: ["id": recordId, "page": "1", "rows": "10"])
        }
    }
}
