import Foundation

// MARK: – Emote cache per channel
actor EmoteService {
    static let shared = EmoteService()
    private init() {}

    // Global emote maps: name → TwitchEmote
    private var globalBTTV: [String: TwitchEmote] = [:]
    private var globalFFZ:  [String: TwitchEmote] = [:]
    private var global7TV:  [String: TwitchEmote] = [:]

    // Per-channel: channelId → name → TwitchEmote
    private var channelBTTV: [String: [String: TwitchEmote]] = [:]
    private var channelFFZ:  [String: [String: TwitchEmote]] = [:]
    private var channel7TV:  [String: [String: TwitchEmote]] = [:]

    // Twitch emotes from chat tags: id → TwitchEmote
    private var twitchById: [String: TwitchEmote] = [:]

    private var loadedChannels: Set<String> = []

    // MARK: – Load globals once
    func loadGlobals() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadBTTVGlobal() }
            group.addTask { await self.loadFFZGlobal() }
            group.addTask { await self.load7TVGlobal() }
        }
        logger.success("EMOTES", "Emotes globales chargées",
                       "BTTV:\(globalBTTV.count) FFZ:\(globalFFZ.count) 7TV:\(global7TV.count)")
    }

    // MARK: – Load per channel
    func loadChannel(channelId: String, channelName: String) async {
        guard !loadedChannels.contains(channelId) else { return }
        loadedChannels.insert(channelId)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadBTTVChannel(channelId: channelId) }
            group.addTask { await self.loadFFZChannel(channelName: channelName) }
            group.addTask { await self.load7TVChannel(channelId: channelId) }
        }
        let total = (channelBTTV[channelId]?.count ?? 0)
                  + (channelFFZ[channelId]?.count ?? 0)
                  + (channel7TV[channelId]?.count ?? 0)
        logger.success("EMOTES", "Emotes canal \(channelName) chargées", "\(total) emotes")
    }

    // MARK: – Register Twitch emote from chat tag
    func registerTwitchEmote(id: String, name: String) {
        if twitchById[id] == nil {
            twitchById[id] = TwitchEmote(
                id: id, name: name,
                url: "https://static-cdn.jtvnw.net/emoticons/v2/\(id)/default/dark/2.0",
                source: .twitch
            )
        }
    }

    // MARK: – Resolve emote by name (channel-first priority)
    func resolve(name: String, channelId: String?) -> TwitchEmote? {
        if let cid = channelId {
            if let e = channelBTTV[cid]?[name] { return e }
            if let e = channelFFZ[cid]?[name]  { return e }
            if let e = channel7TV[cid]?[name]  { return e }
        }
        if let e = globalBTTV[name] { return e }
        if let e = globalFFZ[name]  { return e }
        if let e = global7TV[name]  { return e }
        return nil
    }

    // MARK: – Resolve by Twitch emote ID (from IRC tag)
    func resolveById(_ id: String) -> TwitchEmote? { twitchById[id] }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: – BTTV
    private func loadBTTVGlobal() async {
        guard let url = URL(string: "https://api.betterttv.net/3/cached/emotes/global"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        for obj in arr {
            if let e = bttvEmote(obj) { globalBTTV[e.name] = e }
        }
    }

    private func loadBTTVChannel(channelId: String) async {
        guard let url = URL(string: "https://api.betterttv.net/3/cached/users/twitch/\(channelId)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        var map: [String: TwitchEmote] = [:]
        for key in ["channelEmotes", "sharedEmotes"] {
            if let arr = json[key] as? [[String: Any]] {
                for obj in arr { if let e = bttvEmote(obj) { map[e.name] = e } }
            }
        }
        channelBTTV[channelId] = map
    }

    private func bttvEmote(_ obj: [String: Any]) -> TwitchEmote? {
        guard let id   = obj["id"]   as? String,
              let name = obj["code"] as? String else { return nil }
        return TwitchEmote(id: id, name: name,
                           url: "https://cdn.betterttv.net/emote/\(id)/2x",
                           source: .bttv)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: – FFZ
    private func loadFFZGlobal() async {
        guard let url = URL(string: "https://api.frankerfacez.com/v1/set/global"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sets = json["sets"] as? [String: Any] else { return }
        for (_, setValue) in sets {
            guard let setObj = setValue as? [String: Any],
                  let emoticons = setObj["emoticons"] as? [[String: Any]] else { continue }
            for obj in emoticons { if let e = ffzEmote(obj) { globalFFZ[e.name] = e } }
        }
    }

    private func loadFFZChannel(channelName: String) async {
        guard let url = URL(string: "https://api.frankerfacez.com/v1/room/\(channelName)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sets = json["sets"] as? [String: Any] else { return }
        var map: [String: TwitchEmote] = [:]
        for (_, setValue) in sets {
            guard let setObj = setValue as? [String: Any],
                  let emoticons = setObj["emoticons"] as? [[String: Any]] else { continue }
            for obj in emoticons { if let e = ffzEmote(obj) { map[e.name] = e } }
        }
        channelFFZ[channelName] = map
    }

    private func ffzEmote(_ obj: [String: Any]) -> TwitchEmote? {
        guard let id   = obj["id"] as? Int,
              let name = obj["name"] as? String,
              let urls = (obj["urls"] as? [String: Any]),
              let url  = (urls["2"] ?? urls["1"]) as? String else { return nil }
        let fullURL = url.hasPrefix("//") ? "https:\(url)" : url
        return TwitchEmote(id: "\(id)", name: name, url: fullURL, source: .ffz)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: – 7TV
    private func load7TVGlobal() async {
        guard let url = URL(string: "https://7tv.io/v3/emote-sets/global"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let emotes = json["emotes"] as? [[String: Any]] else { return }
        for obj in emotes { if let e = stvEmote(obj) { global7TV[e.name] = e } }
    }

    private func load7TVChannel(channelId: String) async {
        guard let url = URL(string: "https://7tv.io/v3/users/twitch/\(channelId)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let setObj = json["emote_set"] as? [String: Any],
              let emotes = setObj["emotes"] as? [[String: Any]] else { return }
        var map: [String: TwitchEmote] = [:]
        for obj in emotes { if let e = stvEmote(obj) { map[e.name] = e } }
        channel7TV[channelId] = map
    }

    private func stvEmote(_ obj: [String: Any]) -> TwitchEmote? {
        guard let id   = obj["id"] as? String,
              let name = obj["name"] as? String,
              let data = obj["data"] as? [String: Any],
              let host = (data["host"] as? [String: Any])?["url"] as? String else { return nil }
        let url = "https:\(host)/2x.webp"
        return TwitchEmote(id: id, name: name, url: url, source: .seventv)
    }
}
