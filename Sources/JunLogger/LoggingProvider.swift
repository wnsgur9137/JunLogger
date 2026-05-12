//
//  LoggingProvider.swift
//  JunLogger
//
//  Copyright © 2025 com.junhyeok.JunLogger. All rights reserved.
//

import Foundation
import OSLog

/// 카테고리당 `Logger` 인스턴스를 제공하는 추상화.
///
/// 테스트 환경에서는 `DisabledLogProvider`를 주입해 모든 로그를 no-op으로 만들 수 있다.
public protocol LoggingProvider: Sendable {
    func logger(for category: LogCategory) -> Logger
}

/// OSLog 기반 기본 제공자. `Bundle.main.bundleIdentifier`를 subsystem으로 사용한다.
public struct OSLogProvider: LoggingProvider {

    public let subsystem: String

    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "") {
        self.subsystem = subsystem
    }

    public func logger(for category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}

/// 모든 로그 출력을 끄는 제공자. 단위 테스트나 특정 빌드 구성에서 사용.
public struct DisabledLogProvider: LoggingProvider {

    public init() {}

    public func logger(for category: LogCategory) -> Logger {
        Logger(.disabled)
    }
}
