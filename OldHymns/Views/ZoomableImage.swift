//
//  ZoomableImage.swift
//  OldHymns
//
//  Created by JooYoung Kim on 10/14/25.
//

import SwiftUI
import UIKit

public struct ZoomableImage: View {
    public var img: UIImage
    @State private var containerSize: CGSize = .zero
    @State private var baseZoom: CGFloat = 1
    @State private var minZoom: CGFloat = 1
    @State private var maxZoom: CGFloat = 2
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var refitToken: Int = 0
    
    public init(img: UIImage) { self.img = img }
    
    public var body: some View {
        GeometryReader { geo in
            Representable(
                image: img,
                baseZoom: baseZoom,
                minZoom: minZoom,
                maxZoom: maxZoom,
                refitToken: refitToken
            )
            .onAppear {
                containerSize = geo.size
                recalcZoom(for: geo.size, image: img)
            }
            .onChange(of: geo.size) { newSize in
                containerSize = newSize
                recalcZoom(for: newSize, image: img)
            }
            .onChange(of: img) { newImage in
                // 이미지 교체 시에도 즉시 재계산
                recalcZoom(for: containerSize, image: newImage)
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    // baseZoom 값이 최신인지 보장 후 토큰 갱신
                    recalcZoom(for: containerSize, image: img)
                    refitToken &+= 1
                }
            }
        }
    }
    
    private func recalcZoom(for size: CGSize, image: UIImage) {
        guard size.width > 0, size.height > 0,
              image.size.width > 0, image.size.height > 0 else { return }
        
        let maxSize = size
        let imageSize = image.size
        let widthRatio  = maxSize.width  / imageSize.width
        let heightRatio = maxSize.height / imageSize.height
        let heightRatio2 = max(heightRatio, 0.85)
        
        let minimumScale  = min(widthRatio, heightRatio)        // 전체 보이기
        let viewZoomScale = min(widthRatio, heightRatio2)       // 초기/기본 줌
        self.minZoom  = max(minimumScale, 0.01)
        self.baseZoom = max(viewZoomScale, self.minZoom)
        self.maxZoom  = 2.0
    }
}

