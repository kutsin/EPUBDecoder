import Foundation

struct BaseSpine {
    var linear: Bool
    var resource: Resource

    init(resource: Resource, linear: Bool = true) {
        self.resource = resource
        self.linear = linear
    }
}

class Spine: NSObject {
    var pageProgressionDirection: String?
    var spineReferences = [BaseSpine]()

    var isRtl: Bool {
        if let pageProgressionDirection = pageProgressionDirection , pageProgressionDirection == "rtl" {
            return true
        }
        return false
    }

    func nextChapter(_ href: String) -> Resource? {
        var found = false;

        for item in spineReferences {
            if(found){
                return item.resource
            }

            if(item.resource.href == href) {
                found = true
            }
        }
        return nil
    }
}
