import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The block screen from design/screens/Block.dc.html: the app's own sealed ember orb (pre-rendered,
/// see ShieldOrbArt), "Sealed" and "Tap a tag to open this app.", dark only. iOS shows a button whatever
/// the design says, so it is an ember Close. The system font is the only one a shield can use.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        SealedShield.configuration
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        SealedShield.configuration
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        SealedShield.configuration
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        SealedShield.configuration
    }
}

enum SealedShield {
    static var configuration: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: color("bg"),
            icon: icon,
            title: ShieldConfiguration.Label(text: "Sealed", color: color("ink")),
            subtitle: ShieldConfiguration.Label(text: "Tap a tag to open this app.", color: color("ink-secondary")),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: color("on-ember")),
            primaryButtonBackgroundColor: color("ember"),
            secondaryButtonLabel: nil
        )
    }

    /// The app's glass orb, pre-rendered (see ShieldOrbArt). The drawn fallback only shows if the asset is missing.
    private static var icon: UIImage {
        UIImage(named: "SealedOrb", in: .main, compatibleWith: dark)?.withRenderingMode(.alwaysOriginal) ?? fallbackOrb
    }

    /// A flat ember orb: a ring, a faint halo, the solid orb and its highlight.
    private static var fallbackOrb: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
            let cg = context.cgContext
            let ember = color("ember")
            cg.setStrokeColor(ember.cgColor)
            cg.setLineWidth(3)
            cg.strokeEllipse(in: CGRect(x: 6, y: 6, width: 108, height: 108))
            cg.setFillColor(ember.withAlphaComponent(0.18).cgColor)
            cg.fillEllipse(in: CGRect(x: 20, y: 20, width: 80, height: 80))
            cg.setFillColor(ember.cgColor)
            cg.fillEllipse(in: CGRect(x: 30, y: 30, width: 60, height: 60))
            cg.setFillColor(color("ink").withAlphaComponent(0.85).cgColor)
            cg.fillEllipse(in: CGRect(x: 42, y: 43, width: 18, height: 12))
        }
    }

    private static let dark = UITraitCollection(userInterfaceStyle: .dark)

    /// A design-system colour from this extension's asset catalog, always in its dark appearance.
    private static func color(_ name: String) -> UIColor {
        (UIColor(named: name, in: .main, compatibleWith: dark) ?? .gray).resolvedColor(with: dark)
    }
}
