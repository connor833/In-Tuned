//
//  AIPracticeView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/22/24.
//

import SwiftUI

struct AIPracticeView: View {
    @State private var title = ""
    @State private var description = ""
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var showingResults = false
    @State private var aiResults: (category: String, keywords: [String])?
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isDescriptionFocused: Bool
    @FocusState private var isTagInputFocused: Bool
    
    private let aiProcessor = AIProcessor()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50))
                            .foregroundColor(Color("accentColor"))
                        
                        Text("AI Categorization Practice")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Test how the AI categorizes your content")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Input Form
                    VStack(spacing: 20) {
                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextField("Enter pod title...", text: $title)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isTitleFocused)
                                .onChange(of: title) { newValue in
                                    // Sanitize title input
                                    let sanitized = InputSanitizer.clean(newValue, type: .podTitle)
                                    if sanitized != newValue {
                                        title = sanitized
                                    }
                                }
                        }
                        
                        // Description Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            TextField("Enter pod description...", text: $description, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                                .focused($isDescriptionFocused)
                                .onChange(of: description) { newValue in
                                    // Sanitize description input
                                    let sanitized = InputSanitizer.clean(newValue, type: .podDescription)
                                    if sanitized != newValue {
                                        description = sanitized
                                    }
                                }
                        }
                        
                        // Tags Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags (Optional)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                TextField("Add a tag...", text: $tagInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .focused($isTagInputFocused)
                                    .onSubmit {
                                        addTag()
                                    }
                                    .onChange(of: tagInput) { newValue in
                                        // Sanitize tag input
                                        let sanitized = InputSanitizer.clean(newValue, type: .tag)
                                        if sanitized != newValue {
                                            tagInput = sanitized
                                        }
                                    }
                                
                                Button("Add") {
                                    addTag()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            
                            // Display tags
                            if !tags.isEmpty {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                    ForEach(tags.indices, id: \.self) { index in
                                        HStack {
                                            Text(tags[index])
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color("accentColor").opacity(0.2))
                                                .foregroundColor(Color("accentColor"))
                                                .cornerRadius(12)
                                            
                                            Button(action: {
                                                deleteTag(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Test Button
                        Button(action: testCategorization) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text("Test AI Categorization")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("accentColor"))
                            .cornerRadius(12)
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                    
                    // Results Section
                    if showingResults, let results = aiResults {
                        VStack(spacing: 16) {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 16) {
                                Text("AI Analysis Results")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                // Category Result
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    Text(results.category)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color("accentColor").opacity(0.2))
                                        .foregroundColor(Color("accentColor"))
                                        .cornerRadius(8)
                                }
                                
                                // Keywords Result
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Selected Keywords")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                        ForEach(results.keywords, id: \.self) { keyword in
                                            Text(keyword)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color("mainColor").opacity(0.2))
                                                .foregroundColor(Color("mainColor"))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                
                                // Available Keywords for Category
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("All Keywords in '\(results.category)' Category")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    let allKeywords = aiProcessor.getKeywords(for: results.category)
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                        ForEach(allKeywords, id: \.self) { keyword in
                                            Text(keyword)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(results.keywords.contains(keyword) ? Color("accentColor").opacity(0.3) : Color("lightGrey"))
                                                .foregroundColor(results.keywords.contains(keyword) ? Color("accentColor") : .gray)
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                                
                                // Debug: Show keyword scores
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Keyword Scoring (Debug)")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    let debugScores = aiProcessor.debugKeywordScoring(
                                        title: title,
                                        description: description,
                                        userTags: tags.isEmpty ? nil : tags
                                    )
                                    
                                    if let categoryScores = debugScores[results.category] {
                                        VStack(spacing: 4) {
                                            ForEach(categoryScores.prefix(5), id: \.keyword) { keywordScore in
                                                HStack {
                                                    Text(keywordScore.keyword)
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                    
                                                    Spacer()
                                                    
                                                    Text(String(format: "%.1f", keywordScore.score))
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(results.keywords.contains(keywordScore.keyword) ? Color("accentColor").opacity(0.2) : Color("lightGrey").opacity(0.3))
                                                .cornerRadius(4)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color("lightGrey").opacity(0.3))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("AI Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        clearAll()
                    }
                    .foregroundColor(Color("accentColor"))
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func addTag() {
        let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            // Sanitize tag before adding
            let sanitizedTag = InputSanitizer.clean(trimmedTag, type: .tag)
            if !sanitizedTag.isEmpty {
                tags.append(sanitizedTag)
                tagInput = ""
            }
        }
    }
    
    private func deleteTag(at index: Int) {
        if index < tags.count {
            tags.remove(at: index)
        }
    }
    
    private func testCategorization() {
        // Process with AI using sanitized inputs
        let sanitizedTitle = InputSanitizer.clean(title, type: .podTitle)
        let sanitizedDescription = InputSanitizer.clean(description, type: .podDescription)
        let sanitizedTags = tags.map { InputSanitizer.clean($0, type: .tag) }.filter { !$0.isEmpty }
        
        let results = aiProcessor.processPod(
            title: sanitizedTitle,
            description: sanitizedDescription,
            userTags: sanitizedTags.isEmpty ? nil : sanitizedTags
        )
        
        aiResults = results
        showingResults = true
        
        // Dismiss keyboard
        isTitleFocused = false
        isDescriptionFocused = false
        isTagInputFocused = false
    }
    
    private func clearAll() {
        title = ""
        description = ""
        tagInput = ""
        tags.removeAll()
        showingResults = false
        aiResults = nil
    }
}

struct Previews_AIPracticeView_Previews: PreviewProvider {
    static var previews: some View {
        AIPracticeView()
    }
}
