import SwiftUI

// MARK: - 主页（严格照 res/layout/fragment_main.xml 还原）

@MainActor
final class HomeStore: ObservableObject {
    @Published var loadError: String?
    @Published var total = 0
    @Published var unsubmitted = 0
    @Published var submitted = 0
    @Published var currentTask = ""
    @Published var duration = ""

    func load(unit: String, date: String) async {
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Patrol/timeEfficiency/patrolRecord/getPatrolRecord4APP.do",
                ["unitId": unit, "userid": Net.shared.userid, "type": "P",
                 "patrolDate": date, "page": "1", "rows": "100"])
            guard let tasks = Net.dict(raw)["content1"], !(tasks is NSNull) else {
                throw APIError.message("服务未返回今日任务")
            }
            let arr = Net.array(tasks)
            total = arr.count
            var done = 0
            for t in arr {
                let st = Net.str(t, "status")
                if st == "3" || st == "4" { done += 1 }
            }
            submitted = done
            unsubmitted = max(0, total - done)
            loadError = nil
            currentTask = ""
            duration = ""
            let clock = DateFormatter()
            clock.locale = Locale(identifier: "en_US_POSIX")
            clock.timeZone = TimeZone(identifier: "Asia/Shanghai")
            clock.dateFormat = "yyyy-MM-dd HH:mm"
            let now = clock.string(from: Date())
            if let cur = arr.first(where: {
                let start = Net.str($0, "startTime").replacingOccurrences(of: "T", with: " ")
                let end = Net.str($0, "endTime").replacingOccurrences(of: "T", with: " ")
                return start.count >= 16 && end.count >= 16
                    && String(start.prefix(16)) <= now && now < String(end.prefix(16))
            }) {
                currentTask = Net.str(cur, "name")
                let s = Net.str(cur, "startTime")
                let e = Net.str(cur, "endTime")
                if s.count >= 16 && e.count >= 16 {
                    duration = String(s.dropFirst(11).prefix(5)) + " — " + String(e.dropFirst(11).prefix(5))
                }
            }
        } catch { loadError = error.localizedDescription }
    }
}

struct HomeScreen: View {
    @EnvironmentObject var app: AppState
    @StateObject private var store = HomeStore()
    @State private var showPatrol = false
    @State private var showAlarm = false
    @State private var showMaintain = false
    @State private var showReport = false
    @State private var showEquSearch = false
    @State private var showDispatch = false
    @State private var showPlants = false
    @State private var selectedPlant = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── 顶部 160dp 背景 ──
                ZStack(alignment: .top) {
                    Image("moudle_main_title_bg")
                        .resizable().scaledToFill()
                        .frame(height: 160).clipped()

                    VStack(spacing: 0) {
                        // 当前厂区 30dp
                        Button {
                            selectedPlant = app.unit
                            showPlants = true
                        } label: {
                            HStack(spacing: 0) {
                            Text("当前厂区")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.5))
                                .frame(width: 72, height: 30)
                            Rectangle().fill(Color.white).frame(width: 1, height: 30)
                            Text(app.unitName)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(.leading, 5)
                                .lineLimit(1)
                            Spacer()
                            Image("moudle_location")
                                .resizable().scaledToFit()
                                .padding(4).frame(width: 30, height: 30)
                                .padding(.trailing, 8)
                        }
                            .frame(height: 36)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)

