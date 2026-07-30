import Cocoa
import SwiftUI
import ApplicationServices
import SystemConfiguration

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusBarController: StatusBarController!
    @IBOutlet weak var menu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBarController = StatusBarController.init(menu!)
        createAboutWindow()

        if bindInput(filterCallback)  < 1 {
            print("error: Failed to capture the input device.")
            print("error:     Either the device is already captured, or input monitoring")
            print("error:     has not been allowed for this executable in 'Security & Privacy'.")
            return
        }
        if bindOutput() < 1 {
            print("error: Failed to connect to the output device. Make sure Accessibility is set in settings")
            return
        }
        loadConfiguration()
        startRunLoop()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func createAboutWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("About")
        window.contentView = NSHostingView(rootView: AboutView())
    }
    
    @IBAction func about(sender: AnyObject) {
        window.orderFront(nil)
    }
}

private var usageCodeToCharacterBiMap = BidirectionalMap<Int32, Character>(
    [
        4: "a",
        5: "b",
        6: "c",
        7: "d",
        8: "e",
        9: "f",
        10: "g",
        11: "h",
        12: "i",
        13: "j",
        14: "k",
        15: "l",
        16: "m",
        17: "n",
        18: "o",
        19: "p",
        20: "q",
        21: "r",
        22: "s",
        23: "t",
        24: "u",
        25: "v",
        26: "w",
        27: "x",
        28: "y",
        29: "z"
    ])

private extension Int32 {
    // HID Usage code to character
    var character: Character? {
        usageCodeToCharacterBiMap[self]
    }
}

let filterCallback: @convention(c) (Int32, Int32) -> Int32 = { code, flags in
    // programmed shortcuts for sizing the main window
    if
        flags & NX_COMMANDMASK != 0,
        flags & NX_ALTERNATEMASK != 0,
        flags & NX_NUMERICPADMASK != 0
    {
        switch code {
            case 80: // left arrow
                setApplicationWindow(with: .left)
                return 0
            case 82: // up arrow
                setApplicationWindow(with: .maximum)
                return 0
            case 79: // right arrow
                setApplicationWindow(with: .right)
                return 0
            default:
                break
        }
    }

    guard let character = code.character else {
        return 1
    }

    let binding = KeyBinding(flags: flags, character: character).key
    guard let appName = bindings[binding] else {
        return 1
    }

    let bundleURLOfRunningApp = runningApplicationBundlePath(forAppNamed: appName)

    if let executablePathOfRunningApp = bundleURLOfRunningApp {
        openApplication(arguments: [executablePathOfRunningApp]) { result in
            NSLog("[KMAP-RESOLVE] open result: %@", result)
        }
    } else {
        openApplication(arguments: ["-a", appName])  { result in
            NSLog("[KMAP-RESOLVE] open result: %@", result)
        }
    }

    return 0
}

struct KeyBinding: Hashable {

    struct Key: Hashable {
        let flags: Int32
        let character: UniChar
        func hash(into hasher: inout Hasher) {
            hasher.combine(flags)
            hasher.combine(character)
        }

        static func == (lhs: Key, rhs: Key) -> Bool {
            lhs.flags == rhs.flags && lhs.character == rhs.character
        }
    }

    /// Struct representation for persistent storage usage as a configuration file
    struct ConfigurationRepresentation: Codable {
        let flags: Flags
        let character: String
        let appName: String

        enum Flags: String, Codable {
            case rightCommand
            case rightShift
            case rightCommandAndRightShift

            var flags: Int32 {
                switch self {
                    case .rightShift: return 131330
                    case .rightCommand: return 1048850
                    case .rightCommandAndRightShift: return 1179922
                }
            }
        }
    }

    let applicationNameToActivate: String
    let key: Key

    init(flags: Int32, character: Character, appName: String = "") {
        let char = String(character) as NSString
        self.key = Key(flags: flags, character: char.character(at: 0))
        self.applicationNameToActivate = appName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }

    static func ==(lhs: KeyBinding, rhs: KeyBinding) -> Bool {
        lhs.key == rhs.key
    }
}

