import Foundation
import Testing
@testable import RickAndMortyKit

@Suite("RickAndMortyClient requests")
struct ClientTests {
    @Test func singleCharacter() async throws {
        let stub = StubbedClient { _ in try .json("character") }
        let rick = try await stub.client.character(id: 1)

        #expect(rick.name == "Rick Sanchez")
        #expect(stub.lastPath == "/api/character/1")
        #expect(stub.lastQuery.isEmpty)
    }

    @Test func headers() async throws {
        let stub = StubbedClient { _ in try .json("character") }
        _ = try await stub.client.character(id: 1)

        let request = try #require(stub.requests.last)
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        let agent = request.value(forHTTPHeaderField: "User-Agent") ?? ""
        #expect(agent.hasPrefix("RickAndMortyKit"))
    }

    @Test func firstPageOfCharacters() async throws {
        let stub = StubbedClient { _ in try .json("characters-page-1") }
        let page = try await stub.client.characters()

        #expect(page.results.count == 20)
        #expect(page.info.count == 826)
        #expect(stub.lastPath == "/api/character")
        #expect(stub.lastQueryValue("page") == "1")
    }

    @Test func characterFiltersAreSentInOrder() async throws {
        let stub = StubbedClient { _ in try .json("characters-filtered") }
        let filter = CharacterFilter(name: "smith", status: .alive, species: "Human", type: " ", gender: .female)
        let page = try await stub.client.characters(page: 2, filter: filter)

        #expect(page.results.count == 4)
        let names = stub.lastQuery.map(\.name)
        let expectedNames: [String] = ["page", "name", "status", "species", "gender"]
        #expect(names == expectedNames)
        #expect(stub.lastQueryValue("page") == "2")
        #expect(stub.lastQueryValue("name") == "smith")
        #expect(stub.lastQueryValue("status") == "alive")
        #expect(stub.lastQueryValue("species") == "Human")
        #expect(stub.lastQueryValue("gender") == "female")
        #expect(stub.lastQueryValue("type") == nil)
    }

    @Test func locationAndEpisodeFilters() async throws {
        let stub = StubbedClient { request in
            try request.url?.path == "/api/location" ? .json("locations-page-1") : .json("episodes-page-1")
        }

        _ = try await stub.client.locations(filter: LocationFilter(name: "earth", type: "Planet", dimension: "C-137"))
        #expect(stub.lastPath == "/api/location")
        #expect(stub.lastQueryValue("name") == "earth")
        #expect(stub.lastQueryValue("type") == "Planet")
        #expect(stub.lastQueryValue("dimension") == "C-137")

        _ = try await stub.client.episodes(filter: EpisodeFilter(season: 2))
        #expect(stub.lastPath == "/api/episode")
        #expect(stub.lastQueryValue("episode") == "S02")

        _ = try await stub.client.episodes(filter: EpisodeFilter(name: "rick", code: EpisodeCode(season: 1, episode: 5)))
        #expect(stub.lastQueryValue("name") == "rick")
        #expect(stub.lastQueryValue("episode") == "S01E05")
    }

    @Test func plusSignsAreSentEncoded() async throws {
        let stub = StubbedClient { _ in try .json("characters-filtered") }
        _ = try await stub.client.characters(filter: CharacterFilter(name: "Mr. Poopy+"))

        let url = try #require(stub.requests.last?.url)
        #expect(url.absoluteString.contains("name=Mr.%20Poopy%2B"))
        #expect(stub.lastQueryValue("name") == "Mr. Poopy+")
    }

    @Test func filterWithNoMatchesIsAnEmptyPage() async throws {
        let stub = StubbedClient { _ in try .json("error-nothing-here", status: 404) }
        let page = try await stub.client.characters(filter: CharacterFilter(name: "zzzz"))

        #expect(page.isEmpty)
        #expect(page.info == PageInfo.empty)
        #expect(page.number == 0)
        #expect(page.hasNextPage == false)
    }

