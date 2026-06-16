import SwiftUI

enum ScopaCelebrationState: Equatable {
    case none
    case gameWon(winnerName: String, scores: [(name: String, score: Int)])
    
    static func == (lhs: ScopaCelebrationState, rhs: ScopaCelebrationState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.gameWon(let name1, _), .gameWon(let name2, _)):
            return name1 == name2
        default:
            return false
        }
    }
}

struct ScopaView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var viewDismiss
    
    // Setup state
    @State private var selectedPlayerIds = Set<UUID>()
    @State private var targetScore = 11
    @State private var quickPlayerName = ""
    
    // Gameplay state
    @State private var showingAddRoundSheet = false
    @State private var showingResetAlert = false
    @State private var showingExitAlert = false
    @State private var activeCelebration: ScopaCelebrationState = .none
    @State private var selectedRoundForDetail: ScopaRound? = nil
    
    var body: some View {
        ZStack {
            Group {
                if let game = store.scopaGame, game.isActive {
                    activeGameView(game)
                } else {
                    setupGameView
                }
            }
            .blur(radius: activeCelebration != .none ? 8 : 0)
            
            // Celebration overlay
            if case .gameWon(let winnerName, let scores) = activeCelebration {
                ScopaCelebrationOverlay(
                    winnerName: winnerName,
                    scores: scores
                ) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        activeCelebration = .none
                    }
                    store.endScopaGame()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Scopa")
        .sheet(isPresented: $showingAddRoundSheet) {
            if let game = store.scopaGame {
                ScopaAddRoundSheet(game: game) { primiera, settebello, carte, denari, scope, napola, details in
                    store.saveScopaRound(
                        primieraWinnerId: primiera,
                        settebelloWinnerId: settebello,
                        carteWinnerId: carte,
                        denariWinnerId: denari,
                        scopeScores: scope,
                        napolaScores: napola,
                        primieraDetails: details
                    )
                    
                    // Immediately check if game was won, to show celebration
                    if let updatedGame = store.scopaGame {
                        if updatedGame.isFinished, let winner = updatedGame.winner {
                            let finalScores = updatedGame.players.map { ($0.name, $0.currentScore) }
                            activeCelebration = .gameWon(
                                winnerName: winner.name,
                                scores: finalScores
                            )
                            triggerGameWinHaptics()
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedRoundForDetail) { round in
            if let game = store.scopaGame {
                ScopaRoundDetailSheet(round: round, game: game) { updatedRound in
                    store.updateScopaRound(updatedRound: updatedRound)
                }
            }
        }
        .alert("Azzera Partita?", isPresented: $showingResetAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Azzera", role: .destructive) {
                triggerHaptic(.notification(.warning))
                store.resetScopaGame()
            }
        } message: {
            Text("Sei sicuro di voler azzerare il punteggio e i round della partita corrente?")
        }
        .alert("Termina Partita?", isPresented: $showingExitAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Esci", role: .destructive) {
                triggerHaptic(.notification(.error))
                store.endScopaGame()
            }
        } message: {
            Text("Sei sicuro di voler terminare la partita Scopa corrente? I dati andranno persi.")
        }
    }
    
    // MARK: - SETUP VIEW
    private var setupGameView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Punteggio di arrivo (Partita):")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach([11, 21], id: \.self) { val in
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
                    store.startScopaGame(targetScore: targetScore, players: selected)
                    triggerHaptic(.notification(.success))
                }) {
                    Text("Inizia Scopa")
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
    
    // MARK: - ACTIVE GAME VIEW
    private func activeGameView(_ game: ScopaGame) -> some View {
        VStack(spacing: 0) {
            // Stats Header
            HStack {
                Text("Partita a Scopa")
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
                
                Text("Obiettivo: \(game.targetScore) pt")
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
                        
                        Text("\(game.players[0].currentScore)")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
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
                        
                        Text("\(game.players[1].currentScore)")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
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
                            Image(systemName: "suit.diamond")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("Nessuna smazzata registrata.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Text("Esegui la smazzata e inserisci i punti qui sotto.")
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
                                ScopaRoundHistoryRow(round: round, game: game) {
                                    if let idx = game.rounds.firstIndex(where: { $0.id == round.id }) {
                                        store.deleteScopaRound(at: IndexSet(integer: idx))
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
                    .background(Color.orange)
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

// MARK: - SCOPA ROUND HISTORY ROW
struct ScopaRoundHistoryRow: View {
    let round: ScopaRound
    let game: ScopaGame
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Smazzata \(round.roundNumber)")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Show breakdown
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
            
            // Badges for what was won
            HStack(spacing: 6) {
                badge(label: "Primiera", winnerId: round.primieraWinnerId)
                badge(label: "Settebello", winnerId: round.settebelloWinnerId)
                badge(label: "Carte", winnerId: round.carteWinnerId)
                badge(label: "Denari", winnerId: round.denariWinnerId)
            }
            
            // Scope & Napola text
            let p0 = game.players[0]
            let p1 = game.players[1]
            let sc0 = round.scopeScores[p0.id] ?? 0
            let sc1 = round.scopeScores[p1.id] ?? 0
            let np0 = round.napolaScores[p0.id] ?? 0
            let np1 = round.napolaScores[p1.id] ?? 0
            
            if sc0 > 0 || sc1 > 0 || np0 > 0 || np1 > 0 {
                HStack(spacing: 12) {
                    if sc0 > 0 || sc1 > 0 {
                        Text("Scope: \(p0.name) (\(sc0)) - \(p1.name) (\(sc1))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if np0 > 0 || np1 > 0 {
                        Text("Napola: \(p0.name) (+\(np0)) - \(p1.name) (+\(np1))")
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
    
    private func badge(label: String, winnerId: UUID?) -> some View {
        let playerName = game.players.first(where: { $0.id == winnerId })?.name ?? "-"
        return HStack(spacing: 3) {
            Text(label[label.startIndex..<label.index(label.startIndex, offsetBy: min(3, label.count))].uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
            Text(playerName)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(winnerId != nil ? .orange : .secondary.opacity(0.5))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(winnerId != nil ? Color.orange.opacity(0.1) : Color.white.opacity(0.02))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(winnerId != nil ? Color.orange.opacity(0.25) : Color.cardStroke, lineWidth: 1))
    }
}

// MARK: - SCOPA INTERACTIVE ADD ROUND SHEET
struct ScopaAddRoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    let game: ScopaGame
    let roundToEdit: ScopaRound?
    let onSave: (UUID?, UUID?, UUID?, UUID?, [UUID: Int], [UUID: Int], [UUID: [String: Int]]?) -> Void
    
    // Selections
    @State private var primieraWinnerId: UUID? = nil
    @State private var settebelloWinnerId: UUID? = nil
    @State private var carteWinnerId: UUID? = nil
    @State private var denariWinnerId: UUID? = nil
    
    // Scope and Napola
    @State private var scopeScores: [UUID: Int] = [:]
    @State private var napolaScores: [UUID: Int] = [:]
    
    // Primiera Details
    @State private var primieraDetails: [UUID: [String: Int]]? = nil
    
    @State private var showingPrimieraCalculator = false
    
    init(game: ScopaGame, roundToEdit: ScopaRound? = nil, onSave: @escaping (UUID?, UUID?, UUID?, UUID?, [UUID: Int], [UUID: Int], [UUID: [String: Int]]?) -> Void) {
        self.game = game
        self.roundToEdit = roundToEdit
        self.onSave = onSave
        
        if let round = roundToEdit {
            _primieraWinnerId = State(initialValue: round.primieraWinnerId)
            _settebelloWinnerId = State(initialValue: round.settebelloWinnerId)
            _carteWinnerId = State(initialValue: round.carteWinnerId)
            _denariWinnerId = State(initialValue: round.denariWinnerId)
            _scopeScores = State(initialValue: round.scopeScores)
            _napolaScores = State(initialValue: round.napolaScores)
            _primieraDetails = State(initialValue: round.primieraDetails)
        } else {
            var tempScopes: [UUID: Int] = [:]
            var tempNapolas: [UUID: Int] = [:]
            for p in game.players {
                tempScopes[p.id] = 0
                tempNapolas[p.id] = 0
            }
            _scopeScores = State(initialValue: tempScopes)
            _napolaScores = State(initialValue: tempNapolas)
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
                    
                    // Napola Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Punti Napola / Napoli (da 3 a 10 pt)")
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
                                            let current = napolaScores[player.id] ?? 0
                                            napolaScores[player.id] = max(0, current - 1)
                                        }) {
                                            Image(systemName: "minus")
                                                .font(.caption.bold())
                                                .foregroundColor(.scoreNegative)
                                                .frame(width: 36, height: 36)
                                                .background(Color.scoreNegative.opacity(0.12))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text("\(napolaScores[player.id] ?? 0)")
                                            .font(.title3.bold())
                                            .foregroundColor(.primary)
                                            .frame(width: 30)
                                            .multilineTextAlignment(.center)
                                        
                                        Button(action: {
                                            triggerHaptic(.impact(.light))
                                            let current = napolaScores[player.id] ?? 0
                                            // Napoli max score is usually 10 points
                                            napolaScores[player.id] = min(10, current + 1)
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
                    
                    // Live Preview
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
                            napolaScores,
                            primieraDetails
                        )
                        dismiss()
                    }) {
                        Text(roundToEdit == nil ? "Salva Round" : "Salva Modifiche")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.vertical)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(roundToEdit == nil ? "Punti Smazzata Scopa" : "Modifica Smazzata \(roundToEdit!.roundNumber)")
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
        total += napolaScores[playerId] ?? 0
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
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack(spacing: 8) {
                let p0 = game.players[0]
                Button(action: {
                    triggerHaptic(.impact(.light))
                    if selection.wrappedValue == p0.id {
                        selection.wrappedValue = nil
                    } else {
                        selection.wrappedValue = p0.id
                    }
                    if title == "Primiera" {
                        primieraDetails = nil
                    }
                }) {
                    Text(p0.name)
                        .font(.caption.bold())
                        .foregroundColor(selection.wrappedValue == p0.id ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection.wrappedValue == p0.id ? Color.orange : Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection.wrappedValue == p0.id ? Color.orange : Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                
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
                
                let p1 = game.players[1]
                Button(action: {
                    triggerHaptic(.impact(.light))
                    if selection.wrappedValue == p1.id {
                        selection.wrappedValue = nil
                    } else {
                        selection.wrappedValue = p1.id
                    }
                    if title == "Primiera" {
                        primieraDetails = nil
                    }
                }) {
                    Text(p1.name)
                        .font(.caption.bold())
                        .foregroundColor(selection.wrappedValue == p1.id ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection.wrappedValue == p1.id ? Color.orange : Color.white.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection.wrappedValue == p1.id ? Color.orange : Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - SCOPA ROUND DETAIL SHEET
struct ScopaRoundDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let round: ScopaRound
    let game: ScopaGame
    let onUpdate: (ScopaRound) -> Void
    
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
                                .foregroundColor(sc > 0 ? .orange : .secondary)
                        }
                    }
                } header: {
                    Text("Scope")
                }
                .listRowBackground(Color.cardBackground)
                
                if game.players.contains(where: { (round.napolaScores[$0.id] ?? 0) > 0 }) {
                    Section {
                        ForEach(game.players) { player in
                            let np = round.napolaScores[player.id] ?? 0
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text("+\(np) pt")
                                    .foregroundColor(np > 0 ? .appAccent : .secondary)
                            }
                        }
                    } header: {
                        Text("Napola")
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
                                        .foregroundColor(.orange)
                                    
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
                    .foregroundColor(.orange)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                ScopaAddRoundSheet(game: game, roundToEdit: round) { primiera, settebello, carte, denari, scope, napola, details in
                    let updated = ScopaRound(
                        id: round.id,
                        roundNumber: round.roundNumber,
                        primieraWinnerId: primiera,
                        settebelloWinnerId: settebello,
                        carteWinnerId: carte,
                        denariWinnerId: denari,
                        scopeScores: scope,
                        napolaScores: napola,
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
                    .foregroundColor(.orange)
            } else {
                Text("Nessuno / Pareggio")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - SCOPA CELEBRATION OVERLAY
struct ScopaCelebrationOverlay: View {
    let winnerName: String
    let scores: [(name: String, score: Int)]
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var rotate: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
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
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.trophyGold)
                        .shadow(color: Color.trophyGold.opacity(0.4), radius: 12)
                }
                .scaleEffect(scale)
                
                VStack(spacing: 8) {
                    Text("PARTITA COMPLETATA")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .tracking(2)
                    
                    Text("VINCITORE DELLA PARTITA!")
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
                    
                    if scores.count == 2 {
                        VStack(spacing: 8) {
                            Text("PUNTEGGI FINALI")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text("\(scores[0].name) \(scores[0].score)  -  \(scores[1].score) \(scores[1].name)")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardStroke, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 30)
                .scaleEffect(scale)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Torna ai Giochi")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(14)
                        .shadow(color: Color.orange.opacity(0.3), radius: 8)
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
