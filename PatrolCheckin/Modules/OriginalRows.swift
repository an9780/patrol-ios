import SwiftUI

// MARK: - 原版列表行组件（逐条对应 APK 的 item_*.xml）

/// item_equipment_class.xml：16sp 文本，padding 5，下方 0.2dp #9FA2A3 分隔线
struct SimpleTextRow: View {
    let text: String
    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 16)).foregroundColor(.black)
                .padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(Color(hex: 0x9FA2A3)).frame(height: 0.2)
        }
    }
}

/// item_nodes.xml：40dp 行，箭头 56dp（padding 10），标题 16sp 黑（权重 4）
struct TreeRow: View {
    let title: String
    var expanded: Bool = false
    var body: some View {
        HStack(spacing: 0) {
            Image("arrow_right")
                .resizable().scaledToFit()
                .padding(10)
                .frame(width: 56, height: 40)
                .rotationEffect(.degrees(expanded ? 90 : 0))
            Text(title)
                .font(.system(size: 16)).foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 40)
        }
    }
}

/// item_history_task_log.xml：白卡圆角 3，编号 17sp + 状态胶囊，分隔线，字段 13sp 标签 / 14sp 值
struct HistoryTaskRow: View {
    let id: String
    let status: String
    let fields: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(id)
                    .font(.system(size: 17)).foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(status)
                    .font(.system(size: 12)).foregroundColor(Color(hex: 0x0E8F4E))
                    .padding(.horizontal, 10)
                    .frame(height: 25)
                    .background(Color(hex: 0xE6F7EE))
                    .cornerRadius(12)
            }
            Rectangle().fill(Color(hex: 0xA3A1A1)).frame(height: 0.2)

            ForEach(Array(fields.enumerated()), id: \.offset) { _, f in
                VStack(alignment: .leading, spacing: 0) {
                    Text(f.0)
                        .font(.system(size: 13)).foregroundColor(Color(hex: 0x858585))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(f.1)
                        .font(.system(size: 14)).foregroundColor(.black)
                        .padding(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 3).fill(Color.white))
        .padding(.horizontal, 8).padding(.vertical, 3)
    }
}


/// item_selector_person.xml / item_goods.xml：绿底卡片，40dp 行，白字 + 复选框
struct SelectableGreenRow: View {
    let title: String
    let checked: Bool
    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 15)).foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 40)
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
        }
        .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x2FA84F)))
        .padding(.horizontal, 8).padding(.vertical, 3)
    }
}

/// item_measurepoint.xml：48dp 行，图标 45dp，名称 15sp（权重 6）/ 值 15sp（权重 3）/ 按钮（权重 3）
struct MeasurePointRow: View {
    let name: String
    let value: String
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image("iv_cod")
                    .resizable().scaledToFit()
                    .padding(8).frame(width: 45, height: 45)
                HStack(spacing: 0) {
                    Text(name)
                        .font(.system(size: 15)).foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(6)
                    Text(value)
                        .font(.system(size: 15)).foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .layoutPriority(3)
                    Image("green_btn")
                        .resizable().scaledToFit()
                        .padding(9).frame(maxWidth: .infinity, maxHeight: 45)
                        .layoutPriority(3)
                }
                .frame(height: 45)
            }
            .frame(height: 45)
            Rectangle().fill(Color(hex: 0xDADDE2)).frame(height: 0.7)
        }
        .frame(height: 48)
    }
}
