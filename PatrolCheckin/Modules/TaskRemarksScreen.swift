import SwiftUI

// MARK: - 任务备注（照 res/layout/activity_task_datail.xml 还原）

struct TaskRemarksScreen: View {
    @EnvironmentObject var app: AppState
    let recordId: String
    private var key: String {
        let identity = [Net.shared.userid, app.unit, recordId]
        let data = (try? JSONEncoder().encode(identity)) ?? Data()
        return "taskRemark." + data.base64EncodedString()
    }

    @State private var remarks = ""
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
                    Text("任务备注（本机草稿）")
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


                }
                .padding(.horizontal, 16)
            }

            // 底部 50dp：提交 / 取消
            HStack(spacing: 0) {
                Button { save() } label: {
                    HStack(spacing: 6) {
                        Text("保存草稿")
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
        .onAppear { remarks = UserDefaults.standard.string(forKey: key) ?? "" }
    }

    private func save() {
        guard !recordId.isEmpty else { return }
        UserDefaults.standard.set(remarks, forKey: key)
        app.show("草稿已保存到本机")
        presentation.wrappedValue.dismiss()
    }
}
