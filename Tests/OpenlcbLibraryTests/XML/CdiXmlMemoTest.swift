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

        print (delegate.memoStack)
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
        XCTAssertEqual(delegate.memoStack[0].children.count, 1)
        var testMemo = CdiXmlMemo(.INPUT_INT, "Name", "Desc")
        testMemo.defaultValue = 12
        testMemo.minValue = 15
        testMemo.maxValue = 20
        XCTAssertEqual(delegate.memoStack[0].children[0], testMemo)
        XCTAssertEqual(delegate.memoStack[0].children[0].defaultValue, 12)

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
        XCTAssertEqual(delegate.memoStack[0].children.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children[0].type, .SEGMENT)
        XCTAssertEqual(delegate.memoStack[0].children[0].name, "NameSeg")
        XCTAssertEqual(delegate.memoStack[0].children[0].description, "DescSeg")
        
        XCTAssertEqual(delegate.memoStack[0].children[0].children.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children[0].children[0], CdiXmlMemo(.INPUT_INT, "Name", "Desc"))
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
        XCTAssertEqual(delegate.memoStack[0].children.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children[0].type, .GROUP)
        XCTAssertEqual(delegate.memoStack[0].children[0].name, "NameSeg")
        XCTAssertEqual(delegate.memoStack[0].children[0].description, "DescSeg")
        
        XCTAssertEqual(delegate.memoStack[0].children[0].children.count, 1)
        XCTAssertEqual(delegate.memoStack[0].children[0].children[0], CdiXmlMemo(.INPUT_INT, "Name", "Desc"))
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
        XCTAssertEqual(delegate.memoStack[0].children.count, 1)
        
        XCTAssertEqual(delegate.memoStack[0].children[0].type, .GROUP)
        XCTAssertEqual(delegate.memoStack[0].children[0].name, "NameSeg")
        XCTAssertEqual(delegate.memoStack[0].children[0].description, "DescSeg")
        
        XCTAssertEqual(delegate.memoStack[0].children[0].children.count, 3)
        XCTAssertEqual(delegate.memoStack[0].children[0].children[0], CdiXmlMemo(.INPUT_INT, "Name", "Desc"))
        XCTAssertEqual(delegate.memoStack[0].children[0].children[1], CdiXmlMemo(.INPUT_STRING, "", ""))
        XCTAssertEqual(delegate.memoStack[0].children[0].children[2], CdiXmlMemo(.INPUT_EVENTID, "NameE", "DescE"))
    }

}
