import Foundation

public struct Player: Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct Round: Codable, Identifiable, Hashable {
    public let id: UUID
    public var roundNumber: Int
    public var scores: [UUID: Int] // Player.id -> points added in this round
    public var winnerId: UUID?     // Player.id who won this round
    public var note: String?

    public init(id: UUID = UUID(), roundNumber: Int, scores: [UUID: Int] = [:], winnerId: UUID? = nil, note: String? = nil) {
        self.id = id
        self.roundNumber = roundNumber
        self.scores = scores
        self.winnerId = winnerId
        self.note = note
    }
}

public struct Game: Codable, Identifiable, Hashable {
    public let id: UUID
    public var date: Date
    public var participantIds: [UUID] // Player.id
    public var rounds: [Round]
    public var isCompleted: Bool
    public var gameTypeName: String?

    public init(id: UUID = UUID(), date: Date = Date(), participantIds: [UUID] = [], rounds: [Round] = [], isCompleted: Bool = false, gameTypeName: String? = nil) {
        self.id = id
        self.date = date
        self.participantIds = participantIds
        self.rounds = rounds
        self.isCompleted = isCompleted
        self.gameTypeName = gameTypeName
    }

    public func totalScore(for participantId: UUID) -> Int {
        rounds.reduce(0) { $0 + ($1.scores[participantId] ?? 0) }
    }

    public func roundWins(for participantId: UUID) -> Int {
        rounds.filter { $0.winnerId == participantId }.count
    }
}

// MARK: - Bisca Game Models
public struct BiscaPlayer: Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var lives: Int
    
    public var isEliminated: Bool {
        lives <= 0
    }

    public init(id: UUID = UUID(), name: String, lives: Int) {
        self.id = id
        self.name = name
        self.lives = lives
    }
}

public struct BiscaGame: Codable, Identifiable, Hashable {
    public let id: UUID
    public var maxLives: Int
    public var players: [BiscaPlayer]
    public var isActive: Bool

    public init(id: UUID = UUID(), maxLives: Int = 5, players: [BiscaPlayer] = [], isActive: Bool = false) {
        self.id = id
        self.maxLives = maxLives
        self.players = players
        self.isActive = isActive
    }
}

// MARK: - Ciccopaolo Game Models
public enum CiccopaoloMatchFormat: String, Codable, CaseIterable {
    case bottaSecca = "Botta secca"
    case meglioDiTre = "Alla meglio di 3"
}

public struct CiccopaoloPlayer: Codable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var gameWins: Int // Games won in the overall match
    public var currentPartitionScore: Int // Points in the current game (resetting each game)
    
    public init(id: UUID = UUID(), name: String, gameWins: Int = 0, currentPartitionScore: Int = 0) {
        self.id = id
        self.name = name
        self.gameWins = gameWins
        self.currentPartitionScore = currentPartitionScore
    }
}

public struct CiccopaoloRound: Codable, Identifiable, Hashable {
    public let id: UUID
    public var roundNumber: Int
    
    // UUID of player who won the standard points, or nil
    public var primieraWinnerId: UUID?
    public var settebelloWinnerId: UUID?
    public var carteWinnerId: UUID?
    public var denariWinnerId: UUID?
    
    // Extra points (scope, Napola/etc.)
    public var scopeScores: [UUID: Int] // Player.id -> count of scope
    public var extraScores: [UUID: Int] // Player.id -> count of extra points
    public var coppiaScores: [UUID: Int] // Player.id -> count of "Coppia" declarations (each +3)
    public var menoDiNoveScores: [UUID: Int] // Player.id -> count of "Meno di 9" declarations (each +2)
    
