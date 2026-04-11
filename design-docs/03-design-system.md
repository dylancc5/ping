# Ping — Design System

## Design Philosophy

Ping feels like a warm, personal notebook — not a CRM, not a social network, not a productivity app. The design should evoke the feeling of finding an old note from a friend: familiar, human, unhurried.

**Three design principles:**
1. **Warmth over utility** — Every screen should feel inviting, not transactional. Favor organic shapes, warm neutrals, and unhurried spacing.
2. **Focus over features** — One primary action per screen. The AI draft card is the most important thing on the contact detail. The "+" button is the most important thing in the network list. Don't compete with yourself.
3. **Confidence without noise** — No badges everywhere, no gamification, no streaks. Ping is your quiet assistant, not an attention merchant.

---

## Color Palette

### Core Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `background` | `#FAFAF7` | App background — warm white, not pure white |
| `surface` | `#FFFFFF` | Card backgrounds, sheets |
| `surface-2` | `#F5F4F0` | Input backgrounds, grouped sections, secondary surfaces |
| `surface-3` | `#EEECE8` | Dividers, subtle separators |

### Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `text-primary` | `#1A1A1A` | Headings, primary content |
| `text-secondary` | `#6B6B6B` | Supporting text, subtitles |
| `text-muted` | `#9B9B9B` | Timestamps, metadata, placeholders |
| `text-subtle` | `#C5C5C5` | Tertiary, disabled states |

### Accent Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `accent` | `#E8845A` | Primary CTAs, active tab indicator, nudge badges |
| `accent-light` | `#F5D0BC` | Accent fills, tinted backgrounds |
| `accent-2` | `#D4A96A` | Secondary accents, warmth indicators |
| `accent-2-light` | `#F0DFC0` | Warm tinted fills |

### Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `success` | `#6DBF8F` | Sent indicator, confirmed actions |
| `success-light` | `#D4F0E2` | Success background |
| `destructive` | `#E05252` | Delete, remove actions |
| `destructive-light` | `#FADADD` | Destructive background |

### Warmth Spectrum

Used for warmth indicator dots on contacts. Color communicates relationship health at a glance.

| State | Hex | Label | Threshold |
|-------|-----|-------|-----------|
| Hot | `#E8845A` | Contacted < 2 weeks | warmth_score > 0.8 |
| Warm | `#D4A96A` | Contacted 2-6 weeks | warmth_score 0.5-0.8 |
| Cool | `#B8C5D6` | Contacted 6-12 weeks | warmth_score 0.2-0.5 |
| Cold | `#D4D4D4` | Contacted 12+ weeks | warmth_score < 0.2 |

### Swift Color Extensions

