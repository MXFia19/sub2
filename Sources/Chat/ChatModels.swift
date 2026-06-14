import Foundation
import SwiftUI

// MARK: – Emote
struct TwitchEmote: Identifiable, Hashable {
    let id: String
    let name: String
    let url: String  // CDN URL 2x
    var source: EmoteSource = .twitch
}

enum EmoteSource: String {
    case twitch, bttv, ffz, seventv
}

// MARK: – Badge
struct TwitchBadge: Identifiable, Hashable {
    let id: String   // e.g. "moderator/1"
    let url: String
}

// MARK: – Chat Message token
enum MessageToken: Identifiable {
    case text(String)
    case emote(TwitchEmote)
    case mention(String)

    var id: String {
        switch self {
        case .text(let t):    return "t_\(t.hashValue)"
        case .emote(let e):   return "e_\(e.id)"
        case .mention(let m): return "m_\(m)"
        }
    }
}

// MARK: – Chat Message
struct ChatMessage: Identifiable {
    let id: String
    let userId: String
    let userName: String
    let displayName: String
    let color: Color
    let badges: [TwitchBadge]
    let tokens: [MessageToken]
    let timestamp: Date
    var isAction: Bool = false   // /me messages
    var isHighlight: Bool = false
    var replyTo: String? = nil
}

// MARK: – IRC raw
struct IRCMessage {
    let raw: String
    let tags: [String: String]
    let command: String
    let params: [String]
    let prefix: String?

    var channel: String? { params.first?.hasPrefix("#") == true ? String(params[0].dropFirst()) : nil }
    var text: String? { params.count > 1 ? params[1] : nil }
    var displayName: String { tags["display-name"] ?? tags["login"] ?? "" }
    var userId: String { tags["user-id"] ?? "" }
    var msgId: String { tags["id"] ?? UUID().uuidString }
    var color: String { tags["color"] ?? "" }
    var badgesRaw: String { tags["badges"] ?? "" }
    var emotesRaw: String { tags["emotes"] ?? "" }
    var isReply: Bool { tags["reply-parent-msg-id"] != nil }
    var replyUser: String? { tags["reply-parent-display-name"] }
}
