//
//  LogCategory.swift
//  BaseDomain
//
//  Created by JunHyeok Lee on 12/9/25.
//  Copyright © 2025 com.junhyeok.JunLogger. All rights reserved.
//

import Foundation

/// 로그 카테고리 정의
///
/// 각 카테고리는 서로 다른 로거를 사용하여 Console.app에서 필터링 가능
public enum LogCategory: String, CaseIterable {
    /// 네트워크 관련 로그 (API 호출, 응답, 에러)
    case network = "Network"
    
    /// UI 관련 로그 (화면 전환, 사용자 인터랙션)
    case ui = "UI"
    
    /// 데이터 레이어 로그 (Repository, Database, Cache)
    case data = "Data"
    
    /// 도메인 로직 로그 (UseCase, Business Logic)
    case domain = "Domain"
    
    /// 앱 라이프사이클 로그 (시작, 종료, 백그라운드)
    case lifecycle = "Lifecycle"
    
    /// 인증/보안 관련 로그
    case auth = "Auth"
    
    /// 성능 측정 로그
    case performance = "Performance"
    
    /// 일반 로그
    case general = "General"
}
