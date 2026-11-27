import SwiftUI
import WebKit

// MARK: - 设置

struct SettingsScreen: View {
    @EnvironmentObject var app: AppState
    @State private var showChangePwd = false
    @State private var showAbout = false

    var body: some View {
        List {
            Section(header: Text("账号")) {
                HStack {
                    Text("姓名"); Spacer()
                    Text(app.caption).foregroundColor(C.sub)
                }
                HStack {
                    Text("账号"); Spacer()
                    Text(app.user).foregroundColor(C.sub)
                }
                HStack {
                    Text("单位"); Spacer()
                    Text(app.unit).foregroundColor(C.sub)
                }
            }
            Section(header: Text("操作")) {
                Button("修改密码") { showChangePwd = true }
                Button("关于软件") { showAbout = true }
            }
            Section {
                Button("退出登录", role: .destructive) { app.logout() }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .sheet(isPresented: $showChangePwd) {
            ChangePasswordScreen().environmentObject(app)
        }
        .sheet(isPresented: $showAbout) {
            AboutScreen()
        }
    }
}

struct ChangePasswordScreen: View {
    @EnvironmentObject var app: AppState
    @Environment(\.presentationMode) private var presentation

    @State private var oldPwd = ""
    @State private var newPwd = ""
    @State private var confirmPwd = ""
    @State private var busy = false
    @State private var message: String?
    @State private var ok = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("原密码")) {
                    SecureField("原密码", text: $oldPwd)
                }
                Section(header: Text("新密码")) {
                    SecureField("新密码（8-20位，含字母数字符号）", text: $newPwd)
                    SecureField("确认新密码", text: $confirmPwd)
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Text(ok ? "修改成功" : "确认修改")
                            if busy { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(busy || oldPwd.isEmpty || newPwd.isEmpty || newPwd != confirmPwd)
                    if let m = message {
                        Text(m).font(.footnote).foregroundColor(ok ? .green : .red)
                    }
                }
            }
            .navigationTitle("修改密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { presentation.wrappedValue.dismiss() }
                }
            }
        }
    }

    private func submit() async {
        guard newPwd == confirmPwd else { message = "两次密码不一致"; return }
        busy = true
        message = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Base/user/saveChangePassword.do",
                ["oldPassword": oldPwd, "newPassword": newPwd, "userid": Net.shared.userid])
            let d = Net.dict(raw)
            let success = Net.isOK(raw)
            ok = success
            message = success ? "密码已修改" : (Net.str(d, "msg").isEmpty
                                              ? String(describing: raw).prefix(120).description
                                              : Net.str(d, "msg"))
        } catch {
            message = error.localizedDescription
        }
        busy = false
    }
}