// The initializer here is loading the default bindings.
private var defaultBindings: [KeyBinding] = [
    .init(flags: .rightShift, character: "c", appName: "Google Chrome"),
    .init(flags: .rightCommandAndRightShift, character: "s", appName: "Safari"),
    .init(flags: .rightShift, character: "x", appName: "Xcode"),
    .init(flags: .rightShift, character: "p", appName: "Mail"),
    .init(flags: .rightShift, character: "s", appName: "Slack"),
    .init(flags: .rightCommandAndRightShift, character: "x", appName: "XCLink"),
    .init(flags: .rightShift, character: "m", appName: "Messages"),
    .init(flags: .rightShift, character: "i", appName: "Calendar"),
    .init(flags: .rightShift, character: "t", appName: "Terminal"),
    .init(flags: .rightCommandAndRightShift, character: "o", appName: "iOS Toolbox"),
    .init(flags: .rightCommandAndRightShift, character: "p", appName: "System Preferences"),
    .init(flags: .rightShift, character: "a", appName: "Activity Monitor"),
    .init(flags: .rightShift, character: "u", appName: "Sublime Text"),
    .init(flags: .rightShift, character: "f", appName: "Finder"),
    .init(flags: .rightCommandAndRightShift, character: "f", appName: "Console"),
    .init(flags: .rightCommandAndRightShift, character: "i", appName: "In App Messages Utility App"),
    .init(flags: .rightShift, character: "h", appName: "Charles"),
    .init(flags: .rightShift, character: "g", appName: "GitHub Desktop"),
    .init(flags: .rightShift, character: "e", appName: "Radar"),
    .init(flags: .rightShift, character: "l", appName: "SourceEdit"),
    .init(flags: .rightShift, character: "v", appName: "Visual Studio Code"),
    .init(flags: .rightShift, character: "o", appName: "Spotify"),
    .init(flags: .rightShift, character: "b", appName: "Music"),
    .init(flags: .rightShift, character: "n", appName: "Postman"),
    .init(flags: .rightShift, character: "r", appName: "Reminders"),
    .init(flags: .rightShift, character: "q", appName: "Simulator"),
]

private var bindings: [KeyBinding.Key: String] = [:]

extension Int32 {
    static var rightShift: Int32 { 131330 }
    static var rightCommand: Int32 { 1048850 }
    static var rightCommandAndRightShift: Int32 { 1179922 }
}

func loadBindings() -> [KeyBinding.Key: String]? {
    let fm = FileManager.default
    // URL for /Users
    guard let usersDirectoryURL = fm.urls(for: .userDirectory, in: .allDomainsMask).first else {
        NSLog("Unable to load url from user directory.  Please check application permissions")
        return nil
    }

    let username = getUsername()
    // URL for /Users/<username>/
    let userDirectoryURL = usersDirectoryURL.appendingPathComponent(username)
    // URL for /Users/<username>/.KeyMappingConfig.json
    let configurationFileURL = userDirectoryURL.appendingPathComponent(".KeyMappingConfig.json")

    var keyBindings: [KeyBinding] = []
    do {
        let data = try Data(contentsOf: configurationFileURL)
        let keyBindingsConfigurationArray = try JSONDecoder().decode([KeyBinding.ConfigurationRepresentation].self, from: data)
        keyBindings = keyBindingsConfigurationArray.map {
            KeyBinding(flags: $0.flags.flags, character: Character($0.character), appName: $0.appName)
        }

    } catch {
        NSLog("Error loading config file \(error)")
        keyBindings = defaultBindings
    }

    if keyBindings.isEmpty {
        NSLog("Empty key bindings found from Config File. Loading in-memory defaults")
        keyBindings = defaultBindings
    }

    var dictionaryResult: [KeyBinding.Key: String] = [:]
    keyBindings.forEach {
        dictionaryResult[$0.key] = $0.applicationNameToActivate
    }
    return dictionaryResult
}

func getUsername() -> String {
    var uid: uid_t = 0
    var gid: gid_t = 0
    guard let username = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid) else {
        return NSUserName()  // we're probably running as root but whatever
    }

    return username as String
}

func loadConfiguration() {
    if let loadedBindings = loadBindings() {
        bindings = loadedBindings
    } else {
        NSLog("Error loading config file.  Using hard-coded defaults instead")
    }
}

