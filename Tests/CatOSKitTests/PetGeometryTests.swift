import XCTest
@testable import CatOSKit

final class PetGeometryTests: XCTestCase {
    // MARK: pupilOffset

    func testPupilOffsetPointsTowardTarget() {
        // Arrange
        let eye = CGPoint(x: 100, y: 100)
        let target = CGPoint(x: 500, y: 100)

        // Act
        let offset = PetGeometry.pupilOffset(eyeCenter: eye, target: target, maxOffset: 10)

        // Assert: 目标在正右方,瞳孔只向右偏
        XCTAssertEqual(offset.x, 10, accuracy: 0.001)
        XCTAssertEqual(offset.y, 0, accuracy: 0.001)
    }

    func testPupilOffsetNeverExceedsMax() {
        let offset = PetGeometry.pupilOffset(
            eyeCenter: .zero, target: CGPoint(x: 9999, y: -9999), maxOffset: 8
        )
        XCTAssertLessThanOrEqual(hypot(offset.x, offset.y), 8.001)
    }

    func testPupilOffsetScalesDownWhenTargetIsClose() {
        let near = PetGeometry.pupilOffset(
            eyeCenter: .zero, target: CGPoint(x: 30, y: 0), maxOffset: 10
        )
        XCTAssertEqual(near.x, 10 * 30 / 120, accuracy: 0.001)
    }

    func testPupilOffsetZeroWhenTargetOnEye() {
        let offset = PetGeometry.pupilOffset(
            eyeCenter: CGPoint(x: 5, y: 5), target: CGPoint(x: 5, y: 5), maxOffset: 10
        )
        XCTAssertEqual(offset, .zero)
    }

    // MARK: leanAngle

    func testLeanAngleLeansTowardTargetAndClamps() {
        // 目标在右 → 顺时针(负角度);目标在左 → 正角度
        let right = PetGeometry.leanAngle(petCenterX: 0, targetX: 10000)
        let left = PetGeometry.leanAngle(petCenterX: 0, targetX: -10000)
        let maxRadians = 6 * CGFloat.pi / 180
        XCTAssertEqual(right, -maxRadians, accuracy: 0.0001)
        XCTAssertEqual(left, maxRadians, accuracy: 0.0001)
    }

    // MARK: normalize / denormalize

    func testNormalizeDenormalizeRoundTrip() {
        let size = CGSize(width: 200, height: 300)
        let original = CGPoint(x: 0.25, y: 0.8)

        let denorm = PetGeometry.denormalize(original, in: size)
        let roundTrip = PetGeometry.normalize(denorm, in: size)

        XCTAssertEqual(roundTrip.x, original.x, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.y, original.y, accuracy: 0.0001)
    }

    func testNormalizeClampsOutOfBounds() {
        let result = PetGeometry.normalize(
            CGPoint(x: -50, y: 999), in: CGSize(width: 100, height: 100)
        )
        XCTAssertEqual(result, CGPoint(x: 0, y: 1))
    }

    // MARK: pawStrike

    func testPawStrikeCapsLength() {
        let strike = PetGeometry.pawStrike(
            from: .zero, to: CGPoint(x: 1000, y: 0), maxLength: 80
        )
        XCTAssertEqual(strike.length, 80)
        XCTAssertEqual(strike.angle, 0, accuracy: 0.0001)
    }

    func testPawStrikeAngle() {
        let strike = PetGeometry.pawStrike(
            from: .zero, to: CGPoint(x: 0, y: 50), maxLength: 100
        )
        XCTAssertEqual(strike.angle, .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(strike.length, 50, accuracy: 0.0001)
    }
}
