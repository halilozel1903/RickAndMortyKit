import Foundation

/// Errors thrown by ``RickAndMortyClient``.
public enum RickAndMortyError: Error, Equatable, Sendable, LocalizedError {
    /// The resource does not exist (HTTP 404). `message` is the API's explanation, such as
    /// `"Character not found"`.
    case notFound(message: String?, url: URL)
    /// Any other unsuccessful HTTP status, with the API's `error` message when it sent one.
    case http(statusCode: Int, message: String?, url: URL)
    /// The response was not JSON of the expected shape.
    case decoding(type: String, description: String)
    /// The request could not be completed (offline, timed out, cancelled…).
    case transport(URLError)
    /// The response was not an HTTP response.
    case invalidResponse
    /// The GraphQL endpoint answered with errors; these are their messages.
    case graphQL([String])

    public var errorDescription: String? {
        switch self {
        case let .notFound(message, _):
            return message ?? "The Rick and Morty API has nothing at this address."
        case let .http(statusCode, message, _):
            return message.map { "The Rick and Morty API answered with HTTP status \(statusCode): \($0)" }
                ?? "The Rick and Morty API answered with HTTP status \(statusCode)."
        case let .decoding(type, _):
            return "The Rick and Morty API sent data that could not be read as \(type)."
        case let .transport(error):
            return error.localizedDescription
        case .invalidResponse:
            return "The Rick and Morty API sent an invalid response."
        case let .graphQL(messages):
            return messages.first ?? "The GraphQL query failed."
        }
    }
}

/// The body the API sends with an error status: `{"error":"Character not found"}`.
struct APIErrorBody: Decodable {
    let error: String
}
