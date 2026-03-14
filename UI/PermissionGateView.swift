//
//  PermissionGateView.swift
//  KeyExpander
//
//  Created by Lenie Joice on 3/14/26.
//


import SwiftUI
import ApplicationServices
 
struct PermissionGateView: View {
    var onPermissionsGranted: () -> Void
 
    @State private var accessibilityGranted: Bool = false
    @State private var inputMonitoringGranted: Bool = false
    @State private var pollTimer: Timer? = nil
 
    var bothGranted: Bool { accessibilityGranted && inputMonitoringGranted }
 
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
 
            VStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary)
 
                Text("KeyExpander needs two permissions")
                    .font(.title3)
                    .fontWeight(.medium)
 
                Text("These are required to detect what you type and expand snippets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .padding(.bottom, 28)
 
            VStack(spacing: 10) {
                PermissionRow(
                    icon: "hand.raised",
                    title: "Accessibility",
                    subtitle: "Lets KeyExpander read keystrokes",
                    isGranted: accessibilityGranted
                )
 
                PermissionRow(
                    icon: "keyboard",
                    title: "Input Monitoring",
                    subtitle: "Lets KeyExpander expand snippets",
                    isGranted: inputMonitoringGranted
                )
            }
            .frame(maxWidth: 400)
            .padding(.bottom, 16)
 
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
 
                Text("Once both permissions are granted, this screen will dismiss automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 360)
            .padding(.bottom, 24)
 
            Button {
                openPrivacySettings()
            } label: {
                Text("Open Privacy & Security Settings")
                    .frame(maxWidth: 300)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
 
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            checkPermissions()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }
 
 
    private func checkPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
            as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        inputMonitoringGranted = testInputMonitoringAccess()
    }
 
    private func testInputMonitoringAccess() -> Bool {
        let dummyCallback: CGEventTapCallBack = { _, _, event, _ in
            Unmanaged.passUnretained(event)
        }
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: dummyCallback,
            userInfo: nil
        )
        if let tap {
            CFMachPortInvalidate(tap)
            return true
        }
        return false
    }
 
 
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            checkPermissions()
            if bothGranted {
                stopPolling()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    onPermissionsGranted()
                }
            }
        }
    }
 
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
 
 
    private func openPrivacySettings() {
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            as CFDictionary
        AXIsProcessTrustedWithOptions(promptOptions)
 
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
 
 
private struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
 
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 36, height: 36)
 
                Image(systemName: isGranted ? "checkmark" : icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isGranted ? .green : .secondary)
            }
 
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
 
            Spacer()
 
            Text(isGranted ? "Granted" : "Required")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    isGranted
                        ? Color.green.opacity(0.15)
                        : Color.orange.opacity(0.12)
                )
                .foregroundStyle(isGranted ? .green : .orange)
                .clipShape(Capsule())
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isGranted ? Color.green.opacity(0.3) : Color.secondary.opacity(0.15),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isGranted)
    }
}
 
