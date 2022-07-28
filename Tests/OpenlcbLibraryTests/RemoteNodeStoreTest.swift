//
//  RemoteNodeStoreTest.swift
//  
//
//  Created by Bob Jacobsen on 6/10/22.
//

import XCTest
@testable import OpenlcbLibrary

class RemoteNodeStoreTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSimpleLoadStore() {
        var store = RemoteNodeStore(localNodeID: NodeID(1))
        
        let n12 = Node(NodeID(12))
        
        store.store(n12)
        store.store(Node(NodeID(13)))
        
        XCTAssertEqual(store.lookup(NodeID(12)), n12, "store then lookup OK")
    }

    func testRequestCreates() {
        var store = RemoteNodeStore(localNodeID: NodeID(1))
        
        let n12 = Node(NodeID(12))

        // try a load
        let temp = store.lookup(NodeID(12))
        
        XCTAssertEqual(temp, n12, "store then lookup OK")
    }

    func testAccessThroughLoadStoreByID() {
        var store = RemoteNodeStore(localNodeID: NodeID(1))
        
        let nid12 = NodeID(12)
        let nid13 = NodeID(13)

        let n12 = Node(nid12)
        let n13 = Node(nid13)

        store.store(n12)
        store.store(n13)
        
        // test ability to modify state
        n12.state = Node.State.Initialized
        XCTAssertEqual(n12.state, Node.State.Initialized, "local modification OK")
        XCTAssertEqual(store.lookup(nid12)!.state, Node.State.Initialized, "original in store modified")
        
        // lookup non-existing node creates it
        XCTAssertEqual(store.lookup(NodeID(21)), Node(NodeID(21)), "create on no match in store")
        
        let temp = store.lookup(nid13)
        temp!.state = Node.State.Uninitialized
        store.store(temp!)
        XCTAssertEqual(store.lookup(nid13)!.state, Node.State.Uninitialized, "original in store modified by replacement")

    }

    func testALocalStoreVeto() {
        let nid12 = NodeID(12)
        let n12 = Node(nid12)
        
        let nid13 = NodeID(13)
 
        var store = RemoteNodeStore(localNodeID: nid13)

        store.store(n12)
        
        // lookup non-existing node doesn't create it if in local store
        XCTAssertNil(store.lookup(nid13), "don't create if in local store")
    }

    func testCustomStringConvertible() { // existence test, don't check content which can change
        let store = RemoteNodeStore(localNodeID: NodeID(13))
        _ = store.description
    }

}