    @Test func missingCharacterThrowsTheAPIMessage() async throws {
        let stub = StubbedClient { _ in try .json("error-character-not-found", status: 404) }

        await #expect(throws: RickAndMortyError.self) {
            _ = try await stub.client.character(id: 9999)
        }
        do {
            _ = try await stub.client.character(id: 9999)
            Issue.record("Expected an error")
        } catch let error as RickAndMortyError {
            guard case let .notFound(message, url) = error else {
                Issue.record("Expected notFound, got \(error)")
                return
            }
            #expect(message == "Character not found")
            #expect(url.path == "/api/character/9999")
            #expect(error.errorDescription == "Character not found")
        }
    }

    @Test func serverErrorsKeepTheirStatus() async throws {
        let stub = StubbedClient { _ in .raw(#"{"error":"Hey! you must provide an id"}"#, status: 500) }

        do {
            _ = try await stub.client.episode(id: 1)
            Issue.record("Expected an error")
        } catch let error as RickAndMortyError {
            guard case let .http(status, message, _) = error else {
                Issue.record("Expected http, got \(error)")
                return
            }
            #expect(status == 500)
            #expect(message == "Hey! you must provide an id")
        }
    }

    @Test func malformedJSONIsADecodingError() async throws {
        let stub = StubbedClient { _ in .raw(#"{"id": "one"}"#) }

        do {
            _ = try await stub.client.location(id: 1)
            Issue.record("Expected an error")
        } catch let error as RickAndMortyError {
            guard case let .decoding(type, _) = error else {
                Issue.record("Expected decoding, got \(error)")
                return
            }
            #expect(type == "RMLocation")
        }
    }

    @Test func multipleCharactersInOneRequest() async throws {
        let stub = StubbedClient { _ in try .json("characters-multiple") }
        let characters = try await stub.client.characters(ids: [3, 1, 2, 1])

        #expect(stub.requests.count == 1)
        #expect(stub.lastPath == "/api/character/3,1,2")
        // The result follows the order asked for, without duplicates.
        let ids = characters.map(\.id)
        let expected: [Int] = [3, 1, 2]
        #expect(ids == expected)
    }

    @Test func oneIDAnswersAnObject() async throws {
        let stub = StubbedClient { _ in try .json("character") }
        let characters = try await stub.client.characters(ids: [1])

        #expect(characters.count == 1)
        #expect(characters.first?.name == "Rick Sanchez")
        #expect(stub.lastPath == "/api/character/1")
    }

    @Test func noIDsSendNoRequest() async throws {
        let stub = StubbedClient { _ in try .json("characters-multiple") }
        let characters = try await stub.client.characters(ids: [])

        #expect(characters.isEmpty)
        #expect(stub.requests.isEmpty)
    }

    @Test func unknownIDsAreLeftOut() async throws {
        let stub = StubbedClient { request in
            // One unknown id is a 404, several are an empty array.
            if request.url?.lastPathComponent == "9999" {
                return try .json("error-character-not-found", status: 404)
            }
            return .raw("[]")
        }

        let one = try await stub.client.characters(ids: [9999])
        #expect(one.isEmpty)
        let several = try await stub.client.episodes(ids: [9998, 9999])
        #expect(several.isEmpty)
    }

    @Test func longIDListsAreSplit() async throws {
        let stub = StubbedClient { _ in .raw("[]") }
        let ids = Array(1...250)
        _ = try await stub.client.characters(ids: ids)

        #expect(stub.requests.count == 3)
        let first = stub.requests.first?.lastPathComponent ?? ""
        #expect(first.split(separator: ",").count == RickAndMortyClient.maxIDsPerRequest)
        let last = stub.requests.last?.lastPathComponent ?? ""
        #expect(last.split(separator: ",").count == 50)
    }

    @Test func multipleLocationsAndEpisodes() async throws {
        let stub = StubbedClient { request in
            try request.url?.path.hasPrefix("/api/location") == true ? .json("locations-multiple") : .json("episodes-multiple")
        }

        let locations = try await stub.client.locations(ids: [1, 3])
        #expect(locations.map(\.name).first == "Earth (C-137)")
        #expect(stub.lastPath == "/api/location/1,3")

        let episodes = try await stub.client.episodes(ids: [1, 2, 3])
        #expect(episodes.count == 3)
        #expect(stub.lastPath == "/api/episode/1,2,3")
    }

    @Test func requestBuildsOnTheBaseURL() throws {
        let client = RickAndMortyClient()
        let request = try client.request(path: "character/1,2", query: [URLQueryItem(name: "page", value: "2")])

        #expect(request.url?.absoluteString == "https://rickandmortyapi.com/api/character/1,2?page=2")
        #expect(client.configuration.graphQLURL.absoluteString == "https://rickandmortyapi.com/graphql")
    }
}
