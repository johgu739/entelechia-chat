// @EntelechiaHeaderStart
// Signifier: ModelClient
// Substance: AI model client
// Genus: Model HTTP client
// Differentia: Calls external model endpoints
// Form: Networking/model invocation logic
// Matter: Requests; responses; auth/context headers
// Powers: Send prompts; receive completions
// FinalCause: Supply model outputs for conversations
// Relations: Serves conversation faculty; depends on networking
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation

protocol ModelClient {
    func sendMessage(_ text: String, contextFiles: [LoadedFile]) async -> ModelResponse
}

class StubModelClient: ModelClient {
    func sendMessage(_ text: String, contextFiles: [LoadedFile]) async -> ModelResponse {
        // Simulate network delay (1-2 seconds for realism)
        let delay = UInt64.random(in: 800_000_000...2_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
        
        // Generate contextual mock response
        let mockResponse = generateMockResponse(for: text, contextFiles: contextFiles)
        
        return ModelResponse(content: mockResponse)
    }
    
    private func generateMockResponse(for userMessage: String, contextFiles: [LoadedFile]) -> String {
        let lowercased = userMessage.lowercased()
        
        // Context-aware response generation
        var response = ""
        
        // Add context file reference if present
        if !contextFiles.isEmpty {
            let fileNames = contextFiles.filter { $0.isIncludedInContext }.map { $0.name }.joined(separator: ", ")
            response += "I can see you've attached \(fileNames). "
        }
        
        // Generate response based on message content
        if lowercased.contains("function") || lowercased.contains("code") || lowercased.contains("implement") {
            response += generateCodeResponse()
        } else if lowercased.contains("explain") || lowercased.contains("how") || lowercased.contains("what") {
            response += generateExplanationResponse()
        } else if lowercased.contains("refactor") || lowercased.contains("improve") || lowercased.contains("optimize") {
            response += generateRefactoringResponse()
        } else if lowercased.contains("error") || lowercased.contains("bug") || lowercased.contains("fix") {
            response += generateDebuggingResponse()
        } else {
            response += generateGeneralResponse()
        }
        
        return response
    }
    
    private func generateCodeResponse() -> String {
        return #"""
# Implementation Solution

Here's a clean implementation that addresses your request:

## Approach

The solution uses a **protocol-oriented design** with clear separation of concerns. This makes the code:

- *Testable*: Easy to unit test individual components
- *Maintainable*: Clear responsibilities for each type
- *Extensible*: Easy to add new features

## Code Implementation

```swift
protocol DataProcessor {
    func process(_ data: Data) async throws -> ProcessedData
}

class NetworkDataProcessor: DataProcessor {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func process(_ data: Data) async throws -> ProcessedData {
        // Process network data
        let request = URLRequest(url: endpoint)
        let (responseData, _) = try await session.data(for: request)
        return try JSONDecoder().decode(ProcessedData.self, from: responseData)
    }
}
```

## Usage Example

```swift
let processor = NetworkDataProcessor()
let result = try await processor.process(sampleData)
print("Processed: \(result)")
```

## Key Points

1. **Async/await** for modern concurrency
2. **Protocol-based** architecture for flexibility
3. **Dependency injection** via initializer

The `DataProcessor` protocol allows you to swap implementations easily, which is great for testing with mock objects.

"""#
    }
    
    private func generateExplanationResponse() -> String {
        return #"""
# Explanation

Let me break this down for you:

## Core Concept

The main idea here is about **separation of concerns**. Each component has a single, well-defined responsibility.

### How It Works

1. **Input Layer**: Receives and validates input
2. **Processing Layer**: Transforms data according to business rules
3. **Output Layer**: Formats and delivers results

## Visual Flow

```
Input → Validation → Processing → Formatting → Output
```

## Code Example

Here's a simple illustration:

```javascript
class DataPipeline {
    constructor(validators, processors, formatters) {
        this.validators = validators;
        this.processors = processors;
        this.formatters = formatters;
    }
    
    async execute(input) {
        // Validate
        for (const validator of this.validators) {
            await validator.validate(input);
        }
        
        // Process
        let data = input;
        for (const processor of this.processors) {
            data = await processor.process(data);
        }
        
        // Format
        return this.formatters.reduce(
            (result, formatter) => formatter.format(result),
            data
        );
    }
}
```

## Why This Matters

This pattern makes your code:
- **Testable**: Each step can be tested independently
- **Maintainable**: Changes to one layer don't affect others
- **Scalable**: Easy to add new validators, processors, or formatters

> **Tip**: Start with the simplest implementation that works, then refactor as needed.

"""#
    }
    
    private func generateRefactoringResponse() -> String {
        return #"""
# Refactoring Suggestions

I've analyzed your code and here are some improvements:

## Current Issues

- **Tight coupling** between components
- **Large functions** that do too much
- **Magic numbers** scattered throughout
- **Limited error handling**

## Improved Version

```swift
// Before: Tightly coupled
class UserManager {
    func saveUser() {
        let db = Database()
        db.connect()
        db.insert(user)
        db.close()
    }
}

// After: Dependency injection and protocol
protocol DatabaseProtocol {
    func connect() throws
    func insert<T: Codable>(_ item: T) throws
    func close()
}

class UserManager {
    private let database: DatabaseProtocol
    
    init(database: DatabaseProtocol) {
        self.database = database
    }
    
    func saveUser(_ user: User) throws {
        try database.connect()
        defer { database.close() }
        try database.insert(user)
    }
}
```

## Key Improvements

1. **Protocol-based**: `DatabaseProtocol` allows for easy testing
2. **Dependency injection**: Database is passed in, not created internally
3. **Error handling**: Uses `throws` for proper error propagation
4. **Resource management**: `defer` ensures cleanup

## Additional Optimizations

```python
# Extract constants
MAX_RETRY_ATTEMPTS = 3
TIMEOUT_SECONDS = 30

# Use type hints
def process_data(data: List[Dict[str, Any]]) -> ProcessedResult:
    # Process data with retry logic.
    for attempt in range(MAX_RETRY_ATTEMPTS):
        try:
            return _process(data)
        except RetryableError:
            if attempt == MAX_RETRY_ATTEMPTS - 1:
                raise
            time.sleep(2 ** attempt)  # Exponential backoff
```

These changes improve **readability**, **testability**, and **maintainability**.

"""#
    }
    
    private func generateDebuggingResponse() -> String {
        return #"""
# Debugging Guide

Let's troubleshoot this step by step:

## Common Causes

1. **Null/undefined values** in unexpected places
2. **Type mismatches** between expected and actual types
3. **Race conditions** in async code
4. **Memory leaks** from retained references

## Diagnostic Steps

### Step 1: Check the Error Message

```swift
do {
    try performOperation()
} catch let error as SpecificError {
    print("Error details: \(error.localizedDescription)")
    print("Stack trace: \(error)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Step 2: Add Logging

```swift
func debugOperation() {
    print("🔍 Starting operation")
    print("📊 Input: \(input)")
    
    let result = process(input)
    print("✅ Result: \(result)")
    
    return result
}
```

### Step 3: Use Breakpoints

Set breakpoints at:
- Function entry points
- Before/after critical operations
- Error handling blocks

## Solution

Based on the error pattern, here's the fix:

```swift
// Problem: Force unwrapping can crash
let value = dictionary["key"]!

// Solution: Safe unwrapping with error handling
guard let value = dictionary["key"] else {
    throw MissingKeyError(key: "key")
}
return value
```

## Prevention

- Always use `guard` or `if let` for optionals
- Add unit tests for edge cases
- Use `assert()` in debug builds to catch issues early

> **Remember**: Most bugs come from assumptions. Verify your assumptions with logging and tests.

"""#
    }
    
    private func generateGeneralResponse() -> String {
        return #"""
# Response

I understand what you're looking for. Let me provide a comprehensive answer.

## Overview

This is a common pattern in modern software development. The key is to balance **simplicity** with **flexibility**.

## Best Practices

1. **Start simple**: Build the minimal viable solution first
2. **Iterate**: Refine based on actual usage patterns
3. **Measure**: Use metrics to guide improvements
4. **Document**: Keep documentation in sync with code

## Example Implementation

Here's a practical example:

```swift
struct Configuration {
    let apiKey: String
    let timeout: TimeInterval
    let retryCount: Int
    
    static func fromEnvironment() -> Configuration {
        Configuration(
            apiKey: ProcessInfo.processInfo.environment["API_KEY"] ?? "",
            timeout: 30.0,
            retryCount: 3
        )
    }
}

class APIClient {
    private let config: Configuration
    
    init(config: Configuration) {
        self.config = config
    }
    
    func request<T: Decodable>(_ endpoint: String) async throws -> T {
        // Implementation here
        fatalError("Not implemented")
    }
}
```

## Additional Considerations

- **Error handling**: Always handle edge cases gracefully
- **Performance**: Profile before optimizing
- **Security**: Validate all inputs, sanitize outputs
- **Testing**: Write tests for critical paths

## Next Steps

1. Review the implementation above
2. Adapt it to your specific use case
3. Add error handling and logging
4. Write unit tests

If you need help with any specific part, just ask!

"""#
    }
}
