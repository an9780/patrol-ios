import SwiftUI

// MARK: - 巡检任务列表（照 activity_pro_patrol_task_list.xml + item_pro_patrol_task_list.xml）

struct Shift: Identifiable, Codable {
    let id: String
    let name: String
    let start: String
    let end: String
    let resultId: String
    var serverStatus = ""
    var isTemporary = false
    var content = ""
    var points: [Point] = []

    var rangeText: String {
        let s = start.count >= 16 ? String(start.dropFirst(11).prefix(5)) : start
        let e = end.count >= 16 ? String(end.dropFirst(11).prefix(5)) : end
        return "\(s) — \(e)"
    }
    var allPointsDone: Bool { serverStatus == "3" || (!points.isEmpty && doneCount == points.count) }
    var doneCount: Int { points.filter(\.isDone).count }
}

struct Point: Identifiable, Codable {
    let id: String
    let recordId: String
    let name: String
    let area: String
    var status: String
    var worker: String
    var finish: String
    var kind: String? = nil

    var isDone: Bool { status == "3" }
    var timeText: String {
        finish.count >= 16 ? String(finish.dropFirst(11).prefix(5)) : ""
    }
    /// 已完成显示「时间 姓名」，未完成显示「暂未巡检」
    var dateLine: String {
        if isDone {
            let t = timeText
            return t.isEmpty ? (worker.isEmpty ? "已巡检" : worker) : "\(t)  \(worker)"
        }
        return "暂未巡检"
    }
}

@MainActor
final class PatrolStore: ObservableObject {
    @Published var shifts: [Shift] = []
    @Published var loading = false
    @Published var error: String?

    let demonstration: Bool
    init(demonstration: Bool) {
        self.demonstration = demonstration
    }

    func load(unit: String, date: String) async {
        if demonstration {
            if shifts.isEmpty { shifts = Self.sampleShifts(date: date) }
            return
        }
        guard !loading else { return }
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Patrol/timeEfficiency/patrolRecord/getPatrolRecord4APP.do",
                ["unitId": unit, "userid": Net.shared.userid, "type": "P",
                 "patrolDate": date, "page": "1", "rows": "100"])
            guard Net.dict(raw)["content1"] != nil else { throw APIError.message("服务未返回任务列表") }
            var out: [Shift] = []
            for t in Net.array(raw, key: "content1") {
                let rid = Net.str(t, "id")
                guard !rid.isEmpty else { continue }
                var s = Shift(id: rid,
                              name: Net.str(t, "name"),
                              start: Net.str(t, "startTime"),
                              end: Net.str(t, "endTime"),
                              resultId: Net.str(t, "resultId"))
                s.serverStatus = Net.str(t, "status")
                s.isTemporary = Net.str(t, "patrolModelId") == "temp"
                s.content = Net.str(t, "content")
                out.append(s)
            }
            shifts = out
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func loadPoints(recordId: String) async throws -> [Point] {
        let raw = try await Net.shared.post(
            "SIPAIIS_Patrol/timeEfficiency/patrolPoint/getPatrolPointForRecord4APP.do",
            ["patrolRecordId": recordId, "type": "P"])
        guard Net.dict(raw)["result"] != nil else { throw APIError.message("服务未返回点位列表") }
        return Net.array(raw, key: "result").map { d in
            Point(id: Net.str(d, "id"),
                  recordId: Net.str(d, "recordId"),
                  name: Net.str(d, "name"),
                  area: Net.str(Net.dict(d["processSection"]), "name"),
                  status: Net.str(d, "status"),
                  worker: Net.str(d, "workerId"),
                  finish: Net.str(d, "finishDt"), kind: Net.str(d, "type"))
        }
    }

    func loadDetail(_ id: String) async throws {
        guard !demonstration else { return }
        let points = try await loadPoints(recordId: id)
        if let index = shifts.firstIndex(where: { $0.id == id }) {
            shifts[index].points = points
        }
    }

    func markSample(_ point: Point, shiftID: String) {
        guard demonstration, let i = shifts.firstIndex(where: { $0.id == shiftID }),
              let j = shifts[i].points.firstIndex(where: { $0.id == point.id }),
              !shifts[i].points[j].isDone else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        shifts[i].points[j].status = "3"
        shifts[i].points[j].worker = "演示员"
        shifts[i].points[j].finish = formatter.string(from: Date())
    }

    private static func sampleShifts(date: String) -> [Shift] {
        func make(_ id: String, _ name: String, _ temporary: Bool, _ names: [String]) -> Shift {
            var shift = Shift(id: id, name: name, start: date + " 08:00",
                              end: date + " 17:00", resultId: "")
            shift.isTemporary = temporary
            shift.content = "巡检流程演示"
            shift.points = names.enumerated().map { index, name in
                Point(id: "\(id)-\(index)", recordId: id, name: name,
                      area: "示例区域", status: "1", worker: "", finish: "")
            }
            return shift
        }
        return [make("daily", "日常巡检（演示）", false, ["进水泵房", "配电间"]),
                make("temp", "临时巡检（演示）", true, ["仪表间"])]
    }
}

