import XCTest
@testable import ModelRelay

final class ToolNameTests: XCTestCase {
    func testToolNameIncludesExecuteSQL() {
        XCTAssertTrue(ToolName.allCases.contains(.executeSQL))
        XCTAssertEqual(ToolName.executeSQL.rawValue, "execute_sql")
    }
}
