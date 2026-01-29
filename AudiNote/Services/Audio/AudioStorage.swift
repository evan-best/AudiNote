import Foundation

enum AudioStorage {
    static let cloudContainerIdentifier = "iCloud.AudiNote"

    static func localDirectoryURL() -> URL {
        let fileManager = FileManager.default
        let localDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try? fileManager.createDirectory(at: localDirectory, withIntermediateDirectories: true)
        return localDirectory
    }

    static func localFileURL(fileName: String) -> URL {
        localDirectoryURL().appendingPathComponent(fileName)
    }

    static func ubiquityDirectoryURL() -> URL? {
        let fileManager = FileManager.default
        guard let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: cloudContainerIdentifier)
            ?? fileManager.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }

        let directory = ubiquityURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func ubiquityFileURL(fileName: String) -> URL? {
        ubiquityDirectoryURL()?.appendingPathComponent(fileName)
    }

    static func urlForAudioFile(named fileName: String) -> URL {
        localDirectoryURL().appendingPathComponent(fileName)
    }

    static func resolveAudioURL(from storedPath: String) -> URL? {
        guard !storedPath.isEmpty else { return nil }

        let fileManager = FileManager.default
        if storedPath.contains("/") {
            return URL(fileURLWithPath: storedPath)
        }

        let fileName = (storedPath as NSString).lastPathComponent
        let localURL = localFileURL(fileName: fileName)
        if fileManager.fileExists(atPath: localURL.path) {
            return localURL
        }

        if let ubiquityURL = ubiquityFileURL(fileName: fileName) {
            return ubiquityURL
        }

        return localURL
    }

    @discardableResult
    static func ensureUbiquitousCopy(from sourceURL: URL, fileName: String) -> URL {
        let fileManager = FileManager.default
        guard let ubiquityDirectory = ubiquityDirectoryURL() else {
            return sourceURL
        }

        let destinationURL = ubiquityDirectory.appendingPathComponent(fileName)

        if sourceURL.path == destinationURL.path {
            return destinationURL
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        coordinator.coordinate(writingItemAt: sourceURL, options: .forMoving, writingItemAt: destinationURL, options: .forReplacing, error: &coordinationError) { newSource, newDestination in
            do {
                try fileManager.setUbiquitous(true, itemAt: newSource, destinationURL: newDestination)
            } catch {
            }
        }

        if coordinationError != nil {
            return sourceURL
        }

        return destinationURL
    }
}
