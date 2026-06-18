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
    @State private var selectedRoundForDetail: CiccopaoloRound? = nil
    
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
                CiccopaoloAddRoundSheet(game: game) { primiera, settebello, carte, denari, scope, extra, coppia, menoDiNove, details in
                    // Call save round
                    store.saveCiccopaoloRound(
                        primieraWinnerId: primiera,
                        settebelloWinnerId: settebello,
                        carteWinnerId: carte,
                        denariWinnerId: denari,
                        scopeScores: scope,
                        extraScores: extra,
                        coppiaScores: coppia,
                        menoDiNoveScores: menoDiNove,
                        primieraDetails: details
                    )
                    
                    // Immediately check if game/match was won, to show celebration
                    if let updatedGame = store.ciccopaoloGame {
                        // Check if a player reached required wins
                        let requiredWins = updatedGame.matchFormat == .bottaSecca ? 1 : 2
                        if let matchWinner = updatedGame.matchWinner {
                            // Match finished!
                            let pWins = updatedGame.players.map { ($0.name, $0.gameWins) }
                            
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
                            if updatedGame.rounds.isEmpty, let lastRounds = updatedGame.completedGamesRounds.last {
                                // Find who won this game by calculating points from lastRounds
                                var playerScores: [(player: CiccopaoloPlayer, score: Int)] = []
                                for player in updatedGame.players {
                                    let score = lastRounds.reduce(0) { $0 + $1.pointsForPlayer(id: player.id) }
                                    playerScores.append((player, score))
                                }
                                
                                let gameWinner = playerScores.max(by: { $0.score < $1.score })?.player
                                let gameWinnerName = gameWinner?.name ?? "Nessuno"
                                let finalScores = playerScores.map { ($0.player.name, $0.score) }
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
        .sheet(item: $selectedRoundForDetail) { round in
            if let game = store.ciccopaoloGame {
                CiccopaoloRoundDetailSheet(round: round, game: game) { updatedRound in
                    store.updateCiccopaoloRound(updatedRound: updatedRound)
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
                                if selectedPlayerIds.count < 3 {
                                    selectedPlayerIds.insert(player.id)
                                } else {
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
                Text("Seleziona Partecipanti (2 o 3)")
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
                .disabled(selectedPlayerIds.count < 2 || selectedPlayerIds.count > 3)
                .listRowBackground((selectedPlayerIds.count >= 2 && selectedPlayerIds.count <= 3) ? Color.appAccent : Color.cardBackground.opacity(0.5))
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
                    ForEach(game.players.indices, id: \.self) { idx in
                        let player = game.players[idx]
                        VStack(spacing: 6) {
                            Text(player.name)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Text("\(player.currentPartitionScore)")
                                .font(.system(size: game.players.count > 2 ? 34 : 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 4) {
                                Text("Vinte:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(player.gameWins) 🏆")
                                    .font(.caption.bold())
                                    .foregroundColor(.trophyGold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        if idx < game.players.count - 1 {
                            // Divider with Swap Button
                            ZStack {
                                Rectangle()
                                    .fill(Color.cardStroke)
                                    .frame(width: 1)
                                    .padding(.vertical, 10)
                                
                                Button(action: {
                                    triggerHaptic(.impact(.light))
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        store.swapCiccopaoloPlayers(from: idx, to: idx + 1)
                                    }
                                }) {
                                    Image(systemName: "arrow.left.and.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.appAccent)
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(width: 36)
                        }
                    }
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
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    triggerHaptic(.impact(.light))
                                    selectedRoundForDetail = round
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
            
            // Show scope and extra points if any (dynamic for 2 or 3 players)
            let scopeTexts = game.players.compactMap { player -> String? in
                let sc = round.scopeScores[player.id] ?? 0
                return sc > 0 ? "\(player.name) (\(sc))" : nil
            }
            let coppiaTexts = game.players.compactMap { player -> String? in
                let cop = round.coppiaScores[player.id] ?? 0
                return cop > 0 ? "\(player.name) (\(cop))" : nil
            }
            let menoDiNoveTexts = game.players.compactMap { player -> String? in
                let m9 = round.menoDiNoveScores[player.id] ?? 0
                return m9 > 0 ? "\(player.name) (\(m9))" : nil
            }
            let extraTexts = game.players.compactMap { player -> String? in
                let ex = round.extraScores[player.id] ?? 0
                return ex > 0 ? "\(player.name) (+\(ex))" : nil
            }
            
            if !scopeTexts.isEmpty || !coppiaTexts.isEmpty || !menoDiNoveTexts.isEmpty || !extraTexts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    if !scopeTexts.isEmpty {
                        Text("Scope: \(scopeTexts.joined(separator: " - "))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if !coppiaTexts.isEmpty {
                        Text("Coppie: \(coppiaTexts.joined(separator: " - "))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if !menoDiNoveTexts.isEmpty {
                        Text("Meno di 9: \(menoDiNoveTexts.joined(separator: " - "))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if !extraTexts.isEmpty {
                        Text("Extra: \(extraTexts.joined(separator: " - "))")
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
    let roundToEdit: CiccopaoloRound?
    let onSave: (UUID?, UUID?, UUID?, UUID?, [UUID: Int], [UUID: Int], [UUID: Int], [UUID: Int], [UUID: [String: Int]]?) -> Void
    
    // Selections
    @State private var primieraWinnerId: UUID? = nil
    @State private var settebelloWinnerId: UUID? = nil
    @State private var carteWinnerId: UUID? = nil
    @State private var denariWinnerId: UUID? = nil
    
    // Scope and Extra
    @State private var scopeScores: [UUID: Int] = [:]
    @State private var extraScores: [UUID: Int] = [:]
    @State private var coppiaScores: [UUID: Int] = [:]
    @State private var menoDiNoveScores: [UUID: Int] = [:]
    
    // Primiera Details
    @State private var primieraDetails: [UUID: [String: Int]]? = nil
    
    @State private var showingPrimieraCalculator = false
    
    init(game: CiccopaoloGame, roundToEdit: CiccopaoloRound? = nil, onSave: @escaping (UUID?, UUID?, UUID?, UUID?, [UUID: Int], [UUID: Int], [UUID: Int], [UUID: Int], [UUID: [String: Int]]?) -> Void) {
        self.game = game
        self.roundToEdit = roundToEdit
        self.onSave = onSave
        
        if let round = roundToEdit {
            _primieraWinnerId = State(initialValue: round.primieraWinnerId)
            _settebelloWinnerId = State(initialValue: round.settebelloWinnerId)
            _carteWinnerId = State(initialValue: round.carteWinnerId)
            _denariWinnerId = State(initialValue: round.denariWinnerId)
            _scopeScores = State(initialValue: round.scopeScores)
            _extraScores = State(initialValue: round.extraScores)
            _coppiaScores = State(initialValue: round.coppiaScores)
            _menoDiNoveScores = State(initialValue: round.menoDiNoveScores)
            _primieraDetails = State(initialValue: round.primieraDetails)
        } else {
            // Initialize dictionaries
            var tempScopes: [UUID: Int] = [:]
            var tempExtras: [UUID: Int] = [:]
            var tempCoppie: [UUID: Int] = [:]
            var tempMenoDiNove: [UUID: Int] = [:]
            for p in game.players {
                tempScopes[p.id] = 0
                tempExtras[p.id] = 0
                tempCoppie[p.id] = 0
                tempMenoDiNove[p.id] = 0
            }
            _scopeScores = State(initialValue: tempScopes)
            _extraScores = State(initialValue: tempExtras)
            _coppiaScores = State(initialValue: tempCoppie)
            _menoDiNoveScores = State(initialValue: tempMenoDiNove)
            _primieraDetails = State(initialValue: nil)
        }
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
                                if player.id != game.players.last?.id {
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
                                VStack(alignment: .leading, spacing: 10) {
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
                                    
                                    // Declarations section (Coppia and Meno di 9)
                                    HStack(spacing: 10) {
                                        // Coppia counter
                                        HStack(spacing: 6) {
                                            Text("Coppia (+3)")
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                            
                                            HStack(spacing: 8) {
                                                Button(action: {
                                                    triggerHaptic(.impact(.light))
                                                    let current = coppiaScores[player.id] ?? 0
                                                    coppiaScores[player.id] = max(0, current - 1)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.footnote)
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                                .buttonStyle(.plain)
                                                
                                                Text("\(coppiaScores[player.id] ?? 0)")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.white)
                                                    .frame(width: 12)
                                                    .multilineTextAlignment(.center)
                                                
                                                Button(action: {
                                                    triggerHaptic(.impact(.medium))
                                                    let current = coppiaScores[player.id] ?? 0
                                                    coppiaScores[player.id] = current + 1
                                                }) {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.footnote)
                                                        .foregroundColor(.white)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Color.appAccent)
                                        .cornerRadius(8)
                                        
                                        // Meno di 9 counter
                                        HStack(spacing: 6) {
                                            Text("Meno di 9 (+2)")
                                                .font(.caption.bold())
                                                .foregroundColor(.white)
                                            
                                            HStack(spacing: 8) {
                                                Button(action: {
                                                    triggerHaptic(.impact(.light))
                                                    let current = menoDiNoveScores[player.id] ?? 0
                                                    menoDiNoveScores[player.id] = max(0, current - 1)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.footnote)
                                                        .foregroundColor(.white.opacity(0.7))
                                                }
                                                .buttonStyle(.plain)
                                                
                                                Text("\(menoDiNoveScores[player.id] ?? 0)")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.white)
                                                    .frame(width: 12)
                                                    .multilineTextAlignment(.center)
                                                
                                                Button(action: {
                                                    triggerHaptic(.impact(.medium))
                                                    let current = menoDiNoveScores[player.id] ?? 0
                                                    menoDiNoveScores[player.id] = current + 1
                                                }) {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.footnote)
                                                        .foregroundColor(.white)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                    }
                                    .padding(.top, 2)
                                }
                                .padding(.vertical, 12)
                                
                                if player.id != game.players.last?.id {
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
                    
                    // Live Preview of Round Score (dynamic for 2 or 3 players)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anteprima Punti Round")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .tracking(1)
                            .padding(.horizontal)
                        
                        HStack {
                            ForEach(game.players.indices, id: \.self) { idx in
                                let player = game.players[idx]
                                let tot = calculateRoundTotal(for: player.id)
                                VStack(spacing: 4) {
                                    Text(player.name)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Text("+\(tot)")
                                        .font(.title2.bold())
                                        .foregroundColor(.scorePositive)
                                }
                                .frame(maxWidth: .infinity)
                                
                                if idx < game.players.count - 1 {
                                    Rectangle()
                                        .fill(Color.cardStroke)
                                        .frame(width: 1)
                                        .padding(.vertical, 5)
                                }
                            }
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
                            extraScores,
                            coppiaScores,
                            menoDiNoveScores,
                            primieraDetails
                        )
                        dismiss()
                    }) {
                        Text(roundToEdit == nil ? "Salva Round" : "Salva Modifiche")
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
            .navigationTitle(roundToEdit == nil ? "Registra Punti Smazzata" : "Modifica Smazzata \(roundToEdit!.roundNumber)")
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
                settebelloWinnerId: settebelloWinnerId,
                initialSelections: primieraDetails
            ) { winnerId, details in
                primieraWinnerId = winnerId
                primieraDetails = details
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
        total += (coppiaScores[playerId] ?? 0) * 3
        total += (menoDiNoveScores[playerId] ?? 0) * 2
        total += extraScores[playerId] ?? 0
        return total
    }
    
    private func playerButton(for player: CiccopaoloPlayer, selection: Binding<UUID?>, title: String) -> some View {
        Button(action: {
            triggerHaptic(.impact(.light))
            if selection.wrappedValue == player.id {
                selection.wrappedValue = nil
            } else {
                selection.wrappedValue = player.id
            }
            if title == "Primiera" {
                primieraDetails = nil
            }
        }) {
            Text(player.name)
                .font(.caption.bold())
                .foregroundColor(selection.wrappedValue == player.id ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selection.wrappedValue == player.id ? Color.appAccent : Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection.wrappedValue == player.id ? Color.appAccent : Color.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    private func nessunoButton(selection: Binding<UUID?>, title: String) -> some View {
        Button(action: {
            triggerHaptic(.impact(.light))
            selection.wrappedValue = nil
            if title == "Primiera" {
                primieraDetails = nil
            }
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
                if game.players.count == 2 {
                    playerButton(for: game.players[0], selection: selection, title: title)
                    nessunoButton(selection: selection, title: title)
                    playerButton(for: game.players[1], selection: selection, title: title)
                } else if game.players.count == 3 {
                    playerButton(for: game.players[0], selection: selection, title: title)
                    playerButton(for: game.players[1], selection: selection, title: title)
                    nessunoButton(selection: selection, title: title)
                    playerButton(for: game.players[2], selection: selection, title: title)
                } else {
                    ForEach(game.players) { player in
                        playerButton(for: player, selection: selection, title: title)
                    }
                    nessunoButton(selection: selection, title: title)
                }
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
                    if !scores.isEmpty {
                        VStack(spacing: 4) {
                            Text("PUNTEGGI PARTITA")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            let scoresText = scores.map { "\($0.name) \($0.score)" }.joined(separator: "  -  ")
                            Text(scoresText)
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(10)
                    }
                    
                    // Current total wins progress (supported for any player count)
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


// MARK: - CICCOPAOLO ROUND DETAIL SHEET
struct CiccopaoloRoundDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let round: CiccopaoloRound
    let game: CiccopaoloGame
    let onUpdate: (CiccopaoloRound) -> Void
    
    @State private var showingEditSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Smazzata")
                        Spacer()
                        Text("\(round.roundNumber)")
                            .fontWeight(.bold)
                    }
                } header: {
                    Text("Informazioni Generali")
                }
                .listRowBackground(Color.cardBackground)
                
                Section {
                    ForEach(game.players) { player in
                        let pts = round.pointsForPlayer(id: player.id)
                        HStack {
                            Text(player.name)
                            Spacer()
                            Text("+\(pts) pt")
                                .fontWeight(.bold)
                                .foregroundColor(pts > 0 ? .scorePositive : .secondary)
                        }
                    }
                } header: {
                    Text("Punti Round Totali")
                }
                .listRowBackground(Color.cardBackground)
                
                Section {
                    detailRow(title: "Primiera", winnerId: round.primieraWinnerId)
                    detailRow(title: "Settebello", winnerId: round.settebelloWinnerId)
                    detailRow(title: "Carte", winnerId: round.carteWinnerId)
                    detailRow(title: "Denari", winnerId: round.denariWinnerId)
                } header: {
                    Text("Punti Classici")
                }
                .listRowBackground(Color.cardBackground)
                
                Section {
                    ForEach(game.players) { player in
                        let sc = round.scopeScores[player.id] ?? 0
                        HStack {
                            Text(player.name)
                            Spacer()
                            Text("\(sc) Scope")
                                .foregroundColor(sc > 0 ? .appAccent : .secondary)
                        }
                    }
                } header: {
                    Text("Scope")
                }
                .listRowBackground(Color.cardBackground)
                
                if game.players.contains(where: { (round.coppiaScores[$0.id] ?? 0) > 0 }) {
                    Section {
                        ForEach(game.players) { player in
                            let cop = round.coppiaScores[player.id] ?? 0
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text("\(cop) Coppie (+\(cop * 3) pt)")
                                    .foregroundColor(cop > 0 ? .appAccent : .secondary)
                            }
                        }
                    } header: {
                        Text("Coppie")
                    }
                    .listRowBackground(Color.cardBackground)
                }
                
                if game.players.contains(where: { (round.menoDiNoveScores[$0.id] ?? 0) > 0 }) {
                    Section {
                        ForEach(game.players) { player in
                            let m9 = round.menoDiNoveScores[player.id] ?? 0
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text("\(m9) Meno di 9 (+\(m9 * 2) pt)")
                                    .foregroundColor(m9 > 0 ? .orange : .secondary)
                            }
                        }
                    } header: {
                        Text("Meno di 9")
                    }
                    .listRowBackground(Color.cardBackground)
                }
                
                if game.players.contains(where: { (round.extraScores[$0.id] ?? 0) > 0 }) {
                    Section {
                        ForEach(game.players) { player in
                            let ex = round.extraScores[player.id] ?? 0
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text("+\(ex) pt")
                                    .foregroundColor(ex > 0 ? .appAccent : .secondary)
                            }
                        }
                    } header: {
                        Text("Punti Extra")
                    }
                    .listRowBackground(Color.cardBackground)
                }
                
                // Primiera Details section!
                if let details = round.primieraDetails {
                    Section {
                        ForEach(game.players) { player in
                            if let playerDetails = details[player.id], !playerDetails.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(player.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.appAccent)
                                    
                                    ForEach(PrimieraSuit.allCases) { suit in
                                        if let rankVal = playerDetails[suit.rawValue],
                                           let rank = PrimieraCardRank(rawValue: rankVal) {
                                            HStack {
                                                Text("\(suit.icon) \(suit.rawValue)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text("\(rank.displayName) (\(rank.primieraPoints) pt)")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.primary)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("Dettaglio Carte Primiera")
                    }
                    .listRowBackground(Color.cardBackground)
                } else {
                    Section {
                        HStack {
                            Text("Dettagli non disponibili")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Calcolata a mano")
                                .font(.caption.bold())
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    } header: {
                        Text("Dettaglio Carte Primiera")
                    }
                    .listRowBackground(Color.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Dettaglio Smazzata \(round.roundNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Modifica") {
                        showingEditSheet = true
                    }
                    .foregroundColor(.appAccent)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                CiccopaoloAddRoundSheet(game: game, roundToEdit: round) { primiera, settebello, carte, denari, scope, extra, coppia, menoDiNove, details in
                    let updated = CiccopaoloRound(
                        id: round.id,
                        roundNumber: round.roundNumber,
                        primieraWinnerId: primiera,
                        settebelloWinnerId: settebello,
                        carteWinnerId: carte,
                        denariWinnerId: denari,
                        scopeScores: scope,
                        extraScores: extra,
                        coppiaScores: coppia,
                        menoDiNoveScores: menoDiNove,
                        primieraDetails: details
                    )
                    onUpdate(updated)
                    dismiss()
                }
            }
        }
    }
    
    private func detailRow(title: String, winnerId: UUID?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let winnerId = winnerId, let player = game.players.first(where: { $0.id == winnerId }) {
                Text(player.name)
                    .fontWeight(.semibold)
                    .foregroundColor(.appAccent)
            } else {
                Text("Nessuno / Pareggio")
                    .foregroundColor(.secondary)
            }
        }
    }
}
