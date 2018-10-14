//
//  PlaylistViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlaylistViewController: BaseListViewController {
    var playlist: Playlist!
    @IBAction func didTapSort(_ sender: Any) {
        let alert = UIAlertController(title: "Sort Files", message: "Sort Playlist files by", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Title", style: .default, handler: { (action) in

        }))

        alert.addAction(UIAlertAction(title: "File Name", style: .default, handler: { (action) in
            print("file name")
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            alert.dismiss(animated: true, completion: nil)
        }))

        present(alert, animated: true, completion: nil)
    }
    
    override var items: [LibraryItem] {
        return self.playlist.books?.array as? [LibraryItem] ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.toggleEmptyStateView()

        self.navigationItem.title = playlist.title
    }

    override func handleOperationCompletion(_ files: [FileItem]) {
        DataManager.insertBooks(from: files, into: self.playlist) {
            self.reloadData()
        }

        guard files.count > 1 else {
            self.showLoadView(false)
            NotificationCenter.default.post(name: .reloadData, object: nil)
            return
        }

        let alert = UIAlertController(title: "Import \(files.count) files into", message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Library", style: .default) { (_) in
            DataManager.insertBooks(from: files, into: self.library) {
                self.showLoadView(false)
                self.reloadData()
                NotificationCenter.default.post(name: .reloadData, object: nil)
            }
        })

        alert.addAction(UIAlertAction(title: "Current Playlist", style: .default) { (_) in
            self.showLoadView(false)
            NotificationCenter.default.post(name: .reloadData, object: nil)
        })

        let vc = self.presentedViewController ?? self

        vc.present(alert, animated: true, completion: nil)
    }

    // MARK: - Callback events
    @objc override func onBookPlay() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let index = self.playlist.itemIndex(with: currentBook.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .playing
    }

    @objc override func onBookPause() {
        guard
            let currentBook = PlayerManager.shared.currentBook,
            let index = self.playlist.itemIndex(with: currentBook.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .paused
    }

    @objc override func onBookStop(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book,
            let index = self.playlist.itemIndex(with: book.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: .library)) as? BookCellView
        else {
            return
        }

        bookCell.playbackState = .stopped
    }

    // MARK: - IBActions
    @IBAction func addAction() {
        self.presentImportFilesAlert()
    }
}

// MARK: - DocumentPicker Delegate
extension PlaylistViewController {
    override func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            //context put in playlist
            DataManager.processFile(at: url)
        }
    }
}

// MARK: - TableView DataSource
extension PlaylistViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        guard let bookCell = cell as? BookCellView else {
            return cell
        }

        bookCell.type = .file

        guard let currentBook = PlayerManager.shared.currentBook,
            let index = self.playlist.itemIndex(with: currentBook.fileURL),
            index == indexPath.row else {
                return bookCell
        }

        bookCell.playbackState = .playing

        return bookCell
    }
}

// MARK: - TableView Delegate
extension PlaylistViewController {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.sectionValue == .library else {
            if indexPath.sectionValue == .add {
                self.presentImportFilesAlert()
            }

            return
        }

        let books = self.queueBooksForPlayback(self.items[indexPath.row], forceAutoplay: true)

        self.setupPlayer(books: books)
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.sectionValue == .library, let book = self.items[indexPath.row] as? Book else {
            return nil
        }

        let deleteAction = UITableViewRowAction(style: .default, title: "Options") { (_, indexPath) in
            let sheet = UIAlertController(title: "\(book.title!)", message: nil, preferredStyle: .alert)

            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

            sheet.addAction(UIAlertAction(title: "Export item", style: .default, handler: { _ in

                let bookProvider = BookActivityItemProvider(book)

                let shareController = UIActivityViewController(activityItems: [bookProvider], applicationActivities: nil)

                shareController.excludedActivityTypes = [.copyToPasteboard]

                self.present(shareController, animated: true, completion: nil)
            }))

            sheet.addAction(UIAlertAction(title: "Remove from playlist", style: .default, handler: { _ in
                self.playlist.removeFromBooks(book)
                self.library.addToItems(book)

                DataManager.saveContext()

                self.deleteRows(at: [indexPath])

                NotificationCenter.default.post(name: .reloadData, object: nil)
            }))

            sheet.addAction(UIAlertAction(title: "Delete completely", style: .destructive, handler: { _ in
                if book == PlayerManager.shared.currentBook {
                    PlayerManager.shared.stop()
                }

                self.playlist.removeFromBooks(book)

                DataManager.saveContext()

                try? FileManager.default.removeItem(at: book.fileURL)

                self.deleteRows(at: [indexPath])

                NotificationCenter.default.post(name: .reloadData, object: nil)
            }))

            self.present(sheet, animated: true, completion: nil)
        }

        deleteAction.backgroundColor = UIColor.gray

        return [deleteAction]
    }
}

// MARK: - Reorder Delegate
extension PlaylistViewController {
    override func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard destinationIndexPath.sectionValue == .library else {
            return
        }

        // swiftlint:disable force_cast
        let book = self.items[sourceIndexPath.row] as! Book
        self.playlist.removeFromBooks(at: sourceIndexPath.row)
        self.playlist.insertIntoBooks(book, at: destinationIndexPath.row)
        DataManager.saveContext()
    }
}
