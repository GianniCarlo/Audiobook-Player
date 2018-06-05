//
// Extensions.swift
// BookPlayer
//
// Created by Gianni Carlo on 3/10/17.
// Copyright © 2017 Tortuga Power. All rights reserved.
//

import UIKit

extension Notification.Name {
    public struct AudiobookPlayer {
        public static let openURL = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.openurl")
        public static let requestReview = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.requestreview")
        public static let updatePercentage = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.percentage")
        public static let updateChapter = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.chapter")
        public static let loadingBook = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.loading")
        public static let errorLoadingBook = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.error")
        public static let bookReady = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.ready")
        public static let bookPlayed = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.play")
        public static let bookPaused = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.pause")
        public static let bookStopped = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.stop")
        public static let bookEnd = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.end")
        public static let bookChange = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.change")
        public static let bookPlaying = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.playback")
        public static let skipIntervalsChange = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.settings.skip")
        public static let bookDeleted = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.deleted")
        public static let playerPresented = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.player.presented")
        public static let playerDismissed = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.player.dismissed")
    }
}
