import Foundation

struct SmilFile {
    var resource: Resource
    var data = [SmilElement]()

    init(resource: Resource){
        self.resource = resource;
    }

    func ID() -> String {
        return self.resource.id;
    }

    func href() -> String {
        return self.resource.href;
    }

    func parallelAudioForFragment(_ fragment: String!) -> SmilElement! {
        return findParElement(forTextSrc: fragment, inData: data)
    }

    fileprivate func findParElement(forTextSrc src:String!, inData _data:[SmilElement]) -> SmilElement! {
        for el in _data {

            if( el.name == "par" && (src == nil || el.textElement().attributes["src"]?.contains(src) != false ) ){
                return el

            }else if el.name == "seq" && el.children.count > 0 {
                let parEl = findParElement(forTextSrc: src, inData: el.children)
                if parEl != nil { return parEl }
            }
        }
        return nil
    }

    func nextParallelAudioForFragment(_ fragment: String) -> SmilElement! {
        return findNextParElement(forTextSrc: fragment, inData: data)
    }

    fileprivate func findNextParElement(forTextSrc src:String!, inData _data:[SmilElement]) -> SmilElement! {
        var foundPrev = false
        for el in _data {

            if foundPrev { return el }

            if( el.name == "par" && (src == nil || el.textElement().attributes["src"]?.contains(src) != false) ){
                foundPrev = true

            }else if el.name == "seq" && el.children.count > 0 {
                let parEl = findNextParElement(forTextSrc: src, inData: el.children)
                if parEl != nil { return parEl }
            }
        }
        return nil
    }


    func childWithName(_ name:String) -> SmilElement! {
        for el in data {
            if( el.name == name ){
                return el
            }
        }
        return nil;
    }

    func childrenWithNames(_ name:[String]) -> [SmilElement]! {
        var matched = [SmilElement]()
        for el in data {
            if( name.contains(el.name) ){
                matched.append(el)
            }
        }
        return matched;
    }

    func childrenWithName(_ name:String) -> [SmilElement]! {
        return childrenWithNames([name])
    }
}

class Smils: NSObject {
    var basePath            : String!
    var smils               = [String: SmilFile]()

    func add(_ smil: SmilFile) {
        self.smils[smil.resource.href] = smil
    }

    func findByHref(_ href: String) -> SmilFile? {
        for smil in smils.values {
            if smil.resource.href == href {
                return smil
            }
        }
        return nil
    }

    func findById(_ ID: String) -> SmilFile? {
        for smil in smils.values {
            if smil.resource.id == ID {
                return smil
            }
        }
        return nil
    }
}
