import SwiftUI

// MARK: - 配色（照原版）

enum C {
    static let blue = Color(red: 0.13, green: 0.25, blue: 0.78)
    static let blueDark = Color(red: 0.10, green: 0.19, blue: 0.62)
    static let greenBar = Color(red: 0.30, green: 0.78, blue: 0.55)
    static let cardBg = Color(red: 0.90, green: 0.97, blue: 0.98)
    static let cardBorder = Color(red: 0.72, green: 0.90, blue: 0.93)
    static let cyan = Color(red: 0.42, green: 0.75, blue: 0.83)
    static let text = Color(red: 0.11, green: 0.13, blue: 0.17)
    static let sub = Color(red: 0.46, green: 0.50, blue: 0.56)
    static let bg = Color(red: 0.96, green: 0.97, blue: 0.99)
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

// MARK: - 登录页

struct LoginView: View {
    @EnvironmentObject var app: AppState
    @State private var password = ""

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                LinearGradient(colors: [C.blue, C.blueDark], startPoint: .top, endPoint: .bottom)
                    .frame(height: 190)
                    .overlay {
                        VStack(spacing: 6) {
                            Text("生产巡检").font(.title2).bold().foregroundColor(.white)
                            Text("SIPAIIS · 移动巡检").font(.caption)
                                .foregroundColor(.white.opacity(0.75))
                        }
                    }

                VStack(spacing: 14) {
                    input("账号", $app.user, secure: false)
                    input("密码", $password, secure: true)
                    input("单位", $app.unit, secure: false)

                    Button {
                        Task { await app.login(password: password) }
                    } label: {
                        HStack {
                            Text("登 录").font(.headline)
                            if app.busy { ProgressView().tint(.white) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(C.blue).foregroundColor(.white).cornerRadius(8)
                    }
                    .disabled(app.busy || password.isEmpty)
                    .opacity(password.isEmpty ? 0.55 : 1)
                }
                .padding(20).background(Color.white).cornerRadius(12)
                .padding(.horizontal, 20).offset(y: -40)

                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private func input(_ label: String, _ text: Binding<String>, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundColor(C.sub)
            Group {
                if secure { SecureField(label, text: text) }
                else { TextField(label, text: text).autocapitalization(.none)
                        .disableAutocorrection(true) }
            }
            .padding(11)
            .background(Color(red: 0.97, green: 0.98, blue: 0.99))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .stroke(Color(red: 0.89, green: 0.91, blue: 0.94)))
        }
    }
}

// MARK: - 主框架

struct MainTabView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView {
            PatrolScreen().tabItem { Label("巡检", systemImage: "checklist") }
            FaultScreen().tabItem { Label("故障", systemImage: "exclamationmark.triangle") }
            MaintainScreen().tabItem { Label("维保", systemImage: "wrench.and.screwdriver") }
            AlarmScreen().tabItem { Label("报警", systemImage: "bell") }
            MoreScreen().tabItem { Label("更多", systemImage: "ellipsis.circle") }
        }
        .accentColor(C.blue)
    }
}

// MARK: - 通用小组件

struct BlueHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                if let s = subtitle {
                    Text(s).font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                }
            }
            Spacer()
            if let t = trailing { t }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(C.blue)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(10)
    }
}

struct EmptyHint: View {
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.largeTitle).foregroundColor(C.sub.opacity(0.5))
            Text(text).font(.subheadline).foregroundColor(C.sub)
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
            LazyVStack(spacing: 8) {
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
