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
        case INPUT_EVENTID
        case INPUT_INT
        case INPUT_STRING
        case MAP
    }
    // common values
    public var type : XMLMemoType
    public var name : String
    public var description : String
    // input values - usage determined by type
    public let length : Int
    public let startAddress : Int
    public var defaultValue : Int
    public var maxValue = 2_147_483_647  // 32 bit max
    public var minValue = 0
    
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
    
//    // init mainly for segment, group
//    init(_ type : XMLMemoType, _ name : String, _ description : String, children : [CdiXmlMemo] = []) {
//        self.type = type
//        self.name = name
//        self.description = description
//        self.length = 0
//        self.startAddress = 0
//        self.defaultValue = 0
//        self.currentValue = 0
//        self.children = children
//    }
//    // init mainly for input
//    init(_ type : XMLMemoType, _ name : String, _ description : String, length : Int, startAddress : Int, defaultValue : Int) {
//        self.type = type
//        self.name = name
//        self.description = description
//        self.length = length
//        self.startAddress = startAddress
//        self.defaultValue = defaultValue
//        self.currentValue = defaultValue
//        self.children = []
//    }
    // only for creating a null object
    init() {
        self.type = .TOPLEVEL
        self.name = ""
        self.description = ""
        self.length = 0
        self.startAddress = 0
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

public func sampleCdiXmlData() -> [CdiXmlMemo] {
    let data : Data = ("""
                    <cdi>
                    <segment>
                      <name>Power Monitor</name>
                        <eventid>
                         <name>Power OK</name>
                            <description>EventID</description>
                        </eventid>
                        <eventid>
                         <name>Power Not OK</name>
                            <description>EventID (may be lost)</description>
                        </eventid>
                    </segment>

                    <segment space='253' origin='128'>
                      <name>Port I/O</name>
                      <group replication="16">
                      <name>Select Input/Output line.</name>
                        <repname>Line</repname>
                        <group>
                          <name>I/O</name>
                          <string size="32">
                            <name>User ID</name>
                          </string>
                          <int size="1">
                            <name>Output Mode</name>
                            <default>0</default>
                               <map>
                                  <relation><property>0</property><value>None</value></relation>
                                  <relation><property>1</property><value>Steady</value></relation>
                                  <relation><property>2</property><value>Pulse</value></relation>
                                  <relation><property>3</property><value>Blink phase A</value></relation>
                                  <relation><property>4</property><value>Blink phase B</value></relation>
                               </map>
                          </int>
                          <int size='1'>
                            <name>Receiving the configured Command (C) event(s) will drive, pulse, or blink the line:</name>
                            <default>1</default>
                               <map>
                                  <relation><property>0</property><value>High (5V)</value></relation>
                                  <relation><property>1</property><value>Low (0V)</value></relation>
                               </map>
                          </int>
                          <int size="1">
                            <name>Input Mode</name>
                            <default>0</default>
                               <map>
                                  <relation><property>0</property><value>None</value></relation>
                                  <relation><property>1</property><value>Normal</value></relation>
                                  <relation><property>2</property><value>Alternate action</value></relation>
                               </map>
                          </int>
                          <int size='1'>
                            <name>The configured Indication (P) event(s) will be sent when the line is driven:</name>
                            <default>1</default>
                               <map>
                                  <relation><property>0</property><value>High (5V)</value></relation>
                                  <relation><property>1</property><value>Low (0V)</value></relation>
                               </map>
                          </int>
                          </group>
                          <group replication="2">
                            <name>Delay</name>
                            <description>Int 1 = Delay, Int 2 = Input hold time - Output length</description>
                            <repname>Interval</repname>
                            <int size="2">
                              <name />
                              <description>Delay Time (1-60000).</description>
                              <min>0</min>
                              <max>60000</max>
                            </int>
                            <int size="1">
                              <name />
                              <map>
                              <default>0</default>
                                <relation><property>0</property><value>Milliseconds</value></relation>
                                <relation><property>1</property><value>Seconds</value></relation>
                                <relation><property>2</property><value>Minutes</value></relation>
                              </map>
                            </int>
                            <int size="1">
                              <name>Retrigger</name>
                              <map>
                                <relation><property>0</property><value>No</value></relation>
                                <relation><property>1</property><value>Yes</value></relation>
                              </map>
                            </int>
                          </group>
                          <group replication="6">
                            <name>Commands</name>
                            <description>Consumer commands.</description>
                            <repname>Event</repname>
                            <eventid>
                              <description>(C) When this event occurs,</description>
                            </eventid>
                            <int size="1">
                              <name>the line state will be changed to.</name>
                              <default>0</default>
                              <map>
                                <relation><property>0</property><value>None</value></relation>
                                <relation><property>1</property><value>On  (Line Active)</value></relation>
                                <relation><property>2</property><value>Off (Line Inactive)</value></relation>
                                <relation><property>3</property><value>Change (Toggle)</value></relation>
                                <relation><property>4</property><value>Veto On  (Active)</value></relation>
                                <relation><property>5</property><value>Veto Off (Inactive)</value></relation>
                                <relation><property>6</property><value>Gated On  (Non Veto Output)</value></relation>
                                <relation><property>7</property><value>Gated Off (Non Veto Output)</value></relation>
                                <relation><property>8</property><value>Gated Change (Non Veto Toggle)</value></relation>
                              </map>
                            </int>
                          </group>
                          <group replication="6">
                            <name>Indications</name>
                            <description>Producer commands.</description>
                            <repname>Event</repname>
                            <int size="1">
                              <name>Upon this action</name>
                              <name>Triggers</name>
                              <default>0</default>
                              <map>
                                <relation><property>0</property><value>None</value></relation>
                                <relation><property>1</property><value>Output State On command</value></relation>
                                <relation><property>2</property><value>Output State Off command</value></relation>
                                <relation><property>3</property><value>Output On (Function hi)</value></relation>
                                <relation><property>4</property><value>Output Off (Function lo)</value></relation>
                                <relation><property>5</property><value>Input On</value></relation>
                                <relation><property>6</property><value>Input Off</value></relation>
                                <relation><property>7</property><value>Gated On (Not Veto Input)</value></relation>
                                <relation><property>8</property><value>Gated Off (Not Veto Input)</value></relation>
                              </map>
                            </int>
                            <eventid>
                              <description>(P) this event will be sent.</description>
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
    }
    func segmentEnd() {
        // TODO: fill and pop
        let current = memoStack.removeLast()
        current.type = .SEGMENT
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children?.append(current) // ".last" is a getter
    }

    func groupStart() {
        memoStack.append(CdiXmlMemo())
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
        let current = memoStack.removeLast()
        current.type = .INPUT_INT
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children?.append(current) // ".last" is a getter
        // no children in current node
        current.children = nil
    }

    func eventIdStart(attributes : [String:String]) {
        memoStack.append(CdiXmlMemo())
    }
    func eventIdEnd()  {
        let current = memoStack.removeLast()
        current.type = .INPUT_EVENTID
        // add to children of parent (now last on stack)
        memoStack[memoStack.count-1].children?.append(current) // ".last" is a getter
        current.children = nil
    }

    func stringStart(attributes : [String:String]) {
        memoStack.append(CdiXmlMemo())
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
