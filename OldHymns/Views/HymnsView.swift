//
//  HymnsView.swift
//  OldHymns
//
//  Created by JooYoung Kim on 9/25/25.
//

// Features/HymnsView.swift
import SwiftUI
import ComposableArchitecture

struct HymnsView: View {
    @State private var availableWidth: CGFloat = 320
    let store: StoreOf<HymnsFeature>
    init(store: StoreOf<HymnsFeature>) { self.store = store }
    
    struct SectionInfo: Identifiable, Hashable {
        let id: Int
        let title: String        // "1~50" 등
        let items: [Hymn]
        var anchorID: String { "section-\(id)" }
    }
    
    private func makeSections(_ items: [Hymn], size: Int = 50) -> [SectionInfo] {
        let sorted = items.sorted { $0.number < $1.number }
        guard !sorted.isEmpty else { return [] }
        var out: [SectionInfo] = []; var offset = 0; var sid = 0
        while offset < sorted.count {
            let end = min(offset + size, sorted.count)
            out.append(.init(id: sid, title: "\(offset+1)~\(end)", items: Array(sorted[offset..<end])))
            sid += 1; offset = end
        }
        return out
    }
    
    @FocusState private var searchFocused: Bool
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { vs in
            WithPerceptionTracking {                // ✅ Perception 추적 시작
                let isSearching = !vs.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                VStack(spacing: 0) {
                    // 상단 고정 검색바
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                        TextField("번호(123) 또는 가사/초성(ㄱㄴㄷ) 검색", text: vs.binding(get: \.query, send: HymnsFeature.Action.setQuery))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .onSubmit { store.send(.search) }
                        if !vs.query.isEmpty {
                            Button {
                                vs.send(.binding(.set(\.query, "")))
                                store.send(.search)
                            } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    
                    Divider()
                    
                    // 본문: 검색 중이면 평면 리스트, 아니면 섹션+인덱스
                    if isSearching {
                        FlatList(store: store, results: vs.results)
                            .id("flat")                 // 전환 시 레이아웃 안정
                            .transition(.opacity)
                    } else {
                        let sections = makeSections(vs.results, size: 50)
                        SectionedListWithIndex(store: store, sections: sections)
                            .id("sectioned")
                            .transition(.opacity)
                    }
                    BannerAdView()
                        .frame(height: 50)
                        .background(.ultraThinMaterial)
                }
                .onAppear { store.send(.search) }
                .refreshable { store.send(.search) }
                .animation(.easeInOut, value: isSearching) // 모드 전환 애니메이션
            }
        }
    }
}

// MARK: - Cell 재사용
private struct HymnCell: View {
    let store: StoreOf<HymnsFeature>
    let h: Hymn
    var body: some View {
        NavigationLink {
            HymnDetailView(
                store: store,
                hymn: h
            )
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(h.number)").monospaced()
                    Text(h.title).font(.headline)
                    if h.bookmark { Image(systemName: "bookmark.fill").foregroundStyle(.yellow) }
                }
                Text(h.words.replacingOccurrences(of: ":", with: " "))
                    .lineLimit(1).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 검색 중: 섹션/인덱스 없음
private struct FlatList: View {
    let store: StoreOf<HymnsFeature>
    let results: [Hymn]
    var body: some View {
        List {
            ForEach(results) { h in HymnCell(store: store, h: h) }
        }
        .listStyle(.plain)
    }
}

// MARK: - 기본: 섹션 + 인덱스 바
private struct SectionedListWithIndex: View {
    let store: StoreOf<HymnsFeature>
    let sections: [HymnsView.SectionInfo]
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        ScrollViewReader { proxy in
            WithPerceptionTracking {                // ✅ Perception 추적 시작
                ZStack(alignment: .trailing) {
                    List {
                        ForEach(sections) { section in
                            Section(
                                header: Text(section.title)
                                    .font(.headline)
                                    .id(section.anchorID) // 헤더에 앵커
                            ) {
                                ForEach(section.items) { h in HymnCell(store: store, h: h) }
                            }
                        }
                    }
                    .listStyle(.plain)
                    
                    if sections.count > 1 {
                        VStack(spacing: 6) {
                            ForEach(sections, id: \.id) { section in
                                Button {
                                    let anchor = section.anchorID
                                    DispatchQueue.main.async {
                                        withAnimation(.easeInOut) { proxy.scrollTo(anchor, anchor: .top) }
                                    }
                                } label: {
                                    Text(section.title.split(separator: "~").first.map(String.init) ?? section.title)
                                        .font(.caption2)
                                        .padding(.vertical, 2).padding(.horizontal, 6)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                            }
                        }
                        .padding(.trailing, 6)
                        .appTintedLightOnly(scheme)
                    }
                }
            }
        }
    }
}
