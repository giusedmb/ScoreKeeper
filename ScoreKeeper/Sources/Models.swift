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
    public var mazzoWinnerId: UUID?
    
    // Extra points (scope, Napola/etc.)
    public var scopeScores: [UUID: Int] // Player.id -> count of scope
    public var extraScores: [UUID: Int] // Player.id -> count of extra points
    
    public init(
        id: UUID = UUID(),
        roundNumber: Int,
        primieraWinnerId: UUID? = nil,
        settebelloWinnerId: UUID? = nil,
        carteWinnerId: UUID? = nil,
        mazzoWinnerId: UUID? = nil,
        scopeScores: [UUID: Int] = [:],
        extraScores: [UUID: Int] = [:]
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.primieraWinnerId = primieraWinnerId
        self.settebelloWinnerId = settebelloWinnerId
        self.carteWinnerId = carteWinnerId
        self.mazzoWinnerId = mazzoWinnerId
        self.scopeScores = scopeScores
        self.extraScores = extraScores
    }
    
    public func pointsForPlayer(id: UUID) -> Int {
        var total = 0
        if primieraWinnerId == id { total += 1 }
        if settebelloWinnerId == id { total += 1 }
        if carteWinnerId == id { total += 1 }
        if mazzoWinnerId == id { total += 1 }
        total += scopeScores[id] ?? 0
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
    
    public init(
        id: UUID = UUID(),
        roundNumber: Int,
        primieraWinnerId: UUID? = nil,
        settebelloWinnerId: UUID? = nil,
        carteWinnerId: UUID? = nil,
        denariWinnerId: UUID? = nil,
        scopeScores: [UUID: Int] = [:],
        napolaScores: [UUID: Int] = [:]
    ) {
        self.id = id
        self.roundNumber = roundNumber
        self.primieraWinnerId = primieraWinnerId
        self.settebelloWinnerId = settebelloWinnerId
        self.carteWinnerId = carteWinnerId
        self.denariWinnerId = denariWinnerId
        self.scopeScores = scopeScores
        self.napolaScores = napolaScores
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

