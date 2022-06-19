//
//  CdiXmlMemo.swift
//  
//
//  Created by Bob Jacobsen on 6/19/22.
//

/// Representation of a CDI XML node
///
import Foundation

struct CdiXmlMemo : Equatable {
    enum XMLMemoType {
        case TOPLEVEL // cdi element itself
        case SEGMENT  // Segment is a top-level group
        case GROUP
        case INPUT_EVENTID
        case INPUT_INT
        case INPUT_STRING
    }
    // common values
    var type : XMLMemoType
    var name : String
    var description : String
    // input values - see also type
    let length : Int
    let startAddress : Int
    var defaultValue : Int
    var maxValue = 2_147_483_647  // 32 bit max
    var minValue = 0
    
    var children : [CdiXmlMemo]
    
    // TODO: needs map support
    // TODO: needs max/min for int
    
    // init mainly for segment, group
    init(_ type : XMLMemoType, _ name : String, _ description : String, children : [CdiXmlMemo] = []) {
        self.type = type
        self.name = name
        self.description = description
        self.length = 0
        self.startAddress = 0
        self.defaultValue = 0
        self.children = children
    }
    // init mainly for input
    init(_ type : XMLMemoType, _ name : String, _ description : String, length : Int, startAddress : Int, defaultValue : Int) {
        self.type = type
        self.name = name
        self.description = description
        self.length = length
        self.startAddress = startAddress
        self.defaultValue = defaultValue
        self.children = []
    }
    // only for creating a null object
    init() {
        self.type = .TOPLEVEL
        self.name = ""
        self.description = ""
        self.length = 0
        self.startAddress = 0
        self.defaultValue = 0
        self.children = []
    }
}

// reads from ~/Documents and creates an NSData from the file contents
func getDataFromFile(_ file : String) -> Data? {
    guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print ("problem with directory")
        return nil
    }
    do {
        let fileURL = dir.appendingPathComponent(file)
        let data = try Data(contentsOf: fileURL)
        // print (text)
        return data
    } catch {
        print ("caught \(error)")
        return nil
    }
}

class CdiParserDelegate : NSObject, XMLParserDelegate {
    // MARK: Delegate methods
    func parserDidStartDocument(_ parser : XMLParser) {
        print ("parserDidStartDocument")
    }
    func parserDidEndDocument(_ parser : XMLParser) {
        print ("parserDidEndDocument")
    }
    func parser(_: XMLParser, didStartElement: String, namespaceURI: String?, qualifiedName: String?, attributes: [String : String]) {
        // print ("didStartElement \(didEndElement)")
        switch didStartElement {
        case "cdi" :
            cdiStart()
        case "identification" :
            identificationStart()
        case "acdi" :
            acdiStart()
        case "segment" :
            segmentStart()
        case "group" :
            groupStart()
        case "name" :
            nameSubStart()
        case "description" :
            descSubStart()
        case "default" :
            defaultSubStart()
        case "min" :
            minSubStart()
        case "max" :
            maxSubStart()
        case "int" :
            intStart(attributes: attributes)
        case "eventid" :
            eventIdStart(attributes: attributes)
        case "string" :
            stringStart(attributes: attributes)
        default:
            print ("did start element \(didStartElement) attributes: \(attributes)")
        }
    }

    func parser(_: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName : String?) {
        // print ("didEndElement \(didEndElement)")
        switch didEndElement {
        case "cdi" :
            cdiEnd()
        case "identification" :
            identificationEnd()
        case "acdi" :
            acdiEnd()
        case "segment" :
            segmentEnd()
        case "group" :
            groupEnd()
        case "name" :
            nameSubEnd()
        case "description" :
            descSubEnd()
        case "default" :
            defaultSubEnd()
        case "min" :
            minSubEnd()
        case "max" :
            maxSubEnd()
        case "int" :
            intEnd()
        case "eventid" :
            eventIdEnd()
        case "string" :
            stringEnd()
        default:
            print ("did end element \(didEndElement)")
        }
    }

