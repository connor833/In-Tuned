//
//  MessageBubbleViewModel.swift
//  CryptChat
//
//  Created by Connor Adams on 8/9/22.
//

import Foundation
import Firebase
import FirebaseFirestore
//import FirebaseFirestoreSwift
import SwiftUI

class MessageBubbleViewModel: ObservableObject {
    // MARK: - Properties
    
    var message: Message
    let user: User
    
    // MARK: - Initialization
    
    init(message: Message, user: User) {
        self.message = message
        self.user = user
        //checkIfMessageIsLiked(user: user)
    }
    
    // MARK: - Like Message
    /*
    func likeMessage(message: Message) {
        service.likeMessage(message, user: user) {
            withAnimation {
                self.message.isLiked = true
            }
        }
    }
    
    // MARK: - Unlike Message
    
    func unlikeMessage(message: Message) {
        service.unlikeMessage(message, user: user) {
            withAnimation {
                self.message.isLiked = false
            }
        }
    }
    
    // MARK: - Is Liked
    
    var isLiked: Bool {
        return message.isLiked ?? false
    }

    // MARK: - Toggle Like
    
    func toggleLike() {
        if isLiked {
            withAnimation {
                unlikeMessage(message: message)
            }
        } else {
            withAnimation {
                likeMessage(message: message)
            }
        }
    }
    
    // MARK: - Check If Message Is Liked
    
    func checkIfMessageIsLiked(user: User) {
        service.checkIfMessageIsLiked(message, user: user) { isLiked in
            if isLiked {
                self.message.isLiked = true
            }
        }
    }
     */
}
