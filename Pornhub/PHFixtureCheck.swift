import Foundation

enum PHFixtureCheck {
    static func run() throws {
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PH_FIXTURES"] ?? "Tests/Fixtures")
        let home = try String(contentsOf: root.appendingPathComponent("home.html"), encoding: .utf8)
        let videos = PHParser.videos(in: home)
        precondition(videos.count >= 20, "home videos \(videos.count)")
        precondition(videos[0].vkey == "6ac27ce22fb52", videos[0].vkey)
        precondition(videos[0].author == "Delsa jooon", videos[0].author)
        precondition(videos[0].duration == "11:39", videos[0].duration)
        precondition(videos[0].verified, "expected verified")
        precondition(!videos[0].thumb.isEmpty, "thumb")
        let chips = PHParser.chips(in: home)
        precondition(chips.first?.title == "Shorties", chips.first?.title ?? "none")
        precondition(chips.contains { $0.title == "欧美" }, "missing 欧美")

        let search = try String(contentsOf: root.appendingPathComponent("search.html"), encoding: .utf8)
        let page = PHParser.page(in: search, current: 1)
        precondition(page.videos.count == 30, "search \(page.videos.count)")
        precondition(page.nextPage == 2, "next \(String(describing: page.nextPage))")

        let video = try String(contentsOf: root.appendingPathComponent("video.html"), encoding: .utf8)
        let detail = PHParser.detail(in: video, fallback: videos[0])
        precondition(detail.qualities.contains { $0.height == 1080 }, "missing 1080")
        precondition(detail.qualities.contains { $0.height == 240 }, "missing 240")
        precondition(detail.qualities.allSatisfy { $0.url.absoluteString.contains(".m3u8") }, "not hls")
        precondition(detail.durationSeconds == 699, "duration \(detail.durationSeconds)")
        precondition(detail.tags.contains { $0.title == "劲爆重口味" }, "tags \(detail.tags.map(\.title))")
        precondition(detail.viewsText.contains("41.7K") || detail.viewsText.contains("41"), detail.viewsText)

        let relatedData = try Data(contentsOf: root.appendingPathComponent("related.json"))
        let related = PHParser.related(from: relatedData)
        precondition(related.count >= 40, "related \(related.count)")
        precondition(related.allSatisfy { !$0.vkey.isEmpty && !$0.title.isEmpty }, "blank related")

        let cats = try String(contentsOf: root.appendingPathComponent("cats.html"), encoding: .utf8)
        let categories = PHParser.categories(in: cats)
        precondition(categories.count >= 100, "cats \(categories.count)")
        precondition(categories[0].title == "熟女", categories[0].title)
        precondition(categories[0].count.contains("48"), categories[0].count)

        let stars = try String(contentsOf: root.appendingPathComponent("stars.html"), encoding: .utf8)
        let performers = PHParser.performers(in: stars)
        precondition(performers.contains { $0.name.lowercased().contains("johnny") }, "stars \(performers.prefix(5).map(\.name))")

        let gifs = PHParser.gifs(in: try String(contentsOf: root.appendingPathComponent("gifs.html"), encoding: .utf8))
        precondition(gifs.count >= 10, "gifs \(gifs.count)")
        precondition(gifs.contains { !$0.animated.isEmpty }, "gif animation")

        let albums = PHParser.albums(in: try String(contentsOf: root.appendingPathComponent("albums.html"), encoding: .utf8))
        precondition(albums.count >= 10, "albums \(albums.count)")

        let playlists = PHParser.playlists(in: try String(contentsOf: root.appendingPathComponent("playlists.html"), encoding: .utf8))
        precondition(playlists.contains { $0.id == "109018181" }, "playlist ids \(playlists.prefix(3).map(\.id))")

        let chunk = try String(contentsOf: root.appendingPathComponent("playlist-chunk.html"), encoding: .utf8)
        let chunkVideos = PHParser.videos(in: chunk)
        precondition(chunkVideos.count >= 5, "chunk \(chunkVideos.count)")

        print("ok videos=\(videos.count) search=\(page.videos.count) qualities=\(detail.qualities.count) related=\(related.count) cats=\(categories.count) stars=\(performers.count) gifs=\(gifs.count) albums=\(albums.count) playlists=\(playlists.count)")
    }
}
