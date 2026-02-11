import SwiftUI
import FirebaseFirestore
import Combine
import AudioToolbox
import PhotosUI

// MARK: - 1. YARDIMCI UZANTILAR
extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvas = CGSize(width: width, height: CGFloat(ceil(width/size.width * size.height)))
        UIGraphicsBeginImageContextWithOptions(canvas, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvas))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    func toBase64() -> String? {
        guard let resized = self.resized(toWidth: 150) else { return nil }
        return resized.jpegData(compressionQuality: 0.5)?.base64EncodedString()
    }
}

extension String {
    func toImage() -> UIImage? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return UIImage(data: data)
    }
    var isBase64: Bool { return self.count > 100 }
}

// MARK: - 2. SES VE TİTREŞİM
@MainActor
class HapticManager {
    static let shared = HapticManager()
    func playSuccess() { let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.success) }
    func playError() { let generator = UINotificationFeedbackGenerator(); generator.notificationOccurred(.error) }
    func playLightImpact() { let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred() }
    func playMatchSound() { AudioServicesPlaySystemSound(1016) }
    func playMessageSentSound() { AudioServicesPlaySystemSound(1004) }
}

// MARK: - 3. VERİ MODELLERİ
let avatarList = ["person.fill", "face.smiling.inverse", "ant.circle.fill", "flame.fill", "bolt.fill", "star.fill", "moon.fill", "pawprint.fill", "gamecontroller.fill"]

struct RankOption: Identifiable, Equatable, Hashable { let id = UUID(); let name: String; let color: Color }
struct GameOption: Identifiable, Hashable {
    let id = UUID(); let name: String; let icon: String; let color: Color; let ranks: [RankOption]
    var allowedPartySizes: [Int] {
        switch name {
        case "Valorant", "LoL", "CS2": return [2, 3, 5]
        case "FIFA 24": return [2]
        default: return [2]
        }
    }
    static func == (lhs: GameOption, rhs: GameOption) -> Bool { return lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

let valorantRanks = [RankOption(name: "Demir", color: .gray), RankOption(name: "Bronz", color: .brown), RankOption(name: "Gümüş", color: .white), RankOption(name: "Altın", color: .yellow), RankOption(name: "Platin", color: .cyan), RankOption(name: "Elmas", color: .purple), RankOption(name: "Yücelik", color: .green), RankOption(name: "Ölümsüzlük", color: .red), RankOption(name: "Radyant", color: .orange)]
let lolRanks = [RankOption(name: "Demir", color: .gray), RankOption(name: "Bronz", color: .brown), RankOption(name: "Gümüş", color: .white), RankOption(name: "Altın", color: .yellow), RankOption(name: "Platin", color: .cyan), RankOption(name: "Zümrüt", color: .green), RankOption(name: "Elmas", color: .purple), RankOption(name: "Ustalık", color: .orange), RankOption(name: "Şampiyonluk", color: .red)]
let cs2Ranks = [RankOption(name: "Silver", color: .gray), RankOption(name: "Gold Nova", color: .yellow), RankOption(name: "Master Guardian", color: .blue), RankOption(name: "Eagle", color: .cyan), RankOption(name: "Supreme", color: .purple), RankOption(name: "Global Elite", color: .red)]
let fifaRanks = [RankOption(name: "Div 10", color: .gray), RankOption(name: "Div 8", color: .brown), RankOption(name: "Div 6", color: .white), RankOption(name: "Div 4", color: .yellow), RankOption(name: "Div 2", color: .cyan), RankOption(name: "Div 1", color: .purple), RankOption(name: "Elite", color: .red)]

let gameOptions = [
    GameOption(name: "Valorant", icon: "valorant", color: .red, ranks: valorantRanks),
    GameOption(name: "LoL", icon: "lol", color: .cyan, ranks: lolRanks),
    GameOption(name: "CS2", icon: "cs2", color: .orange, ranks: cs2Ranks),
    GameOption(name: "FIFA 24", icon: "fifa", color: .green, ranks: fifaRanks)
]

extension Color {
    static let deepBackground = Color(red: 0.05, green: 0.05, blue: 0.1)
    static let cardBackground = Color(red: 0.1, green: 0.1, blue: 0.15)
    static let neonBlue = Color(red: 0.0, green: 1.0, blue: 1.0)
    static let neonPink = Color(red: 1.0, green: 0.0, blue: 0.5)
    static let neonRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    let nickname: String; let password: String; let avatar: String; let registerDate: Date
    var reputationScore: Double?; var ratingCount: Int?; var totalRating: Double?
    var isOnline: Bool?; var reportCount: Int?; var bannedUntil: Date?
}

struct RecentChat: Identifiable, Codable {
    @DocumentID var id: String?
    let groupName: String?
    let chatRoomId: String; let lastMessage: String
    let partnerNick: String?; let partnerAvatar: String?
    let players: [String]?
    var unreadCount: Int?; let lastActive: Date
    var safeUnreadCount: Int { return unreadCount ?? 0 }
    var displayName: String { return groupName ?? partnerNick ?? "Bilinmeyen" }
}

struct Lobby: Identifiable, Codable {
    @DocumentID var id: String?
    let gameName: String; let rank: String; let targetSize: Int
    var players: [String]; var isOpen: Bool; let chatRoomId: String; let createdAt: Date
}

struct ChatMessage: Identifiable, Codable {
    @DocumentID var id: String?
    let senderId: String; let text: String; let timestamp: Date
}

// MARK: - 4. BİLEŞENLER

struct LiveAvatarView: View {
    let userId: String; let size: CGFloat; let strokeColor: Color
    @State private var currentAvatar: String = "person.fill"
    
    var body: some View {
        Group {
            if currentAvatar.isBase64, let uiImage = currentAvatar.toImage() {
                Image(uiImage: uiImage).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()).overlay(Circle().stroke(strokeColor, lineWidth: 2))
            } else {
                Image(systemName: currentAvatar).font(.system(size: size * 0.6)).foregroundColor(strokeColor).frame(width: size, height: size).background(Color.deepBackground).clipShape(Circle()).overlay(Circle().stroke(strokeColor, lineWidth: 2))
            }
        }
        .onAppear { startListening() }.onChange(of: userId) { _ in startListening() }
    }
    
    func startListening() {
        if !userId.isEmpty {
            let cleanId = userId.lowercased().trimmingCharacters(in: .whitespaces)
            Firestore.firestore().collection("users").document(cleanId).addSnapshotListener { doc, _ in
                if let doc = doc, doc.exists, let data = doc.data(), let newAvatar = data["avatar"] as? String { self.currentAvatar = newAvatar }
            }
        }
    }
}

struct NeonButtonStyle: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .monospaced)).padding().frame(maxWidth: .infinity).background(color.opacity(0.2)).foregroundColor(color).overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 2).shadow(color: color, radius: configuration.isPressed ? 2 : 10)).cornerRadius(12).scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct GamerTextField: View {
    var placeholder: String; @Binding var text: String; var isSecure: Bool = false
    var body: some View {
        Group { if isSecure { SecureField(placeholder, text: $text) } else { TextField(placeholder, text: $text).textInputAutocapitalization(.never).autocorrectionDisabled(true) } }
        .padding().background(Color.cardBackground).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1)).foregroundColor(.white).font(.system(.body, design: .monospaced))
    }
}

