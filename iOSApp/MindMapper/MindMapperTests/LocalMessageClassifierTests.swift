import XCTest
@testable import MindMapper

final class LocalMessageClassifierTests: XCTestCase {

    func test_scope_waterBillExpense_isInScope() {
        let verdict = LocalMessageClassifier.scopeVerdict(
            for: "Need to add water bill in the Expense list"
        )
        XCTAssertEqual(verdict, .inScope)
    }

    func test_scope_homework_isOutOfScope() {
        let verdict = LocalMessageClassifier.scopeVerdict(
            for: "Can you write my homework essay?"
        )
        guard case .outOfScope = verdict else {
            return XCTFail("expected outOfScope, got \(String(describing: verdict))")
        }
    }

    func test_scope_ambiguous_returnsNil() {
        XCTAssertNil(LocalMessageClassifier.scopeVerdict(for: "Tell me more"))
    }

    func test_intent_waterBill_isStore() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "Need to add water bill in the Expense list"
            ),
            .store
        )
    }

    func test_intent_whereAreKeys_isQuery() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(for: "Where are my keys?"),
            .query
        )
    }

    func test_intent_thanks_isChat() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(for: "Thanks!"),
            .chat
        )
    }
}
