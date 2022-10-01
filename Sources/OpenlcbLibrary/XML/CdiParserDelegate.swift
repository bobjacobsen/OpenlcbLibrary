//
//  CdiParserDelegate.swift
//  OpenlcbLibrary
//
//  Created by Bob Jacobsen on 6/29/22.
//

import Foundation
import os

/// Delegate for use with ``XMLParser``, this is used to process CDI XML files and create a tree of ``CdiXmlMemo`` objects.
final class CdiParserDelegate : NSObject, XMLParserDelegate { // class for inheritance
    
    internal static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "CdiParserDelegate")
    
    // MARK: Delegate methods
    
    func parserDidStartDocument(_ parser : XMLParser) {
    }
    
    func parserDidEndDocument(_ parser : XMLParser) {
    }
    
    func parser(_: XMLParser, didStartElement: String, namespaceURI: String?, qualifiedName: String?, attributes: [String : String]) {
        switch didStartElement {
        case "cdi" :
            cdiStart()
        case "identification" :
            identificationStart()
        case "acdi" :
            acdiStart()
        case "segment" :
            segmentStart(attributes: attributes)
        case "group" :
            groupStart(attributes: attributes)
        case "name" :
            nameSubStart()
        case "repname" :
            repnameSubStart()
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
        case "property" :
            propertyStart()
        case "value" :
            valueStart()
        default:
            break
        }
    }

    func parser(_: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName : String?) {
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
        case "repname" :
            repnameSubEnd()
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
        case "property" :
            propertyEnd()
        case "value" :
            valueEnd()
        default:
            break // have to say something
        }
    }

    func parser(_ : XMLParser, foundCharacters: String) {
        // check state, store as requested
        switch currentTextState { // what kind of element was this text within?
        case .NAME :
            memoStack[memoStack.count-1].name = foundCharacters
        case .REPNAME :
            memoStack[memoStack.count-1].repname = foundCharacters
        case .DESCRIPTION :
            memoStack[memoStack.count-1].description = foundCharacters
        case .DEFAULT :
            memoStack[memoStack.count-1].defaultValue = Int(foundCharacters) ?? 0
            memoStack[memoStack.count-1].currentIntValue = memoStack[memoStack.count-1].defaultValue
        case .MIN :
            memoStack[memoStack.count-1].minValue = Int(foundCharacters) ?? 0
            memoStack[memoStack.count-1].minSet = true
        case .MAX :
            // max depends on length in bytes, assuming unsigned consistent with default min = 0
            let maxDefault = (1 << (8*memoStack[memoStack.count-1].length)) - 1
            memoStack[memoStack.count-1].maxValue = Int(foundCharacters) ?? maxDefault
            if memoStack[memoStack.count-1].maxValue > maxDefault {
                CdiParserDelegate.logger.error("Defined max value \(self.memoStack[self.memoStack.count-1].maxValue, privacy:.public) is larger than sized \(maxDefault, privacy:.public)")
                memoStack[memoStack.count-1].maxValue = maxDefault
            }
            memoStack[memoStack.count-1].maxSet = true
        case .PROPERTY :
            memoStack[memoStack.count-1].properties.append(foundCharacters)
        case .VALUE :
            memoStack[memoStack.count-1].values.append(foundCharacters)
        case .NONE :
            break // need a statement for this case
        }
        currentTextState = .NONE  // nothing else until told to do something
    }

    // MARK: State
    
    var memoStack : [CdiXmlMemo] = []
    var currentTextState = NextTextOperation.NONE
    
    
    /// Defines a state machine that maps specific XML CDI elements to
    ///  `CdiXmlMemo` objects.
    enum NextTextOperation {
        case NONE
        case NAME
        case REPNAME
        case DESCRIPTION
        case DEFAULT
        case MIN
        case MAX
        case PROPERTY // part of map
        case VALUE    // part of map
    }
    
    // MARK: Element methods
    
    func cdiStart() {
        // push first element
        memoStack.append(CdiXmlMemo())
     }
    func cdiEnd() {
    }

    func acdiStart() {
        // TODO: add standard-defined ACDI contents - note that JMRI seems to ignore it, and TCS, RR-Cirkits replicates the info in a Segment
    }
    func acdiEnd() {
    }

    func identificationStart() {
        // TODO: add standard-defined Identification contents - maps to a (virtual) segment with read-only string variables
    }
    func identificationEnd() {
    }

    func segmentStart(attributes : [String:String]) {
        let thisMemo = CdiXmlMemo()
        thisMemo.type = .SEGMENT
        thisMemo.space = 0
        if let attr = attributes["space"] {
            if let space = Int(attr) {
                thisMemo.space = space
            }
        }
        thisMemo.startAddress = 0
        if let attr = attributes["origin"] {
            if let origin = Int(attr) {
                thisMemo.startAddress = origin
            }
        }
        memoStack.append(thisMemo)
    }
    func segmentEnd() {
        // fill and pop
        let current = memoStack.removeLast()
        current.type = .SEGMENT
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children?.append(current) // ".last" is a getter
    }

    func groupStart(attributes : [String:String]) {
        let thisMemo = CdiXmlMemo()
        if let attr = attributes["replication"] {
            if let length = Int(attr) {
                thisMemo.length = length
            }
        }
        thisMemo.offset = 0
        if let attr = attributes["offset"] {
            if let offset = Int(attr) {
                thisMemo.offset = offset
            }
        }
        memoStack.append(thisMemo)
    }
    func groupEnd() {
        // fill and pop
        let current = memoStack.removeLast()
        current.type = .GROUP
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children?.append(current) // ".last" is a getter
    }

    func nameSubStart() {
        // process name sub-element by adding to existing memo
        // next character content goes to the name of the most recent element
        currentTextState = .NAME
    }
    func nameSubEnd() {
        currentTextState = .NONE
    }
    
    func repnameSubStart() {
        // process repname sub-element by adding to existing memo
        // next character content goes to the repname of the most recent element
        currentTextState = .REPNAME
    }
    func repnameSubEnd() {
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
        let thisMemo = CdiXmlMemo()
        thisMemo.length = 1
        var maxDefault = 255
        if let attr = attributes["size"] {
            if let length = Int(attr) {
                thisMemo.length = length
                maxDefault = (1 << (8*length)) - 1
            }
        }
        thisMemo.maxValue = maxDefault  // this will be overridden if there's a later max element

        thisMemo.offset = 0
        if let attr = attributes["offset"] {
            if let offset = Int(attr) {
                thisMemo.offset = offset
            }
        }
        memoStack.append(thisMemo)
    }
    func intEnd()  {
        let current = memoStack.removeLast()
        current.type = .INPUT_INT
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children?.append(current) // ".last" is a getter
        // no children in current node
        current.children = nil
    }

    func eventIdStart(attributes : [String:String]) {
        let thisMemo = CdiXmlMemo()
        thisMemo.length = 8
        thisMemo.offset = 0
        if let attr = attributes["offset"] {
            if let offset = Int(attr) {
                thisMemo.offset = offset
            }
        }
        memoStack.append(thisMemo)
    }
    func eventIdEnd()  {
        let current = memoStack.removeLast()
        current.type = .INPUT_EVENTID
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children?.append(current) // ".last" is a getter
        current.children = nil
    }

    func stringStart(attributes : [String:String]) {
        let thisMemo = CdiXmlMemo()
        if let attr = attributes["size"] {
            if let length = Int(attr) {
                thisMemo.length = length
            }
        }
        thisMemo.offset = 0
        if let attr = attributes["offset"] {
            if let offset = Int(attr) {
                thisMemo.offset = offset
            }
        }
        memoStack.append(thisMemo)
    }
    func stringEnd()  {
        let current = memoStack.removeLast()
        current.type = .INPUT_STRING
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children?.append(current) // ".last" is a getter
        current.children = nil
    }
    
    func propertyStart() {
        currentTextState = .PROPERTY
    }
    func propertyEnd() {
        currentTextState = .NONE
    }

    func valueStart() {
        currentTextState = .VALUE
    }
    func valueEnd() {
        currentTextState = .NONE
    }
}
