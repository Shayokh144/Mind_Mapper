import XCTest
@testable import MindMapper

final class MemoryLinkPreserverTests: XCTestCase {
    private let facebookURL =
        "https://www.facebook.com/share/r/1drnm7bd4K/?mibextid=wwXIfr"

    func test_mergingLinks_appendsURLWhenCleanTextDroppedIt() {
        let raw = "Need to visit this online store for Sharee : \(facebookURL)"
        let clean = "User plans to visit a Facebook online store for a Sharee"
        let merged = MemoryLinkPreserver.mergingLinks(from: raw, into: clean)
        XCTAssertTrue(merged.contains("Sharee"))
        XCTAssertTrue(merged.contains(facebookURL))
    }

    func test_mergingLinks_doesNotDuplicateURLAlreadyPresent() {
        let raw = "Store this \(facebookURL) please"
        let clean = "Visit \(facebookURL) for a Sharee"
        let merged = MemoryLinkPreserver.mergingLinks(from: raw, into: clean)
        XCTAssertEqual(merged.components(separatedBy: facebookURL).count - 1, 1)
    }

    func test_mergingLinks_keepsLocalFilePath() {
        let path = "/Users/nimble/Documents/sharee-order.pdf"
        let merged = MemoryLinkPreserver.mergingLinks(
            from: "The order PDF is at \(path)",
            into: "The Sharee order PDF is saved locally"
        )
        XCTAssertTrue(merged.contains(path))
    }

    func test_mergingLinks_noOpWhenNoLinks() {
        let clean = "Blue T-shirt is in the 3rd drawer"
        XCTAssertEqual(
            MemoryLinkPreserver.mergingLinks(from: "I put my blue T-shirt in the 3rd drawer", into: clean),
            clean
        )
    }

    func test_links_stripsTrailingPeriod() {
        let links = MemoryLinkPreserver.links(in: "See https://example.com/shop.")
        XCTAssertEqual(links, ["https://example.com/shop"])
    }

    func test_preservingLinks_addsURLEntity() {
        let result = ExtractionResult(
            cleanText: "Visit a Facebook store for a Sharee",
            entities: [.init(type: "product", value: "Sharee")],
            supersedesHint: nil
        ).preservingLinks(from: "Need this store \(facebookURL)")
        XCTAssertTrue(result.cleanText.contains(facebookURL))
        XCTAssertTrue(result.entities.contains { $0.type == "url" && $0.value == facebookURL })
        XCTAssertTrue(result.entities.contains { $0.type == "product" && $0.value == "Sharee" })
    }
}
