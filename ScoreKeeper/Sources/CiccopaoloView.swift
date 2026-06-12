import SwiftUI

enum CiccopaoloCelebrationState: Equatable {
    case none
    case gameWon(winnerName: String, scores: [(name: String, score: Int)], wins: [(name: String, wins: Int)], isMatchFinished: Bool)
    
    static func == (lhs: CiccopaoloCelebrationState, rhs: CiccopaoloCelebrationState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.gameWon(let name1, _, _, let finished1), .gameWon(let name2, _, _, let finished2)):
            return name1 == name2 && finished1 == finished2
        default:
            return false
        }
    }
}

struct CiccopaoloView: View {
    @Environment(GameStore.self) private var store
    
    // Setup state
    @State private var selectedPlayerIds = Set<UUID>()
    @State private var targetScore = 21
    @State private var matchFormat: CiccopaoloMatchFormat = .bottaSecca
    @State private var quickPlayerName = ""
    
    // Gameplay state
    @State private var showingAddRoundSheet = false
    @State private var showingResetAlert = false
    @State private var showingExitAlert = false
    @State private var activeCelebration: CiccopaoloCelebrationState = .none
    
    var body: some View {
        ZStack {
            Group {
                if let game = store.ciccopaoloGame, game.isActive {
                    activeGameView(game)
                } else {
                    setupGameView
                }
            }
            .blur(radius: activeCelebration != .none ? 8 : 0)
            
            // Celebration overlay
            if case .gameWon(let winnerName, let scores, let wins, let isMatchFinished) = activeCelebration {
                CiccopaoloCelebrationOverlay(
                    winnerName: winnerName,
                    scores: scores,
                    wins: wins,
                    isMatchFinished: isMatchFinished
                ) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        activeCelebration = .none
                    }
                    if isMatchFinished {
                        store.endCiccopaoloGame()
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Ciccopaolo")
        .sheet(isPresented: $showingAddRoundSheet) {
            if let game = store.ciccopaoloGame {
                CiccopaoloAddRoundSheet(game: game) { primiera, settebello, carte, denari, scope, extra in
                    // Call save round
                    store.saveCiccopaoloRound(
                        primieraWinnerId: primiera,
                        settebelloWinnerId: settebello,
                        carteWinnerId: carte,
                        denariWinnerId: denari,
                        scopeScores: scope,
                        extraScores: extra
                    )
                    
                    // Immediately check if game/match was won, to show celebration
                    if let updatedGame = store.ciccopaoloGame {
                        // Check if a player reached required wins
                        let requiredWins = updatedGame.matchFormat == .bottaSecca ? 1 : 2
                        if let matchWinner = updatedGame.matchWinner {
                            // Match finished!
                            let pWins = updatedGame.players.map { ($0.name, $0.gameWins) }
                            
                            // To show final game scores, we need the scores of the last completed game.
                            // We can fetch from completedGamesRounds last element
                            var finalScores: [(name: String, score: Int)] = []
                            if let lastRounds = updatedGame.completedGamesRounds.last {
                                for player in updatedGame.players {
                                    let score = lastRounds.reduce(0) { $0 + $1.pointsForPlayer(id: player.id) }
                                    finalScores.append((player.name, score))
                                }
                            } else {
                                finalScores = updatedGame.players.map { ($0.name, 0) }
                            }
                            
                            activeCelebration = .gameWon(
                                winnerName: matchWinner.name,
                                scores: finalScores,
                                wins: pWins,
                                isMatchFinished: true
                            )
                            triggerGameWinHaptics()
                        } else {
                            // Check if a partition/game just finished (it resets players' current scores to 0, and increments gameWins).
                            // So if a gameWin occurred, but no matchWinner yet (meaning in best-of-3, one is at 1 win, other is at 0 or 1),
                            // we show game won celebration, but with isMatchFinished: false.
                            // We detect this if a game was just archived in completedGamesRounds and rounds count is 0.
                            if updatedGame.rounds.isEmpty, let lastRounds = updatedGame.completedGamesRounds.last {
                                // Find who won this game by calculating points from lastRounds
                                let player0 = updatedGame.players[0]
                                let player1 = updatedGame.players[1]
                                let pts0 = lastRounds.reduce(0) { $0 + $1.pointsForPlayer(id: player0.id) }
                                let pts1 = lastRounds.reduce(0) { $0 + $1.pointsForPlayer(id: player1.id) }
                                
                                let gameWinnerName = pts0 > pts1 ? player0.name : player1.name
                                let finalScores = [(player0.name, pts0), (player1.name, pts1)]
                                let pWins = updatedGame.players.map { ($0.name, $0.gameWins) }
                                
                                activeCelebration = .gameWon(
                                    winnerName: gameWinnerName,
                                    scores: finalScores,
                                    wins: pWins,
                                    isMatchFinished: false
                                )
                                triggerRoundWinHaptics()
                            }
                        }
                    }
                }
            }
        }
        .alert("Azzera Partita?", isPresented: $showingResetAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Azzera", role: .destructive) {
                triggerHaptic(.notification(.warning))
                store.resetCiccopaoloGame()
            }
        } message: {
            Text("Sei sicuro di voler azzerare il punteggio e i round della partita corrente?")
        }
        .alert("Termina Partita?", isPresented: $showingExitAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Esci", role: .destructive) {
                triggerHaptic(.notification(.error))
                store.endCiccopaoloGame()
            }
        } message: {
            Text("Sei sicuro di voler terminare il match Ciccopaolo corrente? I dati andranno persi.")
        }
    }
    