/// Resolves the on-disk bundle path of an already-running instance of `appName`.
///
/// We prefer an already-running instance over letting `open -a <name>` resolve the
/// name, so that we re-activate the exact copy the user already has open rather
/// than whichever one LaunchServices feels like picking (there are several Xcodes
/// on this machine).
///
/// The matching has to be strict, and specifically it must never return an XPC
/// service. `Quick Look Simulator.app` — buried inside QuickLookUI.framework — is
/// the system's registered Viewer for `com.apple.xpc-service`, so handing `open`
/// *any* `.xpc` path launches it. It is `.regular` and never quits, which is why
/// this looked like a LaunchServices bug that needed a reboot.
///
/// This used to be `localizedName.contains(appName)`, which matched XPC services
/// constantly:
///   - "Simulator"   matched "SimulatorTrampoline" (CoreSimulator .xpc)
///   - "ChatGPT.app" matched "Dock Extra (ChatGPT.app)" (Dock's per-app .xpc helper,
///                   which embeds the .app-suffixed name in its display name)
/// Either one resolved to a `.xpc` bundle and therefore opened Quick Look Simulator.
func runningApplicationBundlePath(forAppNamed appName: String) -> String? {
    // Config entries are written both ways ("Messages" and "Messages.app"), but
    // `localizedName` never carries the extension.
    let wantedName = appName.hasSuffix(".app") ? String(appName.dropLast(4)) : appName

    let candidates = NSWorkspace.shared.runningApplications.filter { app in
        guard
            // Background agents, XPC services and .appex extensions are never
            // something we want to hand to `open`.
            app.activationPolicy == .regular,
            let bundleURL = app.bundleURL,
            bundleURL.pathExtension == "app",
            // A bindable app is a top-level bundle, not one nested inside a
            // framework or another app's bundle.
            !bundleURL.pathComponents.dropLast().contains(where: {
                $0.hasSuffix(".framework") || $0.hasSuffix(".app") || $0.hasSuffix(".xpc") || $0.hasSuffix(".appex")
            }),
            let name = app.localizedName
        else {
            return false
        }

        // Anchored, so we still match a version-suffixed name like "Charles 4",
        // but never one that merely contains the binding ("Quick Look Simulator",
        // "Dock Extra (ChatGPT.app)", "Google Messages").
        return name.range(of: wantedName, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
    }

    // Shortest name wins, so a plain "Xcode" beats "Xcode Previews".
    let match = candidates.min(by: { ($0.localizedName?.count ?? .max) < ($1.localizedName?.count ?? .max) })
    NSLog("[KMAP-RESOLVE] \"%@\" -> %@ (%d running candidates)",
          appName, match?.bundleURL?.path ?? "no running match, falling back to `open -a`", candidates.count)
    return match?.bundleURL?.path
}

// We have to use NSTask
// because NSRunningApplication is unreliable
func openApplication(arguments: [String], completion: @escaping (String) -> Void) {
    DispatchQueue.global(priority: .high).async {
        let pipe = Pipe()
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = arguments
        task.standardOutput = pipe
        let file = pipe.fileHandleForReading
        task.launch()
        if let result = NSString(data: file.readDataToEndOfFile(), encoding: String.Encoding.utf8.rawValue) {
            completion(result as String)
        } else {
            completion("--- Error running command - Unable to initialize string from file data ---")
        }
    }
}

enum WindowPosition {
    case left
    case right
    case maximum
}

func setApplicationWindow(
    with position: WindowPosition,
    using screen: NSScreen? = nil
) {
    let workspace = NSWorkspace.shared
    guard
        let frontmostApplication = workspace.frontmostApplication ?? workspace.runningApplications.first(where: { $0.isActive }),
        let screen = screen ?? KeyMapping.screen(for: frontmostApplication)
    else {
        return
    }

    let appRef = AXUIElementCreateApplication(frontmostApplication.processIdentifier)
    var frontWindow: CFTypeRef?
    AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &frontWindow)

    guard
        let frontWindow = frontWindow,
        let sizeKey = AXValueType(rawValue: kAXValueCGSizeType),
        let positionKey = AXValueType(rawValue: kAXValueCGPointType)
    else {
        return
    }

    let deviceDescriptionKey = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
    let displayID = screen.deviceDescription[deviceDescriptionKey] as? UInt32 ?? 1
    let screenFrame = CGDisplayBounds(displayID)
    var screenSize = screen.frame.size
    var halfScreenSize = NSSize(width: screenFrame.size.width / 2, height: screenFrame.size.height)
    switch position {
        case .left:
            let oldPosition = windowPosition(frontWindow)
            let oldSize = windowSize(frontWindow)
            guard let size = AXValueCreate(sizeKey, &halfScreenSize) else { return }
            // Won't let me conditional cast.... 'Conditional downcast to CoreFoundation type 'AXUIElement' will always succeed'
            AXUIElementSetAttributeValue(frontWindow as! AXUIElement, kAXSizeAttribute as CFString, size)

            var position = screenFrame.origin
            // Shift to the left screen if already in position
            if
                oldPosition.x == position.x,
                oldSize != screenSize,
                let leftScreen = screenToTheLeft(of: screen)
            {
                setApplicationWindow(with: .right, using: leftScreen)
                return
            }

            guard let positionValue = AXValueCreate(positionKey, &position) else { return }
            AXUIElementSetAttributeValue(frontWindow as! AXUIElement, kAXPositionAttribute as CFString, positionValue)
        case .right:
            let oldPosition = windowPosition(frontWindow)
            let oldSize = windowSize(frontWindow)
            guard let size = AXValueCreate(sizeKey, &halfScreenSize) else { return }
            // Won't let me conditional cast.... 'Conditional downcast to CoreFoundation type 'AXUIElement' will always succeed'
            AXUIElementSetAttributeValue(frontWindow as! AXUIElement, kAXSizeAttribute as CFString, size)

            let newSize = windowSize(frontWindow)
            var position = CGPoint(x: screenFrame.maxX - newSize.width, y: screenFrame.origin.y)
            if // Shift to the right screen if already in position
                oldPosition.x == position.x,
                oldSize != screenSize,
                let rightScreen = screenToTheRight(of: screen)
            {
                setApplicationWindow(with: .left, using: rightScreen)
                return
            }
            guard let positionValue = AXValueCreate(positionKey, &position) else { return }
            AXUIElementSetAttributeValue(frontWindow as! AXUIElement, kAXPositionAttribute as CFString, positionValue)
        case .maximum:
            var position = screenFrame.origin
            guard let positionValue = AXValueCreate(positionKey, &position) else { return }
            AXUIElementSetAttributeValue(frontWindow as! AXUIElement, kAXPositionAttribute as CFString, positionValue)

            guard let size = AXValueCreate(sizeKey, &screenSize) else { return }
            // Won't let me conditional cast.... 'Conditional downcast to CoreFoundation type 'AXUIElement' will always succeed'
            AXUIElementSetAttributeValue(frontWindow as! AXUIElement, kAXSizeAttribute as CFString, size)
    }
}

