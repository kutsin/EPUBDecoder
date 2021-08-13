import Foundation

struct Author {
    var name: String
    var role: String
    var fileAs: String

    init(name: String, role: String, fileAs: String) {
        self.name = name
        self.role = role
        self.fileAs = fileAs
    }
}

struct Identifier {
    var id: String?
    var scheme: String?
    var value: String?

    init(id: String?, scheme: String?, value: String?) {
        self.id = id
        self.scheme = scheme
        self.value = value
    }
}

struct EventDate {
    var date: String
    var event: String?

    init(date: String, event: String?) {
        self.date = date
        self.event = event
    }
}

struct Meta {
    var name: String?
    var content: String?
    var id: String?
    var property: String?
    var value: String?
    var refines: String?

    init(name: String? = nil, content: String? = nil, id: String? = nil, property: String? = nil,
         value: String? = nil, refines: String? = nil) {
        self.name = name
        self.content = content
        self.id = id
        self.property = property
        self.value = value
        self.property = property
        self.value = value
        self.refines = refines
    }
}

class Metadata {
    var creators = [Author]()
    var contributors = [Author]()
    var dates = [EventDate]()
    var language = "en-US"
    var titles = [String]()
    var identifiers = [Identifier]()
    var subjects = [String]()
    var descriptions = [String]()
    var publishers = [String]()
    var format = MediaType.epub.name
    var rights = [String]()
    var metaAttributes = [Meta]()

    func find(identifierById id: String) -> Identifier? {
        return identifiers.filter({ $0.id == id }).first
    }

    func find(byName name: String) -> Meta? {
        return metaAttributes.filter({ $0.name == name }).first
    }

    func find(byProperty property: String, refinedBy: String? = nil) -> Meta? {
        return metaAttributes.filter {
            if let refinedBy = refinedBy {
                return $0.property == property && $0.refines == refinedBy
            }
            return $0.property == property
        }.first
    }
}
