import SwiftUI

// MARK: - 测点历史（照 res/layout/activity_pointhistory.xml 还原）

struct PointHistoryScreen: View {
    @EnvironmentObject var app: AppState
    let pointId: String
    let pointName: String

    @State private var start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var end = Date()
    @State private var values: [(String, Double)] = []
    @State private var loading = false
    @State private var error: String?
    @State private var offset = 0

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("测点历史").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            VStack(spacing: 0) {
                // 测点名：16sp，白底，padding 8，居中
                Text(pointName.isEmpty ? "测点名称" : pointName)
                    .font(.system(size: 16)).foregroundColor(.black)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))

                // 日期行 40dp
                HStack(spacing: 0) {
                    Text(dateFmt.string(from: start))
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(hex: 0xDADDE2), lineWidth: 1))
                        .padding(5)
                    Text("至").font(.system(size: 14))
                        .frame(width: 30, height: 40)
                    Text(dateFmt.string(from: end))
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(hex: 0xDADDE2), lineWidth: 1))
                        .padding(5)
                }
                .frame(height: 40)

                // 按钮行 40dp
                HStack(spacing: 0) {
                    Button("上一天") { shift(-1) }
                        .font(.system(size: 14)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(C.blue).cornerRadius(3)
                        .padding(3)
                    Button("查询") { Task { await load() } }
                        .font(.system(size: 14)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(C.blue).cornerRadius(3)
                        .padding(3)
                    Button("下一天") { shift(1) }
                        .font(.system(size: 14)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(C.blue).cornerRadius(3)
                        .padding(3)
                }
                .frame(height: 40)

                // 折线图区
                ZStack {
                    if loading {
                        ProgressView()
                    } else if values.isEmpty {
                        EmptyHint(text: error ?? "暂无数据")
                    } else {
                        LineChartView(points: values.map { $0.1 })
                            .padding(8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
            }
            .padding(.horizontal, 0)

            Spacer(minLength: 0)
        }
        .background(Color(hex: 0xF9F9F9))
        .navigationBarHidden(true)
        .task { await load() }
    }

    private func shift(_ d: Int) {
        start = Calendar.current.date(byAdding: .day, value: d, to: start) ?? start
        end = Calendar.current.date(byAdding: .day, value: d, to: end) ?? end
        Task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/processSection/getMPointHistoryData.do",
                ["mPointId": pointId,
                 "startTime": dateFmt.string(from: start),
                 "endTime": dateFmt.string(from: end)])
            var arr: [[String: Any]] = []
            if let a = raw as? [[String: Any]] { arr = a }
            else if let d = raw as? [String: Any] {
                if let a = d["rows"] as? [[String: Any]] { arr = a }
                else if let r = d["result"] as? [String: Any],
                        let a = r["rows"] as? [[String: Any]] { arr = a }
            }
            values = arr.compactMap { d in
                let t = Net.str(d, "insdt")
                let v = Double(Net.str(d, "value")) ?? Double(Net.str(d, "mvalue")) ?? 0
                return (t, v)
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

/// 简易折线图（iOS 15 兼容）
struct LineChartView: View {
    let points: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxV = points.max() ?? 1
            let minV = points.min() ?? 0
            let span = max(maxV - minV, 0.0001)
            Path { p in
                for (i, v) in points.enumerated() {
                    let x = points.count <= 1 ? w / 2 : w * CGFloat(i) / CGFloat(points.count - 1)
                    let y = h - h * CGFloat((v - minV) / span)
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(C.blue, lineWidth: 1.5)
        }
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 3)
            .stroke(Color(hex: 0xDADDE2), lineWidth: 0.5))
    }
}
