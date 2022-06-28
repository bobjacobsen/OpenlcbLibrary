//
//  CdiXmlMemo.swift
//  
//
//  Created by Bob Jacobsen on 6/19/22.
//

/// Representation of a CDI XML node
///
import Foundation

public final class CdiXmlMemo : Identifiable {
    public enum XMLMemoType {
        case TOPLEVEL // cdi element itself
        case SEGMENT  // Segment is a top-level group
        case GROUP
        case GROUP_REP // child of group for replications > 1
        case INPUT_EVENTID
        case INPUT_INT
        case INPUT_STRING
        case MAP
    }
    // common values
    public var type : XMLMemoType
    public var name : String
    public var repname : String
    public var description : String
    // input values - usage determined by type
    public var length : Int
    public var offset : Int                 // initial offset from the CDI
    public var space : Int
    
    public var defaultValue : Int
    public var maxValue = 2_147_483_647     // 32 bit max
    public var minValue = 0
    
    public var startAddress : Int // set on segment element, otherwise computed

    public var currentValue : Int
    
    public var children : [CdiXmlMemo]? // Optional required to display in SwiftUI?  Never nil here.
    
    public var properties : [String] = []
    public var values : [String] = []
    
    public let id = UUID()
    
    // TODO: needs map support
    // TODO: ACDI expansion
    // TODO: memory address computation
    // TODO: group repl
    // TODO: How to handle the identification block?  Present or not? Read-only
    
    // copy ctor
    init(_ memo : CdiXmlMemo) {
        self.type = memo.type
        self.name = memo.name
        self.repname = memo.repname
        self.description = memo.description
        self.length = memo.length
        self.offset = memo.offset
        self.space = memo.space
        self.startAddress = memo.startAddress
        self.defaultValue = memo.defaultValue
        self.currentValue = memo.currentValue
        // make a recursive deep copy of memo.children
        self.children = nil
        if let children = memo.children {
            self.children = []
            for child in children {
                self.children!.append(CdiXmlMemo(child))
            }
        }

        
    }

    // only for creating a null object
    init() {
        self.type = .TOPLEVEL
        self.name = ""
        self.repname = ""
        self.description = ""
        self.length = 0
        self.offset = 0
        self.startAddress = 0
        self.space = 0
        self.defaultValue = 0
        self.currentValue = 0
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
        return data
    } catch {
        print ("caught \(error)")
        return nil
    }
}

// recurse through the Mmeo tree to expand group(replication>1) -> group with
public func processGroupReplication(_ memo : CdiXmlMemo) {
    if memo.type == .GROUP  && memo.length > 1 { // length holds replication count
        // here, replication is required
        // copy the current node to get children, etc,
        let newChildNode = CdiXmlMemo(memo) // includes making a deep copy
        newChildNode.type = .GROUP_REP // this will be the master that's copied for the new childen

        // drop children in prior memo
        memo.children = []  // clears old elements (int, event, even group) that are now in new sub-elements

        // add repl nodes as children of original
        for i in 1...memo.length {
            let tempChildNode = CdiXmlMemo(newChildNode)  // create a new, to-be child node
            tempChildNode.name = memo.repname+" \(i)"
            memo.children?.append(tempChildNode)
        }
    }
    // done if needed here, descend into children (including the new .GROUP_REP nodes)
    if let children = memo.children {
        for child in children {
            processGroupReplication(child)
        }
    }
}

// Recursively scan the tree (depth first) assigning starting addresses.
// Assumes that group expansion has already taken place (or won't be done)
public func computeMemoryLocations(_ memo : CdiXmlMemo, space : Int, endAddress : Int) -> Int {  // returns endAddress of entire memo subtree
    var nextSpace = space
    var newEndAddress = endAddress
    
    if memo.type == .SEGMENT {
        nextSpace = memo.space
        newEndAddress = memo.startAddress
    } else {
        memo.startAddress = endAddress+memo.offset
        newEndAddress = memo.startAddress+memo.length
    }
    memo.space = nextSpace
    // descend into children (including the new .GROUP_REP nodes)
    if let children = memo.children {
        for child in children {
            newEndAddress = computeMemoryLocations(child, space: nextSpace, endAddress: newEndAddress)
        }
    }
    return newEndAddress
}