    // Detailed card selections for primiera
    public var primieraDetails: [UUID: [String: Int]]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case roundNumber
        case primieraWinnerId
        case settebelloWinnerId
        case carteWinnerId
        case denariWinnerId
        case mazzoWinnerId // For backwards compatibility
        case scopeScores
        case extraScores
        case coppiaScores
        case menoDiNoveScores
        case primieraDetails
    }
    
    public init(
        id: UUID = UUID(),
        roundNumber: Int,
        primieraWinnerId: UUID? = nil,
        settebelloWinnerId: UUID? = nil,
        carteWinnerId: UUID? = nil,
        denariWinnerId: UUID? = nil,
        scopeScores: [UUID: Int] = [:],
        extraScores: [UUID: Int] = [:],
        coppiaScores: [UUID: Int] = [:],
        menoDiNoveScores: [UUID: Int] = [:],
        primieraDetails: [UUID: [String: Int]]? = nil
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.primieraWinnerId = primieraWinnerId
        self.settebelloWinnerId = settebelloWinnerId
        self.carteWinnerId = carteWinnerId
        self.denariWinnerId = denariWinnerId
        self.scopeScores = scopeScores
        self.extraScores = extraScores
        self.coppiaScores = coppiaScores
        self.menoDiNoveScores = menoDiNoveScores
        self.primieraDetails = primieraDetails
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        roundNumber = try container.decode(Int.self, forKey: .roundNumber)
        primieraWinnerId = try container.decodeIfPresent(UUID.self, forKey: .primieraWinnerId)
        settebelloWinnerId = try container.decodeIfPresent(UUID.self, forKey: .settebelloWinnerId)
        carteWinnerId = try container.decodeIfPresent(UUID.self, forKey: .carteWinnerId)
        
        // Decode denariWinnerId, fallback to mazzoWinnerId if present
        if let denari = try container.decodeIfPresent(UUID.self, forKey: .denariWinnerId) {
            self.denariWinnerId = denari
        } else {
            self.denariWinnerId = try container.decodeIfPresent(UUID.self, forKey: .mazzoWinnerId)
        }
        
        scopeScores = try container.decode([UUID: Int].self, forKey: .scopeScores)
        extraScores = try container.decode([UUID: Int].self, forKey: .extraScores)
        coppiaScores = (try? container.decode([UUID: Int].self, forKey: .coppiaScores)) ?? [:]
        menoDiNoveScores = (try? container.decode([UUID: Int].self, forKey: .menoDiNoveScores)) ?? [:]
        primieraDetails = try container.decodeIfPresent([UUID: [String: Int]].self, forKey: .primieraDetails)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(roundNumber, forKey: .roundNumber)
        try container.encodeIfPresent(primieraWinnerId, forKey: .primieraWinnerId)
        try container.encodeIfPresent(settebelloWinnerId, forKey: .settebelloWinnerId)
        try container.encodeIfPresent(carteWinnerId, forKey: .carteWinnerId)
        try container.encodeIfPresent(denariWinnerId, forKey: .denariWinnerId)
        try container.encode(scopeScores, forKey: .scopeScores)
        try container.encode(extraScores, forKey: .extraScores)
        try container.encode(coppiaScores, forKey: .coppiaScores)
        try container.encode(menoDiNoveScores, forKey: .menoDiNoveScores)
        try container.encodeIfPresent(primieraDetails, forKey: .primieraDetails)
    }
    
    public func pointsForPlayer(id: UUID) -> Int {
        var total = 0
        if primieraWinnerId == id { total += 1 }
        if settebelloWinnerId == id { total += 1 }
        if carteWinnerId == id { total += 1 }
        if denariWinnerId == id { total += 1 }
        total += scopeScores[id] ?? 0
        total += (coppiaScores[id] ?? 0) * 3
        total += (menoDiNoveScores[id] ?? 0) * 2
        total += extraScores[id] ?? 0
        return total
    }
}

public struct CiccopaoloGame: Codable, Identifiable, Hashable {
    public let id: UUID
    public var targetScore: Int // Max score, e.g. 21 or 31
    public var matchFormat: CiccopaoloMatchFormat
    public var players: [CiccopaoloPlayer] // Always 2 players
    public var rounds: [CiccopaoloRound] // Rounds in the current active game
    public var completedGamesRounds: [[CiccopaoloRound]] // Archived rounds of completed games in the match
    public var isActive: Bool
    
    public var isMatchFinished: Bool {
        let requiredWins = matchFormat == .bottaSecca ? 1 : 2
        return players.contains(where: { $0.gameWins >= requiredWins })
    }
    
    public var matchWinner: CiccopaoloPlayer? {
        let requiredWins = matchFormat == .bottaSecca ? 1 : 2
        return players.first(where: { $0.gameWins >= requiredWins })
    }

