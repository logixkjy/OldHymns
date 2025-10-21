//
//  BannerAdView.swift
//  OldHymns
//
//  Created by JooYoung Kim on 10/17/25.
//

// BannerAdView.swift
import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String = "ca-app-pub-2746869735313650/2526983323"
    
    func makeUIView(context: Context) -> BannerView {
        let adSize = AdSizeBanner
        print("banner adSize \(adSize)")
        let banner = BannerView(adSize: adSize)
        
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared.firstKeyWindowRootViewController()
        banner.load(Request())
        return banner
    }
    func updateUIView(_ uiView: BannerView, context: Context) {
//        let newSize = currentOrientationAnchoredAdaptiveBanner(width: width)
//        if !CGSizeEqualToSize(newSize.size, uiView.adSize.size) {
//            uiView.adSize = newSize
//            uiView.load(Request())
//        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd( _ banner: BannerView) {
            print("Banner Loaded")
        }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: any Error) {
            print("Banner Failed \(error.localizedDescription)")
        }
    }
}

private extension UIApplication {
    func firstKeyWindowRootViewController() -> UIViewController? {
        connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .rootViewController
    }
}
private extension UIWindowScene {
    var keyWindow: UIWindow? { windows.first(where:  { $0.isKeyWindow })}
}
