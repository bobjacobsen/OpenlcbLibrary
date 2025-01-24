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
        
        let result = CdiXmlMemo.process(data)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].children!.count, 1)
        
        XCTAssertEqual(result[0].children![0].type, .INPUT_INT)
        XCTAssertEqual(result[0].children![0].minValue, 15)
        XCTAssertEqual(result[0].children![0].maxValue, 20)
        XCTAssertEqual(result[0].children![0].defaultValue, 12)
    }
    
    func testFutureExpansion() throws {
        let data : Data = ("""
                            <cdi><someFutureElement size="12">
                            </someFutureElement></cdi>
                        """.data(using: .utf8))!
        
        let result = CdiXmlMemo.process(data)
        
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].children!.count, 1)
        
        XCTAssertEqual(result[0].children![0].type, .UNKNOWN_SIZED)
    }
    
    func testSeqmentOfIntElement() throws {
        let data : Data =  ("""
                        <cdi>
                            <segment space="21" origin="123">
                                <name>NameSeg</name>
                                <description>DescSeg</description>
                                <int>
                                    <name>Name</name>
                                    <description>Desc</description>
                                </int>
                            </segment>
                        </cdi>
                    """.data(using: .utf8))!
 
        let result = CdiXmlMemo.process(data)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].children!.count, 1)
        
        XCTAssertEqual(result[0].children![0].type, .SEGMENT)
        XCTAssertEqual(result[0].children![0].name, "NameSeg")
        XCTAssertEqual(result[0].children![0].description, "DescSeg")
        
        XCTAssertEqual(result[0].children![0].children!.count, 1)
        XCTAssertEqual(result[0].children![0].children![0].type, .INPUT_INT)
        XCTAssertEqual(result[0].children![0].children![0].space, 21)
        XCTAssertEqual(result[0].children![0].children![0].startAddress, 123)
        XCTAssertEqual(result[0].children![0].children![0].name, "Name")
        XCTAssertEqual(result[0].children![0].children![0].description, "Desc")
    }

    func testGroupOfIntElements() throws {
        let data : Data = ("""
                          <cdi>
                            <group>
                                <name>NameSeg</name>
                                <description>DescSeg</description>
                                <int size="2">
                                    <name>Name</name>
                                    <description>Desc</description>
                                </int>
                                <int>
                                </int>
                            </group>
                        </cdi>
                    """.data(using: .utf8))!
 
        let result = CdiXmlMemo.process(data)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].children!.count, 1)
        
        XCTAssertEqual(result[0].children![0].type, .GROUP)
        XCTAssertEqual(result[0].children![0].name, "NameSeg")
        XCTAssertEqual(result[0].children![0].description, "DescSeg")
        
        XCTAssertEqual(result[0].children![0].children!.count, 2)
        XCTAssertEqual(result[0].children![0].children![0].type, .INPUT_INT)
        XCTAssertEqual(result[0].children![0].children![0].name, "Name")
        XCTAssertEqual(result[0].children![0].children![0].description, "Desc")
        XCTAssertEqual(result[0].children![0].children![0].startAddress, 0)
        XCTAssertEqual(result[0].children![0].children![1].startAddress, 2)
    }

    func testGroupOfThreeElement() throws {
        let data : Data = ("""
                            <cdi><group>
                                <name>NameSeg</name>
                                <repname>RepNameSeg</repname>
                                <description>DescSeg</description>
                                <int size="2"><name>Name</name><description>Desc</description></int>"
                                <string size="3" offset="4"></string>
                                <eventid><name>NameE</name><description>DescE</description></eventid>
                            </group></cdi>
                        """.data(using: .utf8))!
 
        let result = CdiXmlMemo.process(data)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].children!.count, 1)
        
        XCTAssertEqual(result[0].children![0].type, .GROUP)
        XCTAssertEqual(result[0].children![0].name, "NameSeg")
        XCTAssertEqual(result[0].children![0].repname, "RepNameSeg")
        XCTAssertEqual(result[0].children![0].description, "DescSeg")
        
        XCTAssertEqual(result[0].children![0].children!.count, 3)
        
        XCTAssertEqual(result[0].children![0].children![0].type, .INPUT_INT)
        XCTAssertEqual(result[0].children![0].children![0].name, "Name")
        XCTAssertEqual(result[0].children![0].children![0].description, "Desc")
        XCTAssertEqual(result[0].children![0].children![0].startAddress, 0)

        XCTAssertEqual(result[0].children![0].children![1].type, .INPUT_STRING)
        XCTAssertEqual(result[0].children![0].children![1].name, "")
        XCTAssertEqual(result[0].children![0].children![1].description, "")
        XCTAssertEqual(result[0].children![0].children![1].startAddress, 6) // 2 plus 4 offset

        XCTAssertEqual(result[0].children![0].children![2].type, .INPUT_EVENTID)
        XCTAssertEqual(result[0].children![0].children![2].name, "NameE")
        XCTAssertEqual(result[0].children![0].children![2].description, "DescE")
        XCTAssertEqual(result[0].children![0].children![2].startAddress, 9)
    }

    func testTripleRepGroupOfTwoElement() throws {
        let data : Data = ("""
                            <cdi><group replication="3" offset="2">
                                    <name>NameGroup</name>
                                    <repname>Repl Name</repname>
                                    <description>DescGroup</description>
                                    <int>
                                        <name>Int Name</name>
                                        <description>Desc</description></int>"
                                    <string size="5"></string>
                            </group></cdi>
                        """.data(using: .utf8))!
 
        let result = CdiXmlMemo.process(data)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].children!.count, 1)
        
        XCTAssertEqual(result[0].children![0].type, .GROUP)
        XCTAssertEqual(result[0].children![0].name, "NameGroup")
        XCTAssertEqual(result[0].children![0].description, "DescGroup")
        
        XCTAssertEqual(result[0].children![0].children!.count, 3)
        
        XCTAssertEqual(result[0].children![0].children![0].type, .GROUP_REP) // three repl's under the group
        XCTAssertEqual(result[0].children![0].children![0].name, "Repl Name 1")  // created from replication name and
        XCTAssertEqual(result[0].children![0].children![1].type, .GROUP_REP)
        XCTAssertEqual(result[0].children![0].children![1].name, "Repl Name 2")  // created from replication name and
        XCTAssertEqual(result[0].children![0].children![2].type, .GROUP_REP)
        XCTAssertEqual(result[0].children![0].children![2].name, "Repl Name 3")  // created from replication name and

        
        XCTAssertEqual(result[0].children![0].children![0].children![0].type, .INPUT_INT) // each repl contains all elements
        XCTAssertEqual(result[0].children![0].children![0].children![0].startAddress, 2)
        XCTAssertEqual(result[0].children![0].children![0].children![0].name, "Int Name")  // created from replication name and number
        XCTAssertEqual(result[0].children![0].children![0].children![0].description, "Desc")
        XCTAssertEqual(result[0].children![0].children![0].children![1].type, .INPUT_STRING)
        XCTAssertEqual(result[0].children![0].children![0].children![1].startAddress, 3)
        XCTAssertEqual(result[0].children![0].children![0].children![1].name, "")
        XCTAssertEqual(result[0].children![0].children![0].children![1].description, "")

        XCTAssertEqual(result[0].children![0].children![1].children![0].type, .INPUT_INT) // each repl contains all elements
        XCTAssertEqual(result[0].children![0].children![1].children![0].startAddress, 8)
        XCTAssertEqual(result[0].children![0].children![1].children![0].name, "Int Name")
        XCTAssertEqual(result[0].children![0].children![1].children![0].description, "Desc")
        XCTAssertEqual(result[0].children![0].children![1].children![1].type, .INPUT_STRING)
        XCTAssertEqual(result[0].children![0].children![1].children![1].startAddress, 9)
        XCTAssertEqual(result[0].children![0].children![1].children![1].name, "")
        XCTAssertEqual(result[0].children![0].children![1].children![1].description, "")

        XCTAssertEqual(result[0].children![0].children![2].children![0].type, .INPUT_INT) // each repl contains all elements
        XCTAssertEqual(result[0].children![0].children![2].children![0].startAddress, 14)
        XCTAssertEqual(result[0].children![0].children![2].children![0].name, "Int Name")
        XCTAssertEqual(result[0].children![0].children![2].children![0].description, "Desc")
        XCTAssertEqual(result[0].children![0].children![2].children![1].type, .INPUT_STRING)
        XCTAssertEqual(result[0].children![0].children![2].children![1].startAddress, 15)
        XCTAssertEqual(result[0].children![0].children![2].children![1].name, "")
        XCTAssertEqual(result[0].children![0].children![2].children![1].description, "")

    }


    func testIntWithMap() throws {
        let data : Data = ("""
                            <cdi><segment>
                             <int size="1">
                               <name>the line state will be changed to.</name>
                               <default>0</default>
                               <map>
                                 <relation><property>0</property><value>None</value></relation>
                                 <relation><property>1</property><value>On</value></relation>
                                 <relation><property>2</property><value>Off</value></relation>
                                </map>
                             </int>
                            </segment></cdi>
                        """.data(using: .utf8))!
 
        let result = CdiXmlMemo.process(data)

        // check for content
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].children!.count, 1)
        
        XCTAssertEqual(result[0].children![0].type, .SEGMENT)
        XCTAssertEqual(result[0].children![0].children!.count, 1)
        
        XCTAssertEqual(result[0].children![0].children![0].type, .INPUT_INT)
        XCTAssertNil(result[0].children![0].children![0].children)
        XCTAssertEqual(result[0].children![0].children![0].properties, ["0", "1", "2"])
        XCTAssertEqual(result[0].children![0].children![0].values, ["None", "On", "Off"])

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

        let _ = CdiXmlMemo.process(data)

    }
    
    func testTwoRRCirKitsSegmentsSample() throws {
        _ = CdiSampleDataAccess.sampleCdiXmlData() // this does the parsing
    }
}