func windowSize(_ window: CFTypeRef) -> CGSize {
    var newSizeValue: CFTypeRef?
    AXUIElementCopyAttributeValue(window as! AXUIElement, kAXSizeAttribute as CFString, &newSizeValue)

    var newSize: CGSize = CGSize.zero
    AXValueGetValue(newSizeValue as! AXValue, AXValueType.cgSize, &newSize)
    return newSize
}

func windowPosition(_ window: CFTypeRef) -> CGPoint {
    var newPositionValue: CFTypeRef?
    AXUIElementCopyAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, &newPositionValue)

    var newPosition: CGPoint = CGPoint.zero
    AXValueGetValue(newPositionValue as! AXValue, AXValueType.cgPoint, &newPosition)
    return newPosition
}

func screenToTheRight(of screen: NSScreen) -> NSScreen? {
    // Get the frame of the input screen
    let targetFrame = screen.frame

    // Filter all screens that are positioned to the right of the given screen
    let screensToRight = NSScreen.screens.filter { otherScreen in
        let otherFrame = otherScreen.frame

        // Check if the other screen is to the right of the target screen (considering overlaps)
        return otherFrame.minX >= targetFrame.maxX
    }

    // Get the screen with the smallest `minX`, which is the closest to the right of the target screen
    return screensToRight.min { $0.frame.minX < $1.frame.minX }
}

func screenToTheLeft(of screen: NSScreen) -> NSScreen? {
    // Get the frame of the input screen
    let targetFrame = screen.frame

    // Filter all screens that are positioned to the left of the given screen
    let screensToLeft = NSScreen.screens.filter { otherScreen in
        let otherFrame = otherScreen.frame

        // Check if the other screen is to the left of the target screen (considering overlaps)
        return otherFrame.maxX <= targetFrame.minX
    }

    // Get the screen with the largest `maxX`, which is the closest to the left of the target screen
    return screensToLeft.max { $0.frame.maxX < $1.frame.maxX }
}

func screen(for app: NSRunningApplication) -> NSScreen? {
    let pid = app.processIdentifier
    // Get the list of all windows
    guard
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    else {
        return nil
    }

    for window in windowList {
        // Filter based on the application's PID
        // Get window bounds
        guard
            let windowPID = window[kCGWindowOwnerPID as String] as? pid_t,
            windowPID == pid,
            let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat]
        else {
            continue
        }

        let windowRect = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        // Check against screens
        var chosenScreen: NSScreen?
        var maxIntersectionArea: CGFloat = 0

        for screen in NSScreen.screens {
            let intersectionRect = screen.frame.intersection(windowRect)
            let intersectionArea = intersectionRect.width * intersectionRect.height

            if intersectionArea > maxIntersectionArea {
                maxIntersectionArea = intersectionArea
                chosenScreen = screen
            }
        }

        if let screen = chosenScreen {
            return screen
        }

        // Fallback to the original behavior if no intersection is found
        for screen in NSScreen.screens {
            if screen.frame.intersects(windowRect) {
                return screen
            }
        }
    }

    return nil
}
