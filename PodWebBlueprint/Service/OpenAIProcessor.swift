//
//  OpenAIProcessor.swift
//  PodWebBlueprint
//
//  Enhanced AI categorization using OpenAI API
//

import Foundation

class OpenAIProcessor {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // Use categories from AIConfig for consistency
    private var validCategories: [String] {
        return AIConfig.validCategories
    }
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Main Processing Function
    
    func processPod(title: String, description: String, userTags: [String]? = nil) async throws -> (category: String, keywords: [String]) {
        if AIConfig.enableDebugging {
            print("🤖 [OpenAI] Starting categorization for: '\(title.prefix(50))...'")
            print("🤖 [OpenAI] Model: \(AIConfig.openAIModel), Temperature: \(AIConfig.temperature)")
        }
        
        let prompt = buildCategorizePrompt(title: title, description: description, userTags: userTags)
        
        if AIConfig.enableDebugging {
            print("🤖 [OpenAI] Sending request to OpenAI API...")
        }
        
        let startTime = Date()
        let response = try await callOpenAI(prompt: prompt)
        let duration = Date().timeIntervalSince(startTime)
        
        let result = try parseResponse(response)
        
        if AIConfig.enableDebugging {
            print("🤖 [OpenAI] ✅ SUCCESS - Duration: \(String(format: "%.2f", duration))s")
            print("🤖 [OpenAI] Category: '\(result.category)' | Keywords: \(result.keywords)")
        }
        
        return result
    }
    
    // MARK: - OpenAI Integration
    
    private func buildCategorizePrompt(title: String, description: String, userTags: [String]?) -> String {
        let categories = validCategories.joined(separator: ", ")
        let tagsText = userTags?.joined(separator: ", ") ?? "None"
        
        return """
        You are an expert content categorization assistant for a podcast/audio content platform. Analyze the following content and categorize it accurately.
        
        CONTENT TO ANALYZE:
        Title: "\(title)"
        Description: "\(description)"
        User Tags: \(tagsText)
        
        AVAILABLE CATEGORIES (choose exactly one):
        \(categories)
        
        KEYWORD GENERATION GUIDELINES:
        - Generate exactly \(AIConfig.keywordCount) diverse, relevant keywords
        - Keywords should be 1-3 words each
        - Focus on terms users would search for to discover this content
        - Include mix of: topic-specific terms, broad themes, and descriptive words
        - Consider both explicit content and implied themes
        - Prioritize searchability and discoverability
        
        CATEGORY SELECTION RULES:
        1. Analyze the main topic/theme of the content
        2. Consider the target audience and purpose
        3. If multiple categories apply, choose the MOST SPECIFIC one
        4. Must use exact category name from the list above
        
        RESPONSE FORMAT (JSON only, no explanations):
        {
            "category": "exact category name from list",
            "keywords": ["keyword1", "keyword2", "keyword3", "keyword4", "keyword5"]
        }
        
        Examples of good keywords:
        - For tech content: "artificial intelligence", "startup", "innovation"
        - For health content: "wellness", "mental health", "fitness tips"
        - For entertainment: "celebrity news", "movie review", "pop culture"
        """
    }
    
    private func callOpenAI(prompt: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            if AIConfig.enableDebugging {
                print("🤖 [OpenAI] ❌ Invalid URL")
            }
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AIConfig.requestTimeout
        
        let requestBody: [String: Any] = [
            "model": AIConfig.openAIModel,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": AIConfig.temperature,
            "max_tokens": AIConfig.maxTokens,
            "response_format": ["type": "json_object"]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            if AIConfig.enableDebugging {
                print("🤖 [OpenAI] Request body size: \(request.httpBody?.count ?? 0) bytes")
            }
        } catch {
            if AIConfig.enableDebugging {
                print("🤖 [OpenAI] ❌ Failed to serialize request: \(error)")
            }
            throw OpenAIError.requestFailed
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            if AIConfig.enableDebugging {
                print("🤖 [OpenAI] ❌ Invalid response type")
            }
            throw OpenAIError.requestFailed
        }
        
        if AIConfig.enableDebugging {
            print("🤖 [OpenAI] HTTP Status: \(httpResponse.statusCode)")
        }
        
        if httpResponse.statusCode == 429 {
            if AIConfig.enableDebugging {
                print("🤖 [OpenAI] ❌ Rate limited")
            }
            throw OpenAIError.rateLimited
        }
        
        guard httpResponse.statusCode == 200 else {
            if AIConfig.enableDebugging, let errorData = String(data: data, encoding: .utf8) {
                print("🤖 [OpenAI] ❌ Request failed with error: \(errorData)")
            }
            throw OpenAIError.requestFailed
        }
        
        guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if AIConfig.enableDebugging {
                print("🤖 [OpenAI] ❌ Failed to parse JSON response")
            }
            throw OpenAIError.invalidResponse
        }
        