```swift
// Color+Ping.swift
extension Color {
    static let pingBackground   = Color(hex: "FAFAF7")
    static let pingSurface      = Color(hex: "FFFFFF")
    static let pingSurface2     = Color(hex: "F5F4F0")
    static let pingSurface3     = Color(hex: "EEECE8")

    static let pingTextPrimary  = Color(hex: "1A1A1A")
    static let pingTextSecondary = Color(hex: "6B6B6B")
    static let pingTextMuted    = Color(hex: "9B9B9B")

    static let pingAccent       = Color(hex: "E8845A")
    static let pingAccentLight  = Color(hex: "F5D0BC")
    static let pingAccent2      = Color(hex: "D4A96A")

    static let pingSuccess      = Color(hex: "6DBF8F")
    static let pingDestructive  = Color(hex: "E05252")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

---

## Typography

**Typeface:** SF Pro exclusively — no custom typefaces. SF Pro is optimized for iOS legibility at every size and adapts to Dynamic Type automatically.

### Type Scale

| Style | Font | Weight | Size | Usage |
|-------|------|--------|------|-------|
| `largeTitle` | SF Pro Display | Bold | 34pt | Screen titles (rare) |
| `title` | SF Pro Display | Semibold | 28pt | Tab header, modal titles |
| `title2` | SF Pro Display | Semibold | 22pt | Section headings |
| `headline` | SF Pro Text | Semibold | 17pt | Contact names in list, card headings |
| `body` | SF Pro Text | Regular | 17pt | Body copy, notes |
| `callout` | SF Pro Text | Regular | 16pt | Supporting descriptions |
| `subheadline` | SF Pro Text | Regular | 15pt | Secondary labels |
| `footnote` | SF Pro Text | Regular | 13pt | Timestamps, metadata |
| `caption` | SF Pro Text | Regular | 12pt | Labels, tags, badges |

All text styles use Dynamic Type via SwiftUI `.font(.headline)` etc. — never hardcoded sizes.

---

## Spacing & Layout

### Spacing Scale

```swift
// Spacing.swift
struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let section: CGFloat = 40
}
```

### Layout Principles
- **Horizontal padding:** 20pt (`Spacing.xl`) for full-width content
- **Card internal padding:** 16pt (`Spacing.lg`)
- **List row spacing:** 12pt between rows
- **Section spacing:** 40pt between distinct content sections
- **Safe areas:** Always respect iOS safe areas — bottom content never hidden by tab bar or home indicator

---

## Corner Radius

| Element | Radius |
|---------|--------|
| Cards | 14pt |
| Buttons (full-width) | 14pt |
| Buttons (small/pill) | 10pt |
| Input fields | 10pt |
| Modals / sheets | 20pt top corners |
| Warmth dots | Circle (radius = half size) |
| Tags/badges | 6pt |

---

## Shadows

Ping uses very subtle shadows — barely perceptible, just enough to lift cards off the background without looking like a Material Design clone.

```swift
// Shadow tokens
extension View {
    func pingCardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
    func pingSoftShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}
```

---

## Iconography

Use **SF Symbols** exclusively. They adapt to Dynamic Type, support rendering modes, and feel native.

### Icon Vocabulary

| Context | SF Symbol | Style |
|---------|-----------|-------|
| Ping tab | `bell.fill` | Hierarchical |
| Network tab | `person.2.fill` | Hierarchical |
| Search tab | `magnifyingglass` | Monochrome |
| Profile tab | `person.crop.circle.fill` | Hierarchical |
| Add contact | `plus` (in circle) | Monochrome |
| Voice capture | `mic.fill` | Hierarchical |
| Send message | `paperplane.fill` | Hierarchical |
| Regenerate draft | `arrow.clockwise` | Monochrome |
| Snooze nudge | `moon.zzz.fill` | Hierarchical |
| LinkedIn | Custom asset (SVG) | — |
| Google | Custom asset (SVG) | — |
| Copy | `doc.on.doc` | Monochrome |
| Edit | `pencil` | Monochrome |
| Delete | `trash` | Monochrome |
| Calendar | `calendar` | Hierarchical |
| Goal | `target` | Hierarchical |
| Tag | `tag.fill` | Hierarchical |

---

## Components

### WarmthDot

Small colored circle indicating relationship health.

```swift
struct WarmthDot: View {
    let score: Double
    var size: CGFloat = 10

