import SwiftUI

// MARK: - 任务备注（照 res/layout/activity_task_datail.xml 还原）

struct TaskRemarksScreen: View {
    @EnvironmentObject var app: AppState
    let recordId: String
    let pointId: String

    @State private var remarks = ""
    @State private var busy = false
    @State private var msg: String?
    @Environment(\.presentationMode) private var presentation

    var body: some View {
        VStack(spacing: 0) {
            // ActionBar 50dp
            ZStack {
                Color(hex: 0x2748F1)
                Text("巡检备注").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("巡检备注")
                        .font(.system(size: 20)).foregroundColor(.black)
                        .padding(.top, 10)

                    ZStack(alignment: .topLeading) {
                        if remarks.isEmpty {
                            Text("请输入巡检备注")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: 0xC7C7CD))
                                .padding(10)
                        }
                        TextEditor(text: $remarks)
                            .font(.system(size: 15))
                            .padding(6)
                            .frame(height: 200)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: 0xDADDE2), lineWidth: 1))

                    if let m = msg {
                        Text(m).font(.system(size: 12)).foregroundColor(.red)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
            }

            // 底部 50dp：提交 / 取消
            HStack(spacing: 0) {
                Button { Task { await submit() } } label: {
                    HStack(spacing: 6) {
                        if busy { ProgressView().tint(.white).scaleEffect(0.7) }
                        Text(busy ? "提交中…" : "提交")
                            .font(.system(size: 18)).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(Color(hex: 0x2748F1))
                }
                Button { presentation.wrappedValue.dismiss() } label: {
                    Text("取消")
                        .font(.system(size: 18)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color(hex: 0x9FA2A3))
                }
            }
            .frame(height: 50)
        }
        .background(Color.white)
        .navigationBarHidden(true)
    }

    private func submit() async {
        busy = true
        msg = nil
        do {
            let raw = try await Net.shared.post(
                "SIPAIIS_Patrol/timeEfficiency/patrolRecord/updatePatrolPointRemark.do",
                ["id": pointId, "recordId": recordId, "remarks": remarks])
            if Net.isOK(raw) {
                app.show("备注已保存 ✓")
                presentation.wrappedValue.dismiss()
            } else {
                msg = Net.message(raw)
            }
        } catch {
            msg = error.localizedDescription
        }
        busy = false
    }
}
