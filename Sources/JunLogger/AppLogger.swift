//
//  AppLogger.swift
//  JunLogger
//
//  Created by JunHyeok Lee on 12/9/25.
//  Copyright © 2025 com.junhyeok.JunLogger. All rights reserved.
//

import Foundation
import OSLog

/// 앱 전역 로깅 진입점.
///
/// `Log[.category]`가 `Logger` 인스턴스를 반환하므로 그 위에서 OSLog native 인터폴레이션을
/// 그대로 사용할 수 있다. 호출 위치에서 컴파일러의 OSLog SIL 최적화가 적용되어
/// privacy 마커와 lazy evaluation이 모두 보존된다.
///
/// ```swift
/// Log[.network].debug("GET \(path, privacy: .public) → \(status, privacy: .public)")
/// Log[.auth].error("token: \(jwt, privacy: .private(mask: .hash))")
/// Log[.lifecycle].notice("Entered background")
/// Log["Payment"].info("amount: \(amount)")
/// ```
///
/// 테스트나 특정 빌드 구성에서 로그를 끄려면 앱 시작 시점에 `Log.provider`를 교체한다.
///
/// ```swift
/// Log.provider = DisabledLogProvider()
/// ```
public enum Log {

    /// 카테고리당 `Logger`를 공급하는 제공자.
    ///
    /// 동시성 안전을 위해 앱 시작 시점에 한 번만 설정하는 것을 권장한다.
    nonisolated(unsafe) public static var provider: any LoggingProvider = OSLogProvider()

    /// 카테고리에 해당하는 `Logger`를 반환한다.
    ///
    /// 반환된 `Logger`에 직접 인터폴레이션 메시지를 호출하면 컴파일러가
    /// privacy 마커와 lazy evaluation을 보존한다.
    public static subscript(_ category: LogCategory) -> Logger {
        provider.logger(for: category)
    }

    // MARK: - Performance

    /// 성능 측정 시작.
    /// - Parameter name: 측정할 작업 이름
    /// - Returns: Signpost ID
    public static func beginSignpost(name: StaticString) -> OSSignpostID {
        Logger.performance.beginSignpost(name: name)
    }

    /// 성능 측정 종료.
    /// - Parameters:
    ///   - name: 측정한 작업 이름
    ///   - signpostID: `beginSignpost(name:)`에서 반환된 ID
    public static func endSignpost(name: StaticString, signpostID: OSSignpostID) {
        Logger.performance.endSignpost(name: name, signpostID: signpostID)
    }
}