struct GamerBackground: View {
    var body: some View {
        ZStack { Color.deepBackground.ignoresSafeArea(); Circle().fill(Color.neonBlue.opacity(0.1)).frame(width: 300, height: 300).offset(x: -150, y: -300).blur(radius: 50); Circle().fill(Color.neonPink.opacity(0.1)).frame(width: 300, height: 300).offset(x: 150, y: 300).blur(radius: 50) }
    }
}

struct GameListItem: View {
    let game: GameOption
    var body: some View {
        HStack(spacing: 20) {
            if UIImage(named: game.icon) != nil { Image(game.icon).resizable().renderingMode(.original).aspectRatio(contentMode: .fit).frame(width: 60, height: 60).shadow(color: .black.opacity(0.5), radius: 5) } else { Image(systemName: "gamecontroller.fill").font(.system(size: 40)).foregroundColor(game.color) }
            Text(game.name).font(.system(.title2, design: .monospaced, weight: .bold)).foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray)
        }
        .padding().background(Color.cardBackground.opacity(0.8)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(game.color.opacity(0.5), lineWidth: 1)).padding(.horizontal)
    }
}

struct RankGridItem: View {
    let rank: RankOption; let isSelected: Bool
    var body: some View {
        VStack { Text(rank.name).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(isSelected ? .black : rank.color).multilineTextAlignment(.center) }
        .frame(height: 60).frame(maxWidth: .infinity).background(isSelected ? rank.color : Color.cardBackground).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(rank.color, lineWidth: isSelected ? 0 : 2))
    }
}

// MARK: - 5. VIEWMODELS
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false; @Published var errorMessage = ""
    private var db = Firestore.firestore()
    
    func register(nickname: String, password: String, avatar: String, completion: @escaping (Bool) -> Void) {
        if password.count < 8 { self.errorMessage = "Şifre en az 8 karakter olmalı!"; return }
        self.isLoading = true; self.errorMessage = ""
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        db.collection("users").whereField("nickname", isEqualTo: cleanNick).getDocuments { snapshot, _ in
            DispatchQueue.main.async {
                if let docs = snapshot?.documents, !docs.isEmpty { self.errorMessage = "Bu isim alınmış!"; self.isLoading = false; HapticManager.shared.playError() }
                else {
                    let newUser = UserProfile(nickname: cleanNick, password: password, avatar: avatar, registerDate: Date(), reputationScore: 0.0, ratingCount: 0, totalRating: 0.0, isOnline: true, reportCount: 0, bannedUntil: nil)
                    try? self.db.collection("users").document(cleanNick).setData(from: newUser)
                    self.isLoading = false; completion(true); HapticManager.shared.playSuccess()
                }
            }
        }
    }
    
    func login(nickname: String, password: String, completion: @escaping (String?, Double?, Int?) -> Void) {
        self.isLoading = true; self.errorMessage = ""
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        db.collection("users").document(cleanNick).getDocument { document, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                if let document = document, document.exists, let data = document.data() {
                    let savedPassword = data["password"] as? String; let avatar = data["avatar"] as? String ?? "person.fill"; let score = data["reputationScore"] as? Double ?? 0.0; let count = data["ratingCount"] as? Int ?? 0
                    if savedPassword == password { completion(avatar, score, count); HapticManager.shared.playSuccess() }
                    else { self.errorMessage = "Şifre hatalı."; completion(nil, nil, nil); HapticManager.shared.playError() }
                } else { self.errorMessage = "Kullanıcı bulunamadı."; completion(nil, nil, nil); HapticManager.shared.playError() }
            }
        }
    }
    
    func setUserStatus(nickname: String, isOnline: Bool) {
        guard !nickname.isEmpty else { return }
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        db.collection("users").document(cleanNick).updateData(["isOnline": isOnline])
    }
    
    func updateAvatarInstant(nickname: String, newAvatar: String) {
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        Task { try? await db.collection("users").document(cleanNick).updateData(["avatar": newAvatar]) }
    }
    
    func updatePassword(nickname: String, currentPassword: String, newPassword: String, completion: @escaping (Bool) -> Void) {
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        db.collection("users").document(cleanNick).getDocument { snapshot, _ in
            guard let document = snapshot, document.exists, let data = document.data() else { return }
            if let actualPassword = data["password"] as? String, actualPassword != currentPassword {
                DispatchQueue.main.async { self.errorMessage = "Mevcut şifre YANLIŞ!"; completion(false) }; return
            }
            document.reference.updateData(["password": newPassword]) { err in DispatchQueue.main.async { completion(err == nil) } }
        }
    }
    
    func deleteAccount(nickname: String, completion: @escaping (Bool) -> Void) {
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        db.collection("users").document(cleanNick).delete { err in DispatchQueue.main.async { completion(err == nil) } }
    }
}

@MainActor
class MatchmakingViewModel: ObservableObject {
    @Published var isSearching = false
    @Published var matchFound = false
    @Published var currentChatId: String?
    @Published var messages: [ChatMessage] = []
    @Published var recentChats: [RecentChat] = []
    @Published var isReportAllowed: Bool = false
    @Published var ratingAlertMessage = ""
    @Published var showRatingAlert = false
    
    // LOBBY BİLGİLERİ
    @Published var lobbyPlayers: [String] = []
    @Published var lobbyTargetSize: Int = 2
    @Published var lobbyId: String?
    @Published var isLobbyFull: Bool = false
    @Published var isMinimized: Bool = false
    
    // 2 KİŞİLİK EŞLEŞME İÇİN EKSTRALAR
    @Published var partnerIsOnline: Bool = false
    @Published var partnerNickForDuo: String = ""
    
    // GEÇMİŞ SOHBET MODU
    @Published var isHistoryChat: Bool = false
    
    var currentUserNick: String = ""
    var currentUserAvatar: String = "person.fill"
    var myReputationScore: Double = 0.0
    var myRatingCount: Int = 0
    
    private let bannedWords = ["amk", "aq", "mk", "mq", "oç", "oc", "a.q", "a.k", "sik", "s1k", "skm", "sikerim", "siktir", "yarrak", "yarak", "yarram", "amcık", "amcik", "orospu", "kahpe", "fahişe", "sürtük", "piç", "pic", "yavşak", "göt", "got", "ibne", "puşt", "kavat", "gavat", "aptal", "salak", "gerizekalı", "mal", "davar", "öküz", "angut", "hıyar", "keko", "ezik", "çomar", "yobaz", "kaşar", "kezban", "beyinsiz", "ahmak", "şerefsiz"]
    