        // Log usage information if available
        if AIConfig.enableDebugging, let usage = jsonResponse["usage"] as? [String: Any] {
            print("🤖 [OpenAI] Token usage - Prompt: \(usage["prompt_tokens"] ?? "?"), Completion: \(usage["completion_tokens"] ?? "?"), Total: \(usage["total_tokens"] ?? "?")")
        }
        
        guard let choices = jsonResponse["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            if AIConfig.enableDebugging {
                print("🤖 [OpenAI] ❌ Invalid response structure")
            }
            throw OpenAIError.invalidResponse
        }
        
        if AIConfig.enableDebugging {
            print("🤖 [OpenAI] Raw response length: \(content.count) characters")
        }
        return content
    }
    
    private func parseResponse(_ response: String) throws -> (category: String, keywords: [String]) {
        guard let data = response.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let category = json["category"] as? String,
              let keywords = json["keywords"] as? [String] else {
            throw OpenAIError.parseError
        }
        
        // Validate category is in our list
        let finalCategory = validCategories.contains(category) ? category : "Technology"
        
        // Ensure we have exactly 5 keywords
        var finalKeywords = Array(keywords.prefix(5))
        
        // Fill with generic keywords if we don't have enough
        let fallbackKeywords = ["Content", "Audio", "Podcast", "Discussion", "Media"]
        while finalKeywords.count < 5 {
            let fallback = fallbackKeywords[finalKeywords.count - keywords.count]
            finalKeywords.append(fallback)
        }
        
        return (finalCategory, finalKeywords)
    }
    
    // MARK: - Fallback to Original Processor
    
    func processPodWithFallback(title: String, description: String, userTags: [String]? = nil, originalProcessor: AIProcessor) async -> (category: String, keywords: [String]) {
        // Check if OpenAI is enabled
        guard AIConfig.useOpenAIForCategorization else {
            if AIConfig.enableDebugging {
                print("🔄 [FALLBACK] OpenAI disabled in config, using local processor")
            }
            let result = originalProcessor.processPod(title: title, description: description, userTags: userTags)
            if AIConfig.enableDebugging {
                print("🔄 [FALLBACK] Local result - Category: '\(result.category)' | Keywords: \(result.keywords)")
            }
            return result
        }
        
        var attempt = 0
        let maxRetries = AIConfig.maxRetries
        
        while attempt < maxRetries {
            attempt += 1
            if AIConfig.enableDebugging {
                print("🤖 [OpenAI] Attempt \(attempt)/\(maxRetries)")
            }
            
            do {
                let result = try await processPod(title: title, description: description, userTags: userTags)
                if AIConfig.enableDebugging {
                    print("🤖 [OpenAI] ✅ SUCCESS on attempt \(attempt)")
                }
                return result
            } catch let error as OpenAIError {
                if AIConfig.enableDebugging {
                    print("🤖 [OpenAI] ❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                }
                
                // Don't retry on certain errors
                if error == .rateLimited && attempt < maxRetries {
                    if AIConfig.enableDebugging {
                        print("🤖 [OpenAI] ⏱️ Rate limited, waiting 2 seconds before retry...")
                    }
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    continue
                }
                
                if attempt >= maxRetries {
                    if AIConfig.enableDebugging {
                        print("🔄 [FALLBACK] Max retries reached, switching to local processor")
                    }
                    break
                }
            } catch {
                if AIConfig.enableDebugging {
                    print("🤖 [OpenAI] ❌ Unexpected error on attempt \(attempt): \(error)")
                }
                if attempt >= maxRetries {
                    break
                }
            }
        }
        
        // Fallback to local processor
        if AIConfig.enableDebugging {
            print("🔄 [FALLBACK] Using local AI processor")
        }
        let startTime = Date()
        let result = originalProcessor.processPod(title: title, description: description, userTags: userTags)
        let duration = Date().timeIntervalSince(startTime)
        
        if AIConfig.enableDebugging {
            print("🔄 [FALLBACK] ✅ Local processing complete - Duration: \(String(format: "%.3f", duration))s")
            print("🔄 [FALLBACK] Category: '\(result.category)' | Keywords: \(result.keywords)")
        }
        
        return result
    }
}

// MARK: - Error Types

enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse
    case parseError
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OpenAI URL"
        case .requestFailed:
            return "OpenAI request failed"
        case .invalidResponse:
            return "Invalid OpenAI response"
        case .parseError:
            return "Failed to parse OpenAI response"
        case .rateLimited:
            return "OpenAI rate limit exceeded"
        }
    }
}
