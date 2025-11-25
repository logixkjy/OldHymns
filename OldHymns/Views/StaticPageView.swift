//
//  StaticPageView.swift
//  OldHymns
//
//  Created by JooYoung Kim on 10/2/25.
//

// Features/StaticPageView.swift
import SwiftUI
import ComposableArchitecture

struct StaticPageView: View {
    let store: StoreOf<StaticPageFeature>
    @Environment(\.colorScheme) private var scheme
    
    // (선택) 간단 영구 저장 — 화면별로 따로 저장하려면 title을 키에 포함
    // 주석 해제 시 onAppear / onChange 에서 동기화 코드도 아래 주석 해제
    @AppStorage("StaticPage.fontSize") private var fontSize: Double = 17
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { vs in
            
            VStack(spacing: 0) {
                // 본문
                ScrollView {
                    Text(vs.text)
                        .font(.system(size: CGFloat(fontSize))) // ✅ 슬라이더 값 반영
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                }
                
                Divider()
                
                // 하단 슬라이더 바(고정 영역)
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size.smaller")
                    Slider(value: $fontSize, in: 12...60, step: 1)  // ✅ 슬라이더
                    Image(systemName: "textformat.size.larger")
                    Text("\(Int(fontSize))pt")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .appTintedLightOnly(scheme)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if InterstitialAdManager.shared.recordEventAndCheckShow() {
                    InterstitialAdManager.shared.showIfAvailable()
                }
            }
        }
    }
}


struct StaticPageHTMLView: View {
    let store: StoreOf<StaticPageFeature>
    @Environment(\.colorScheme) private var scheme
    
    // (선택) 간단 영구 저장 — 화면별로 따로 저장하려면 title을 키에 포함
    // 주석 해제 시 onAppear / onChange 에서 동기화 코드도 아래 주석 해제
    @AppStorage("StaticPage.fontSize") private var fontSize: Double = 17
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { vs in
            WithPerceptionTracking {                // ✅ perceptible state 추적 보장
                let html = HTMLBuilder.styledHTML(
                    body: vs.text,
                    fontSize: fontSize
                )
                
                VStack(spacing: 0) {
                    // 본문: 웹뷰가 나머지 공간을 모두 차지하도록
                    GeometryReader { geo in
                        WithPerceptionTracking {           // ✅ escaping 클로저 내부도 추적
                            HTMLWebView(html: html)
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                    
                    Divider()
                    
                    // 하단 슬라이더 바 (고정)
                    HStack(spacing: 12) {
                        Image(systemName: "textformat.size.smaller")
                        Slider(value: $fontSize, in: 12...60, step: 1)
                        Image(systemName: "textformat.size.larger")
                        Text("\(Int(fontSize))pt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .appTintedLightOnly(scheme)
                }
            }
        }
    }
}
