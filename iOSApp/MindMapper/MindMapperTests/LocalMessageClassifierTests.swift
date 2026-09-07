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

    func test_scope_tripErrandWithShopURL_isInScope() {
        let verdict = LocalMessageClassifier.scopeVerdict(for: Self.bangladeshDressPlan)
        XCTAssertEqual(verdict, .inScope)
    }

    func test_intent_tripErrandWithShopURL_isStore() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(for: Self.bangladeshDressPlan),
            .store
        )
    }

    func test_scope_needToVisitWithoutPronoun_isInScope() {
        XCTAssertEqual(
            LocalMessageClassifier.scopeVerdict(
                for: "Need to visit this online store for a sharee"
            ),
            .inScope
        )
    }

    func test_intent_planURLQueryString_isStoreNotMixed() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "Need to visit this shop: https://example.com/share?mibextid=abc"
            ),
            .store
        )
    }

    func test_intent_realQuestionWithURL_isStillQuery() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "Where is my dress? See https://example.com?foo=1"
            ),
            .query
        )
    }

    func test_scope_bestTimeToVisit_isInScope() {
        XCTAssertEqual(
            LocalMessageClassifier.scopeVerdict(
                for: "What is the best time to visit Bangladesh?"
            ),
            .inScope
        )
    }

    func test_intent_bestTimeToVisit_isMixed() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "What is the best time to visit Bangladesh?"
            ),
            .mixed
        )
    }

    func test_intent_whatShouldIPack_isMixed() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "What should I pack for the trip?"
            ),
            .mixed
        )
    }

    func test_scope_projectDeadline_isInScope() {
        XCTAssertEqual(
            LocalMessageClassifier.scopeVerdict(
                for: "We decided the project ships in October"
            ),
            .inScope
        )
    }

    func test_intent_projectDecision_isStore() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "We decided the project ships in October"
            ),
            .store
        )
    }

    func test_intent_projectRecall_isNotBlocked() {
        XCTAssertEqual(
            LocalMessageClassifier.scopeVerdict(
                for: "What did we decide about the project deadline?"
            ),
            .inScope
        )
        let intent = LocalMessageClassifier.intentVerdict(
            for: "What did we decide about the project deadline?"
        )
        XCTAssertEqual(intent, .query)
    }

    func test_intent_whatsLeftOnProject_isQuery() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "What's left on the project?"
            ),
            .query
        )
    }

    func test_intent_whatIPlannedForBangladesh_isQuery() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "What things I planned to do when I will visit Bangladesh next year"
            ),
            .query
        )
    }

    func test_scope_birthdayGiftSuggestion_isInScope() {
        XCTAssertEqual(
            LocalMessageClassifier.scopeVerdict(
                for: "Suggests me some good birthday gift"
            ),
            .inScope
        )
    }

    func test_intent_birthdayGiftSuggestion_isMixed() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "Suggests me some good birthday gift"
            ),
            .mixed
        )
    }

    func test_scope_aseanBudgetTour_isInScope() {
        XCTAssertEqual(
            LocalMessageClassifier.scopeVerdict(
                for: "which Asean country good for budget friendly tour?"
            ),
            .inScope
        )
    }

    func test_intent_aseanBudgetTour_isMixed() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "which Asean country good for budget friendly tour?"
            ),
            .mixed
        )
    }

    func test_scope_facebookLinkRecall_isInScope() {
        XCTAssertEqual(
            LocalMessageClassifier.scopeVerdict(
                for: "Do you know the link of that facebook page?"
            ),
            .inScope
        )
    }

    func test_intent_facebookLinkRecall_isQuery() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "Do you know the link of that facebook page?"
            ),
            .query
        )
    }

    func test_scope_tryAgainFindTheLink_isInScope() {
        XCTAssertEqual(
            LocalMessageClassifier.scopeVerdict(
                for: "Try again and check if you can find the link"
            ),
            .inScope
        )
    }

    func test_intent_tryAgainFindTheLink_isQuery() {
        XCTAssertEqual(
            LocalMessageClassifier.intentVerdict(
                for: "Try again and check if you can find the link"
            ),
            .query
        )
    }

    func test_isFollowUpRecall_tryAgain_isTrue() {
        XCTAssertTrue(
            LocalMessageClassifier.isFollowUpRecall(
                "Try again and check if you can find the link"
            )
        )
        XCTAssertFalse(LocalMessageClassifier.isFollowUpRecall("Where is my passport?"))
    }

    private static let bangladeshDressPlan = """
        Need to visit vougue by prince outlet for Moushumy’s dress

        Also need to visit this online store for Sharee : https://www.facebook.com/share/r/1drnm7bd4K/?mibextid=wwXIfr
        """
}
