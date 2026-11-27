import SwiftUI

// MARK: - 配色（全部取自 APK res/values/colors.xml）

enum C {
    static let bar = Color(hex: 0x2748F1)          // bar_color / task_top_blue / pro_task_tab_sel
    static let blue = Color(hex: 0x419DE4)         // blue / colorPrimary
    static let gradStart = Color(hex: 0x4C76F8)    // bg_patrol_task_detail 渐变起
    static let gradEnd = Color(hex: 0x2541EF)      // 渐变止
    static let pointUncom = Color(hex: 0xF9F9F9)   // bg_patrol_point_uncom
    static let pointCom = Color(hex: 0xE2FFFF)     // bg_patrol_point_com
    static let pointArea = Color(hex: 0x828585)    // bg_patrol_point_area
    static let errorYellow = Color(hex: 0xFF8400)  // error_yellow
    static let grayText = Color(hex: 0xA8A8A8)     // gray_text
    static let tabSel = Color(hex: 0x2748F1)       // pro_task_tab_sel
    static let tabUnsel = Color(hex: 0x797979)     // pro_task_tab_unsel
    static let doingBg = Color(hex: 0xE5F0FF)      // bg_task_doing
    static let tabTextGray = Color(hex: 0xD4DAE0)  // tab_text_gray
    static let line = Color(hex: 0xE5E5E5)
    static let text = Color.black
    static let sub = Color(hex: 0x666666)
    static let bg = Color(hex: 0xF6F6F6)
    // 兼容旧代码里的名字
    static let cyan = Color(hex: 0x419DE4)
    static let greenBar = Color(hex: 0x2748F1)
    static let cardBg = Color(hex: 0xF9F9F9)
    static let cardBorder = Color(hex: 0xE5E5E5)
    static let blueDark = Color(hex: 0x2541EF)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - 全局状态

@MainActor
final class AppState: ObservableObject {
    @Published var loggedIn = false
    @Published var caption = ""
    @Published var unit: String
    @Published var user: String
    @Published var date: String
    @Published var busy = false
    @Published var toast: String?
    @Published var tab: Int = 2          // 默认「生产监视」

    init() {
        let d = UserDefaults.standard
        unit = d.string(forKey: "unit") ?? "MM_NH11_C"
        user = d.string(forKey: "user") ?? "huangbinwei"
        date = AppState.today()
    }

    static func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    func show(_ m: String) {
        toast = m
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            if self?.toast == m { self?.toast = nil }
        }
    }

    func login(password: String) async {
        busy = true
        do {
            let r = try await Net.shared.login(user: user, password: password)
            caption = r.caption
            loggedIn = true
            UserDefaults.standard.set(user, forKey: "user")
            UserDefaults.standard.set(unit, forKey: "unit")
        } catch {
            show("登录失败：\(error.localizedDescription)")
        }
        busy = false
    }

    func logout() {
        Net.shared.clear()
        loggedIn = false
    }
}

// MARK: - 入口

@main
struct PatrolCheckinApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    @StateObject private var app = AppState()

    var body: some View {
        Group {
            if app.loggedIn { MainTabView().environmentObject(app) }
            else { LoginView().environmentObject(app) }
        }
        .overlay {
            if let t = app.toast {
                Text(t).font(.subheadline).foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color.black.opacity(0.82))
                    .cornerRadius(12)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: app.toast)
    }
}

