import SwiftUI

// MARK: - 我的（照 res/layout/fragment_fifth.xml 还原）

struct MyScreen: View {
    @EnvironmentObject var app: AppState
    @AppStorage("alarmSoundEnabled") private var voiceOn = true
    @State private var showAbout = false
    @State private var showKnowledge = false
    @State private var confirmExit = false

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
                        Text("登录时长：  " + (app.totalLoginHours.isEmpty ? "—" : app.totalLoginHours + " 小时"))
                            .font(.system(size: 12)).foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("上次登录：  " + app.lastLogin)
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
                            Text("报警声音")
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

                        menuRow("退出", "moudle_exit", showArrow: true) { confirmExit = true }
                    }
                    .background(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                    Spacer(minLength: 30)
                }
            }
        }
        .navigationBarHidden(true)
        .confirmationDialog("是否确认退出？", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("退出", role: .destructive) { app.logout() }
            Button("取消", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showAbout) {
            AboutScreen()
        }
        .fullScreenCover(isPresented: $showKnowledge) {
            NavigationView {
                KnowledgeTreeScreen()
                    .environmentObject(app)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("返回") { showKnowledge = false }
                        }
                    }
            }
            .navigationViewStyle(.stack)
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

