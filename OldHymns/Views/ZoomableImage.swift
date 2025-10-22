//
//  ZoomableImage.swift
//  OldHymns
//
//  Created by JooYoung Kim on 10/14/25.
//

import SwiftUI
import UIKit

struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    let topAligned: Bool = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator(topAligned: topAligned)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.bouncesZoom = false
        scroll.bounces = false
        scroll.backgroundColor = .clear
        scroll.decelerationRate = .fast
        scroll.contentInsetAdjustmentBehavior = .never
        
        let iv = context.coordinator.imageView
//        iv.image = image
//        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = true
//        iv.frame = CGRect(origin: .zero, size: image.size)
        
        scroll.addSubview(iv)
//        scroll.contentSize = image.size
        
        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        
//        context.coordinator.configureZoom(scroll: scroll, image: image, force: true)
        
        return scroll
    }
    
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let co = context.coordinator
        
        co.replaceImage(image, in: scroll)
//        if context.coordinator.imageView.image !== image {
//            context.coordinator.imageView.image = image
//            context.coordinator.imageView.frame = CGRect(origin: .zero, size: image.size)
//            scroll.contentSize = image.size
//            context.coordinator.configureZoom(scroll: scroll, image: image, force: true)
//        } else {
//            context.coordinator.configureZoom(scroll: scroll, image: image, force: true)
//        }
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView = UIImageView()
//        private var lastBoundsSize: CGSize = .zero
        private(set) var minScale: CGFloat = 1.0
        private(set) var maxScale: CGFloat = 1.0
//        private var isIninitialApplied: Bool = false
        private var didInit = false
        private var topAligned: Bool
        
        init(topAligned: Bool) {
            self.topAligned = topAligned
        }
        
        private func fixedOrientation(_ image: UIImage) -> UIImage {
            guard image.imageOrientation != .up else { return image }
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return normalized ?? image
        }
        
        func replaceImage(_ newImage: UIImage, in scroll: UIScrollView) {
            let img = fixedOrientation(newImage)
            
            // 1) 이미지뷰 프레임 리셋 (프레임 기반)
            imageView.image = img
            imageView.translatesAutoresizingMaskIntoConstraints = true
            imageView.frame = CGRect(origin: .zero, size: img.size)
            scroll.contentSize = imageView.bounds.size
            
            // 2) 레이아웃이 안정된 “다음 프레임”에서 재계산
            DispatchQueue.main.async { [weak self, weak scroll] in
                guard let self, let scroll = scroll else { return }
                self.configureZoomAfterLayout(scroll: scroll)
            }
        }
        
        private func configureZoomAfterLayout(scroll: UIScrollView) {
            // bounds가 0이면 한 프레임 더 미룸
            guard scroll.bounds.width > 0, scroll.bounds.height > 0 else {
                DispatchQueue.main.async { [weak self, weak scroll] in
                    guard let self, let scroll = scroll else { return }
                    self.configureZoomAfterLayout(scroll: scroll)
                }
                return
            }
            
            // 3) "줌 기준"은 항상 imageView.bounds (pt)
            let bounds = scroll.bounds.size
            let base   = imageView.bounds.size
            guard base.width > 0, base.height > 0 else { return }
            
            let xScale = bounds.width / base.width
            let yScale = bounds.height / base.height
            let yScale2 = max((bounds.height / base.height), 0.85)
            let newMin = (xScale > yScale) ? yScale : xScale
            let viewZoom = (xScale > yScale2) ? yScale2 : xScale
            
//            let newMin = min(bounds.width / base.width, bounds.height / base.height)
            let newMax = max(newMin * 6, 4)
            
            scroll.minimumZoomScale = newMin
            scroll.maximumZoomScale = newMax
            minScale = newMin
            maxScale = newMax
            
            // 화면 맞춤
            scroll.setZoomScale(viewZoom, animated: false)
            centerOrTopAlign(scroll: scroll)  // ← 인셋 + 오프셋 동시 보정
            didInit = true
        }

        
//        func configureZoom(scroll: UIScrollView, image: UIImage, force: Bool) {
//            let boundsSize = scroll.bounds.size
//            let imageSize = image.size
//            guard boundsSize.width > 0, boundsSize.height > 0 else {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
//                    self.configureZoom(scroll: scroll, image: image, force: force)
//                }
//                return
//            }
//            
//            if !force && boundsSize == lastBoundsSize { return }
//            lastBoundsSize = boundsSize
//            
//            let xScale = boundsSize.width / imageSize.width
//            let yScale = boundsSize.height / imageSize.height
//            let yScale2 = max((boundsSize.height / imageSize.height), 0.85)
//            let newMinScale = (xScale > yScale) ? yScale : xScale
//            let viewZoomScale = (xScale > yScale2) ? yScale2 : xScale
//            
//            let newMaxScale = max(newMinScale * 6, 4)
//            print("boundsLog imageSize W \(imageSize.width) zoom \(viewZoomScale) \(imageSize.width * viewZoomScale) boundsW \(boundsSize.width)")
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
//                scroll.minimumZoomScale = newMinScale
//                scroll.maximumZoomScale = newMaxScale
//                scroll.setZoomScale(viewZoomScale, animated: false)
//                self.centerOrTopAlign(scroll: scroll)
//            }
//            minScale = newMinScale
//            maxScale = newMaxScale
//            
////            if !isIninitialApplied || force {
////                scroll.zoomScale = viewZoomScale
////                isIninitialApplied = true
////            } else if scroll.zoomScale < minScale {
////                scroll.setZoomScale(minScale, animated: false)
////            }
//            
//        }
        
