import Foundation
import os.log

// Setup logger
let logger = LoggerUtility.createLogger(category: "Main")

// Use default handler
let handler = DefaultClamshellEventHandler()

// Create and start monitor
let monitor = ClamshellMonitor(eventHandler: handler)
if monitor.start() {
    logger.info("Clamshell monitor started successfully")

    // Run loop keeps the program alive
    CFRunLoopRun()
} else {
    logger.error("Failed to start clamshell monitor")
    exit(1)
}
