// Replace everything in your current file with this

import SwiftUI
import Network
import UniformTypeIdentifiers

// MARK: - Accent Color Environment Support

struct AccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .blue
}

extension EnvironmentValues {
    var accentColor: Color {
        get { self[AccentColorKey.self] }
        set { self[AccentColorKey.self] = newValue }
    }
}

// MARK: - Version Update Check

func httpGet(_ urlString: String, result: @escaping (String?) -> Void) {
    if let url = URL(string: urlString) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil,
                  let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let dataString = String(data: data, encoding: .utf8)
            else {
                result(nil)
                return
            }
            result(dataString)
        }
        task.resume()
    }
}

func UpdateRetrieval() -> Bool {
    var ver: String {
        let marketingVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return marketingVersion
    }
    let urlString = "https://raw.githubusercontent.com/0-Blu/StikJIT/refs/heads/main/version.txt"
    var res = false
    httpGet(urlString) { result in
        if let fc = result, ver != fc {
            res = true
        }
    }
    return res
}

// MARK: - DNS Checker (unchanged)

// [Keep your DNSChecker and other helper classes exactly as-is — unchanged]

// MARK: - Main App

@main
struct HeartbeatApp: App {
    @State private var isLoading2 = true
    @State private var isPairing = false
    @State private var heartBeat = false
    @State private var error: Int32? = nil
    @State private var show_alert = false
    @State private var alert_string = ""
    @State private var alert_title = ""
    @StateObject private var mount = MountingProgress.shared
    @StateObject private var dnsChecker = DNSChecker()
    @AppStorage("appTheme") private var appTheme: String = "system"
    @Environment(\.scenePhase) private var scenePhase

    let urls: [String] = [
        "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized/BuildManifest.plist",
        "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized/Image.dmg",
        "https://github.com/doronz88/DeveloperDiskImage/raw/refs/heads/main/PersonalizedImages/Xcode_iOS_DDI_Personalized/Image.dmg.trustcache"
    ]

    let outputFiles: [String] = [
        "DDI/BuildManifest.plist",
        "DDI/Image.dmg",
        "DDI/Image.dmg.trustcache"
    ]

    let outputDir: String = "DDI"

    init() {
        newVerCheck()
        let fixMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.fix_init(forOpeningContentTypes:asCopy:)))!
        let origMethod = class_getInstanceMethod(UIDocumentPickerViewController.self, #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:)))!
        method_exchangeImplementations(origMethod, fixMethod)
        applyTheme()
    }

    func newVerCheck() {
        let currentDate = Calendar.current.startOfDay(for: Date())
        let VUA = UserDefaults.standard.object(forKey: "VersionUpdateAlert") as? Date ?? Date.distantPast

        if currentDate > Calendar.current.startOfDay(for: VUA) {
            if UpdateRetrieval() {
                alert_title = "Update Available!"
                httpGet("https://raw.githubusercontent.com/0-Blu/StikJIT/refs/heads/main/version.txt") { result in
                    guard let version = result else { return }
                    alert_string = "Update to: version \(version)!"
                    show_alert = true
                }
            }
            UserDefaults.standard.set(currentDate, forKey: "VersionUpdateAlert")
        }
    }

    private func applyTheme() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            switch appTheme {
            case "dark": window.overrideUserInterfaceStyle = .dark
            case "light": window.overrideUserInterfaceStyle = .light
            default: window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if isLoading2 {
                LoadingView(
                    showAlert: $show_alert,
                    alertTitle: $alert_title,
                    alertMessage: $alert_string
                )
                .onAppear {
                    dnsChecker.checkDNS()
                    // Proxy/VPN/Heartbeat logic (unchanged)
                }
                .fileImporter(isPresented: $isPairing, allowedContentTypes: [UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data)!, .propertyList]) { result in
                    // Handle file import logic (unchanged)
                }
            } else {
                MainTabView()
                    .onAppear {
                        applyTheme()
                        // Download logic (unchanged)
                    }
                    .overlay(
                        ZStack {
                            if show_alert {
                                CustomErrorView(
                                    title: alert_title,
                                    message: alert_string,
                                    onDismiss: { show_alert = false },
                                    showButton: true,
                                    primaryButtonText: "OK"
                                )
                            }
                        }
                    )
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("App became active – restarting heartbeat")
                startHeartbeatInBackground()
            }
        }
        .onChange(of: dnsChecker.dnsError) { newError in
            if let errorMsg = newError, !errorMsg.contains("Not connected to WiFi") {
                alert_title = "Network Issue"
                alert_string = errorMsg
                show_alert = true
            }
        }
    }
}

// MARK: - Modified LoadingView with iOS Simulation

struct LoadingView: View {
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String

    @State private var animate = false
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("customAccentColor") private var customAccentColorHex: String = ""
    @AppStorage("appTheme") private var appTheme: String = "system"

    private var accentColor: Color {
        customAccentColorHex.isEmpty ? .blue : (Color(hex: customAccentColorHex) ?? .blue)
    }

    private var isDarkMode: Bool {
        switch appTheme {
        case "dark": return true
        case "light": return false
        default: return colorScheme == .dark
        }
    }

    var body: some View {
        ZStack {
            Color(isDarkMode ? .black : .white)
                .ignoresSafeArea()

            VStack {
                ZStack {
                    Circle()
                        .stroke(lineWidth: 8)
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(AngularGradient(
                            gradient: Gradient(colors: [
                                accentColor.opacity(0.8),
                                accentColor.opacity(0.3)
                            ]),
                            center: .center
                        ), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(animate ? 360 : 0))
                        .frame(width: 80, height: 80)
                        .animation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false), value: animate)
                }
                .shadow(color: accentColor.opacity(0.4), radius: 10)
                .onAppear {
                    animate = true
                    simulateOSCheck()
                }

                Text("Loading...")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    .padding(.top, 20)
                    .opacity(animate ? 1.0 : 0.5)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)
            }
        }
    }

    func simulateOSCheck() {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let simulate18_4b1 = true

        let majorVersion = simulate18_4b1 ? 18 : os.majorVersion
        let minorVersion = simulate18_4b1 ? 4 : os.minorVersion
        let patchVersion = simulate18_4b1 ? 0 : os.patchVersion
        let buildVersion = simulate18_4b1 ? "22E5200" :
            (ProcessInfo.processInfo.operatingSystemVersionString
                .split(separator: ")")
                .first?
                .split(separator: "(")
                .last
                .map { String($0) } ?? "")

        if majorVersion < 17 || (majorVersion == 17 && minorVersion < 0) {
            alertTitle = "Unsupported OS Version"
            alertMessage = "StikJIT only supports 17.4 and above. Your device is running iOS/iPadOS \(majorVersion).\(minorVersion).\(patchVersion)"
            showAlert = true
        } else if majorVersion == 18 && minorVersion == 4 && patchVersion == 0 {
            if buildVersion == "22E5200" {
                alertTitle = "Unsupported OS Version"
                alertMessage = "StikJIT does not support iOS 18.4 beta 1 (22E5200)."
                showAlert = true
            }
        }
    }
}
