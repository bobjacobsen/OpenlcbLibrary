//
//  NodeTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class NodeTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testContents() throws {
        let nid12 = NodeID(12)
 
        let n12 = Node(nid12)
        
        n12.state = Node.State.Initialized
        XCTAssertEqual(n12.state, Node.State.Initialized)
 
    }

    func testDescription() {
        let nid = NodeID(0x0A0B0C0D0E0F)
        XCTAssertEqual(Node(nid).description, "Node (NodeID 0A.0B.0C.0D.0E.0F)")
    }
    
    func testName() {
        let nid = NodeID(0x0A0B0C0D0E0F)
        let node = Node(nid)
        node.snip.userProvidedNodeName = "test 123"
        XCTAssertEqual(node.name, "test 123")
    }

    func testEquatable() {
        let nid12 = NodeID(12)
        let n12 = Node(nid12)
        n12.state = Node.State.Initialized // should not affect equality
        
        let nid12a = NodeID(12)
        let n12a = Node(nid12a)
        
        let nid13 = NodeID(13)
        let n13 = Node(nid13)
        

        XCTAssertEqual(n12, n12a)
        XCTAssertNotEqual(n12, n13)
    }

    func testComparable() {
        let nid12 = NodeID(12)
        let n12 = Node(nid12)
        n12.state = Node.State.Initialized // should not affect comparison
        
        let nid13 = NodeID(13)
        let n13 = Node(nid13)
        
        XCTAssertFalse(n12 < n12)
        XCTAssertFalse(n12 > n12)

        XCTAssertFalse(n13 < n12)
        XCTAssertTrue(n12 < n13)

    }

    func testHash() {
        let nid12 = NodeID(12)
        let n12 = Node(nid12)
        n12.state = Node.State.Initialized // should not affect equality
        
        let nid12a = NodeID(12)
        let n12a = Node(nid12a)
        
        let nid13 = NodeID(13)
        let n13 = Node(nid13)
 
        let testSet = Set([n12, n12a, n13])
        XCTAssertEqual(testSet, Set([n12, n13]))
    }

    func testPipSet() {
        let n12 = Node(NodeID(12))
        
        XCTAssertEqual(n12.pipSet, Set<PIP>())

        n12.pipSet.insert(PIP.DISPLAY_PROTOCOL)
        
        XCTAssertEqual(n12.pipSet, Set<PIP>([PIP.DISPLAY_PROTOCOL]))
        
        XCTAssertTrue(n12.pipSet.contains(PIP.DISPLAY_PROTOCOL))
        XCTAssertFalse(n12.pipSet.contains(PIP.STREAM_PROTOCOL))

    }
    
    func testConvenienceCtors() {
        let pipSet = Set([PIP.DISPLAY_PROTOCOL])
        let n1 = Node(NodeID(12), pip: pipSet)
        XCTAssertTrue(n1.pipSet.contains(PIP.DISPLAY_PROTOCOL))
        
        var snip = SNIP()
        snip.modelName = "modelX"
        let n2 = Node(NodeID(13), snip: snip)
        XCTAssertTrue(n2.snip.modelName == "modelX")
    }
}
