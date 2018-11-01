//
//  LibraryViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/7/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import MediaPlayer
import SwiftReorder
import UIKit

// swiftlint:disable file_length

class LibraryViewController: BaseListViewController, UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        // VoiceOver
        setupCustomRotors()

        // enables pop gesture on pushed controller
        navigationController!.interactivePopGestureRecognizer!.delegate = self

        // register for appDelegate openUrl notifications
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: .reloadData, object: nil)

        loadLibrary()

        // handle CoreData migration into shared app groups
        if !UserDefaults.standard.bool(forKey: Constants.UserDefaults.appGroupsMigration.rawValue) {
            migrateCoreDataStack()
            UserDefaults.standard.set(true, forKey: Constants.UserDefaults.appGroupsMigration.rawValue)
        }

        guard let identifier = UserDefaults.standard.string(forKey: Constants.UserDefaults.lastPlayedBook.rawValue),
            let item = self.library.getItem(with: identifier) else {
            return
        }

        var book: Book?

        if
            let playlist = item as? Playlist,
            let index = playlist.itemIndex(with: identifier),
            let playlistBook = playlist.getBook(at: index) {
            book = playlistBook
        } else if let lastPlayedBook = item as? Book {
            book = lastPlayedBook
        }

        guard book != nil else { return }

        // Preload player
        PlayerManager.shared.load(book!) { loaded in
            guard loaded else { return }

            NotificationCenter.default.post(name: .playerDismissed, object: nil, userInfo: nil)
        }
    }

    // No longer need to deregister observers for iOS 9+!
    // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11NotificationCenter
    deinit {
        // for iOS 8
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    /**
     *  Load local files and process them (rename them if necessary)
     *  Spaces in file names can cause side effects when trying to load the data
     */
    func loadLibrary() {
        library = DataManager.getLibrary()

        toggleEmptyStateView()

        tableView.reloadData()

        DataManager.notifyPendingFiles()
    }

    /**
     *  Migrates existing stack into the new container app groups.
     *  In case it fails, it loads all the files from the Processed folder
     */
    func migrateCoreDataStack() {
        DataManager.makeFilesPublic()
        do {
            try DataManager.migrateStack()
        } catch {
            // Migration failed, fallback: load all books from processed folder
            if let fileUrls = DataManager.getFiles(from: DataManager.getProcessedFolderURL()) {
                let fileItems = fileUrls.map { (url) -> FileItem in
                    return FileItem(originalUrl: url, processedUrl: url, destinationFolder: url)
                }
                DataManager.insertBooks(from: fileItems, into: library) {
                    self.reloadData()
                }
            }
        }
    }

    override func handleOperationCompletion(_ files: [FileItem]) {
        DataManager.insertBooks(from: files, into: library) {
            self.reloadData()
        }

        guard files.count > 1 else {
            showLoadView(false)
            return
        }

        let alert = UIAlertController(title: "Import \(files.count) files into", message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Library", style: .default) { _ in
            self.showLoadView(false)
        })

        alert.addAction(UIAlertAction(title: "New Playlist", style: .default) { _ in
            var placeholder = "New Playlist"

            if let file = files.first {
                placeholder = file.originalUrl.deletingPathExtension().lastPathComponent
            }

            self.presentCreatePlaylistAlert(placeholder, handler: { title in
                let playlist = DataManager.createPlaylist(title: title, books: [])

                self.library.addToItems(playlist)

                DataManager.insertBooks(from: files, into: playlist) {
                    DataManager.saveContext()

                    self.showLoadView(false)
                    self.reloadData()
                }

            })
        })

        let vc = presentedViewController ?? self

        vc.present(alert, animated: true, completion: nil)
    }

    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        return navigationController!.viewControllers.count > 1
    }

    private func presentPlaylist(_ playlist: Playlist) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        guard let playlistVC = storyboard.instantiateViewController(withIdentifier: "PlaylistViewController") as? PlaylistViewController else {
            return
        }

        playlistVC.library = library
        playlistVC.playlist = playlist

        navigationController?.pushViewController(playlistVC, animated: true)
    }

    func handleDelete(book: Book, indexPath: IndexPath) {
        let alert = UIAlertController(title: "Delete \(book.title!)?", message: "Do you really want to delete this book?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.tableView.setEditing(false, animated: true)
        }))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            if book == PlayerManager.shared.currentBook {
                PlayerManager.shared.stop()
            }

            try? FileManager.default.removeItem(at: book.fileURL)

            self.library.removeFromItems(book)

            DataManager.delete(book)

            self.deleteRows(at: [indexPath])
        }))

        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(x: Double(view.bounds.size.width / 2.0), y: Double(view.bounds.size.height - 45), width: 1.0, height: 1.0)

        present(alert, animated: true, completion: nil)
    }

    func handleDelete(playlist: Playlist, indexPath: IndexPath) {
        guard playlist.hasBooks() else {
            library.removeFromItems(playlist)

            DataManager.delete(playlist)

            deleteRows(at: [indexPath])
            return
        }

        let sheet = UIAlertController(title: "Delete \(playlist.title!)?",
                                      message: "Deleting only the playlist will move all its files back to the Library.",
                                      preferredStyle: .alert)

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        sheet.addAction(UIAlertAction(title: "Delete playlist only", style: .default, handler: { _ in
            if let orderedSet = playlist.books {
                self.library.addToItems(orderedSet)
            }

            self.library.removeFromItems(playlist)
            DataManager.delete(playlist)

            self.tableView.beginUpdates()
            self.tableView.reloadSections(IndexSet(integer: Section.library.rawValue), with: .none)
            self.tableView.endUpdates()
            self.toggleEmptyStateView()
        }))

        sheet.addAction(UIAlertAction(title: "Delete both playlist and books", style: .destructive, handler: { _ in
            // swiftlint:disable force_cast
            for book in playlist.books?.array as! [Book] {
                if book == PlayerManager.shared.currentBook {
                    PlayerManager.shared.stop()
                }
                try? FileManager.default.removeItem(at: book.fileURL)
            }

            self.library.removeFromItems(playlist)

            DataManager.delete(playlist)

            self.deleteRows(at: [indexPath])
        }))

        present(sheet, animated: true, completion: nil)
    }

    func presentCreatePlaylistAlert(_ namePlaceholder: String = "New Playlist", handler: ((_ title: String) -> Void)?) {
        let playlistAlert = UIAlertController(
            title: "Create a new playlist",
            message: "Files in playlists are automatically played one after the other",
            preferredStyle: .alert
        )

        playlistAlert.addTextField(configurationHandler: { textfield in
            textfield.text = namePlaceholder
        })

        playlistAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        playlistAlert.addAction(UIAlertAction(title: "Create", style: .default, handler: { _ in
            let title = playlistAlert.textFields!.first!.text!

            handler?(title)
        }))

        let vc = presentedViewController ?? self

        vc.present(playlistAlert, animated: true) {
            guard let textfield = playlistAlert.textFields?.first else { return }
            textfield.becomeFirstResponder()
            textfield.selectedTextRange = textfield.textRange(from: textfield.beginningOfDocument, to: textfield.endOfDocument)
        }
    }

    // MARK: - IBActions

    @IBAction func addAction() {
        let alertController = UIAlertController(
            title: nil,
            message: "You can also add files via AirDrop. Send an audiobook file to your device and select BookPlayer from the list that appears.",
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: "Import files", style: .default) { _ in
            self.presentImportFilesAlert()
        })

        alertController.addAction(UIAlertAction(title: "Create playlist", style: .default) { _ in
            self.presentCreatePlaylistAlert(handler: { title in
                let playlist = DataManager.createPlaylist(title: title, books: [])

                self.library.addToItems(playlist)
                DataManager.saveContext()

                self.reloadData()
            })
        })

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alertController, animated: true, completion: nil)
    }

    // MARK: Accessibility

    private func setupCustomRotors() {
        accessibilityCustomRotors = [rotorFactory(name: "Books", type: .book), rotorFactory(name: "Playlists", type: .playlist)]
    }

    private func rotorFactory(name: String, type: BookCellType) -> UIAccessibilityCustomRotor {
        return UIAccessibilityCustomRotor(name: name) { (predicate) -> UIAccessibilityCustomRotorItemResult? in
            let forward: Bool = (predicate.searchDirection == .next)

            let playListCells = self.tableView.visibleCells.filter({ (cell) -> Bool in
                guard let cell = cell as? BookCellView else { return false }
                return cell.type == type
            })

            var currentIndex = forward ? -1 : playListCells.count
            //
            if let currentElement = predicate.currentItem.targetElement {
                if let cell = currentElement as? BookCellView {
                    currentIndex = playListCells.firstIndex(of: cell) ?? currentIndex
                }
            }
            let nextIndex = forward ? currentIndex + 1 : currentIndex - 1

            while nextIndex >= 0 && nextIndex < playListCells.count {
                let cell = playListCells[nextIndex]
                return UIAccessibilityCustomRotorItemResult(targetElement: cell, targetRange: nil)
            }
            return nil
        }
    }

    // Sorting
    override func sort(by sortType: PlayListSortOrder) throws {
        try library.sort(by: sortType)
    }
}

