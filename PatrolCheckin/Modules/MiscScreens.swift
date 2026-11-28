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
    @State private var query = ""
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
                    NavigationLink {
                        KnowledgeAttachmentScreen(documentID: Net.str(r.raw, "id"), title: r.title)
                    } label: {
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
                    .buttonStyle(.plain)
                    .disabled(Net.str(r.raw, "id").isEmpty)
                }
            }
        }
        .background(C.bg)
        .navigationTitle(typeName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "搜索文档")
        .onSubmit(of: .search) { Task { await load() } }
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        rows = []
        do {
            let raw = try await Net.shared.get(
                "SIPAIIS_LIBRARY/knowledge/searchDocument",
                ["typeId": typeId, "page": "1", "rows": "100", "status": "1",
                 "roleIds": Net.shared.roleIDs.joined(separator: ","),
                 "versiontag": "latest", "comment": query, "sort": "insdt", "isAsc": "false"])
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
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var equipmentClass = ""
    @State private var classes: [FormOption] = []
    @State private var rows: [[String: Any]] = []
    @State private var page = 0
    @State private var hasMore = false
    @State private var activeKeyword = ""
    @State private var loading = false
    @State private var error: String?

    private let pageSize = 20

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "arrow.left").foregroundColor(.white)
                }
                .accessibilityLabel("返回")
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(C.sub)
                    TextField("点击输入名称搜索", text: $keyword)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                }
                .padding(8).background(Color.white).clipShape(Capsule())
                Button("搜索") { Task { await search() } }
                    .foregroundColor(.white).disabled(loading)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(C.bar)
            Menu {
                Button("全部") { selectClass("") }
                ForEach(classes) { item in
                    Button(item.name) { selectClass(item.id) }
                }
            } label: {
                HStack {
                    Text(classes.first { $0.id == equipmentClass }?.name ?? "全部")
                    Spacer()
                    Image(systemName: "chevron.down").foregroundColor(C.sub)
                }
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(Color.white)
            }
            .disabled(loading)
            .padding(8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        let name = Net.str(row, "equipmentname")
                        NavigationLink {
                            EquipmentCardScreen(equipment: row)
                        } label: {
                            equipmentRow(row, name: name)
                        }
                        .buttonStyle(.plain)
                    }
                    if loading { ProgressView().padding() }
                    if let error = error {
                        Text(error).foregroundColor(C.sub).padding(8)
                        Button("重试") { Task { await search() } }
                    } else if rows.isEmpty && !loading {
                        EmptyHint(text: "暂无设备")
                    }
                    if hasMore && !loading {
                        Button("加载更多") { Task { await search(nextPage: true) } }
                            .padding(8)
                    }
                }
                .padding(.horizontal, 7)
            }
            .refreshable { await search() }
        }
        .background(C.bg)
        .navigationBarHidden(true)
        .task(id: app.unit) {
            async let list: Void = search()
            async let filters: Void = loadClasses()
            _ = await (list, filters)
        }
    }

    private func selectClass(_ id: String) {
        equipmentClass = id
        Task { await search() }
    }

    private func equipmentRow(_ row: [String: Any], name: String) -> some View {
        let level = Net.str(Net.dict(row["equipmentLevel"]), "levelname")
        let configuredType = Net.str(Net.dict(row["equipmentTypeNumber"]), "name")
        let type = configuredType.isEmpty ? Net.str(Net.dict(row["equipmentClass"]), "name") : configuredType
        let section = Net.str(Net.dict(row["processSection"]), "name")
        let statuses = ["0": "停用", "1": "在用", "2": "封存", "3": "报废待处理"]
        let status = statuses[Net.str(row, "equipmentstatus")] ?? "未知"
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(name).font(.system(size: 17))
                Spacer(minLength: 6)
                if !level.isEmpty { badge(level, color: .red) }
                badge(status, color: status == "在用" ? .green : .gray)
            }
            .padding(12)
            Divider()
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    equipmentField("设备编号", Net.str(row, "equipmentcardid"))
                    equipmentField("工艺位置", section)
                    equipmentField("制造厂家", Net.str(row, "equipmentmanufacturer"), fallback: "厂商暂未录入")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    equipmentField("设备类型", type)
                    equipmentField("规格型号", Net.str(row, "equipmentmodelname"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
        .foregroundColor(.black)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }

    private func badge(_ name: String, color: Color) -> some View {
        Text(name)
            .font(.system(size: 13))
            .foregroundColor(color)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(color.opacity(0.16)).cornerRadius(4)
    }

    private func equipmentField(_ label: String, _ value: String, fallback: String = "暂未配置") -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 13)).foregroundColor(C.sub)
            Text(value.isEmpty || value == "null" ? fallback : value)
                .font(.system(size: 14))
        }
    }

    private func loadClasses() async {
        do {
            let data = try await Net.shared.get(
                "SIPAIIS_Equipment/equipment/equipmentClass/getEquipmentClassTree.do", [:])
            classes = FormOption.treeOptions(from: data, users: false)
        } catch {
            classes = []
        }
    }

    private func search(nextPage: Bool = false) async {
        guard !loading else { return }
        let requestedPage = nextPage ? page + 1 : 1
        let query = nextPage ? activeKeyword : keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        loading = true
        error = nil
        defer { loading = false }
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Equipment/equipment/getList.do",
                ["unitId": app.unit, "search_name": query, "page": String(requestedPage),
                 "rows": String(pageSize), "pSectionId": "", "equipmentCardClass": equipmentClass,
                 "sort": "insdt", "order": "desc"])
            try Task.checkCancellation()
            let root = Net.dict(raw)
            let result = Net.dict(root["result"])
            guard let records = root["rows"] ?? result["rows"], !(records is NSNull) else {
                throw APIError.message(Net.message(raw))
            }
            let received = Net.array(records)
            var current = nextPage ? rows : []
            var ids = Set(current.map { Net.str($0, "id") })
            current.append(contentsOf: received.filter {
                let id = Net.str($0, "id")
                return !id.isEmpty && ids.insert(id).inserted
            })
            rows = current
            page = requestedPage
            activeKeyword = query
            let total = max(Net.int(root, "total"), Net.int(result, "total"))
            hasMore = !received.isEmpty && (total > 0 ? page * pageSize < total : received.count == pageSize)
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }
}