struct AboutScreen: View {
    @Environment(\.presentationMode) private var presentation

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("名称"); Spacer()
                        Text("巡检打卡（iOS）").foregroundColor(C.sub)
                    }
                    HStack {
                        Text("版本"); Spacer()
                        Text("1.0").foregroundColor(C.sub)
                    }
                    HStack {
                        Text("服务端"); Spacer()
                        Text("omp.gdgyep.com").foregroundColor(C.sub)
                    }
                    HStack {
                        Text("接口数"); Spacer()
                        Text("\(Endpoints.all.count)").foregroundColor(C.sub)
                    }
                }
                Section(header: Text("说明")) {
                    Text("按原安卓版功能重写，不含大华视频、ArcGIS 地图、NFC 刷卡模块。")
                        .font(.footnote).foregroundColor(C.sub)
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { presentation.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// MARK: - 内置网页（ChatWebActivity / GuideMenuActivity）

struct WebScreen: View {
    let urlString: String
    let title: String

    var body: some View {
        WebView(urlString: urlString)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView()
        w.allowsBackForwardNavigationGestures = true
        if let u = URL(string: urlString) {
            w.load(URLRequest(url: u))
        }
        return w
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - 知识库分类树

struct KnowledgeTreeScreen: View {
    @EnvironmentObject var app: AppState
    @State private var types: [FormOption] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if types.isEmpty {
                EmptyHint(text: error ?? "暂无知识分类")
            } else {
                List(types) { t in
                    NavigationLink {
                        KnowledgeDocScreen(typeId: t.id, typeName: t.name)
                    } label: {
                        Label(t.name, systemImage: "folder")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(C.bg)
        .navigationTitle("知识库")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_LIBRARY/knowledgeType/tree", ["active": "1"])
            var arr: [[String: Any]] = []
            if let a = raw as? [[String: Any]] {
                arr = a
            } else if let d = raw as? [String: Any] {
                for k in ["result", "rows", "data", "list"] {
                    if let a = d[k] as? [[String: Any]] { arr = a; break }
                }
            }
            types = arr.compactMap {
                let id = Net.str($0, "id")
                let name = Net.str($0, "name")
                if id.isEmpty { return nil }
                return FormOption(id: id, name: name.isEmpty ? id : name)
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - 知识库文档

struct KnowledgeDocScreen: View {
    @EnvironmentObject var app: AppState
    let typeId: String
    let typeName: String

    @State private var rows: [GenericRow] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if rows.isEmpty {
                EmptyHint(text: error ?? "该分类下暂无文档")
            } else {
                LoadableList(items: rows, empty: "暂无文档") { r in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            Image("icon_statement")
                                .resizable().scaledToFit()
                                .padding(2).frame(width: 20, height: 20)
                            Text(r.status)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: 0x9A9B9C))
                                .frame(height: 20, alignment: .center)
                            Spacer()
                        }
                        .frame(height: 20)
                        Text(r.title)
                            .font(.system(size: 16)).foregroundColor(.black)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(r.subtitle)
                            .font(.system(size: 13)).foregroundColor(C.grayText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                }
            }
        }
        .background(C.bg)
        .navigationTitle(typeName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_LIBRARY/knowledge/searchDocument",
                ["typeId": typeId, "page": "1", "rows": "100", "status": "1"])
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                for k in ["rows", "result", "list", "data"] {
                    if let a = d[k] as? [[String: Any]] { arr = a; break }
                    if let sub = d[k] as? [String: Any], let a = sub["rows"] as? [[String: Any]] {
                        arr = a; break
                    }
                }
            }
            rows = arr.enumerated().map { GenericRow.from($0.element, index: $0.offset) }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - 设备查询

struct EquipmentSearchScreen: View {
    @EnvironmentObject var app: AppState
    @State private var keyword = ""
    @State private var rows: [GenericRow] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(C.sub)
                TextField("设备名称", text: $keyword)
                    .font(.system(size: 15))
                    .onSubmit { Task { await search() } }
                if !keyword.isEmpty {
                    Button {
                        keyword = ""; Task { await search() }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(C.sub)
                    }
                }
            }
            .padding(10).background(Color.white).cornerRadius(8)
            .padding(12)

            if loading {
                ProgressView().padding(.top, 50); Spacer()
            } else if rows.isEmpty {
                EmptyHint(text: error ?? "输入设备名搜索")
            } else {
                LoadableList(items: rows, empty: "无结果") { r in
                    HStack(spacing: 10) {
                        Image(systemName: "square.stack.3d.up").foregroundColor(C.blue)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.title).font(.system(size: 15)).foregroundColor(C.text)
                            if !r.subtitle.isEmpty {
                                Text(r.subtitle).font(.system(size: 11)).foregroundColor(C.sub)
                            }
                        }
                        Spacer()
                    }
                    .padding(11).background(Color.white).cornerRadius(6)
                }
            }
        }
        .background(C.bg)
        .navigationTitle("设备查询")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func search() async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/equipment/getList.do",
                ["unitId": app.unit, "search_name": keyword, "page": "1", "rows": "100"])
            var arr: [[String: Any]] = []
            if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { arr = a }
                else if let sub = d["result"] as? [String: Any],
                        let a = sub["rows"] as? [[String: Any]] { arr = a }
            }
            rows = arr.enumerated().map { GenericRow.from($0.element, index: $0.offset) }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
