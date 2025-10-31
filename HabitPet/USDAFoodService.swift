//
//  USDAFoodService.swift
//  HabitPet
//
//  Created by Janice C on 9/17/25.
//

import Foundation
import Combine

/// Service class for interacting with USDA FoodData Central API
final class USDAFoodService: ObservableObject {
    static let shared = USDAFoodService()

    // API Configuration
    private let baseURL = USDAConfig.baseURL
    private let apiKey  = USDAConfig.apiKeyOrFallback

    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()

    // A single shared decoder with *default keys* (important for USDA payloads).
    // Do NOT use `.convertFromSnakeCase` here.
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()

    // Cache
    private var searchCache: [String: [FoodItem]] = [:]
    private var foodDetailsCache: [Int: USDAFood] = [:]

    private init() {}

    // MARK: - Search

    /// Search for foods using USDA FoodData Central API
    /// - Parameters:
    ///   - query: Search term
    ///   - pageSize: Number of results (default: 25, max: 200)
    ///   - pageNumber: Page number (default: 1)
    ///   - dataType: Optional filter ("Foundation", "SR Legacy", "Branded")
    ///   - sortBy: Default "lowercaseDescription.keyword"
    ///   - sortOrder: "asc" or "desc"
    func searchFoods(
        query: String,
        pageSize: Int = 25,
        pageNumber: Int = 1,
        dataType: String? = nil,
        sortBy: String = "lowercaseDescription.keyword",
        sortOrder: String = "asc"
    ) -> AnyPublisher<[FoodItem], Error> {

        // Cache key
        let cacheKey = "\(query)_\(pageSize)_\(pageNumber)_\(dataType ?? "all")_\(sortBy)_\(sortOrder)"
        if let cached = searchCache[cacheKey] {
            return Just(cached)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        // Build URL
        let params = USDAConfig.buildSearchQueryParameters(
            query: query,
            pageSize: pageSize,
            pageNumber: pageNumber,
            dataType: dataType,
            sortBy: sortBy,
            sortOrder: sortOrder
        )

        var components = URLComponents(string: USDAConfig.searchFoodsURL)!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            return Fail(error: USDAError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("HabitPet iOS", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                // Surface HTTP errors with readable messages
                if let response = output.response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                    throw USDAError.networkError(NSError(domain: "HTTP \(response.statusCode)", code: response.statusCode))
                }
                return output.data
            }
            .decode(type: USDASearchResponse.self, decoder: decoder)
            .map { response in
                let items = response.foods.map { $0.toFoodItem() }
                self.searchCache[cacheKey] = items
                return items
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Details (single)

    func getFoodDetails(fdcId: Int) -> AnyPublisher<USDAFood, Error> {
        if let cached = foodDetailsCache[fdcId] {
            return Just(cached)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        guard let url = URL(string: "\(USDAConfig.foodDetailsURL(fdcId: fdcId))?api_key=\(apiKey)") else {
            return Fail(error: USDAError.invalidURL).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("HabitPet iOS", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                    throw USDAError.networkError(NSError(domain: "HTTP \(response.statusCode)", code: response.statusCode))
                }
                return output.data
            }
            .decode(type: USDAFood.self, decoder: decoder)
            .handleEvents(receiveOutput: { food in
                self.foodDetailsCache[fdcId] = food
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Details (multiple)

    func getMultipleFoodDetails(fdcIds: [Int]) -> AnyPublisher<[USDAFood], Error> {
        guard let url = URL(string: "\(USDAConfig.multipleFoodDetailsURL)?api_key=\(apiKey)") else {
            return Fail(error: USDAError.invalidURL).eraseToAnyPublisher()
        }

        let body = ["fdcIds": fdcIds]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("HabitPet iOS", forHTTPHeaderField: "User-Agent")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: request)
            .tryMap { output in
                if let response = output.response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                    throw USDAError.networkError(NSError(domain: "HTTP \(response.statusCode)", code: response.statusCode))
                }
                return output.data
            }
            .decode(type: [USDAFood].self, decoder: decoder)
            .handleEvents(receiveOutput: { foods in
                foods.forEach { self.foodDetailsCache[$0.fdcId] = $0 }
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Helpers / Caches

    func clearSearchCache() { searchCache.removeAll() }
    func clearFoodDetailsCache() { foodDetailsCache.removeAll() }
    func clearAllCaches() {
        clearSearchCache()
        clearFoodDetailsCache()
    }

    /// Search with fallback to Foundation foods if the first call fails
    func searchFoodsWithFallback(query: String) -> AnyPublisher<[FoodItem], Error> {
        searchFoods(query: query)
            .catch { _ in self.searchFoods(query: query, dataType: "Foundation") }
            .eraseToAnyPublisher()
    }

    /// Quick mock items (offline/testing)
    func getMockFoods() -> [FoodItem] {
        let tofu = FoodItem(
            id: 999_2190,
            name: "Korean Braised Tofu (Dubu Jorim)",
            calories: 220,
            protein: 16,
            carbs: 8,
            fats: 14,
            category: "Prepared entrée",
            usdaFood: nil
        )
        
        let base = [
            FoodItem(id: 1,  name: "Apple, raw, with skin",         calories: 52,  protein: 0.3, carbs: 13.8, fats: 0.2, category: "Fruits and Fruit Juices", usdaFood: nil),
            FoodItem(id: 2,  name: "Banana, raw",                   calories: 89,  protein: 1.1, carbs: 22.8, fats: 0.3, category: "Fruits and Fruit Juices", usdaFood: nil),
            FoodItem(id: 3,  name: "Chicken breast, skinless",      calories: 120, protein: 22.5, carbs: 0,    fats: 2.6, category: "Poultry Products",       usdaFood: nil),
            FoodItem(id: 4,  name: "Salmon, Atlantic, farmed",      calories: 208, protein: 20.4, carbs: 0,    fats: 12.4,category: "Finfish & Shellfish",    usdaFood: nil),
            FoodItem(id: 5,  name: "Broccoli, raw",                 calories: 34,  protein: 2.8, carbs: 6.6,  fats: 0.4, category: "Vegetables",              usdaFood: nil),
            FoodItem(id: 6,  name: "Rice, brown, long-grain, raw",  calories: 370, protein: 7.9, carbs: 77.2, fats: 2.9, category: "Cereal Grains & Pasta",   usdaFood: nil),
            FoodItem(id: 7,  name: "Avocado, raw, California",      calories: 167, protein: 2.0, carbs: 8.5,  fats: 15.4,category: "Fruits and Fruit Juices", usdaFood: nil),
            FoodItem(id: 8,  name: "Egg, whole, raw, fresh",        calories: 143, protein: 12.6,carbs: 0.7,  fats: 9.5, category: "Dairy & Egg Products",   usdaFood: nil),
            FoodItem(id: 9,  name: "Milk, whole, 3.25% milkfat",    calories: 61,  protein: 3.2, carbs: 4.8,  fats: 3.3, category: "Dairy & Egg Products",   usdaFood: nil),
            FoodItem(id: 10, name: "Bread, white, commercial",      calories: 265, protein: 8.9, carbs: 49.4, fats: 3.2, category: "Baked Products",         usdaFood: nil)
        ]

        return [tofu] + base
    }
}

// MARK: - Error Types

enum USDAError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case apiKeyRequired
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidURL:         return "Invalid URL for USDA API request"
        case .noData:             return "No data received from USDA API"
        case .decodingError:      return "Failed to decode USDA API response"
        case .networkError(let e):return "Network error: \(e.localizedDescription)"
        case .apiKeyRequired:     return "USDA API key is required"
        case .rateLimitExceeded:  return "Rate limit exceeded for USDA API"
        }
    }
}

