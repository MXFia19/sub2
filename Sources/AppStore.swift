import SwiftUI
import Combine

// MARK: - AppStore Principal
class AppStore: ObservableObject {
    @Published var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") }
    }

    // ✨ Le Proxy est maintenant désactivé de base (false)
    @Published var useProxy: Bool {
        didSet { UserDefaults.standard.set(useProxy, forKey: "useProxy") }
    }

    @Published var history: [HistoryItem] = []

    init() {
        // Chargement de la langue
        let savedLang = UserDefaults.standard.string(forKey: "lang") ?? "fr"
        self.lang = Lang(rawValue: savedLang) ?? .fr

        // Chargement du proxy (si jamais défini auparavant, on force à false)
        if UserDefaults.standard.object(forKey: "useProxy") == nil {
            self.useProxy = false
        } else {
            self.useProxy = UserDefaults.standard.bool(forKey: "useProxy")
        }

        loadHistory()
    }

    // MARK: - Gestion de l'historique
    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "history"),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            self.history = decoded
        }
    }

    func saveToHistory(_ item: HistoryItem) {
        var current = history.filter { $0.term != item.term }
        current.insert(item, at: 0)
        if current.count > 50 { current = Array(current.prefix(50)) } // Garde les 50 derniers
        history = current
        
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "history")
        }
    }
    
    func clearHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: "history")
    }

    // MARK: - Dictionnaire des Traductions
    private let dict: [Lang: [String: String]] = [
        .fr: [
            // Onglets & Header
            "title": "Twitch sans Sub",
            "tab_discovery": "Découverte",
            "tab_streamer": "Streamers",
            "tab_history": "VODs",
            "tab_direct": "Lien / ID",
            "settings": "Paramètres",

            // Statuts Live / VOD
            "live_on": "EN DIRECT",
            "offline": "HORS LIGNE",
            "offline_since": "Hors ligne depuis : ",
            "btn_watch_live": "Regarder le live",
            "live_badge": "LIVE",

            // Lecteur Vidéo
            "reduce": "Réduire",
            "loading_vod": "Chargement de la vidéo...",
            "back": "Retour",

            // Textes Découverte & Streamers
            "search_streamer_placeholder": "Nom du streamer...",
            "search_btn": "Rechercher",
            "favorites_title": "💜 Vos Chaînes Suivies",
            "top_streams_title": "🔥 Top Streams du Moment",

            // Historique
            "history_title": "Historique des VODs",
            "history_empty": "Aucune vidéo dans l'historique.",
            "clear_history": "Vider l'historique",

            // Direct Link
            "direct_placeholder": "Lien de la VOD ou ID...",
            "direct_btn": "Lancer la VOD",

            // Authentification Twitch
            "login_twitch": "Se connecter avec Twitch",
            "logout_twitch": "Se déconnecter",
            "login_msg": "Connectez-vous pour retrouver vos chaînes préférées.",
            
            // Paramètres
            "settings_title": "Paramètres de l'application",
            "settings_proxy": "Activer le Proxy",
            "settings_proxy_desc": "Utilisez le proxy uniquement si Twitch bloque certaines de vos VODs.",
            "settings_lang": "Langue"
        ],
        .en: [
            // Tabs & Header
            "title": "Twitch Ad-Free",
            "tab_discovery": "Discovery",
            "tab_streamer": "Streamers",
            "tab_history": "VODs",
            "tab_direct": "Link / ID",
            "settings": "Settings",

            // Live / VOD Status
            "live_on": "LIVE",
            "offline": "OFFLINE",
            "offline_since": "Offline since: ",
            "btn_watch_live": "Watch Live",
            "live_badge": "LIVE",

            // Video Player
            "reduce": "Minimize",
            "loading_vod": "Loading video...",
            "back": "Back",

            // Discovery & Streamers texts
            "search_streamer_placeholder": "Streamer name...",
            "search_btn": "Search",
            "favorites_title": "💜 Followed Channels",
            "top_streams_title": "🔥 Top Streams Right Now",

            // History
            "history_title": "VOD History",
            "history_empty": "No videos in history.",
            "clear_history": "Clear History",

            // Direct Link
            "direct_placeholder": "VOD Link or ID...",
            "direct_btn": "Play VOD",

            // Twitch Auth
            "login_twitch": "Login with Twitch",
            "logout_twitch": "Logout",
            "login_msg": "Log in to find your favorite channels.",
            
            // Settings
            "settings_title": "App Settings",
            "settings_proxy": "Enable Proxy",
            "settings_proxy_desc": "Use the proxy only if Twitch is blocking your VODs.",
            "settings_lang": "Language"
        ]
    ]

    // Fonction de traduction
    func t(_ key: String) -> String {
        return dict[lang]?[key] ?? dict[.en]?[key] ?? key
    }
}