//        func centerOrTopAlign(scroll: UIScrollView) {
//            let boundsSize = scroll.bounds.size
//            let ivSize = imageView.bounds.size
//            let contentW = ivSize.width * scroll.zoomScale
//            let contentH = ivSize.height * scroll.zoomScale
//            var inset = UIEdgeInsets.zero
//            
//            if contentW < boundsSize.width {
//                let pad = (boundsSize.width - contentW) * 0.5
//                inset.left = pad
//                inset.right = pad
//            }
//            
////            if topAligned {
//                inset.top = 0
//                inset.bottom = max(0, boundsSize.height - contentH)
////            } else {
////                if contentH < boundsSize.height {
////                    let pad = (boundsSize.height - contentH) * 0.5
////                    inset.top = pad
////                    inset.bottom = pad
////                }
////            }
//            
//            scroll.contentInset = inset
//            scroll.scrollIndicatorInsets = inset
//
//            // !! 핵심: 인셋에 맞춰 오프셋도 보정해야 함
//            // 인셋을 주면 '보이는 원점'은 -inset 이 되어야 중앙이 정확히 맞음.
//            let targetOffset = CGPoint(x: -inset.left, y: -inset.top)
//
//            // 레이아웃이 안정된 다음 프레임에 세팅해야 튐/무시 방지
//            DispatchQueue.main.async {
//                // overscroll clamp를 피하려면 contentSize도 최신이어야 함
//                // (줌 중에는 시스템이 contentSize를 갱신해 줍니다)
//                scroll.setContentOffset(targetOffset, animated: false)
//            }
//        }
        
        @objc func handleDoubleTap(_ gr: UITapGestureRecognizer) {
            guard let scroll = gr.view as? UIScrollView else { return }
            let point = gr.location(in: imageView)
            if abs(scroll.zoomScale - minScale) < 0.001 {
                let target = min(scroll.zoomScale * 2, maxScale)
                let w = scroll.bounds.width / target
                let h = scroll.bounds.height / target
                let rect = CGRect(x: point.x - w/2, y: point.y - h/2, width: w, height: h)
                scroll.zoom(to: rect, animated: true)
            } else {
                scroll.setZoomScale(minScale, animated: true)
                centerOrTopAlign(scroll: scroll)
            }
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let bounds = scrollView.bounds.size
            let base   = imageView.bounds.size
            
            let contentW = base.width  * scrollView.zoomScale
            let contentH = base.height * scrollView.zoomScale
            
            var topInset = UIDevice.current.userInterfaceIdiom == .pad ? (bounds.height - contentH) * 0.5 : 0
            var sideInset = (bounds.width - contentW) * 0.5
            if topInset < 0.0 { topInset = 0.0 }
            if sideInset < 0.0 { sideInset = 0.0}
            
            let inset = UIEdgeInsets(top: 0, left: sideInset, bottom: -topInset, right: -sideInset)
            scrollView.contentInset = inset
        }
        
//        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
//            centerOrTopAlign(scroll: scrollView)
//        }
        
        func centerOrTopAlign(scroll: UIScrollView) {
            let bounds = scroll.bounds.size
            let base   = scroll.bounds.size
            
            let contentW = base.width  * scroll.zoomScale
            let contentH = base.height * scroll.zoomScale
            
            var topInset = UIDevice.current.userInterfaceIdiom == .pad ? (bounds.height - contentH) * 0.5 : 0
            var sideInset = (bounds.width - contentW) * 0.5
            if topInset < 0.0 { topInset = 0.0 }
            if sideInset < 0.0 { sideInset = 0.0}
            
            let inset = UIEdgeInsets(top: 0, left: sideInset, bottom: -topInset, right: -sideInset)
            scroll.contentInset = inset
            scroll.scrollIndicatorInsets = inset
            
            // **핵심: 오프셋도 인셋에 맞춰 보정**
            let target = CGPoint(x: -inset.left, y: -inset.top)
            if scroll.contentOffset != target {
                scroll.setContentOffset(target, animated: false)
            }
        }
    }
}
