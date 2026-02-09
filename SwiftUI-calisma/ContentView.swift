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
    
    var isBase64: Bool {
        return self.count > 100
    }
}

// MARK: - 2. SES VE TİTREŞİM
@MainActor
class HapticManager {
    static let shared = HapticManager()
    
    func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func playError() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    func playLightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func playMatchSound() {
        AudioServicesPlaySystemSound(1016)
    }
    
    func playMessageSentSound() {
        AudioServicesPlaySystemSound(1004)
    }
}

// MARK: - 3. VERİ MODELLERİ
let avatarList = [
    "person.fill", "face.smiling.inverse", "ant.circle.fill",
    "flame.fill", "bolt.fill", "star.fill",
    "moon.fill", "pawprint.fill", "gamecontroller.fill"
]

struct RankOption: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
}

struct GameOption: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let ranks: [RankOption]
    
    static func == (lhs: GameOption, rhs: GameOption) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// RÜTBE LİSTELERİ
let valorantRanks = [
    RankOption(name: "Demir", color: .gray), RankOption(name: "Bronz", color: .brown),
    RankOption(name: "Gümüş", color: .white), RankOption(name: "Altın", color: .yellow),
    RankOption(name: "Platin", color: .cyan), RankOption(name: "Elmas", color: .purple),
    RankOption(name: "Yücelik", color: .green), RankOption(name: "Ölümsüzlük", color: .red),
    RankOption(name: "Radyant", color: .orange)
]

let lolRanks = [
    RankOption(name: "Demir", color: .gray), RankOption(name: "Bronz", color: .brown),
    RankOption(name: "Gümüş", color: .white), RankOption(name: "Altın", color: .yellow),
    RankOption(name: "Platin", color: .cyan), RankOption(name: "Zümrüt", color: .green),
    RankOption(name: "Elmas", color: .purple), RankOption(name: "Ustalık", color: .orange),
    RankOption(name: "Şampiyonluk", color: .red)
]

let cs2Ranks = [
    RankOption(name: "Silver", color: .gray), RankOption(name: "Gold Nova", color: .yellow),
    RankOption(name: "Master Guardian", color: .blue), RankOption(name: "Eagle", color: .cyan),
    RankOption(name: "Supreme", color: .purple), RankOption(name: "Global Elite", color: .red)
]

let fifaRanks = [
    RankOption(name: "Div 10", color: .gray), RankOption(name: "Div 8", color: .brown),
    RankOption(name: "Div 6", color: .white), RankOption(name: "Div 4", color: .yellow),
    RankOption(name: "Div 2", color: .cyan), RankOption(name: "Div 1", color: .purple),
    RankOption(name: "Elite", color: .red)
]

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

// FIREBASE MODELLERİ
struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    let nickname: String
    let password: String
    let avatar: String
    let registerDate: Date
    var reputationScore: Double?
    var ratingCount: Int?
    var totalRating: Double?
}

struct RecentChat: Identifiable, Codable {
    @DocumentID var id: String?
    let partnerNick: String
    let partnerAvatar: String
    let chatRoomId: String
    let lastMessage: String
    var unreadCount: Int?
    let lastActive: Date
    
    var safeUnreadCount: Int { return unreadCount ?? 0 }
}

struct MatchRequest: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let userAvatar: String
    let gameName: String
    let rank: String
    var status: String
    var chatRoomId: String?
    var joinedUser: String?
    var joinedUserAvatar: String?
    let timestamp: Date
    var userReputation: Double?
}

struct ChatMessage: Identifiable, Codable {
    @DocumentID var id: String?
    let senderId: String
    let text: String
    let timestamp: Date
}

// MARK: - 4. BİLEŞENLER

struct LiveAvatarView: View {
    let userId: String
    let size: CGFloat
    let strokeColor: Color
    
    @State private var currentAvatar: String = "person.fill"
    
    var body: some View {
        Group {
            if currentAvatar.isBase64, let uiImage = currentAvatar.toImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(strokeColor, lineWidth: 2))
            } else {
                Image(systemName: currentAvatar)
                    .font(.system(size: size * 0.6))
                    .foregroundColor(strokeColor)
                    .frame(width: size, height: size)
                    .background(Color.deepBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(strokeColor, lineWidth: 2))
            }
        }
        .onAppear { startListening() }
        .onChange(of: userId) { _ in startListening() }
    }
    
    func startListening() {
        if !userId.isEmpty {
            let cleanId = userId.lowercased().trimmingCharacters(in: .whitespaces)
            Firestore.firestore().collection("users").document(cleanId).addSnapshotListener { doc, _ in
                if let doc = doc, doc.exists, let data = doc.data(), let newAvatar = data["avatar"] as? String {
                    self.currentAvatar = newAvatar
                }
            }
        }
    }
}

struct NeonButtonStyle: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .monospaced))
            .padding()
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 2).shadow(color: color, radius: configuration.isPressed ? 2 : 10))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct GamerTextField: View {
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        .foregroundColor(.white)
        .font(.system(.body, design: .monospaced))
    }
}

