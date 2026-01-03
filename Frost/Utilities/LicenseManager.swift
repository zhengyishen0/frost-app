//
//  LicenseManager.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//

import Foundation

class LicenseManager {

    static let shared = LicenseManager()

    // MARK: - Constants

    private let licenseKey = "FrostLicenseKey"

    // 12 base words - sliding window of 4 creates weekly tokens
    private let words = [
        "FROST", "SNOW", "ICE", "CRYSTAL", "WINTER", "CHILL",
        "POLAR", "ARCTIC", "GLACIER", "POWDER", "ALPINE", "AURORA"
    ]

    // MARK: - Public Methods

    /// Check if app is licensed
    var isLicensed: Bool {
        return UserDefaults.standard.string(forKey: licenseKey) != nil
    }

    /// Get stored license key
    var storedLicense: String? {
        return UserDefaults.standard.string(forKey: licenseKey)
    }

    /// Validate and store a license key
    /// Returns true if valid, false otherwise
    func activate(key: String) -> Bool {
        let cleanKey = key.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if isValidToken(cleanKey) {
            UserDefaults.standard.set(cleanKey, forKey: licenseKey)
            return true
        }
        return false
    }

    /// Remove stored license
    func deactivate() {
        UserDefaults.standard.removeObject(forKey: licenseKey)
    }

    // MARK: - Token Generation

    /// Generate token for a given week number (1-52)
    private func getTokenForWeek(_ weekNum: Int) -> String {
        let startIndex = (weekNum - 1) % 12
        var tokenWords: [String] = []
        for i in 0..<4 {
            tokenWords.append(words[(startIndex + i) % 12])
        }
        return tokenWords.joined(separator: "-")
    }

    /// Get ISO week number from date
    private func getWeekNumber(from date: Date) -> Int {
        let calendar = Calendar(identifier: .iso8601)
        return calendar.component(.weekOfYear, from: date)
    }

    // MARK: - Validation

    /// Check if token is valid (current week or 3 weeks before)
    private func isValidToken(_ token: String) -> Bool {
        let currentWeek = getWeekNumber(from: Date())

        // Generate valid tokens: current week + 3 previous weeks
        var validTokens: [String] = []
        for i in 0..<4 {
            var week = currentWeek - i
            // Handle year boundary (week 0 or negative = previous year's weeks)
            if week <= 0 {
                week += 52
            }
            validTokens.append(getTokenForWeek(week))
        }

        return validTokens.contains(token)
    }

    /// Get current week's token (for testing/debug)
    func getCurrentToken() -> String {
        let currentWeek = getWeekNumber(from: Date())
        return getTokenForWeek(currentWeek)
    }

    /// Get all currently valid tokens (for testing/debug)
    func getValidTokens() -> [String] {
        let currentWeek = getWeekNumber(from: Date())
        var tokens: [String] = []
        for i in 0..<4 {
            var week = currentWeek - i
            if week <= 0 {
                week += 52
            }
            tokens.append(getTokenForWeek(week))
        }
        return tokens
    }
}
