//
//  LocalNodeStoreTest.swift
//
//  Created by Bob Jacobsen on 6/1/22.
//

import XCTest
@testable import OpenlcbLibrary

class LocalNodeStoreTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSimpleLoadStore() {
        let store = LocalNodeStore()
        
        let n12 = Node(NodeID(12))
        
        store.store(n12)
        store.store(Node(NodeID(13)))
        
        XCTAssertEqual(store.lookup(NodeID(12)), n12, "store then lookup OK")
        
        var array = store.asArray()
        array.sort() // so that test value is consistent
        
        XCTAssertEqual(array, [n12, Node(NodeID(13))])
    }

    func testAccessThroughLoadStoreByID() {
        let store = LocalNodeStore()
        
        let nid12 = NodeID(12)
        let nid13 = NodeID(13)

        let n12 = Node(nid12)
        let n13 = Node(nid13)

        XCTAssertFalse(store.isPresent(nid12))  // n12 not present yet
        
        store.store(n12)
        store.store(n13)
 
        XCTAssertTrue(store.isPresent(nid12))  // n12 present now
 
        // test ability to modify state
        n12.state = Node.State.Initialized
        XCTAssertEqual(n12.state, Node.State.Initialized, "local modification OK")
        XCTAssertEqual(store.lookup(nid12)!.state, Node.State.Initialized, "original in store modified")
        
        // lookup non-existing node leaves it uncreated
        XCTAssertNil(store.lookup(NodeID(21)), "no match in store")
        
        let temp = store.lookup(nid13)
        temp!.state = Node.State.Uninitialized
        store.store(temp!)
        XCTAssertEqual(store.lookup(nid13)!.state, Node.State.Uninitialized, "original in store modified by replacement")

    }

    func testAccessThroughLoadStoreByName() {
        let store = LocalNodeStore()
        
        let nid12 = NodeID(12)
        let nid13 = NodeID(13)

        let n12 = Node(nid12)
        n12.state = Node.State.Initialized
        n12.snip.userProvidedDescription = "N12"
        let n13 = Node(nid13)

        store.store(n12)
        store.store(n13)

        XCTAssertEqual(store.lookup(userProvidedDescription : "N12")!, n12, "retrieve original")
        XCTAssertEqual(store.lookup(userProvidedDescription : "foo"), nil, "no match")  // check Optional is nil on no match
     }
}
