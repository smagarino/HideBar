import CoreGraphics

// MARK: - Menu bar geometry

public enum MenuBarGeometry {
    /// Shortest menu bar height to assume, when a screen reports none.
    public static let minimumHeight: CGFloat = 25

    /// The y below which a point is no longer in the menu bar.
    /// Screen coordinates put y = 0 at the bottom, so the menu bar is at the top.
    public static func bottomEdge(screenMaxY: CGFloat, visibleMaxY: CGFloat) -> CGFloat {
        screenMaxY - max(screenMaxY - visibleMaxY, minimumHeight)
    }

    public static func contains(point: CGPoint, screenMaxY: CGFloat, visibleMaxY: CGFloat) -> Bool {
        point.y >= bottomEdge(screenMaxY: screenMaxY, visibleMaxY: visibleMaxY)
    }
}

// MARK: - Clicks on the chevron

public enum ClickAction: Equatable, Sendable {
    case showMenu
    case toggleHiddenSection
    case toggleAlwaysHiddenSection
}

public enum ClickRouter {
    /// One button serves every click, so the type of click decides the action.
    public static func action(isRightClick: Bool,
                              optionHeld: Bool,
                              hasAlwaysHiddenSection: Bool) -> ClickAction {
        if isRightClick { return .showMenu }
        // Option reaches the always-hidden section, but only when one exists.
        if optionHeld && hasAlwaysHiddenSection { return .toggleAlwaysHiddenSection }
        return .toggleHiddenSection
    }
}

// MARK: - Reveal transitions

public enum RevealCommand: Equatable, Sendable {
    case expand
    case collapse
    case showAll
    case toggleHiddenSection
    case toggleAlwaysHiddenSection
}

public enum RevealMachine {
    public static func next(from current: Reveal, command: RevealCommand) -> Reveal {
        switch command {
        case .expand:
            // Never step back from showing everything.
            return current == .none ? .hidden : current
        case .collapse:
            return .none
        case .showAll:
            return .all
        case .toggleHiddenSection:
            return current == .none ? .hidden : .none
        case .toggleAlwaysHiddenSection:
            return current == .all ? .none : .all
        }
    }
}

// MARK: - The self-hide guard

public enum CollapseGuard {
    /// Collapsing while the chevron sits left of the separator would push the
    /// chevron off-screen too, leaving no way to bring it back. The saved
    /// positions would then restore that broken layout on every launch.
    public static func mayCollapse(toggleMinX: CGFloat?, separatorMinX: CGFloat?) -> Bool {
        guard let toggleMinX, let separatorMinX else { return true }  // unknown: do not block
        return toggleMinX > separatorMinX
    }
}

// MARK: - Hover

public enum HoverDecision: Equatable, Sendable {
    case doNothing
    case reveal
    case collapse
}

public enum HoverRules {
    /// How far outside the chevron still counts as hovering it.
    public static let margin: CGFloat = 6

    public static func decide(pointer: CGPoint,
                              chevron: CGRect?,
                              screenMaxY: CGFloat,
                              visibleMaxY: CGFloat,
                              reveal: Reveal,
                              revealedByHover: Bool) -> HoverDecision {
        let inMenuBar = MenuBarGeometry.contains(
            point: pointer, screenMaxY: screenMaxY, visibleMaxY: visibleMaxY)

        guard inMenuBar else {
            // Only a reveal caused by hovering hides again on its own. One the
            // user clicked for must survive the pointer moving away.
            return revealedByHover ? .collapse : .doNothing
        }
        guard reveal == .none, let chevron else { return .doNothing }
        return chevron.insetBy(dx: -margin, dy: 0).contains(pointer) ? .reveal : .doNothing
    }
}

// MARK: - Clicks elsewhere

public enum OutsideClickRules {
    /// A click inside the menu bar must not collapse the sections. Revealing an
    /// icon and then clicking it would otherwise pull it away mid-click.
    public static func shouldCollapse(pointer: CGPoint,
                                      screenMaxY: CGFloat,
                                      visibleMaxY: CGFloat) -> Bool {
        !MenuBarGeometry.contains(point: pointer, screenMaxY: screenMaxY, visibleMaxY: visibleMaxY)
    }
}
