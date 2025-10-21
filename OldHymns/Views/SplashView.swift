//
//  SplashView.swift
//  OldHymns
//
//  Created by JooYoung Kim on 10/16/25.
//

import SwiftUI
import ComposableArchitecture
import GoogleMobileAds
import Combine

struct SplashView: View {
    @State private var timerQueue = DispatchQueue.main
    @State private var timer: DispatchSourceTimer?
    
    @Binding var isSplash: Bool
    @StateObject private var adBridge = SplashDelegateBridge()
    
    init(isSplash: Binding<Bool>) {
        self._isSplash = isSplash
    }
    
    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                Color(AppTheme.primary)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .task {
            // 1) SDK 시작 + 미리 로드
            AppOpenAdManager.shared.startSDKIfNeeded()
            
            AppOpenAdManager.shared.delegate = adBridge
            adBridge.onFinish = { [weak adBridge] in
                // (선택) 메인 보장
                DispatchQueue.main.async { isSplash = false }
                _ = adBridge // 캡처 경고 회피용(선택)
            }
            await AppOpenAdManager.shared.loadAd()
            
            // 2) 스플래시 타이머 시작
            startTimer()
        }
        .onDisappear {
            // 안전 정리 (선택)
            AppOpenAdManager.shared.delegate = nil
        }
    }
    
    private func startTimer() {
        timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer?.schedule(deadline: .now() + 3)
        timer?.setEventHandler {
            // 3) 타이머 끝났을 때: 광고 있으면 표시, 없으면 바로 진행
//            AppOpenAdManager.shared.showAdIfAvailable {
                self.isSplash = false
//            }
        }
        timer?.activate()
    }
}

/// SwiftUI에서 delegate 연결을 간편하게 하기 위한 브리지 객체
final class SplashDelegateBridge: NSObject, ObservableObject, AppOpenAdManagerDelegate {
    var onFinish: (() -> Void)?
    func appOpenAdDidFinish() { onFinish?() }
}
