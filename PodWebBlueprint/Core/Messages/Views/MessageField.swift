//
//  ConversationView.swift
//  CryptChat
//
//  Created by Connor Adams on 8/10/22.
//

import SwiftUI

struct MessageField: View {
    // MARK: - Properties
    
    @ObservedObject var viewModel: MessageViewModel
    @State private var message = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var showingBlockedAlert = false

    var user: User
    
    // MARK: - Initialization
    
    init(user: User, viewModel: MessageViewModel) {
        self.viewModel = viewModel
        self.user = user
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            CustomTextField(placeholder: Text("New Message"), text: $message)
            
            Button {
                // Check if current user is blocked before sending
                guard !user.uid.isEmpty else {
                    print("❌ MESSAGE_FIELD: User UID is empty, cannot check blocking status")
                    return
                }
                
                viewModel.conversationService.isCurrentUserBlockedBy(userId: user.uid) { isBlocked in
                    if isBlocked {
                        print("🚫 MESSAGE_FIELD: Cannot send message - current user is blocked by \(user.username)")
                        print("🚫 MESSAGE_FIELD: Dismissing conversation view due to blocking")
                        
                        // Show blocked alert and then dismiss the conversation view
                        DispatchQueue.main.async {
                            showingBlockedAlert = true
                            
                            // Dismiss after a short delay to show the alert
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        return
                    }
                    
                    // Sanitize message before sending
                    let sanitizedMessage = InputSanitizer.clean(message, type: .message)
                    if !sanitizedMessage.isEmpty {
                        viewModel.sendMessage(user: user, text: sanitizedMessage)
                        message = ""
                    }
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(message.isEmpty ? .gray : Color("accentColor"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal)
        .padding(.vertical, 8)

        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
                .foregroundColor(Color("accentColor"))
                .font(.system(size: 16, weight: .medium))
            }
        }
        .alert("User Blocked", isPresented: $showingBlockedAlert) {
            Button("OK") { }
        } message: {
            Text("You cannot send messages to this user. The conversation will be closed.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct MessageField_Previews: PreviewProvider {
    static var previews: some View {
        MessageField(user: PreviewClass().previewUser, viewModel: MessageViewModel(user: PreviewClass().previewUser))
    }
}

struct CustomTextField: View {
    // MARK: - Properties
    
    var placeholder: Text
    @Binding var text: String
    var editingChanged: (Bool) -> () = {_ in}
    var commit: () -> () = {}
    @FocusState private var isFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        TextField("", text: $text)
            .focused($isFocused)
            .submitLabel(.done)
            .onSubmit {
                hideKeyboard()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isFocused ? Color("accentColor") : Color.gray.opacity(0.3),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isFocused ? Color("accentColor").opacity(0.2) : Color.black.opacity(0.05),
                        radius: isFocused ? 8 : 4,
                        x: 0,
                        y: isFocused ? 4 : 2
                    )
            )
            .overlay(
                // Custom placeholder
                HStack {
                    if text.isEmpty {
                        placeholder
                            .opacity(0.6)
                            .font(.system(size: 16, weight: .regular))
                            .allowsHitTesting(false)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .foregroundColor(Color("accentColor"))
                    .font(.system(size: 16, weight: .medium))
                }
            }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
}
