import CoreGraphics

// MARK: - Spacing

/// 8pt base grid. All values are multiples of 4pt or 8pt.
enum CadenceSpacing {
    /// 4pt — tight internal gaps (chip gaps, icon-to-label)
    static let xs: CGFloat = 4
    /// 8pt — row internal padding, small gaps
    static let sm: CGFloat = 8
    /// 12pt — standard row vertical padding, card internal gaps
    static let md: CGFloat = 12
    /// 16pt — screen horizontal margins, card padding, section gaps
    static let lg: CGFloat = 16
    /// 24pt — between major sections
    static let xl: CGFloat = 24
    /// 32pt — large vertical gaps, top padding on screens
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius

enum CadenceRadius {
    /// 8pt — icon tiles, chips, pills, flow/energy buttons
    static let sm: CGFloat = 8
    /// 10pt — picker rows, insight cards, day summary cards
    static let md: CGFloat = 10
    /// 12pt — settings groups, sharing cards, log entry cards
    static let lg: CGFloat = 12
    /// 14pt — primary content cards (log card, partner activity card)
    static let xl: CGFloat = 14
    /// 16pt — hero cards (Today hero, Partner hero)
    static let xxl: CGFloat = 16
    /// 9999pt — pills, tags, toggles, avatar circles, capsule shapes
    static let full: CGFloat = 9999
}
