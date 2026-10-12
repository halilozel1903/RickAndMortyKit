import Foundation
import Testing
@testable import RickAndMortyKit

@Suite("GraphQL helper")
struct GraphQLTests {
    struct CharactersQuery: Decodable {
        struct Characters: Decodable {
            struct Info: Decodable {
                let count: Int
                let next: Int?
            }

            struct Item: Decodable {
                struct Appearance: Decodable {
                    let episode: String
                }

                let id: String
                let name: String
                let status: CharacterStatus
                let episode: [Appearance]
            }

            let info: Info
            let results: [Item]
        }

        let characters: Characters
    }

    static let query = """
    query Characters($page: Int, $filter: FilterCharacter) {
      characters(page: $page, filter: $filter) {
        info { count next }
        results { id name status episode { episode } }
      }
    }
    """

    @Test func postsTheQueryAndVariables() async throws {
        let stub = StubbedClient { _ in try .json("graphql-characters") }
        let result = try await stub.client.graphQL(
            Self.query,
            variables: ["page": 1, "filter": ["name": "rick", "status": "alive"]],
            operationName: "Characters",
            as: CharactersQuery.self
        )

        #expect(result.characters.info.count == 107)
        #expect(result.characters.info.next == 2)
        #expect(result.characters.results.first?.name == "Rick Sanchez")
        #expect(result.characters.results.first?.id == "1")
        #expect(result.characters.results.last?.status == .dead)
        #expect(result.characters.results.first?.episode.first?.episode == "S01E01")

        let request = try #require(stub.requests.last)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/graphql")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body)
        let object = try #require(json as? [String: Any])
        #expect(object["query"] as? String == Self.query)
        #expect(object["operationName"] as? String == "Characters")
        let variables = try #require(object["variables"] as? [String: Any])
        #expect(variables["page"] as? Int == 1)
        let filter = try #require(variables["filter"] as? [String: Any])
        #expect(filter["name"] as? String == "rick")
        #expect(filter["status"] as? String == "alive")
    }

    @Test func noVariablesAreLeftOut() async throws {
        let stub = StubbedClient { _ in try .json("graphql-characters") }
        _ = try await stub.client.graphQL("{ characters { info { count next } results { id name status episode { episode } } } }", as: CharactersQuery.self)

        let body = try #require(stub.requests.last?.httpBody)
        let json = try JSONSerialization.jsonObject(with: body)
        let object = try #require(json as? [String: Any])
        #expect(object["variables"] == nil)
    }

    @Test func errorsAreThrown() async throws {
        let stub = StubbedClient { _ in try .json("graphql-error", status: 400) }

        do {
            _ = try await stub.client.graphQL("{ characters { results { nmae } } }", as: CharactersQuery.self)
            Issue.record("Expected an error")
        } catch let error as RickAndMortyError {
            guard case let .graphQL(messages) = error else {
                Issue.record("Expected graphQL, got \(error)")
                return
            }
            #expect(messages.count == 1)
            #expect(messages.first?.hasPrefix("Cannot query field") == true)
        }
    }

    @Test func valuesEncodeAsJSON() throws {
        let value: GraphQLValue = ["ids": [1, 2, 3], "name": "Rick", "ratio": 0.5, "alive": true, "type": nil]
        let data = try JSONEncoder().encode(value)
        let json = try JSONSerialization.jsonObject(with: data)
        let object = try #require(json as? [String: Any])

        let expectedIDs: [Int] = [1, 2, 3]
        #expect(object["ids"] as? [Int] == expectedIDs)
        #expect(object["name"] as? String == "Rick")
        #expect(object["ratio"] as? Double == 0.5)
        #expect(object["alive"] as? Bool == true)
        #expect(object["type"] is NSNull)
    }
}