public func sampleCdiXmlData() -> [CdiXmlMemo] {
    let data : Data = ("""
                    <cdi>
                    <segment><name>Sample Segment</name><description>Desc of Segment</description>
                        <group><name>Sample Group</name><description>Desc of Group</description>
                        <int><name>Numeric Int</name><description>Description of Num Int</description><default>321</default></int>
                        <int><name>Mapped Int</name><description>Description of Map Int</description><default>2</default>
                            <map>
                                <relation><property>1</property><value>One</value></relation>
                                <relation><property>2</property><value>Two</value></relation>
                                <relation><property>3</property><value>Three</value></relation>
                            </map></int>
                        </group>
                    </segment>
                    
                    <segment space="253" origin="7744">
                      <name>Node Power Monitor</name>
                      <int size="1">
                        <name>Message Options</name>
                        <map>
                          <relation>
                            <property>0</property>
                            <value>None</value>
                          </relation>
                          <relation>
                            <property>1</property>
                            <value>Send Power OK only</value>
                          </relation>
                          <relation>
                            <property>2</property>
                            <value>Send both Power OK and Power Not OK</value>
                          </relation>
                        </map>
                      </int>
                      <eventid>
                        <name>Power OK</name>
                        <description>EventID</description>
                      </eventid>
                      <eventid>
                        <name>Power Not OK</name>
                        <description>EventID (may be lost)</description>
                      </eventid>
                    </segment>
                    <segment space="253" origin="128">
                      <name>Port I/O</name>
                      <group replication="16">
                        <name>Line</name>
                        <description>Select Input/Output line.</description>
                        <repname>Line</repname>
                        <string size="32">
                          <name>Line Description</name>
                        </string>
                        <int size="1" offset="11424">
                          <name>Output Function</name>
                          <map>
                            <relation>
                              <property>0</property>
                              <value>None</value>
                            </relation>
                            <relation>
                              <property>1</property>
                              <value>Steady</value>
                            </relation>
                            <relation>
                              <property>2</property>
                              <value>Pulse</value>
                            </relation>
                            <relation>
                              <property>3</property>
                              <value>Blink A</value>
                            </relation>
                            <relation>
                              <property>4</property>
                              <value>Blink B</value>
                            </relation>
                          </map>
                        </int>
                        <int size="1">
                          <name>Receiving the configured Command (C) event(s) will drive or pulse the line:</name>
                          <map>
                            <relation>
                              <property>0</property>
                              <value>Low  (0V)</value>
                            </relation>
                            <relation>
                              <property>1</property>
                              <value>High (5V)</value>
                            </relation>
                          </map>
                        </int>
                        <int size="1">
                          <name>Input Function</name>
                          <map>
                            <relation>
                              <property>0</property>
                              <value>None</value>
                            </relation>
                            <relation>
                              <property>1</property>
                              <value>Normal</value>
                            </relation>
                            <relation>
                              <property>2</property>
                              <value>Alternating</value>
                            </relation>
                          </map>
                        </int>
                        <int size="1">
                          <name>The configured Indication (P) event(s) will be sent when the line is driven:</name>
                          <map>
                            <relation>
                              <property>0</property>
                              <value>Low  (0V)</value>
                            </relation>
                            <relation>
                              <property>1</property>
                              <value>High (5V)</value>
                            </relation>
                          </map>
                        </int>
                        <group replication="2" offset="-11426">
                          <name>Delay</name>
                          <description>Delay time values for blinks, pulses, debounce.</description>
                          <repname>Interval</repname>
                          <int size="2">
                            <name>Delay Time (1-60000)</name>
                          </int>
                          <int size="1">
                            <name>Units</name>
                            <map>
                              <relation>
                                <property>0</property>
                                <value>Milliseconds</value>
                              </relation>
                              <relation>
                                <property>1</property>
                                <value>Seconds</value>
                              </relation>
                              <relation>
                                <property>2</property>
                                <value>Minutes</value>
                              </relation>
                            </map>
                          </int>
                          <int size="1">
                            <name>Retrigger</name>
                            <map>
                              <relation>
                                <property>0</property>
                                <value>No</value>
                              </relation>
                              <relation>
                                <property>1</property>
                                <value>Yes</value>
                              </relation>
                            </map>
                          </int>
                        </group>
                        <group replication="6">
                          <name>Event</name>
                          <repname>Event</repname>
                          <eventid>
                            <name>Command</name>
                            <description>(C) When this event occurs</description>
                          </eventid>
                          <int size="1">
                            <name>Action</name>
                            <description>the line state will be changed to</description>
                            <map>
                              <relation>
                                <property>0</property>
                                <value>None</value>
                              </relation>
                              <relation>
                                <property>1</property>
                                <value>On  (Line Active)</value>
                              </relation>
                              <relation>
                                <property>2</property>
                                <value>Off (Line Inactive)</value>
                              </relation>
                              <relation>
                                <property>3</property>
                                <value>Change (Toggle)</value>
                              </relation>
                              <relation>
                                <property>4</property>
                                <value>Veto On  (Active)</value>
                              </relation>
                              <relation>
                                <property>5</property>
                                <value>Veto Off (Inactive)</value>
                              </relation>
                              <relation>
                                <property>6</property>
                                <value>Gated On  (Non Veto Output)</value>
                              </relation>
                              <relation>
                                <property>7</property>
                                <value>Gated Off (Non Veto Output)</value>
                              </relation>
                              <relation>
                                <property>8</property>
                                <value>Gated Change (Non Veto Toggle)</value>
                              </relation>
                            </map>
                          </int>
                        </group>
                        <group replication="6">
                          <name>Event</name>
                          <repname>Event</repname>
                          <int size="1">
                            <name>Upon this action</name>
                            <map>
                              <relation>
                                <property>0</property>
                                <value>None</value>
                              </relation>
                              <relation>
                                <property>1</property>
                                <value>Output State On command</value>
                              </relation>
                              <relation>
                                <property>2</property>
                                <value>Output State Off command</value>
                              </relation>
                              <relation>
                                <property>3</property>
                                <value>Output On (Function hi)</value>
                              </relation>
                              <relation>
                                <property>4</property>
                                <value>Output Off (Function lo)</value>
                              </relation>
                              <relation>
                                <property>5</property>
                                <value>Input On</value>
                              </relation>
                              <relation>
                                <property>6</property>
                                <value>Input Off</value>
                              </relation>
                              <relation>
                                <property>7</property>
                                <value>Gated On (Non Veto Input)</value>
                              </relation>
                              <relation>
                                <property>8</property>
                                <value>Gated Off (Non Veto Input)</value>
                              </relation>
                            </map>
                          </int>
                          <eventid>
                            <name>Indicator</name>
                            <description>(P) this event will be sent</description>
                          </eventid>
                        </group>
                      </group>
                    </segment>
                    </cdi>
                    """.data(using: .utf8))!

    let parser = XMLParser(data: data)
    parser.shouldResolveExternalEntities = false
    let delegate = CdiParserDelegate()
    parser.delegate = delegate

    // run the parser
    parser.parse()

    return delegate.memoStack[0].children!
}

final class CdiParserDelegate : NSObject, XMLParserDelegate {
    // MARK: Delegate methods
    func parserDidStartDocument(_ parser : XMLParser) {
    }
    func parserDidEndDocument(_ parser : XMLParser) {
        print ("parserDidEndDocument")
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
            memoStack[memoStack.count-1].currentValue = memoStack[memoStack.count-1].defaultValue
        case .MIN :
            memoStack[memoStack.count-1].minValue = Int(foundCharacters) ?? 0
        case .MAX :
            memoStack[memoStack.count-1].maxValue = Int(foundCharacters) ?? 2_147_483_647  // 32 bit max
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
        // TODO: add standard-defined ACDI contents
    }
    func acdiEnd() {
    }

    func identificationStart() {
        // TODO: add standard-defined Identification contents
    }
    func identificationEnd() {
    }

    func segmentStart(attributes : [String:String]) {
        let thisMemo = CdiXmlMemo()
        thisMemo.type = .SEGMENT
        thisMemo.space = 0 // TODO: Is this the right default? Check CDI definition
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
        // TODO: fill and pop
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
        // TODO: fill and pop
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
        if let attr = attributes["length"] {
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
        if let attr = attributes["length"] {
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
