import Foundation
import IOKit.pwr_mgt
import os.log

class sleep {

    private let logger = LoggerUtility.createLogger(category: "SleepHelper")

    func sleepMac() {

        let process = Process()
        process.launchPath = "/usr/bin/pmset"
        process.arguments = ["sleepnow"]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.error("Failed to put Mac to sleep: \(error)")
        }
    }
}
