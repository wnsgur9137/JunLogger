//
//  Logger+Extension.swift
//  BaseDomain
//
//  Created by JunHyeok Lee on 12/9/25.
//  Copyright © 2025 com.junhyeok.JunLogger. All rights reserved.
//

import Foundation
import OSLog

extension Logger {
    
    /// 앱의 Bundle Identifier를 서브시스템으로 사용
    private static var subsystem: String {
        Bundle.main.bundleIdentifier ?? ""
    }
    
    // MARK: - Category Loggers
    
    /// 네트워크 관련 로거
    public static let network = Logger(
        subsystem: subsystem,
        category: LogCategory.network.rawValue
    )
    
    /// UI 관련 로거
    public static let ui = Logger(
        subsystem: subsystem,
        category: LogCategory.ui.rawValue
    )
    
    /// 데이터 레이어 로거
    public static let data = Logger(
        subsystem: subsystem,
        category: LogCategory.data.rawValue
    )
    
    /// 도메인 로직 로거
    public static let domain = Logger(
        subsystem: subsystem,
        category: LogCategory.domain.rawValue
    )
    
    /// 앱 라이프사이클 로거
    public static let lifecycle = Logger(
        subsystem: subsystem,
        category: LogCategory.lifecycle.rawValue
    )
    
    /// 인증/보안 로거
    public static let auth = Logger(
        subsystem: subsystem,
        category: LogCategory.auth.rawValue
    )
    
    /// 성능 측정 로거
    public static let performance = Logger(
        subsystem: subsystem,
        category: LogCategory.performance.rawValue
    )
    
    /// 일반 로거
    public static let general = Logger(
        subsystem: subsystem,
        category: LogCategory.general.rawValue
    )
    
    // MARK: - Dynamic Logger
    
    /// 카테고리를 기반으로 동적 로거 생성
    /// - Parameter category: 로그 카테고리
    /// - Returns: 해당 카테고리의 Logger 인스턴스
    public static func logger(for category: LogCategory) -> Logger {
        switch category {
        case .network: return network
        case .ui: return ui
        case .data: return data
        case .domain: return domain
        case .lifecycle: return lifecycle
        case .auth: return auth
        case .performance: return performance
        case .general: return general
        }
    }
}

// MARK: - Convenience Logging Methods

extension Logger {
    
    /// 디버그 로그 (개발 중에만 표시, 릴리즈에서는 제거됨)
    /// - Parameters:
    ///   - message: 로그 메시지
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public func debug(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        self.log(level: .debug, "🔨 [\(fileName):\(line)] \(function) - \(message)")
    }
    
    /// 정보 로그 (일반적인 정보성 메시지)
    /// - Parameters:
    ///   - message: 로그 메시지
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public func info(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        self.log(level: .info, "ℹ️ [\(fileName):\(line)] \(function) - \(message)")
    }
    
    /// 경고 로그 (주의가 필요한 상황)
    /// - Parameters:
    ///   - message: 로그 메시지
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public func warning(
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        self.log(level: .error, "⚠️ [\(fileName):\(line)] \(function) - \(message)")
    }
    
    /// 에러 로그 (에러 발생 시)
    /// - Parameters:
    ///   - message: 로그 메시지
    ///   - error: Error 객체 (optional)
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public func error(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        if let error = error {
            self.log(level: .error, "❗ [\(fileName):\(line)] \(function) - \(message) | Error: \(error.localizedDescription)")
        } else {
            self.log(level: .error, "❗ [\(fileName):\(line)] \(function) - \(message)")
        }
    }
    
    /// 치명적 에러 로그 (앱 크래시 가능성이 있는 심각한 에러)
    /// - Parameters:
    ///   - message: 로그 메시지
    ///   - error: Error 객체 (optional)
    ///   - file: 파일 이름 (자동)
    ///   - function: 함수 이름 (자동)
    ///   - line: 라인 번호 (자동)
    public func fault(
        _ message: String,
        error: Error? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        if let error = error {
            self.log(level: .fault, "🚨 [\(fileName):\(line)] \(function) - \(message) | Error: \(error.localizedDescription)")
        } else {
            self.log(level: .fault, "🚨 [\(fileName):\(line)] \(function) - \(message)")
        }
    }
}

// MARK: - Performance Measurement

extension Logger {
    
    /// 성능 측정 시작
    /// - Parameter name: 측정할 작업 이름
    /// - Returns: Signpost ID
    public func beginSignpost(name: StaticString) -> OSSignpostID {
        let signpostID = OSSignpostID(log: OSLog(
            subsystem: Logger.subsystem,
            category: "Performance"
        ))
        os_signpost(
            .begin,
            log: OSLog(
                subsystem: Logger.subsystem,
                category: "Performance"
            ),
            name: name,
            signpostID: signpostID
        )
        return signpostID
    }
    
    /// 성능 측정 종료
    /// - Parameters:
    ///   - name: 측정한 작업 이름
    ///   - signpostID: beginSignpost에서 반환된 ID
    public func endSignpost(
        name: StaticString,
        signpostID: OSSignpostID
    ) {
        os_signpost(
            .end,
            log: OSLog(
                subsystem: Logger.subsystem,
                category: "Performance"
            ),
            name: name,
            signpostID: signpostID
        )
    }
}