    private var db = Firestore.firestore()
    
    private var lobbyListener: ListenerRegistration?
    private var chatListener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    private var matchListener: ListenerRegistration?
    private var partnerStatusListener: ListenerRegistration? // YENİ
    
    func filterMessage(_ text: String) -> String {
        var cleanText = text
        for word in bannedWords {
            if cleanText.localizedCaseInsensitiveContains(word) {
                let stars = String(repeating: "*", count: word.count)
                cleanText = cleanText.replacingOccurrences(of: word, with: stars, options: [.caseInsensitive, .diacriticInsensitive])
            }
        }
        return cleanText
    }
    
    func checkBanStatus(completion: @escaping (Bool, String?) -> Void) {
        let cleanMe = currentUserNick.lowercased().trimmingCharacters(in: .whitespaces)
        db.collection("users").document(cleanMe).getDocument { snapshot, error in
            guard let data = snapshot?.data() else { completion(false, nil); return }
            if let banDate = (data["bannedUntil"] as? Timestamp)?.dateValue() {
                if banDate > Date() {
                    let formatter = RelativeDateTimeFormatter(); formatter.locale = Locale(identifier: "tr_TR")
                    let timeStr = formatter.localizedString(for: banDate, relativeTo: Date())
                    completion(true, "AFK nedeniyle cezalısın. \(timeStr) açılacak.")
                    return
                }
            }
            completion(false, nil)
        }
    }
    
