import SwiftUI

struct PointHistoryScreen: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let pointId: String
    let pointName: String

    @State private var interval: DateInterval
    @State private var query: DateInterval
    @State private var reloadCount = 0
    @State private var samples: [HistorySample] = []
    @State private var loading = true
    @State private var error: String?
    @State private var editingDate: DateBoundary?
    @State private var draftDate = Date()

    private enum DateBoundary: String, Identifiable {
        case start = "开始时间"
        case end = "结束时间"
        var id: Self { self }
    }

    private static let zone = TimeZone(identifier: "Asia/Shanghai") ?? .current
    private static let timestamp = formatter("yyyy-MM-dd HH:mm:ss")

    init(pointId: String, pointName: String) {
        self.pointId = pointId
        self.pointName = pointName
        let now = Date()
        let window = DateInterval(start: now.addingTimeInterval(-86_400), end: now)
        _interval = State(initialValue: window)
        _query = State(initialValue: window)
    }

    var body: some View {
        VStack(spacing: 8) {
            BlueHeader(title: "历史曲线", back: { dismiss() })
            Text(pointName).font(.system(size: 16)).foregroundColor(C.sub)
            HStack(spacing: 4) {
                dateControl(.start, date: interval.start)
                Text("至").font(.footnote).foregroundColor(C.sub)
                dateControl(.end, date: interval.end)
            }
            .padding(.horizontal, 8)
            HStack(spacing: 8) {
                action("上一天") { shift(-1) }
                action("查询") { runQuery() }
                action("下一天") { shift(1) }
            }
            .padding(.horizontal, 8)
            Group {
                if loading {
                    ProgressView()
                } else if samples.isEmpty {
                    EmptyHint(text: error ?? "该时段暂无历史数据")
                } else {
                    HistoryChart(samples: samples)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.24), lineWidth: 0.5))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .environment(\.timeZone, Self.zone)
        .background(C.bg)
        .navigationBarHidden(true)
        .task(id: reloadCount) { await load(window: query) }
        .sheet(item: $editingDate) { boundary in
            VStack(spacing: 16) {
                BlueHeader(title: "选择" + boundary.rawValue, back: { editingDate = nil })
                DatePicker(boundary.rawValue, selection: $draftDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.wheel)
                action("确定") {
                    updateDate(draftDate, start: boundary == .start)
                    editingDate = nil
                }
                .padding(.horizontal, 16)
                Spacer()
            }
            .environment(\.timeZone, Self.zone)
        }
    }

    private func dateControl(_ boundary: DateBoundary, date: Date) -> some View {
        let label = Self.timestamp.string(from: date)
        return Button {
            draftDate = date
            editingDate = boundary
        } label: {
            Text(label)
                .font(.system(size: 12)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 34)
                .padding(.horizontal, 5)
                .overlay(Capsule().stroke(Color.gray.opacity(0.22), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(boundary.rawValue)
        .accessibilityValue(label)
    }

    private func updateDate(_ date: Date, start: Bool) {
        interval = start ? DateInterval(start: date, end: max(date, interval.end))
                         : DateInterval(start: min(date, interval.start), end: date)
    }

    private func action(_ title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(.system(size: 14)).foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(C.blue).cornerRadius(3)
        }
        .buttonStyle(.plain)
    }

    private func shift(_ days: Int) {
        let seconds = TimeInterval(days) * 86_400
        interval = DateInterval(start: interval.start.addingTimeInterval(seconds), duration: interval.duration)
        runQuery()
    }

    private func runQuery() {
        query = interval
        reloadCount += 1
    }

    private func load(window: DateInterval) async {
        loading = true
        error = nil
        samples = []
        defer { if !Task.isCancelled { loading = false } }
        guard !PlantReadingValue.clean(pointId).isEmpty else {
            error = "后台未提供此测点的历史编号"
            return
        }
        guard window.duration > 0 else {
            error = "结束时间需晚于开始时间"
            return
        }
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_DataCenter/work/mpoint/getHistory.do",
                ["bizId": app.unit, "ids": pointId, "sort": "insdt", "order": "desc",
                 "sdt": Self.timestamp.string(from: window.start), "edt": Self.timestamp.string(from: window.end)])
            try Task.checkCancellation()
            let root = Net.dict(raw)
            let payload = root["result"] ?? root["rows"] ?? raw
            let result = Net.dict(payload)
            guard let records = (payload as? [[[String: Any]]])?.first
                    ?? Net.objectRows(result["rows"] ?? result["list"] ?? payload) else {
                throw APIError.message("服务未返回历史数据列表")
            }
            samples = records.compactMap { record in
                let time = Net.str(record, "measuredt").replacingOccurrences(of: "T", with: " ")
                guard let date = Self.timestamp.date(from: String(time.prefix(19))),
                      let value = Double(Net.str(record, "parmvalue")), value.isFinite else { return nil }
                return HistorySample(time: date, value: value)
            }.sorted { $0.time < $1.time }
            if !records.isEmpty && samples.isEmpty {
                error = "后台返回的历史数据无法读取"
            }
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    fileprivate static func formatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        return formatter
    }
}

