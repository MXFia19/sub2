import SwiftUI

// MARK: – Main Chat View
struct ChatView: View {
    let channelName: String
    let channelId: String?
    let token: String?

    @StateObject private var chat = ChatService()
    @State private var autoScroll = true
    @State private var showScrollButton = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Status bar ───────────────────────────────────────────
            HStack(spacing: 6) {
                Circle()
                    .fill(chat.isConnected ? Color.tSuccess : Color.tDanger)
                    .frame(width: 6, height: 6)
                Text(chat.isConnected ? "Chat connecté" : "Connexion...")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.tMuted)
                Spacer()
                Text("#\(channelName)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.tPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.tCard)
            .overlay(Divider().background(Color.tBorder), alignment: .bottom)

            // ── Messages ─────────────────────────────────────────────
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(chat.messages.reversed()) { msg in
                                ChatMessageRow(message: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    // ✅ Syntaxe compatible avec iOS 16 (sans le _,)
                    .onChange(of: chat.messages.first?.id) { newId in
                        guard autoScroll, let id = newId else { return }
                        withAnimation(.linear(duration: 0.1)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }

                // Scroll to bottom button
                if !autoScroll {
                    Button {
                        autoScroll = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                            Text("Suivre le chat")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.tPrimary)
                        .cornerRadius(20)
                    }
                    .padding(10)
                }
            }
        }
        .background(Color.tDark)
        .onAppear {
            Task {
                await EmoteService.shared.loadGlobals()
                if let cid = channelId {
                    await EmoteService.shared.loadChannel(channelId: cid, channelName: channelName)
                }
                chat.channelId = channelId
                chat.connect(channel: channelName, token: token)
            }
        }
        .onDisappear {
            chat.disconnect()
        }
    }
}

// MARK: – Single Message Row
struct ChatMessageRow: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Reply indicator
            if let reply = message.replyTo {
                HStack(spacing: 4) {
                    Rectangle().fill(Color.tMuted).frame(width: 2)
                    Text("↩ \(reply)")
                        .font(.system(size: 11))
                        .foregroundColor(.tMuted)
                        .lineLimit(1)
                }
                .padding(.leading, 12)
            }

            // Main message
            HStack(alignment: .top, spacing: 0) {
                // Highlight bar
                if message.isHighlight {
                    Rectangle().fill(Color.tWarning).frame(width: 3)
                }

                WrappingHStack(message: message)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
        .background(message.isHighlight ? Color.tWarning.opacity(0.08) : Color.clear)
    }
}

// MARK: – Wrapping HStack (Native iOS 16 Layout)
struct WrappingHStack: View {
    let message: ChatMessage

    var body: some View {
        let blocks = buildBlocks()

        // ✨ LE NOUVEAU MOTEUR DE MISE EN PAGE PARFAIT
        MessageFlowLayout(spacing: 4, lineSpacing: 4) {
            // Badges
            ForEach(message.badges) { badge in
                AsyncImage(url: URL(string: badge.url)) { img in
                    img.resizable().interpolation(.medium)
                } placeholder: { Color.clear }
                .frame(width: 18, height: 18)
            }

            // Username
            Text(message.displayName + ":")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(message.color)

            // Tokens
            ForEach(blocks) { block in
                switch block.content {
                case .text(let t):
                    Text(t)
                        .font(.system(size: 13))
                        .foregroundColor(message.isAction ? message.color : .tText)
                case .emote(let e):
                    CachedEmoteImage(url: e.url, name: e.name)
                case .mention(let m):
                    Text("@\(m)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.tPrimary)
                }
            }
        }
        // Force l'alignement sur la gauche
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildBlocks() -> [TokenBlock] {
        message.tokens.enumerated().map { idx, token in
            TokenBlock(id: idx, content: token)
        }
    }
}

struct TokenBlock: Identifiable {
    let id: Int
    let content: MessageToken
}

// MARK: – Native Message Layout Algorithm Corrigé
struct MessageFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Sécurise la largeur pour éviter un plantage ou un calcul infini
        let width = proposal.replacingUnspecifiedDimensions(by: .init(width: UIScreen.main.bounds.width, height: 0)).width
        return computeLayout(width: width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = computeLayout(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = layout.positions[index]
            // Aligne verticalement l'élément au milieu de la ligne
            let yOffset = (layout.lineHeights[index] - subview.sizeThatFits(.unspecified).height) / 2
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y + yOffset), proposal: .unspecified)
        }
    }

    // Le moteur mathématique qui aligne chaque mot de gauche à droite
    private func computeLayout(width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint], lineHeights: [CGFloat]) {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxLineHeight: CGFloat = 0
        
        var positions: [CGPoint] = []
        var lineHeights: [CGFloat] = Array(repeating: 0, count: subviews.count)
        var lineStartIndex = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            
            // Si on dépasse l'écran, on passe à la ligne
            if currentX > 0 && currentX + size.width > width {
                for j in lineStartIndex..<index { lineHeights[j] = maxLineHeight }
                currentX = 0
                currentY += maxLineHeight + lineSpacing
                maxLineHeight = 0
                lineStartIndex = index
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            maxLineHeight = max(maxLineHeight, size.height)
            currentX += size.width + spacing
        }
        
        // Dernière ligne
        for j in lineStartIndex..<subviews.count { lineHeights[j] = maxLineHeight }

        return (CGSize(width: width, height: currentY + maxLineHeight), positions, lineHeights)
    }
}

// MARK: – Cached Emote Image
struct CachedEmoteImage: View {
    let url: String
    let name: String

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let img):
                img.resizable()
                    .interpolation(.medium)
                    .scaledToFit()
            case .failure:
                Text(name).font(.system(size: 13)).foregroundColor(.tMuted)
            case .empty:
                Color.clear
            @unknown default:
                EmptyView()
            }
        }
        // Force la taille pour éviter que le chat tremble quand l'image charge !
        .frame(height: 24)
    }
}
