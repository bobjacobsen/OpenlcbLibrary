//
//  CdiXmlMemoTest.swift
//  
//
//  Created by Bob Jacobsen on 6/19/22.
//

import XCTest
@testable import OpenlcbLibrary

class CdiXmlMemoTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testStringElementFromFile() throws {
        #if os(macOS)  // file access only works on macOS due to file location?
        // set up the same file
        let file = "tower-lcc-cdi.xml" //this is the file we will read from in ~/Documents
        let data = getDataFromFile(file)
        print (data as Any)

        let parser = XMLParser(data: data!)
        print (parser)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate

        // run the parser
        parser.parse()

        // print (delegate.memoStack)
        #endif
    }

    func testIntElement() throws {
        let data : Data = ("""
                            <cdi><int>
                                <default>12</default>
                                <name>Name</name>
                                <description>Desc</description>
                                <min>15</min>
                                <max>20</max>
                            </int></cdi>
                        """.data(using: .utf8))!
 
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate

        // run the parser
        parser.parse()

        XCTAssertEqual(delegate.memoStack.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children!.count, 1)

        XCTAssertEqual(delegate.memoStack[0].children![0].type, .INPUT_INT)
        XCTAssertEqual(delegate.memoStack[0].children![0].minValue, 15)
        XCTAssertEqual(delegate.memoStack[0].children![0].maxValue, 20)
        XCTAssertEqual(delegate.memoStack[0].children![0].defaultValue, 12)
    }

    func testSeqmentOfIntElement() throws {
        let data : Data = ("<cdi><segment><name>NameSeg</name><description>DescSeg</description><int><name>Name</name><description>Desc</description></int></segment></cdi>".data(using: .utf8))!
 
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate

        // run the parser
        parser.parse()

        XCTAssertEqual(delegate.memoStack.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children!.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children![0].type, .SEGMENT)
        XCTAssertEqual(delegate.memoStack[0].children![0].name, "NameSeg")
        XCTAssertEqual(delegate.memoStack[0].children![0].description, "DescSeg")
        
        XCTAssertEqual(delegate.memoStack[0].children![0].children!.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].type, .INPUT_INT)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].name, "Name")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].description, "Desc")
    }

    func testGroupOfIntElement() throws {
        let data : Data = ("<cdi><group><name>NameSeg</name><description>DescSeg</description><int><name>Name</name><description>Desc</description></int></group></cdi>".data(using: .utf8))!
 
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate

        // run the parser
        parser.parse()

        XCTAssertEqual(delegate.memoStack.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children!.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children![0].type, .GROUP)
        XCTAssertEqual(delegate.memoStack[0].children![0].name, "NameSeg")
        XCTAssertEqual(delegate.memoStack[0].children![0].description, "DescSeg")
        
        XCTAssertEqual(delegate.memoStack[0].children![0].children!.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].type, .INPUT_INT)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].name, "Name")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].description, "Desc")
    }

    func testGroupOfThreeElement() throws {
        let data : Data = ("""
                            <cdi><group><name>NameSeg</name><description>DescSeg</description>
                                <int><name>Name</name><description>Desc</description></int>"
                                <string></string>
                                <eventid><name>NameE</name><description>DescE</description></eventid>
                            </group></cdi>
                        """.data(using: .utf8))!
 
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate

        // run the parser
        parser.parse()

        XCTAssertEqual(delegate.memoStack.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children!.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children![0].type, .GROUP)
        XCTAssertEqual(delegate.memoStack[0].children![0].name, "NameSeg")
        XCTAssertEqual(delegate.memoStack[0].children![0].description, "DescSeg")
        
        XCTAssertEqual(delegate.memoStack[0].children![0].children!.count, 3)
        
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].type, .INPUT_INT)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].name, "Name")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].description, "Desc")

        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].type, .INPUT_STRING)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].name, "")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].description, "")

        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].type, .INPUT_EVENTID)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].name, "NameE")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].description, "DescE")
    }

    
    func testOneRRCirKitsSegment() throws {
        let data : Data = ("""
                            <cdi><segment>
                              <name>Power Monitor</name>
                                <eventid>
                                 <name>Power OK</name>
                                    <description>EventID</description>
                                </eventid>
                                <eventid>
                                 <name>Power Not OK</name>
                                    <description>EventID (may be lost)</description>
                                </eventid>
                            </segment></cdi>
                        """.data(using: .utf8))!
 
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate

        // run the parser
        parser.parse()
    }
    
    func testTwoRRCirKitsSegments() throws {
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
    }
}
