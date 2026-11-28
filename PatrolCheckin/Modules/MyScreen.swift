import SwiftUI

// MARK: - 我的（照 res/layout/fragment_fifth.xml 还原）
// 原版菜单仅 4 项：关于软件 / 知识库 / 语音播报 / 切换登录
// 其余功能统一收进「更多功能」，保证原页 1:1

struct MyScreen: View {
    @EnvironmentObject var app: AppState
    @State private var voiceOn = true
    @State private var showAbout = false
    @State private var showKnowledge = false
    @State private var showMore = false

    private let titleColor = Color(hex: 0x373A3D)
    private let lineColor = Color(hex: 0xE5E5E5)

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xF5F7FA).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        Image("moudle_fifth_fg_bg")
                            .resizable().scaledToFill()
                            .frame(height: 165).clipped()

                        HStack(spacing: 12) {
                            Image("moudle_ic_default_man")
                                .resizable().scaledToFill()
                                .frame(width: 55, height: 55)
                                .clipShape(Circle())
                            Spacer()
                        }
                        .padding(.leading, 20)
                        .padding(.top, 90)
                    }

                    VStack(spacing: 0) {
                        Spacer()
                        Text(app.caption.isEmpty ? app.user : app.caption)
                            .font(.system(size: 14)).foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("累计登录时长 0 分钟")
                            .font(.system(size: 12)).foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("最近登录 " + app.date)
                            .font(.system(size: 12)).foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 132)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))
                    .padding(.horizontal, 10)
                    .padding(.top, -20)

                    VStack(spacing: 0) {
                        menuRow("关于软件", "moudle_about", showArrow: true) { showAbout = true }
                        divider
                        menuRow("知识库", "moudle_doc", showArrow: true) { showKnowledge = true }
                        divider

                        HStack(spacing: 0) {
                            Image("moudle_ic_voice")
                                .resizable().scaledToFit()
                                .padding(13).frame(width: 44, height: 44)
                            Text("语音播报")
                                .font(.system(size: 14)).foregroundColor(titleColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Toggle("", isOn: $voiceOn)
                                .labelsHidden().scaleEffect(0.8)
                                .frame(width: 80)
                        }
                        .frame(height: 44)
                        divider

                        menuRow("切换登录", "moudle_switch", showArrow: true) { app.logout() }
                        divider

                        // 附加入口（原版无此项，集中收纳其他功能）
                        menuRow("更多功能", "moudle_doc", showArrow: true) { showMore = true }
                    }
                    .background(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                    Spacer(minLength: 30)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAbout) {
            NavigationView { AboutScreen() }
        }
        .sheet(isPresented: $showKnowledge) {
            NavigationView { KnowledgeTreeScreen().environmentObject(app) }
        }
        .sheet(isPresented: $showMore) {
            NavigationView { MoreFeaturesScreen().environmentObject(app) }
        }
    }

    private var divider: some View {
        Rectangle().fill(lineColor).frame(height: 0.6)
    }

    private func menuRow(_ title: String, _ icon: String,
                         showArrow: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Image(icon)
                    .resizable().scaledToFit()
                    .padding(13).frame(width: 44, height: 44)
                Text(title)
                    .font(.system(size: 14)).foregroundColor(titleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showArrow {
                    Image("moudle_arrow_to_next")
                        .resizable().scaledToFit()
                        .padding(15).frame(width: 44, height: 44)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 更多功能（收纳非原版主菜单的业务入口）

struct MoreFeaturesScreen: View {
    @EnvironmentObject var app: AppState
    @Environment(\.presentationMode) private var presentation

    @State private var showSchedules = false
    @State private var showScheduleCreate = false
    @State private var showSpare = false
    @State private var showSettings = false
    @State private var showChangePwd = false
    @State private var showEndpoints = false

    private let titleColor = Color(hex: 0x373A3D)

    var body: some View {
        List {
            row("排班管理") { showSchedules = true }
            row("新建调度") { showScheduleCreate = true }
            row("备件") { showSpare = true }
            row("设置") { showSettings = true }
            row("修改密码") { showChangePwd = true }
            row("接口总览") { showEndpoints = true }
        }
        .listStyle(.plain)
        .navigationTitle("更多功能")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { presentation.wrappedValue.dismiss() }
            }
        }
        .sheet(isPresented: $showSchedules) {
            NavigationView { ScheduleListScreen().environmentObject(app) }
        }
        .sheet(isPresented: $showScheduleCreate) {
            NavigationView { ScheduleCreateScreen().environmentObject(app) }
        }
        .sheet(isPresented: $showSpare) {
            NavigationView { SparePartScreen().environmentObject(app) }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView { SettingsScreen().environmentObject(app) }
        }
        .sheet(isPresented: $showChangePwd) {
            NavigationView { ChangePasswordScreen().environmentObject(app) }
        }
        .sheet(isPresented: $showEndpoints) {
            NavigationView { EndpointListScreen().environmentObject(app) }
        }
    }

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 15)).foregroundColor(titleColor)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundColor(C.sub)
            }
        }
    }
}
