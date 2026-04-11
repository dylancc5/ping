import Foundation

extension Contact {
    static let previewWarm = Contact(
        id: UUID(), userId: UUID(),
        name: "Sarah Kim", company: "a16z", title: "Partner",
        howMet: "Intro from Marcus", notes: "Focused on consumer social and fintech.",
        email: "sarah@a16z.com",
        tags: ["vc", "advisor"], warmthScore: 0.6,
        lastContactedAt: Calendar.current.date(byAdding: .day, value: -21, to: .now),
        metAt: Calendar.current.date(byAdding: .month, value: -3, to: .now),
        createdAt: Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .now,
        updatedAt: .now
    )

    static let previewCool = Contact(
        id: UUID(), userId: UUID(),
        name: "Jordan Patel", company: "Linear", title: "Product Designer",
        howMet: "Twitter DM", notes: nil,
        linkedinUrl: "jordanpatel",
        tags: ["design"], warmthScore: 0.35,
        lastContactedAt: Calendar.current.date(byAdding: .day, value: -55, to: .now),
        metAt: Calendar.current.date(byAdding: .month, value: -6, to: .now),
        createdAt: Calendar.current.date(byAdding: .month, value: -6, to: .now) ?? .now,
        updatedAt: .now
    )

    static let previewSamples: [Contact] = [
        .preview,
        .previewWarm,
        .previewCool,
        .previewCold,
        Contact(
            id: UUID(), userId: UUID(),
            name: "Priya Nair", company: "Figma", title: "Design Lead",
            howMet: "Design meetup SF", notes: "Passionate about design systems.",
            linkedinUrl: "priyanair", email: "priya@figma.com",
            tags: ["design", "mentor"], warmthScore: 0.72,
            lastContactedAt: Calendar.current.date(byAdding: .day, value: -14, to: .now),
            metAt: Calendar.current.date(byAdding: .month, value: -5, to: .now),
            createdAt: Calendar.current.date(byAdding: .month, value: -5, to: .now) ?? .now,
            updatedAt: .now
        ),
        Contact(
            id: UUID(), userId: UUID(),
            name: "Tom Walsh", company: "Vercel", title: "Developer Advocate",
            howMet: "Next.js conf", notes: nil,
            linkedinUrl: "tomwalsh",
            tags: ["devrel", "eng"], warmthScore: 0.9,
            lastContactedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now),
            metAt: Calendar.current.date(byAdding: .month, value: -2, to: .now),
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: .now) ?? .now,
            updatedAt: .now
        )
    ]
}

extension Array where Element == Contact {
    static let previewSamples: [Contact] = Contact.previewSamples
}