struct GamerBackground: View {
    var body: some View {
        ZStack {
            Color.deepBackground.ignoresSafeArea()
            Circle().fill(Color.neonBlue.opacity(0.1)).frame(width: 300, height: 300).offset(x: -150, y: -300).blur(radius: 50)
            Circle().fill(Color.neonPink.opacity(0.1)).frame(width: 300, height: 300).offset(x: 150, y: 300).blur(radius: 50)
        }
    }
}

struct GameListItem: View {
    let game: GameOption
    var body: some View {
        HStack(spacing: 20) {
            if UIImage(named: game.icon) != nil {
                Image(game.icon).resizable().renderingMode(.original).aspectRatio(contentMode: .fit).frame(width: 60, height: 60).shadow(color: .black.opacity(0.5), radius: 5)
            } else {
                Image(systemName: "gamecontroller.fill").font(.system(size: 40)).foregroundColor(game.color)
            }
            Text(game.name).font(.system(.title2, design: .monospaced, weight: .bold)).foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray)
        }
        .padding()
        .background(Color.cardBackground.opacity(0.8))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(game.color.opacity(0.5), lineWidth: 1))
        .padding(.horizontal)
    }
}

struct RankGridItem: View {
    let rank: RankOption
    let isSelected: Bool
    var body: some View {
        VStack {
            Text(rank.name).font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .black : rank.color)
                .multilineTextAlignment(.center)
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(isSelected ? rank.color : Color.cardBackground)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(rank.color, lineWidth: isSelected ? 0 : 2))
    }
}

// MARK: - 5. VIEWMODELS
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage = ""
    private var db = Firestore.firestore()
    
    func register(nickname: String, password: String, avatar: String, completion: @escaping (Bool) -> Void) {
        if password.count < 8 { self.errorMessage = "Şifre en az 8 karakter olmalı!"; return }
        self.isLoading = true
        self.errorMessage = ""
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        
        db.collection("users").whereField("nickname", isEqualTo: cleanNick).getDocuments { snapshot, _ in
            DispatchQueue.main.async {
                if let docs = snapshot?.documents, !docs.isEmpty {
                    self.errorMessage = "Bu isim alınmış!"
                    self.isLoading = false
                    HapticManager.shared.playError()
                } else {
                    let newUser = UserProfile(nickname: cleanNick, password: password, avatar: avatar, registerDate: Date(), reputationScore: 0.0, ratingCount: 0, totalRating: 0.0)
                    try? self.db.collection("users").document(cleanNick).setData(from: newUser)
                    self.isLoading = false
                    completion(true)
                    HapticManager.shared.playSuccess()
                }
            }
        }
    }
    
    func login(nickname: String, password: String, completion: @escaping (String?, Double?, Int?) -> Void) {
        self.isLoading = true
        self.errorMessage = ""
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        
        db.collection("users").document(cleanNick).getDocument { document, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                if let document = document, document.exists, let data = document.data() {
                    let savedPassword = data["password"] as? String
                    let avatar = data["avatar"] as? String ?? "person.fill"
                    let score = data["reputationScore"] as? Double ?? 0.0
                    let count = data["ratingCount"] as? Int ?? 0
                    
                    if savedPassword == password {
                        completion(avatar, score, count)
                        HapticManager.shared.playSuccess()
                    } else {
                        self.errorMessage = "Şifre hatalı."
                        completion(nil, nil, nil)
                        HapticManager.shared.playError()
                    }
                } else {
                    self.errorMessage = "Kullanıcı bulunamadı."
                    completion(nil, nil, nil)
                    HapticManager.shared.playError()
                }
            }
        }
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
                DispatchQueue.main.async { self.errorMessage = "Mevcut şifre YANLIŞ!"; completion(false) }
                return
            }
            document.reference.updateData(["password": newPassword]) { err in
                DispatchQueue.main.async { completion(err == nil) }
            }
        }
    }
    
    func deleteAccount(nickname: String, completion: @escaping (Bool) -> Void) {
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        db.collection("users").document(cleanNick).delete { err in
            DispatchQueue.main.async { completion(err == nil) }
        }
    }
}

@MainActor
class MatchmakingViewModel: ObservableObject {
    @Published var isSearching = false
    @Published var matchFound = false
    @Published var currentChatId: String?
    @Published var messages: [ChatMessage] = []
    @Published var partnerName: String = "Bilinmiyor"
    @Published var partnerAvatar: String = "person.fill"
    @Published var partnerScore: Double = 0.0 // EKLENDİ: Partnerin puanı
    @Published var partnerRatingCount: Int = 0 // EKLENDİ: Kaç kişi oyladı
    @Published var recentChats: [RecentChat] = []
    
    var currentUserNick: String = ""
    var currentUserAvatar: String = "person.fill"
    var myReputationScore: Double = 0.0
    var myRatingCount: Int = 0
    
    private var currentRequestId: String?
    private var activeMatchDocId: String?
    private var db = Firestore.firestore()
    private var matchListener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    private var chatListener: ListenerRegistration?
    