struct PatrolScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store: PatrolStore
    init(demonstration: Bool = false) {
        _store = StateObject(wrappedValue: PatrolStore(demonstration: demonstration))
    }
    private var visibleShifts: [Shift] {
        store.shifts.filter { $0.isTemporary == (tabIndex == 1) }
    }
    @State private var tabIndex = 0        // 0=日常 1=临时

    var body: some View {
        NavigationView {
            content
                .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .task { await store.load(unit: app.unit, date: app.date) }
    }

    private var content: some View {
        VStack(spacing: 0) {
            // 标题栏
            BlueHeader(title: store.demonstration ? "本地演示 · 今日巡检任务" : "今日巡检任务",
                       trailing: AnyView(Button {
                           Task { await store.load(unit: app.unit, date: app.date) }
                       } label: {
                           Image(systemName: "arrow.clockwise")
                               .font(.system(size: 15)).foregroundColor(.white)
                       }))

            // 日常 / 临时 页签 + 3dp 指示条
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button { tabIndex = 0 } label: {
                        Text("日   常").font(.system(size: 15))
                            .foregroundColor(tabIndex == 0 ? C.tabSel : C.tabUnsel)
                            .frame(maxWidth: .infinity).frame(height: 35)
                    }.buttonStyle(.plain).accessibilityIdentifier("dailyTab")
                    Button { tabIndex = 1 } label: {
                        Text("临   时").font(.system(size: 15))
                            .foregroundColor(tabIndex == 1 ? C.tabSel : C.tabUnsel)
                            .frame(maxWidth: .infinity).frame(height: 35)
                    }.buttonStyle(.plain).accessibilityIdentifier("temporaryTab")
                }
                .padding(.leading, 50).padding(.trailing, 50)

                HStack(spacing: 0) {
                    ForEach(0..<2) { index in
                        Capsule().fill(tabIndex == index ? C.tabSel : Color.clear)
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 83)
            }
            .background(Color.white)

            // 列表
            if store.loading && store.shifts.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleShifts.isEmpty {
                EmptyHint(text: store.error ?? "暂无任务")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleShifts) { s in
                            NavigationLink {
                                PatrolDetailScreen(store: store, shiftId: s.id)
                            } label: {
                                shiftCard(s)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("shift-" + s.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                }
                .background(Color(hex: 0xFEFEFE))
            }
        }
    }

    /// 照 item_pro_patrol_task_list.xml
    private func shiftCard(_ s: Shift) -> some View {
        VStack(spacing: 0) {
            // 顶部 10dp 色带
            HStack(spacing: 0) {
                Rectangle().fill(s.allPointsDone ? Color(hex: 0x6FDD7F) : C.bar)
                    .frame(height: 10)
                Rectangle().fill(s.allPointsDone ? Color(hex: 0x6FDD7F) : C.bar)
                    .frame(height: 10)
            }

            HStack(spacing: 0) {
                Text(s.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.leading, 10)
                    .frame(height: 30, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(statusText(s))
                    .font(.system(size: 12))
                    .foregroundColor(statusColor(s))
                    .frame(height: 22)
                    .padding(.horizontal, 10)
                    .background(statusBg(s))
                    .cornerRadius(11)
                    .padding(.trailing, 5)
            }
            .frame(height: 30)

            Text("任务时限：" + s.rangeText)
                .font(.system(size: 13))
                .foregroundColor(.black)
                .padding(.leading, 10)
                .frame(height: 20, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("生产巡检")
                .font(.system(size: 14))
                .foregroundColor(.black)
                .padding(.leading, 10)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 10)
        .background(
            RoundCorners(corners: [.bottomLeft, .bottomRight], radius: 8)
                .fill(C.pointUncom)
        )
        .padding(.horizontal, 0)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    private func statusText(_ s: Shift) -> String {
        if s.allPointsDone { return "已完成" }
        if s.doneCount > 0 { return "进行中" }
        return "任务未开始"
    }
    private func statusColor(_ s: Shift) -> Color {
        if s.allPointsDone { return Color(hex: 0x1890FF) }
        if s.doneCount > 0 { return C.bar }
        return C.grayText
    }
    private func statusBg(_ s: Shift) -> Color {
        if s.allPointsDone { return Color(hex: 0xE5F0FF) }
        if s.doneCount > 0 { return C.doingBg }
        return Color(hex: 0xF0F0F0)
    }
}

// MARK: - 任务详情（照 activity_patrol_detail.xml + item_pro_point.xml）

struct PatrolDetailScreen: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var store: PatrolStore
    let shiftId: String
    @Environment(\.dismiss) private var dismiss
    @State private var showReport = false
    @State private var detailsError: String?
    @State private var loadingDetails = true
    @State private var pointInfo: Point?
    @State private var showRemarks = false
    @State private var showImages = false

    private var shift: Shift? { store.shifts.first { $0.id == shiftId } }
    private let cols = [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)]

    var body: some View {
        let s = shift
        VStack(spacing: 0) {
            // 蓝色渐变头部
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                    }.accessibilityLabel("返回任务列表")
                    Spacer()
                    Text("任务详情")
                        .font(.system(size: 15)).foregroundColor(.white)
                        .frame(height: 50)
                    Spacer()
                    Color.clear.frame(width: 30, height: 30)
                }

                Text(s?.name ?? "")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .frame(height: 30, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("任务时间：" + (s?.rangeText ?? ""))
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0xCACACA))
                    .padding(.horizontal, 30)
                    .frame(height: 30, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)

                Text("内容：" + (s?.content ?? ""))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
            )

            // 白色点位区（顶部圆角 10）
            ScrollView {
                if loadingDetails {
                    ProgressView().padding()
                } else if let error = detailsError {
                    Button("点位加载失败：\(error) · 重试") { Task { await loadDetails() } }.padding()
                } else if s?.points.isEmpty != false {
                    EmptyHint(text: "暂无巡检点")
                }
                LazyVGrid(columns: cols, spacing: 0) {
                    ForEach(s?.points ?? []) { p in
                        pointCard(p)
                            .padding(.leading, 5).padding(.trailing, 5)
                            .padding(.top, 8).padding(.bottom, 4)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.top, 15)
            }
            .background(
                RoundCorners(corners: [.topLeft, .topRight], radius: 10)
                    .fill(Color.white)
            )
            .padding(.top, -15)

            // 底部操作栏（62dp）
            HStack(spacing: 0) {
                Button { showReport = true } label: {
                    bottomItem("异常上报", "moudle_patrol_task_sub_fault")
                }.disabled(store.demonstration)
                Button { showImages = true } label: {
                    bottomItem("图片补充", "add_iv")
                }
                .buttonStyle(.plain)
                .disabled(store.demonstration)
                Button { showRemarks = true } label: {
                    bottomItem("填写备注", "moudle_patrol_task_remark")
                }
                .buttonStyle(.plain)
                .disabled(store.demonstration)
                Spacer()
                Button {
                    if store.demonstration {
                        app.show(s?.allPointsDone == true ? "本地演示已完成" : "请先点选所有示例点位")
                    } else {
                        app.show("请在支持现场核验的客户端完成巡检")
                    }
                } label: {
                    Text("完  成")
                        .font(.system(size: 15)).foregroundColor(.white)
                        .frame(width: 100, height: 33)
                        .background(C.blue)
                        .cornerRadius(5)
                }
                .padding(.trailing, 15)
            }
            .frame(height: 62)
            .background(Color.white)
        }
        .navigationBarHidden(true)
        .task { await loadDetails() }
        .sheet(item: $pointInfo) { p in
            NavigationView {
                PatrolPointDataScreen(point: p, shiftID: shiftId, unit: app.unit)
                .toolbar { Button("关闭") { pointInfo = nil } }
            }
        }
        .sheet(isPresented: $showReport) {
            FaultReportScreen(patrolRecordID: shiftId).environmentObject(app)
        }
        .sheet(isPresented: $showImages) {
            NavigationView {
                RemarkImageScreen(recordId: shiftId)
                    .environmentObject(app)
            }
        }
        .sheet(isPresented: $showRemarks) {
            NavigationView {
                TaskRemarksScreen(recordId: shiftId)
                    .environmentObject(app)
            }
        }
    }

    private func loadDetails() async {
        loadingDetails = true
        detailsError = nil
        do { try await store.loadDetail(shiftId) }
        catch { detailsError = error.localizedDescription }
        loadingDetails = false
    }

    /// 照 item_pro_point.xml
    private func pointCard(_ p: Point) -> some View {
        Button {
            if store.demonstration {
                store.markSample(p, shiftID: shiftId)
            } else {
                pointInfo = p
            }
        } label: {
            VStack(spacing: 0) {
                Text(p.name)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .padding(.vertical, 8)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 0) {
                    Text(p.area)
                        .font(.system(size: 12)).foregroundColor(C.pointArea)
                        .frame(maxWidth: .infinity).frame(height: 20)
                    Text(p.isDone && !p.worker.isEmpty ? p.worker : "暂无")
                        .font(.system(size: 12)).foregroundColor(C.pointArea)
                        .frame(maxWidth: .infinity).frame(height: 20)
                }

                Text(p.dateLine)
                    .font(.system(size: 12)).foregroundColor(C.pointArea)
                    .frame(maxWidth: .infinity).frame(height: 25)
            }
            .padding(5)
            .background(p.isDone ? C.pointCom : C.pointUncom)
            .cornerRadius(5)
            .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("point-" + p.id)
        .accessibilityValue(p.isDone ? "已完成" : "待巡检")
    }

    private func bottomItem(_ title: String, _ image: String) -> some View {
        VStack(spacing: 0) {
            Image(image)
                .resizable().scaledToFit()
                .frame(height: 22)
                .padding(1)
                .frame(maxHeight: .infinity)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0x868686))
                .frame(height: 18)
        }
        .frame(width: 50)
        .padding(.top, 11).padding(.bottom, 8)
        .padding(.leading, 15)
    }
}
