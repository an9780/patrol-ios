import SwiftUI

// MARK: - 排班审核（照 res/layout/activity_audit_schedule_sheet.xml 的蓝框卡片结构还原）

struct ScheduleAuditScreen: View {
    @EnvironmentObject var app: AppState
    let taskId: String
    let businessId: String

    @StateObject private var store = DetailStore()
    @State private var opinion = ""
    @State private var busy = false
    @State private var msg: String?
    @Environment(\.presentationMode) private var presentation

    private let gray04 = Color(hex: 0x757778)
    private let gray01 = Color(hex: 0xDADDE2)

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [C.gradStart, C.gradEnd],
                               startPoint: .leading, endPoint: .trailing)
                Text("排班审核").font(.system(size: 15)).foregroundColor(.white)
            }
            .frame(height: 50)

            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Button("签名") { }
                            .font(.system(size: 14)).foregroundColor(.white)
                            .frame(width: 80, height: 35)
                            .background(C.blue).cornerRadius(3)
                        Spacer()
                        Button { Task { await submit() } } label: {
                            HStack(spacing: 6) {
                                if busy { ProgressView().tint(.white).scaleEffect(0.7) }
                                Text(busy ? "提交中…" : "提交")
                                    .font(.system(size: 14)).foregroundColor(.white)
                            }
                            .frame(width: 80, height: 35)
                            .background(C.blue).cornerRadius(3)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("*审核意见，请填写")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: 0xA3A1A1))
                            .padding(.leading, 10).padding(.top, 8)

                        VStack(spacing: 0) {
                            ForEach(Array(store.fields.prefix(10).enumerated()), id: \.offset) { _, f in
                                HStack(spacing: 0) {
                                    Text(f.label)
                                        .font(.system(size: 14)).foregroundColor(gray04)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .layoutPriority(1)
                                    VStack(spacing: 0) {
                                        Text(f.value)
                                            .font(.system(size: 14)).foregroundColor(.black)
                                            .frame(height: 34.5, alignment: .center)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Rectangle().fill(gray01).frame(height: 0.3)
                                    }
                                    .layoutPriority(3)
                                }
                            }

                            ZStack(alignment: .topLeading) {
                                if opinion.isEmpty {
                                    Text("请填写审核意见")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: 0xC7C7CD))
                                        .padding(6)
                                }
                                TextEditor(text: $opinion)
                                    .font(.system(size: 14))
                                    .padding(2)
                                    .frame(height: 90)
                            }
                            .overlay(Rectangle().stroke(Color(hex: 0xE9E9E9), lineWidth: 1))
                            .padding(.horizontal, 8).padding(.vertical, 6)
                        }
                        .padding(5).padding(8)
                    }
                    .overlay(Rectangle().stroke(Color(hex: 0x43B3FF), lineWidth: 1))
                    .padding(.horizontal, 10)

                    if let m = msg {
                        Text(m).font(.system(size: 12)).foregroundColor(.red).padding(.top, 8)
                    }
                    Spacer(minLength: 20)
                }
            }
            .background(C.bg)
        }
        .navigationBarHidden(true)
        .task {
            await store.load(
                path: "SIPAIIS_DataCenter/work/processAdjustment/showView.do",
                params: ["id": businessId])
        }
    }

    private func submit() async {
        busy = true
        do {
            let raw = try await Net.shared.postJSON(
                "SIPAIIS_DataCenter/work/processAdjustment/doAuditDetail.do",
                ["taskid": taskId, "businessid": businessId,
                 "passstatus": "true", "auditopinion": opinion])
            if Net.isOK(raw) {
                app.show("审核已提交 ✓")
                presentation.wrappedValue.dismiss()
            } else { msg = Net.message(raw) }
        } catch { msg = error.localizedDescription }
        busy = false
    }
}