// MARK: - TableView Delegate

extension LibraryViewController {
    func tableView(_: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.sectionValue == .library else {
            return nil
        }

        let item = items[indexPath.row]

        // "…" on a button indicates a follow up dialog instead of an immmediate action in macOS and iOS
        var title = "Delete…"

        // Remove the dots if trying to delete an empty playlist
        if let playlist = item as? Playlist {
            title = playlist.hasBooks() ? title : "Delete"
        }

        let deleteAction = UITableViewRowAction(style: .default, title: title) { _, indexPath in
            guard let book = self.items[indexPath.row] as? Book else {
                guard let playlist = self.items[indexPath.row] as? Playlist else {
                    return
                }

                self.handleDelete(playlist: playlist, indexPath: indexPath)

                return
            }

            self.handleDelete(book: book, indexPath: indexPath)
        }

        deleteAction.backgroundColor = .red

        if item is Playlist {
            let renameAction = UITableViewRowAction(style: .normal, title: "Rename") { _, indexPath in
                guard let playlist = self.items[indexPath.row] as? Playlist else {
                    return
                }

                let alert = UIAlertController(title: "Rename playlist", message: nil, preferredStyle: .alert)

                alert.addTextField(configurationHandler: { textfield in
                    textfield.placeholder = playlist.title
                    textfield.text = playlist.title
                })

                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: "Rename", style: .default) { _ in
                    if let title = alert.textFields!.first!.text, title != playlist.title {
                        playlist.title = title

                        DataManager.saveContext()
                        self.tableView.reloadRows(at: [indexPath], with: .none)
                    }
                })

                self.present(alert, animated: true, completion: nil)
            }