    // YENİ FONKSİYON: Konuştuğum kişinin profil bilgilerini (puanını) çek
    func fetchPartnerProfile(nickname: String) {
        guard !nickname.isEmpty else { return }
        let cleanNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        
        db.collection("users").document(cleanNick).getDocument { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                self.partnerScore = data["reputationScore"] as? Double ?? 0.0
                self.partnerRatingCount = data["ratingCount"] as? Int ?? 0
            }
        }
    }
    
    func checkIfAlreadyRated(targetUser: String, completion: @escaping (Bool) -> Void) {
        let cleanTarget = targetUser.lowercased().trimmingCharacters(in: .whitespaces)
        let cleanMe = currentUserNick.lowercased().trimmingCharacters(in: .whitespaces)
        
        db.collection("users").document(cleanTarget).collection("raters").document(cleanMe).getDocument { snapshot, error in
            if let snapshot = snapshot, snapshot.exists {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    func submitRating(for targetUser: String, rating: Double) {
        let cleanTarget = targetUser.lowercased().trimmingCharacters(in: .whitespaces)
        let cleanMe = currentUserNick.lowercased().trimmingCharacters(in: .whitespaces)
        let ref = db.collection("users").document(cleanTarget)
        
        Task {
            do {
                _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
                    let userDoc: DocumentSnapshot
                    do {
                        try userDoc = transaction.getDocument(ref)
                    } catch let nsError as NSError {
                        errorPointer?.pointee = nsError
                        return nil
                    }
                    
                    let data = userDoc.data() ?? [:]
                    let oldTotal = data["totalRating"] as? Double ?? 0.0
                    let oldCount = data["ratingCount"] as? Int ?? 0
                    
                    let newTotal = oldTotal + rating
                    let newCount = oldCount + 1
                    let newScore = newTotal / Double(newCount)
                    
                    transaction.updateData([
                        "totalRating": newTotal,
                        "ratingCount": newCount,
                        "reputationScore": newScore
                    ], forDocument: ref)
                    
                    let raterRef = self.db.collection("users").document(cleanTarget).collection("raters").document(cleanMe)
                    transaction.setData(["timestamp": Date()], forDocument: raterRef)
                    
                    return nil
                })
            } catch {
                print("Rating failed: \(error)")
            }
        }
    }
    
    func prepareForNewUser(nickname: String, avatar: String, score: Double, count: Int) {
        resetLocalState()
        self.currentUserNick = nickname.lowercased().trimmingCharacters(in: .whitespaces)
        self.currentUserAvatar = avatar
        self.myReputationScore = score
        self.myRatingCount = count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.fetchHistory() }
    }
    
    func resetLocalState() {
        self.isSearching = false
        self.matchFound = false
        self.currentChatId = nil
        self.messages = []
        self.recentChats = []
        self.currentRequestId = nil
        self.activeMatchDocId = nil
        self.partnerName = "Bilinmiyor"
        self.partnerAvatar = "person.fill"
        self.partnerScore = 0.0 // Sıfırla
        self.partnerRatingCount = 0 // Sıfırla
        self.matchListener?.remove()
        self.historyListener?.remove()
        self.chatListener?.remove()
    }
    
    func findMatch(game: String, rank: String) {
        self.isSearching = true
        HapticManager.shared.playLightImpact()
        db.collection("match_requests").whereField("gameName", isEqualTo: game).whereField("rank", isEqualTo: rank).whereField("status", isEqualTo: "searching").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            if !self.isSearching { return }
            
            let candidates = snapshot?.documents.compactMap { doc -> (DocumentSnapshot, Double)? in
                let data = doc.data()
                let uid = data["userId"] as? String ?? ""
                if uid == self.currentUserNick { return nil }
                let score = data["userReputation"] as? Double ?? 0.0
                return (doc, score)
            } ?? []
            
            if !candidates.isEmpty {
                let bestMatch = self.myRatingCount == 0 ? candidates.randomElement() : candidates.min { abs($0.1 - self.myReputationScore) < abs($1.1 - self.myReputationScore) }
                if let match = bestMatch?.0 {
                    let data = match.data()
                    let otherUser = data?["userId"] as? String ?? "Oyuncu"
                    let otherAvatar = data!["userAvatar"] as? String ?? "person.fill"
                    
                    DispatchQueue.main.async {
                        self.partnerName = otherUser
                        self.partnerAvatar = otherAvatar
                        self.fetchPartnerProfile(nickname: otherUser) // PUANINI ÇEK
                        
                        self.activeMatchDocId = match.documentID
                        let persistentRoomId = self.getFixedChatRoomId(user1: self.currentUserNick, user2: otherUser)
                        self.db.collection("match_requests").document(match.documentID).updateData([
                            "status": "matched",
                            "chatRoomId": persistentRoomId,
                            "joinedUser": self.currentUserNick,
                            "joinedUserAvatar": self.currentUserAvatar
                        ])
                        self.updateHistory(partnerNick: otherUser, partnerAvatar: otherAvatar, chatId: persistentRoomId, message: "Sohbet başladı! 👋", isMeSender: true)
                        self.startChat(chatId: persistentRoomId)
                        HapticManager.shared.playSuccess()
                        HapticManager.shared.playMatchSound()
                    }
                }
            } else {
                let newRequest = MatchRequest(userId: self.currentUserNick, userAvatar: self.currentUserAvatar, gameName: game, rank: rank, status: "searching", chatRoomId: nil, joinedUser: nil, joinedUserAvatar: nil, timestamp: Date(), userReputation: self.myReputationScore)
                do {
                    let ref = try self.db.collection("match_requests").addDocument(from: newRequest)
                    DispatchQueue.main.async {
                        self.currentRequestId = ref.documentID
                        self.activeMatchDocId = ref.documentID
                        self.listenForMyMatch()
                    }
                } catch { self.isSearching = false }
            }
        }
    }
    
    func listenForMyMatch() {
        matchListener?.remove()
        matchListener = db.collection("match_requests").whereField("userId", isEqualTo: currentUserNick).whereField("status", isEqualTo: "matched").addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self, let doc = snapshot?.documents.first else { return }
            if !self.isSearching && !self.matchFound { return }
            
            if let chatId = doc.get("chatRoomId") as? String {
                if let joiner = doc.get("joinedUser") as? String {
                    DispatchQueue.main.async {
                        self.partnerName = joiner
                        self.fetchPartnerProfile(nickname: joiner) // PUANINI ÇEK
                    }
                }
                if let joinerAvatar = doc.get("joinedUserAvatar") as? String { DispatchQueue.main.async { self.partnerAvatar = joinerAvatar } }
                DispatchQueue.main.async {
                    self.activeMatchDocId = doc.documentID
                    self.updateHistory(partnerNick: self.partnerName, partnerAvatar: self.partnerAvatar, chatId: chatId, message: "Sohbet başladı! 👋", isMeSender: false)
                    self.startChat(chatId: chatId)
                    HapticManager.shared.playSuccess()
                    HapticManager.shared.playMatchSound()
                }
            }
        }
    }
    
    func updateHistory(partnerNick: String, partnerAvatar: String, chatId: String, message: String, isMeSender: Bool) {
        guard !currentUserNick.isEmpty, !partnerNick.isEmpty else { return }
        let cleanPartnerNick = partnerNick.lowercased().trimmingCharacters(in: .whitespaces)
        let timestamp = Date()
        let myData: [String: Any] = ["partnerNick": cleanPartnerNick, "partnerAvatar": partnerAvatar, "chatRoomId": chatId, "lastMessage": isMeSender ? "Ben: \(message)" : message, "lastActive": timestamp]
        var myMergeData = myData; if isMeSender { myMergeData["unreadCount"] = 0 }
        
        Task { try? await db.collection("users").document(currentUserNick).collection("recent_chats").document(cleanPartnerNick).setData(myMergeData, merge: true) }
        let partnerData: [String: Any] = ["partnerNick": currentUserNick, "partnerAvatar": currentUserAvatar, "chatRoomId": chatId, "lastMessage": isMeSender ? message : "Ben: \(message)", "lastActive": timestamp]
        let partnerRef = db.collection("users").document(cleanPartnerNick).collection("recent_chats").document(currentUserNick)
        Task { try? await partnerRef.setData(partnerData, merge: true) }
        if !message.contains("Sohbet başladı") && isMeSender { Task { try? await partnerRef.updateData(["unreadCount": FieldValue.increment(Int64(1))]) } }
    }
    
    func fetchHistory() {
        guard !currentUserNick.isEmpty else { return }
        historyListener?.remove()
        historyListener = db.collection("users").document(currentUserNick).collection("recent_chats").order(by: "lastActive", descending: true).addSnapshotListener { [weak self] snapshot, _ in
            self?.recentChats = snapshot?.documents.compactMap { try? $0.data(as: RecentChat.self) } ?? []
        }
    }
    
    func openChatFromHistory(chat: RecentChat) {
        self.partnerName = chat.partnerNick
        self.partnerAvatar = chat.partnerAvatar
        self.fetchPartnerProfile(nickname: chat.partnerNick) // GEÇMİŞTEN AÇINCA DA PUANI ÇEK
        self.activeMatchDocId = nil
        self.startChat(chatId: chat.chatRoomId)
        markChatAsRead(partnerNick: chat.partnerNick)
    }
    
    func markChatAsRead(partnerNick: String) {
        guard !currentUserNick.isEmpty, !partnerNick.isEmpty else { return }
        let cleanPartner = partnerNick.lowercased().trimmingCharacters(in: .whitespaces)
        db.collection("users").document(currentUserNick).collection("recent_chats").document(cleanPartner).setData(["unreadCount": 0], merge: true)
    }
    
    func startChat(chatId: String) {
        self.matchFound = true
        self.isSearching = false
        self.currentChatId = chatId
        self.currentRequestId = nil
        chatListener?.remove()
        chatListener = db.collection("chats").document(chatId).collection("messages").order(by: "timestamp", descending: false).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else { return }
            self.messages = documents.compactMap { try? $0.data(as: ChatMessage.self) }
        }
    }
    
    func sendMessage(text: String) {
        guard let chatId = currentChatId, !text.isEmpty else { return }
        let message = ChatMessage(senderId: currentUserNick, text: text, timestamp: Date())
        try? db.collection("chats").document(chatId).collection("messages").addDocument(from: message)
        self.updateHistory(partnerNick: partnerName, partnerAvatar: partnerAvatar, chatId: chatId, message: text, isMeSender: true)
        HapticManager.shared.playLightImpact()
        HapticManager.shared.playMessageSentSound()
    }
    
    func cancelSearch() {
        self.isSearching = false
        if let reqId = currentRequestId { db.collection("match_requests").document(reqId).delete(); self.currentRequestId = nil }
        HapticManager.shared.playLightImpact()
    }
    
    func leaveMatch() {
        if let matchDocId = activeMatchDocId { db.collection("match_requests").document(matchDocId).delete() }
        resetLocalState()
        HapticManager.shared.playLightImpact()
    }
    
    func getFixedChatRoomId(user1: String, user2: String) -> String {
        let users = [user1, user2].sorted()
        return users.joined(separator: "_")
    }
}

