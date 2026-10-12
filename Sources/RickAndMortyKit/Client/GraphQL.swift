import Foundation

/// A GraphQL variable value. Write it as a literal:
///
/// ```swift
/// let variables: [String: GraphQLValue] = ["page": 2, "filter": ["name": "rick", "status": "alive"]]
/// ```
public enum GraphQLValue: Hashable, Sendable, Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case list([GraphQLValue])
    case object([String: GraphQLValue])
    case null

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .list(values): try container.encode(values)
        case let .object(values): try container.encode(values)
        case .null: try container.encodeNil()
        }
    }
}

extension GraphQLValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension GraphQLValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension GraphQLValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension GraphQLValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension GraphQLValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension GraphQLValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: GraphQLValue...) {
        self = .list(elements)
    }
}

extension GraphQLValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, GraphQLValue)...) {
        var object: [String: GraphQLValue] = [:]
        for (key, value) in elements {
            object[key] = value
        }
        self = .object(object)
    }
}

/// The body POSTed to the GraphQL endpoint.
struct GraphQLRequestBody: Encodable {
    let query: String
    let variables: [String: GraphQLValue]?
    let operationName: String?
}

/// `{ "data": …, "errors": [{ "message": … }] }`.
struct GraphQLResponseBody<Value: Decodable>: Decodable {
    struct Message: Decodable {
        let message: String
    }

    let data: Value?
    let errors: [Message]?
}

extension RickAndMortyClient {
    /// Runs a GraphQL query against `https://rickandmortyapi.com/graphql` and decodes its `data`
    /// into your own type. Use it to fetch exactly the fields you need, or related resources in
    /// one round trip.
    ///
    /// ```swift
    /// struct Result: Decodable {
    ///     struct Characters: Decodable { let results: [Item] }
    ///     struct Item: Decodable { let id: String; let name: String }
    ///     let characters: Characters
    /// }
    /// let result = try await client.graphQL(
    ///     "query($page: Int, $name: String) { characters(page: $page, filter: { name: $name }) { results { id name } } }",
    ///     variables: ["page": 1, "name": "rick"],
    ///     as: Result.self
    /// )
    /// ```
    ///
    /// GraphQL ids are strings. Throws ``RickAndMortyError/graphQL(_:)`` when the response has
    /// errors.
    public func graphQL<Value: Decodable>(
        _ query: String,
        variables: [String: GraphQLValue] = [:],
        operationName: String? = nil,
        as type: Value.Type = Value.self
    ) async throws -> Value {
        var request = URLRequest(url: configuration.graphQLURL, timeoutInterval: configuration.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let userAgent = configuration.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        let body = GraphQLRequestBody(
            query: query,
            variables: variables.isEmpty ? nil : variables,
            operationName: operationName
        )
        request.httpBody = try JSONEncoder().encode(body)

        // A query the server rejects comes back as HTTP 400 with `errors`; report those.
        let (data, http) = try await send(request)
        let response: GraphQLResponseBody<Value>
        do {
            response = try JSONDecoder().decode(GraphQLResponseBody<Value>.self, from: data)
        } catch {
            guard (200..<300).contains(http.statusCode) else {
                throw RickAndMortyError.http(
                    statusCode: http.statusCode,
                    message: nil,
                    url: request.url ?? configuration.graphQLURL
                )
            }
            throw RickAndMortyError.decoding(type: String(describing: Value.self), description: String(describing: error))
        }
        if let errors = response.errors, !errors.isEmpty {
            throw RickAndMortyError.graphQL(errors.map(\.message))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RickAndMortyError.http(statusCode: http.statusCode, message: nil, url: request.url ?? configuration.graphQLURL)
        }
        guard let value = response.data else {
            throw RickAndMortyError.decoding(type: String(describing: Value.self), description: "The response has no data.")
        }
        return value
    }
}
