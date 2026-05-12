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

    override func tearDown() {
        Log.provider = OSLogProvider()
        super.tearDown()
    }

    // MARK: - LogCategory

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

    func testLogCategoryStringLiteral() {
        let payment: LogCategory = "Payment"
        XCTAssertEqual(payment.rawValue, "Payment")
        XCTAssertEqual(payment, LogCategory(rawValue: "Payment"))
    }

    func testAllBuiltInCategoriesContainsEightEntries() {
        XCTAssertEqual(LogCategory.allBuiltInCategories.count, 8)
    }

    // MARK: - Log Subscript

    func testLoggingMethodsDoNotCrash() {
        // 호출이 크래시 없이 컴파일·실행되는지 확인.
        Log[.network].debug("Test debug log")
        Log[.ui].info("Test info log")
        Log[.data].warning("Test warning log")
        Log[.domain].error("Test error log")
        Log[.general].fault("Test fault log")
        Log[.lifecycle].notice("Test notice log")
        Log["CustomCategory"].debug("Test custom category")
    }

    // MARK: - DI

    func testLoggingProviderInjection() {
        Log.provider = DisabledLogProvider()
        Log[.network].debug("Should be no-op")
        Log[.auth].error("Should be no-op")
        // 크래시 없이 통과하면 OK. 실제 출력 부재는 lazy eval 테스트에서 검증.
    }

    func testLazyEvaluationWhenDisabled() {
        Log.provider = DisabledLogProvider()

        final class Counter: @unchecked Sendable {
            var count = 0
            func inc() -> String {
                count += 1
                return "v\(count)"
            }
        }

        let counter = Counter()
        for _ in 0..<100 {
            Log[.network].debug("\(counter.inc(), privacy: .public)")
        }

        XCTAssertEqual(
            counter.count, 0,
            "DisabledLogProvider 환경에서 인터폴레이션 인자 표현식이 평가되면 안 됨"
        )
    }

    // MARK: - Signpost

    func testSignpostPerformance() {
        let signpostID = Log.beginSignpost(name: "Test Performance")
        XCTAssertNotEqual(signpostID, OSSignpostID.invalid)
        Log.endSignpost(name: "Test Performance", signpostID: signpostID)
    }
}