// MARK: - 6. EKRANLAR

struct WelcomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Binding var loggedInUser: String
    @Binding var loggedInAvatar: String
    @Binding var loggedInScore: Double
    @Binding var loggedInRatingCount: Int
    @ObservedObject var gameViewModel: MatchmakingViewModel
    @State private var showLogin = false
    @State private var showRegister = false
    
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
                    Text("v3.2 - Puan Görünür").font(.caption2).foregroundColor(.gray).padding(.top)
                    Spacer()
                }
                .padding()
            }
            .sheet(isPresented: $showLogin) { LoginView(viewModel: authViewModel, loggedInUser: $loggedInUser, loggedInAvatar: $loggedInAvatar, loggedInScore: $loggedInScore, loggedInRatingCount: $loggedInRatingCount) }
            .sheet(isPresented: $showRegister) { RegisterView(viewModel: authViewModel, loggedInUser: $loggedInUser, loggedInAvatar: $loggedInAvatar) }
        }
    }
}

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Binding var loggedInUser: String
    @Binding var loggedInAvatar: String
    @Binding var loggedInScore: Double
    @Binding var loggedInRatingCount: Int
    @Environment(\.dismiss) var dismiss
    @State private var nick = ""
    @State private var pass = ""
    
    var body: some View {
        ZStack {
            Color.deepBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("GİRİŞ YAP").font(.title).bold().foregroundColor(.white).padding(.top)
                GamerTextField(placeholder: "Kullanıcı Adı", text: $nick)
                GamerTextField(placeholder: "Şifre", text: $pass, isSecure: true)
                if !viewModel.errorMessage.isEmpty { Text(viewModel.errorMessage).foregroundColor(.red).font(.caption) }
                Button("BAĞLAN") {
                    viewModel.login(nickname: nick, password: pass) { av, sc, co in
                        if let a = av {
                            loggedInUser = nick; loggedInAvatar = a; loggedInScore = sc ?? 0; loggedInRatingCount = co ?? 0; dismiss()
                        }
                    }
                }.buttonStyle(NeonButtonStyle(color: .neonBlue)).disabled(viewModel.isLoading)
                Spacer()
            }.padding()
        }
    }
}

struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Binding var loggedInUser: String
    @Binding var loggedInAvatar: String
    @Environment(\.dismiss) var dismiss
    @State private var nick = ""
    @State private var pass = ""
    @State private var selectedAvatar = "person.fill"
    
    var body: some View {
        ZStack {
            Color.deepBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("KAYIT OL").font(.title).bold().foregroundColor(.white).padding(.top)
                Text("Avatar Seç").foregroundColor(.gray)
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(avatarList, id: \.self) { av in
                            Button(action: { selectedAvatar = av }) {
                                Image(systemName: av).font(.title).padding().background(selectedAvatar == av ? Color.neonPink : Color.cardBackground).foregroundColor(.white).clipShape(Circle())
                            }
                        }
                    }
                }.padding()
                GamerTextField(placeholder: "Kullanıcı Adı", text: $nick)
                GamerTextField(placeholder: "Şifre", text: $pass, isSecure: true)
                if !viewModel.errorMessage.isEmpty { Text(viewModel.errorMessage).foregroundColor(.red).font(.caption) }
                Button("KAYIT OL") {
                    viewModel.register(nickname: nick, password: pass, avatar: selectedAvatar) { success in
                        if success { loggedInUser = nick; loggedInAvatar = selectedAvatar; dismiss() }
                    }
                }.buttonStyle(NeonButtonStyle(color: .green))
                Spacer()
            }.padding()
        }
    }
}

struct AnaMenu: View {
    @ObservedObject var viewModel: MatchmakingViewModel
    @ObservedObject var authViewModel: AuthViewModel
    let kullaniciAdi: String
    @Binding var kullaniciAvatar: String
    @Binding var kullaniciPuan: Double
    @Binding var kullaniciOylayanSayisi: Int
    var cikisYap: () -> Void
    @State private var showMessages = false
    @State private var showSettings = false
    
