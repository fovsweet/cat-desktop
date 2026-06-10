import AppKit
import XCTest
@testable import CatOSKit

/// 用 cat_png 下的真实猫照验证完整处理管线:
/// HEIC 读取 → Vision 抠图 → 眼睛检测 → 持久化 → 重新加载。
final class PipelineIntegrationTests: XCTestCase {
    private static var photosDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CatOSKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("cat_png")
    }

    private func loadTestPhoto() throws -> CGImage {
        let dir = Self.photosDirectory
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )) ?? []
        guard let url = files.first(where: {
            ["heic", "png", "jpg", "jpeg"].contains($0.pathExtension.lowercased())
        }) else {
            throw XCTSkip("cat_png 目录下没有测试照片")
        }
        let image = try XCTUnwrap(NSImage(contentsOf: url), "无法读取 \(url.lastPathComponent)")
        return try ImageUtil.cgImage(from: image)
    }

    func testCutoutProducesTransparentCroppedImage() throws {
        let source = try loadTestPhoto()

        let cutout = try CutoutProcessor.cutout(from: source)

        XCTAssertGreaterThan(cutout.width, 50, "抠图结果过小")
        XCTAssertGreaterThan(cutout.height, 50, "抠图结果过小")
        XCTAssertLessThanOrEqual(cutout.width, source.width)
        XCTAssertTrue(
            cutout.alphaInfo == .premultipliedLast || cutout.alphaInfo == .premultipliedFirst
                || cutout.alphaInfo == .last || cutout.alphaInfo == .first,
            "抠图结果应带 alpha 通道,实际: \(cutout.alphaInfo.rawValue)"
        )
    }

    func testEyeDetectionOnRealCatPhoto() throws {
        let source = try loadTestPhoto()
        let cutout = try CutoutProcessor.cutout(from: source)

        let eyes = PoseAnalyzer.detectEyes(in: cutout)

        // 真实照片角度不保证双眼都检出;检出的必须在合法范围内。
        for point in [eyes.leftEye, eyes.rightEye].compactMap({ $0 }) {
            XCTAssertTrue((0...1).contains(point.x), "眼睛 x 越界: \(point)")
            XCTAssertTrue((0...1).contains(point.y), "眼睛 y 越界: \(point)")
        }
    }

    func testStoreSaveAndReloadRoundTrip() throws {
        let source = try loadTestPhoto()
        let cutout = try CutoutProcessor.cutout(from: source)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatOSTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = PetStore(baseURL: tempDir)
        let profile = PetProfile(
            name: "测试猫",
            leftEye: CGPoint(x: 0.4, y: 0.6),
            rightEye: CGPoint(x: 0.6, y: 0.6)
        )
        try store.save(profile: profile, image: cutout)

        let loaded = try XCTUnwrap(store.loadCurrent())
        XCTAssertEqual(loaded.profile, profile)
        XCTAssertTrue(loaded.image.isValid)
    }

    func testStoreReturnsNilForCorruptProfile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatOSTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: tempDir.appendingPathComponent("profile.json"))

        XCTAssertNil(PetStore(baseURL: tempDir).loadCurrent())
    }
}
