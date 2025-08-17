import Foundation
import os.log

/// Centralized logging utility for the application
enum LoggerUtility {
    /// The application's logging subsystem identifier
    static let subsystem = "com.example.ClamshellMonitor"

    /// Create a logger for a specific category
    /// - Parameter category: The category name for the logger
    /// - Returns: A configured Logger instance
    static func createLogger(category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }
}