    var color: Color {
        switch score {
        case 0.8...: return .pingAccent         // Hot
        case 0.5..<0.8: return .pingAccent2     // Warm
        case 0.2..<0.5: return Color(hex: "B8C5D6") // Cool
        default: return Color(hex: "D4D4D4")    // Cold
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}
```

### ContactRowView

Standard contact list row.

```
┌────────────────────────────────────────┐
│ [Avatar]  Name Surname          ●      │
│           Company · Title              │
│           3 weeks ago                  │
└────────────────────────────────────────┘
```

- Avatar: initials in `accent-light` circle, 40pt
- Name: `.headline` weight
- Company/title: `.subheadline`, `text-secondary`
- Timestamp: `.footnote`, `text-muted`
- Warmth dot: trailing, 10pt

### NudgeCardView

Used in the Ping tab feed.

```
┌────────────────────────────────────────┐
│ [Avatar]  Name Surname          🔔     │
│           Met at SCET fair · 9 days ago│
│ ─────────────────────────────────────  │
│ "Hey Marcus, it was great meeting..."  │
│                    [Draft message →]   │
└────────────────────────────────────────┘
```

- Nudge bell icon in `accent` color
- Draft preview: `.callout`, italic, `text-secondary`
- CTA button: `accent` text, `.subheadline` semibold

### QuickCaptureSheet

Bottom sheet modal (`.presentationDetents([.large])`).

```
┌────────────────────────────────────────┐
│        [─ drag handle ─]               │
│                                        │
│  Log a contact                         │
│                                        │
│  Name *                                │
│  ┌──────────────────────────────────┐  │
│  │ Marcus Chen                      │  │
│  └──────────────────────────────────┘  │
│                                        │
│  Where did you meet? *                 │
│  ┌──────────────────────────────────┐  │
│  │ SCET career fair                 │  │
│  └──────────────────────────────────┘  │
│                                        │
│  Notes                                 │
│  ┌──────────────────────────────────┐  │
│  │ PM at Google, interested in ML   │  │
│  │ infra, wants to grab coffee      │  │
│  └──────────────────────────────────┘  │
│                                        │
│         [  🎤  ]  hold to speak        │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │         Save Contact             │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

### MessageDraftView

Full-screen editing experience.

```
┌────────────────────────────────────────┐
│ ← Back          Draft Message          │
├────────────────────────────────────────┤
│ ┌──────────────────────────────────┐   │
│ │ Marcus Chen — PM at Google       │   │
│ │ Met at SCET fair · 9 days ago    │   │
│ └──────────────────────────────────┘   │
│                                        │
│ ┌──────────────────────────────────┐   │
│ │ Hey Marcus! It was really great  │   │
│ │ meeting you at the SCET career   │   │
│ │ fair. I'd love to stay in touch  │   │
│ │ — would you be open to a quick   │   │
│ │ coffee chat sometime?            │   │
│ │                                  │   │
│ └──────────────────────────────────┘   │
│           ↺ Try another tone           │
│                                        │
│ Send via:                              │
│ [Messages] [Gmail] [LinkedIn] [Copy]   │
└────────────────────────────────────────┘
```

### PingButton

Primary CTA button.

```swift
struct PingButton: View {
    let title: String
    let action: () -> Void
    var style: ButtonStyle = .primary

    enum ButtonStyle { case primary, secondary, destructive }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(backgroundColor)
                .cornerRadius(14)
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .pingAccent
        case .secondary: return .pingSurface2
        case .destructive: return .pingDestructive
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .pingTextPrimary
        case .destructive: return .white
        }
    }
}
```

---

## Motion & Animation

**Principle:** Subtle, purposeful, fast. Ping is a tool, not a toy. Animations should make interactions feel polished and responsive, never decorative.

| Interaction | Animation | Duration |
|-------------|-----------|----------|
| Sheet presentation | System default (spring) | — |
| Card tap (expand) | `.spring(response: 0.35, dampingFraction: 0.7)` | — |
| FAB tap | Scale 0.95 → 1.0 spring | 200ms |
| Nudge card dismiss | Slide right + fade | 300ms |
| List row appear | Stagger fade-in | 50ms per item |
| Tab switch | System default | — |
| Loading skeleton | Shimmer (loop) | 1.2s cycle |

**Never:**
- Bounce animations on content (not a game)
- Long transitions (> 400ms)
- Animations that block user interaction

---

## Empty States

Every list and feed needs a warm empty state — no blank screens.

| Screen | Empty state copy | Illustration |
|--------|-----------------|--------------|
| Ping tab (no nudges) | "All caught up — your network is in good shape" | Soft checkmark or small plant growing |
| Network tab (no contacts) | "Your network starts here. Log your first contact." | Single contact bubble |
| Search (no results) | "No one matches that — try different words or add a new contact" | Magnifying glass |
| Goals (no goals) | "Add a goal to surface relevant people from your network" | Target with arrow |

---

## Dark Mode

v1 ships **light mode only**. Dark mode is v2. Using semantic colors (`Color.pingBackground` etc.) now means dark mode adaptation is a small lift when we get there — just add dark variants to the color extensions.
