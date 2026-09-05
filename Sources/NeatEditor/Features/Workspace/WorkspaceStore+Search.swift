import Foundation

extension WorkspaceStore {
    // MARK: - Search

    func presentSearchBar() {
        searchState.present()
    }

    func dismissSearchBar() {
        searchState.dismiss()
    }

    func toggleRegexSearch() {
        searchState.toggleRegex()
    }

    func submitSearch() {
        searchState.submit()
    }
}
