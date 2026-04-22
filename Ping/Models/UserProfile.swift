import Foundation

struct UserProfile: Codable, Sendable {
    var careerRole: String?
    var careerCompany: String?
    var careerIndustry: String?
    var careerSeniority: String?
    var interests: [String]
    var city: String?
    var hometown: String?
    var school: String?
    var aboutMe: String?

    enum CodingKeys: String, CodingKey {
        case careerRole      = "career_role"
        case careerCompany   = "career_company"
        case careerIndustry  = "career_industry"
        case careerSeniority = "career_seniority"
        case interests
        case city
        case hometown
        case school
        case aboutMe         = "about_me"
    }

    init(
        careerRole: String? = nil,
        careerCompany: String? = nil,
        careerIndustry: String? = nil,
        careerSeniority: String? = nil,
        interests: [String] = [],
        city: String? = nil,
        hometown: String? = nil,
        school: String? = nil,
        aboutMe: String? = nil
    ) {
        self.careerRole = careerRole
        self.careerCompany = careerCompany
        self.careerIndustry = careerIndustry
        self.careerSeniority = careerSeniority
        self.interests = interests
        self.city = city
        self.hometown = hometown
        self.school = school
        self.aboutMe = aboutMe
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        careerRole      = try c.decodeIfPresent(String.self, forKey: .careerRole)
        careerCompany   = try c.decodeIfPresent(String.self, forKey: .careerCompany)
        careerIndustry  = try c.decodeIfPresent(String.self, forKey: .careerIndustry)
        careerSeniority = try c.decodeIfPresent(String.self, forKey: .careerSeniority)
        interests       = try c.decodeIfPresent([String].self, forKey: .interests) ?? []
        city            = try c.decodeIfPresent(String.self, forKey: .city)
        hometown        = try c.decodeIfPresent(String.self, forKey: .hometown)
        school          = try c.decodeIfPresent(String.self, forKey: .school)
        aboutMe         = try c.decodeIfPresent(String.self, forKey: .aboutMe)
    }

    /// True if the user has filled in at least one field.
    var hasContent: Bool {
        [careerRole, careerCompany, careerIndustry, careerSeniority, city, hometown, school, aboutMe]
            .compactMap { $0 }.contains { !$0.isEmpty }
        || !interests.isEmpty
    }
}
