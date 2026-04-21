import Foundation
import Testing
@testable import UIMole

@MainActor
struct HomeViewModelTests {

    @Test
    func exposesExpectedMenuItemsInOrder() {
        let sut = DefaultHomeViewModel()

        let ids = sut.menuItems.map(\.id)

        #expect(ids == [.clean, .uninstall, .optimize, .analyze, .status, .settings])
    }

    @Test
    func onlyImplementedDestinationsAreEnabled() {
        let sut = DefaultHomeViewModel()

        let enabledIDs = sut.menuItems
            .filter(\.isEnabled)
            .map(\.id)

        #expect(Set(enabledIDs) == [.status, .analyze, .uninstall, .settings])
    }

    @Test
    func everyItemHasIconTitleAndSubtitle() {
        let sut = DefaultHomeViewModel()

        for item in sut.menuItems {
            #expect(!item.icon.isEmpty, "icon missing for \(item.id)")
            #expect(!item.title.isEmpty, "title missing for \(item.id)")
            #expect(!item.subtitle.isEmpty, "subtitle missing for \(item.id)")
        }
    }

    @Test
    func itemIDsAreUnique() {
        let sut = DefaultHomeViewModel()
        let ids = sut.menuItems.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
