import SwiftUI
import UIKit

// MARK: - 照片条（多处复用）

struct PhotoStrip: View {
    @Binding var photos: [UIImage]
    @State private var showCamera = false
    @State private var showLibrary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("现场照片").font(.system(size: 12)).foregroundColor(C.sub)
            if photos.isEmpty {
                HStack(spacing: 10) {
                    btn("拍照", "camera.fill") { showCamera = true }
                    btn("相册", "photo.on.rectangle") { showLibrary = true }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { idx, img in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 86, height: 86).clipped().cornerRadius(6)
                                Button { photos.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                        Button { showCamera = true } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20)).foregroundColor(C.blue)
                                .frame(width: 86, height: 86)
                                .background(C.cardBg).cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(C.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("共 \(photos.count) 张").font(.system(size: 11)).foregroundColor(C.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).background(Color.white).cornerRadius(10)
        .sheet(isPresented: $showCamera) { CameraPicker(images: $photos, useCamera: true) }
        .sheet(isPresented: $showLibrary) { CameraPicker(images: $photos, useCamera: false) }
    }

    private func btn(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20))
                Text(title).font(.system(size: 11))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(C.cardBg).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(C.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
        }
        .buttonStyle(.plain)
    }
}


// MARK: - 指定角圆角（兼容 iOS 15）

struct RoundCorners: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
