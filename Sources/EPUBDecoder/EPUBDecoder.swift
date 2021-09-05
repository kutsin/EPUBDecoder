import Foundation
import AEXML
import ZIPFoundation

public final class EPUBDecoder {
    public static func decode(sourceURL: URL) throws -> EPUB {
        return try _EPUBDecoder().decode(sourceURL: sourceURL)
    }
}

private final class _EPUBDecoder {

    private let book = EPUB()
    
    private var resourcesURL: URL!
    private var sourceURL: URL?

    private let fileExtension = "epub"

    func decode(sourceURL: URL) throws -> EPUB {
        self.sourceURL = sourceURL

        let fileManager = FileManager.default
        let fileName = sourceURL.lastPathComponent
        let bookURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask)[0]
            .appendingPathComponent("Temp")
            .appendingPathComponent(fileName)
        
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: bookURL.path,
                                            isDirectory: &isDirectory)
        if !exists && !isDirectory.boolValue {
            guard fileManager.fileExists(atPath: sourceURL.path),
                  sourceURL.pathExtension == fileExtension else {
                throw Error.bookNotAvailable(path: sourceURL.path)
            }
            try fileManager.unzipItem(at: sourceURL, to: bookURL)
        }

        try addSkipBackupAttributeToItemAtURL(bookURL)

        book.name = sourceURL.deletingPathExtension().lastPathComponent
        try readContainer(at: bookURL)
        try readOpf(at: bookURL)
        return self.book
    }

    private func readContainer(at bookURL: URL) throws {
        let containerPath = "META-INF/container.xml"
        let containerData = try Data(contentsOf: bookURL.appendingPathComponent(containerPath), options: .alwaysMapped)
        let xmlDoc = try AEXMLDocument(xml: containerData)
        let opfResource = Resource()
        opfResource.href = xmlDoc.root["rootfiles"]["rootfile"].attributes["full-path"]
        guard let fullPath = xmlDoc.root["rootfiles"]["rootfile"].attributes["full-path"] else {
            throw Error.fullPathEmpty
        }
        opfResource.mediaType = MediaType.by(fileName: fullPath)
        book.opfResource = opfResource
        resourcesURL = bookURL.appendingPathComponent(book.opfResource.href).deletingLastPathComponent()
    }

    private func readOpf(at bookURL: URL) throws {
        let opfURL = bookURL.appendingPathComponent(book.opfResource.href)
        var identifier: String?

        let opfData = try Data(contentsOf: opfURL, options: .alwaysMapped)
        let xmlDoc = try AEXMLDocument(xml: opfData)

        if let package = xmlDoc.children.first {
            identifier = package.attributes["unique-identifier"]

            if let version = package.attributes["version"] {
                book.version = Double(version)
            }
        }

        xmlDoc.root["manifest"]["item"].all?.forEach {
            let resource = Resource()
            resource.id = $0.attributes["id"]
            resource.properties = $0.attributes["properties"]
            resource.href = $0.attributes["href"]
            resource.fullHref = resourcesURL.appendingPathComponent(resource.href).path.removingPercentEncoding
            resource.mediaType = MediaType.by(name: $0.attributes["media-type"] ?? "", fileName: resource.href)
            resource.mediaOverlay = $0.attributes["media-overlay"]

            if (resource.mediaType != nil && resource.mediaType == .smil) {
                readSmilFile(resource)
            }

            book.resources.add(resource)
        }

        book.smils.basePath = resourcesURL.path

        book.metadata = readMetadata(xmlDoc.root["metadata"].children)

        if let identifier = identifier, let uniqueIdentifier = book.metadata.find(identifierById: identifier) {
            book.uniqueIdentifier = uniqueIdentifier.value
        }

        let coverImageId = book.metadata.find(byName: "cover")?.content
        if let coverImageId = coverImageId, let coverResource = book.resources.findById(coverImageId) {
            book.coverImage = coverResource
        } else if let coverResource = book.resources.findByProperty("cover-image") {
            book.coverImage = coverResource
        }

        if let tocResource = book.resources.findByMediaType(MediaType.ncx) {
            book.tocResource = tocResource
        } else if let tocResource = book.resources.findByExtension(MediaType.ncx.defaultExtension) {
            book.tocResource = tocResource
        } else if let tocResource = book.resources.findByProperty("nav") {
            book.tocResource = tocResource
        }

        precondition(book.tocResource != nil, "ERROR: Could not find table of contents resource. The book don't have a TOC resource.")

        book.tableOfContents = findTableOfContents()
        book.flatTableOfContents = flatTOC

        let spine = xmlDoc.root["spine"]
        book.spine = readSpine(spine.children)

        if let pageProgressionDirection = spine.attributes["page-progression-direction"] {
            book.spine.pageProgressionDirection = pageProgressionDirection
        }
    }

    private func readSmilFile(_ resource: Resource) {
        do {
            let smilData = try Data(contentsOf: URL(fileURLWithPath: resource.fullHref), options: .alwaysMapped)
            var smilFile = SmilFile(resource: resource)
            let xmlDoc = try AEXMLDocument(xml: smilData)

            let children = xmlDoc.root["body"].children

            if children.count > 0 {
                smilFile.data.append(contentsOf: readSmilFileElements(children))
            }

            book.smils.add(smilFile)
        } catch {
            print("Cannot read .smil file: " + resource.href)
        }
    }

    private func readSmilFileElements(_ children: [AEXMLElement]) -> [SmilElement] {
        var data = [SmilElement]()

        children.forEach{
            let smil = SmilElement(name: $0.name, attributes: $0.attributes)

            if $0.children.count > 0 {
                smil.children.append(contentsOf: readSmilFileElements($0.children))
            }

            data.append(smil)
        }

        return data
    }

    private func findTableOfContents() -> [TocReference] {
        var tableOfContent = [TocReference]()
        var tocItems: [AEXMLElement]?
        guard let tocResource = book.tocResource else { return tableOfContent }
        let tocURL = resourcesURL.appendingPathComponent(tocResource.href)
        
        do {
            if tocResource.mediaType == MediaType.ncx {
                let ncxData = try Data(contentsOf: tocURL, options: .alwaysMapped)
                let xmlDoc = try AEXMLDocument(xml: ncxData)
                if let itemsList = xmlDoc.root["navMap"]["navPoint"].all {
                    tocItems = itemsList
                }
            } else {
                let tocData = try Data(contentsOf: tocURL, options: .alwaysMapped)
                let xmlDoc = try AEXMLDocument(xml: tocData)
                
                if let nav = xmlDoc.root["body"]["nav"].first, let itemsList = nav["ol"]["li"].all {
                    tocItems = itemsList
                } else if let nav = findNavTag(xmlDoc.root["body"]), let itemsList = nav["ol"]["li"].all {
                    tocItems = itemsList
                }
            }
        } catch {
            print("Cannot find Table of Contents.")
        }
        
        guard let items = tocItems else { return tableOfContent }

        for item in items {
            guard let ref = readTOCReference(item) else { continue }
            tableOfContent.append(ref)
        }

        return tableOfContent
    }

    @discardableResult func findNavTag(_ element: AEXMLElement) -> AEXMLElement? {
        for element in element.children {
            if let nav = element["nav"].first {
                return nav
            } else {
                findNavTag(element)
            }
        }
        return nil
    }

    fileprivate func readTOCReference(_ navpointElement: AEXMLElement) -> TocReference? {
        var label = ""

        if book.tocResource?.mediaType == MediaType.ncx {
            if let labelText = navpointElement["navLabel"]["text"].value {
                label = labelText
            }

            guard let reference = navpointElement["content"].attributes["src"] else { return nil }
            let hrefSplit = reference.split {$0 == "#"}.map { String($0) }
            let fragmentID = hrefSplit.count > 1 ? hrefSplit[1] : ""
            let href = hrefSplit[0]

            let resource = book.resources.findByHref(href)
            let toc = TocReference(title: label, resource: resource, fragmentID: fragmentID)

            if let navPoints = navpointElement["navPoint"].all {
                for navPoint in navPoints {
                    guard let item = readTOCReference(navPoint) else { continue }
                    toc.children.append(item)
                }
            }
            return toc
        } else {
            if let labelText = navpointElement["a"].value {
                label = labelText
            }

            guard let reference = navpointElement["a"].attributes["href"] else { return nil }
            let hrefSplit = reference.split {$0 == "#"}.map { String($0) }
            let fragmentID = hrefSplit.count > 1 ? hrefSplit[1] : ""
            let href = hrefSplit[0]

            let resource = book.resources.findByHref(href)
            let toc = TocReference(title: label, resource: resource, fragmentID: fragmentID)

            if let navPoints = navpointElement["ol"]["li"].all {
                for navPoint in navPoints {
                    guard let item = readTOCReference(navPoint) else { continue }
                    toc.children.append(item)
                }
            }
            return toc
        }
    }

    var flatTOC: [TocReference] {
        var tocItems = [TocReference]()

        for item in book.tableOfContents {
            tocItems.append(item)
            tocItems.append(contentsOf: countTocChild(item))
        }
        return tocItems
    }

    func countTocChild(_ item: TocReference) -> [TocReference] {
        var tocItems = [TocReference]()

        item.children.forEach {
            tocItems.append($0)
        }
        return tocItems
    }

    fileprivate func readMetadata(_ tags: [AEXMLElement]) -> Metadata {
        let metadata = Metadata()

        for tag in tags {
            if tag.name == "dc:title" {
                metadata.titles.append(tag.value ?? "")
            }

            if tag.name == "dc:identifier" {
                let identifier = Identifier(id: tag.attributes["id"], scheme: tag.attributes["opf:scheme"], value: tag.value)
                metadata.identifiers.append(identifier)
            }

            if tag.name == "dc:language" {
                let language = tag.value ?? metadata.language
                metadata.language = language != "en" ? language : metadata.language
            }

            if tag.name == "dc:creator" {
                metadata.creators.append(Author(name: tag.value ?? "", role: tag.attributes["opf:role"] ?? "", fileAs: tag.attributes["opf:file-as"] ?? ""))
            }

            if tag.name == "dc:contributor" {
                metadata.creators.append(Author(name: tag.value ?? "", role: tag.attributes["opf:role"] ?? "", fileAs: tag.attributes["opf:file-as"] ?? ""))
            }

            if tag.name == "dc:publisher" {
                metadata.publishers.append(tag.value ?? "")
            }

            if tag.name == "dc:description" {
                metadata.descriptions.append(tag.value ?? "")
            }

            if tag.name == "dc:subject" {
                metadata.subjects.append(tag.value ?? "")
            }

            if tag.name == "dc:rights" {
                metadata.rights.append(tag.value ?? "")
            }

            if tag.name == "dc:date" {
                metadata.dates.append(EventDate(date: tag.value ?? "", event: tag.attributes["opf:event"] ?? ""))
            }

            if tag.name == "meta" {
                if tag.attributes["name"] != nil {
                    metadata.metaAttributes.append(Meta(name: tag.attributes["name"], content: tag.attributes["content"]))
                }

                if tag.attributes["property"] != nil && tag.attributes["id"] != nil {
                    metadata.metaAttributes.append(Meta(id: tag.attributes["id"], property: tag.attributes["property"], value: tag.value))
                }

                if tag.attributes["property"] != nil {
                    metadata.metaAttributes.append(Meta(property: tag.attributes["property"], value: tag.value, refines: tag.attributes["refines"]))
                }
            }
        }
        return metadata
    }

    fileprivate func readSpine(_ tags: [AEXMLElement]) -> Spine {
        let spine = Spine()

        for tag in tags {
            guard let idref = tag.attributes["idref"] else { continue }
            var linear = true

            if tag.attributes["linear"] != nil {
                linear = tag.attributes["linear"] == "yes" ? true : false
            }

            if book.resources.containsById(idref) {
                guard let resource = book.resources.findById(idref) else { continue }
                spine.spineReferences.append(BaseSpine(resource: resource, linear: linear))
            }
        }
        return spine
    }

    fileprivate func addSkipBackupAttributeToItemAtURL(_ url: URL) throws {
        assert(FileManager.default.fileExists(atPath: url.path))

        var urlToExclude = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try urlToExclude.setResourceValues(resourceValues)
    }
}

extension _EPUBDecoder {
    enum Error: Swift.Error, LocalizedError {
        case bookNotAvailable(path: String)
        case errorInContainer
        case errorInOpf
        case authorNameNotAvailable
        case coverNotAvailable
        case invalidImage(path: String)
        case titleNotAvailable
        case fullPathEmpty
        
        public var errorDescription: String? {
            switch self {
            case .bookNotAvailable(let path): return "Book not found at path: \(path)"
            case .errorInContainer, .errorInOpf: return "Invalid book format"
            case .authorNameNotAvailable: return "Author name not available"
            case .coverNotAvailable: return "Cover image not available"
            case .invalidImage(let path): return "Invalid image at path: \(path)"
            case .titleNotAvailable: return "Book title not available"
            case .fullPathEmpty: return "Book corrupted"
            }
        }
    }
}
