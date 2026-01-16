import XCTest
@testable import ModelRelay

final class ToolNameTests: XCTestCase {
    func testToolNameIncludesExecuteSQL() {
        XCTAssertTrue(ToolName.allCases.contains(.executeSQL))
        XCTAssertEqual(ToolName.executeSQL.rawValue, "execute_sql")
    }

    func testToolNameIncludesSchemaInspectionTools() {
        XCTAssertTrue(ToolName.allCases.contains(.listTables))
        XCTAssertEqual(ToolName.listTables.rawValue, "list_tables")
        XCTAssertTrue(ToolName.allCases.contains(.describeTable))
        XCTAssertEqual(ToolName.describeTable.rawValue, "describe_table")
        XCTAssertTrue(ToolName.allCases.contains(.sampleRows))
        XCTAssertEqual(ToolName.sampleRows.rawValue, "sample_rows")
    }
}