    func startReportTimer() {
        self.isReportAllowed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 180) { self.isReportAllowed = true }
    }
    
    // YENİ: PARTNER DURUMUNU DİNLE (2 KİŞİLİK İÇİN)
    func listenToPartnerStatus(nickname: String) {
        partnerStatusListener?.remove()
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        partnerStatusListener = db.collection("users").document(cleanNick).addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self, let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                self.partnerIsOnline = data["isOnline"] as? Bool ?? false
            }
        }
    }
    
    func reportAFK(targetUser: String, completion: @escaping (Bool, String) -> Void) {
        if !isReportAllowed { completion(false, "Eşleşme yeni başladı. Şikayet için 3 dakika bekle."); return }
        
        let cleanTarget = targetUser.lowercased().trimmingCharacters(in: .whitespaces)
        let cleanMe = currentUserNick.lowercased().trimmingCharacters(in: .whitespaces)
        let ref = db.collection("users").document(cleanTarget)
        let reportCheckRef = ref.collection("reporters").document(cleanMe)
        
        reportCheckRef.getDocument { snapshot, error in
            if let snapshot = snapshot, snapshot.exists { completion(false, "Zaten şikayet ettin."); return }
            Task {
                do {
                    _ = try await self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                        let userDoc: DocumentSnapshot; do { try userDoc = transaction.getDocument(ref) } catch let nsError as NSError { errorPointer?.pointee = nsError; return nil }
                        let data = userDoc.data() ?? [:]; var currentReports = data["reportCount"] as? Int ?? 0; currentReports += 1
                        var updateData: [String: Any] = ["reportCount": currentReports]
                        if currentReports >= 5 {
                            let banDate = Date().addingTimeInterval(24 * 60 * 60)
                            updateData["bannedUntil"] = banDate; updateData["reportCount"] = 0
                        }
                        transaction.updateData(updateData, forDocument: ref)
                        transaction.setData(["timestamp": Date()], forDocument: reportCheckRef)
                        return nil
                    })
                    completion(true, "Şikayet edildi.")
                } catch { completion(false, "Hata.") }
            }
        }
    }
    
    func submitRating(for targetUser: String, rating: Double) {
        let cleanTarget = targetUser.lowercased().trimmingCharacters(in: .whitespaces)
        let cleanMe = currentUserNick.lowercased().trimmingCharacters(in: .whitespaces)
        let ref = db.collection("users").document(cleanTarget)
        let raterRef = self.db.collection("users").document(cleanTarget).collection("raters").document(cleanMe)
        
        raterRef.getDocument { [weak self] snapshot, _ in
            guard let self = self else { return }
            if let snapshot = snapshot, snapshot.exists {
                DispatchQueue.main.async {
                    self.ratingAlertMessage = "Bu oyuncuyu zaten puanladınız!"
                    self.showRatingAlert = true
                }
                return
            }
            Task {
                do {
                    _ = try await self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                        let userDoc: DocumentSnapshot; do { try userDoc = transaction.getDocument(ref) } catch let nsError as NSError { errorPointer?.pointee = nsError; return nil }
                        let data = userDoc.data() ?? [:]
                        let oldTotal = data["totalRating"] as? Double ?? 0.0
                        let oldCount = data["ratingCount"] as? Int ?? 0
                        let newTotal = oldTotal + rating; let newCount = oldCount + 1; let newScore = newTotal / Double(newCount)
                        transaction.updateData(["totalRating": newTotal, "ratingCount": newCount, "reputationScore": newScore], forDocument: ref)
                        transaction.setData(["timestamp": Date()], forDocument: raterRef)
                        return nil
                    })
                } catch { print("Rating failed: \(error)") }
            }
        }
    }
    
    func prepareForNewUser(nickname: String, avatar: String, score: Double, count: Int) {
        resetLocalState(); self.currentUserNick = nickname.lowercased().trimmingCharacters(in: .whitespaces); self.currentUserAvatar = avatar; self.myReputationScore = score; self.myRatingCount = count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.fetchHistory() }
    }
    
    func resetLocalState() {
        self.isSearching = false; self.matchFound = false; self.currentChatId = nil; self.messages = []; self.recentChats = []
        self.lobbyPlayers = []; self.lobbyId = nil; self.isLobbyFull = false; self.isMinimized = false
        self.isHistoryChat = false
        self.matchListener?.remove(); self.chatListener?.remove(); self.lobbyListener?.remove(); self.historyListener?.remove(); self.partnerStatusListener?.remove()
        self.isReportAllowed = false
    }
    
    func findLobby(game: String, rank: String, targetSize: Int) {
        self.lobbyTargetSize = targetSize
        self.isLobbyFull = false
        self.isMinimized = false
        self.isHistoryChat = false
        self.lobbyPlayers = [currentUserNick]
        self.matchFound = true
        self.isSearching = true
        HapticManager.shared.playLightImpact()
        
        db.collection("lobbies")
            .whereField("gameName", isEqualTo: game)
            .whereField("rank", isEqualTo: rank)
            .whereField("targetSize", isEqualTo: targetSize)
            .whereField("isOpen", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let doc = snapshot?.documents.first {
                    self.joinLobby(lobbyId: doc.documentID)
                } else {
                    self.createLobby(game: game, rank: rank, targetSize: targetSize)
                }
            }
    }
    
    func createLobby(game: String, rank: String, targetSize: Int) {
        let newLobbyRef = db.collection("lobbies").document()
        let chatId = newLobbyRef.documentID
        let lobbyData: [String: Any] = [
            "gameName": game, "rank": rank, "targetSize": targetSize,
            "players": [currentUserNick], "isOpen": true, "chatRoomId": chatId, "createdAt": Date()
        ]
        newLobbyRef.setData(lobbyData) { error in
            if error == nil { self.joinLobby(lobbyId: newLobbyRef.documentID) }
        }
    }
    
    func joinLobby(lobbyId: String) {
        let lobbyRef = db.collection("lobbies").document(lobbyId)
        lobbyRef.updateData(["players": FieldValue.arrayUnion([currentUserNick])])
        self.lobbyId = lobbyId
        listenToLobby(lobbyId: lobbyId)
    }
    
    func listenToLobby(lobbyId: String) {
        lobbyListener?.remove()
        lobbyListener = db.collection("lobbies").document(lobbyId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            if let players = data["players"] as? [String] {
                DispatchQueue.main.async {
                    self.lobbyPlayers = players
                    self.currentChatId = data["chatRoomId"] as? String
                    
                    if players.count >= self.lobbyTargetSize {
                        self.isLobbyFull = true
                        self.isSearching = false // Arama bitti, oyun başladı
                        self.db.collection("lobbies").document(lobbyId).updateData(["isOpen": false])
                        
                        // EĞER 2 KİŞİLİKSE PARTNERİ DİNLEMEYE BAŞLA
                        if self.lobbyTargetSize == 2 {
                            if let partner = players.first(where: { $0 != self.currentUserNick }) {
                                self.partnerNickForDuo = partner
                                self.listenToPartnerStatus(nickname: partner)
                            }
                        }
                        
                        if self.chatListener == nil, let cid = self.currentChatId {
                            self.startChat(chatId: cid)
                            HapticManager.shared.playMatchSound()
                        }
                    } else {
                        self.isLobbyFull = false
                    }
                }
            }
        }
    }
    
    func fetchHistory() {
        guard !currentUserNick.isEmpty else { return }
        historyListener?.remove()
        historyListener = db.collection("users").document(currentUserNick).collection("recent_chats").order(by: "lastActive", descending: true).addSnapshotListener { [weak self] snapshot, _ in
            self?.recentChats = snapshot?.documents.compactMap { try? $0.data(as: RecentChat.self) } ?? []
        }
    }
    
    func openChatFromHistory(chat: RecentChat) {
        self.currentChatId = chat.chatRoomId
        self.isHistoryChat = true
        self.matchFound = true
        self.isLobbyFull = true
        self.lobbyPlayers = chat.players ?? []
        self.lobbyTargetSize = chat.players?.count ?? 2 // Varsayılan 2
        
        // Geçmişte açılsa bile eğer 2 kişiyse partner durumunu dinle
        if let players = chat.players, players.count == 2 {
            if let partner = players.first(where: { $0 != self.currentUserNick }) {
                self.partnerNickForDuo = partner
                self.listenToPartnerStatus(nickname: partner)
            }
        }
        
        self.startChat(chatId: chat.chatRoomId)
    }
    
    func deleteChat(chatId: String) {
        db.collection("users").document(currentUserNick).collection("recent_chats").document(chatId).delete()
        leaveMatch()
    }
    
    func leaveGroup(chatId: String) {
        let sysMsg = ChatMessage(senderId: "SYSTEM", text: "\(currentUserNick.uppercased()) gruptan ayrıldı.", timestamp: Date())
        try? db.collection("chats").document(chatId).collection("messages").addDocument(from: sysMsg)
        
        if let lid = lobbyId {
            db.collection("lobbies").document(lid).updateData(["players": FieldValue.arrayRemove([currentUserNick])])
        }
        
        for player in lobbyPlayers {
            if player != currentUserNick {
                db.collection("users").document(player).collection("recent_chats").document(chatId).updateData([
                    "players": FieldValue.arrayRemove([currentUserNick])
                ])
            }
        }
        
        db.collection("users").document(currentUserNick).collection("recent_chats").document(chatId).delete()
        leaveMatch()
    }
    
    func startChat(chatId: String) {
        if !isHistoryChat { self.startReportTimer() }
        chatListener?.remove()
        chatListener = db.collection("chats").document(chatId).collection("messages").order(by: "timestamp", descending: false).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else { return }
            self.messages = documents.compactMap { try? $0.data(as: ChatMessage.self) }
        }
    }
    
    func sendMessage(text: String) {
        guard let chatId = currentChatId, !text.isEmpty else { return }
        let cleanText = filterMessage(text); let message = ChatMessage(senderId: currentUserNick, text: cleanText, timestamp: Date())
        
        self.messages.append(message)
        try? db.collection("chats").document(chatId).collection("messages").addDocument(from: message)
        
        if !lobbyPlayers.isEmpty {
            for player in lobbyPlayers {
                if player != currentUserNick {
                    let recentRef = db.collection("users").document(player).collection("recent_chats").document(chatId)
                    recentRef.setData([
                        "groupName": "\(lobbyTargetSize) Kişilik Ekip",
                        "chatRoomId": chatId,
                        "lastMessage": "\(currentUserNick): \(cleanText)",
                        "lastActive": Date(),
                        "unreadCount": FieldValue.increment(Int64(1)),
                        "players": lobbyPlayers
                    ], merge: true)
                }
            }
            let myRef = db.collection("users").document(currentUserNick).collection("recent_chats").document(chatId)
            myRef.setData([
                "groupName": "\(lobbyTargetSize) Kişilik Ekip",
                "chatRoomId": chatId,
                "lastMessage": "Ben: \(cleanText)",
                "lastActive": Date(),
                "players": lobbyPlayers
            ], merge: true)
        }
        HapticManager.shared.playLightImpact(); HapticManager.shared.playMessageSentSound()
    }
    
    func cancelSearch() {
        self.isSearching = false
        self.matchFound = false
        if let lid = lobbyId {
            db.collection("lobbies").document(lid).getDocument { snapshot, _ in
                if let data = snapshot?.data(), let players = data["players"] as? [String] {
                    if players.count <= 1 {
                        self.db.collection("lobbies").document(lid).delete()
                    } else {
                        self.db.collection("lobbies").document(lid).updateData(["players": FieldValue.arrayRemove([self.currentUserNick])])
                    }
                }
            }
        }
        HapticManager.shared.playLightImpact()
    }
    
    func minimizeSearch() { self.isMinimized = true }
    func maximizeSearch() { self.isMinimized = false }
    
    func leaveMatch() {
        resetLocalState()
        HapticManager.shared.playLightImpact()
    }
}

// MARK: - 6. EKRANLAR

