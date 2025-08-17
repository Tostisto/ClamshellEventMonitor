import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import os.log

class ClamshellMonitor {
    // Track last known state to avoid duplicate events
    private var lastClosed: Bool?

    // Event handler to call when lid state changes
    private let eventHandler: ClamshellEventHandler

    // Logging
    private let osLogger: Logger

    // IOKit resources
    private var notifyPort: IONotificationPortRef?
    private var rootDomain: io_service_t = 0
    private var notifier: io_object_t = 0

    // Store context as a class property to maintain a strong reference
    private var contextRef: Unmanaged<ClamshellMonitor>?

    init(eventHandler: ClamshellEventHandler = DefaultClamshellEventHandler()) {
        self.eventHandler = eventHandler

        // Initialize loggers
        osLogger = LoggerUtility.createLogger(category: "ClamshellMonitor")
    }

    deinit {
        stop()
        osLogger.info("ClamshellMonitor destroyed")
    }

    func start() -> Bool {
        // Create notification port and add to run loop
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else {
            osLogger.error("IONotificationPortCreate failed")
            return false
        }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)

        // Find the IOPMrootDomain service
        guard let matching = IOServiceMatching("IOPMrootDomain") else {
            osLogger.error("IOServiceMatching failed for IOPMrootDomain")
            return false
        }

        rootDomain = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard rootDomain != 0 else {
            osLogger.error("IOPMrootDomain not found")
            return false
        }

        // Create and store a strong reference to self for the callback
        contextRef = Unmanaged.passRetained(self)

        // Subscribe to property change notifications
        let kr = IOServiceAddInterestNotification(
            notifyPort,
            rootDomain,
            kIOGeneralInterest,
            clamshellCallback,
            contextRef?.toOpaque(),
            &notifier
        )

        guard kr == KERN_SUCCESS else {
            osLogger.error("IOServiceAddInterestNotification failed: \(kr)")
            // Release the retained reference if registration fails
            contextRef?.release()
            contextRef = nil
            return false
        }

        // Emit current state once at startup
        readAndProcessInitialState()

        osLogger.info("Clamshell monitor started successfully")
        return true
    }

    func stop() {
        osLogger.info("Stopping clamshell monitor")

        if notifier != 0 {
            IOObjectRelease(notifier)
            notifier = 0
        }

        if rootDomain != 0 {
            IOObjectRelease(rootDomain)
            rootDomain = 0
        }

        if let notifyPort = notifyPort {
            IONotificationPortDestroy(notifyPort)
            self.notifyPort = nil
        }

        // Release our retained reference when stopping
        contextRef?.release()
        contextRef = nil

        osLogger.info("Clamshell monitor stopped")
    }

    func readAndProcessInitialState() {
        guard rootDomain != 0 else { return }

        let key = "AppleClamshellState" as CFString
        if let unmanagedVal = IORegistryEntryCreateCFProperty(
            rootDomain, key, kCFAllocatorDefault, 0)
        {
            let val = unmanagedVal.takeRetainedValue()
            if CFGetTypeID(val) == CFBooleanGetTypeID() {
                let closed = CFBooleanGetValue((val as! CFBoolean))
                lastClosed = closed
                osLogger.info("Initial clamshell state: \(closed ? "closed" : "open")")
            }
        }
    }

    // Handler for clamshell state change
    func handleClamshellStateChange(service: io_service_t) {
        let key = "AppleClamshellState" as CFString
        if let unmanagedVal = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0)
        {
            let val = unmanagedVal.takeRetainedValue()
            if CFGetTypeID(val) == CFBooleanGetTypeID() {
                let closed = CFBooleanGetValue((val as! CFBoolean))

                // Only trigger events if state has changed
                if lastClosed == nil || lastClosed! != closed {
                    if closed {
                        osLogger.info("Lid closed event detected")
                        eventHandler.onLidClosed()
                    } else {
                        osLogger.info("Lid opened event detected")
                        eventHandler.onLidOpened()
                    }
                    lastClosed = closed
                }
            }
        }
    }
}

// C-compatible callback for IOServiceAddInterestNotification
private let clamshellCallback: IOServiceInterestCallback = { context, service, _, _ in
    guard let context = context else { return }
    let monitor = Unmanaged<ClamshellMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.handleClamshellStateChange(service: service)
}
