import AppKit
import CoreFoundation
import CoreGraphics
import Foundation
import IOKit
import IOKit.graphics
import os.log

// Data structure representing a single display
struct DisplayInfo: CustomStringConvertible {
    let id: CGDirectDisplayID
    let uuid: UUID?
    let isBuiltin: Bool
    let isMain: Bool
    let isOnline: Bool
    let isActive: Bool

    var isExternal: Bool { !isBuiltin }

    var description: String {
        var parts: [String] = []
        parts.append(String(format: "Display 0x%08X", id))
        if let uuid { parts.append("uuid=\(uuid.uuidString)") }
        parts.append(isBuiltin ? "[Built‑in]" : "[External]")
        if isMain { parts.append("[Main]") }
        return parts.joined(separator: " ")
    }
}

// Class to manage and query displays
class DisplayManager {
    private let logger = LoggerUtility.createLogger(category: "DisplayManager")

    /// Returns an array of all active displays in the system
    /// - Returns: Array of DisplayInfo objects
    func getActiveDisplays() -> [DisplayInfo] {
        logger.info("Querying active displays")

        // Query active display list
        var displayCount: UInt32 = 0
        var err = CGGetActiveDisplayList(0, nil, &displayCount)

        guard err == .success, displayCount > 0 else {
            logger.warning("No active displays found or error occurred")
            return []
        }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        err = CGGetActiveDisplayList(displayCount, &ids, &displayCount)

        guard err == .success else {
            logger.error("Failed to get display list: \(err.rawValue)")
            return []
        }

        logger.info("Found \(displayCount) active displays")

        return ids.compactMap { did in
            let isOnline = CGDisplayIsOnline(did) != 0
            let isActive = CGDisplayIsActive(did) != 0
            let isBuiltin = CGDisplayIsBuiltin(did) != 0
            let isMain = CGDisplayIsMain(did) != 0

            // CFUUID? -> UUID?
            let uuid: UUID? = {
                guard let cf = CGDisplayCreateUUIDFromDisplayID(did)?.takeRetainedValue() else {
                    return nil
                }
                let s = CFUUIDCreateString(nil, cf) as String
                return UUID(uuidString: s)
            }()

            return DisplayInfo(
                id: did,
                uuid: uuid,
                isBuiltin: isBuiltin,
                isMain: isMain,
                isOnline: isOnline,
                isActive: isActive
            )
        }
    }

    /// Checks if any external displays are connected
    /// - Returns: True if at least one external display is connected
    func hasExternalDisplays() -> Bool {
        let displays = getActiveDisplays()
        let externalDisplays = displays.filter { $0.isExternal }
        let result = !externalDisplays.isEmpty

        logger.info(
            "External displays connected: \(result) (found \(externalDisplays.count) external displays)"
        )
        return result
    }

    /// Returns counts of different display types
    /// - Returns: Tuple with counts of (total, built-in, external) displays
    func getDisplayCounts() -> (total: Int, builtIn: Int, external: Int) {
        let displays = getActiveDisplays()
        let builtInCount = displays.filter { !$0.isExternal }.count
        let externalCount = displays.filter { $0.isExternal }.count
        let totalCount = displays.count

        logger.info(
            "Display counts - Total: \(totalCount), Built-in: \(builtInCount), External: \(externalCount)"
        )
        return (totalCount, builtInCount, externalCount)
    }

    /// Gets information about a specific registry property
    /// - Parameters:
    ///   - service: The IOKit service
    ///   - key: The property key
    /// - Returns: Property value as UInt32
    private func ioRegistryInt(_ service: io_service_t, key: String) -> UInt32 {
        guard
            let cf = IORegistryEntryCreateCFProperty(
                service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        else {
            return 0
        }
        if let n = cf as? NSNumber {
            return n.uint32Value
        }
        return 0
    }

    /// Gets a registry property
    /// - Parameters:
    ///   - service: The IOKit service
    ///   - key: The property key
    /// - Returns: Property value
    private func ioRegistryProperty(_ service: io_service_t, key: String) -> Any? {
        guard
            let cf = IORegistryEntryCreateCFProperty(
                service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        else {
            return nil
        }
        return cf as Any
    }
}