    var etikDegeriText: String {
        if kullaniciOylayanSayisi == 0 { return "Belirsiz" }
        return String(format: "%.1f", kullaniciPuan)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GamerBackground()
                if viewModel.matchFound {
                    ChatView(viewModel: viewModel)
                } else {
                    VStack(spacing: 20) {
                        HStack {
                            LiveAvatarView(userId: kullaniciAdi, size: 40, strokeColor: .neonBlue)
                            VStack(alignment: .leading) {
                                Text(kullaniciAdi.uppercased()).font(.headline).bold().foregroundColor(.white)
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill").font(.caption).foregroundColor(kullaniciOylayanSayisi == 0 ? .gray : .gold)
                                    Text(etikDegeriText).font(.caption).foregroundColor(kullaniciOylayanSayisi == 0 ? .gray : .gold)
                                }
                            }
                            Spacer()
                            Button(action: { showMessages = true }) {
                                ZStack {
                                    Image(systemName: "message.fill").foregroundColor(.white).padding(8).background(Color.neonPink).clipShape(Circle())
                                    let c = viewModel.recentChats.reduce(0) { $0 + $1.safeUnreadCount }
                                    if c > 0 { Text("\(c)").font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(4).background(Color.neonRed).clipShape(Circle()).offset(x: 10, y: -10) }
                                }
                            }
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape.fill").foregroundColor(.white).padding(8).background(Color.gray.opacity(0.3)).clipShape(Circle())
                            }
                        }
                        .padding().background(Color.cardBackground.opacity(0.9)).cornerRadius(15).padding(.horizontal)
                        
                        Text("OYNAMAK İSTEDİĞİN OYUNU SEÇ").font(.caption).bold().foregroundColor(.gray).padding(.top)
                        
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 15) {
                                ForEach(gameOptions) { game in
                                    NavigationLink(destination: GameDetailView(game: game, viewModel: viewModel)) {
                                        GameListItem(game: game)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.top)
                    .sheet(isPresented: $showMessages) { MessagesListView(viewModel: viewModel) }
                    .sheet(isPresented: $showSettings) { ProfileSettingsView(authViewModel: authViewModel, kullaniciAdi: kullaniciAdi, kullaniciAvatar: $kullaniciAvatar, kullaniciPuan: $kullaniciPuan, kullaniciOylayanSayisi: $kullaniciOylayanSayisi, cikisYap: cikisYap) }
                }
            }
        }
    }
}

struct GameDetailView: View {
    let game: GameOption
    @ObservedObject var viewModel: MatchmakingViewModel
    @State private var selectedRank: RankOption?
    @Environment(\.dismiss) var dismiss
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        ZStack {
            GamerBackground()
            if viewModel.matchFound {
                ChatView(viewModel: viewModel)
            } else {
                VStack(spacing: 20) {
                    if UIImage(named: game.icon) != nil {
                        Image(game.icon).resizable().renderingMode(.original).aspectRatio(contentMode: .fit).frame(height: 80).shadow(color: game.color, radius: 10)
                    } else {
                        Image(systemName: "gamecontroller.fill").font(.system(size: 60)).foregroundColor(game.color)
                    }
                    Text(game.name.uppercased()).font(.system(.title, design: .monospaced, weight: .heavy)).foregroundColor(.white)
                    Divider().background(Color.gray)
                    Text("RÜTBENİ SEÇ").font(.caption).foregroundColor(.gray)
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(game.ranks) { rank in
                                Button(action: {
                                    selectedRank = rank; HapticManager.shared.playLightImpact()
                                }) {
                                    RankGridItem(rank: rank, isSelected: selectedRank?.id == rank.id)
                                }
                            }
                        }.padding()
                    }
                    Spacer()
                    Button(action: {
                        if let rank = selectedRank {
                            if viewModel.isSearching { viewModel.cancelSearch() } else { viewModel.findMatch(game: game.name, rank: rank.name) }
                        } else {
                            HapticManager.shared.playError()
                        }
                    }) {
                        HStack {
                            if viewModel.isSearching { Image(systemName: "xmark.square.fill"); Text("ARANIYOR...") } else { Image(systemName: "magnifyingglass"); Text(selectedRank == nil ? "RÜTBE SEÇİN" : "EŞLEŞME BAŞLAT") }
                        }
                    }.buttonStyle(NeonButtonStyle(color: viewModel.isSearching ? .red : (selectedRank == nil ? .gray : .neonBlue))).disabled(selectedRank == nil && !viewModel.isSearching).padding()
                }
            }
        }
    }
}

