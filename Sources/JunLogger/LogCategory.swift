//
//  LogCategory.swift
//  JunLogger
//
//  Created by JunHyeok Lee on 12/9/25.
//  Copyright © 2025 com.junhyeok.JunLogger. All rights reserved.
//

import Foundation

/// 로그 카테고리.
///
/// `rawValue`는 OSLog의 `category` 문자열로 그대로 사용되며 Console.app의 `category:Network`
/// 같은 필터에 매핑된다. 외부 사용자는 문자열 리터럴이나 정적 프로퍼티 또는 직접 `init`을 통해
/// 임의 카테고리를 정의할 수 있다.
///
/// ```swift
/// Log[.network].debug("...")
/// Log["Payment"].info("...")
/// ```
public struct LogCategory: RawRepresentable, ExpressibleByStringLiteral, Hashable, Sendable {

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    // MARK: - Built-in Categories

    /// 네트워크 관련 로그 (API 호출, 응답, 에러)
    public static let network: LogCategory = "Network"

    /// UI 관련 로그 (화면 전환, 사용자 인터랙션)
    public static let ui: LogCategory = "UI"

    /// 데이터 레이어 로그 (Repository, Database, Cache)
    public static let data: LogCategory = "Data"

    /// 도메인 로직 로그 (UseCase, Business Logic)
    public static let domain: LogCategory = "Domain"

    /// 앱 라이프사이클 로그 (시작, 종료, 백그라운드)
    public static let lifecycle: LogCategory = "Lifecycle"

    /// 인증/보안 관련 로그
    public static let auth: LogCategory = "Auth"

    /// 성능 측정 로그
    public static let performance: LogCategory = "Performance"

    /// 일반 로그
    public static let general: LogCategory = "General"

    /// 라이브러리가 기본 제공하는 카테고리 목록.
    public static let allBuiltInCategories: [LogCategory] = [
        .network, .ui, .data, .domain, .lifecycle, .auth, .performance, .general
    ]
}