                        // 三个计数 75dp
                        HStack(spacing: 0) {
                            Spacer().frame(width: 20)
                            stat("今日任务", "moudle_all_count", store.total)
                            Spacer().frame(width: 15)
                            stat("未提交", "moudle_uncom_count", store.unsubmitted)
                            Spacer().frame(width: 10)
                            stat("已提交", "moudle_com_count", store.submitted)
                            Spacer().frame(width: 10)
                        }
                        .frame(height: 75)
                        .padding(.top, 10)
                    }
                }

                if let error = store.loadError {
                    Button("任务加载失败：\(error) · 重试") {
                        Task { await store.load(unit: app.unit, date: app.date) }
                    }.font(.footnote)
                }
                // ── 当前任务卡 ──
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("当前任务: ")
                            .font(.system(size: 13)).foregroundColor(.black)
                        Text(store.duration.isEmpty ? "暂无" : store.duration)
                            .font(.system(size: 12)).foregroundColor(Color(hex: 0x808388))
                        Spacer()
                    }
                    .frame(height: 28)

                    HStack(spacing: 0) {
                        Text("任务")
                            .font(.system(size: 12)).foregroundColor(.black)
                        Text(store.currentTask.isEmpty ? "暂无任务" : store.currentTask)
                            .font(.system(size: 12)).foregroundColor(Color(hex: 0x808388))
                            .padding(.leading, 4)
                        Spacer()
                    }
                    .frame(height: 28)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(4)
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                .padding(.horizontal, 10)
                .padding(.top, 10).padding(.bottom, 5)

                // ── 第一行模块（60dp，4 个）──
                HStack(spacing: 0) {
                    module("巡检任务", "moudle_fg_main_patrol") { showPatrol = true }
                    module("异常上报", "moudle_fg_main_fault") { showReport = true }
                    module("调度申请", "moudle_fg_main_data") { showDispatch = true }
                    module("设备查询", "moudle_fg_main_equ") { showEquSearch = true }
                }
                .frame(height: 60)
                .padding(.top, 10).padding(.bottom, 10)

                // ── 第二行模块 ──
                HStack(spacing: 0) {
                    module("历史报警", "moudle_fg_main_alarm") { showAlarm = true }
                    module("保养工单", "moudle_fg_main_com_adj") { showMaintain = true }
                }
                .frame(height: 60)
                .padding(.bottom, 10)

                HomePlantReadings(unit: app.unit)
            }
        }
        .background(C.bg)
        .navigationBarHidden(true)
        .sheet(isPresented: $showPatrol) { PatrolScreen().environmentObject(app) }
        .sheet(isPresented: $showReport) { FaultReportScreen().environmentObject(app) }
        .sheet(isPresented: $showAlarm) { AlarmScreen().environmentObject(app) }
        .sheet(isPresented: $showMaintain) { MaintainScreen().environmentObject(app) }
        .sheet(isPresented: $showEquSearch) {
            NavigationView { EquipmentSearchScreen().environmentObject(app) }
        }
        .sheet(isPresented: $showDispatch) {
            NavigationView { ScheduleListScreen().environmentObject(app) }
        }
        .sheet(isPresented: $showPlants) {
            VStack(spacing: 12) {
                HStack {
                    Button("取消") { showPlants = false }.foregroundColor(C.sub)
                    Spacer()
                    Button("完成") {
                        if !selectedPlant.isEmpty { app.unit = selectedPlant }
                        showPlants = false
                    }.disabled(selectedPlant.isEmpty)
                }
                .padding(16)
                if app.loadingPlants {
                    ProgressView()
                } else if let error = app.plantError, app.plants.isEmpty {
                    Text(error).foregroundColor(C.sub)
                    Button("重试") { Task { await app.loadPlants() } }
                } else {
                    ForEach(app.plants) { plant in
                        Button {
                            selectedPlant = plant.id
                        } label: {
                            HStack {
                                Text(plant.name)
                                Spacer()
                                if selectedPlant == plant.id { Image(systemName: "checkmark") }
                            }
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                        }
                        Divider()
                    }
                }
                Spacer()
            }
            .modifier(PlantSheetHeight())
        }
        .task(id: app.unit) { await store.load(unit: app.unit, date: app.date) }
    }

    private func stat(_ title: String, _ icon: String, _ value: Int) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Image(icon).resizable().scaledToFit()
                    .padding(.horizontal, 5).padding(.top, 8)
                    .frame(height: 55)
                Text(title)
                    .font(.system(size: 12)).foregroundColor(.white)
                    .frame(height: 15)
            }
            .frame(maxWidth: .infinity)
            Text(store.loadError == nil ? String(value) : "—")
                .font(.system(size: 26)).foregroundColor(.white)
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 70)
        .frame(maxWidth: .infinity)
    }

    private func module(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(icon).resizable().scaledToFit()
                    .padding(2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(title)
                    .font(.system(size: 12)).foregroundColor(.black)
                    .frame(height: 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}


private struct PlantSheetHeight: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium, .large])
        } else {
            content
        }
    }
}
