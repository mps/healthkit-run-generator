import XCTest
@testable import HealthKitRunGenerator

final class PlaceholderTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(HealthKitRunGeneratorVersion.version, "0.1.0")
    }
}
