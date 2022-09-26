//
//  FdiParserDelegate.swift
//  
//
//  Created by Bob Jacobsen on 9/25/22.
//

import Foundation
import os

/// Delegate for use with ``XMLParser``, this is used to process FDI XML files and create a tree of ``FdiXmlMemo`` objects.
final class FdiParserDelegate : NSObject, XMLParserDelegate { // class for inheritance
    
    private static let logger = Logger(subsystem: "us.ardenwood.OpenlcbLibrary", category: "FdiParserDelegate")
    
    // MARK: Delegate methods
    
    func parserDidStartDocument(_ parser : XMLParser) {
    }
    
    func parserDidEndDocument(_ parser : XMLParser) {
        // print ("parserDidEndDocument")
    }
    
    func parser(_: XMLParser, didStartElement: String, namespaceURI: String?, qualifiedName: String?, attributes: [String : String]) {
        switch didStartElement {
        case "fdi" :
            fdiStart()
        case "segment" :
            segmentStart(attributes: attributes)
        case "name" :
            nameSubStart()
        case "description" :
            descriptionSubStart()
        case "group" :
            groupStart(attributes: attributes)
        case "function" :
            functionStart(attributes: attributes)
        case "number" :
            numberStart()
        default:
            FdiParserDelegate.logger.error("Unexpected element: \(didStartElement, privacy:.public)")
            break
        }
    }
    
    func parser(_: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName : String?) {
        switch didEndElement {
        case "fdi" :
            fdiEnd()
        case "segment" :
            segmentEnd()
        case "name" :
            nameSubEnd()
        case "description" :
            descriptionSubEnd()
        case "group" :
            groupEnd()
        case "function" :
            functionEnd()
        case "number" :
            numberEnd()
        default:
            break // have to say something
        }
    }
    
    func parser(_ : XMLParser, foundCharacters: String) {
        // check state, store as requested
        switch currentTextState { // what kind of element was this text within?
        case .NAME :
            memoStack[memoStack.count-1].name = foundCharacters
        case .DESCRIPTION :
            memoStack[memoStack.count-1].description = foundCharacters
        case .NUMBER :
            if let number = Int(foundCharacters) {
                memoStack[memoStack.count-1].number = number
            } else {
                FdiParserDelegate.logger.error("Cound not parse number: \(foundCharacters, privacy:.public)")
                memoStack[memoStack.count-1].number = 0
            }
        case .FUNCTION:
            break // need a statement for this case
        case .NONE:
            break // need a statement for this case
        }
        currentTextState = .NONE  // nothing else until told to do something
    }
    
    // MARK: State
    
    var memoStack : [FdiXmlMemo] = []
    var currentTextState = NextTextOperation.NONE
    
    
    /// Defines a state machine that maps specific XML FDI elements to
    ///  `FdiXmlMemo` objects.
    enum NextTextOperation {
        case NONE
        case NAME
        case DESCRIPTION
        case FUNCTION
        case NUMBER
    }
    
    // MARK: Element methods
    
    func fdiStart() {
        // push first element
        memoStack.append(FdiXmlMemo())
    }
    func fdiEnd() {
    }
    
    func segmentStart(attributes : [String:String]) {
        let thisMemo = FdiXmlMemo()
        thisMemo.type = .SEGMENT
        thisMemo.space = 0
        if let attr = attributes["space"] {
            if let space = Int(attr) {
                thisMemo.space = space
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
    
    func nameSubStart() {
        // process name sub-element by adding to existing memo
        // next character content goes to the name of the most recent element
        currentTextState = .NAME
    }
    func nameSubEnd() {
        currentTextState = .NONE
    }
    
    func descriptionSubStart() {
        // process description sub-element by adding to existing memo
        // next character content goes to the description of the most recent element
        currentTextState = .DESCRIPTION
    }
    func descriptionSubEnd() {
        currentTextState = .NONE
    }
    
    func groupStart(attributes : [String:String]) {
        let thisMemo = FdiXmlMemo()
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
    
    func functionStart(attributes : [String:String]) {
        let thisMemo = FdiXmlMemo()
        thisMemo.offset = 0
        if let attr = attributes["kind"] {
            if attr == "binary" {
                thisMemo.binaryKind = true
                thisMemo.momentaryKind = false
            } else if attr == "momentary" {
                thisMemo.binaryKind = false
                thisMemo.momentaryKind = true
            }
        }
        memoStack.append(thisMemo)
    }
    
    func functionEnd() {
        // fill and pop
        let current = memoStack.removeLast()
        current.type = .FUNCTION
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children?.append(current) // ".last" is a getter
    }
    
    func numberStart() {
        // process number sub-element by adding to existing memo
        // next character content goes to the name of the most recent element
        currentTextState = .NUMBER
    }
    func numberEnd() {
        currentTextState = .NONE
    }

}

