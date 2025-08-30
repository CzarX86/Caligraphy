import XCTest
@testable import Caligraphy

final class CaligraphyTests: XCTestCase {
    func testMetricsInitialization() {
        let m = Metrics(
            precision: 0.5,
            speedMean: 1.0,
            speedCV: 0.2,
            consistency: 0.5,
            spacing: 0.5,
            baseline: 0.5,
            planning: 0.5,
            fluencyJerk: 0.3,
            microstops: 1
        )
        XCTAssertEqual(m.precision, 0.5)
        XCTAssertEqual(m.microstops, 1)
    }
}

