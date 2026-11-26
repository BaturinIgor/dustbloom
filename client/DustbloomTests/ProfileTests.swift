import XCTest
@testable import Dustbloom

final class ProfileTests: XCTestCase {
    func testNameRules() {
        XCTAssertEqual(Profile.validName("  Игорь  "), "Игорь")
        XCTAssertEqual(Profile.validName("Farmer_42"), "Farmer_42")
        XCTAssertNil(Profile.validName("ab"))
        XCTAssertNil(Profile.validName(String(repeating: "a", count: 17)))
        XCTAssertNil(Profile.validName("1234"))       // needs a letter
        XCTAssertNil(Profile.validName("hi<script>"))  // symbols
    }

    func testAvatarUnlocks() {
        XCTAssertTrue(Profile.isUnlocked(avatar: 0, level: 1))
        XCTAssertFalse(Profile.isUnlocked(avatar: 8, level: 9))
        XCTAssertTrue(Profile.isUnlocked(avatar: 8, level: 10))
        XCTAssertFalse(Profile.isUnlocked(avatar: 99, level: 99))
    }
}
