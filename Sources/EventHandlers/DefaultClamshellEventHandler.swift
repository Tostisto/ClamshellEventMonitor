import Foundation
import IOKit.pwr_mgt
import os.log

class DefaultClamshellEventHandler: ClamshellEventHandler {
    // Logger instance
    private let logger = LoggerUtility.createLogger(category: "ClamshellEventHandler")
    
    func onLidClosed() {
        logger.info("Lid closed, putting system to sleep")
        let process = Process()
        process.launchPath = "/usr/bin/pmset"
        process.arguments = ["sleepnow"]
        do {
            try process.run()
        } catch {
            logger.error("Failed to put system to sleep: \(error.localizedDescription)")
        }
    }
    
    func onLidOpened() {
        logger.info("Lid opened")
    }
}
