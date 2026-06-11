import Foundation
import Observation
import Combine

@Observable
public class GameStore {
    // Persistent state
    public var players: [Player] = []
    public var gamesHistory: [Game] = []
    public var currentGame: Game?
    public var biscaGame: BiscaGame? = nil
    public var ciccopaoloGame: CiccopaoloGame? = nil
    
    // UI temporary state for the active/current round
    public var activeRoundScores: [UUID: Int] = [:]
    public var activeRoundWinnerId: UUID? = nil
    
    // File URLs
    private var playersURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("players.json")
    }
    
    private var historyURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("history.json")
    }
    
    private var currentGameURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("current_game.json")
    }
    
    private var biscaGameURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bisca_game.json")
    }
    
    private var ciccopaoloGameURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ciccopaolo_game.json")
    }
    
    public init() {
        loadAll()
    }
    
    // MARK: - Persistence Functions
    public func saveAll() {
        saveJSON(players, to: playersURL)
        saveJSON(gamesHistory, to: historyURL)
        saveJSON(currentGame, to: currentGameURL)
        saveJSON(biscaGame, to: biscaGameURL)
        saveJSON(ciccopaoloGame, to: ciccopaoloGameURL)
    }
    
    public func loadAll() {
        players = loadJSON([Player].self, from: playersURL) ?? []
        gamesHistory = loadJSON([Game].self, from: historyURL) ?? []
        currentGame = loadJSON(Game.self, from: currentGameURL)
        biscaGame = loadJSON(BiscaGame.self, from: biscaGameURL)
        ciccopaoloGame = loadJSON(CiccopaoloGame.self, from: ciccopaoloGameURL)
        
        resetActiveRoundState()
    }
    
    private func saveJSON<T: Encodable>(_ data: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(data)
            try encoded.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            print("Error saving to \(url.lastPathComponent): \(error)")
        }
    }
    
    private func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            print("Error loading from \(url.lastPathComponent): \(error)")
            return nil
        }
    }
    
    // MARK: - Player Actions
    @discardableResult
    public func addPlayer(name: String) -> Player {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return Player(name: "Giocatore") }
        
        if let existing = players.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            return existing
        }
        
        let newPlayer = Player(name: trimmedName)
        players.append(newPlayer)
        saveAll()
        return newPlayer
    }
    
    public func deletePlayer(at offsets: IndexSet) {
        players.remove(atOffsets: offsets)
        saveAll()
    }
    
    // MARK: - Game Management
    public func startNewGame(participantIds: [UUID]) {
        let newGame = Game(participantIds: participantIds, rounds: [], isCompleted: false)
        self.currentGame = newGame
        resetActiveRoundState()
        saveAll()
    }
    
    public func endCurrentGame() {
        guard var game = currentGame else { return }
        game.isCompleted = true
        gamesHistory.insert(game, at: 0)
        currentGame = nil
        saveAll()
    }
    
    public func cancelCurrentGame() {
        currentGame = nil
        saveAll()
    }
    
    public func resetScores() {
        guard var game = currentGame else { return }
        game.rounds = []
        currentGame = game
        resetActiveRoundState()
        saveAll()
    }
    
    // MARK: - Round Actions
    public func resetActiveRoundState() {
        activeRoundScores = [:]
        activeRoundWinnerId = nil
        
        guard let game = currentGame else { return }
        for id in game.participantIds {
            activeRoundScores[id] = 0
        }
    }
    
    public func updateActiveScore(for participantId: UUID, by value: Int) {
        let current = activeRoundScores[participantId] ?? 0
        activeRoundScores[participantId] = current + value
    }
    
    public func setWinnerForActiveRound(_ winnerId: UUID?) {
        if activeRoundWinnerId == winnerId {
            activeRoundWinnerId = nil
        } else {
            activeRoundWinnerId = winnerId
        }
    }
    
    public func saveActiveRound(note: String? = nil) {
        guard var game = currentGame else { return }
        
        let roundNumber = game.rounds.count + 1
        let newRound = Round(
            roundNumber: roundNumber,
            scores: activeRoundScores,
            winnerId: activeRoundWinnerId,
            note: note
        )
        
        game.rounds.append(newRound)
        currentGame = game
        resetActiveRoundState()
        saveAll()
    }
    
    public func deleteRound(at offsets: IndexSet) {
        guard var game = currentGame else { return }
        game.rounds.remove(atOffsets: offsets)
        
        for i in 0..<game.rounds.count {
            game.rounds[i].roundNumber = i + 1
        }
        currentGame = game
        saveAll()
    }
    
    // MARK: - Bisca Game Actions
    public func startBiscaGame(maxLives: Int, playerNames: [String]) {
        let bPlayers = playerNames.map { BiscaPlayer(name: $0, lives: maxLives) }
        self.biscaGame = BiscaGame(maxLives: maxLives, players: bPlayers, isActive: true)
        saveAll()
    }
    
    public func updateBiscaLives(playerId: UUID, by amount: Int) {
        guard var game = biscaGame else { return }
        if let index = game.players.firstIndex(where: { $0.id == playerId }) {
            let oldLives = game.players[index].lives
            // Allow going up without limits, and down to 0
            let newLives = max(0, oldLives + amount)
            game.players[index].lives = newLives
            self.biscaGame = game
            saveAll()
        }
    }
    
    public func endBiscaGame() {
        self.biscaGame = nil
        saveAll()
    }
    
    public func resetBiscaGame() {
        guard var game = biscaGame else { return }
        for i in 0..<game.players.count {
            game.players[i].lives = game.maxLives
        }
        self.biscaGame = game
        saveAll()
    }
    
    // MARK: - Ciccopaolo Game Actions
    public func startCiccopaoloGame(targetScore: Int, matchFormat: CiccopaoloMatchFormat, playerNames: [String]) {
        let cpPlayers = playerNames.map { CiccopaoloPlayer(name: $0) }
        self.ciccopaoloGame = CiccopaoloGame(
            targetScore: targetScore,
            matchFormat: matchFormat,
            players: cpPlayers,
            isActive: true
        )
        saveAll()
    }
    
    public func saveCiccopaoloRound(
        primieraWinnerId: UUID?,
        settebelloWinnerId: UUID?,
        carteWinnerId: UUID?,
        mazzoWinnerId: UUID?,
        scopeScores: [UUID: Int],
        extraScores: [UUID: Int]
    ) {
        guard var game = ciccopaoloGame else { return }
        
        let roundNumber = game.rounds.count + 1
        let newRound = CiccopaoloRound(
            roundNumber: roundNumber,
            primieraWinnerId: primieraWinnerId,
            settebelloWinnerId: settebelloWinnerId,
            carteWinnerId: carteWinnerId,
            mazzoWinnerId: mazzoWinnerId,
            scopeScores: scopeScores,
            extraScores: extraScores
        )
        
        // Add round to rounds array
        game.rounds.append(newRound)
        
        // Update players currentPartitionScore
        for i in 0..<game.players.count {
            let pid = game.players[i].id
            let pts = newRound.pointsForPlayer(id: pid)
            game.players[i].currentPartitionScore += pts
        }
        
        // Check if game (partita) is finished
        // We only check at the end of the round!
        let hasPlayerReachedTarget = game.players.contains(where: { $0.currentPartitionScore >= game.targetScore })
        
        if hasPlayerReachedTarget {
            // Find who won the game (partita)
            // It's the one with the higher score.
            // If there's a tie (e.g. both are >= targetScore and they are equal), we play another round (do not declare game win yet).
            let score0 = game.players[0].currentPartitionScore
            let score1 = game.players[1].currentPartitionScore
            
            if score0 != score1 {
                let winnerIdx = score0 > score1 ? 0 : 1
                game.players[winnerIdx].gameWins += 1
                
                // Archive current rounds into completedGamesRounds
                game.completedGamesRounds.append(game.rounds)
                game.rounds = []
                
                // Reset partition scores for next game (if any)
                for j in 0..<game.players.count {
                    game.players[j].currentPartitionScore = 0
                }
            }
        }
        
        self.ciccopaoloGame = game
        saveAll()
    }
    
    public func deleteCiccopaoloRound(at offsets: IndexSet) {
        guard var game = ciccopaoloGame else { return }
        game.rounds.remove(atOffsets: offsets)
        
        // Re-index round numbers
        for i in 0..<game.rounds.count {
            game.rounds[i].roundNumber = i + 1
        }
        
        // Recalculate current partition scores
        for i in 0..<game.players.count {
            let pid = game.players[i].id
            game.players[i].currentPartitionScore = game.rounds.reduce(0) { $0 + $1.pointsForPlayer(id: pid) }
        }
        
        self.ciccopaoloGame = game
        saveAll()
    }
    
    public func resetCiccopaoloGame() {
        guard var game = ciccopaoloGame else { return }
        for i in 0..<game.players.count {
            game.players[i].gameWins = 0
            game.players[i].currentPartitionScore = 0
        }
        game.rounds = []
        game.completedGamesRounds = []
        self.ciccopaoloGame = game
        saveAll()
    }
    
    public func endCiccopaoloGame() {
        self.ciccopaoloGame = nil
        saveAll()
    }
}

