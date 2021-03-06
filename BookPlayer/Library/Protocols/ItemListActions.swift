//
//  ItemListActions.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/11/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

protocol ItemListActions: ItemList {
    func sort(by sortType: PlayListSortOrder)
    func delete(_ items: [LibraryItem], mode: DeleteMode)
    func move(_ items: [LibraryItem], to folder: Folder)
}

extension ItemListActions {
    func delete(_ items: [LibraryItem], mode: DeleteMode) {
        DataManager.delete(items, library: self.library, mode: mode)
        self.reloadData()
    }

    func move(_ items: [LibraryItem], to folder: Folder) {
        for item in items {
            if let parent = item.folder {
                parent.removeFromItems(item)
                parent.updateCompletionState()
            } else {
                self.library.removeFromItems(item)
            }
        }

        folder.addToItems(NSOrderedSet(array: items))
        folder.updateCompletionState()

        DataManager.saveContext()

        self.reloadData()
    }

    func createExportController(_ item: LibraryItem) -> UIViewController? {
        guard let book = item as? Book else { return nil }

        let bookProvider = BookActivityItemProvider(book)

        let shareController = UIActivityViewController(activityItems: [bookProvider], applicationActivities: nil)
        shareController.excludedActivityTypes = [.copyToPasteboard]

        return shareController
    }
}
