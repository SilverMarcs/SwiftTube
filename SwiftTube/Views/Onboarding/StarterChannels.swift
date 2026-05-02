import Foundation

struct StarterChannel: Identifiable, Hashable {
    let name: String
    let handle: String
    let category: String
    var id: String { handle }
}

enum StarterChannelCategory: String, CaseIterable {
    case tech = "Tech"
    case science = "Science & Education"
    case programming = "Programming"
    case cooking = "Cooking"
    case lifestyle = "Lifestyle"

    var icon: String {
        switch self {
        case .tech: "cpu"
        case .science: "atom"
        case .programming: "chevron.left.forwardslash.chevron.right"
        case .cooking: "fork.knife"
        case .lifestyle: "person.crop.square"
        }
    }

    var channels: [StarterChannel] {
        Self.all.filter { $0.category == rawValue }
    }

    static let all: [StarterChannel] = [
        // Tech
        StarterChannel(name: "Marques Brownlee", handle: "@mkbhd", category: "Tech"),
        StarterChannel(name: "Linus Tech Tips", handle: "@LinusTechTips", category: "Tech"),
        StarterChannel(name: "Mrwhosetheboss", handle: "@Mrwhosetheboss", category: "Tech"),
        StarterChannel(name: "The Verge", handle: "@TheVerge", category: "Tech"),

        // Science & Education
        StarterChannel(name: "Veritasium", handle: "@veritasium", category: "Science & Education"),
        StarterChannel(name: "Kurzgesagt", handle: "@kurzgesagt", category: "Science & Education"),
        StarterChannel(name: "CGP Grey", handle: "@CGPGrey", category: "Science & Education"),
        StarterChannel(name: "Vsauce", handle: "@Vsauce", category: "Science & Education"),

        // Programming
        StarterChannel(name: "Fireship", handle: "@Fireship", category: "Programming"),
        StarterChannel(name: "ThePrimeagen", handle: "@ThePrimeagen", category: "Programming"),
        StarterChannel(name: "Theo - t3․gg", handle: "@t3dotgg", category: "Programming"),
        StarterChannel(name: "Hacking with Swift", handle: "@twostraws", category: "Programming"),

        // Cooking
        StarterChannel(name: "Binging with Babish", handle: "@bingingwithbabish", category: "Cooking"),
        StarterChannel(name: "Joshua Weissman", handle: "@JoshuaWeissman", category: "Cooking"),
        StarterChannel(name: "Bon Appétit", handle: "@bonappetit", category: "Cooking"),
        StarterChannel(name: "Adam Ragusea", handle: "@aragusea", category: "Cooking"),

        // Lifestyle
        StarterChannel(name: "Casey Neistat", handle: "@CaseyNeistat", category: "Lifestyle"),
        StarterChannel(name: "Peter McKinnon", handle: "@PeterMcKinnon", category: "Lifestyle"),
        StarterChannel(name: "Mark Rober", handle: "@MarkRober", category: "Lifestyle"),
        StarterChannel(name: "Yes Theory", handle: "@yestheory", category: "Lifestyle"),
    ]
}
