//
//  ImportViewController.swift
//  BookPlayer
//
//  Created by Murali Murugan on 7/26/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import GCDWebServers
import Themeable
import UIKit

private protocol webServerLaunchable {
    func didStartWebServer()
    func didStopWebServer()
}

final class ImportViewController: UITableViewController {
    enum ImportSections: Int {
        case wifi = 0
    }
    
    private var webServer: GCDWebUploader?
    @IBOutlet private weak var bonjourServer: UILabel!
    @IBOutlet weak var wifiSharingLabel: LocalizableLabel!
    @IBOutlet weak var serverIpAddress: UILabel!
    @IBOutlet weak var serverStatus: UISwitch!

    @IBAction func didTapStartServer(_ sender: Any) {
        if self.serverStatus.isOn {
            self.didStartWebServer()
            self.updateUI()
        } else {
            self.didStopWebServer()
            self.serverIpAddress.text = "Inactive Server"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpTheming()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.didStopWebServer()
    }

    private func updateUI() {
        guard let webServer = webServer else {
            return
        }

        if webServer.isRunning, self.serverStatus.isOn {
            self.serverIpAddress.text = webServer.serverURL?.absoluteString
        }
    }
}

extension ImportViewController {
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as? UITableViewHeaderFooterView
        header?.textLabel?.textColor = self.themeProvider.currentTheme.detailColor
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as? UITableViewHeaderFooterView
        footer?.textLabel?.textColor = self.themeProvider.currentTheme.detailColor
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let importSection = ImportSections(rawValue: section) else {
            return super.tableView(tableView, titleForFooterInSection: section)
        }

        switch importSection {
        case .wifi:
            return "settings_wifi_import_desc".localized
        }
    }
}

extension ImportViewController: webServerLaunchable {
    fileprivate func didStartWebServer() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        self.webServer = GCDWebUploader(uploadDirectory: documentsPath)

        guard
            let webServer = webServer,
            let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
        else {
            return
        }

        webServer.header = "Book Player file uploader"
        webServer.footer = "Book Player - " + version + " - " + build
        webServer.prologue = "Please upload the book in a zipped file or upload one zip/mp3/m4b/m4a file at a time!"
        webServer.allowedFileExtensions = ["zip", "mp3", "m4a", "m4b"]
        webServer.allowHiddenItems = false
        webServer.delegate = self
        webServer.start()
    }

    fileprivate func didStopWebServer() {
        guard let webServer = webServer else {
            return
        }
        if webServer.isRunning {
            webServer.stop()
        }
    }
}

extension ImportViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.wifiSharingLabel.textColor = theme.primaryColor
        self.serverIpAddress.textColor = theme.primaryColor
        self.tableView.backgroundColor = theme.settingsBackgroundColor
        self.tableView.separatorColor = theme.separatorColor
        self.tableView.reloadData()
    }
}

extension ImportViewController: GCDWebUploaderDelegate {
    func webUploader(_: GCDWebUploader, didUploadFileAtPath path: String) {
        DataManager.processFile(at: URL(fileURLWithPath: path))
    }
}
