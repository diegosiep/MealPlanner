import Foundation

// MARK: - Claude AI Provider for Meal Planning
class ClaudeProvider: LLMProvider {
    let name = "Claude AI (Anthropic)"
    private let apiKey = "example" // Replace with your actual API key
    private let baseURL = "https://api.anthropic.com/v1/messages"
    
    func generateCompletion(prompt: String) async throws -> String {
        // Validate API key
//        guard !apiKey.isEmpty && apiKey != "" else {
//            throw LLMError.invalidAPIKey
//        }
        
        // Create the request URL
        guard let url = URL(string: baseURL) else {
            throw LLMError.networkError
        }
        
        // Set up the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        // Format the request body for Claude's API
        // Claude uses a different format than OpenAI - it wants messages with roles
        let requestBody = ClaudeRequest(
            model: "claude-sonnet-4-20250514", // Fast and cost-effective model
            max_tokens: 1500, // Enough for detailed meal plans
            messages: [
                ClaudeMessage(
                    role: "user",
                    content: formatPromptForClaude(prompt)
                )
            ],
            temperature: 0.3 // Low temperature for consistent, factual responses
        )
        
        // Encode the request
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            print("❌ Failed to encode request: \(error)")
            throw LLMError.invalidResponse
        }
        
        print("🤖 Making request to Claude API...")
        
        // Make the network request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.networkError
            }
            
            print("🤖 Claude API Response Status: \(httpResponse.statusCode)")
            
            // Handle different response codes
            switch httpResponse.statusCode {
            case 200:
                break // Success - continue processing
            case 401:
                print("🤖 Invalid API key")
                throw LLMError.invalidAPIKey
            case 429:
                print("🤖 Rate limit exceeded")
                throw LLMError.rateLimitExceeded
            case 400:
                // Log the error details for debugging
                if let responseText = String(data: data, encoding: .utf8) {
                    print("🤖 Bad request details: \(responseText)")
                }
                throw LLMError.invalidResponse
            default:
                if let responseText = String(data: data, encoding: .utf8) {
                    print("🤖 Error response: \(responseText)")
                }
                throw LLMError.serverError(httpResponse.statusCode)
            }
            
            // Parse the response
            let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            
            // Extract the content from Claude's response
            guard let content = claudeResponse.content.first?.text else {
                print("🤖 No content found in Claude response")
                throw LLMError.invalidResponse
            }
            
            print("✅ Successfully received response from Claude")
            return content
            
        } catch {
            print("❌ Claude API Error: \(error)")
            throw error
        }
    }
    
    // MARK: - Claude-Specific Prompt Formatting
    private func formatPromptForClaude(_ originalPrompt: String) -> String {
        // Claude works best with clear, structured prompts
        // Extract key information and reformat for optimal Claude performance
        
        let enhancedPrompt = """
        You are a professional registered dietitian and nutrition expert. I need you to create a precise meal plan based on the following requirements.

        \(originalPrompt)

        IMPORTANT: Your response must be ONLY valid JSON in the exact format specified above. Do not include any explanatory text before or after the JSON. The JSON must be parseable and complete.

        Focus on:
        1. Nutritional accuracy and balance
        2. Real, commonly available foods
        3. Appropriate portion sizes
        4. Meeting the specified dietary restrictions and medical needs
        5. Creating meals that are practical and appealing

        Remember: Response must be pure JSON only, starting with { and ending with }.
        """
        
        return enhancedPrompt
    }
}

// MARK: - Claude API Request/Response Models
struct ClaudeRequest: Codable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
    let temperature: Double
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stop_reason: String?
    let stop_sequence: String?
    let usage: ClaudeUsage
}

struct ClaudeContent: Codable {
    let type: String
    let text: String
}

struct ClaudeUsage: Codable {
    let input_tokens: Int
    let output_tokens: Int
}
