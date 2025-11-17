//
//  PreviewClass.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 3/15/23.
//

import SwiftUI
import Firebase

class PreviewClass: ObservableObject {
    let previewPod = Pod(title: "Best hot sauces pod", timestamp: Timestamp(date: Date()), description: "New pod cast, this is where you can learn about all the best hot sauces. With a special so guest so make sure you dont miss out! You will not regret it!", fileUrl: "https://firebasestorage.googleapis.com/v0/b/podwebtest-eb470.appspot.com/o/audio%2FColdplay_-_Paradise_(Naijay.com).mp3?alt=media&token=6b244fb8-9c41-4ee6-8767-31cfe8044a81", thumbnailUrl: "https://vehicle-images.dealerinspire.com/d88c-110006976/WP0AE2A84RS274163/f4dc3ecacdc53f93713bf9a7602094d4.jpg", userId: "1", likes: 122, didLike: false)
    
    let previewComment = Comment(caption: "This is a comment", timestamp: Timestamp(date: Date()), uid: "fdsw23423", likes: 12, replyCount: 0, isActive: true, createdAt: Timestamp(date: Date()), updatedAt: Timestamp(date: Date()), version: 1, podId: "preview-pod-id", isReported: false)
    
    let previewUser = User(uid: "PodWeb12345", username: "Pod Webbbbbbbbbbbbbb", fullname: "PodWeb", profileImageUrl: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ-LiiQQ_eAvmigj2P1O2WmJ2Vzh1cHr0vOZQ&usqp=CAU", email: "podweb@gmail.com", isVerified: true, followers: 50, following: 12, podCount: 5, bio: "Check us out for the newest news right here!")
    
    let loadingUser = User(uid: "12345", username: "", fullname: "", profileImageUrl: "", email: "", isVerified: false, followers: 0, following: 20, podCount: 56)
    
    let loadingPod = Pod(title: "", timestamp: Timestamp(date: Date()), description: "", fileUrl: "", thumbnailUrl: "", userId: "12345", likes: 0)
    
    let previewPlaylist = Playlist(title: "Testing", thumbnailUrl: "https://vehicle-images.dealerinspire.com/d88c-110006976/WP0AE2A84RS274163/f4dc3ecacdc53f93713bf9a7602094d4.jpg", userId: "123", likes: 12132)
    
    

}
