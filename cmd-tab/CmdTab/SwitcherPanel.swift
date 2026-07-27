import AppKit

final class SwitcherPanel {
    var onSelect: ((Int) -> Void)?
    var onCommit: ((Int) -> Void)?

    private let panel: NSPanel
    private let stack = NSStackView()
    private var itemViews: [SwitcherItemView] = []
    private var displayedIndexes: [Int] = []
    private var applications: [NSRunningApplication] = []

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 32
        effect.layer?.masksToBounds = true

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        effect.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
        ])
        panel.contentView = effect
    }

    func show(applications: [NSRunningApplication], selectedIndex: Int) {
        self.applications = applications
        rebuild(selectedIndex: selectedIndex)
        panel.orderFrontRegardless()
    }

    func updateSelection(_ selectedIndex: Int) {
        if !displayedIndexes.contains(selectedIndex) {
            rebuild(selectedIndex: selectedIndex)
            return
        }
        for (itemView, index) in zip(itemViews, displayedIndexes) {
            itemView.isSelected = index == selectedIndex
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func rebuild(selectedIndex: Int) {
        itemViews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        itemViews.removeAll()

        let screen = NSScreen.main ?? NSScreen.screens.first
        let availableWidth = (screen?.visibleFrame.width ?? 1200) * 0.85
        let maxCount = max(2, Int((availableWidth - 16) / 126))
        let count = min(maxCount, applications.count)
        var start = max(0, selectedIndex - count / 2)
        start = min(start, applications.count - count)
        displayedIndexes = Array(start..<(start + count))

        for index in displayedIndexes {
            let item = SwitcherItemView(application: applications[index], index: index)
            item.isSelected = index == selectedIndex
            item.onSelect = onSelect
            item.onCommit = onCommit
            itemViews.append(item)
            stack.addArrangedSubview(item)
        }

        let width = CGFloat(count * 122 + max(0, count - 1) * 4 + 16)
        let size = NSSize(width: width, height: 150)
        panel.setContentSize(size)
        if let screen {
            panel.setFrameOrigin(NSPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2
            ))
        }
    }
}

private final class SwitcherItemView: NSView {
    var onSelect: ((Int) -> Void)?
    var onCommit: ((Int) -> Void)?
    var isSelected = false { didSet { updateAppearance() } }

    private let index: Int
    private let background = NSView()

    init(application: NSRunningApplication, index: Int) {
        self.index = index
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        background.wantsLayer = true
        background.layer?.cornerRadius = 28
        addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView(image: application.icon ?? NSImage())
        icon.imageScaling = .scaleProportionallyUpOrDown
        background.addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: application.localizedName ?? "Application")
        label.alignment = .center
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 122),
            heightAnchor.constraint(equalToConstant: 134),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.centerXAnchor.constraint(equalTo: centerXAnchor),
            background.widthAnchor.constraint(equalToConstant: 116),
            background.heightAnchor.constraint(equalToConstant: 116),
            icon.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 104),
            icon.heightAnchor.constraint(equalToConstant: 104),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            label.topAnchor.constraint(equalTo: background.bottomAnchor, constant: 7)
        ])
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self
        ))
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        onSelect?(index)
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?(index)
    }

    override func mouseUp(with event: NSEvent) {
        onCommit?(index)
    }

    private func updateAppearance() {
        background.layer?.backgroundColor = isSelected
            ? NSColor.white.withAlphaComponent(0.22).cgColor
            : NSColor.clear.cgColor
        background.layer?.borderWidth = 0
    }
}
