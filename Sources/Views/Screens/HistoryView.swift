import SwiftUI

struct HistoryView: View {
    let onPlayVod: (String, String?, String?, String?) -> Void
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Vos dernières VODs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .padding(.top, 16)

                let vods = store.history.filter { $0.type == .vod }
                
                if vods.isEmpty {
                    Text("Aucune VOD dans votre historique pour le moment.")
                        .foregroundColor(.tMuted)
                        .padding()
                } else {
                    ForEach(vods, id: \.term) { item in
                        Button {
                            onPlayVod(item.term, item.display, item.thumb, item.streamer)
                        } label: {
                            HStack {
                                // Miniature (à adapter selon tes composants)
                                Rectangle()
                                    .fill(Color.tSurface)
                                    .frame(width: 120, height: 68)
                                    .cornerRadius(8)
                                    .overlay(
                                        Text("VOD").foregroundColor(.tMuted).font(.caption)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.display)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    if let streamer = item.streamer {
                                        Text(streamer)
                                            .font(.caption)
                                            .foregroundColor(.tPrimary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .background(Color.tDark)
    }
}
