/// A pure, platform-independent classification of clicks in the Hop app.
/// AppKit's transient NSPopover handles clicks in other applications.
public enum PopoverClickPolicy {
    public static func shouldDismiss(
        isPanelWindow: Bool, isStatusItemWindow: Bool,
        canBecomeKey: Bool, isTitled: Bool
    ) -> Bool {
        !isPanelWindow && !isStatusItemWindow && canBecomeKey && isTitled
    }
}
