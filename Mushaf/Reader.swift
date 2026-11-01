import SwiftUI

struct ReaderView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("mushaf.theme") private var themeRaw = MushafTheme.auto.rawValue
    @AppStorage("mushaf.lastPage") private var lastPage = 1
    @State private var store = MushafStore()
    @State private var page = ReaderView.initialPage
    @State private var chrome = false
    @State private var showSurahs = false
    @State private var showJuz = false
    @State private var showTokens = false
    @State private var scrubbing = false
    @State private var scrub = Double(ReaderView.initialPage)
    private let screenshotLocked = ReaderView.locked

    private var theme: MushafTheme { Self.themeOverride ?? MushafTheme(rawValue: themeRaw) ?? .auto }
    private var palette: Palette { theme.palette(for: scheme) }

    var body: some View {
        Group {
            if ProcessInfo.processInfo.arguments.contains("-tokens") {
                TokenPreview()
            } else if let error = store.error {
                Text(error).font(MushafType.ui).foregroundStyle(palette.uiSecondary).padding(32)
            } else {
                reader
            }
        }
        .environment(\.palette, palette)
        .preferredColorScheme(theme.preferredScheme)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private var reader: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                palette.desk.ignoresSafeArea()
                FingerPager(
                    index: pagerIndex(landscape),
                    count: landscape ? 302 : 604,
                    reduceMotion: reduceMotion,
                    page: { index in AnyView(spread(index, landscape: landscape, in: geo.size)) },
                    onIndex: { index in
                        page = landscape ? index * 2 + 1 : index + 1
                        if !scrubbing { scrub = Double(page) }
                    },
                    onTap: { chrome.toggle() }
                )
                .padding(.horizontal, landscape ? 16 : 28)
                .padding(.vertical, 76)
                if chrome {
                    VStack(spacing: 0) {
                        topBar(landscape)
                        Spacer()
                        scrubber
                    }
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: chrome)
        }
        .onChange(of: page) { _, new in
            if !screenshotLocked { lastPage = new }
            if !scrubbing { scrub = Double(new) }
        }
        .sheet(isPresented: $showSurahs) { surahSheet }
        .sheet(isPresented: $showJuz) { juzSheet }
        .sheet(isPresented: $showTokens) { TokenPreview() }
    }

    private func spread(_ index: Int, landscape: Bool, in size: CGSize) -> some View {
        let numbers = landscape ? [index * 2 + 1, index * 2 + 2] : [index + 1]
        let pages = numbers.compactMap { store.page($0) }
        let fitted = pageSize(pages: pages.count, in: CGSize(width: size.width - (landscape ? 32 : 56), height: size.height - 152))
        return HStack(spacing: 18) {
            ForEach(pages) { item in
                MushafPageView(page: item).frame(width: fitted.width, height: fitted.height)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pageSize(pages: Int, in available: CGSize) -> CGSize {
        let gap: CGFloat = pages > 1 ? 18 : 0
        let aspect: CGFloat = 1 / 1.62
        var width = (available.width - gap) / CGFloat(max(pages, 1))
        var height = width / aspect
        if height > available.height {
            height = available.height
            width = height * aspect
        }
        return CGSize(width: max(width, 1), height: max(height, 1))
    }

    private func pagerIndex(_ landscape: Bool) -> Int {
        landscape ? (page - 1) / 2 : page - 1
    }

    private func topBar(_ landscape: Bool) -> some View {
        let right = landscape ? ((page - 1) / 2) * 2 + 1 : page
        let label = landscape ? "\(right)–\(min(604, right + 1))" : "\(page)"
        let name = store.page(right)?.surahName ?? ""
        let juz = store.page(right)?.juz ?? 1
        return HStack(spacing: 8) {
            Button(name) { showSurahs = true }.frame(minHeight: 44)
            Text("·").foregroundStyle(palette.uiSecondary)
            Button("Juz \(juz)") { showJuz = true }.font(MushafType.juz).frame(minHeight: 44)
            Text("·").foregroundStyle(palette.uiSecondary)
            Text(label).font(MushafType.ui.monospacedDigit())
            Spacer()
            Menu {
                ForEach(MushafTheme.allCases) { item in
                    Button(item.title) { themeRaw = item.rawValue }
                }
                Button("Colour tokens") { showTokens = true }
            } label: {
                Image(systemName: "circle.lefthalf.filled").frame(width: 44, height: 44)
            }
        }
        .font(MushafType.ui)
        .foregroundStyle(palette.uiInk)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Text("\(store.surahName(on: Int(scrub.rounded())))   \(Int(scrub.rounded()))")
                .font(MushafType.uiSmall)
                .foregroundStyle(palette.uiSecondary)
                .opacity(scrubbing ? 1 : 0)
            Slider(value: $scrub, in: 1...604, step: 1) { editing in
                scrubbing = editing
                if !editing { page = Int(scrub.rounded()) }
            }
            .tint(palette.accent)
            Canvas { context, size in
                for juz in 1...30 {
                    let start = store.juzPages[juz]
                    let x = (CGFloat(start) - 1) / 603 * size.width
                    let tick = CGRect(x: x, y: 0, width: 1, height: 8)
                    context.fill(Path(tick), with: .color(palette.uiSecondary.opacity(0.7)))
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var surahSheet: some View {
        NavigationStack {
            List(store.surahs) { surah in
                Button {
                    page = surah.page
                    showSurahs = false
                } label: {
                    HStack {
                        Text("\(surah.id)")
                            .font(MushafType.ui.monospacedDigit())
                            .foregroundStyle(palette.uiSecondary)
                            .frame(width: 32, alignment: .trailing)
                        Text(surah.name).foregroundStyle(palette.uiInk)
                        Spacer()
                        Text("\(surah.page)")
                            .font(MushafType.uiSmall.monospacedDigit())
                            .foregroundStyle(palette.uiSecondary)
                    }
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle("Surah")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var juzSheet: some View {
        NavigationStack {
            List(1...30, id: \.self) { juz in
                Button {
                    page = store.juzPages[juz]
                    showJuz = false
                } label: {
                    HStack {
                        Text("Juz \(juz)").foregroundStyle(palette.uiInk)
                        Spacer()
                        Text("\(store.juzPages[juz])")
                            .font(MushafType.uiSmall.monospacedDigit())
                            .foregroundStyle(palette.uiSecondary)
                    }
                    .frame(minHeight: 44)
                }
            }
            .navigationTitle("Juz")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private static var initialPage: Int {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-page"), index + 1 < args.count, let number = Int(args[index + 1]) {
            return min(604, max(1, number))
        }
        let saved = UserDefaults.standard.integer(forKey: "mushaf.lastPage")
        return saved == 0 ? 1 : min(604, saved)
    }

    private static var themeOverride: MushafTheme? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-theme"), index + 1 < args.count else { return nil }
        return MushafTheme(rawValue: args[index + 1])
    }

    private static var locked: Bool {
        ProcessInfo.processInfo.arguments.contains("-page")
    }
}
