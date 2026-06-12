import SwiftUI

enum ScalaQuarantaCelebrationState: Equatable {
    case none
    case gameWon(winnerName: String, scores: [(name: String, score: Int)])
    
    static func == (lhs: ScalaQuarantaCelebrationState, rhs: ScalaQuarantaCelebrationState) -> Bool {
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

struct ScalaQuarantaView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var viewDismiss
    
    // Setup state
    @State private var selectedPlayerIds = Set<UUID>()
    @State private var targetScore = 101
    @State private var quickPlayerName = ""
    
    // Gameplay state
    @State private var showingAddRoundSheet = false
    @State private var showingResetAlert = false
    @State private var showingExitAlert = false
    @State private var activeCelebration: ScalaQuarantaCelebrationState = .none
    
    var body: some View {
        ZStack {
            Group {
                if let game = store.scalaQuarantaGame, game.isActive {
                    activeGameView(game)
                } else {
                    setupGameView
                }
            }
            .blur(radius: activeCelebration != .none ? 8 : 0)
            
            // Celebration overlay
            if case .gameWon(let winnerName, let scores) = activeCelebration {
                ScalaQuarantaCelebrationOverlay(
                    winnerName: winnerName,
                    scores: scores
                ) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        activeCelebration = .none
                    }
                    store.endScalaQuarantaGame()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Scala 40")
        .sheet(isPresented: $showingAddRoundSheet) {
            if let game = store.scalaQuarantaGame {
                ScalaQuarantaAddRoundSheet(game: game) { roundScores, closingPlayerId in
                    store.saveScalaQuarantaRound(scores: roundScores, closingPlayerId: closingPlayerId)
                    
                    // Immediately check if game is finished, to show celebration
                    if let updatedGame = store.scalaQuarantaGame {
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
        .alert("Azzera Partita?", isPresented: $showingResetAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Azzera", role: .destructive) {
                triggerHaptic(.notification(.warning))
                store.resetScalaQuarantaGame()
            }
        } message: {
            Text("Sei sicuro di voler azzerare il punteggio e i round della partita corrente?")
        }
        .alert("Termina Partita?", isPresented: $showingExitAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Esci", role: .destructive) {
                triggerHaptic(.notification(.error))
                store.endScalaQuarantaGame()
            }
        } message: {
            Text("Sei sicuro di voler terminare la partita di Scala 40? I dati andranno persi.")
        }
    }
    
    // MARK: - SETUP VIEW
    private var setupGameView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Punteggio limite (Eliminazione):")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach([101, 151, 201, 301], id: \.self) { val in
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
                    
                    Stepper(value: $targetScore, in: 50...999, step: 10) {
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
                .padding(.vertical, 6)
            } header: {
                Text("IMPOSTAZIONI PARTITA")
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
                            selectedPlayerIds.insert(newPlayer.id)
                            quickPlayerName = ""
                            triggerHaptic(.notification(.success))
                        }
                    }
                    .disabled(quickPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.bold)
                }
            } header: {
                Text("AGGIUNGI NUOVO GIOCATORE")
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                if store.players.isEmpty {
                    Text("Nessun giocatore registrato. Aggiungine uno sopra per iniziare.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                } else {
                    ForEach(store.players) { player in
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(selectedPlayerIds.contains(player.id) ? .appAccent : .secondary)
                                .font(.title3)
                            Text(player.name)
                                .foregroundColor(.primary)
                                .font(.body)
                                .fontWeight(.semibold)
                            Spacer()
                            if selectedPlayerIds.contains(player.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.appAccent)
                                    .font(.title3)
                            } else {
                                Circle()
                                    .stroke(Color.cardStroke, lineWidth: 2)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            triggerHaptic(.impact(.light))
                            if selectedPlayerIds.contains(player.id) {
                                selectedPlayerIds.remove(player.id)
                            } else {
                                selectedPlayerIds.insert(player.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("SELEZIONA PARTECIPANTI (MIN. 2)")
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                Button(action: {
                    triggerHaptic(.notification(.success))
                    let selected = store.players.filter { selectedPlayerIds.contains($0.id) }
                    store.startScalaQuarantaGame(targetScore: targetScore, players: selected)
                }) {
                    Text("Inizia Partita")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .disabled(selectedPlayerIds.count < 2)
                .listRowBackground(selectedPlayerIds.count >= 2 ? Color.appAccent : Color.cardBackground.opacity(0.5))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }
    
    // MARK: - ACTIVE GAME VIEW
    private func activeGameView(_ game: ScalaQuarantaGame) -> some View {
        VStack(spacing: 0) {
            // Header stats
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(game.players) { player in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(player.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                if player.isEliminated {
                                    Text("SBALLATO")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.scoreNegative)
                                        .cornerRadius(4)
                                } else {
                                    Text("Attivo")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.scorePositive)
                                        .cornerRadius(4)
                                }
                            }
                            
                            HStack(alignment: .bottom) {
                                Text("\(player.currentScore)")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(player.isEliminated ? .secondary : (player.currentScore > game.targetScore - 20 ? .orange : .white))
                                Text("/ \(game.targetScore) pt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                            }
                            
                            if player.reentriesCount > 0 {
                                Text("Rientri: \(player.reentriesCount)")
                                    .font(.caption2)
                                    .foregroundColor(.trophyGold)
                            }
                            
                            // Re-enter button if eliminated and game is not finished
                            if player.isEliminated && !game.isFinished {
                                Button(action: {
                                    triggerHaptic(.notification(.success))
                                    store.reenterPlayer(playerId: player.id)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.uturn.left.circle.fill")
                                            .font(.caption)
                                        Text("Rientra")
                                            .font(.caption.bold())
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.trophyGold)
                                    .cornerRadius(8)
                                    .shadow(color: Color.trophyGold.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                                .padding(.top, 4)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .frame(width: 150)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(player.isEliminated ? Color.scoreNegative.opacity(0.2) : Color.cardStroke, lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            
            Divider()
                .background(Color.cardStroke)
            
            // Rounds list
            if game.rounds.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Nessun round registrato")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tocca il tasto '+' per aggiungere i punti di questo round.")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                List {
                    ForEach(game.rounds.reversed()) { round in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("ROUND \(round.roundNumber)")
                                    .font(.caption.bold())
                                    .foregroundColor(.appAccent)
                                    .tracking(0.5)
                                
                                Spacer()
                                
                                if let closingId = round.closingPlayerId,
                                   let closer = game.players.first(where: { $0.id == closingId }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.scorePositive)
                                            .font(.caption)
                                        Text("\(closer.name) chiude")
                                            .font(.caption.bold())
                                            .foregroundColor(.scorePositive)
                                    }
                                }
                            }
                            
                            // Scores Grid
                            HStack(spacing: 16) {
                                ForEach(game.players) { player in
                                    let score = round.scores[player.id] ?? 0
                                    let isCloser = round.closingPlayerId == player.id
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(player.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        
                                        Text(isCloser ? "0 pt" : "+\(score) pt")
                                            .font(.subheadline.bold())
                                            .foregroundColor(isCloser ? .scorePositive : (score >= 25 ? .scoreNegative : .primary))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.cardBackground)
                    }
                    .onDelete { offsets in
                        triggerHaptic(.notification(.warning))
                        store.deleteScalaQuarantaRound(at: offsets)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
            
            // Footer with action button
            VStack {
                Button(action: {
                    triggerHaptic(.impact(.medium))
                    showingAddRoundSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Aggiungi Round")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appAccent)
                    .cornerRadius(14)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
                .padding(.top, 10)
            }
            .background(Color.cardBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.cardStroke),
                alignment: .top
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    showingExitAlert = true
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.cardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: {
                    showingResetAlert = true
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.cardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    triggerHaptic(.notification(.warning))
                    // Terminate early and archive
                    if let winner = game.winner {
                        let finalScores = game.players.map { ($0.name, $0.currentScore) }
                        activeCelebration = .gameWon(
                            winnerName: winner.name,
                            scores: finalScores
                        )
                        triggerGameWinHaptics()
                    } else {
                        store.endScalaQuarantaGame()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 11, weight: .bold))
                        Text("Termina")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.scoreNegative)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - CELEBRATION OVERLAY
struct ScalaQuarantaCelebrationOverlay: View {
    let winnerName: String
    let scores: [(name: String, score: Int)]
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Trophy and Title
                VStack(spacing: 12) {
                    Text("🏆")
                        .font(.system(size: 80))
                        .shadow(color: Color.trophyGold.opacity(0.4), radius: 10, x: 0, y: 5)
                    
                    Text("VINCITORE!")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.trophyGold)
                        .tracking(2)
                    
                    Text(winnerName)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Final Leaderboard
                VStack(spacing: 12) {
                    Text("CLASSIFICA FINALE")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .tracking(1)
                        .padding(.bottom, 4)
                    
                    VStack(spacing: 8) {
                        // Sort by score ascending (lowest score wins in Scala 40)
                        let sortedScores = scores.sorted(by: { $0.score < $1.score })
                        ForEach(0..<sortedScores.count, id: \.self) { index in
                            let entry = sortedScores[index]
                            
                            HStack {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundColor(index == 0 ? .trophyGold : .secondary)
                                    .frame(width: 24, alignment: .leading)
                                
                                Text(entry.name)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(entry.score) pt")
                                    .font(.body.bold())
                                    .foregroundColor(index == 0 ? .scorePositive : .white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(index == 0 ? Color.trophyGold.opacity(0.12) : Color.white.opacity(0.04))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(index == 0 ? Color.trophyGold.opacity(0.3) : Color.cardStroke, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Completa e Salva")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.scorePositive)
                        .cornerRadius(14)
                        .shadow(color: Color.scorePositive.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - ADD ROUND SHEET
struct ScalaQuarantaAddRoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let game: ScalaQuarantaGame
    let onSave: ([UUID: Int], UUID?) -> Void
    
    // Tracks scores added for each player
    @State private var inputScores: [UUID: Int] = [:]
    // Toggles for card calculator modes
    @State private var closingPlayerId: UUID? = nil
    @State private var notOpenedIds = Set<UUID>()
    
    // Custom calculator values per player
    @State private var jokersCount: [UUID: Int] = [:]
    @State private var acesCount: [UUID: Int] = [:]
    @State private var figuresCount: [UUID: Int] = [:]
    @State private var otherCardsSum: [UUID: Int] = [:]
    @State private var expandedCalculatorId: UUID? = nil
    
    init(game: ScalaQuarantaGame, onSave: @escaping ([UUID: Int], UUID?) -> Void) {
        self.game = game
        self.onSave = onSave
        
        // Initialize active scores for non-eliminated players
        var scores: [UUID: Int] = [:]
        for player in game.players {
            if !player.isEliminated {
                scores[player.id] = 0
            }
        }
        self._inputScores = State(initialValue: scores)
    }
    
    private func updateScoreFromCalculator(for playerId: UUID) {
        if closingPlayerId == playerId {
            inputScores[playerId] = 0
            return
        }
        
        if notOpenedIds.contains(playerId) {
            inputScores[playerId] = 100
            return
        }
        
        let jokers = jokersCount[playerId] ?? 0
        let aces = acesCount[playerId] ?? 0
        let figures = figuresCount[playerId] ?? 0
        let others = otherCardsSum[playerId] ?? 0
        
        let total = (jokers * 25) + (aces * 11) + (figures * 10) + others
        inputScores[playerId] = total
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Quick Info Banner
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.appAccent)
                        Text("Calcola il punteggio delle carte rimaste in mano:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    ForEach(game.players) { player in
                        let isEliminated = player.isEliminated
                        
                        VStack(spacing: 0) {
                            // Player Info Row
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(.headline)
                                        .foregroundColor(isEliminated ? .secondary : .white)
                                    if isEliminated {
                                        Text("Sballato")
                                            .font(.caption2.bold())
                                            .foregroundColor(.scoreNegative)
                                    } else {
                                        Text("Score: \(player.currentScore) pt")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if !isEliminated {
                                    HStack(spacing: 12) {
                                        // Points badge
                                        let points = inputScores[player.id] ?? 0
                                        Text("\(points) pt")
                                            .font(.title3.bold())
                                            .foregroundColor(closingPlayerId == player.id ? .scorePositive : .white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(closingPlayerId == player.id ? Color.scorePositive.opacity(0.12) : Color.white.opacity(0.05))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(closingPlayerId == player.id ? Color.scorePositive : Color.cardStroke, lineWidth: 1)
                                            )
                                        
                                        // Expand calculator toggle
                                        Button(action: {
                                            triggerHaptic(.impact(.light))
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                if expandedCalculatorId == player.id {
                                                    expandedCalculatorId = nil
                                                } else {
                                                    expandedCalculatorId = player.id
                                                }
                                            }
                                        }) {
                                            Image(systemName: "chevron.down")
                                                .font(.body.bold())
                                                .foregroundColor(.appAccent)
                                                .rotationEffect(.degrees(expandedCalculatorId == player.id ? 180 : 0))
                                                .padding(6)
                                                .background(Color.white.opacity(0.05))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding()
                            
                            // Interactive Calculator (Visible if expanded and player is active)
                            if !isEliminated && expandedCalculatorId == player.id {
                                Divider()
                                    .background(Color.cardStroke)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 16) {
                                    // Row toggles: Close & Not Opened
                                    HStack(spacing: 12) {
                                        // "Ha Chiuso" toggle
                                        let isCloser = closingPlayerId == player.id
                                        Button(action: {
                                            triggerHaptic(.impact(.light))
                                            withAnimation {
                                                if isCloser {
                                                    closingPlayerId = nil
                                                } else {
                                                    closingPlayerId = player.id
                                                    notOpenedIds.remove(player.id)
                                                }
                                                updateScoreFromCalculator(for: player.id)
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: isCloser ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(isCloser ? .white : .secondary)
                                                Text("Ha Chiuso (0 pt)")
                                                    .font(.footnote.bold())
                                                    .foregroundColor(isCloser ? .white : .primary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(isCloser ? Color.scorePositive : Color.white.opacity(0.04))
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isCloser ? Color.scorePositive : Color.cardStroke, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        
                                        // "Non ha aperto" toggle
                                        let isNotOpened = notOpenedIds.contains(player.id)
                                        Button(action: {
                                            triggerHaptic(.impact(.light))
                                            withAnimation {
                                                if isNotOpened {
                                                    notOpenedIds.remove(player.id)
                                                } else {
                                                    notOpenedIds.insert(player.id)
                                                    if closingPlayerId == player.id {
                                                        closingPlayerId = nil
                                                    }
                                                }
                                                updateScoreFromCalculator(for: player.id)
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: isNotOpened ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(isNotOpened ? .white : .secondary)
                                                Text("Non Aperto (100 pt)")
                                                    .font(.footnote.bold())
                                                    .foregroundColor(isNotOpened ? .white : .primary)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(isNotOpened ? Color.scoreNegative : Color.white.opacity(0.04))
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isNotOpened ? Color.scoreNegative : Color.cardStroke, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    // Custom Card Counters (only active if neither Closed nor Not Opened is selected)
                                    if closingPlayerId != player.id && !notOpenedIds.contains(player.id) {
                                        VStack(spacing: 12) {
                                            // Counter: Joker (25 pt)
                                            counterRow(
                                                title: "🃏 Jolly (25 pt)",
                                                value: Binding(
                                                    get: { jokersCount[player.id] ?? 0 },
                                                    set: { jokersCount[player.id] = $0; updateScoreFromCalculator(for: player.id) }
                                                )
                                            )
                                            
                                            // Counter: Ace (11 pt)
                                            counterRow(
                                                title: "🅰️ Asso (11 pt)",
                                                value: Binding(
                                                    get: { acesCount[player.id] ?? 0 },
                                                    set: { acesCount[player.id] = $0; updateScoreFromCalculator(for: player.id) }
                                                )
                                            )
                                            
                                            // Counter: Figure (10 pt)
                                            counterRow(
                                                title: "👑 Figure (K, Q, J) (10 pt)",
                                                value: Binding(
                                                    get: { figuresCount[player.id] ?? 0 },
                                                    set: { figuresCount[player.id] = $0; updateScoreFromCalculator(for: player.id) }
                                                )
                                            )
                                            
                                            // Stepper: Other points (face values)
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    Text("🔢 Altre carte (valore nominale)")
                                                        .font(.footnote)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                    Text("\(otherCardsSum[player.id] ?? 0) pt")
                                                        .font(.footnote.bold())
                                                        .foregroundColor(.appAccent)
                                                }
                                                
                                                HStack(spacing: 12) {
                                                    // Quick add points
                                                    ForEach([2, 5, 10], id: \.self) { pts in
                                                        Button(action: {
                                                            triggerHaptic(.impact(.light))
                                                            let current = otherCardsSum[player.id] ?? 0
                                                            otherCardsSum[player.id] = current + pts
                                                            updateScoreFromCalculator(for: player.id)
                                                        }) {
                                                            Text("+\(pts)")
                                                                .font(.caption.bold())
                                                                .foregroundColor(.secondary)
                                                                .padding(.horizontal, 10)
                                                                .padding(.vertical, 6)
                                                                .background(Color.white.opacity(0.05))
                                                                .cornerRadius(6)
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    // Clear button
                                                    Button("Azzera") {
                                                        triggerHaptic(.impact(.light))
                                                        otherCardsSum[player.id] = 0
                                                        updateScoreFromCalculator(for: player.id)
                                                    }
                                                    .font(.caption.bold())
                                                    .foregroundColor(.scoreNegative)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.scoreNegative.opacity(0.1))
                                                    .cornerRadius(6)
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.top, 4)
                                        }
                                        .transition(.opacity)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.02))
                            }
                        }
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isEliminated ? Color.clear : Color.cardStroke, lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .opacity(isEliminated ? 0.5 : 1.0)
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Color.appBackground)
            .navigationTitle("Aggiungi Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salva") {
                        triggerHaptic(.notification(.success))
                        onSave(inputScores, closingPlayerId)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    @ViewBuilder
    private func counterRow(title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(.footnote)
                .foregroundColor(.white)
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    triggerHaptic(.impact(.light))
                    if value.wrappedValue > 0 {
                        value.wrappedValue -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(value.wrappedValue > 0 ? .appAccent : .secondary.opacity(0.3))
                }
                .disabled(value.wrappedValue <= 0)
                .buttonStyle(.plain)
                
                Text("\(value.wrappedValue)")
                    .font(.body.bold())
                    .frame(width: 20)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    triggerHaptic(.impact(.light))
                    value.wrappedValue += 1
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.appAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
        }
    }
}
