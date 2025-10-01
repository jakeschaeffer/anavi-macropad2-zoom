import Foundation
import CoreGraphics
import IOKit.hid

private let vendorID: Int = 0xCEEB
private let productID: Int = 0x0002
private let rawUsagePage: Int = 0xFF60
private let rawUsage: Int = 0x0061

private let messageMagic: UInt8 = 0xA5
private let messageTypeScroll: UInt8 = 0x01
private let messageTypeConfig: UInt8 = 0x81
private let reportLength: Int = 32

private struct SmoothScrollConfig: Codable {
    var hostStepPixels: UInt8 = 3
    var hostIntervalMs: UInt8 = 5
    var damping: Double = 0.28
    var maxStepPerFrame: Double = 6.0
    var minimumOutputMagnitude: Double = 0.4

    func sanitized() -> SmoothScrollConfig {
        var copy = self
        copy.hostStepPixels = max(1, copy.hostStepPixels)
        copy.hostIntervalMs = max(1, copy.hostIntervalMs)
        copy.damping = max(0.01, min(copy.damping, 1.0))
    copy.maxStepPerFrame = max(1.0, max(copy.maxStepPerFrame, Double(copy.hostStepPixels)))
        copy.minimumOutputMagnitude = max(0.1, copy.minimumOutputMagnitude)
        return copy
    }
}

private func configurationFileURL() -> URL {
    let fm = FileManager.default
    let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
    let directory = base.appendingPathComponent("SmoothScrollDaemon", isDirectory: true)
    if !fm.fileExists(atPath: directory.path) {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    return directory.appendingPathComponent("config.json", isDirectory: false)
}

private func loadConfiguration() -> SmoothScrollConfig {
    let url = configurationFileURL()
    guard let data = try? Data(contentsOf: url) else {
        return SmoothScrollConfig().sanitized()
    }

    do {
        return try JSONDecoder().decode(SmoothScrollConfig.self, from: data).sanitized()
    } catch {
        fputs("[smooth-scroll-daemon] Failed to parse config.json (\(error.localizedDescription)). Using defaults.\n", stderr)
        return SmoothScrollConfig().sanitized()
    }
}

private class ScrollEngine {
    private let queue = DispatchQueue(label: "smooth-scroll-engine")
    private var accumulator: Double = 0
    private var timer: DispatchSourceTimer?
    private var damping: Double
    private var maxStepPerFrame: Double
    private var frameInterval: DispatchTimeInterval
    private var minimumOutputMagnitude: Double

    init(config: SmoothScrollConfig) {
        damping = config.damping
        maxStepPerFrame = config.maxStepPerFrame
        frameInterval = .milliseconds(Int(config.hostIntervalMs))
        minimumOutputMagnitude = config.minimumOutputMagnitude
        startTimer()
    }

    func updateConfiguration(step: UInt8, intervalMs: UInt8) {
        queue.async {
            if step > 0 {
                self.maxStepPerFrame = Double(step)
            }
            if intervalMs > 0 {
                self.frameInterval = .milliseconds(Int(intervalMs))
                self.resetTimer()
            }
        }
    }

    func enqueue(vertical delta: Int16) {
        queue.async {
            self.accumulator += Double(delta)
        }
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: frameInterval, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            self?.drain()
        }
        timer.resume()
        self.timer = timer
    }

    private func resetTimer() {
        timer?.cancel()
        timer = nil
        startTimer()
    }

    private func drain() {
        guard abs(accumulator) > 0.1 else {
            return
        }

        var delta = accumulator * damping
        if delta > maxStepPerFrame {
            delta = maxStepPerFrame
        } else if delta < -maxStepPerFrame {
            delta = -maxStepPerFrame
        }

        if abs(delta) < minimumOutputMagnitude {
            delta = delta.sign == .minus ? -minimumOutputMagnitude : minimumOutputMagnitude
        }

        accumulator -= delta
        postScrollEvent(pixels: Int32(delta.rounded()))
    }

    private func postScrollEvent(pixels: Int32) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil,
                                  units: .pixel,
                                  wheelCount: 1,
                                  wheel1: pixels,
                                  wheel2: 0,
                                  wheel3: 0) else {
            return
        }

        event.setIntegerValueField(CGEventField.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(CGEventField.scrollWheelEventMomentumPhase, value: pixels == 0 ? 0 : 1)
        event.setIntegerValueField(CGEventField.scrollWheelEventScrollPhase, value: pixels == 0 ? 0 : 1)

        event.post(tap: CGEventTapLocation.cgSessionEventTap)
    }
}

