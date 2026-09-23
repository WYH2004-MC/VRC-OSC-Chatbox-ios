import AVFoundation
import Darwin
import Speech
import UIKit

@MainActor
final class StartupPermissionController {
    private var hasStarted = false

    func requestOnLaunch() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true

        guard await waitForForeground() else { return }
        if AVAudioApplication.shared.recordPermission == .undetermined {
            await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { _ in
                    continuation.resume()
                }
            }
        }

        guard await waitForForeground() else { return }
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    continuation.resume()
                }
            }
        }

        guard await waitForForeground() else { return }
        triggerLocalNetworkPermission()
    }

    private func waitForForeground() async -> Bool {
        let activations = NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification)
        if UIApplication.shared.applicationState != .active {
            for await _ in activations {
                break
            }
        }
        return !Task.isCancelled
    }

    private func triggerLocalNetworkPermission() {
        // TN3179: connecting a UDP socket to a link-local address requests access
        // without sending traffic. iOS has no explicit local-network permission API.
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let interfaces else { return }
        defer { freeifaddrs(interfaces) }

        for entry in sequence(first: interfaces, next: { $0.pointee.ifa_next }) {
            let interface = entry.pointee
            guard interface.ifa_flags & UInt32(IFF_UP | IFF_BROADCAST) == UInt32(IFF_UP | IFF_BROADCAST),
                  let address = interface.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET6),
                  Int(address.pointee.sa_len) >= MemoryLayout<sockaddr_in6>.size else {
                continue
            }

            let source = UnsafeRawPointer(address).load(as: sockaddr_in6.self)
            let isLinkLocal = withUnsafeBytes(of: source.sin6_addr) {
                $0[0] == 0xfe && ($0[1] & 0xc0) == 0x80
            }
            guard isLinkLocal else { continue }

            for _ in 0..<2 {
                var destination = source
                destination.sin6_port = UInt16(9).bigEndian
                withUnsafeMutableBytes(of: &destination.sin6_addr) { bytes in
                    for index in 8..<16 {
                        bytes[index] = UInt8.random(in: .min ... .max)
                    }
                }

                let socket = Darwin.socket(AF_INET6, SOCK_DGRAM, 0)
                guard socket >= 0 else { continue }
                defer { Darwin.close(socket) }
                withUnsafePointer(to: &destination) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        _ = Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in6>.size))
                    }
                }
            }
        }
    }
}
