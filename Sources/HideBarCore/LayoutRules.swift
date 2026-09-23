import CoreGraphics

/// How much of the menu bar is on show.
public enum Reveal: Sendable, CaseIterable {
    /// Only the items to the right of the first separator.
    case none
    /// Plus the ordinary hidden section.
    case hidden
    /// Plus the always-hidden section.
    case all
}

/// The width each separator takes, and whether it draws its image.
public struct SeparatorLayout: Equatable, Sendable {
    public let hidden: CGFloat
    public let alwaysHidden: CGFloat
    public let showsHiddenImage: Bool
    public let showsAlwaysHiddenImage: Bool

    public init(hidden: CGFloat, alwaysHidden: CGFloat,
                showsHiddenImage: Bool, showsAlwaysHiddenImage: Bool) {
        self.hidden = hidden
        self.alwaysHidden = alwaysHidden
        self.showsHiddenImage = showsHiddenImage
        self.showsAlwaysHiddenImage = showsAlwaysHiddenImage
    }
}

/// Decides the separator widths that produce each reveal state.
///
/// A separator stretched to an enormous width pushes everything to its left off
/// the screen. Which separator is stretched decides what stays visible.
public enum LayoutRules {

    /// Wide enough to push every item on its left past the edge of the screen.
    /// AppKit clamps it to the space available.
    public static let stretchedWidth: CGFloat = 10_000

    /// The width of a separator that is not pushing anything.
    public static func restingWidth(slim: Bool) -> CGFloat { slim ? 1 : 20 }

    public static func layout(for reveal: Reveal, slim: Bool = false) -> SeparatorLayout {
        let resting = restingWidth(slim: slim)
        switch reveal {
        case .none:
            // The first separator hides both sections at once. The second must
            // stay at rest: two stretched items overflow the layout, which can
            // strand the chevron where macOS never draws it.
            return SeparatorLayout(hidden: stretchedWidth, alwaysHidden: resting,
                                   showsHiddenImage: false, showsAlwaysHiddenImage: true)
        case .hidden:
            return SeparatorLayout(hidden: resting, alwaysHidden: stretchedWidth,
                                   showsHiddenImage: true, showsAlwaysHiddenImage: false)
        case .all:
            return SeparatorLayout(hidden: resting, alwaysHidden: resting,
                                   showsHiddenImage: true, showsAlwaysHiddenImage: true)
        }
    }
}
