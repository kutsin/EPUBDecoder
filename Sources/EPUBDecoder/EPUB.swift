import Foundation

public final class EPUB: NSObject {
    var metadata = Metadata()
    var spine = Spine()
    var smils = Smils()
    var version: Double?
    
    public var opfResource: Resource!
    public var tocResource: Resource?
    public var uniqueIdentifier: String?
    public var coverImage: Resource?
    public var name: String?
    public var resources = Resources()
    public var tableOfContents: [TocReference]!
    public var flatTableOfContents: [TocReference]!

    var hasAudio: Bool {
        return smils.smils.count > 0
    }

    var title: String? {
        return metadata.titles.first
    }

    var authorName: String? {
        return metadata.creators.first?.name
    }
    
    var duration: String? {
        return metadata.find(byProperty: "media:duration")?.value
    }

    var activeClass: String {
        guard let className = metadata.find(byProperty: "media:active-class")?.value else {
            return "epub-media-overlay-active"
        }
        return className
    }

    var playbackActiveClass: String {
        guard let className = metadata.find(byProperty: "media:playback-active-class")?.value else {
            return "epub-media-overlay-playing"
        }
        return className
    }

    func smilFileForResource(_ resource: Resource?) -> SmilFile? {
        guard let resource = resource, let mediaOverlay = resource.mediaOverlay else { return nil }

        guard let smilResource = resources.findById(mediaOverlay) else { return nil }

        return smils.findByHref(smilResource.href)
    }

    func smilFile(forHref href: String) -> SmilFile? {
        return smilFileForResource(resources.findByHref(href))
    }

    func smilFile(forId ID: String) -> SmilFile? {
        return smilFileForResource(resources.findById(ID))
    }
    
    func duration(for ID: String) -> String? {
        return metadata.find(byProperty: "media:duration", refinedBy: ID)?.value
    }
    
    func plainText() throws -> String {
        elements = []
        for reference in flatTableOfContents {
            guard let resource = reference.resource else {
                throw Error.resourceNotFound(title: reference.title)
            }
            let fileURL = URL(fileURLWithPath: resource.fullHref)
            guard let parser = XMLParser(contentsOf: fileURL) else {
                throw Error.unableToParse(path: resource.fullHref)
            }
            parser.delegate = self
            guard parser.parse() else {
                throw Error.unableToParse(path: resource.fullHref)
            }
            guard error == nil else { throw error! }
        }
        return elements
            .filter { !($0.text?.isEmpty ?? true) }
            .compactMap { $0.text }
            .joined(separator: " ")
    }
    
    private var error: Swift.Error?
    private var elements: [XMLElement] = []
    private var didStartNewElement = true
}

extension EPUB: XMLParserDelegate {

    private enum XMLElementType: String {
        case root
        case html, head, meta, title, link, body, span, div, img, h1, h2, ul, li, a
        case unknown
        
        init(name: String) {
            self = XMLElementType(rawValue: name) ?? .unknown
        }
    }
    
    private class XMLElement: NSObject {
        var name: String
        var attributes: [String : String] = [:]
        var text: String?
                
        public init(name: String) {
            self.name = name
        }
        
        var type: XMLElementType {
            return XMLElementType(name: name)
        }
        
        override var debugDescription: String {
            return "\n================\nName = \(name)\nAttributes = \(attributes)\nText = \(text ?? "")"
        }
    }

    public func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        didStartNewElement = true
        let element = XMLElement(name: elementName)
        element.attributes = attributeDict
        elements.append(element)
    }
    
    public func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        didStartNewElement = false
    }
    
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        let string = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !string.isEmpty else { return }
        if let text = elements.last?.text {
            var newText = text
            if !didStartNewElement && !newText.hasSuffix(" ") {
                didStartNewElement = true
                newText.append(" ")
            }
            newText.append(string)
            elements.last?.text = newText
        } else {
            elements.last?.text = string
        }
    }
    
    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Swift.Error) {
        error = parseError
    }
    
    public func parser(_ parser: XMLParser, validationErrorOccurred validationError: Swift.Error) {
        error = validationError
    }
}

extension EPUB {
    enum Error: Swift.Error, LocalizedError {
        case resourceNotFound(title: String)
        case invalidResourcePath(path: String)
        case unableToParse(path: String)
        case unableToParseElement(name: String)
        case unknown

        public var errorDescription: String? {
            switch self {
            case .resourceNotFound(let title): return "Resource not found: \(title)"
            case .invalidResourcePath(let path): return "Invalid resource path: \(path)"
            case .unableToParse(let path): return "Unable to parse file at path: \(path)"
            case .unableToParseElement(let name): return "Unable to parse element: \(name)"
            case .unknown: return "Unknown Error"
            }
        }
    }
}