private class HIDListener {
    private let manager: IOHIDManager
    private let config: SmoothScrollConfig
    private let scrollEngine: ScrollEngine
    private var reportBuffers: [IOHIDDevice: UnsafeMutablePointer<UInt8>] = [:]

    init(config: SmoothScrollConfig) {
        self.config = config
        self.scrollEngine = ScrollEngine(config: config)
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func start() throws {
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDictionaries() as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceMatchedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemovedCallback, context)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: [NSLocalizedDescriptionKey: "Unable to open HID manager: \(result)"])
        }

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    private func matchingDictionaries() -> [[String: Any]] {
        return [
            [
                kIOHIDVendorIDKey: vendorID,
                kIOHIDProductIDKey: productID,
                kIOHIDDeviceUsagePageKey: rawUsagePage,
                kIOHIDDeviceUsageKey: rawUsage
            ]
        ]
    }

    fileprivate func registerDevice(_ device: IOHIDDevice) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportLength)
        buffer.initialize(repeating: 0, count: reportLength)
        reportBuffers[device] = buffer

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buffer, CFIndex(reportLength), inputReportCallback, context)

        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        print("[smooth-scroll-daemon] attached RAW HID device: \(productName(for: device) ?? "unknown")")

        sendConfiguration(to: device)
    }

    fileprivate func unregisterDevice(_ device: IOHIDDevice) {
        if let buffer = reportBuffers.removeValue(forKey: device) {
            buffer.deallocate()
        }
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        print("[smooth-scroll-daemon] detached RAW HID device: \(device)")
    }

    fileprivate func handle(report pointer: UnsafePointer<UInt8>, length: CFIndex) {
        guard length >= 8 else { return }
        let count = Int(length)
        let bytes = UnsafeBufferPointer(start: pointer, count: count)
        guard bytes[0] == messageMagic else { return }

        switch bytes[1] {
        case messageTypeScroll:
            let vertical = Int16(bitPattern: UInt16(bytes[2]) | (UInt16(bytes[3]) << 8))
            scrollEngine.enqueue(vertical: vertical)
        case messageTypeConfig:
            let step = bytes[2]
            let interval = bytes[3]
            scrollEngine.updateConfiguration(step: step, intervalMs: interval)
        default:
            return
        }
    }

    private func productName(for device: IOHIDDevice) -> String? {
        guard let cfValue = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) else {
            return nil
        }
        return cfValue as? String
    }

    private func sendConfiguration(to device: IOHIDDevice) {
        var payload = [UInt8](repeating: 0, count: reportLength)
        payload[0] = messageMagic
        payload[1] = messageTypeConfig
    payload[2] = config.hostStepPixels
    payload[3] = config.hostIntervalMs

        let result = payload.withUnsafeMutableBufferPointer { buffer -> IOReturn in
            guard let base = buffer.baseAddress else { return kIOReturnError }
            return IOHIDDeviceSetReport(device,
                                        kIOHIDReportTypeOutput,
                                        CFIndex(0),
                                        base,
                                        buffer.count)
        }

        if result != kIOReturnSuccess {
            fputs("[smooth-scroll-daemon] failed to push configuration (\(result))\n", stderr)
        }
    }
}

private func deviceMatchedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice!) {
    guard result == kIOReturnSuccess,
          let context = context,
          let device = device else { return }

    let listener = Unmanaged<HIDListener>.fromOpaque(context).takeUnretainedValue()
    listener.registerDevice(device)
}

private func deviceRemovedCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, device: IOHIDDevice!) {
    guard let context = context,
          let device = device else { return }

    let listener = Unmanaged<HIDListener>.fromOpaque(context).takeUnretainedValue()
    listener.unregisterDevice(device)
}

private func inputReportCallback(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, type: IOHIDReportType, reportID: UInt32, report: UnsafeMutablePointer<UInt8>, reportLength: CFIndex) {
    guard result == kIOReturnSuccess,
          let context = context else { return }

    let listener = Unmanaged<HIDListener>.fromOpaque(context).takeUnretainedValue()
    listener.handle(report: UnsafePointer(report), length: reportLength)
}

private func mainLoop() {
    let config = loadConfiguration()
    print("[smooth-scroll-daemon] config: step=\(config.hostStepPixels) interval=\(config.hostIntervalMs) damping=\(String(format: "%.3f", config.damping)) maxStepPerFrame=\(String(format: "%.2f", config.maxStepPerFrame)) minOutput=\(String(format: "%.2f", config.minimumOutputMagnitude))")
    let listener = HIDListener(config: config)

    do {
        try listener.start()
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }

    CFRunLoopRun()
}

mainLoop()
