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
    public var scopaGame: ScopaGame? = nil
    public var briscolaGame: BriscolaGame? = nil
    public var scalaQuarantaGame: ScalaQuarantaGame? = nil
    
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
    
    private var scopaGameURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scopa_game.json")
    }
    
    private var briscolaGameURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("briscola_game.json")
    }
    
    private var scalaQuarantaGameURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scala_quaranta_game.json")
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
        saveJSON(scopaGame, to: scopaGameURL)
        saveJSON(briscolaGame, to: briscolaGameURL)
        saveJSON(scalaQuarantaGame, to: scalaQuarantaGameURL)
    }
    
    public func loadAll() {
        players = loadJSON([Player].self, from: playersURL) ?? []
        gamesHistory = loadJSON([Game].self, from: historyURL) ?? []
        currentGame = loadJSON(Game.self, from: currentGameURL)
        biscaGame = loadJSON(BiscaGame.self, from: biscaGameURL)
        ciccopaoloGame = loadJSON(CiccopaoloGame.self, from: ciccopaoloGameURL)
        scopaGame = loadJSON(ScopaGame.self, from: scopaGameURL)
        briscolaGame = loadJSON(BriscolaGame.self, from: briscolaGameURL)
        scalaQuarantaGame = loadJSON(ScalaQuarantaGame.self, from: scalaQuarantaGameURL)
        
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
            if data.count == 4, let str = String(data: data, encoding: .utf8), str == "null" {
                return nil
            }
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
        game.gameTypeName = "Punti (Standard)"
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
    public func startBiscaGame(maxLives: Int, players: [Player]) {
        let bPlayers = players.map { BiscaPlayer(id: $0.id, name: $0.name, lives: maxLives) }
        self.biscaGame = BiscaGame(maxLives: maxLives, players: bPlayers, isActive: true)
        saveAll()
    }
    
    public func updateBiscaLives(playerId: UUID, by amount: Int) {
        guard var game = biscaGame else { return }
        if let index = game.players.firstIndex(where: { $0.id == playerId }) {
            let oldLives = game.players[index].lives
            let newLives = max(0, oldLives + amount)
            game.players[index].lives = newLives
            self.biscaGame = game
            saveAll()
            
            // Check if there is now exactly one survivor
            let survivors = game.players.filter { !$0.isEliminated }
            if survivors.count == 1 {
                saveCompletedBiscaGame()
            }
        }
    }
    
    public func donateBiscaLife(from donorId: UUID, to recipientId: UUID) {
        guard var game = biscaGame else { return }
        if let donorIndex = game.players.firstIndex(where: { $0.id == donorId }),
           let recipientIndex = game.players.firstIndex(where: { $0.id == recipientId }) {
            
            // Donor must have lives > 0 and recipient must have lives == 0
            guard game.players[donorIndex].lives > 0 else { return }
            guard game.players[recipientIndex].lives == 0 else { return }
            
            game.players[donorIndex].lives -= 1
            game.players[recipientIndex].lives += 1
            self.biscaGame = game
            saveAll()
            
            // Check if there is now exactly one survivor (in case the donor dies and nobody else remains)
            let survivors = game.players.filter { !$0.isEliminated }
            if survivors.count == 1 {
                saveCompletedBiscaGame()
            }
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
    public func startCiccopaoloGame(targetScore: Int, matchFormat: CiccopaoloMatchFormat, players: [Player]) {
        let cpPlayers = players.map { CiccopaoloPlayer(id: $0.id, name: $0.name) }
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
        denariWinnerId: UUID?,
        scopeScores: [UUID: Int],
        extraScores: [UUID: Int],
        primieraDetails: [UUID: [String: Int]]? = nil
    ) {
        guard var game = ciccopaoloGame else { return }
        
        let roundNumber = game.rounds.count + 1
        let newRound = CiccopaoloRound(
            roundNumber: roundNumber,
            primieraWinnerId: primieraWinnerId,
            settebelloWinnerId: settebelloWinnerId,
            carteWinnerId: carteWinnerId,
            denariWinnerId: denariWinnerId,
            scopeScores: scopeScores,
            extraScores: extraScores,
            primieraDetails: primieraDetails
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
        let hasPlayerReachedTarget = game.players.contains(where: { $0.currentPartitionScore >= game.targetScore })
        
        if hasPlayerReachedTarget {
            let scores = game.players.map { $0.currentPartitionScore }
            let maxScore = scores.max() ?? 0
            let winners = game.players.filter { $0.currentPartitionScore == maxScore }
            
            if winners.count == 1, let winner = winners.first, maxScore >= game.targetScore {
                if let winnerIdx = game.players.firstIndex(where: { $0.id == winner.id }) {
                    game.players[winnerIdx].gameWins += 1
                    
                    // Archive current rounds into completedGamesRounds
                    game.completedGamesRounds.append(game.rounds)
                    game.rounds = []
                    
                    // Reset partition scores for next game (if any)
                    for j in 0..<game.players.count {
                        game.players[j].currentPartitionScore = 0
                    }
                    
                    // Save to history if the match is finished!
                    let requiredWins = game.matchFormat == .bottaSecca ? 1 : 2
                    if game.players[winnerIdx].gameWins >= requiredWins {
                        saveCompletedCiccopaoloGame(game: game)
                    }
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
    
    public func updateCiccopaoloRound(updatedRound: CiccopaoloRound) {
        guard var game = ciccopaoloGame else { return }
        if let idx = game.rounds.firstIndex(where: { $0.id == updatedRound.id }) {
            game.rounds[idx] = updatedRound
            
            // Recalculate current partition scores
            for i in 0..<game.players.count {
                let pid = game.players[i].id
                game.players[i].currentPartitionScore = game.rounds.reduce(0) { $0 + $1.pointsForPlayer(id: pid) }
            }
            
            // Check if game (partita) is finished
            let hasPlayerReachedTarget = game.players.contains(where: { $0.currentPartitionScore >= game.targetScore })
            if hasPlayerReachedTarget {
                let scores = game.players.map { $0.currentPartitionScore }
                let maxScore = scores.max() ?? 0
                let winners = game.players.filter { $0.currentPartitionScore == maxScore }
                
                if winners.count == 1, let winner = winners.first, maxScore >= game.targetScore {
                    if let winnerIdx = game.players.firstIndex(where: { $0.id == winner.id }) {
                        game.players[winnerIdx].gameWins += 1
                        
                        // Archive current rounds into completedGamesRounds
                        game.completedGamesRounds.append(game.rounds)
                        game.rounds = []
                        
                        // Reset partition scores
                        for j in 0..<game.players.count {
                            game.players[j].currentPartitionScore = 0
                        }
                        
                        // Save to history if the match is finished
                        let requiredWins = game.matchFormat == .bottaSecca ? 1 : 2
                        if game.players[winnerIdx].gameWins >= requiredWins {
                            saveCompletedCiccopaoloGame(game: game)
                        }
                    }
                }
            }
            
            self.ciccopaoloGame = game
            saveAll()
        }
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
    
    // MARK: - Unified History Saving
    public func saveGameToHistory(participantIds: [UUID], rounds: [Round], gameTypeName: String) {
        let historyGame = Game(
            participantIds: participantIds,
            rounds: rounds,
            isCompleted: true,
            gameTypeName: gameTypeName
        )
        gamesHistory.insert(historyGame, at: 0)
        saveAll()
    }
    
    public func saveCompletedBiscaGame() {
        guard let game = biscaGame else { return }
        let survivors = game.players.filter { !$0.isEliminated }
        guard survivors.count == 1 else { return }
        let winnerId = survivors[0].id
        
        let participantIds = game.players.map { $0.id }
        var scores: [UUID: Int] = [:]
        for p in game.players {
            scores[p.id] = p.lives
        }
        let round = Round(roundNumber: 1, scores: scores, winnerId: winnerId, note: "Vite rimanenti")
        
        saveGameToHistory(participantIds: participantIds, rounds: [round], gameTypeName: "Bisca")
    }
    
    public func saveCompletedCiccopaoloGame(game: CiccopaoloGame) {
        let participantIds = game.players.map { $0.id }
        
        // Find overall winner based on gameWins
        let maxWins = game.players.map { $0.gameWins }.max() ?? 0
        let winners = game.players.filter { $0.gameWins == maxWins }
        let winnerId: UUID? = winners.count == 1 ? winners[0].id : nil
        
        var historyRounds: [Round] = []
        var roundCounter = 1
        
        for gameRounds in game.completedGamesRounds {
            for cpRound in gameRounds {
                var scores: [UUID: Int] = [:]
                for pId in participantIds {
                    scores[pId] = cpRound.pointsForPlayer(id: pId)
                }
                
                // Find round winner (highest score, unique)
                let maxPts = participantIds.map { cpRound.pointsForPlayer(id: $0) }.max() ?? 0
                let roundWinners = participantIds.filter { cpRound.pointsForPlayer(id: $0) == maxPts }
                let roundWinner = roundWinners.count == 1 ? roundWinners[0] : nil
                
                let hRound = Round(roundNumber: roundCounter, scores: scores, winnerId: roundWinner)
                historyRounds.append(hRound)
                roundCounter += 1
            }
        }
        
        saveGameToHistory(participantIds: participantIds, rounds: historyRounds, gameTypeName: "Ciccopaolo")
    }
    
    // MARK: - Ciccopaolo Swap Player Action
    public func swapCiccopaoloPlayers(from index1: Int, to index2: Int) {
        guard var game = ciccopaoloGame else { return }
        guard index1 >= 0 && index1 < game.players.count else { return }
        guard index2 >= 0 && index2 < game.players.count else { return }
        game.players.swapAt(index1, index2)
        self.ciccopaoloGame = game
        saveAll()
    }
    
    // MARK: - Scopa Game Actions
    public func swapScopaPlayers() {
        guard var game = scopaGame, game.players.count == 2 else { return }
        game.players.swapAt(0, 1)
        self.scopaGame = game
        saveAll()
    }
    
    public func startScopaGame(targetScore: Int, players: [Player]) {
        let scPlayers = players.map { ScopaPlayer(id: $0.id, name: $0.name) }
        self.scopaGame = ScopaGame(targetScore: targetScore, players: scPlayers, isActive: true)
        saveAll()
    }
    
    public func saveScopaRound(
        primieraWinnerId: UUID?,
        settebelloWinnerId: UUID?,
        carteWinnerId: UUID?,
        denariWinnerId: UUID?,
        scopeScores: [UUID: Int],
        napolaScores: [UUID: Int],
        primieraDetails: [UUID: [String: Int]]? = nil
    ) {
        guard var game = scopaGame else { return }
        
        let roundNumber = game.rounds.count + 1
        let newRound = ScopaRound(
            roundNumber: roundNumber,
            primieraWinnerId: primieraWinnerId,
            settebelloWinnerId: settebelloWinnerId,
            carteWinnerId: carteWinnerId,
            denariWinnerId: denariWinnerId,
            scopeScores: scopeScores,
            napolaScores: napolaScores,
            primieraDetails: primieraDetails
        )
        
        game.rounds.append(newRound)
        
        // Update player scores
        for i in 0..<game.players.count {
            let pid = game.players[i].id
            game.players[i].currentScore += newRound.pointsForPlayer(id: pid)
        }
        
        if game.isFinished {
            saveCompletedScopaGame(game: game)
        }
        
        self.scopaGame = game
        saveAll()
    }
    
    public func deleteScopaRound(at offsets: IndexSet) {
        guard var game = scopaGame else { return }
        game.rounds.remove(atOffsets: offsets)
        
        for i in 0..<game.rounds.count {
            game.rounds[i].roundNumber = i + 1
        }
        
        for i in 0..<game.players.count {
            let pid = game.players[i].id
            game.players[i].currentScore = game.rounds.reduce(0) { $0 + $1.pointsForPlayer(id: pid) }
        }
        
        self.scopaGame = game
        saveAll()
    }
    
    public func updateScopaRound(updatedRound: ScopaRound) {
        guard var game = scopaGame else { return }
        if let idx = game.rounds.firstIndex(where: { $0.id == updatedRound.id }) {
            game.rounds[idx] = updatedRound
            
            for i in 0..<game.players.count {
                let pid = game.players[i].id
                game.players[i].currentScore = game.rounds.reduce(0) { $0 + $1.pointsForPlayer(id: pid) }
            }
            
            if game.isFinished {
                saveCompletedScopaGame(game: game)
            }
            
            self.scopaGame = game
            saveAll()
        }
    }
    
    public func resetScopaGame() {
        guard var game = scopaGame else { return }
        for i in 0..<game.players.count {
            game.players[i].currentScore = 0
        }
        game.rounds = []
        self.scopaGame = game
        saveAll()
    }
    
    public func endScopaGame() {
        self.scopaGame = nil
        saveAll()
    }
    
    private func saveCompletedScopaGame(game: ScopaGame) {
        let participantIds = game.players.map { $0.id }
        guard let winner = game.winner else { return }
        
        var historyRounds: [Round] = []
        for scRound in game.rounds {
            var scores: [UUID: Int] = [:]
            for pId in participantIds {
                scores[pId] = scRound.pointsForPlayer(id: pId)
            }
            let pts0 = scRound.pointsForPlayer(id: participantIds[0])
            let pts1 = scRound.pointsForPlayer(id: participantIds[1])
            let roundWinner = pts0 == pts1 ? nil : (pts0 > pts1 ? participantIds[0] : participantIds[1])
            
            let hRound = Round(roundNumber: scRound.roundNumber, scores: scores, winnerId: roundWinner)
            historyRounds.append(hRound)
        }
        
        saveGameToHistory(participantIds: participantIds, rounds: historyRounds, gameTypeName: "Scopa")
    }
    
    // MARK: - Briscola Game Actions
    public func startBriscolaGame(targetWins: Int, players: [Player]) {
        let brPlayers = players.map { BriscolaPlayer(id: $0.id, name: $0.name) }
        self.briscolaGame = BriscolaGame(targetWins: targetWins, players: brPlayers, isActive: true)
        saveAll()
    }
    
    public func saveBriscolaRound(cardScores: [UUID: Int]) {
        guard var game = briscolaGame else { return }
        
        let roundNumber = game.rounds.count + 1
        let newRound = BriscolaRound(roundNumber: roundNumber, cardScores: cardScores)
        
        game.rounds.append(newRound)
        
        if let winnerId = newRound.winnerId {
            for i in 0..<game.players.count {
                if game.players[i].id == winnerId {
                    game.players[i].gameWins += 1
                }
            }
        }
        
        if game.isFinished {
            saveCompletedBriscolaGame(game: game)
        }
        
        self.briscolaGame = game
        saveAll()
    }
    
    public func deleteBriscolaRound(at offsets: IndexSet) {
        guard var game = briscolaGame else { return }
        game.rounds.remove(atOffsets: offsets)
        
        for i in 0..<game.rounds.count {
            game.rounds[i].roundNumber = i + 1
        }
        
        for i in 0..<game.players.count {
            game.players[i].gameWins = 0
        }
        
        for round in game.rounds {
            if let winnerId = round.winnerId {
                for i in 0..<game.players.count {
                    if game.players[i].id == winnerId {
                        game.players[i].gameWins += 1
                    }
                }
            }
        }
        
        self.briscolaGame = game
        saveAll()
    }
    
    public func resetBriscolaGame() {
        guard var game = briscolaGame else { return }
        for i in 0..<game.players.count {
            game.players[i].gameWins = 0
        }
        game.rounds = []
        self.briscolaGame = game
        saveAll()
    }
    
    public func endBriscolaGame() {
        self.briscolaGame = nil
        saveAll()
    }
    
    private func saveCompletedBriscolaGame(game: BriscolaGame) {
        let participantIds = game.players.map { $0.id }
        guard let winner = game.winner else { return }
        
        var historyRounds: [Round] = []
        for brRound in game.rounds {
            var scores: [UUID: Int] = [:]
            for pId in participantIds {
                scores[pId] = brRound.cardScores[pId] ?? 0
            }
            let hRound = Round(roundNumber: brRound.roundNumber, scores: scores, winnerId: brRound.winnerId)
            historyRounds.append(hRound)
        }
        
        saveGameToHistory(participantIds: participantIds, rounds: historyRounds, gameTypeName: "Briscola")
    }
    
    // MARK: - Scala Quaranta Game Actions
    public func startScalaQuarantaGame(targetScore: Int, players: [Player]) {
        let sqPlayers = players.map { ScalaQuarantaPlayer(id: $0.id, name: $0.name) }
        self.scalaQuarantaGame = ScalaQuarantaGame(targetScore: targetScore, players: sqPlayers, isActive: true)
        saveAll()
    }
    
    public func saveScalaQuarantaRound(scores: [UUID: Int], closingPlayerId: UUID?) {
        guard var game = scalaQuarantaGame else { return }
        
        let roundNumber = game.rounds.count + 1
        let newRound = ScalaQuarantaRound(
            roundNumber: roundNumber,
            scores: scores,
            closingPlayerId: closingPlayerId
        )
        
        game.rounds.append(newRound)
        
        // Update players' scores
        for i in 0..<game.players.count {
            let pid = game.players[i].id
            let roundScore = scores[pid] ?? 0
            
            // Only add if not already eliminated
            if !game.players[i].isEliminated {
                game.players[i].currentScore += roundScore
                if game.players[i].currentScore >= game.targetScore {
                    game.players[i].isEliminated = true
                }
            }
        }
        
        // Check if finished
        if game.isFinished {
            saveCompletedScalaQuarantaGame(game: game)
        }
        
        self.scalaQuarantaGame = game
        saveAll()
    }
    
    public func deleteScalaQuarantaRound(at offsets: IndexSet) {
        guard var game = scalaQuarantaGame else { return }
        game.rounds.remove(atOffsets: offsets)
        
        // Re-index round numbers
        for i in 0..<game.rounds.count {
            game.rounds[i].roundNumber = i + 1
        }
        
        // Recalculate scores from scratch
        for i in 0..<game.players.count {
            let pid = game.players[i].id
            var calculatedScore = 0
            for round in game.rounds {
                calculatedScore += round.scores[pid] ?? 0
            }
            game.players[i].currentScore = calculatedScore
            game.players[i].isEliminated = calculatedScore >= game.targetScore
            if calculatedScore < game.targetScore {
                game.players[i].isEliminated = false
            }
        }
        
        self.scalaQuarantaGame = game
        saveAll()
    }
    
    public func resetScalaQuarantaGame() {
        guard var game = scalaQuarantaGame else { return }
        for i in 0..<game.players.count {
            game.players[i].currentScore = 0
            game.players[i].isEliminated = false
            game.players[i].reentriesCount = 0
        }
        game.rounds = []
        self.scalaQuarantaGame = game
        saveAll()
    }
    
    public func endScalaQuarantaGame() {
        self.scalaQuarantaGame = nil
        saveAll()
    }
    
    public func reenterPlayer(playerId: UUID) {
        guard var game = scalaQuarantaGame else { return }
        // The player must be eliminated to re-enter
        guard let pIndex = game.players.firstIndex(where: { $0.id == playerId }), game.players[pIndex].isEliminated else { return }
        
        // Find highest score among currently active (not eliminated) players
        let activeScores = game.players.filter { !$0.isEliminated }.map { $0.currentScore }
        
        if let maxActiveScore = activeScores.max() {
            game.players[pIndex].currentScore = maxActiveScore
            game.players[pIndex].isEliminated = false
            game.players[pIndex].reentriesCount += 1
            self.scalaQuarantaGame = game
            saveAll()
        }
    }
    
    private func saveCompletedScalaQuarantaGame(game: ScalaQuarantaGame) {
        let participantIds = game.players.map { $0.id }
        
        var historyRounds: [Round] = []
        for sqRound in game.rounds {
            var scores: [UUID: Int] = [:]
            for pId in participantIds {
                scores[pId] = sqRound.scores[pId] ?? 0
            }
            
            let roundWinnerId = sqRound.closingPlayerId
            
            let hRound = Round(
                roundNumber: sqRound.roundNumber,
                scores: scores,
                winnerId: roundWinnerId,
                note: sqRound.closingPlayerId != nil ? "Chiusura" : nil
            )
            historyRounds.append(hRound)
        }
        
        saveGameToHistory(participantIds: participantIds, rounds: historyRounds, gameTypeName: "Scala 40")
    }
}

