import Foundation

struct SessionComposition {
    let childSelectionStore: ChildSelectionStore
    let classSelectionStore: ClassSelectionStore

    static func live() -> SessionComposition {
        SessionComposition(
            childSelectionStore: UserDefaultsChildSelectionStore(),
            classSelectionStore: UserDefaultsClassSelectionStore()
        )
    }
}
