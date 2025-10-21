import GoogleMobileAds
import UIKit

protocol AppOpenAdManagerDelegate: AnyObject {
    func appOpenAdDidFinish()
}

final class AppOpenAdManager: NSObject {
    static let shared = AppOpenAdManager()

    // ⚠️ 실제 운영 adUnitID로 교체 (지금은 테스트 단위)
    private let adUnitID = "ca-app-pub-2746869735313650/6577904495"

    private var appOpenAd: AppOpenAd?
    private var loadDate: Date?
    private var isShowingAd = false
    weak var delegate: AppOpenAdManagerDelegate?

    // 너무 잦은 노출 방지 (원하면 조정)
    private var lastShownAt: Date?
    private let minInterval: TimeInterval = 60 * 3 // 3분

    // MARK: - Public
    func startSDKIfNeeded() {
        // 중복 호출 안전
        MobileAds.shared.start()
    }
    
    func loadAd() async {
        print("AppOpenAd loadAd")
        // 4시간 만료 체크
        if let loadDate, Date().timeIntervalSince(loadDate) < 60*60*4, appOpenAd != nil { return }
        
        do {
            appOpenAd = try await AppOpenAd.load(
                with: adUnitID, request: Request())
            loadDate = Date()
            appOpenAd?.fullScreenContentDelegate = self
            print("AppOpenAd loaded")
        } catch {
            print("App open ad failed to load with error: \(error.localizedDescription)")
            appOpenAd = nil
            loadDate = nil
        }
    }
        
    /// 스플래시 종료 시점 등에서 호출
    func showAdIfAvailable(or onNoAd: (() -> Void)? = nil) {
        // 빈도 제한
        if let lastShownAt, Date().timeIntervalSince(lastShownAt) < minInterval {
            onNoAd?()
            return
        }
        guard !isShowingAd else { return }
        guard let ad = appOpenAd else {
            onNoAd?()
            return
        }
        isShowingAd = true
        DispatchQueue.main.async {
            ad.present(from: nil)
        }
    }

    // MARK: - Utilities
    private static func topViewController(
        _ base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        return base
    }
}

extension AppOpenAdManager: FullScreenContentDelegate {
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("AppOpenAd did present")
    }
    
    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("AppOpenAd fail to present:", error.localizedDescription)
        isShowingAd = false
        appOpenAd = nil
        Task {
            await loadAd()
        }
        // 광고 실패 → 바로 진행
        delegate?.appOpenAdDidFinish()
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("AppOpenAd did dismiss")
        isShowingAd = false
        lastShownAt = Date()
        appOpenAd = nil
        Task {
            await loadAd() // 다음 번을 위해 미리 로드
        }
        delegate?.appOpenAdDidFinish()
    }
}

//import SwiftUI
//import GoogleMobileAds
//import Combine
//
//protocol AppOpenAdManagerDelegate: AnyObject {
//    /// Method to be invoked when an app open ad life cycle is complete (i.e. dismissed or fails to
//    /// show).
//    func appOpenAdManagerAdDidComplete(_ appOpenAdManager: AppOpenAdManager)
//}
//
//// MARK: - 2. App Open Ad Manager (Observable Object)
///// 앱 오프닝 광고의 로드 및 표시를 관리하는 싱글톤 클래스.
//final class AppOpenAdManager: NSObject, ObservableObject {
//    // AdMob 테스트 광고 단위 ID. 실제 ID로 교체하세요.
//    private let adUnitID = "ca-app-pub-2746869735313650/6577904495"
//    
//    @Published var isLoadingAd = false
//    @Published var isAdShowing = false
//    
//    private var appOpenAd: AppOpenAd?
//    weak var appOpenAdManagerDelegate: AppOpenAdManagerDelegate?
//    private var loadTime: Date?
//    let timeoutInterval: TimeInterval = 4 * 3_600
//    
//    static let shared = AppOpenAdManager()
//    
//    private override init() {
//        super.init()
//    }
//    
//    // MARK: Ad Loading
//    /// 광고를 로드합니다.
//    func requestAd() async {
//        if isLoadingAd || isLoadingAd { return }
//        
//        print("App Open Ad Loading...")
//        isLoadingAd = true
//        do {
//            appOpenAd = try await AppOpenAd.load(
//                with: adUnitID, request: Request())
//            // [START set_delegate]
//            appOpenAd?.fullScreenContentDelegate = self
//            // [END set_delegate]
//            loadTime = Date()
//        } catch {
//            print("App open ad failed to load with error: \(error.localizedDescription)")
//            appOpenAd = nil
//            loadTime = nil
//        }
//        isLoadingAd = false
//    }
//    private func wasLoadTimeLessThanNHoursAgo(timeoutInterval: TimeInterval) -> Bool {
//        // Check if ad was loaded more than n hours ago.
//        if let loadTime = loadTime {
//            return Date().timeIntervalSince(loadTime) < timeoutInterval
//        }
//        return false
//    }
//    
//    private func isAdAvailable() -> Bool {
//        // Check if ad exists and can be shown.
//        return appOpenAd != nil && wasLoadTimeLessThanNHoursAgo(timeoutInterval: timeoutInterval)
//    }
//    
//    /// 광고를 표시할 수 있으면 표시합니다.
//    func showAdIfAvailable() {
//        // 이미 광고가 표시 중이거나, 로드 가능한 상태가 아니면 리턴
//        if isAdShowing {
//            return print("App open ad is already showing.")
//            return
//        }
//        
//        // If the app open ad is not available yet but is supposed to show, load
//        // a new ad.
//        if !isAdAvailable() {
//            print("App open ad is not ready yet.")
//            // The app open ad is considered to be complete in this example.
//            appOpenAdManagerDelegate?.appOpenAdManagerAdDidComplete(self)
//            // Load a new ad.
//            // [START_EXCLUDE silent]
//            if GoogleMobileAdsConsentManager.shared.canRequestAds {
//                Task {
//                    await requestAd()
//                }
//            }
//            // [END_EXCLUDE]
//            return
//        }
//        
//        if let appOpenAd {
//            appOpenAd.present(from: nil)
//            isAdShowing = true
//        }
//    }
//    
//    private func isAdLoading() -> Bool {
//        // GADAppOpenAd.load의 비동기 특성 때문에 정확한 로딩 상태를 파악하기 어려움.
//        // 여기서는 단순하게 Ad 객체의 존재 유무로 로드 여부를 가정합니다.
//        return appOpenAd == nil && loadTime == nil
//    }
//}
//
//// MARK: GADFullScreenContentDelegate Extension
//extension AppOpenAdManager: FullScreenContentDelegate {
//    /// 광고 표시 실패 시 호출됨
//    func ad(
//        _ ad: FullScreenPresentingAd,
//        didFailToPresentFullScreenContentWithError error: Error
//    ) {
//        print("App open ad failed to present with error: \(error.localizedDescription)")
//        isAdShowing = false
//        appOpenAd = nil
//        loadTime = nil
//        // 실패 시 다음 광고 로드
//        Task {
//            await requestAd()
//        }
//    }
//    
//    /// 광고가 닫힐 때 호출됨
//    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        print("App open ad was dismissed.")
//        isAdShowing = false
//        appOpenAd = nil
//        loadTime = nil
//        // 광고가 닫히면 다음 광고 로드
//        Task {
//            await requestAd()
//        }
//    }
//    
//    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
//        print("App open ad recorded an impression.")
//    }
//    
//    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
//        print("App open ad recorded a click.")
//    }
//    
//    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        print("App open ad will be dismissed.")
//    }
//    
//    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
//        print("App open ad will be presented.")
//    }
//}
