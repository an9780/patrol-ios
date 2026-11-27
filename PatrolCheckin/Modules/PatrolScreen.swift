import SwiftUI

// MARK: - 巡检任务列表（照 activity_pro_patrol_task_list.xml + item_pro_patrol_task_list.xml）

struct Shift: Identifiable {
    let id: String
    let name: String
    let start: String
    let end: String
    let resultId: String
    var points: [Point] = []

    var rangeText: String {
        let s = start.count >= 16 ? String(start.dropFirst(11).prefix(5)) : start
        let e = end.count >= 16 ? String(end.dropFirst(11).prefix(5)) : end
        return "\(s) — \(e)"
    }
    var doneCount: Int { points.filter(\.isDone).count }
}

struct Point: Identifiable {
    let id: String
    let recordId: String
    let name: String
    let area: String
    let status: String
    let worker: String
    let finish: String

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

    func load(unit: String, date: String) async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Patrol/timeEfficiency/patrolRecord/getPatrolRecord4APP.do",
                ["unitId": unit, "userid": Net.shared.userid, "type": "P",
                 "patrolDate": date, "page": "1", "rows": "100"])
            var out: [Shift] = []
            for t in Net.array(raw, key: "content1") {
                let rid = Net.str(t, "id")
                guard !rid.isEmpty else { continue }
                var s = Shift(id: rid,
                              name: Net.str(t, "name"),
                              start: Net.str(t, "startTime"),
                              end: Net.str(t, "endTime"),
                              resultId: Net.str(t, "resultId"))
                s.points = try await loadPoints(recordId: rid)
                if !s.points.isEmpty { out.append(s) }
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
        return Net.array(raw, key: "result").map { d in
            Point(id: Net.str(d, "id"),
                  recordId: Net.str(d, "recordId"),
                  name: Net.str(d, "name"),
                  area: Net.str(Net.dict(d["processSection"]), "name"),
                  status: Net.str(d, "status"),
                  worker: Net.str(d, "workerId"),
                  finish: Net.str(d, "finishDt"))
        }
    }

    func complete(_ p: Point) async -> Bool {
        guard !p.recordId.isEmpty else { return false }
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Patrol/timeEfficiency/patrolRecord/updatePatrolPointByAPP.do",
                ["id": p.recordId])
            return Net.isOK(raw)
        } catch { return false }
    }

    func completeAll(_ s: Shift) async -> Int {
        var n = 0
        for p in s.points {
            if await complete(p) { n += 1 }
        }
        return n
    }

    /// 任务级「完成」：updatePatrolRecordByAPP
    func finishTask(_ s: Shift) async -> Bool {
        guard !s.id.isEmpty else { return false }
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Patrol/timeEfficiency/patrolRecord/updatePatrolRecordByAPP.do",
                ["id": s.id, "status": "3"])
            return Net.isOK(raw)
        } catch { return false }
    }
}

struct PatrolScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = PatrolStore()
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
            BlueHeader(title: "今日巡检任务",
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
                    }.buttonStyle(.plain)
                    Button { tabIndex = 1 } label: {
                        Text("临   时").font(.system(size: 15))
                            .foregroundColor(tabIndex == 1 ? C.tabSel : C.tabUnsel)
                            .frame(maxWidth: .infinity).frame(height: 35)
                    }.buttonStyle(.plain)
                }
                .padding(.leading, 50).padding(.trailing, 50)

                HStack(spacing: 0) {
                    Rectangle().fill(C.tabSel)
                        .frame(height: 3).cornerRadius(1.5)
                        .padding(.leading, tabIndex == 0 ? 83 : 0)
                    Rectangle().fill(tabIndex == 1 ? C.tabSel : Color.clear)
                        .frame(height: 3).cornerRadius(1.5)
                        .padding(.trailing, tabIndex == 1 ? 83 : 0)
                }
                .padding(.horizontal, 83)
            }
            .background(Color.white)

            // 列表
            if store.loading && store.shifts.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.shifts.isEmpty {
                EmptyHint(text: store.error ?? "暂无任务")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.shifts) { s in
                            NavigationLink {
                                PatrolDetailScreen(store: store, shiftId: s.id)
                            } label: {
                                shiftCard(s)
                            }
                            .buttonStyle(.plain)
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
                Rectangle().fill(s.doneCount == s.points.count ? Color(hex: 0x6FDD7F) : C.bar)
                    .frame(height: 10)
                Rectangle().fill(s.doneCount == s.points.count ? Color(hex: 0x6FDD7F) : C.bar)
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
        if s.doneCount == s.points.count { return "已完成" }
        if s.doneCount > 0 { return "进行中" }
        return "任务未开始"
    }
    private func statusColor(_ s: Shift) -> Color {
        if s.doneCount == s.points.count { return Color(hex: 0x1890FF) }
        if s.doneCount > 0 { return C.bar }
        return C.grayText
    }
    private func statusBg(_ s: Shift) -> Color {
        if s.doneCount == s.points.count { return Color(hex: 0xE5F0FF) }
        if s.doneCount > 0 { return C.doingBg }
        return Color(hex: 0xF0F0F0)
    }
}

// MARK: - 任务详情（照 activity_patrol_detail.xml + item_pro_point.xml）

struct PatrolDetailScreen: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var store: PatrolStore
    let shiftId: String
    @State private var showRemarks = false

    private var shift: Shift? { store.shifts.first { $0.id == shiftId } }
    private let cols = [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)]

    var body: some View {
        let s = shift
        VStack(spacing: 0) {
            // 蓝色渐变头部
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Button { } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                    }
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

                Text("内容：生产巡检")
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
                bottomItem("异常上报", "moudle_patrol_task_sub_fault")
                bottomItem("图片补充", "add_iv")
                Button { showRemarks = true } label: {
                    bottomItem("填写备注", "moudle_patrol_task_remark")
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    guard let s = s else { return }
                    Task {
                        let n = await store.completeAll(s)
                        _ = await store.finishTask(s)
                        app.show("已提交 \(n)/\(s.points.count)")
                        await store.load(unit: app.unit, date: app.date)
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
        .sheet(isPresented: $showRemarks) {
            NavigationView {
                TaskRemarksScreen(recordId: s?.id ?? "", pointId: "")
                    .environmentObject(app)
            }
        }
    }

    /// 照 item_pro_point.xml
    private func pointCard(_ p: Point) -> some View {
        Button {
            Task {
                let ok = await store.complete(p)
                app.show(ok ? "打卡成功 ✓" : "打卡失败")
                await store.load(unit: app.unit, date: app.date)
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
