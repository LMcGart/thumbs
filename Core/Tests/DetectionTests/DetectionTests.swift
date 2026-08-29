import Testing
@testable import Detection

@Test func moduleIsPresent() {
    #expect(Detection.moduleName == "Detection")
}