    public init(
        id: UUID = UUID(),
        targetScore: Int = 21,
        matchFormat: CiccopaoloMatchFormat = .bottaSecca,
        players: [CiccopaoloPlayer] = [],
        rounds: [CiccopaoloRound] = [],
        completedGamesRounds: [[CiccopaoloRound]] = [],
        isActive: Bool = false
    ) {
        self.id = id
        self.targetScore = targetScore
        self.matchFormat = matchFormat
        self.players = players
        self.rounds = rounds
        self.completedGamesRounds = completedGamesRounds
        self.isActive = isActive
    }
}

// MARK: - Scopa Game Models
public struct ScopaPlayer: Codable, Identifiable, Hashable {
    public let id: UUID // Original Player.id
    public var name: String
    public var currentScore: Int // Accumulated score
    
    public init(id: UUID, name: String, currentScore: Int = 0) {
        self.id = id
        self.name = name
        self.currentScore = currentScore
    }
}

public struct ScopaRound: Codable, Identifiable, Hashable {
    public let id: UUID
    public var roundNumber: Int
    
    // Scopa classic points
    public var primieraWinnerId: UUID?
    public var settebelloWinnerId: UUID?
    public var carteWinnerId: UUID?
    public var denariWinnerId: UUID?
    
    // Scope made by each player
    public var scopeScores: [UUID: Int] // Player.id -> count
    
    // Napoli / Napola extra points (if played)
    public var napolaScores: [UUID: Int] // Player.id -> Napola points (usually 3 to 10 points)
    
    // Detailed card selections for primiera
    public var primieraDetails: [UUID: [String: Int]]?
    
    public init(
        id: UUID = UUID(),
        roundNumber: Int,
        primieraWinnerId: UUID? = nil,
        settebelloWinnerId: UUID? = nil,
        carteWinnerId: UUID? = nil,
        denariWinnerId: UUID? = nil,
        scopeScores: [UUID: Int] = [:],
        napolaScores: [UUID: Int] = [:],
        primieraDetails: [UUID: [String: Int]]? = nil
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.primieraWinnerId = primieraWinnerId
        self.settebelloWinnerId = settebelloWinnerId
        self.carteWinnerId = carteWinnerId
        self.denariWinnerId = denariWinnerId
        self.scopeScores = scopeScores
        self.napolaScores = napolaScores
        self.primieraDetails = primieraDetails
    }
    
    public func pointsForPlayer(id: UUID) -> Int {
        var total = 0
        if primieraWinnerId == id { total += 1 }
        if settebelloWinnerId == id { total += 1 }
        if carteWinnerId == id { total += 1 }
        if denariWinnerId == id { total += 1 }
        total += scopeScores[id] ?? 0
        total += napolaScores[id] ?? 0
        return total
    }
}

public struct ScopaGame: Codable, Identifiable, Hashable {
    public let id: UUID
    public var date: Date
    public var targetScore: Int // e.g. 11 or 21
    public var players: [ScopaPlayer] // Always 2 players
    public var rounds: [ScopaRound]
    public var isActive: Bool
    
    public var isFinished: Bool {
        players.contains(where: { $0.currentScore >= targetScore })
    }
    
    public var winner: ScopaPlayer? {
        guard isFinished else { return nil }
        let s0 = players[0].currentScore
        let s1 = players[1].currentScore
        if s0 >= targetScore && s0 > s1 {
            return players[0]
        } else if s1 >= targetScore && s1 > s0 {
            return players[1]
        }
        return nil
    }
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        targetScore: Int = 11,
        players: [ScopaPlayer] = [],
        rounds: [ScopaRound] = [],
        isActive: Bool = false
    ) {
        self.id = id
        self.date = date
        self.targetScore = targetScore
        self.players = players
        self.rounds = rounds
        self.isActive = isActive
    }
}

// MARK: - Briscola Game Models
public struct BriscolaPlayer: Codable, Identifiable, Hashable {
    public let id: UUID // Original Player.id
    public var name: String
    public var gameWins: Int // "Segni" won so far
    
    public init(id: UUID, name: String, gameWins: Int = 0) {
        self.id = id
        self.name = name
        self.gameWins = gameWins
    }
}

