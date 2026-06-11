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

    public init(id: UUID = UUID(), date: Date = Date(), participantIds: [UUID] = [], rounds: [Round] = [], isCompleted: Bool = false) {
        self.id = id
        self.date = date
        self.participantIds = participantIds
        self.rounds = rounds
        self.isCompleted = isCompleted
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

