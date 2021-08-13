import Foundation

open class Resources: NSObject {
    
    var resources = [String: Resource]()

    func add(_ resource: Resource) {
        self.resources[resource.href] = resource
    }

    func findByMediaType(_ mediaType: MediaType) -> Resource? {
        for resource in resources.values {
            if resource.mediaType != nil && resource.mediaType == mediaType {
                return resource
            }
        }
        return nil
    }

    func findByExtension(_ ext: String) -> Resource? {
        for resource in resources.values {
            if resource.mediaType != nil && resource.mediaType.defaultExtension == ext {
                return resource
            }
        }
        return nil
    }

    func findByProperty(_ properties: String) -> Resource? {
        for resource in resources.values {
            if resource.properties == properties {
                return resource
            }
        }
        return nil
    }

    func findByHref(_ href: String) -> Resource? {
        guard !href.isEmpty else { return nil }

        let cleanHref = href.replacingOccurrences(of: "../", with: "")
        return resources[cleanHref]
    }

    func findById(_ id: String?) -> Resource? {
        guard let id = id else { return nil }

        for resource in resources.values {
            if let resourceID = resource.id, resourceID == id {
                return resource
            }
        }
        return nil
    }

    func containsByHref(_ href: String) -> Bool {
        guard !href.isEmpty else { return false }

        return resources.keys.contains(href)
    }

    func containsById(_ id: String?) -> Bool {
        guard let id = id else { return false }

        for resource in resources.values {
            if let resourceID = resource.id, resourceID == id {
                return true
            }
        }
        return false
    }
}