    func parser(_ : XMLParser, foundCharacters: String) {
        // check state, store as requested
        switch currentTextState {
        case .NAME :
            memoStack[memoStack.count-1].name = foundCharacters
        case .DESCRIPTION :
            memoStack[memoStack.count-1].description = foundCharacters
        case .DEFAULT :
            memoStack[memoStack.count-1].defaultValue = Int(foundCharacters) ?? 0
        case .MIN :
            memoStack[memoStack.count-1].minValue = Int(foundCharacters) ?? 0
        case .MAX :
            memoStack[memoStack.count-1].maxValue = Int(foundCharacters) ?? 2_147_483_647  // 32 bit max
        case .NONE :
            break // need a statement for this case
        }
        currentTextState = .NONE  // nothing else until told to do something
    }

    // MARK: State
    var memoStack : [CdiXmlMemo] = []
    var currentTextState = NextTextOperation.NONE
    enum NextTextOperation {
        case NONE
        case NAME
        case DESCRIPTION
        case DEFAULT
        case MIN
        case MAX
    }
    
    // MARK: Element methods
    func cdiStart() {
        // push first element
        memoStack.append(CdiXmlMemo())
     }
    func cdiEnd() {
        // TODO: leave in place, don't pop, report as end element
    }

    func acdiStart() {
        // TODO: add standard-defined ACDI contents
    }
    func acdiEnd() {
        // TODO: add standard-defined ACDI contents
    }

    func identificationStart() {
        // TODO: add standard-defined Identification contents
    }
    func identificationEnd() {
        // TODO: add standard-defined Identification contents
    }

    func segmentStart() {
        memoStack.append(CdiXmlMemo())
        print ("segment start \(memoStack)")
    }
    func segmentEnd() {
        // TODO: fill and pop
        var current = memoStack.removeLast()
        current.type = .SEGMENT
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children.append(current) // ".last" is a getter
        print ("segment end \(memoStack)")
    }

    func groupStart() {
        memoStack.append(CdiXmlMemo())
        print ("group start \(memoStack)")
    }
    func groupEnd() {
        // TODO: fill and pop
        var current = memoStack.removeLast()
        current.type = .GROUP
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children.append(current) // ".last" is a getter
        print ("group end \(memoStack)")
    }

    func nameSubStart() {
        // process name sub-element by adding to existing memo
        // next character content goes to the name of the most recent element
        currentTextState = .NAME
    }
    func nameSubEnd() {
        currentTextState = .NONE
    }
    
    func descSubStart() {
        // process description sub-element by adding to existing memo
        // next character content goes to the description of the most recent element
        currentTextState = .DESCRIPTION
    }
    func descSubEnd() {
        currentTextState = .NONE
    }
    
    func minSubStart() {
        // process min sub-element by adding to existing memo
        // next character content goes to the min of the most recent element
        currentTextState = .MIN
    }
    func minSubEnd() {
        currentTextState = .NONE
    }
    
    func maxSubStart() {
        // process max sub-element by adding to existing memo
        // next character content goes to the max of the most recent element
        currentTextState = .MAX
    }
    func maxSubEnd() {
        currentTextState = .NONE
    }
    
    func defaultSubStart() {
        // process default sub-element by adding to existing memo
        // next character content goes to the default of the most recent element
        currentTextState = .DEFAULT
    }
    func defaultSubEnd() {
        currentTextState = .NONE
    }
    
    func intStart(attributes : [String:String]) {
        let memo = CdiXmlMemo()
        memoStack.append(memo)
    }
    func intEnd()  {
        var current = memoStack.removeLast()
        current.type = .INPUT_INT
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children.append(current) // ".last" is a getter
        print ("int end \(memoStack)")
    }

    func eventIdStart(attributes : [String:String]) {
        memoStack.append(CdiXmlMemo())
    }
    func eventIdEnd()  {
        var current = memoStack.removeLast()
        current.type = .INPUT_EVENTID
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children.append(current) // ".last" is a getter
        print ("int end \(memoStack)")
    }

    func stringStart(attributes : [String:String]) {
        memoStack.append(CdiXmlMemo())
    }
    func stringEnd()  {
        var current = memoStack.removeLast()
        current.type = .INPUT_STRING
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children.append(current) // ".last" is a getter
        print ("int end \(memoStack)")
    }

}