// MARK: - 登录页（照 activity_login.xml 还原）

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var password = ""
    @State private var isInnerNet = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("moudle_ic_login_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Logo：295x100，padding 18，marginTop 70
                    Image("moudle_ipatrol_logo")
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .frame(width: 295, height: 100)
                        .padding(.top, 70)

                    // 输入区：左右 25，top 20
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Image("moudle_icon_man")
                                .resizable().scaledToFit()
                                .padding(8).frame(width: 34, height: 34)
                            TextField("", text: $app.user,
                                      prompt: Text("请输入用户名").foregroundColor(.white))
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.horizontal, 15)
                                .frame(height: 34)
                        }
                        .frame(width: 260)

                        Rectangle().fill(C.line).frame(width: 250, height: 0.3)

                        HStack(spacing: 0) {
                            Image("moudle_icon_lock")
                                .resizable().scaledToFit()
                                .padding(8).frame(width: 34, height: 34)
                            SecureField("", text: $password,
                                        prompt: Text("请输入密码").foregroundColor(.white))
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(.horizontal, 15)
                                .frame(height: 34)
                            Image("moudle_eye")
                                .resizable().scaledToFit()
                                .padding(8).frame(width: 34, height: 34)
                        }
                        .frame(width: 260)
                        .padding(.top, 25)

                        Rectangle().fill(C.line).frame(width: 250, height: 0.3)
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 20)

                    // 内网/外网
                    HStack(spacing: 17) {
                        HStack(spacing: 4) {
                            Text(isInnerNet ? "内网" : "外网")
                                .font(.system(size: 12)).foregroundColor(.white)
                            Toggle("", isOn: $isInnerNet)
                                .labelsHidden().scaleEffect(0.75)
                        }
                        .frame(width: 80, alignment: .leading)
                        Spacer()
                    }
                    .frame(width: 260)
                    .padding(.top, 15)
                    .frame(height: 40)

                    // 登录
                    Button {
                        Task { await app.login(password: password) }
                    } label: {
                        HStack(spacing: 6) {
                            if app.busy { ProgressView().tint(.white).scaleEffect(0.8) }
                            Text("登录").font(.system(size: 15)).foregroundColor(.white)
                        }
                        .frame(width: 250, height: 38)
                        .background(C.blue)
                        .cornerRadius(5)
                    }
                    .padding(.top, 22)

                    // 设置
                    Button {
                    } label: {
                        Text("设置")
                            .font(.system(size: 15)).foregroundColor(.white)
                            .frame(width: 250, height: 38)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(3)
                    }
                    .padding(.top, 12)

                    Spacer()

                    Text("本平台为互联网非涉密平台，严禁处理、传输国家秘密")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(40)

                    Spacer().frame(height: 0)

                    // 版本 + 备案号
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("v2.77")
                            .font(.system(size: 13)).foregroundColor(.white)
                        Text("ICP备案/许可证号:粤ICP备2022148356号")
                            .font(.system(size: 10)).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 15)
                    .padding(.bottom, 10)
                }
            }
        }
    }
}

// MARK: - 主框架（照 activity_main_app.xml 还原：4 个 Tab，50dp 高）

struct TabItem {
    let title: String
    let iconFull: String
    let iconEmpty: String
}

struct MainTabView: View {
    @EnvironmentObject var app: AppState

    private let tabs = [
        TabItem(title: "主页", iconFull: "moudle_tab_main_full", iconEmpty: "moudle_tab_main_empty"),
        TabItem(title: "异常处理", iconFull: "moudle_tab_fault_full", iconEmpty: "moudle_tab_fault_empty"),
        TabItem(title: "生产监视", iconFull: "moudle_tab_pro_full", iconEmpty: "moudle_tab_pro_empty"),
        TabItem(title: "我的", iconFull: "moudle_tab_self_full", iconEmpty: "moudle_tab_self_empty"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch app.tab {
                case 0: HomeScreen()
                case 1: FaultScreen()
                case 3: MoreScreen()
                default: PatrolScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                ForEach(0..<4) { i in
                    Button {
                        app.tab = i
                    } label: {
                        VStack(spacing: 0) {
                            Image(app.tab == i ? tabs[i].iconFull : tabs[i].iconEmpty)
                                .resizable().scaledToFit()
                                .frame(height: 26)
                                .padding(.horizontal, 4)
                            Text(tabs[i].title)
                                .font(.system(size: 11))
                                .foregroundColor(app.tab == i ? .black : C.tabTextGray)
                                .frame(height: 18)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 50)
            .background(Color.white)
        }
    }
}

// MARK: - 主页


// MARK: - 通用组件

struct BlueHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        ZStack {
            C.bar
            Text(title)
                .font(.system(size: 15)).foregroundColor(.white)
            HStack {
                Spacer()
                if let t = trailing { t }
            }
            .padding(.trailing, 12)
        }
        .frame(height: 50)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(color.opacity(0.12))
            .cornerRadius(11)
    }
}

struct EmptyHint: View {
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.largeTitle).foregroundColor(C.grayText)
            Text(text).font(.subheadline).foregroundColor(C.grayText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

struct LoadableList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    let empty: String
    let row: (Item) -> Row

    init(items: [Item], empty: String, @ViewBuilder row: @escaping (Item) -> Row) {
        self.items = items
        self.empty = empty
        self.row = row
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if items.isEmpty {
                    EmptyHint(text: empty)
                } else {
                    ForEach(items) { i in row(i) }
                }
            }
            .padding(12)
        }
        .background(C.bg)
    }
}