            return [deleteAction, renameAction]
        }

        let exportAction = UITableViewRowAction(style: .normal, title: "Export") { _, indexPath in
            guard let book = self.items[indexPath.row] as? Book else {
                return
            }

            let bookProvider = BookActivityItemProvider(book)

            let shareController = UIActivityViewController(activityItems: [bookProvider], applicationActivities: nil)

            shareController.excludedActivityTypes = [.copyToPasteboard]

            self.present(shareController, animated: true, completion: nil)
        }

        return [deleteAction, exportAction]
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.sectionValue == .library else {
            if indexPath.sectionValue == .add {
                addAction()
            }

            return
        }

        if let playlist = self.items[indexPath.row] as? Playlist {
            presentPlaylist(playlist)

            return
        }

        if let book = self.items[indexPath.row] as? Book {
            setupPlayer(book: book)
        }
    }
}

// MARK: - TableView DataSource

extension LibraryViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        guard let bookCell = cell as? BookCellView,
            let currentBook = PlayerManager.shared.currentBook,
            let index = self.library.itemIndex(with: currentBook.fileURL),
            index == indexPath.row else {
            return cell
        }

        bookCell.playbackState = .paused

        return bookCell
    }
}

// MARK: - Reorder Delegate

extension LibraryViewController {
    override func tableView(_: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard destinationIndexPath.sectionValue == .library else {
            return
        }

        let item = items[sourceIndexPath.row]

        library.removeFromItems(at: sourceIndexPath.row)
        library.insertIntoItems(item, at: destinationIndexPath.row)

        DataManager.saveContext()
    }

    override func tableViewDidFinishReordering(_: UITableView, from _: IndexPath, to finalDestinationIndexPath: IndexPath, dropped overIndexPath: IndexPath?) {
        guard let overIndexPath = overIndexPath, overIndexPath.sectionValue == .library, let book = self.items[finalDestinationIndexPath.row] as? Book else {
            return
        }

        let item = items[overIndexPath.row]

        if item is Playlist {
            let alert = UIAlertController(title: "Move to playlist",
                                          message: "Do you want to move \(book.title!) to \(item.title!)?",
                                          preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

            alert.addAction(UIAlertAction(title: "Move", style: .default, handler: { _ in
                if let playlist = item as? Playlist {
                    playlist.addToBooks(book)
                }

                self.library.removeFromItems(at: finalDestinationIndexPath.row)

                DataManager.saveContext()

                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [finalDestinationIndexPath], with: .fade)
                self.tableView.reloadRows(at: [overIndexPath], with: .fade)
                self.tableView.endUpdates()
            }))

            present(alert, animated: true, completion: nil)
        } else {
            let minIndex = min(finalDestinationIndexPath.row, overIndexPath.row)

            // Removing based on minIndex works because the cells are always adjacent
            let book1 = items[minIndex]

            presentCreatePlaylistAlert(book1.title, handler: { title in

                self.library.removeFromItems(book1)

                let book2 = self.items[minIndex]

                self.library.removeFromItems(book2)

                // swiftlint:disable force_cast
                let books = [book1 as! Book, book2 as! Book]
                let playlist = DataManager.createPlaylist(title: title, books: books)

                self.library.insertIntoItems(playlist, at: minIndex)

                DataManager.saveContext()

                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [IndexPath(row: minIndex, section: .library), IndexPath(row: minIndex + 1, section: .library)], with: .fade)
                self.tableView.insertRows(at: [IndexPath(row: minIndex, section: .library)], with: .fade)
                self.tableView.endUpdates()
            })
        }
    }
}
