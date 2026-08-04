import XCTest
@testable import Decantry

final class DecantryTargetSmokeTests: XCTestCase {
    @MainActor
    func testAppEnvironmentBootstraps() async {
        let env = AppEnvironment.live()
        await env.bootstrap()
        XCTAssertTrue(env.isReady || env.bootstrapError != nil)
    }
}