struct WelcomeView: View {
    @ObservedObject var authViewModel: AuthViewModel; @Binding var loggedInUser: String; @Binding var loggedInAvatar: String; @Binding var loggedInScore: Double; @Binding var loggedInRatingCount: Int; @ObservedObject var gameViewModel: MatchmakingViewModel; @State private var showLogin = false; @State private var showRegister = false
    var body: some View {
        NavigationStack {
            ZStack {
                GamerBackground()
                VStack(spacing: 30) {
                    Image(systemName: "gamecontroller.fill").font(.system(size: 80)).foregroundColor(.neonBlue).shadow(color: .neonBlue, radius: 20).padding(.top, 50)
                    Text("GAME FINDER").font(.system(size: 40, weight: .heavy, design: .monospaced)).foregroundColor(.white).shadow(color: .purple, radius: 10)
                    Text("Takım arkadaşını bul,\nefsane ol.").multilineTextAlignment(.center).foregroundColor(.gray).font(.system(.body, design: .monospaced)).padding(.horizontal)
                    Spacer()
                    Button("GİRİŞ YAP") { showLogin = true }.buttonStyle(NeonButtonStyle(color: .neonBlue))
                    Button("ÜYE OL") { showRegister = true }.buttonStyle(NeonButtonStyle(color: .neonPink))
                    Text("v23.0 - Duo & Group UI").font(.caption2).foregroundColor(.gray).padding(.top)
                    Spacer()
                }.padding()
            }
            .sheet(isPresented: $showLogin) { LoginView(viewModel: authViewModel, loggedInUser: $loggedInUser, loggedInAvatar: $loggedInAvatar, loggedInScore: $loggedInScore, loggedInRatingCount: $loggedInRatingCount) }
            .sheet(isPresented: $showRegister) { RegisterView(viewModel: authViewModel, loggedInUser: $loggedInUser, loggedInAvatar: $loggedInAvatar) }
        }
    }
}

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel; @Binding var loggedInUser: String; @Binding var loggedInAvatar: String; @Binding var loggedInScore: Double; @Binding var loggedInRatingCount: Int; @Environment(\.dismiss) var dismiss; @State private var nick = ""; @State private var pass = ""
    var body: some View {
        ZStack {
            Color.deepBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("GİRİŞ YAP").font(.title).bold().foregroundColor(.white).padding(.top)
                GamerTextField(placeholder: "Kullanıcı Adı", text: $nick)
                GamerTextField(placeholder: "Şifre", text: $pass, isSecure: true)
                if !viewModel.errorMessage.isEmpty { Text(viewModel.errorMessage).foregroundColor(.red).font(.caption) }
                Button("BAĞLAN") {
                    viewModel.login(nickname: nick, password: pass) { av, sc, co in if let a = av { loggedInUser = nick; loggedInAvatar = a; loggedInScore = sc ?? 0; loggedInRatingCount = co ?? 0; dismiss() } }
                }.buttonStyle(NeonButtonStyle(color: .neonBlue)).disabled(viewModel.isLoading)
                Spacer()
            }.padding()
        }
    }
}

struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel; @Binding var loggedInUser: String; @Binding var loggedInAvatar: String; @Environment(\.dismiss) var dismiss; @State private var nick = ""; @State private var pass = ""; @State private var selectedAvatar = "person.fill"
    var body: some View {
        ZStack {
            Color.deepBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("KAYIT OL").font(.title).bold().foregroundColor(.white).padding(.top)
                Text("Avatar Seç").foregroundColor(.gray)
                ScrollView(.horizontal) { HStack { ForEach(avatarList, id: \.self) { av in Button(action: { selectedAvatar = av }) { Image(systemName: av).font(.title).padding().background(selectedAvatar == av ? Color.neonPink : Color.cardBackground).foregroundColor(.white).clipShape(Circle()) } } } }.padding()
                GamerTextField(placeholder: "Kullanıcı Adı", text: $nick)
                GamerTextField(placeholder: "Şifre", text: $pass, isSecure: true)
                if !viewModel.errorMessage.isEmpty { Text(viewModel.errorMessage).foregroundColor(.red).font(.caption) }
                Button("KAYIT OL") { viewModel.register(nickname: nick, password: pass, avatar: selectedAvatar) { success in if success { loggedInUser = nick; loggedInAvatar = selectedAvatar; dismiss() } } }.buttonStyle(NeonButtonStyle(color: .green))
                Spacer()
            }.padding()
        }
    }
}

struct AnaMenu: View {
    @ObservedObject var viewModel: MatchmakingViewModel; @ObservedObject var authViewModel: AuthViewModel; let kullaniciAdi: String; @Binding var kullaniciAvatar: String; @Binding var kullaniciPuan: Double; @Binding var kullaniciOylayanSayisi: Int; var cikisYap: () -> Void; @State private var showMessages = false; @State private var showSettings = false
    var etikDegeriText: String { if kullaniciOylayanSayisi == 0 { return "Belirsiz" } else { return String(format: "%.1f", kullaniciPuan) } }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GamerBackground()
                
                // NORMAL AKIŞ
                if !viewModel.matchFound || viewModel.isMinimized {
                    VStack(spacing: 20) {
                        HStack {
                            LiveAvatarView(userId: kullaniciAdi, size: 40, strokeColor: .neonBlue)
                            VStack(alignment: .leading) {
                                Text(kullaniciAdi.uppercased()).font(.headline).bold().foregroundColor(.white)
                                HStack(spacing: 4) { Image(systemName: "star.fill").font(.caption).foregroundColor(kullaniciOylayanSayisi == 0 ? .gray : .gold); Text(etikDegeriText).font(.caption).foregroundColor(kullaniciOylayanSayisi == 0 ? .gray : .gold) }
                            }
                            Spacer()
                            Button(action: { showMessages = true }) { ZStack { Image(systemName: "message.fill").foregroundColor(.white).padding(8).background(Color.neonPink).clipShape(Circle()); let c = viewModel.recentChats.reduce(0) { $0 + $1.safeUnreadCount }; if c > 0 { Text("\(c)").font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(4).background(Color.neonRed).clipShape(Circle()).offset(x: 10, y: -10) } } }
                            Button(action: { showSettings = true }) { Image(systemName: "gearshape.fill").foregroundColor(.white).padding(8).background(Color.gray.opacity(0.3)).clipShape(Circle()) }
                        }.padding().background(Color.cardBackground.opacity(0.9)).cornerRadius(15).padding(.horizontal)
                        
                        // MİNİ PLAYER
                        if viewModel.matchFound && viewModel.isMinimized {
                            Button(action: { viewModel.maximizeSearch() }) {
                                HStack {
                                    Circle().fill(Color.green).frame(width: 10, height: 10).shadow(color: .green, radius: 5)
                                    Text(viewModel.isLobbyFull ? "OYUN BAŞLADI! (Tıkla)" : "LOBİ ARANIYOR... (\(viewModel.lobbyPlayers.count)/\(viewModel.lobbyTargetSize))").bold().foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.up")
                                }
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green, lineWidth: 1))
                                .padding(.horizontal)
                            }
                        }
                        
