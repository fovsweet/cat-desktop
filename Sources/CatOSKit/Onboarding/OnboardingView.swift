import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class OnboardingModel: ObservableObject {
    enum Step: Equatable {
        case pick, processing, adjust
    }

    @Published var step: Step = .pick
    @Published var cutout: CGImage?
    @Published var leftEye = CGPoint(x: 0.4, y: 0.65)
    @Published var rightEye = CGPoint(x: 0.6, y: 0.65)
    @Published var name = ""
    @Published var displayWidth: CGFloat = 220
    @Published var errorMessage: String?
    @Published var isDropTargeted = false

    var onComplete: ((PetProfile, CGImage) -> Void)?

    func process(url: URL) {
        guard let image = NSImage(contentsOf: url),
              let source = try? ImageUtil.cgImage(from: image)
        else {
            errorMessage = "无法读取这张图片,换一张试试。"
            return
        }
        errorMessage = nil
        step = .processing

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let cutout = try CutoutProcessor.cutout(from: source)
                let eyes = PoseAnalyzer.detectEyes(in: cutout)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.cutout = cutout
                    if let left = eyes.leftEye { self.leftEye = left }
                    if let right = eyes.rightEye { self.rightEye = right }
                    self.step = .adjust
                }
            } catch {
                DispatchQueue.main.async {
                    self?.errorMessage = error.localizedDescription
                    self?.step = .pick
                }
            }
        }
    }

    func finish() {
        guard let cutout else { return }
        let profile = PetProfile(
            name: name.isEmpty ? "毛孩子" : name,
            leftEye: leftEye,
            rightEye: rightEye,
            displayWidth: displayWidth
        )
        onComplete?(profile, cutout)
    }
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(spacing: 16) {
            switch model.step {
            case .pick: pickStep
            case .processing: processingStep
            case .adjust: adjustStep
            }
        }
        .padding(24)
        .frame(width: 520, height: 560)
    }

    // MARK: - 第一步:选照片

    private var pickStep: some View {
        VStack(spacing: 18) {
            Text("创建你的桌宠")
                .font(.title.bold())
            Text("上传一张猫或狗的照片,CatOS 会自动抠图\n并把它变成住在你桌面上的小宠物。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    model.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .frame(height: 240)
                .overlay {
                    VStack(spacing: 10) {
                        Text("🐱 🐶").font(.system(size: 44))
                        Text("把照片拖到这里").font(.headline)
                        Text("或").foregroundStyle(.secondary)
                        Button("选择照片…") { openPanel() }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $model.isDropTargeted) { providers in
                    handleDrop(providers)
                }

            if let error = model.errorMessage {
                Text(error).foregroundStyle(.red)
            }
            Spacer()
        }
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.process(url: url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async { model.process(url: url) }
        }
        return true
    }

    // MARK: - 第二步:抠图中

    private var processingStep: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().controlSize(.large)
            Text("正在抠图、寻找眼睛…").foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 第三步:确认眼睛位置 + 参数

    private var adjustStep: some View {
        VStack(spacing: 14) {
            Text("拖动两个圆点,对准宠物的眼睛")
                .font(.headline)

            if let cutout = model.cutout {
                EyeMarkingCanvas(model: model, cutout: cutout)
                    .frame(width: 460, height: 320)
                    .background(
                        Image(nsImage: checkerboard())
                            .resizable(resizingMode: .tile)
                            .opacity(0.35)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Text("名字")
                TextField("毛孩子", text: $model.name).frame(width: 140)
                Spacer()
                Text("大小")
                Slider(value: $model.displayWidth, in: 120...400).frame(width: 160)
            }

            HStack {
                Button("重新选照片") { model.step = .pick }
                Spacer()
                Button("放到桌面 🐾") { model.finish() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
        }
    }

    private func checkerboard() -> NSImage {
        let size: CGFloat = 16
        let image = NSImage(size: NSSize(width: size * 2, height: size * 2))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: size * 2, height: size * 2).fill()
        NSColor(white: 0.85, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        NSRect(x: size, y: size, width: size, height: size).fill()
        image.unlockFocus()
        return image
    }
}

/// 抠图预览 + 可拖动的眼睛标记点。
private struct EyeMarkingCanvas: View {
    @ObservedObject var model: OnboardingModel
    let cutout: CGImage

    var body: some View {
        GeometryReader { geo in
            let imageRect = fittedRect(in: geo.size)
            ZStack {
                Image(decorative: cutout, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                eyeDot(normalized: $model.leftEye, in: imageRect, color: .blue)
                eyeDot(normalized: $model.rightEye, in: imageRect, color: .orange)
            }
        }
    }

    private func fittedRect(in container: CGSize) -> CGRect {
        let imageAspect = CGFloat(cutout.width) / CGFloat(cutout.height)
        let containerAspect = container.width / container.height
        var size = container
        if imageAspect > containerAspect {
            size.height = container.width / imageAspect
        } else {
            size.width = container.height * imageAspect
        }
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func eyeDot(
        normalized: Binding<CGPoint>, in rect: CGRect, color: Color
    ) -> some View {
        // 归一化坐标原点在左下;SwiftUI 原点在左上,Y 轴翻转。
        let position = CGPoint(
            x: rect.minX + normalized.wrappedValue.x * rect.width,
            y: rect.minY + (1 - normalized.wrappedValue.y) * rect.height
        )
        return Circle()
            .strokeBorder(color, lineWidth: 3)
            .background(Circle().fill(color.opacity(0.25)))
            .frame(width: 26, height: 26)
            .position(position)
            .gesture(
                DragGesture().onChanged { value in
                    let clampedX = max(rect.minX, min(value.location.x, rect.maxX))
                    let clampedY = max(rect.minY, min(value.location.y, rect.maxY))
                    normalized.wrappedValue = CGPoint(
                        x: (clampedX - rect.minX) / rect.width,
                        y: 1 - (clampedY - rect.minY) / rect.height
                    )
                }
            )
    }
}
