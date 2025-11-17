//
//  PodCategory.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import SwiftUI

// MARK: - Pod Category Enum

enum PodCategory: String, CaseIterable, Identifiable {
    case music = "Music"
    case business = "Business"
    case comedy = "Comedy"
    case education = "Education"
    case health = "Health & Fitness"
    case gaming = "Gaming"
    case news = "News"
    case science = "Science"
    case technology = "Technology"
    case sports = "Sports"
    case arts = "Arts"
    case history = "History"
    case trueCrime = "True Crime"
    case fiction = "Fiction"
    case selfHelp = "Self-Help"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .music: return "music.note"
        case .business: return "briefcase.fill"
        case .comedy: return "theatermasks.fill"
        case .education: return "book.fill"
        case .health: return "heart.fill"
        case .gaming: return "gamecontroller.fill"
        case .news: return "newspaper.fill"
        case .science: return "flask.fill"
        case .technology: return "laptopcomputer"
        case .sports: return "sportscourt.fill"
        case .arts: return "paintpalette.fill"
        case .history: return "hourglass"
        case .trueCrime: return "magnifyingglass"
        case .fiction: return "book.closed.fill"
        case .selfHelp: return "brain.head.profile"
        case .other: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .music: return .purple
        case .business: return .blue
        case .comedy: return .yellow
        case .education: return .green
        case .health: return .red
        case .gaming: return .orange
        case .news: return .gray
        case .science: return .cyan
        case .technology: return .indigo
        case .sports: return .orange
        case .arts: return .pink
        case .history: return .brown
        case .trueCrime: return .red
        case .fiction: return .purple
        case .selfHelp: return .mint
        case .other: return .secondary
        }
    }
    
    var description: String {
        switch self {
        case .music: return "Songs, albums, and music discussions"
        case .business: return "Entrepreneurship, investing, and careers"
        case .comedy: return "Standup, sketches, and humor"
        case .education: return "Learning and teaching content"
        case .health: return "Fitness, wellness, and mental health"
        case .gaming: return "Video games and gaming culture"
        case .news: return "Current events and journalism"
        case .science: return "Research, discoveries, and experiments"
        case .technology: return "Tech news, gadgets, and innovation"
        case .sports: return "Athletics, teams, and competitions"
        case .arts: return "Visual arts, design, and creativity"
        case .history: return "Historical events and stories"
        case .trueCrime: return "Mysteries, investigations, and cases"
        case .fiction: return "Stories, novels, and narratives"
        case .selfHelp: return "Personal growth and motivation"
        case .other: return "Everything else"
        }
    }
}

// MARK: - Mood/Vibe Enum

enum PodMood: String, CaseIterable, Identifiable {
    case laugh = "Make Me Laugh"
    case learn = "Learn Something"
    case chill = "Chill Vibes"
    case motivate = "Get Motivated"
    case sleep = "Relax & Unwind"
    case mindBlowing = "Mind-Blowing"
    case deep = "Deep Conversations"
    case quick = "Quick Listen"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .laugh: return "face.smiling.fill"
        case .learn: return "brain.head.profile"
        case .chill: return "leaf.fill"
        case .motivate: return "bolt.fill"
        case .sleep: return "moon.zzz.fill"
        case .mindBlowing: return "sparkles"
        case .deep: return "bubble.left.and.bubble.right.fill"
        case .quick: return "timer"
        }
    }
    
    var emoji: String {
        switch self {
        case .laugh: return "😂"
        case .learn: return "🧠"
        case .chill: return "😌"
        case .motivate: return "💪"
        case .sleep: return "😴"
        case .mindBlowing: return "🤯"
        case .deep: return "💭"
        case .quick: return "⚡"
        }
    }
    
    var description: String {
        switch self {
        case .laugh: return "Comedy and lighthearted content"
        case .learn: return "Educational and informative"
        case .chill: return "Relaxing and easy listening"
        case .motivate: return "Inspirational and energizing"
        case .sleep: return "Calm stories and meditation"
        case .mindBlowing: return "Thought-provoking and fascinating"
        case .deep: return "Philosophical and meaningful"
        case .quick: return "Under 10 minutes"
        }
    }
    
    // Categories that match this mood
    var matchingCategories: [PodCategory] {
        switch self {
        case .laugh: return [.comedy]
        case .learn: return [.education, .science, .history, .technology]
        case .chill: return [.music, .arts, .fiction]
        case .motivate: return [.selfHelp, .health, .business]
        case .sleep: return [.fiction, .music]
        case .mindBlowing: return [.science, .technology, .trueCrime]
        case .deep: return [.education, .science, .history]
        case .quick: return [] // Duration-based, not category
        }
    }
}

// MARK: - Explore Section Enum

enum ExploreSection: String, CaseIterable, Identifiable {
    case trending = "Trending Now"
    case newAndNoteworthy = "New & Noteworthy"
    case topCharts = "Top Charts"
    case featured = "Featured"
    case categories = "Browse Categories"
    case moods = "By Mood"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .trending: return "flame.fill"
        case .newAndNoteworthy: return "sparkles"
        case .topCharts: return "chart.bar.fill"
        case .featured: return "star.fill"
        case .categories: return "square.grid.2x2.fill"
        case .moods: return "face.smiling"
        }
    }
    
    var description: String {
        switch self {
        case .trending: return "What's hot right now"
        case .newAndNoteworthy: return "Fresh uploads worth checking out"
        case .topCharts: return "All-time favorites"
        case .featured: return "Curated picks from our team"
        case .categories: return "Discover by topic"
        case .moods: return "Find your vibe"
        }
    }
    
    var color: Color {
        switch self {
        case .trending: return .orange
        case .newAndNoteworthy: return .purple
        case .topCharts: return .blue
        case .featured: return .yellow
        case .categories: return .green
        case .moods: return .pink
        }
    }
}
