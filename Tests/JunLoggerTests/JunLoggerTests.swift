//
//  JunLoggerTests.swift
//  JunLogger
//
//  Created by JunHyeok Lee on 12/9/25.
//

import XCTest
import OSLog
@testable import JunLogger

final class JunLoggerTests: XCTestCase {
    
    func testLogCategoryRawValues() {
        XCTAssertEqual(LogCategory.network.rawValue, "Network")
        XCTAssertEqual(LogCategory.ui.rawValue, "UI")
        XCTAssertEqual(LogCategory.data.rawValue, "Data")
        XCTAssertEqual(LogCategory.domain.rawValue, "Domain")
        XCTAssertEqual(LogCategory.lifecycle.rawValue, "Lifecycle")
        XCTAssertEqual(LogCategory.auth.rawValue, "Auth")
        XCTAssertEqual(LogCategory.performance.rawValue, "Performance")
        XCTAssertEqual(LogCategory.general.rawValue, "General")
    }
    
    func testLoggingMethods() {
        // 로깅 메서드가 크래시 없이 실행되는지 확인
        Log.debug(.network, "Test debug log")
        Log.info(.ui, "Test info log")
        Log.warning(.data, "Test warning log")
        Log.error(.domain, "Test error log")
        Log.fault(.general, "Test fault log")
    }
    
    func testSignpostPerformance() {
        let signpostID = Log.beginSignpost(name: "Test Performance")
        XCTAssertNotEqual(signpostID, OSSignpostID.invalid)
        Log.endSignpost(name: "Test Performance", signpostID: signpostID)
    }
}
