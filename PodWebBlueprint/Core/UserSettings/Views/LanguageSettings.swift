//
//  LanguageSettings.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 5/27/25.
//

import SwiftUI

struct LanguageSettings: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("selectedLanguage") private var selectedLanguage = "en"
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    let languages = [
        Language(code: "en", name: "English", nativeName: "English"),
        Language(code: "es", name: "Spanish", nativeName: "Español"),
        Language(code: "zh", name: "Chinese", nativeName: "中文")
    ]
    
    var body: some View {
        VStack {
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
                
                Text("Language Settings")
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
            
            VStack(alignment: .leading, spacing: 20) {
                Text("Language")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select your preferred language")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                LazyVStack(spacing: 0) {
                    ForEach(languages, id: \.code) { language in
                        LanguageRow(
                            language: language,
                            isSelected: selectedLanguage == language.code
                        ) {
                            selectedLanguage = language.code
                            updateLanguage(language.code)
                        }
                        
                        if language.code != languages.last?.code {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Language Updated"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationBarHidden(true)
    }
    
    private func updateLanguage(_ languageCode: String) {
        // Update the app's language preference
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        let languageName = languages.first { $0.code == languageCode }?.name ?? "Unknown"
        alertMessage = "Language updated to \(languageName). Restart the app to see changes."
        showAlert = true
    }
}

struct Language {
    let code: String
    let name: String
    let nativeName: String
}

struct LanguageRow: View {
    let language: Language
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.nativeName)
                        .font(.headline)
                        .foregroundColor(Color("textColor"))
                    
                    Text(language.name)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(Color("accentColor"))
                        .font(.headline)
                }
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    LanguageSettings()
}
