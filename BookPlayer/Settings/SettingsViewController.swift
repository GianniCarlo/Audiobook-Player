//
//  SettingsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/29/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import DeviceKit
import IntentsUI
import MessageUI
import SafariServices
import Themeable
import UIKit

protocol IntentSelectionDelegate: AnyObject {
    func didSelectIntent(_ intent: INIntent)
}

class SettingsViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var autoplayLibrarySwitch: UISwitch!
    @IBOutlet weak var disableAutolockSwitch: UISwitch!
    @IBOutlet weak var autolockDisabledOnlyWhenPoweredSwitch: UISwitch!
    @IBOutlet weak var autolockDisabledOnlyWhenPoweredLabel: UILabel!
    @IBOutlet weak var themeLabel: UILabel!
    @IBOutlet weak var appIconLabel: UILabel!

    var iconObserver: NSKeyValueObservation!

    enum SettingsSection: Int {
        case plus = 0, theme, playback, autoplay, autolock, siri, bookimport, support, credits
    }

    let lastPlayedShortcutPath = IndexPath(row: 0, section: 5)
    let sleepTimerShortcutPath = IndexPath(row: 1, section: 5)

    let supportSection: Int = 6
    let githubLinkPath = IndexPath(row: 0, section: 7)
    let supportEmailPath = IndexPath(row: 1, section: 7)

    var version: String = "0.0.0"
    var build: String = "0"
    var supportEmail = "support@bookplayer.app"

    var appVersion: String {
        return "\(self.version)-\(self.build)"
    }

    var systemVersion: String {
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = "settings_title".localized

        setUpTheming()

        self.appIconLabel.text = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"

        self.iconObserver = UserDefaults.standard.observe(\.userSettingsAppIcon) { _, _ in
            self.appIconLabel.text = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"
        }
        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) {
            self.donationMade()
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(self.donationMade), name: .donationMade, object: nil)
        }

        self.autoplayLibrarySwitch.addTarget(self, action: #selector(self.autoplayToggleDidChange), for: .valueChanged)
        self.disableAutolockSwitch.addTarget(self, action: #selector(self.disableAutolockDidChange), for: .valueChanged)
        self.autolockDisabledOnlyWhenPoweredSwitch.addTarget(self, action: #selector(self.autolockOnlyWhenPoweredDidChange), for: .valueChanged)

        // Set initial switch positions
        self.autoplayLibrarySwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue), animated: false)
        self.disableAutolockSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue), animated: false)
        self.autolockDisabledOnlyWhenPoweredSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabledOnlyWhenPowered.rawValue), animated: false)
        self.autolockDisabledOnlyWhenPoweredSwitch.isEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue)
        self.autolockDisabledOnlyWhenPoweredLabel.isEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue)

        guard
            let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
        else {
            return
        }

        self.version = version
        self.build = build
    }

    @objc func donationMade() {
        self.tableView.reloadData()
    }

    @objc func autoplayToggleDidChange() {
        UserDefaults.standard.set(self.autoplayLibrarySwitch.isOn, forKey: Constants.UserDefaults.autoplayEnabled.rawValue)
    }

    @objc func disableAutolockDidChange() {
        UserDefaults.standard.set(self.disableAutolockSwitch.isOn, forKey: Constants.UserDefaults.autolockDisabled.rawValue)
        self.autolockDisabledOnlyWhenPoweredSwitch.isEnabled = self.disableAutolockSwitch.isOn
        self.autolockDisabledOnlyWhenPoweredLabel.isEnabled = self.disableAutolockSwitch.isOn
    }

    @objc func autolockOnlyWhenPoweredDidChange() {
        UserDefaults.standard.set(self.autolockDisabledOnlyWhenPoweredSwitch.isOn, forKey: Constants.UserDefaults.autolockDisabledOnlyWhenPowered.rawValue)
    }

    @IBAction func done(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.section == 0 else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }

        guard !UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) else { return 0 }

        return 102
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section == 0, UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) else {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }

        return CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard section == 0, UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) else {
            return super.tableView(tableView, heightForFooterInSection: section)
        }

        return CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)

        switch indexPath {
        case self.supportEmailPath:
            self.sendSupportEmail()
        case self.githubLinkPath:
            self.showProjectOnGitHub()
        case self.lastPlayedShortcutPath:
            self.showLastPlayedShortcut()
        case self.sleepTimerShortcutPath:
            self.showSleepTimerShortcut()
        default: break
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let settingsSection = SettingsSection(rawValue: section) else {
            return super.tableView(tableView, titleForFooterInSection: section)
        }

        switch settingsSection {
        case .theme:
            return "settings_appearance_title".localized
        case .playback:
            return "settings_playback_title".localized
        case .siri:
            return "settings_siri_title".localized
        case .support:
            return "settings_support_title".localized
        case .bookimport:
            return "settings_import_title".localized
        default:
            return super.tableView(tableView, titleForHeaderInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let settingsSection = SettingsSection(rawValue: section) else {
            return super.tableView(tableView, titleForFooterInSection: section)
        }

        switch settingsSection {
        case .autoplay:
            return "settings_autoplay_description".localized
        case .autolock:
            return "settings_autolock_description".localized
        case .support:
            return "BookPlayer \(self.appVersion) - \(self.systemVersion)"
        default:
            return super.tableView(tableView, titleForFooterInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as? UITableViewHeaderFooterView
        header?.textLabel?.textColor = self.themeProvider.currentTheme.detailColor
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as? UITableViewHeaderFooterView
        footer?.textLabel?.textColor = self.themeProvider.currentTheme.detailColor
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    func showLastPlayedShortcut() {
        let intent = INPlayMediaIntent()

        guard let shortcut = INShortcut(intent: intent) else { return }

        let vc = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        vc.delegate = self

        self.present(vc, animated: true, completion: nil)
    }

    func showSleepTimerShortcut() {
        if #available(iOS 13.0, *) {
            let intent = SleepTimerIntent()
            intent.option = .unknown
            let shortcut = INShortcut(intent: intent)!

            let vc = INUIAddVoiceShortcutViewController(shortcut: shortcut)
            vc.delegate = self

            self.present(vc, animated: true, completion: nil)
            return
        }

        let sheet = SleepTimer.shared.intentSheet(on: self)

        self.present(sheet, animated: true, completion: nil)
    }

    @IBAction func sendSupportEmail() {
        let device = Device()

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()

            mail.mailComposeDelegate = self
            mail.setToRecipients([self.supportEmail])
            mail.setSubject("I need help with BookPlayer \(self.version)-\(self.build)")
            mail.setMessageBody("<p>Hello BookPlayer Crew,<br>I have an issue concerning BookPlayer \(self.appVersion) on my \(device) running \(self.systemVersion)</p><p>When I try to…</p>", isHTML: true)

            self.present(mail, animated: true)
        } else {
            let debugInfo = "BookPlayer \(self.appVersion)\n\(device) - \(self.systemVersion)"
            let message = "settings_support_compose_description".localized

            let alert = UIAlertController(title: "settings_support_compose_title".localized, message: "\(message) \(self.supportEmail)\n\n\(debugInfo)", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "settings_support_compose_copy".localized, style: .default, handler: { _ in
                UIPasteboard.general.string = "\(self.supportEmail)\n\(debugInfo)"
            }))

            alert.addAction(UIAlertAction(title: "ok_button".localized, style: .cancel, handler: nil))

            self.present(alert, animated: true, completion: nil)
        }
    }

    func showProjectOnGitHub() {
        let url = URL(string: "https://github.com/GianniCarlo/Audiobook-Player")
        let safari = SFSafariViewController(url: url!)
        safari.dismissButtonStyle = .close

        self.present(safari, animated: true)
    }
}

extension SettingsViewController: INUIAddVoiceShortcutViewControllerDelegate {
    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        self.dismiss(animated: true, completion: nil)
    }

    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SettingsViewController: IntentSelectionDelegate {
    func didSelectIntent(_ intent: INIntent) {
        let shortcut = INShortcut(intent: intent)!
        let vc = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
}

extension SettingsViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.themeLabel.text = theme.title
        self.tableView.backgroundColor = theme.settingsBackgroundColor
        self.tableView.separatorColor = theme.settingsBackgroundColor
        self.tableView.reloadData()
    }
}