struct ProfileSettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    let kullaniciAdi: String
    @Binding var kullaniciAvatar: String
    @Binding var kullaniciPuan: Double
    @Binding var kullaniciOylayanSayisi: Int
    var cikisYap: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var newPassword = ""
    @State private var currentPassword = ""
    @State private var showDeleteAlert = false
    @State private var selectedItem: PhotosPickerItem? = nil
    
    var etikDegeriText: String {
        if kullaniciOylayanSayisi == 0 { return "BELİRSİZ" }
        return String(format: "%.1f / 10", kullaniciPuan)
    }
    
    var body: some View {
        ZStack {
            GamerBackground()
            VStack(spacing: 20) {
                Text("PROFİL AYARLARI").font(.title2).bold().foregroundColor(.white).padding(.top)
                LiveAvatarView(userId: kullaniciAdi, size: 80, strokeColor: .neonBlue)
                VStack {
                    Text("ETİK DEĞERİ").font(.caption2).bold().foregroundColor(.gray)
                    HStack {
                        Image(systemName: "star.fill").foregroundColor(kullaniciOylayanSayisi == 0 ? .gray : .gold)
                        Text(etikDegeriText).font(.title3).bold().foregroundColor(kullaniciOylayanSayisi == 0 ? .gray : .white)
                    }
                }.padding().background(Color.cardBackground.opacity(0.5)).cornerRadius(10)
                
                VStack {
                    Text("AVATAR DEĞİŞTİR").font(.caption).foregroundColor(.green)
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("GALERİDEN SEÇ", systemImage: "photo").font(.caption).padding(8).background(Color.neonBlue.opacity(0.2)).cornerRadius(8)
                    }
                    .onChange(of: selectedItem) { item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                                if let base64 = image.toBase64() {
                                    authViewModel.updateAvatarInstant(nickname: kullaniciAdi, newAvatar: base64)
                                }
                            }
                        }
                    }
                }.padding().background(Color.cardBackground.opacity(0.5)).cornerRadius(15)
                
                VStack(alignment: .leading, spacing: 10) {
                    GamerTextField(placeholder: "Yeni Şifre", text: $newPassword, isSecure: true)
                    if !newPassword.isEmpty { GamerTextField(placeholder: "Mevcut Şifre", text: $currentPassword, isSecure: true) }
                }
                
                if !authViewModel.errorMessage.isEmpty { Text(authViewModel.errorMessage).font(.caption).foregroundColor(.red) }
                if !newPassword.isEmpty {
                    Button("ŞİFREYİ GÜNCELLE") {
                        authViewModel.updatePassword(nickname: kullaniciAdi, currentPassword: currentPassword, newPassword: newPassword) { s in if s { dismiss() } }
                    }.buttonStyle(NeonButtonStyle(color: .green))
                }
                
                Spacer()
                Button("ÇIKIŞ YAP") { cikisYap() }.buttonStyle(NeonButtonStyle(color: .orange))
                Button("HESABI SİL") { showDeleteAlert = true }.foregroundColor(.red).padding()
            }.padding()
        }.alert(isPresented: $showDeleteAlert) {
            Alert(title: Text("HESAP SİLİNECEK!"), primaryButton: .destructive(Text("SİL")) {
                authViewModel.deleteAccount(nickname: kullaniciAdi) { s in if s { cikisYap() } }
            }, secondaryButton: .cancel())
        }
    }
}

struct MessagesListView: View {
    @ObservedObject var viewModel: MatchmakingViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.deepBackground.ignoresSafeArea()
            VStack {
                Text("MESAJLAR").font(.title2).bold().foregroundColor(.white).padding().padding(.top)
                if viewModel.recentChats.isEmpty {
                    Spacer(); Text("Henüz mesaj yok").foregroundColor(.gray); Spacer()
                } else {
                    List(viewModel.recentChats) { chat in
                        Button {
                            viewModel.openChatFromHistory(chat: chat)
                            dismiss()
                        } label: {
                            HStack {
                                LiveAvatarView(userId: chat.partnerNick, size: 40, strokeColor: .neonBlue)
                                VStack(alignment: .leading) {
                                    Text(chat.partnerNick).bold().foregroundColor(.white)
                                    Text(chat.lastMessage).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                if chat.safeUnreadCount > 0 { Text("\(chat.safeUnreadCount)").font(.caption2).bold().foregroundColor(.white).padding(6).background(Color.neonRed).clipShape(Circle()) }
                            }
                        }.listRowBackground(Color.cardBackground)
                    }.scrollContentBackground(.hidden)
                }
            }.onAppear { viewModel.fetchHistory() }
        }
    }
}

// MARK: - SOHBET EKRANI (PUAN GÖSTERGELİ)
struct ChatView: View {
    @ObservedObject var viewModel: MatchmakingViewModel
    @State private var text = ""
    @State private var showAlert = false
    @State private var showRating = false
    @State private var hasAlreadyRated = false
    @State private var alreadyRatedAlert = false
    
    // Partner puanını formatlamak için
    var partnerScoreText: String {
        if viewModel.partnerRatingCount == 0 { return "Belirsiz" }
        return String(format: "%.1f", viewModel.partnerScore)
    }
    
