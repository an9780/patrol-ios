import Foundation

// MARK: - 通用网络层

enum APIError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let m): return m }
    }
}

/// 绝大多数接口都是 POST + form-urlencoded + header token，
/// 返回 JSON。这里统一封装，各模块只描述路径和参数。
final class Net {
    static let shared = Net()
    let base = "https://omp.gdgyep.com"

    private(set) var token = ""
    private(set) var userid = ""
    private(set) var caption = ""
    private(set) var bizid = ""
    private(set) var roleIDs: [String] = []

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 25
        cfg.timeoutIntervalForResource = 40
        return URLSession(configuration: cfg)
    }()

    func setSession(token: String, userid: String, caption: String, bizid: String) {
        self.token = token
        self.userid = userid
        self.caption = caption
        self.bizid = bizid
    }

    func clear() {
        roleIDs = []
        token = ""; userid = ""; caption = ""; bizid = ""
    }

    // MARK: 文件上传（multipart，对应 base/updateFile.do）

    struct UploadFile {
        let field: String
        let filename: String
        let mime: String
        let data: Data
    }

    func upload(_ path: String, fields: [String: String], files: [UploadFile]) async throws -> Any {
        let boundary = "----PatrolFormBoundary\(UUID().uuidString)"
        var body = Data()

        func append(_ s: String) {
            body.append(s.data(using: .utf8) ?? Data())
        }

        for (k, v) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n")
            append("\(v)\r\n")
        }
        for f in files {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(f.field)\"; filename=\"\(f.filename)\"\r\n")
            append("Content-Type: \(f.mime)\r\n\r\n")
            body.append(f.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")

        var req = URLRequest(url: URL(string: base + "/" + path)!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { req.setValue(token, forHTTPHeaderField: "token") }
        req.httpBody = body
        return try await send(req)
    }

    private func encode(_ form: [String: String]) -> Data {
        form.map { k, v in
            let ek = k.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? k
            let ev = String(describing: v)
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? v
            return "\(ek)=\(ev)"
        }
        .joined(separator: "&")
        .data(using: .utf8) ?? Data()
    }

    /// form 提交（绝大多数接口）
    func post(_ path: String, _ form: [String: String] = [:]) async throws -> Any {
        var req = URLRequest(url: URL(string: base + "/" + path)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { req.setValue(token, forHTTPHeaderField: "token") }
        req.httpBody = encode(form)
        return try await send(req)
    }

    /// JSON 提交（仅登录等少数接口）
    func postJSON(_ path: String, _ json: [String: String]) async throws -> Any {
        var req = URLRequest(url: URL(string: base + "/" + path)!)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if !token.isEmpty { req.setValue(token, forHTTPHeaderField: "token") }
        req.httpBody = try JSONSerialization.data(withJSONObject: json)
        return try await send(req)
    }

    private func send(_ req: URLRequest) async throws -> Any {
        let (data, resp) = try await Net.session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw APIError.message("无响应")
        }
        guard http.statusCode == 200 else {
            throw APIError.message("HTTP \(http.statusCode)")
        }
        // 有些接口返回 GBK，先试 UTF-8 再退 GB18030
        var text = String(data: data, encoding: .utf8)
        if text == nil {
            let gbk = CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
            text = String(data: data, encoding: String.Encoding(rawValue: gbk))
        }
        guard let s = text else { throw APIError.message("编码无法识别") }
        if let obj = try? JSONSerialization.jsonObject(with: Data(s.utf8)) {
            return obj
        }
        throw APIError.message(String(s.prefix(120)))
    }

    // MARK: 便捷取值

    static func dict(_ any: Any?) -> [String: Any] {
        (any as? [String: Any]) ?? [:]
    }

    static func array(_ any: Any?, key: String? = nil) -> [[String: Any]] {
        let value: Any?
        if let key = key {
            value = (any as? [String: Any])?[key]
        } else {
            value = any
        }
        if let rows = value as? [[String: Any]] { return rows }
        if let string = value as? String,
           let decoded = try? JSONSerialization.jsonObject(with: Data(string.utf8)) {
            return (decoded as? [[String: Any]]) ?? []
        }
        return []
    }
    static func str(_ d: [String: Any], _ k: String) -> String {
        if d[k] is NSNull { return "" }
        if let v = d[k] as? String { return v }
        if let v = d[k] { return String(describing: v) }
        return ""
    }
    static func int(_ d: [String: Any], _ k: String) -> Int {
        if let v = d[k] as? Int { return v }
        if let s = d[k] as? String, let v = Int(s) { return v }
        return 0
    }

    /// 统一成功判定：服务端不同接口返回 {"code":1} / {"status":true} / {"suc":true} / {"success":true}
    static func isOK(_ any: Any) -> Bool {
        let d = dict(any)
        if int(d, "code") == 1 { return true }
        for k in ["status", "suc", "success", "result"] {
            if let b = d[k] as? Bool, b { return true }
        }
        return false
    }

    static func message(_ any: Any) -> String {
        let d = dict(any)
        for k in ["msg", "message", "error"] {
            let s = str(d, k)
            if !s.isEmpty && s != "null" { return s }
        }
        return String(describing: any).prefix(200).description
    }
}

// MARK: - 登录

struct LoginResp {
    let token: String
    let userid: String
    let caption: String
    let bizid: String
    let roles: [String]
}

extension Net {
    func login(user: String, password: String) async throws -> LoginResp {
        let any = try await postJSON(
            "SIPAIIS_Base/j_spring_security_check",
            ["j_username": user, "j_password": password, "verCode": "64368180"]
        )
        let d = Net.dict(any)
        guard let t = d["Access_Token"] as? String, !t.isEmpty else {
            throw APIError.message("账号或密码不对")
        }
        let res = Net.dict(d["res"])
        let rolesArr = Net.array(res["roles"])
        roleIDs = rolesArr.map { Net.str($0, "id") }.filter { !$0.isEmpty }
        let roles = rolesArr.compactMap { $0["name"] as? String }
        let biz = rolesArr.map { Net.str($0, "bizid") }.first { !$0.isEmpty } ?? Net.str(res, "bizid")
        setSession(token: t,
                   userid: Net.str(res, "id"),
                   caption: Net.str(res, "caption"),
                   bizid: biz)
        return LoginResp(token: t, userid: Net.str(res, "id"),
                         caption: Net.str(res, "caption"), bizid: biz, roles: roles)
    }
}
