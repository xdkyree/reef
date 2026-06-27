import SwiftUI

// MARK: - LibraryViewModel

@MainActor
final class LibraryViewModel: ObservableObject {

    // MARK: Published state
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var totalCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var error: Error?

    // MARK: Constants
    private let pageSize = 50

    // MARK: Dependencies
    private let api: JellyfinAPIClientProtocol
    private let libraryID: String
    private let libraryType: LibraryType

    // MARK: Init
    init(api: JellyfinAPIClientProtocol, libraryID: String, libraryType: LibraryType) {
        self.api = api
        self.libraryID = libraryID
        self.libraryType = libraryType
    }

    // MARK: - Load

    func loadFirstPage(userID: String, token: String) async {
        isLoading = true
        error = nil
        items = []
        defer { isLoading = false }

        do {
            let result = try await api.fetchLibraryItems(
                userID: userID,
                parentID: libraryID,
                libraryType: libraryType,
                token: token,
                startIndex: 0,
                limit: pageSize
            )
            items = result.items
            totalCount = result.totalCount
        } catch {
            self.error = error
        }
    }

    func loadNextPageIfNeeded(userID: String, token: String, currentItem item: MediaItem) async {
        guard
            !isLoadingNextPage,
            !isLoading,
            let index = items.firstIndex(where: { $0.id == item.id }),
            index >= items.count - 10,           // Trigger when near the end
            items.count < totalCount
        else { return }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        do {
            let result = try await api.fetchLibraryItems(
                userID: userID,
                parentID: libraryID,
                libraryType: libraryType,
                token: token,
                startIndex: items.count,
                limit: pageSize
            )
            let existingIDs = Set(items.map(\.id))
            let newItems = result.items.filter { !existingIDs.contains($0.id) }
            items.append(contentsOf: newItems)
        } catch {
            self.error = error
        }
    }

    var hasMore: Bool { items.count < totalCount }
}
