import SwiftUI
import UIKit

struct FingerPager: UIViewControllerRepresentable {
    var index: Int
    var count: Int
    var reduceMotion: Bool
    var page: (Int) -> AnyView
    var onIndex: (Int) -> Void
    var onTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = .clear
        context.coordinator.bind(pager, parent: self)
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        context.coordinator.bind(pager, parent: self)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        private weak var pager: UIPageViewController?
        private var count = 1
        private var reduceMotion = false
        private var makePage: (Int) -> AnyView = { _ in AnyView(EmptyView()) }
        private var onIndex: (Int) -> Void = { _ in }
        private var onTap: () -> Void = {}
        private var hosts: [Int: PageHost] = [:]
        private var tap: UITapGestureRecognizer?

        func bind(_ pager: UIPageViewController, parent: FingerPager) {
            self.pager = pager
            count = parent.count
            reduceMotion = parent.reduceMotion
            makePage = parent.page
            onIndex = parent.onIndex
            onTap = parent.onTap
            for (index, host) in hosts { host.rootView = makePage(index) }
            fingersOnly(pager)
            let showing = (pager.viewControllers?.first as? PageHost)?.index
            guard showing != parent.index else { return }
            let direction: UIPageViewController.NavigationDirection = (showing ?? -1) < parent.index ? .forward : .reverse
            pager.setViewControllers([host(parent.index)], direction: direction, animated: showing != nil && !reduceMotion)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = (viewController as? PageHost)?.index, index > 0 else { return nil }
            return host(index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = (viewController as? PageHost)?.index, index + 1 < count else { return nil }
            return host(index + 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let index = (pageViewController.viewControllers?.first as? PageHost)?.index else { return }
            onIndex(index)
        }

        @objc private func tapped() { onTap() }

        private func host(_ index: Int) -> PageHost {
            if let existing = hosts[index] { return existing }
            let created = PageHost(rootView: makePage(index))
            created.index = index
            created.view.backgroundColor = .clear
            created.safeAreaRegions = []
            hosts[index] = created
            let visible = Set((pager?.viewControllers ?? []).compactMap { ($0 as? PageHost)?.index })
            hosts = hosts.filter { visible.contains($0.key) || abs($0.key - index) <= 2 }
            return hosts[index] ?? created
        }

        private func fingersOnly(_ pager: UIPageViewController) {
            pager.view.semanticContentAttribute = .forceRightToLeft
            for case let scroll as UIScrollView in pager.view.subviews {
                scroll.semanticContentAttribute = .forceRightToLeft
                scroll.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
                if tap == nil {
                    let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
                    tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
                    tap.require(toFail: scroll.panGestureRecognizer)
                    pager.view.addGestureRecognizer(tap)
                    self.tap = tap
                }
            }
        }
    }
}

final class PageHost: UIHostingController<AnyView> {
    var index = 0
}