    var body: some View {
        ZStack {
            GamerBackground()
            VStack {
                // YENİ ÜST BAŞLIK (İSİM + PUAN)
                HStack {
                    Button {
                        // Çıkarken kontrol et: Puanladı mı?
                        viewModel.checkIfAlreadyRated(targetUser: viewModel.partnerName) { rated in
                            self.hasAlreadyRated = rated
                            if rated {
                                alreadyRatedAlert = true
                            } else {
                                showAlert = true
                            }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    // ORTA KISIM: İsim ve Puan
                    VStack(spacing: 4) {
                        HStack {
                            LiveAvatarView(userId: viewModel.partnerName, size: 30, strokeColor: .green)
                            Text(viewModel.partnerName.uppercased())
                                .font(.headline)
                                .bold()
                                .foregroundColor(.white)
                        }
                        
                        // PUAN GÖSTERGESİ
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(viewModel.partnerRatingCount == 0 ? .gray : .gold)
                            Text(partnerScoreText)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(viewModel.partnerRatingCount == 0 ? .gray : .gold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    Image(systemName: "xmark.circle.fill").font(.title).hidden()
                }.padding().background(Color.cardBackground.opacity(0.9))
                
                // MESAJLAR
                ScrollViewReader { p in
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(viewModel.messages) { msg in
                                HStack {
                                    if msg.senderId == viewModel.currentUserNick { Spacer() }
                                    VStack(alignment: msg.senderId == viewModel.currentUserNick ? .trailing : .leading) {
                                        if msg.senderId != viewModel.currentUserNick {
                                            Text(msg.senderId).font(.caption2).foregroundColor(.gray)
                                        }
                                        Text(msg.text)
                                            .padding(10)
                                            .background(msg.senderId == viewModel.currentUserNick ? Color.neonBlue.opacity(0.8) : Color.cardBackground)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }
                                    if msg.senderId != viewModel.currentUserNick { Spacer() }
                                }
                                .id(msg.id)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let last = viewModel.messages.last?.id {
                            withAnimation { p.scrollTo(last, anchor: .bottom) }
                        }
                    }
                }
                
                // MESAJ YAZMA
                HStack {
                    TextField("Mesaj...", text: $text)
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(20)
                        .foregroundColor(.white)
                    Button {
                        viewModel.sendMessage(text: text)
                        text = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .padding()
                            .background(Color.neonBlue)
                            .clipShape(Circle())
                            .foregroundColor(.black)
                    }
                }.padding()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("OYUN BİTTİ Mİ?"),
                message: Text("Oyuncuyu puanlamak ister misin?"),
                primaryButton: .default(Text("PUANLA VE ÇIK")) {
                    showRating = true
                },
                secondaryButton: .destructive(Text("DİREKT ÇIK")) {
                    viewModel.leaveMatch()
                }
            )
        }
        .alert("ZATEN OY VERDİN", isPresented: $alreadyRatedAlert) {
            Button("ÇIKIŞ YAP", role: .destructive) {
                viewModel.leaveMatch()
            }
            Button("İPTAL", role: .cancel) {}
        } message: {
            Text("Bu oyuncuyu daha önce puanladın. Direkt çıkış yapılıyor.")
        }
        .sheet(isPresented: $showRating) {
            RatingSheetView(partnerName: viewModel.partnerName) { score in
                viewModel.submitRating(for: viewModel.partnerName, rating: score)
                viewModel.leaveMatch()
            }
        }
    }
}

struct RatingSheetView: View {
    let partnerName: String
    let onSubmit: (Double) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var rating = 5.0
    
    var body: some View {
        ZStack {
            Color.deepBackground.ignoresSafeArea()
            VStack(spacing: 30) {
                Text("OYUN NASILDI?").font(.title).bold().foregroundColor(.white).padding(.top)
                Text("\(partnerName.uppercased()) oyuncusunu puanla").foregroundColor(.gray)
                
                VStack {
                    Image(systemName: "star.fill").font(.system(size: 60)).foregroundColor(.gold)
                    Text(String(format: "%.1f", rating)).font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(.white)
                }
                
                Slider(value: $rating, in: 1...10, step: 0.1).accentColor(.gold).padding(.horizontal, 40)
                
                HStack {
                    Text("Berbat (1)").font(.caption).foregroundColor(.gray)
                    Spacer()
                    Text("Efsane (10)").font(.caption).foregroundColor(.gray)
                }.padding(.horizontal, 40)
                
                Button("PUANLA VE BİTİR") {
                    HapticManager.shared.playSuccess()
                    onSubmit(rating)
                    dismiss()
                }.buttonStyle(NeonButtonStyle(color: .green)).padding(.top, 20)
            }.padding()
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
    
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.deepBackground)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        if girisYapanKullanici.isEmpty {
            WelcomeView(authViewModel: authViewModel, loggedInUser: $girisYapanKullanici, loggedInAvatar: $girisYapanAvatar, loggedInScore: $girisYapanPuan, loggedInRatingCount: $girisYapanOylayanSayisi, gameViewModel: gameViewModel).preferredColorScheme(.dark)
        } else {
            AnaMenu(viewModel: gameViewModel, authViewModel: authViewModel, kullaniciAdi: girisYapanKullanici, kullaniciAvatar: $girisYapanAvatar, kullaniciPuan: $girisYapanPuan, kullaniciOylayanSayisi: $girisYapanOylayanSayisi, cikisYap: {
                gameViewModel.resetLocalState()
                girisYapanKullanici = ""
                girisYapanAvatar = "person.fill"
                girisYapanPuan = 0.0
                girisYapanOylayanSayisi = 0
            }).onAppear {
                gameViewModel.prepareForNewUser(nickname: girisYapanKullanici, avatar: girisYapanAvatar, score: girisYapanPuan, count: girisYapanOylayanSayisi)
            }.preferredColorScheme(.dark)
        }
    }
}

#Preview {
    ContentView()
}
