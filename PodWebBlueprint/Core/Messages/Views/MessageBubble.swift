//
//  MessageBubble.swift
//  CryptChat
//
//  Created by Connor Adams on 8/10/22.
//

import SwiftUI
import Firebase
import Kingfisher
import FirebaseAuth

struct MessageBubble: View {
    // MARK: - Properties
    
    var message: Message
    @State private var showTime = false
    var currentUid = Auth.auth().currentUser?.uid
    @ObservedObject var messageBubbleViewModel: MessageBubbleViewModel
    @ObservedObject var messageViewModel: MessageViewModel
    
    // MARK: - Initialization
    
    init(message: Message, user: User, messageViewModel: MessageViewModel) {
        self.message = message
        self.messageViewModel = messageViewModel
        self.messageBubbleViewModel = MessageBubbleViewModel(message: message, user: user)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 8) {
            VStack(alignment: message.senderId != currentUid ? .leading : .trailing) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(message.senderId != currentUid ? Color("textColor") : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                message.senderId != currentUid ? 
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(.systemGray6), Color(.systemGray5)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: message.senderId != currentUid ? 
                                Color.black.opacity(0.1) : 
                                Color("accentColor").opacity(0.3),
                                radius: message.senderId != currentUid ? 4 : 8,
                                x: 0,
                                y: message.senderId != currentUid ? 2 : 4
                            )
                    )
                    .frame(maxWidth: 280, alignment: message.senderId != currentUid ? .leading : .trailing)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showTime.toggle()
                        }
                    }
            }
            
            if showTime {
                HStack {
                    if message.senderId != currentUid {
                        Spacer()
                    }
                    
                    Text("\(message.timestamp.formatted(.dateTime.hour().minute()))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6).opacity(0.8))
                        )
                    
                    if message.senderId == currentUid {
                        Spacer()
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.senderId != currentUid ? .leading : .trailing)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}


