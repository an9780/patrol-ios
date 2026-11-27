import SwiftUI

// MARK: - 巡检模块（完整可用）

struct Shift: Identifiable {
    let id: String
    let name: String
    let start: String
    let end: String
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
    let status: String
    let worker: String
    let finish: String

    var isDone: Bool { status == "3" }
    var timeText: String {
        finish.count >= 16 ? String(finish.dropFirst(11).prefix(5)) : ""
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
                 "patrolDate": date, "page": "1", "rows": "100"]
            )
            let tasks = Net.array(raw, key: "content1")
            var out: [Shift] = []
            for t in tasks {
                let rid = Net.str(t, "id")
                guard !rid.isEmpty else { continue }
                var s = Shift(id: rid, name: Net.str(t, "name"),
                              start: Net.str(t, "startTime"), end: Net.str(t, "endTime"))
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
            ["patrolRecordId": recordId, "type": "P"]
        )
        let arr = Net.array(raw, key: "result")
        return arr.map { d in
            Point(id: Net.str(d, "id"),
                  recordId: Net.str(d, "recordId"),
                  name: Net.str(d, "name"),
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
                ["id": p.recordId]
            )
            return Net.int(Net.dict(raw), "code") == 1
        } catch {
            return false
        }
    }

    func completeAll(_ s: Shift) async -> Int {
        var ok = 0
        for p in s.points {
            if await complete(p) { ok += 1 }
        }
        return ok
    }
}

struct PatrolScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = PatrolStore()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                BlueHeader(
                    title: "今日巡检任务",
                    subtitle: "\(app.caption) · \(app.date)",
                    trailing: AnyView(
                        Button { Task { await reload() } } label: {
                            Image(systemName: "arrow.clockwise").foregroundColor(.white)
                        }
                    )
                )

                if store.loading {
                    ProgressView().padding(.top, 60)
                    Spacer()
                } else {
                    LoadableList(items: store.shifts, empty: "这一天没有点位任务") { s in
                        NavigationLink {
                            PatrolDetailScreen(store: store, shiftId: s.id)
                        } label: {
                            shiftCard(s)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationBarHidden(true)
            .task { await reload() }
        }
        .navigationViewStyle(.stack)
    }

    private func reload() async {
        await store.load(unit: app.unit, date: app.date)
    }

    private func shiftCard(_ s: Shift) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(s.doneCount == s.points.count ? C.greenBar : C.cyan)
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(s.name).font(.system(size: 16, weight: .semibold)).foregroundColor(C.text)
                    Spacer()
                    StatusPill(text: statusText(s), color: statusColor(s))
                }
                Text("任务时限：\(s.rangeText)").font(.system(size: 12)).foregroundColor(C.sub)
                HStack {
                    Text("生产巡检").font(.system(size: 13)).foregroundColor(C.text)
                    Spacer()
                    Text("\(s.doneCount)/\(s.points.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(s.doneCount == s.points.count ? C.greenBar : C.sub)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
        }
        .background(Color.white).cornerRadius(6)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private func statusText(_ s: Shift) -> String {
        if s.doneCount == s.points.count { return "已完成" }
        if s.doneCount > 0 { return "进行中" }
        return "任务未开始"
    }
    private func statusColor(_ s: Shift) -> Color {
        if s.doneCount == s.points.count { return Color(red: 0.09, green: 0.64, blue: 0.29) }
        if s.doneCount > 0 { return Color(red: 0.85, green: 0.47, blue: 0.02) }
        return C.sub
    }
}

struct PatrolDetailScreen: View {
    @EnvironmentObject var app: AppState
    @ObservedObject var store: PatrolStore
    let shiftId: String

    private var shift: Shift? { store.shifts.first { $0.id == shiftId } }
    private let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        let s = shift
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text(s?.name ?? "任务详情")
                    .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                if let s = s {
                    Text("任务时间：\(s.rangeText)")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
                }
                Text("内容：生产巡检")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(C.blue)

            HStack {
                Text("巡检结果:\(resultText(s))")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(C.greenBar)

            ScrollView {
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(s?.points ?? []) { p in
                        pointCard(p)
                    }
                }
                .padding(10)

                Button {
                    guard let s = s else { return }
                    Task {
                        let n = await store.completeAll(s)
                        app.show("整班提交 \(n)/\(s.points.count)")
                        await store.load(unit: app.unit, date: app.date)
                    }
                } label: {
                    Text("整班点完")
                        .font(.system(size: 15, weight: .medium)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(C.cyan).cornerRadius(6)
                }
                .padding(.horizontal, 10).padding(.bottom, 20)
            }
            .background(C.bg)
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resultText(_ s: Shift?) -> String {
        guard let s = s else { return "未填写" }
        return s.doneCount == s.points.count ? "已填写" : "未填写"
    }

    private func pointCard(_ p: Point) -> some View {
        Button {
            Task {
                let ok = await store.complete(p)
                app.show(ok ? "打卡成功 ✓" : "打卡失败")
                await store.load(unit: app.unit, date: app.date)
            }
        } label: {
            VStack(spacing: 3) {
                Text(p.name).font(.system(size: 14, weight: .semibold))
                    .foregroundColor(C.cyan).lineLimit(1)
                Text(p.name).font(.system(size: 11)).foregroundColor(C.sub).lineLimit(1)
                HStack(spacing: 5) {
                    Text("暂无").font(.system(size: 10)).foregroundColor(C.sub)
                    if p.isDone {
                        Text(p.timeText).font(.system(size: 10)).foregroundColor(C.cyan)
                        Text(p.worker).font(.system(size: 10)).foregroundColor(C.cyan)
                    } else {
                        Text("暂未巡检").font(.system(size: 10)).foregroundColor(C.sub)
                    }
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(p.isDone ? Color(red: 0.85, green: 0.96, blue: 0.92) : C.cardBg)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(p.isDone ? C.greenBar.opacity(0.5) : C.cardBorder, lineWidth: 1))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
