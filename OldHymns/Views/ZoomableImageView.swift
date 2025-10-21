//
//  ZoomableImageView.swift
//  OldHymns
//
//  Created by JooYoung Kim on 10/12/25.
//

// Views/ZoomableImageView.swift
import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var maxZoomScale: CGFloat = 2.0
    
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        
        // ✨ 기본 스크롤/줌 옵션
        scroll.isScrollEnabled = true
        scroll.bounces = true
        scroll.bouncesZoom = true
        
        // ⛔️ 초기엔 “무조건” 바운스 금지 (컨텐츠 크기에 따라 나중에 켜줌)
        scroll.alwaysBounceVertical = false
        scroll.alwaysBounceHorizontal = false
        
        // 깔끔: 인디케이터/터치
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.delaysContentTouches = false
        scroll.canCancelContentTouches = true
        scroll.backgroundColor = .clear
        
        let iv = UIImageView(image: image)
        iv.contentMode = .topLeft
        iv.clipsToBounds = true
        iv.isUserInteractionEnabled = true
        
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        iv.addGestureRecognizer(doubleTap)
        
        scroll.addSubview(iv)
        context.coordinator.imageView = iv
        context.coordinator.scrollView = scroll
        return scroll
    }
    
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        print("test log 0 - updateUIView")
        guard let iv = context.coordinator.imageView else { return }
        
        // 🔑 이미지 변경 감지용 키
        let imgKey = "\(image.size.width)x\(image.size.height)@\(image.scale)"
        let imageChanged = (context.coordinator.lastImageKey != imgKey)
        if imageChanged {
            context.coordinator.lastImageKey = imgKey
            context.coordinator.didSetInitialZoom = false   // ← 강제 초기화
        }
        
        iv.image = image
        iv.frame = CGRect(origin: .zero, size: image.size)
        scroll.contentSize = image.size
        let size = scroll.bounds.size
        if size.width == 0 || size.height == 0 {
            DispatchQueue.main.async { updateUIView(scroll, context: context) }
            return
        }
        
        // 배율 계산
        let widthRatio  = size.width  / max(image.size.width,  1)
        let heightRatio = size.height / max(image.size.height, 1)
        let heightRatio2 = max(heightRatio, 0.85)
        let minimumScale = min(widthRatio, heightRatio)        // 전체 보기
        let viewZoomScale = min(widthRatio, heightRatio2)      // 초기 배율
        
        scroll.minimumZoomScale = max(0.01, minimumScale)
        scroll.maximumZoomScale = maxZoomScale
        
        context.coordinator.fitWidthScale = widthRatio
        context.coordinator.minScale = scroll.minimumZoomScale
        context.coordinator.maxScale = scroll.maximumZoomScale
        
        // ✅ 이미지가 바뀌었거나, bounds가 바뀐 경우에만 초기 줌/오프셋 재설정
        if imageChanged || !context.coordinator.didSetInitialZoom || context.coordinator.lastBounds != size {
            context.coordinator.didSetInitialZoom = true
            context.coordinator.lastBounds = size
            
            // 먼저 최소 배율로 확 내려 의존 상태 제거
            scroll.setZoomScale(scroll.minimumZoomScale, animated: false)
            
            // 그다음 원하는 초기 배율로 세팅
            let initial = min(max(viewZoomScale, scroll.minimumZoomScale), scroll.maximumZoomScale)
            scroll.setZoomScale(initial, animated: false)
            
            // 오프셋/인셋 초기화
            scroll.contentInset = .zero
            scroll.contentOffset = .zero
        }
        print("test log 0-1 - updateUIView scroll.contentSize \(scroll.contentSize)")
        
        // 스크롤 가능 여부/바운스 갱신 + 오프셋 보정
        context.coordinator.syncContentSize(for: scroll)
        context.coordinator.updateBounce(for: scroll)
        context.coordinator.clampContentOffset(scroll)
        print("test log 0 - updateUIView scroll.contentSize \(scroll.contentSize)")
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        
        var didSetInitialZoom = false
        var lastBounds: CGSize = .zero
        
        // 🔑 마지막 이미지 키
        var lastImageKey: String?
        
        var fitWidthScale: CGFloat = 1
        var minScale: CGFloat = 1
        var maxScale: CGFloat = 2
        let doubleTapFactor: CGFloat = 2.0
        
        // ✅ 현재 zoomScale을 반영한 contentSize를 항상 재설정
        func syncContentSize(for sv: UIScrollView) {
            print("test log 6 (FIXED) - syncContentSize scrollView.contentSize \(sv.contentSize)")
            guard let iv = imageView else { return }
            // 부동소수 흔들림 완화용 반올림
            let w = (iv.bounds.width  * sv.zoomScale).rounded(.toNearestOrAwayFromZero)
            let h = (iv.bounds.height * sv.zoomScale).rounded(.toNearestOrAwayFromZero)
            sv.contentSize = CGSize(width: w, height: h)
                  print("test log 6 (FIXED) - syncContentSize scrollView.contentSize \(sv.contentSize)")
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            scrollView.contentInset = .zero
            syncContentSize(for: scrollView)
            updateBounce(for: scrollView)
            clampContentOffset(scrollView)
            print("test log 1 (FIXED) - scrollViewDidZoom scrollView.contentSize \(scrollView.contentSize)")
        }
        
        func updateBounce(for sv: UIScrollView) {
            print("test log 2-1 - updateBounce sv.contentSize \(sv.contentSize)")
            let canScrollX = sv.contentSize.width  > sv.bounds.width  + 0.5
            let canScrollY = sv.contentSize.height > sv.bounds.height + 0.5
            
            sv.alwaysBounceHorizontal = canScrollX
            sv.alwaysBounceVertical   = canScrollY
            sv.isScrollEnabled = canScrollX || canScrollY
            print("test log 2 - updateBounce sv.contentSize \(sv.contentSize)")
        }
        
        @objc func handleDoubleTap(_ gr: UITapGestureRecognizer) {
            guard let iv = imageView, let sv = scrollView else { return }
            let pointInImage = gr.location(in: iv)
            
            let fit = fitWidthScale
            let expandScale = min(maxScale, max(fit * doubleTapFactor, fit))
            let collapseScale = max(minScale, fit)
            let targetScale: CGFloat = (sv.zoomScale >= (fit * 1.05)) ? collapseScale : expandScale
            
            let bounds = sv.bounds.size
            let zoomW = bounds.width  / max(targetScale, 0.01)
            let zoomH = bounds.height / max(targetScale, 0.01)
            
            let originX = clamp(pointInImage.x - zoomW / 2, lower: 0, upper: max(0, (iv.bounds.width  - zoomW)))
            let originY = clamp(pointInImage.y - zoomH / 2, lower: 0, upper: max(0, (iv.bounds.height - zoomH)))
            let rect = CGRect(x: originX, y: originY, width: zoomW, height: zoomH)
            
            sv.zoom(to: rect, animated: true)
            
            // 애니메이션 후 상태 보정
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self, weak sv] in
                guard let self, let sv else { return }
                self.syncContentSize(for: sv)
                self.updateBounce(for: sv)
                self.clampContentOffset(sv)
            }
        }
        
        func clampContentOffset(_ sv: UIScrollView) {
            let maxX = max(0, sv.contentSize.width  - sv.bounds.width)
            let maxY = max(0, sv.contentSize.height - sv.bounds.height)
            let clampedX = clamp(sv.contentOffset.x, lower: 0, upper: maxX)
            let clampedY = clamp(sv.contentOffset.y, lower: 0, upper: maxY)
            if clampedX != sv.contentOffset.x || clampedY != sv.contentOffset.y {
                sv.setContentOffset(CGPoint(x: clampedX, y: clampedY), animated: false)
            }
            print("test log 3 - clampContentOffset sv.contentSize \(sv.contentSize)")
        }
        
        func clamp(_ v: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
            min(max(v, lower), upper)
        }
    }
}
