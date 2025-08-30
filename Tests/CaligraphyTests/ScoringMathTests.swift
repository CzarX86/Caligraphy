import XCTest
@testable import Caligraphy
import CoreGraphics

final class ScoringMathTests: XCTestCase {
    func testDTWZeroForIdentical() {
        let a: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0), CGPoint(x: 20, y: 0)]
        let b = a
        let d = ScoringMath.dtwDistance(a, b)
        XCTAssertEqual(d, 0, accuracy: 1e-6)
    }

    func testFrechetZeroForIdentical() {
        let a: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 5), CGPoint(x: 10, y: 0)]
        let d = ScoringMath.frechetDistance(a, a)
        XCTAssertEqual(d, 0, accuracy: 1e-6)
    }

    func testVelocitiesAndJerk() {
        let pts: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0), CGPoint(x: 3, y: 0)]
        let v = ScoringMath.velocities(pts)
        XCTAssertEqual(v.count, pts.count - 1)
        XCTAssertTrue(v.allSatisfy { $0 >= 0 })
        // Constant step -> zero jerk
        let j = ScoringMath.meanJerk(v)
        XCTAssertEqual(j, 0, accuracy: 1e-6)
    }
}

