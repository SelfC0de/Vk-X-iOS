import SwiftUI
import UIKit

// MARK: - TKSwitch styles enum
enum TKSwitchStyle {
    case liquid    // TKLiquidSwitch  — анимированный пузырь
    case simple    // TKSimpleSwitch  — скользящий кружок
    case exchange  // TKExchangeSwitch — иконки меняются местами
}

// MARK: - SwiftUI wrapper для TKBaseSwitch
struct TKSwitch: UIViewRepresentable {
    @Binding var isOn: Bool
    var style: TKSwitchStyle = .liquid
    var onColor: UIColor   = UIColor(red: 0.2, green: 0.7, blue: 0.95, alpha: 1)  // cyberBlue
    var offColor: UIColor  = UIColor(white: 0.25, alpha: 1)

    func makeUIView(context: Context) -> TKBaseSwitch {
        let sw: TKBaseSwitch
        switch style {
        case .liquid:
            let liq = TKLiquidSwitch(frame: CGRect(x: 0, y: 0, width: 60, height: 32))
            liq.onColor  = onColor
            liq.offColor = offColor
            sw = liq
        case .simple:
            let sim = TKSimpleSwitch(frame: CGRect(x: 0, y: 0, width: 60, height: 32))
            sim.onColor  = onColor
            sim.offColor = offColor
            sw = sim
        case .exchange:
            let exch = TKExchangeSwitch(frame: CGRect(x: 0, y: 0, width: 60, height: 32))
            exch.onColor  = onColor
            exch.offColor = offColor
            sw = exch
        }
        sw.isOn = isOn
        sw.valueChange = { _ in }
        sw.addTarget(context.coordinator, action: #selector(Coordinator.toggled(_:)), for: .valueChanged)
        return sw
    }

    func updateUIView(_ uiView: TKBaseSwitch, context: Context) {
        if uiView.isOn != isOn {
            uiView.setOn(isOn, animate: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject {
        var parent: TKSwitch
        init(_ parent: TKSwitch) { self.parent = parent }

        @objc func toggled(_ sender: TKBaseSwitch) {
            parent.isOn = sender.isOn
        }
    }
}

// MARK: - Размер UIViewRepresentable
extension TKSwitch {
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: TKBaseSwitch, context: Context) -> CGSize? {
        CGSize(width: 60, height: 32)
    }
}