                        Text("OYNAMAK İSTEDİĞİN OYUNU SEÇ").font(.caption).bold().foregroundColor(.gray).padding(.top)
                        ScrollView(showsIndicators: false) { VStack(spacing: 15) { ForEach(gameOptions) { game in NavigationLink(destination: GameDetailView(game: game, viewModel: viewModel)) { GameListItem(game: game) } } }.padding(.bottom, 20) }
                    }.padding(.top)
                        .sheet(isPresented: $showMessages) { MessagesListView(viewModel: viewModel) }
                        .sheet(isPresented: $showSettings) { ProfileSettingsView(authViewModel: authViewModel, kullaniciAdi: kullaniciAdi, kullaniciAvatar: $kullaniciAvatar, kullaniciPuan: $kullaniciPuan, kullaniciOylayanSayisi: $kullaniciOylayanSayisi, cikisYap: cikisYap) }
                }
                
                // EŞLEŞME EKRANLARI
                if viewModel.matchFound && !viewModel.isMinimized {
                    if viewModel.isLobbyFull {
                        ChatView(viewModel: viewModel)
                    } else {
                        WaitingRoomView(viewModel: viewModel)
                    }
                }
            }
        }
    }
}

struct WaitingRoomView: View {
    @ObservedObject var viewModel: MatchmakingViewModel
    var body: some View {
        ZStack {
            GamerBackground()
            VStack(spacing: 30) {
                ZStack {
                    Circle().stroke(Color.neonBlue.opacity(0.3), lineWidth: 2).frame(width: 200, height: 200)
                    Circle().stroke(Color.neonBlue.opacity(0.5), lineWidth: 2).frame(width: 150, height: 150)
                    Image(systemName: "magnifyingglass").font(.system(size: 60)).foregroundColor(.neonBlue)
                }
                Text("OYUNCULAR ARANIYOR...").font(.title2).bold().foregroundColor(.white).fontDesign(.monospaced)
                HStack(spacing: 15) {
                    ForEach(0..<viewModel.lobbyTargetSize, id: \.self) { index in
                        VStack {
                            if index < viewModel.lobbyPlayers.count {
                                LiveAvatarView(userId: viewModel.lobbyPlayers[index], size: 50, strokeColor: .green)
                                    .id(viewModel.lobbyPlayers[index])
                                Text(viewModel.lobbyPlayers[index]).font(.caption2).foregroundColor(.white).lineLimit(1)
                            } else {
                                Circle().stroke(Color.gray, lineWidth: 2).frame(width: 50, height: 50).overlay(Image(systemName: "person.fill").foregroundColor(.gray))
                                Text("Bekleniyor").font(.caption2).foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding().background(Color.cardBackground.opacity(0.5)).cornerRadius(15)
                Text("\(viewModel.lobbyPlayers.count) / \(viewModel.lobbyTargetSize) OYUNCU BULUNDU").foregroundColor(.gray)
                Spacer()
                
                HStack {
                    Button(action: { viewModel.cancelSearch() }) { Text("İPTAL ET").bold() }.buttonStyle(NeonButtonStyle(color: .red))
                    Button(action: { viewModel.minimizeSearch() }) { Text("MENÜYE DÖN (GİZLE)").bold() }.buttonStyle(NeonButtonStyle(color: .orange))
                }.padding()
            }
        }
    }
}

struct GameDetailView: View {
    let game: GameOption; @ObservedObject var viewModel: MatchmakingViewModel; @State private var selectedRank: RankOption?; @State private var selectedSize: Int = 2; @Environment(\.dismiss) var dismiss; @State private var banAlertMessage = ""; @State private var showBanAlert = false
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            GamerBackground()
            if viewModel.matchFound && !viewModel.isMinimized {
                Color.clear
            } else {
                VStack(spacing: 20) {
                    if UIImage(named: game.icon) != nil { Image(game.icon).resizable().renderingMode(.original).aspectRatio(contentMode: .fit).frame(height: 80).shadow(color: game.color, radius: 10) } else { Image(systemName: "gamecontroller.fill").font(.system(size: 60)).foregroundColor(game.color) }
                    Text(game.name.uppercased()).font(.system(.title, design: .monospaced, weight: .heavy)).foregroundColor(.white)
                    VStack(alignment: .leading) {
                        Text("EKİP BÜYÜKLÜĞÜ").font(.caption).foregroundColor(.gray)
                        Picker("Ekip", selection: $selectedSize) { ForEach(game.allowedPartySizes, id: \.self) { size in Text("\(size) Kişilik").tag(size) } }.pickerStyle(SegmentedPickerStyle()).background(Color.cardBackground).cornerRadius(8)
                    }.padding(.horizontal)
                    Divider().background(Color.gray)
                    Text("RÜTBENİ SEÇ").font(.caption).foregroundColor(.gray)
                    ScrollView { LazyVGrid(columns: columns, spacing: 15) { ForEach(game.ranks) { rank in Button(action: { selectedRank = rank; HapticManager.shared.playLightImpact() }) { RankGridItem(rank: rank, isSelected: selectedRank?.id == rank.id) } } }.padding() }
                    Spacer()
                    Button(action: {
                        if let rank = selectedRank {
                            dismiss()
                            viewModel.checkBanStatus { isBanned, message in
                                if isBanned { banAlertMessage = message ?? "Banlısın."; showBanAlert = true; HapticManager.shared.playError() }
                                else { viewModel.findLobby(game: game.name, rank: rank.name, targetSize: selectedSize) }
                            }
                        } else { HapticManager.shared.playError() }
                    }) {
                        HStack { if viewModel.isSearching { Image(systemName: "xmark.square.fill"); Text("ARANIYOR...") } else { Image(systemName: "magnifyingglass"); Text(selectedRank == nil ? "RÜTBE SEÇİN" : "LOBİ BUL (\(selectedSize) Kişilik)") } }
                    }.buttonStyle(NeonButtonStyle(color: viewModel.isSearching ? .red : (selectedRank == nil ? .gray : .neonBlue))).disabled(selectedRank == nil && !viewModel.isSearching).padding()
                }
            }
        }.alert("EŞLEŞME ENGELİ", isPresented: $showBanAlert) { Button("TAMAM", role: .cancel) {} } message: { Text(banAlertMessage) }
    }
}

struct ProfileSettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel; let kullaniciAdi: String; @Binding var kullaniciAvatar: String; @Binding var kullaniciPuan: Double; @Binding var kullaniciOylayanSayisi: Int; var cikisYap: () -> Void; @Environment(\.dismiss) var dismiss; @State private var newPassword = ""; @State private var currentPassword = ""; @State private var showDeleteAlert = false; @State private var selectedItem: PhotosPickerItem? = nil
    var etikDegeriText: String { if kullaniciOylayanSayisi == 0 { return "BELİRSİZ" } else { return String(format: "%.1f / 10", kullaniciPuan) } }
    
    var body: some View {
        ZStack {
            GamerBackground()
            VStack(spacing: 20) {
                Text("PROFİL AYARLARI").font(.title2).bold().foregroundColor(.white).padding(.top)
                LiveAvatarView(userId: kullaniciAdi, size: 80, strokeColor: .neonBlue).id(kullaniciAdi)
                VStack { Text("ETİK DEĞERİ").font(.caption2).bold().foregroundColor(.gray); HStack { Image(systemName: "star.fill").foregroundColor(kullaniciOylayanSayisi == 0 ? .gray : .gold); Text(etikDegeriText).font(.title3).bold().foregroundColor(kullaniciOylayanSayisi == 0 ? .gray : .white) } }.padding().background(Color.cardBackground.opacity(0.5)).cornerRadius(10)
                VStack {
                    Text("AVATAR DEĞİŞTİR").font(.caption).foregroundColor(.green)
                    PhotosPicker(selection: $selectedItem, matching: .images) { Label("GALERİDEN SEÇ", systemImage: "photo").font(.caption).padding(8).background(Color.neonBlue.opacity(0.2)).cornerRadius(8) }.onChange(of: selectedItem) { item in Task { if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) { if let base64 = image.toBase64() { authViewModel.updateAvatarInstant(nickname: kullaniciAdi, newAvatar: base64) } } } }
                }.padding().background(Color.cardBackground.opacity(0.5)).cornerRadius(15)
                VStack(alignment: .leading, spacing: 10) { GamerTextField(placeholder: "Yeni Şifre", text: $newPassword, isSecure: true); if !newPassword.isEmpty { GamerTextField(placeholder: "Mevcut Şifre", text: $currentPassword, isSecure: true) } }
                if !authViewModel.errorMessage.isEmpty { Text(authViewModel.errorMessage).font(.caption).foregroundColor(.red) }
                if !newPassword.isEmpty { Button("ŞİFREYİ GÜNCELLE") { authViewModel.updatePassword(nickname: kullaniciAdi, currentPassword: currentPassword, newPassword: newPassword) { s in if s { dismiss() } } }.buttonStyle(NeonButtonStyle(color: .green)) }
                Spacer(); Button("ÇIKIŞ YAP") { cikisYap() }.buttonStyle(NeonButtonStyle(color: .orange)); Button("HESABI SİL") { showDeleteAlert = true }.foregroundColor(.red).padding()
            }.padding()
        }.alert(isPresented: $showDeleteAlert) { Alert(title: Text("HESAP SİLİNECEK!"), primaryButton: .destructive(Text("SİL")) { authViewModel.deleteAccount(nickname: kullaniciAdi) { s in if s { cikisYap() } } }, secondaryButton: .cancel()) }
    }
}

