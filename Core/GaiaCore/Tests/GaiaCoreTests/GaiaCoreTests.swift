import XCTest
@testable import GaiaCore

final class GaiaCoreTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(GaiaCore().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
