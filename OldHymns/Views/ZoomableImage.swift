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
    
    func makeUIView(context: Context) -> ContainerView {
        let container = ContainerView(coordinator: context.coordinator)
        container.backgroundColor = .clear
        
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.bouncesZoom = false
        scroll.bounces = false
        scroll.decelerationRate = .fast
        
        let iv = context.coordinator.imageView
        iv.image = image
        iv.isUserInteractionEnabled = true
        iv.frame = CGRect(origin: .zero, size: image.size)
        
        scroll.addSubview(iv)
        scroll.contentSize = image.size
        
        // 스크롤뷰를 컨테이너에 꽉 채우기
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        
        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        
        return container
    }
    
    func updateUIView(_ container: ContainerView, context: Context) {
        let scroll = context.coordinator.scrollView
        let iv = context.coordinator.imageView

        if iv.image !== image {
            iv.image = image
            iv.frame = CGRect(origin: .zero, size: image.size)
            scroll.contentSize = image.size
        }

        // 레이아웃 이후(container.layoutSubviews)에서 자동으로 configureZoom가 호출됨
        container.imageForPendingLayout = image
    }
    
    // 컨테이너: 레이아웃이 실제로 잡힌 후 configureZoom 트리거
    final class ContainerView: UIView {
        private weak var coordinator: Coordinator?
        var imageForPendingLayout: UIImage?

        private var lastAppliedSize: CGSize = .zero

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let coordinator, let img = imageForPendingLayout else { return }
            // 사이즈가 바뀌었거나 최초 레이아웃일 때만
            if bounds.size != lastAppliedSize, bounds.width > 0, bounds.height > 0 {
                lastAppliedSize = bounds.size
                coordinator.configureZoom(scroll: coordinator.scrollView, image: img, force: true)
            }
        }
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let scrollView = UIScrollView()
        var imageView = UIImageView()
        private var lastBoundsSize: CGSize = .zero
        private(set) var minScale: CGFloat = 1.0
        private(set) var maxScale: CGFloat = 1.0
        private var isIninitialApplied: Bool = false
        private var topAligned: Bool
        
        init(topAligned: Bool) {
            self.topAligned = topAligned
        }
        
        func configureZoom(scroll: UIScrollView, image: UIImage, force: Bool) {
            let boundsSize = scroll.bounds.size
            let imageSize = image.size
            guard boundsSize.width > 0, boundsSize.height > 0 else { return }
            
            if !force && boundsSize == lastBoundsSize { return }
            lastBoundsSize = boundsSize
            
            let xScale = boundsSize.width / imageSize.width
            let yScale = boundsSize.height / imageSize.height
            let yScale2 = max((boundsSize.height / imageSize.height), 0.85)
            let newMinScale = (xScale > yScale) ? yScale : xScale
            let viewZoomScale = (xScale > yScale2) ? yScale2 : xScale
            
            let newMaxScale = max(newMinScale * 6, 4)
            
            scroll.minimumZoomScale = newMinScale
            scroll.maximumZoomScale = newMaxScale
            minScale = newMinScale
            maxScale = newMaxScale
            
            if !isIninitialApplied || force {
                scroll.zoomScale = viewZoomScale
                isIninitialApplied = true
            } else if scroll.zoomScale < minScale {
                scroll.setZoomScale(minScale, animated: false)
            }
            
//            centerOrTopAlign(scroll: scroll)
        }
        
        func centerOrTopAlign(scroll: UIScrollView) {
            let boundsSize = scroll.bounds.size
            let ivFrame = imageView.frame
            
            let contentW = ivFrame.size.width * scroll.zoomScale
            let contentH = ivFrame.size.height * scroll.zoomScale
            
            var inset = UIEdgeInsets.zero
            
            if contentW < boundsSize.width {
                let pad = (boundsSize.width - contentW) * 0.5
                inset.left = pad
                inset.right = pad
            }
            
            if topAligned {
                inset.top = 0
                inset.bottom = max(0, boundsSize.height - contentH)
            } else {
                if contentH < boundsSize.height {
                    let pad = (boundsSize.height - contentH) * 0.5
                    inset.top = pad
                    inset.bottom = pad
                }
            }
            
            scroll.contentInset = inset
        }
        
        @objc func handleDoubleTap(_ gr: UITapGestureRecognizer) {
            guard let scroll = gr.view as? UIScrollView else { return }
            let point = gr.location(in: imageView)
            
            if abs(scroll.zoomScale - minScale) < 0.001 {
                let targetScale = min(scroll.zoomScale * 2, maxScale)
                zoom(to: point, scale: targetScale, scroll: scroll, animated: true)
            } else {
                scroll.setZoomScale(minScale, animated: true)
            }
        }
        
        private func zoom(to point: CGPoint, scale: CGFloat, scroll: UIScrollView, animated: Bool) {
            let width = scroll.bounds.size.width / scale
            let height = scroll.bounds.size.height / scale
            let rect = CGRect(x: point.x - width / 2,
                              y: point.y - height / 2,
                              width: width,
                              height: height)
            scroll.zoom(to: rect, animated: animated)
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // 확대/축소 중에도 인셋 재조정 (센터/상단 정렬 유지)
            centerOrTopAlign(scroll: scrollView)
        }
    }
}
