//
//  Logger+Extension.swift
//  JunLogger
//
//  Created by JunHyeok Lee on 12/9/25.
//  Copyright © 2025 com.junhyeok.JunLogger. All rights reserved.
//

import Foundation
import OSLog

extension Logger {

    /// 앱의 Bundle Identifier를 subsystem으로 사용한다.
    fileprivate static var defaultSubsystem: String {
        Bundle.main.bundleIdentifier ?? ""
    }

    // MARK: - Category Loggers (1.x 호환 경로)
    //
    // `Logger.network.debug("...")`처럼 Logger 인스턴스를 직접 사용하던 1.x 호출자를 위해
    // 정적 프로퍼티를 유지한다. 신규 코드는 `Log[.network].debug(...)` 패턴을 권장.

    public static let network = Logger(
        subsystem: defaultSubsystem,
        category: LogCategory.network.rawValue
    )

    public static let ui = Logger(
        subsystem: defaultSubsystem,
        category: LogCategory.ui.rawValue
    )

    public static let data = Logger(
        subsystem: defaultSubsystem,
        category: LogCategory.data.rawValue
    )

    public static let domain = Logger(
        subsystem: defaultSubsystem,
        category: LogCategory.domain.rawValue
    )

    public static let lifecycle = Logger(
        subsystem: defaultSubsystem,
        category: LogCategory.lifecycle.rawValue
    )

    public static let auth = Logger(
        subsystem: defaultSubsystem,
        category: LogCategory.auth.rawValue
    )

    public static let performance = Logger(
        subsystem: defaultSubsystem,
        category: LogCategory.performance.rawValue
    )

    public static let general = Logger(
        subsystem: defaultSubsystem,
        category: LogCategory.general.rawValue
    )
}

// MARK: - Performance Measurement

extension Logger {

    /// 성능 측정 시작.
    /// - Parameter name: 측정할 작업 이름
    /// - Returns: Signpost ID
    public func beginSignpost(name: StaticString) -> OSSignpostID {
        let log = OSLog(
            subsystem: Logger.defaultSubsystem,
            category: LogCategory.performance.rawValue
        )
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: signpostID)
        return signpostID
    }

    /// 성능 측정 종료.
    /// - Parameters:
    ///   - name: 측정한 작업 이름
    ///   - signpostID: `beginSignpost(name:)`에서 반환된 ID
    public func endSignpost(
        name: StaticString,
        signpostID: OSSignpostID
    ) {
        let log = OSLog(
            subsystem: Logger.defaultSubsystem,
            category: LogCategory.performance.rawValue
        )
        os_signpost(.end, log: log, name: name, signpostID: signpostID)
    }
}
