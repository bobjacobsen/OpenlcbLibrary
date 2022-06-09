import XCTest
@testable import OpenlcbLibrary

final class OpenlcbLibraryTests: XCTestCase {
    
    func testCanSetup() {
        let lib = OpenlcbLibrary()
        lib.configureCanTelnet()
        
        lib.createSampleData()
        
        // TODO: add tests of outcome, see also ProcessingAchitectureTest which does small parts
    }
    
}