struct MessagesListView: View {
    @ObservedObject var viewModel: MatchmakingViewModel; @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            Color.deepBackground.ignoresSafeArea()
            VStack {
                Text("MESAJLAR").font(.title2).bold().foregroundColor(.white).padding().padding(.top)
                if viewModel.recentChats.isEmpty { Spacer(); Text("Henüz mesaj yok").foregroundColor(.gray); Spacer() } else {
                    List(viewModel.recentChats) { chat in
                        Button { viewModel.openChatFromHistory(chat: chat); dismiss() } label: {
                            HStack { LiveAvatarView(userId: "Grup", size: 40, strokeColor: .neonBlue); VStack(alignment: .leading) { Text(chat.displayName).bold().foregroundColor(.white); Text(chat.lastMessage).font(.caption).foregroundColor(.gray) }; Spacer(); if chat.safeUnreadCount > 0 { Text("\(chat.safeUnreadCount)").font(.caption2).bold().foregroundColor(.white).padding(6).background(Color.neonRed).clipShape(Circle()) } }
                        }.listRowBackground(Color.cardBackground)
                    }.scrollContentBackground(.hidden)
                }
            }.onAppear { viewModel.fetchHistory() }
        }
    }
}

struct ChatView: View {
    @ObservedObject var viewModel: MatchmakingViewModel
    @State private var text = ""; @State private var showAlert = false; @State private var showMultiRating = false; @State private var showReportAlert = false; @State private var reportMessage = ""
    @State private var selectedUserToReport: String = ""
    @State private var showActionSheet = false
    @State private var showReportSheet = false
    