private struct Representable: UIViewRepresentable {
    var image: UIImage
    var baseZoom: CGFloat
    var minZoom: CGFloat
    var maxZoom: CGFloat
    var refitToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.bouncesZoom = true
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.decelerationRate = .fast
        scroll.backgroundColor = .clear
        scroll.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .center
        imageView.frame = CGRect(origin: .zero, size: image.size)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)

        scroll.addSubview(imageView)
        context.coordinator.scrollView = scroll
        context.coordinator.imageView = imageView
        context.coordinator.baseZoom = baseZoom
        context.coordinator.lastImageSize = image.size

        // 초기 세팅
        scroll.minimumZoomScale = minZoom
        scroll.maximumZoomScale = maxZoom
        scroll.setZoomScale(baseZoom, animated: false)
        adjustInsetsTopAligned(scroll)
        snapToTop(scroll)

        context.coordinator.didInitialFit = false
        context.coordinator.initialFitRetry = 0
        context.coordinator.lastRefitToken = refitToken
        
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.baseZoom = baseZoom

        // ✅ refitToken이 바뀌었으면 강제로 화면맞춤 재적용
        if context.coordinator.lastRefitToken != refitToken {
            context.coordinator.lastRefitToken = refitToken
            
            // ✅ 사용자 줌 유지: 사용자가 한번이라도 줌 변경했으면 '맞춤'을 건너뜀
            if context.coordinator.userAdjustedZoom == false {
                scroll.minimumZoomScale = minZoom
                scroll.maximumZoomScale = maxZoom
                scroll.setZoomScale(baseZoom, animated: false)
            } else {
                // 사용자 줌 유지: 범위만 갱신 + 클램프
                scroll.minimumZoomScale = minZoom
                scroll.maximumZoomScale = maxZoom
                let clamped = max(minZoom, min(scroll.zoomScale, maxZoom))
                if abs(clamped - scroll.zoomScale) > 0.001 {
                    scroll.setZoomScale(clamped, animated: false)
                }
            }
            adjustInsetsTopAligned(scroll)
            snapToTop(scroll)
            return
        }
        
        let imageChanged = context.coordinator.lastImageSize != image.size
        if imageChanged {
            context.coordinator.lastImageSize = image.size
            replaceImageAndReset(scroll, image: image, min: minZoom, base: baseZoom, max: maxZoom)
            return
        }

        // 이미지가 같아도 줌 범위/베이스가 바뀌면 반영
        if scroll.minimumZoomScale != minZoom { scroll.minimumZoomScale = minZoom }
        if scroll.maximumZoomScale != maxZoom { scroll.maximumZoomScale = maxZoom }

        // 현재 줌이 범위를 벗어나면 base로
        if scroll.zoomScale < minZoom - 0.0001 || scroll.zoomScale > maxZoom + 0.0001 {
            scroll.setZoomScale(baseZoom, animated: false)
        }

        // 레이아웃 변경(회전 등) 후에도 상단 정렬 유지
        DispatchQueue.main.async {
            adjustInsetsTopAligned(scroll)
            // 상단 고정이 목적이므로 Y만 스냅 (가로는 가운데 유지)
            snapToTop(scroll)
        }
        
        scheduleInitialFitIfNeeded(scroll, context: context)
    }

    // MARK: - Helpers
    /// 첫 표시 시 레이아웃 완료를 기다렸다가 baseZoom을 강제로 적용.
    /// (bounds가 0이거나 window가 없거나 아직 레이아웃 전이면 재시도)
    private func scheduleInitialFitIfNeeded(_ scroll: UIScrollView, context: Context) {
        guard !context.coordinator.didInitialFit else { return }

        // 🔹 먼저 retryLater를 선언해야 함
        var retryLater: (() -> Void)!
        retryLater = {
            guard context.coordinator.initialFitRetry < 8 else {
                context.coordinator.didInitialFit = true
                return
            }
            context.coordinator.initialFitRetry += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05 ) {
                tryFit()   // 이때 tryFit이 아래에 선언되어 있으므로 참조 가능
            }
        }

        // 🔹 이제 tryFit 선언
        func tryFit() {
            guard scroll.window != nil, scroll.bounds.size != .zero else {
                retryLater()
                return
            }

            scroll.layoutIfNeeded()
            scroll.setZoomScale(baseZoom, animated: false)
            adjustInsetsTopAligned(scroll)
            snapToTop(scroll)

            context.coordinator.didInitialFit = true
        }

        // 첫 시도 실행
        tryFit()
    }
    
    /// 이미지 교체 시, 안정된 순서로 모든 상태 초기화 후 상단 고정.
    private func replaceImageAndReset(_ scroll: UIScrollView,
                                      image: UIImage,
                                      min: CGFloat, base: CGFloat, max: CGFloat)
    {
        guard let iv = (scroll.subviews.first { $0 is UIImageView }) as? UIImageView else { return }

        // 1) 줌 1배로 초기화(왜? 기존 줌 상태에서 프레임/콘텐츠 갱신하면 값이 튀기 쉬움)
        scroll.setZoomScale(1.0, animated: false)

        // 2) 이미지 교체 + 이미지뷰 크기 원본으로 재설정
        iv.image = image
        iv.frame = CGRect(origin: .zero, size: image.size)

        // (참고) contentSize는 zoomable뷰에선 스크롤뷰가 관리하지만, 초기값을 명시적으로 맞춰줘도 OK
        scroll.contentSize = image.size

        // 3) 줌 범위 재설정
        scroll.minimumZoomScale = min
        scroll.maximumZoomScale = max

        // 4) 원하는 기본 줌으로 맞춤
        scroll.setZoomScale(base, animated: false)

        // 5) 줌이 반영된 다음 프레임 기준으로 인셋 재계산 -> 상단 고정 + 오프셋 보정
        DispatchQueue.main.async {
            adjustInsetsTopAligned(scroll)
            snapToTop(scroll)
        }
    }

    /// 세로는 상단 고정(top=0), 가로는 가운데 정렬(남는 폭만큼 좌우 인셋 균등)
    private func adjustInsetsTopAligned(_ scroll: UIScrollView) {
        guard let imageView = (scroll.subviews.first { $0 is UIImageView }) else { return }
        scroll.layoutIfNeeded() // 최신 프레임 적용

        let bounds = scroll.bounds.size
        let frame  = imageView.frame

        let horizontalInset = max(0, (bounds.width - frame.width) * 0.5)
        // top=0으로 고정, 남는 세로는 bottom으로만
        let bottomInset     = max(0, bounds.height - frame.height)

        scroll.contentInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: bottomInset, right: horizontalInset)
    }

    /// 상단(Top)으로 정확히 붙이기 위해 contentOffset 보정
    private func snapToTop(_ scroll: UIScrollView) {
        // top inset이 0이므로, y는 항상 0이 되어야 상단 고정
        // (x는 가운데 정렬을 유지하기 위해 scroll.contentInset.left에 맞춰 -left로 보정됨)
        let target = CGPoint(x: -scroll.contentInset.left, y: -scroll.contentInset.top)
        if scroll.contentOffset != target {
            scroll.setContentOffset(target, animated: false)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var baseZoom: CGFloat = 1
        var lastImageSize: CGSize = .zero
        
        var didInitialFit: Bool = false
        var initialFitRetry = 0
        var userAdjustedZoom: Bool = false
        var lastRefitToken: Int = 0

        @objc func onDoubleTap(_ g: UITapGestureRecognizer) {
            guard let scroll = scrollView, let view = imageView else { return }
            let p = g.location(in: view)
            let isAtBase = abs(scroll.zoomScale - baseZoom) < 0.001
            let target = isAtBase ? scroll.maximumZoomScale : baseZoom

            let size = CGSize(width: scroll.bounds.width / target, height: scroll.bounds.height / target)
            let origin = CGPoint(x: p.x - size.width * 0.5, y: p.y - size.height * 0.5)
            let rect = CGRect(origin: origin, size: size)
            scroll.zoom(to: rect, animated: true)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        func scrollViewDidZoom(_ scroll: UIScrollView) {
            userAdjustedZoom = true
            // 줌 중에도 항상 상단 고정 유지
            guard let iv = imageView else { return }
            let b = scroll.bounds.size
            let f = iv.frame
            let horizontalInset = max(0, (b.width - f.width) * 0.5)
            let bottomInset     = max(0, b.height - f.height)
            scroll.contentInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: bottomInset, right: horizontalInset)
            // 상단 스냅 (y는 0 유지)
            let targetY: CGFloat = -scroll.contentInset.top
            if abs(scroll.contentOffset.y - targetY) > 0.5 { // 미세 흔들림 방지
                scroll.contentOffset.y = targetY
            }
        }
    }
}
