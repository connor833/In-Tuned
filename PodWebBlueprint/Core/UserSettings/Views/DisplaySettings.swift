//
//  DisplaySettings.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 5/27/25.
//

import SwiftUI

struct DisplaySettings: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var initialMode: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
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
                
                Text("Display Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible spacer for symmetry
                Button { } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Dark Mode Setting Card
                    VStack(alignment: .leading, spacing: 16) {
                        // Header with icon
                        HStack(spacing: 12) {
                            Image(systemName: "moon.circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color("accentColor"))
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dark Mode")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Customize your app's appearance")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dark mode benefits:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Easier on the eyes in low light")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                                
                                Text("• Reduces battery usage on OLED displays")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                                
                                Text("• Matches your system preferences")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 36)
                        
                        // Toggle with modern styling
                        HStack {
                            Text("Enable Dark Mode")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $isDarkMode)
                                .labelsHidden()
                                .onChange(of: isDarkMode) { newValue in
                                    if newValue != initialMode {
                                        updateDisplayMode(isDark: newValue)
                                    }
                                }
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(
                                color: Color.black.opacity(0.08),
                                radius: 12,
                                x: 0,
                                y: 4
                            )
                    )
                    
                    // Theme Preview Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "paintbrush")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color("accentColor"))
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Theme Preview")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("See how your choice looks")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Preview content
                        VStack(spacing: 12) {
                            HStack {
                                Circle()
                                    .fill(Color("accentColor"))
                                    .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray3))
                                        .frame(width: 120, height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 80, height: 6)
                                }
                                
                                Spacer()
                            }
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .frame(height: 60)
                                .overlay(
                                    Text("Sample content preview")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                )
                        }
                        .padding(.leading, 36)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(
                                color: Color.black.opacity(0.08),
                                radius: 12,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            initialMode = isDarkMode
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Display Update"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func updateDisplayMode(isDark: Bool) {
        // Update the app's color scheme
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
        }
        
        alertMessage = "Display mode updated successfully"
        showAlert = true
        initialMode = isDark
    }
}

#Preview {
    DisplaySettings()
}