    var body: some View {
        ZStack {
            GamerBackground()
            VStack {
                // HEADER (2 KİŞİ vs ÇOK KİŞİ AYRIMI)
                HStack(spacing: 10) {
                    if viewModel.isHistoryChat {
                        Button { viewModel.leaveMatch() } label: { Image(systemName: "chevron.left").font(.title).foregroundColor(.white) }
                    } else {
                        Button { viewModel.minimizeSearch() } label: { Image(systemName: "chevron.down").font(.title).foregroundColor(.orange) }
                    }
                    
                    if viewModel.lobbyTargetSize == 2 {
                        // 2 KİŞİLİK ÖZEL TASARIM (DİREK PROFİL)
                        Spacer()
                        VStack(spacing: 2) {
                            LiveAvatarView(userId: viewModel.partnerNickForDuo, size: 50, strokeColor: viewModel.partnerIsOnline ? .green : .gray)
                                .id(viewModel.partnerNickForDuo) // Force Refresh
                            Text(viewModel.partnerNickForDuo).font(.headline).bold().foregroundColor(.white)
                            HStack {
                                Circle().fill(viewModel.partnerIsOnline ? Color.green : Color.gray).frame(width: 8, height: 8)
                                Text(viewModel.partnerIsOnline ? "Çevrimiçi" : "Çevrimdışı").font(.caption2).foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    } else {
                        // 3+ KİŞİLİK GRUP TASARIMI (KAYDIRMALI)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.lobbyPlayers, id: \.self) { player in
                                    VStack {
                                        LiveAvatarView(userId: player, size: 30, strokeColor: player == viewModel.currentUserNick ? .neonBlue : .green).id(player)
                                        Text(player).font(.caption2).foregroundColor(.white).lineLimit(1)
                                    }
                                    .onTapGesture {
                                        if player != viewModel.currentUserNick && !viewModel.isHistoryChat {
                                            selectedUserToReport = player; viewModel.reportAFK(targetUser: player) { success, msg in reportMessage = msg; showReportAlert = true }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Button { showReportSheet = true } label: { Image(systemName: "exclamationmark.bubble.fill").font(.title2).foregroundColor(.yellow) }
                    Button { showActionSheet = true } label: { Image(systemName: "ellipsis.circle.fill").font(.title).foregroundColor(.white) }
                }.padding().background(Color.cardBackground.opacity(0.9))
                
                ScrollViewReader { p in ScrollView { VStack(spacing: 15) { ForEach(viewModel.messages) { msg in
                    if msg.senderId == "SYSTEM" {
                        Text(msg.text).font(.caption).foregroundColor(.gray).frame(maxWidth: .infinity).padding(.vertical, 5)
                    } else {
                        HStack { if msg.senderId == viewModel.currentUserNick { Spacer() }; VStack(alignment: msg.senderId == viewModel.currentUserNick ? .trailing : .leading) { if msg.senderId != viewModel.currentUserNick { Text(msg.senderId).font(.caption2).foregroundColor(.gray) }; Text(msg.text).padding(10).background(msg.senderId == viewModel.currentUserNick ? Color.neonBlue.opacity(0.8) : Color.cardBackground).foregroundColor(.white).cornerRadius(12) }; if msg.senderId != viewModel.currentUserNick { Spacer() } }.id(msg.id).padding(.horizontal)
                    }
                } }.padding(.vertical) }.onChange(of: viewModel.messages.count) { _ in if let last = viewModel.messages.last?.id { withAnimation { p.scrollTo(last, anchor: .bottom) } } } }
                
                HStack { TextField("Mesaj...", text: $text).padding().background(Color.cardBackground).cornerRadius(20).foregroundColor(.white); Button { viewModel.sendMessage(text: text); text = "" } label: { Image(systemName: "paperplane.fill").font(.title2).padding().background(Color.neonBlue).clipShape(Circle()).foregroundColor(.black) } }.padding()
            }
        }
        .confirmationDialog("Seçenekler", isPresented: $showActionSheet, titleVisibility: .visible) {
            Button("Oyuncuları Puanla") { showMultiRating = true }
            Button("Gruptan Ayrıl", role: .destructive) { if let chatId = viewModel.currentChatId { viewModel.leaveGroup(chatId: chatId) } }
            Button("İptal", role: .cancel) { }
        }
        .confirmationDialog("Kimi Şikayet Etmek İstiyorsun?", isPresented: $showReportSheet, titleVisibility: .visible) {
            ForEach(viewModel.lobbyPlayers.filter { $0 != viewModel.currentUserNick }, id: \.self) { player in
                Button(player) {
                    viewModel.reportAFK(targetUser: player) { success, msg in reportMessage = msg; showReportAlert = true }
                }
            }
            Button("İptal", role: .cancel) { }
        }
        .alert("ŞİKAYET SONUCU", isPresented: $showReportAlert) { Button("TAMAM", role: .cancel) {} } message: { Text(reportMessage) }
        .alert(viewModel.ratingAlertMessage, isPresented: $viewModel.showRatingAlert) { Button("TAMAM", role: .cancel) { } }
        .sheet(isPresented: $showMultiRating) {
            MultiRatingView(players: viewModel.lobbyPlayers.filter { $0 != viewModel.currentUserNick }) { ratings in
                for (player, score) in ratings { viewModel.submitRating(for: player, rating: score) }
            }
        }
    }
}

struct MultiRatingView: View {
    let players: [String]; let onFinish: ([String: Double]) -> Void; @Environment(\.dismiss) var dismiss; @State private var ratings: [String: Double] = [:]; @State private var currentIndex = 0
    var body: some View {
        ZStack {
            Color.deepBackground.ignoresSafeArea()
            if currentIndex < players.count {
                let currentPlayer = players[currentIndex]
                VStack(spacing: 30) {
                    Text("TAKIMI PUANLA (\(currentIndex + 1)/\(players.count))").font(.headline).foregroundColor(.gray)
                    Text(currentPlayer.uppercased()).font(.largeTitle).bold().foregroundColor(.white)
                    Image(systemName: "person.fill").font(.system(size: 60)).foregroundColor(.neonBlue).padding().background(Circle().stroke(Color.neonBlue, lineWidth: 2))
                    VStack { Text("\(Int(ratings[currentPlayer] ?? 5.0))").font(.system(size: 50, weight: .bold)).foregroundColor(.gold); Slider(value: Binding(get: { ratings[currentPlayer] ?? 5.0 }, set: { ratings[currentPlayer] = $0 }), in: 1...10, step: 1).accentColor(.gold) }.padding()
                    Button("SONRAKİ") { if ratings[currentPlayer] == nil { ratings[currentPlayer] = 5.0 }; withAnimation { currentIndex += 1 } }.buttonStyle(NeonButtonStyle(color: .green))
                }.padding()
            } else { VStack { Text("TEŞEKKÜRLER!").font(.largeTitle).bold().foregroundColor(.white); Button("BİTİR") { onFinish(ratings); dismiss() }.buttonStyle(NeonButtonStyle(color: .blue)).padding() } }
        }
    }
}

// MARK: - 7. CONTENT VIEW (ANA GİRİŞ)
struct ContentView: View {
    @AppStorage("girisYapanKullanici") var girisYapanKullanici: String = ""
    @AppStorage("girisYapanAvatar") var girisYapanAvatar: String = "person.fill"
    @AppStorage("girisYapanPuan") var girisYapanPuan: Double = 0.0
    @AppStorage("girisYapanOylayanSayisi") var girisYapanOylayanSayisi: Int = 0
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var gameViewModel = MatchmakingViewModel()
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        let appearance = UINavigationBarAppearance(); appearance.configureWithOpaqueBackground(); appearance.backgroundColor = UIColor(Color.deepBackground); appearance.titleTextAttributes = [.foregroundColor: UIColor.white]; UINavigationBar.appearance().standardAppearance = appearance; UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        Group {
            if girisYapanKullanici.isEmpty {
                WelcomeView(authViewModel: authViewModel, loggedInUser: $girisYapanKullanici, loggedInAvatar: $girisYapanAvatar, loggedInScore: $girisYapanPuan, loggedInRatingCount: $girisYapanOylayanSayisi, gameViewModel: gameViewModel).preferredColorScheme(.dark)
            } else {
                AnaMenu(viewModel: gameViewModel, authViewModel: authViewModel, kullaniciAdi: girisYapanKullanici, kullaniciAvatar: $girisYapanAvatar, kullaniciPuan: $girisYapanPuan, kullaniciOylayanSayisi: $girisYapanOylayanSayisi, cikisYap: {
                    authViewModel.setUserStatus(nickname: girisYapanKullanici, isOnline: false)
                    gameViewModel.resetLocalState()
                    girisYapanKullanici = ""; girisYapanAvatar = "person.fill"; girisYapanPuan = 0.0; girisYapanOylayanSayisi = 0
                }).onAppear {
                    authViewModel.setUserStatus(nickname: girisYapanKullanici, isOnline: true)
                    gameViewModel.prepareForNewUser(nickname: girisYapanKullanici, avatar: girisYapanAvatar, score: girisYapanPuan, count: girisYapanOylayanSayisi)
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if !girisYapanKullanici.isEmpty {
                if newPhase == .active { authViewModel.setUserStatus(nickname: girisYapanKullanici, isOnline: true) }
                else if newPhase == .background { authViewModel.setUserStatus(nickname: girisYapanKullanici, isOnline: false) }
            }
        }
    }
}

#Preview { ContentView() }