public struct BriscolaRound: Codable, Identifiable, Hashable {
    public let id: UUID
    public var roundNumber: Int
    public var cardScores: [UUID: Int] // Player.id -> card points in this hand (0...120)
    
    public var winnerId: UUID? {
        let scores = Array(cardScores.values)
        guard scores.count == 2 else { return nil }
        let maxEntry = cardScores.max(by: { $0.value < $1.value })
        if let maxEntry = maxEntry, maxEntry.value > 60 {
            return maxEntry.key
        }
        return nil
    }
    
    public init(id: UUID = UUID(), roundNumber: Int, cardScores: [UUID: Int] = [:]) {
        self.id = id
        self.roundNumber = roundNumber
        self.cardScores = cardScores
    }
}

public struct BriscolaGame: Codable, Identifiable, Hashable {
    public let id: UUID
    public var date: Date
    public var targetWins: Int // e.g. 1, 2 (meglio di 3), 3 (meglio di 5)
    public var players: [BriscolaPlayer] // Always 2 players
    public var rounds: [BriscolaRound] // Current active set of rounds/hands
    public var isActive: Bool
    
    public var isFinished: Bool {
        players.contains(where: { $0.gameWins >= targetWins })
    }
    
    public var winner: BriscolaPlayer? {
        players.first(where: { $0.gameWins >= targetWins })
    }
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        targetWins: Int = 2,
        players: [BriscolaPlayer] = [],
        rounds: [BriscolaRound] = [],
        isActive: Bool = false
    ) {
        self.id = id
        self.date = date
        self.targetWins = targetWins
        self.players = players
        self.rounds = rounds
        self.isActive = isActive
    }
}

// MARK: - Scala Quaranta Game Models
public struct ScalaQuarantaPlayer: Codable, Identifiable, Hashable {
    public let id: UUID // Original Player.id
    public var name: String
    public var currentScore: Int // Accumulated score (wants to stay < targetScore)
    public var isEliminated: Bool // True if currentScore >= targetScore
    public var reentriesCount: Int // Number of times this player re-entered
    
    public init(id: UUID, name: String, currentScore: Int = 0, isEliminated: Bool = false, reentriesCount: Int = 0) {
        self.id = id
        self.name = name
        self.currentScore = currentScore
        self.isEliminated = isEliminated
        self.reentriesCount = reentriesCount
    }
}

public struct ScalaQuarantaRound: Codable, Identifiable, Hashable {
    public let id: UUID
    public var roundNumber: Int
    public var scores: [UUID: Int] // Player.id -> round score
    public var closingPlayerId: UUID? // Player.id who closed (gets 0 points)
    
    public init(
        id: UUID = UUID(),
        roundNumber: Int,
        scores: [UUID: Int] = [:],
        closingPlayerId: UUID? = nil
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.scores = scores
        self.closingPlayerId = closingPlayerId
    }
}

public struct ScalaQuarantaGame: Codable, Identifiable, Hashable {
    public let id: UUID
    public var date: Date
    public var targetScore: Int // Usually 101, 151, 201, 301, 501
    public var players: [ScalaQuarantaPlayer]
    public var rounds: [ScalaQuarantaRound]
    public var isActive: Bool
    
    public var activePlayersCount: Int {
        players.filter { !$0.isEliminated }.count
    }
    
    public var isFinished: Bool {
        // Scala Quaranta ends when only 1 active player remains, or if all players are eliminated
        activePlayersCount <= 1
    }
    
    public var winner: ScalaQuarantaPlayer? {
        guard isFinished else { return nil }
        // The winner is the last remaining active player (or the one with the lowest score if all are eliminated)
        if let lastActive = players.first(where: { !$0.isEliminated }) {
            return lastActive
        }
        return players.min(by: { $0.currentScore < $1.currentScore })
    }
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        targetScore: Int = 101,
        players: [ScalaQuarantaPlayer] = [],
        rounds: [ScalaQuarantaRound] = [],
        isActive: Bool = false
    ) {
        self.id = id
        self.date = date
        self.targetScore = targetScore
        self.players = players
        self.rounds = rounds
        self.isActive = isActive
    }
}


