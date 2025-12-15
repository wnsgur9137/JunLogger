//
//  AppLogger.swift
//  BaseDomain
//
//  Created by JunHyeok Lee on 12/9/25.
//  Copyright © 2025 com.junhyeok.JunLogger. All rights reserved.
//

import Foundation
import OSLog

/// 앱 전역 로깅 유틸리티
///
/// 사용 예시:
/// ```swift
/// Log.debug(.network, "API 호출 시작")
/// Log.info(.ui, "HomeView appeared")
/// Log.error(.data, "데이터 로드 실패", error: someError)
/// Log.debug("일반 로그")  // category 생략 시 .general
/// ```
public enum Log {
    
    // MARK: - Debug
    
    /// 디버그 로그 (개발 중에만 표시)
    /// - Parameters:
    ///   - category: 로그 카테고리 (기본값: .general)
    ///   - message: 로그 메시지
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public static func debug(
        _ category: LogCategory = .general,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        Logger
            .logger(for: category)
            .debug(
                message,
                file: file,
                function: function,
                line: line
            )
    }
    
    // MARK: - Info
    
    /// 정보 로그 (일반적인 정보성 메시지)
    /// - Parameters:
    ///   - category: 로그 카테고리 (기본값: .general)
    ///   - message: 로그 메시지
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public static func info(
        _ category: LogCategory = .general,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        Logger
            .logger(for: category)
            .info(
                message,
                file: file,
                function: function,
                line: line
            )
    }
    
    // MARK: - Warning
    
    /// 경고 로그 (주의가 필요한 상황)
    /// - Parameters:
    ///   - category: 로그 카테고리 (기본값: .general)
    ///   - message: 로그 메시지
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public static func warning(
        _ category: LogCategory = .general,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        Logger
            .logger(for: category)
            .warning(
                message,
                file: file,
                function: function,
                line: line
            )
    }
    
    // MARK: - Error
    
    /// 에러 로그 (에러 발생 시)
    /// - Parameters:
    ///   - category: 로그 카테고리 (기본값: .general)
    ///   - message: 로그 메시지
    ///   - error: Error 객체 (optional)
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public static func error(
        _ category: LogCategory = .general,
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        Logger
            .logger(for: category)
            .error(
                message,
                error: error,
                file: file,
                function: function,
                line: line
            )
    }
    
    // MARK: - Fault
    
    /// 치명적 에러 로그 (앱 크래시 가능성이 있는 심각한 에러)
    /// - Parameters:
    ///   - category: 로그 카테고리 (기본값: .general)
    ///   - message: 로그 메시지
    ///   - error: Error 객체 (optional)
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public static func fault(
        _ category: LogCategory = .general,
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        Logger
            .logger(for: category)
            .fault(
                message,
                error: error,
                file: file,
                function: function,
                line: line
            )
    }
    
    // MARK: - Performance
    
    /// 성능 측정 시작
    /// - Parameter name: 측정할 작업 이름
    /// - Returns: Signpost ID
    public static func beginSignpost(name: StaticString) -> OSSignpostID {
        return Logger
            .performance
            .beginSignpost(name: name)
    }
    
    /// 성능 측정 종료
    /// - Parameters:
    ///   - name: 측정한 작업 이름
    ///   - signpostID: beginSignpost에서 반환된 ID
    public static func endSignpost(name: StaticString, signpostID: OSSignpostID) {
        Logger
            .performance
            .endSignpost(
                name: name,
                signpostID: signpostID
            )
    }
}
