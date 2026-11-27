import SwiftUI

// MARK: - 我的（照 res/layout/fragment_fifth.xml 还原）

struct MyScreen: View {
    @EnvironmentObject var app: AppState
    @State private var voiceOn = true
    @State private var showAbout = false
    @State private var showKnowledge = false
    @State private var showSchedule = false

    private let titleColor = Color(hex: 0x373A3D)
    private let lineColor = Color(hex: 0xE5E5E5)

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: 0xF5F7FA).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部 165dp 背景图 + 头像 + 信息卡
                    ZStack(alignment: .top) {
                        Image("moudle_fifth_fg_bg")
                            .resizable().scaledToFill()
                            .frame(height: 165).clipped()

                        VStack(spacing: 0) {
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
                    }

                    // 信息卡 132dp
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

                    // 菜单
                    VStack(spacing: 0) {
                        menuRow("新建调度", "moudle_doc", showArrow: true) { showSchedule = true }
                        divider
                        menuRow("关于软件", "moudle_about", showArrow: true) { showAbout = true }
                        divider
                        menuRow("知识库", "moudle_doc", showArrow: true) { showKnowledge = true }
                        divider

                        // 语音播报（开关）
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
        .sheet(isPresented: $showSchedule) {
            NavigationView { ScheduleCreateScreen().environmentObject(app) }
        }
        .sheet(isPresented: $showKnowledge) {
            NavigationView { KnowledgeTreeScreen().environmentObject(app) }
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