    // MARK: - Setup View
    private var setupGameView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Punteggio di arrivo (Partita):")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach([21, 31], id: \.self) { val in
                            Button(action: {
                                triggerHaptic(.impact(.light))
                                targetScore = val
                            }) {
                                Text("\(val)")
                                    .font(.title3.bold())
                                    .foregroundColor(targetScore == val ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(targetScore == val ? Color.appAccent : Color.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(targetScore == val ? Color.appAccent : Color.cardStroke, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Stepper(value: $targetScore, in: 5...99) {
                        HStack {
                            Text("Personalizzato:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(targetScore)")
                                .font(.body.bold())
                                .foregroundColor(.appAccent)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Impostazioni Punteggio")
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                Picker("Formato Match", selection: $matchFormat) {
                    ForEach(CiccopaoloMatchFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            } header: {
                Text("Formato Match")
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                HStack {
                    TextField("Nome Giocatore Rapido", text: $quickPlayerName)
                        .textInputAutocapitalization(.words)
                        .foregroundColor(.primary)
                    
                    Button("Aggiungi") {
                        if !quickPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let newPlayer = store.addPlayer(name: quickPlayerName)
                            if selectedPlayerIds.count < 2 {
                                selectedPlayerIds.insert(newPlayer.id)
                            }
                            quickPlayerName = ""
                            triggerHaptic(.notification(.success))
                        }
                    }
                    .foregroundColor(.appAccent)
                    .disabled(quickPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("Aggiungi Giocatore")
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                if store.players.isEmpty {
                    Text("Nessun giocatore salvato. Aggiungine uno sopra per iniziare.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .padding(.vertical, 8)
                } else {
                    ForEach(store.players) { player in
                        let isSelected = selectedPlayerIds.contains(player.id)
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(isSelected ? .appAccent : .secondary)
                            Text(player.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appAccent)
                                    .fontWeight(.bold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            triggerHaptic(.impact(.light))
                            if isSelected {
                                selectedPlayerIds.remove(player.id)
                            } else {
                                if selectedPlayerIds.count < 2 {
                                    selectedPlayerIds.insert(player.id)
                                } else {
                                    // Replace one if we already have 2 selected
                                    if let first = selectedPlayerIds.first {
                                        selectedPlayerIds.remove(first)
                                    }
                                    selectedPlayerIds.insert(player.id)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Seleziona Partecipanti (Esattamente 2)")
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                Button(action: {
                    let selected = store.players.filter { selectedPlayerIds.contains($0.id) }
                    store.startCiccopaoloGame(targetScore: targetScore, matchFormat: matchFormat, players: selected)
                    triggerHaptic(.notification(.success))
                }) {
                    Text("Inizia Ciccopaolo")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .disabled(selectedPlayerIds.count != 2)
                .listRowBackground(selectedPlayerIds.count == 2 ? Color.appAccent : Color.cardBackground.opacity(0.5))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }
    
    // MARK: - Active Game View
    private func activeGameView(_ game: CiccopaoloGame) -> some View {
        VStack(spacing: 0) {
            // Stats Header
            HStack {
                Text(game.matchFormat.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
                
                Spacer()
                
                Text("Partita a: \(game.targetScore) pt")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Score Board Card
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    // Player 1
                    VStack(spacing: 6) {
                        Text(game.players[0].name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("\(game.players[0].currentPartitionScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text("Partite Vinte:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(game.players[0].gameWins) 🏆")
                                .font(.caption.bold())
                                .foregroundColor(.trophyGold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.cardStroke)
                        .frame(width: 1)
                        .padding(.vertical, 10)
                    
                    // Player 2
                    VStack(spacing: 6) {
                        Text(game.players[1].name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("\(game.players[1].currentPartitionScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text("Partite Vinte:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(game.players[1].gameWins) 🏆")
                                .font(.caption.bold())
                                .foregroundColor(.trophyGold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 16)
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardStroke, lineWidth: 1))
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            // Rounds History list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if game.rounds.isEmpty {
                        VStack(spacing: 16) {
                            Spacer(minLength: 40)
                            Image(systemName: "suit.club")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("Nessun round registrato per questa partita.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Text("Fai la smazzata e inserisci i punti qui sotto.")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        Text("Storico Smazzate")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 10) {
                            ForEach(game.rounds.reversed()) { round in
                                CiccopaoloRoundHistoryRow(round: round, game: game) {
                                    if let idx = game.rounds.firstIndex(where: { $0.id == round.id }) {
                                        store.deleteCiccopaoloRound(at: IndexSet(integer: idx))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Bottom Action Bar
            VStack(spacing: 16) {
                Button(action: {
                    triggerHaptic(.impact(.medium))
                    showingAddRoundSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Nuova Smazzata (Inserisci Punti)")
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.appAccent)
                    .cornerRadius(14)
                }
                
                HStack(spacing: 16) {
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Azzera")
                        }
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        showingExitAlert = true
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Termina")
                        }
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .background(Color.scoreNegative)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color.appBackground.opacity(0.85))
        }
    }
}

// MARK: - Round History Row component
struct CiccopaoloRoundHistoryRow: View {
    let round: CiccopaoloRound
    let game: CiccopaoloGame
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Smazzata \(round.roundNumber)")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Show breakdown of the round
                HStack(spacing: 8) {
                    ForEach(game.players) { player in
                        let pts = round.pointsForPlayer(id: player.id)
                        Text("\(player.name): +\(pts)")
                            .font(.caption.bold())
                            .foregroundColor(pts > 0 ? .scorePositive : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Show icons of what was won in this round
            HStack(spacing: 6) {
                pointBadge(label: "Primiera", winnerId: round.primieraWinnerId)
                pointBadge(label: "Settebello", winnerId: round.settebelloWinnerId)
                pointBadge(label: "Carte", winnerId: round.carteWinnerId)
                pointBadge(label: "Denari", winnerId: round.denariWinnerId)
            }
            
            // Show scope and extra points if any
            let p0 = game.players[0]
            let p1 = game.players[1]
            let sc0 = round.scopeScores[p0.id] ?? 0
            let sc1 = round.scopeScores[p1.id] ?? 0
            let ex0 = round.extraScores[p0.id] ?? 0
            let ex1 = round.extraScores[p1.id] ?? 0
            
            if sc0 > 0 || sc1 > 0 || ex0 > 0 || ex1 > 0 {
                HStack(spacing: 12) {
                    if sc0 > 0 || sc1 > 0 {
                        Text("Scope: \(p0.name) (\(sc0)) - \(p1.name) (\(sc1))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if ex0 > 0 || ex1 > 0 {
                        Text("Extra: \(p0.name) (+\(ex0)) - \(p1.name) (+\(ex1))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardStroke, lineWidth: 1))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                triggerHaptic(.notification(.warning))
                withAnimation {
                    onDelete()
                }
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }
    
    private func pointBadge(label: String, winnerId: UUID?) -> some View {
        let playerName = game.players.first(where: { $0.id == winnerId })?.name ?? "-"
        return HStack(spacing: 3) {
            Text(label[label.startIndex..<label.index(label.startIndex, offsetBy: min(3, label.count))].uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
            Text(playerName)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(winnerId != nil ? .appAccent : .secondary.opacity(0.5))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(winnerId != nil ? Color.appAccent.opacity(0.1) : Color.white.opacity(0.02))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(winnerId != nil ? Color.appAccent.opacity(0.25) : Color.cardStroke, lineWidth: 1))
    }
}

// MARK: - Interactive Add Round Sheet
struct CiccopaoloAddRoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    let game: CiccopaoloGame
    let onSave: (UUID?, UUID?, UUID?, UUID?, [UUID: Int], [UUID: Int]) -> Void
    
    // Selections
    @State private var primieraWinnerId: UUID? = nil
    @State private var settebelloWinnerId: UUID? = nil
    @State private var carteWinnerId: UUID? = nil
    @State private var denariWinnerId: UUID? = nil
    
    // Scope and Extra
    @State private var scopeScores: [UUID: Int] = [:]
    @State private var extraScores: [UUID: Int] = [:]
    
    @State private var showingPrimieraCalculator = false
    
    init(game: CiccopaoloGame, onSave: @escaping (UUID?, UUID?, UUID?, UUID?, [UUID: Int], [UUID: Int]) -> Void) {
        self.game = game
        self.onSave = onSave
        
        // Initialize dictionaries
        var tempScopes: [UUID: Int] = [:]
        var tempExtras: [UUID: Int] = [:]
        for p in game.players {
            tempScopes[p.id] = 0
            tempExtras[p.id] = 0
        }
        _scopeScores = State(initialValue: tempScopes)
        _extraScores = State(initialValue: tempExtras)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Standard Points Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Punti Classici Scopa (1 pt ciascuno)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .tracking(1)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            pointSelectorRow(title: "Primiera", selection: $primieraWinnerId) {
                                showingPrimieraCalculator = true
                            }
                            pointSelectorRow(title: "Settebello", selection: $settebelloWinnerId)
                            pointSelectorRow(title: "Carte", selection: $carteWinnerId)
                            pointSelectorRow(title: "Denari", selection: $denariWinnerId)
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardStroke, lineWidth: 1))
                        .padding(.horizontal)
                    }
                    
                    // Scope Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scope fatte (1 pt ciascuna)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .tracking(1)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(game.players) { player in
                                HStack {
                                    Text(player.name)
                                        .font(.body.bold())
                                        .foregroundColor(.primary)
                                    Spacer()
                                    
                                    HStack(spacing: 14) {
                                        Button(action: {
                                            triggerHaptic(.impact(.light))
                                            let current = scopeScores[player.id] ?? 0
                                            scopeScores[player.id] = max(0, current - 1)
                                        }) {
                                            Image(systemName: "minus")
                                                .font(.caption.bold())
                                                .foregroundColor(.scoreNegative)
                                                .frame(width: 36, height: 36)
                                                .background(Color.scoreNegative.opacity(0.12))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text("\(scopeScores[player.id] ?? 0)")
                                            .font(.title3.bold())
                                            .foregroundColor(.primary)
                                            .frame(width: 30)
                                            .multilineTextAlignment(.center)
                                        
                                        Button(action: {
                                            triggerHaptic(.impact(.light))
                                            let current = scopeScores[player.id] ?? 0
                                            scopeScores[player.id] = current + 1
                                        }) {
                                            Image(systemName: "plus")
                                                .font(.caption.bold())
                                                .foregroundColor(.scorePositive)
                                                .frame(width: 36, height: 36)
                                                .background(Color.scorePositive.opacity(0.12))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 10)
                                if player.id == game.players[0].id {
                                    Divider().background(Color.cardStroke)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardStroke, lineWidth: 1))
                        .padding(.horizontal)
                    }
                    
                    // Extra Points Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Punti Extra (es. Napola o altro)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .tracking(1)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            ForEach(game.players) { player in
                                HStack {
                                    Text(player.name)
                                        .font(.body.bold())
                                        .foregroundColor(.primary)
                                    Spacer()
                                    
                                    HStack(spacing: 14) {
                                        Button(action: {
                                            triggerHaptic(.impact(.light))
                                            let current = extraScores[player.id] ?? 0
                                            extraScores[player.id] = max(0, current - 1)
                                        }) {
                                            Image(systemName: "minus")
                                                .font(.caption.bold())
                                                .foregroundColor(.scoreNegative)
                                                .frame(width: 36, height: 36)
                                                .background(Color.scoreNegative.opacity(0.12))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text("\(extraScores[player.id] ?? 0)")
                                            .font(.title3.bold())
                                            .foregroundColor(.primary)
                                            .frame(width: 30)
                                            .multilineTextAlignment(.center)
                                        
                                        Button(action: {
                                            triggerHaptic(.impact(.light))
                                            let current = extraScores[player.id] ?? 0
                                            extraScores[player.id] = current + 1
                                        }) {
                                            Image(systemName: "plus")
                                                .font(.caption.bold())
                                                .foregroundColor(.scorePositive)
                                                .frame(width: 36, height: 36)
                                                .background(Color.scorePositive.opacity(0.12))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 10)
                                if player.id == game.players[0].id {
                                    Divider().background(Color.cardStroke)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardStroke, lineWidth: 1))
                        .padding(.horizontal)
                    }
                    
                    // Live Preview of Round Score
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anteprima Punti Round")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .tracking(1)
                            .padding(.horizontal)
                        
                        let p0 = game.players[0]
                        let p1 = game.players[1]
                        let tot0 = calculateRoundTotal(for: p0.id)
                        let tot1 = calculateRoundTotal(for: p1.id)
                        
                        HStack {
                            VStack(spacing: 4) {
                                Text(p0.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("+\(tot0)")
                                    .font(.title2.bold())
                                    .foregroundColor(.scorePositive)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Rectangle()
                                .fill(Color.cardStroke)
                                .frame(width: 1)
                                .padding(.vertical, 5)
                            
                            VStack(spacing: 4) {
                                Text(p1.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("+\(tot1)")
                                    .font(.title2.bold())
                                    .foregroundColor(.scorePositive)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardStroke, lineWidth: 1))
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        triggerHaptic(.notification(.success))
                        onSave(
                            primieraWinnerId,
                            settebelloWinnerId,
                            carteWinnerId,
                            denariWinnerId,
                            scopeScores,
                            extraScores
                        )
                        dismiss()
                    }) {
                        Text("Salva Round")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Registra Punti Smazzata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingPrimieraCalculator) {
            let primieraPlayers = game.players.map { PrimieraPlayerInfo(id: $0.id, name: $0.name) }
            PrimieraCalculatorView(
                players: primieraPlayers,
                currentWinnerId: primieraWinnerId,
                settebelloWinnerId: settebelloWinnerId
            ) { winnerId in
                primieraWinnerId = winnerId
            }
        }
    }
    
    private func calculateRoundTotal(for playerId: UUID) -> Int {
        var total = 0
        if primieraWinnerId == playerId { total += 1 }
        if settebelloWinnerId == playerId { total += 1 }
        if carteWinnerId == playerId { total += 1 }
        if denariWinnerId == playerId { total += 1 }
        total += scopeScores[playerId] ?? 0
        total += extraScores[playerId] ?? 0
        return total
    }
    
    private func pointSelectorRow(title: String, selection: Binding<UUID?>, onHelpTap: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                
                if let onHelpTap = onHelpTap {
                    Spacer()
                    Button(action: onHelpTap) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.caption2)
                            Text("Usa Calcolatore 🧮")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.appAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appAccent.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack(spacing: 8) {
                // Player 0
                let p0 = game.players[0]
                Button(action: {
                    triggerHaptic(.impact(.light))
                    if selection.wrappedValue == p0.id {
                        selection.wrappedValue = nil
                    } else {
                        selection.wrappedValue = p0.id
                    }
                }) {
                    Text(p0.name)
                        .font(.caption.bold())
                        .foregroundColor(selection.wrappedValue == p0.id ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection.wrappedValue == p0.id ? Color.appAccent : Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection.wrappedValue == p0.id ? Color.appAccent : Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                // Nessuno / Tie
                Button(action: {
                    triggerHaptic(.impact(.light))
                    selection.wrappedValue = nil
                }) {
                    Text("Nessuno")
                        .font(.caption.bold())
                        .foregroundColor(selection.wrappedValue == nil ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection.wrappedValue == nil ? Color.secondary.opacity(0.3) : Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection.wrappedValue == nil ? Color.secondary.opacity(0.4) : Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                // Player 1
                let p1 = game.players[1]
                Button(action: {
                    triggerHaptic(.impact(.light))
                    if selection.wrappedValue == p1.id {
                        selection.wrappedValue = nil
                    } else {
                        selection.wrappedValue = p1.id
                    }
                }) {
                    Text(p1.name)
                        .font(.caption.bold())
                        .foregroundColor(selection.wrappedValue == p1.id ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection.wrappedValue == p1.id ? Color.appAccent : Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection.wrappedValue == p1.id ? Color.appAccent : Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Celebration Overlay View for Ciccopaolo
struct CiccopaoloCelebrationOverlay: View {
    let winnerName: String
    let scores: [(name: String, score: Int)]
    let wins: [(name: String, wins: Int)]
    let isMatchFinished: Bool
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var rotate: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Glowing trophy or crown
                ZStack {
                    Circle()
                        .stroke(Color.trophyGold.opacity(0.15), lineWidth: 4)
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .stroke(
                            Color.trophyGold,
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap: .round,
                                lineJoin: .miter,
                                dash: [12, 16]
                            )
                        )
                        .frame(width: 124, height: 124)
                        .rotationEffect(.degrees(rotate))
                    
                    Image(systemName: isMatchFinished ? "trophy.fill" : "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.trophyGold)
                        .shadow(color: Color.trophyGold.opacity(0.4), radius: 12)
                }
                .scaleEffect(scale)
                
                VStack(spacing: 8) {
                    Text(isMatchFinished ? "MATCH COMPLETATO" : "PARTITA COMPLETATA")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .tracking(2)
                    
                    Text(isMatchFinished ? "VINCITORE DELLO SCONTRO!" : "VINCITORE DELLA PARTITA!")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.trophyGold)
                        .tracking(1)
                }
                .scaleEffect(scale)
                
                VStack(spacing: 16) {
                    Text(winnerName)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Final game points
                    if scores.count == 2 {
                        VStack(spacing: 4) {
                            Text("PUNTEGGI PARTITA")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text("\(scores[0].name) \(scores[0].score)  -  \(scores[1].score) \(scores[1].name)")
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                    }
                    
                    // Current total wins progress
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STATO DEL MATCH")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .tracking(1)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 6) {
                            ForEach(wins, id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.body.bold())
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(item.wins) \(item.wins == 1 ? "Vittoria" : "Vittorie") 🏆")
                                        .font(.body.bold())
                                        .foregroundColor(.trophyGold)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardStroke, lineWidth: 1))
                }
                .padding(.horizontal, 30)
                .scaleEffect(scale)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text(isMatchFinished ? "Torna alla Home" : "Inizia Prossima Partita")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent)
                        .cornerRadius(14)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 8)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                opacity = 1.0
            }
            withAnimation(.spring(response: 0.65, dampingFraction: 0.7)) {
                scale = 1.0
            }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotate = 360.0
            }
        }
    }
}
