import Foundation
import Testing
@testable import RickAndMortyKit

@Suite("Page sequences and resolving resource URLs")
struct PagingTests {
    /// Serves `/episode?page=n` from episodes-page-n.json.
    static func episodePages() -> StubbedClient {
        StubbedClient { request in
            let page = request.queryValue("page") ?? "1"
            return try .json("episodes-page-" + page)
        }
    }

    @Test func pagesFollowNextUntilTheEnd() async throws {
        let stub = Self.episodePages()
        var numbers: [Int] = []
        var counts: [Int] = []
        for try await page in stub.client.episodePages() {
            numbers.append(page.number)
            counts.append(page.results.count)
        }

        let expectedNumbers: [Int] = [1, 2, 3]
        let expectedCounts: [Int] = [20, 20, 11]
        #expect(numbers == expectedNumbers)
        #expect(counts == expectedCounts)
        #expect(stub.requests.count == 3)
        // Every page is asked of the client's own host, not the host in `info.next`.
        let hosts = Set(stub.requests.compactMap { $0.url?.host })
        #expect(hosts == [stub.host])
    }

    @Test func itemsWalkEveryPage() async throws {
        let stub = Self.episodePages()
        var codes: [String] = []
        for try await episode in stub.client.allEpisodes() {
            codes.append(episode.codeString)
        }

        #expect(codes.count == 51)
        #expect(codes.first == "S01E01")
        #expect(codes.last == "S05E10")
    }

    @Test func collectReturnsEveryItem() async throws {
        let stub = Self.episodePages()
        let episodes = try await stub.client.allEpisodes().collect()

        #expect(episodes.count == 51)
        let seasons = episodes.groupedBySeason()
        let seasonNumbers = seasons.map(\.season)
        let expectedSeasons: [Int] = [1, 2, 3, 4, 5]
        #expect(seasonNumbers == expectedSeasons)
        #expect(seasons.first?.episodes.count == 11)
        #expect(seasons.last?.episodes.last?.name == "Rickmurai Jack")
    }

    @Test func startingPageAndFilterAreKept() async throws {
        let stub = Self.episodePages()
        var numbers: [Int] = []
        for try await page in stub.client.episodePages(filter: EpisodeFilter(name: "rick"), startingAt: 2) {
            numbers.append(page.number)
        }

        let expected: [Int] = [2, 3]
        #expect(numbers == expected)
        let names = Set(stub.requests.compactMap { $0.queryValue("name") })
        #expect(names == ["rick"])
    }

    @Test func singlePageSequence() async throws {
        let stub = StubbedClient { _ in try .json("characters-filtered") }
        let smiths = try await stub.client.allCharacters(filter: CharacterFilter(name: "smith", status: .alive)).collect()

        #expect(smiths.count == 4)
        #expect(stub.requests.count == 1)
    }

    @Test func noMatchesEndsAtOnce() async throws {
        let stub = StubbedClient { _ in try .json("error-nothing-here", status: 404) }
        var pages = 0
        for try await _ in stub.client.locationPages(filter: LocationFilter(name: "nowhere")) {
            pages += 1
        }

        #expect(pages == 0)
        #expect(stub.requests.count == 1)
    }

    @Test func errorsStopTheSequence() async throws {
        let stub = StubbedClient { request in
            if request.queryValue("page") == "2" {
                return .status(500)
            }
            return try .json("episodes-page-1")
        }

        var seen = 0
        var failed = false
        do {
            for try await _ in stub.client.allEpisodes() {
                seen += 1
            }
        } catch is RickAndMortyError {
            failed = true
        }
        #expect(failed)
        #expect(seen == 20)
    }

    @Test func episodesOfACharacter() async throws {
        let stub = StubbedClient { _ in try .json("episodes-multiple") }
        let rick = try Fixture.decode(RMCharacter.self, from: "character")
        let episodes = try await stub.client.episodes(of: rick)

        // Rick is in all 51 episodes: one request with every id, and the episodes come back by id.
        #expect(stub.requests.count == 1)
        let path = stub.lastPath ?? ""
        #expect(path.hasPrefix("/api/episode/1,2,3,"))
        #expect(path.hasSuffix(",51"))
        let names = episodes.map(\.name)
        let expected: [String] = ["Pilot", "Lawnmower Dog", "Anatomy Park"]
        #expect(names == expected)
    }

    @Test func residentsOfALocation() async throws {
        let stub = StubbedClient { _ in .raw("[]") }
        let earth = try Fixture.decode(RMLocation.self, from: "location")
        _ = try await stub.client.residents(of: earth)

        let ids = earth.residentIDs.map { String($0) }.joined(separator: ",")
        #expect(stub.lastPath == "/api/character/" + ids)
    }

    @Test func charactersInAnEpisode() async throws {
        let stub = StubbedClient { _ in try .json("characters-multiple") }
        let pilot = try Fixture.decode(RMEpisode.self, from: "episode")
        let characters = try await stub.client.characters(in: pilot)

        #expect(characters.map(\.id).contains(1))
        #expect(stub.lastPath?.hasPrefix("/api/character/1,2,") == true)
    }

    @Test func originAndLocation() async throws {
        let stub = StubbedClient { _ in try .json("location") }
        let rick = try Fixture.decode(RMCharacter.self, from: "character")
        let morty = try Fixture.decode(RMCharacter.self, from: "character-unknown-origin")

        let origin = try await stub.client.location(rick.origin)
        #expect(origin?.name == "Earth (C-137)")
        #expect(stub.lastPath == "/api/location/1")

        let unknown = try await stub.client.location(morty.origin)
        #expect(unknown == nil)
        #expect(stub.requests.count == 1)
    }

    @Test func resourceAtAnAPIURLUsesTheBaseURL() async throws {
        let stub = StubbedClient { _ in try .json("episodes-page-2") }
        let next = try #require(URL(string: "https://rickandmortyapi.com/api/episode/?page=2"))
        let page = try await stub.client.resource(at: next, as: Page<RMEpisode>.self)

        #expect(page.number == 2)
        #expect(stub.requests.last?.url?.host == stub.host)
        #expect(stub.lastPath == "/api/episode")
        #expect(stub.lastQueryValue("page") == "2")
    }

    @Test func idsFromURLs() throws {
        let urls: [URL] = [
            try #require(URL(string: "https://rickandmortyapi.com/api/episode/7")),
            try #require(URL(string: "https://rickandmortyapi.com/api/episode/")),
            try #require(URL(string: "https://rickandmortyapi.com/api/episode/28")),
        ]
        let expected: [Int] = [7, 28]
        #expect(ResourceURL.ids(urls) == expected)
    }
}
