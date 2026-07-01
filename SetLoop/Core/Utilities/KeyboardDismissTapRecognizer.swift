import SwiftUI
import UIKit

struct KeyboardDismissTapRecognizer: UIViewRepresentable {
    let onTapOutsideInput: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapOutsideInput: onTapOutsideInput)
    }

    func makeUIView(context: Context) -> WindowObserverView {
        let view = WindowObserverView()
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateUIView(_ uiView: WindowObserverView, context: Context) {
        context.coordinator.onTapOutsideInput = onTapOutsideInput
    }

    static func dismantleUIView(_ uiView: WindowObserverView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class WindowObserverView: UIView {
        var onWindowChange: ((UIWindow?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onWindowChange?(window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTapOutsideInput: () -> Void
        private weak var window: UIWindow?
        private weak var recognizer: UITapGestureRecognizer?

        init(onTapOutsideInput: @escaping () -> Void) {
            self.onTapOutsideInput = onTapOutsideInput
        }

        func attach(to window: UIWindow?) {
            guard let window else {
                detach()
                return
            }

            guard self.window !== window else {
                return
            }

            detach()

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)

            self.window = window
            self.recognizer = recognizer
        }

        func detach() {
            if let recognizer, let window {
                window.removeGestureRecognizer(recognizer)
            }

            recognizer = nil
            window = nil
        }

        @objc private func handleTap() {
            onTapOutsideInput()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            isTextInput(touch.view) == false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func isTextInput(_ view: UIView?) -> Bool {
            var currentView = view

            while let candidate = currentView {
                if candidate is UITextField || candidate is UITextView {
                    return true
                }

                currentView = candidate.superview
            }

            return false
        }
    }
}