private struct HistorySample {
    let time: Date
    let value: Double
}

private struct HistoryChart: View {
    let samples: [HistorySample]
    private static let axisDate = PointHistoryScreen.formatter("MM-dd HH:mm")

    var body: some View {
        Canvas { context, size in
            let plot = CGRect(x: 38, y: 25, width: max(1, size.width - 51), height: max(1, size.height - 54))
            let values = samples.map(\.value)
            let low = min(0, values.min() ?? 0)
            let high = max(values.max() ?? 1, low + 0.0001)
            let magnitude = pow(10, floor(log10((high - low) / 5)))
            let step = ceil((high - low) / (5 * magnitude)) * magnitude
            let bottom = floor(low / step) * step
            let top = max(ceil(high / step) * step, bottom + step)
            let first = samples.first?.time ?? Date()
            let last = samples.last?.time ?? first
            let duration = last.timeIntervalSince(first)

            for index in 0...5 {
                let fraction = Double(index) / 5
                let y = plot.maxY - plot.height * fraction
                var grid = Path()
                grid.move(to: CGPoint(x: plot.minX, y: y))
                grid.addLine(to: CGPoint(x: plot.maxX, y: y))
                context.stroke(grid, with: .color(.gray.opacity(0.28)), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                let value = bottom + (top - bottom) * fraction
                context.draw(Text(String(format: "%.4g", value)).font(.system(size: 9)).foregroundColor(C.sub),
                             at: CGPoint(x: plot.minX - 5, y: y), anchor: .trailing)
            }
            var axes = Path()
            axes.move(to: CGPoint(x: plot.minX, y: plot.minY))
            axes.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
            axes.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            context.stroke(axes, with: .color(.gray.opacity(0.5)), lineWidth: 0.5)
            let labelCount = max(1, min(4, Int(plot.width / 75)))
            for index in 0...labelCount {
                if duration == 0 && index != 0 { continue }
                let fraction = Double(index) / Double(labelCount)
                let time = first.addingTimeInterval(duration * fraction)
                let x = plot.minX + plot.width * fraction
                let anchor: UnitPoint = index == 0 ? .topLeading : index == labelCount ? .topTrailing : .top
                context.draw(Text(Self.axisDate.string(from: time)).font(.system(size: 8)).foregroundColor(C.sub),
                             at: CGPoint(x: x, y: plot.maxY + 4), anchor: anchor)
            }
            context.draw(Text("■ 值").font(.system(size: 10)).foregroundColor(.green),
                         at: CGPoint(x: plot.maxX, y: 11), anchor: .trailing)

            var line = Path()
            for (index, sample) in samples.enumerated() {
                let fraction = duration > 0 ? sample.time.timeIntervalSince(first) / duration : 0.5
                let x = plot.minX + plot.width * fraction
                let y = plot.maxY - plot.height * ((sample.value - bottom) / (top - bottom))
                if index == 0 { line.move(to: CGPoint(x: x, y: y)) }
                else { line.addLine(to: CGPoint(x: x, y: y)) }
                if samples.count == 1 {
                    context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(.green))
                }
            }
            context.stroke(line, with: .color(.green), lineWidth: 1)
        }
        .accessibilityLabel("历史曲线")
        .accessibilityValue("\(samples.count) 条历史读数")
    }
}
