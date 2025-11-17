import SwiftUI
import Firebase

/// Comprehensive session management view for users to monitor and control their active sessions
struct SessionManagementView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var isLoading = false
    @State private var showLogoutAllAlert = false
    @State private var showRevokeDeviceAlert = false
    @State private var deviceToRevoke: DeviceSession?
    @State private var showSecurityAlerts = false
    @State private var showSessionRevokedAlert = false
    @State private var showDetailedPhoneInfo = false
    
    var body: some View {
        VStack {
            // Header with modern back button and refresh button
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color("accentColor"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color("accentColor"), lineWidth: 2)
                            )
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Session Management")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    Task {
                        await refreshSessions()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(isLoading ? "Refreshing..." : "Refresh")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color("accentColor"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color("accentColor"), lineWidth: 2)
                            )
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .disabled(isLoading)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            ScrollView {
                VStack {
                    // Session status header
                    sessionStatusHeader
                    
                    // Active devices list
                    activeDevicesList
                    
                    // Security alerts section
                    securityAlertsSection
                    
                    Spacer()
                }
            }
            .onAppear {
                Task {
                    // Try to initialize SessionManager first
                    await initializeSessionManager()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("sessionRevoked"))) { _ in
                // Handle session revocation from another device
                handleSessionRevoked()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeviceSessionRevoked"))) { notification in
                // Handle device session revocation - refresh the UI immediately
                if let deviceId = notification.object as? String {
                    Task {
                        await refreshSessions()
                    }
                }
            }
            .refreshable {
                await refreshSessions()
            }
        }
        .alert("Logout from All Devices", isPresented: $showLogoutAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout All", role: .destructive) {
                Task {
                    await logoutFromAllDevices()
                }
            }
        } message: {
            Text("This will sign you out from all devices. You'll need to sign in again on each device.")
        }
        .alert("Revoke Device", isPresented: $showRevokeDeviceAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Revoke", role: .destructive) {
                if let device = deviceToRevoke {
                    Task {
                        await revokeDevice(device)
                    }
                }
            }
        } message: {
            if let device = deviceToRevoke {
                Text("This will revoke the session for \(device.deviceName) and force it to log out.")
            }
        }
        .alert("Session Revoked", isPresented: $showSessionRevokedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your session has been revoked from another device. You may need to log in again.")
        }
        .sheet(isPresented: $showSecurityAlerts) {
            SessionSecurityAlertsView(alerts: sessionManager.securityAlerts)
        }
        .sheet(isPresented: $showDetailedPhoneInfo) {
            DetailedPhoneInfoView()
        }
    }
    
    // MARK: - Session Status Header
    
    private var sessionStatusHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.green)
                
                Text("Session Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let currentSession = sessionManager.currentSession {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Device")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(currentSession.deviceName)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Active Sessions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(sessionManager.activeDevices.count)")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    // MARK: - Active Devices List
    
    private var activeDevicesList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Devices")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Show Detailed Device Info") {
                    showDetailedPhoneInfo = true
                }
                .font(.caption)
                .foregroundColor(Color("accentColor"))
            }
            .padding(.horizontal)
            
            if sessionManager.activeDevices.isEmpty {
                VStack {
                    Image(systemName: "iphone.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No Active Sessions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("You are not currently logged in on any devices.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sessionManager.activeDevices) { device in
                        DeviceSessionRow(device: device) {
                            // Revoke action
                            deviceToRevoke = device
                            showRevokeDeviceAlert = true
                        }
                    }
                }
                .padding(.horizontal)
                
                // Logout from all devices button
                Button {
                    showLogoutAllAlert = true
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text("Logout from All Devices")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Security Alerts Section
    
    private var securityAlertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Security Alerts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !sessionManager.securityAlerts.isEmpty {
                    Button("View All") {
                        showSecurityAlerts = true
                    }
                    .font(.subheadline)
                    .foregroundColor(Color("accentColor"))
                }
            }
            .padding(.horizontal)
            
            if sessionManager.securityAlerts.isEmpty {
                HStack {
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(.green)
                    
                    Text("No security alerts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else {
                let recentAlerts = Array(sessionManager.securityAlerts.prefix(3))
                
                LazyVStack(spacing: 8) {
                    ForEach(recentAlerts) { alert in
                        SecurityAlertRow(alert: alert)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func refreshSessions() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await sessionManager.refreshActiveDevices()
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("❌ Failed to refresh sessions: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func logoutFromAllDevices() async {
        do {
            try await sessionManager.logoutFromAllDevices()
        } catch {
            print("❌ Failed to logout from all devices: \(error)")
        }
    }
    
    private func revokeDevice(_ device: DeviceSession) async {
        do {
            try await sessionManager.revokeDeviceSession(deviceId: device.deviceId)
        } catch {
            print("❌ Failed to revoke device session: \(error)")
        }
    }
    
    private func handleSessionRevoked() {
        self.showSessionRevokedAlert = true
    }
    
    private func initializeSessionManager() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Refresh the sessions to get current state
        await refreshSessions()
    }
}

// MARK: - Device Session Row

struct DeviceSessionRow: View {
    let device: DeviceSession
    let onRevoke: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Device icon
                Image(systemName: getDeviceIcon(for: device.deviceType))
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.deviceName)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if device.isCurrentDevice {
                            Text("(This Device)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(device.deviceType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Last active: \(formatTimestamp(device.lastActivity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    SessionDetailRow(label: "OS Version", value: device.osVersion)
                    SessionDetailRow(label: "App Version", value: device.appVersion)
                    SessionDetailRow(label: "Session Created", value: formatTimestamp(device.createdAt))
                    SessionDetailRow(label: "Last Activity", value: formatTimestamp(device.lastActivity))
                    
                    if let ipAddress = device.ipAddress {
                        SessionDetailRow(label: "IP Address", value: ipAddress)
                    }
                    
                    if let location = device.location {
                        if let city = location.city, let country = location.country {
                            SessionDetailRow(label: "Location", value: "\(city), \(country)")
                        } else if let country = location.country {
                            SessionDetailRow(label: "Location", value: country)
                        }
                        
                        if let timezone = location.timezone {
                            SessionDetailRow(label: "Timezone", value: timezone)
                        }
                    }
                    
                    // Revoke session button (only for non-current devices)
                    if !device.isCurrentDevice {
                        Divider()
                            .padding(.top, 8)
                        
                        Button {
                            onRevoke()
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Revoke Session")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.leading, 40)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private func getDeviceIcon(for deviceType: String) -> String {
        let lowercased = deviceType.lowercased()
        
        if lowercased.contains("iphone") {
            return "iphone"
        } else if lowercased.contains("ipad") {
            return "ipad.gen3"
        } else if lowercased.contains("macbook") {
            return "laptopcomputer"
        } else if lowercased.contains("mac") {
            return "desktopcomputer"
        } else {
            return "desktopcomputer"
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Detail Row

struct SessionDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Security Alert Row

struct SecurityAlertRow: View {
    let alert: SecurityAlert
    
    var body: some View {
        HStack {
            Image(systemName: getAlertIcon(for: alert.type))
                .font(.system(size: 16))
                .foregroundColor(getAlertColor(for: alert.severity))
                .frame(width: 24, height: 24)
                .background(getAlertColor(for: alert.severity).opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formatTimestamp(alert.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor(getAlertColor(for: alert.severity))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(getAlertColor(for: alert.severity), lineWidth: 1)
        )
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func getAlertIcon(for type: SecurityAlertType) -> String {
        switch type {
        case .locationAnomaly:
            return "location.fill"
        case .tooManySessions:
            return "person.2.fill"
        case .sessionTooOld:
            return "clock.fill"
        case .ipChanged:
            return "network"
        case .deviceRevoked:
            return "xmark.shield.fill"
        }
    }
    
    private func getAlertColor(for severity: SecuritySeverity) -> Color {
        switch severity {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
}

// MARK: - Security Alerts View

struct SessionSecurityAlertsView: View {
    let alerts: [SecurityAlert]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List(alerts) { alert in
                SecurityAlertRow(alert: alert)
            }
            .navigationTitle("Security Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Detailed Phone Info View

struct DetailedPhoneInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    deviceInfoSection
                }
                .padding()
            }
            .navigationTitle("Device Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            let device = UIDevice.current
            let bundle = Bundle.main
            
            VStack(spacing: 12) {
                InfoRow(label: "Device Name", value: device.name)
                InfoRow(label: "Device Model", value: device.model)
                InfoRow(label: "System Name", value: device.systemName)
                InfoRow(label: "System Version", value: device.systemVersion)
                InfoRow(label: "App Version", value: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                InfoRow(label: "Bundle ID", value: bundle.bundleIdentifier ?? "Unknown")
                InfoRow(label: "Device ID", value: device.identifierForVendor?.uuidString ?? "Unknown")
            }
            
            Divider()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Info Row Helper

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
            
            Spacer()
        }
    }
}
