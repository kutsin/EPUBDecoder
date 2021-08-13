import Foundation

class SmilElement: NSObject {
    var name: String
    var attributes: [String: String]!
    var children: [SmilElement]

    init(name: String, attributes: [String:String]!) {
        self.name = name
        self.attributes = attributes
        self.children = [SmilElement]()
    }
    
    func getId() -> String! {
        return getAttribute("id")
    }

    func getSrc() -> String! {
        return getAttribute("src")
    }

    func getType() -> [String]! {
        let type = getAttribute("epub:type", defaultVal: "")
        return type!.components(separatedBy: " ")
    }

    func isType(_ aType:String) -> Bool {
        return getType().contains(aType)
    }

    func getAttribute(_ name: String, defaultVal: String!) -> String! {
        return attributes[name] != nil ? attributes[name] : defaultVal;
    }

    func getAttribute(_ name: String ) -> String! {
        return getAttribute(name, defaultVal: nil)
    }

    func textElement() -> SmilElement! {
        return childWithName("text")
    }

    func audioElement() -> SmilElement! {
        return childWithName("audio")
    }

    func videoElement() -> SmilElement! {
        return childWithName("video")
    }

    func childWithName(_ name:String) -> SmilElement! {
        for el in children {
            if( el.name == name ){
                return el
            }
        }
        return nil;
    }

    func childrenWithNames(_ name:[String]) -> [SmilElement]! {
        var matched = [SmilElement]()
        for el in children {
            if( name.contains(el.name) ){
                matched.append(el)
            }
        }
        return matched;
    }

    func childrenWithName(_ name:String) -> [SmilElement]! {
        return childrenWithNames([name])
    }

    func clipBegin() -> Double {
        let val = audioElement().getAttribute("clipBegin", defaultVal: "")
        return val!.clockTimeToSeconds()
    }

    func clipEnd() -> Double {
        let val = audioElement().getAttribute("clipEnd", defaultVal: "")
        return val!.clockTimeToSeconds()
    }
}

private extension String {
    func clockTimeToSeconds() -> Double {
        
        let val = self.trimmingCharacters(in: CharacterSet.whitespaces)
        
        if( val.isEmpty ){ return 0 }
        
        let formats = [
            "HH:mm:ss.SSS"  : "^\\d{1,2}:\\d{2}:\\d{2}\\.\\d{1,3}$",
            "HH:mm:ss"      : "^\\d{1,2}:\\d{2}:\\d{2}$",
            "mm:ss.SSS"     : "^\\d{1,2}:\\d{2}\\.\\d{1,3}$",
            "mm:ss"         : "^\\d{1,2}:\\d{2}$",
            "ss.SSS"         : "^\\d{1,2}\\.\\d{1,3}$",
            ]
        
        for (format, pattern) in formats {
            
            if val.range(of: pattern, options: .regularExpression) != nil {
                
                let formatter = DateFormatter()
                formatter.dateFormat = format
                let time = formatter.date(from: val)
                
                if( time == nil ){ return 0 }
                
                formatter.dateFormat = "ss.SSS"
                let seconds = (formatter.string(from: time!) as NSString).doubleValue
                
                formatter.dateFormat = "mm"
                let minutes = (formatter.string(from: time!) as NSString).doubleValue
                
                formatter.dateFormat = "HH"
                let hours = (formatter.string(from: time!) as NSString).doubleValue
                
                return seconds + (minutes*60) + (hours*60*60)
            }
        }
        
        if val.range(of: "^\\d+ms$", options: .regularExpression) != nil{
            return (val as NSString).doubleValue / 1000.0
        }
        
        if val.range(of: "^\\d+(\\.\\d+)?h$", options: .regularExpression) != nil {
            return (val as NSString).doubleValue * 60 * 60
        }
        
        if val.range(of: "^\\d+(\\.\\d+)?min$", options: .regularExpression) != nil {
            return (val as NSString).doubleValue * 60
        }
        
        return 0
    }
}
