import Foundation
import IOKit.pwr_mgt
import os.log

class DefaultClamshellEventHandler: ClamshellEventHandler {

    // Logger instance
    private let logger = LoggerUtility.createLogger(category: "ClamshellEventHandler")

    func onLidClosed() {
        logger.info("Lid closed, putting system to sleep")

        let displayManager = DisplayManager()

        let displays = displayManager.getActiveDisplays()

        for display in displays {
            // is built in
            if !display.isBuiltin {
                logger.info("External display detected: \(display.description)")

                sleep().sleepMac()
            }
        }
    }

    func onLidOpened() {
        logger.info("Lid opened")
    }
}
