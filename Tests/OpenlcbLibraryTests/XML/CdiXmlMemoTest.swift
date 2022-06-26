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
        // and post-process
        processGroupReplication(delegate.memoStack[0])

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
        // and post-process
        processGroupReplication(delegate.memoStack[0])

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
        // and post-process
        processGroupReplication(delegate.memoStack[0])

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
        // and post-process
        processGroupReplication(delegate.memoStack[0])

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
                            <cdi><group>
                                <name>NameSeg</name>
                                <repname>RepNameSeg</repname>
                                <description>DescSeg</description>
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
        // and post-process
        processGroupReplication(delegate.memoStack[0])
        
        XCTAssertEqual(delegate.memoStack.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children!.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children![0].type, .GROUP)
        XCTAssertEqual(delegate.memoStack[0].children![0].name, "NameSeg")
        XCTAssertEqual(delegate.memoStack[0].children![0].repname, "RepNameSeg")
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

    func testTripleRepGroupOfTwoElement() throws {
        let data : Data = ("""
                            <cdi><group replication="3">
                                    <name>NameGroup</name>
                                    <repname>Repl Name</repname>
                                    <description>DescGroup</description>
                                    <int>
                                        <name>Int Name</name>
                                        <description>Desc</description></int>"
                                    <string></string>
                            </group></cdi>
                        """.data(using: .utf8))!
 
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate

        // run the parser
        parser.parse()
        // and post-process
        processGroupReplication(delegate.memoStack[0])

        XCTAssertEqual(delegate.memoStack.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children!.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children![0].type, .GROUP)
        XCTAssertEqual(delegate.memoStack[0].children![0].name, "NameGroup")
        XCTAssertEqual(delegate.memoStack[0].children![0].description, "DescGroup")
        
        XCTAssertEqual(delegate.memoStack[0].children![0].children!.count, 3)
        
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].type, .GROUP_REP) // three repl's under the group
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].name, "Repl Name 1")  // created from replication name and
        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].type, .GROUP_REP)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].name, "Repl Name 2")  // created from replication name and
        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].type, .GROUP_REP)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].name, "Repl Name 3")  // created from replication name and

        
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].children![0].type, .INPUT_INT) // each repl contains all elements
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].children![0].name, "Int Name")  // created from replication name and number
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].children![0].description, "Desc")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].children![1].type, .INPUT_STRING)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].children![1].name, "")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].children![1].description, "")

        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].children![0].type, .INPUT_INT) // each repl contains all elements
        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].children![0].name, "Int Name")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].children![0].description, "Desc")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].children![1].type, .INPUT_STRING)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].children![1].name, "")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![1].children![1].description, "")

        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].children![0].type, .INPUT_INT) // each repl contains all elements
        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].children![0].name, "Int Name")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].children![0].description, "Desc")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].children![1].type, .INPUT_STRING)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].children![1].name, "")
        XCTAssertEqual(delegate.memoStack[0].children![0].children![2].children![1].description, "")

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
 
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        let delegate = CdiParserDelegate()
        parser.delegate = delegate

        // run the parser
        parser.parse()
        // and post-process
        processGroupReplication(delegate.memoStack[0])

        // check for content
        XCTAssertEqual(delegate.memoStack.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children!.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children![0].type, .SEGMENT)
        XCTAssertEqual(delegate.memoStack[0].children![0].children!.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].type, .INPUT_INT)
        XCTAssertNil(delegate.memoStack[0].children![0].children![0].children)
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].properties, ["0", "1", "2"])
        XCTAssertEqual(delegate.memoStack[0].children![0].children![0].values, ["None", "On", "Off"])

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
        // and post-process
        processGroupReplication(delegate.memoStack[0])
    }
    
    func testTwoRRCirKitsSegmentsSample() throws {
        _ = sampleCdiXmlData() // this does the parsing
    }
}
