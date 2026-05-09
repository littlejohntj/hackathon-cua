import ReplayKit
import SwiftUI
import UIKit

struct BroadcastStartButton: View {
    let preferredExtension: String
    let isDisabled: Bool
    let onPress: () -> Void

    private let width: CGFloat = 154
    private let height: CGFloat = 44

    var body: some View {
        ZStack {
            Label("Start guide", systemImage: "play.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: width, height: height)
                .background(isDisabled ? Color.gray : Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            if !isDisabled {
                BroadcastPickerView(preferredExtension: preferredExtension, onTouchDown: onPress)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: width, height: height)
        .accessibilityLabel("Start guide")
        .accessibilityHint("Opens the iOS screen broadcast picker for Northstar")
    }
}

struct BroadcastPickerView: UIViewRepresentable {
    let preferredExtension: String
    let onTouchDown: () -> Void

    func makeUIView(context: Context) -> NorthstarBroadcastPickerUIView {
        let picker = NorthstarBroadcastPickerUIView(frame: .zero)
        picker.preferredExtension = preferredExtension
        picker.showsMicrophoneButton = false
        picker.backgroundColor = .clear
        picker.onTouchDown = onTouchDown
        return picker
    }

    func updateUIView(_ uiView: NorthstarBroadcastPickerUIView, context: Context) {
        uiView.preferredExtension = preferredExtension
        uiView.onTouchDown = onTouchDown
        uiView.setNeedsLayout()
    }
}

final class NorthstarBroadcastPickerUIView: RPSystemBroadcastPickerView {
    var onTouchDown: (() -> Void)?
    private weak var hookedButton: UIButton?
    private var didLogMissingButton = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let button = firstSubview(of: UIButton.self) else {
            if !didLogMissingButton {
                didLogMissingButton = true
                AppLog.error("ReplayKit picker internal button missing bounds=\(bounds)")
            }
            return
        }

        button.frame = bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        button.backgroundColor = .clear
        button.tintColor = .clear
        button.imageView?.tintColor = .clear
        button.adjustsImageWhenHighlighted = false

        guard hookedButton !== button else { return }
        hookedButton?.removeTarget(self, action: #selector(pickerTouched), for: .touchDown)
        button.addTarget(self, action: #selector(pickerTouched), for: .touchDown)
        hookedButton = button
        AppLog.info("ReplayKit picker button hooked bounds=\(bounds)")
    }

    @objc private func pickerTouched() {
        AppLog.info("ReplayKit picker touchDown")
        onTouchDown?()
    }
}

private extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let view = self as? T { return view }
        for subview in subviews {
            if let found = subview.firstSubview(of: type) {
                return found
            }
        }
        return nil
    }
}
