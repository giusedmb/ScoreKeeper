import SwiftUI

enum BriscolaCelebrationState: Equatable {
    case none
    case matchWon(winnerName: String, wins: [(name: String, wins: Int)])
    
    static func == (lhs: BriscolaCelebrationState, rhs: BriscolaCelebrationState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.matchWon(let name1, _), .matchWon(let name2, _)):
            return name1 == name2
        default:
            return false
        }
    }
}

struct BriscolaView: View {
    @Environment(GameStore.self) private var store
    
    // Setup state
    @State private var selectedPlayerIds = Set<UUID>()
    @State private var targetWins = 2 // default to best of 3 (first to 2 wins)
    @State private var quickPlayerName = ""
    
    // Gameplay state
    @State private var showingAddRoundSheet = false
    @State private var showingResetAlert = false
    @State private var showingExitAlert = false
    @State private var activeCelebration: BriscolaCelebrationState = .none
    
    var body: some View {
        ZStack {
            Group {
                if let game = store.briscolaGame, game.isActive {
                    activeGameView(game)
                } else {
                    setupGameView
                }
            }
            .blur(radius: activeCelebration != .none ? 8 : 0)
            
            // Celebration overlay
            if case .matchWon(let winnerName, let wins) = activeCelebration {
                BriscolaCelebrationOverlay(
                    winnerName: winnerName,
                    wins: wins
                ) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        activeCelebration = .none
                    }
                    store.endBriscolaGame()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Briscola")
        .sheet(isPresented: $showingAddRoundSheet) {
            if let game = store.briscolaGame {
                BriscolaAddRoundSheet(game: game) { scores in
                    store.saveBriscolaRound(cardScores: scores)
                    
                    // Immediately check if match was won, to show celebration
                    if let updatedGame = store.briscolaGame {
                        if updatedGame.isFinished, let winner = updatedGame.winner {
                            let matchWins = updatedGame.players.map { ($0.name, $0.gameWins) }
                            activeCelebration = .matchWon(
                                winnerName: winner.name,
                                wins: matchWins
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
                store.resetBriscolaGame()
            }
        } message: {
            Text("Sei sicuro di voler azzerare i segni vinti e le mani giocate?")
        }
        .alert("Termina Partita?", isPresented: $showingExitAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Esci", role: .destructive) {
                triggerHaptic(.notification(.error))
                store.endBriscolaGame()
            }
        } message: {
            Text("Sei sicuro di voler terminare il match Briscola corrente? I dati andranno persi.")
        }
    }
    
    // MARK: - SETUP VIEW
    private var setupGameView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mani da vincere per aggiudicarsi il match:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach([1, 2, 3], id: \.self) { val in
                            let label = val == 1 ? "Singola" : (val == 2 ? "Meglio di 3 (2)" : "Meglio di 5 (3)")
                            Button(action: {
                                triggerHaptic(.impact(.light))
                                targetWins = val
                            }) {
                                Text(label)
                                    .font(.subheadline.bold())
                                    .foregroundColor(targetWins == val ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(targetWins == val ? Color.red : Color.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(targetWins == val ? Color.red : Color.cardStroke, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Impostazioni Match")
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
                    store.startBriscolaGame(targetWins: targetWins, players: selected)
                    triggerHaptic(.notification(.success))
                }) {
                    Text("Inizia Briscola")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .disabled(selectedPlayerIds.count != 2)
                .listRowBackground(selectedPlayerIds.count == 2 ? Color.red : Color.cardBackground.opacity(0.5))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }
    
    // MARK: - ACTIVE GAME VIEW
    private func activeGameView(_ game: BriscolaGame) -> some View {
        VStack(spacing: 0) {
            // Stats Header
            HStack {
                let formatText = game.targetWins == 1 ? "Singola" : (game.targetWins == 2 ? "Al meglio di 3" : "Al meglio di 5")
                Text(formatText)
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
                
                Text("Mani per Vincere: \(game.targetWins)")
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
            
            // Score Board Card (Segni Vinti)
            VStack(spacing: 16) {
                Text("SEGNI VINTI (VITTORIE)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                
                HStack(spacing: 0) {
                    // Player 1
                    VStack(spacing: 6) {
                        Text(game.players[0].name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("\(game.players[0].gameWins)")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundColor(game.players[0].gameWins > 0 ? .red : .primary)
                        
                        // Small stars representing wins
                        HStack(spacing: 4) {
                            ForEach(0..<game.targetWins, id: \.self) { index in
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(index < game.players[0].gameWins ? .red : Color.white.opacity(0.1))
                            }
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
                        
                        Text("\(game.players[1].gameWins)")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundColor(game.players[1].gameWins > 0 ? .red : .primary)
                        
                        // Small stars representing wins
                        HStack(spacing: 4) {
                            ForEach(0..<game.targetWins, id: \.self) { index in
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(index < game.players[1].gameWins ? .red : Color.white.opacity(0.1))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 8)
            }
            .padding(.vertical, 16)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardStroke, lineWidth: 1))
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            // Rounds History list (Smazzate)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if game.rounds.isEmpty {
                        VStack(spacing: 16) {
                            Spacer(minLength: 40)
                            Image(systemName: "suit.heart")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("Nessuna mano registrata.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Text("Gioca la mano, conta le carte e inserisci i punteggi.")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        Text("Storico Mani (Max 120 pt)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 10) {
                            ForEach(game.rounds.reversed()) { round in
                                BriscolaRoundHistoryRow(round: round, game: game) {
                                    if let idx = game.rounds.firstIndex(where: { $0.id == round.id }) {
                                        store.deleteBriscolaRound(at: IndexSet(integer: idx))
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
                        Text("Nuova Mano (Inserisci Punti Carte)")
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
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

// MARK: - BRISCOLA ROUND HISTORY ROW
struct BriscolaRoundHistoryRow: View {
    let round: BriscolaRound
    let game: BriscolaGame
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mano \(round.roundNumber)")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                if let winnerId = round.winnerId {
                    let wPlayerName = game.players.first(where: { $0.id == winnerId })?.name ?? ""
                    Text("Vinta da \(wPlayerName)")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.8))
                } else {
                    Text("Pareggio (60 - 60)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Score comparison bar
            let p0 = game.players[0]
            let p1 = game.players[1]
            let s0 = round.cardScores[p0.id] ?? 0
            let s1 = round.cardScores[p1.id] ?? 0
            
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(p0.name)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(s0) pt")
                        .font(.subheadline.bold())
                        .foregroundColor(s0 > 60 ? .red : (s0 == 60 ? .secondary : .primary))
                }
                
                Text("-")
                    .foregroundColor(.secondary.opacity(0.5))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(p1.name)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(s1) pt")
                        .font(.subheadline.bold())
                        .foregroundColor(s1 > 60 ? .red : (s1 == 60 ? .secondary : .primary))
                }
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
}

// MARK: - BRISCOLA INTERACTIVE ADD ROUND SHEET
struct BriscolaAddRoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    let game: BriscolaGame
    let onSave: ([UUID: Int]) -> Void
    
    @State private var player1Score: Double = 60.0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                let p0 = game.players[0]
                let p1 = game.players[1]
                let score0 = Int(player1Score)
                let score1 = 120 - score0
                
                Text("Trascina il cursore per distribuire i 120 punti totali della mano.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Visual distribution bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(score0 >= 61 ? Color.red : Color.white.opacity(0.1))
                        .frame(width: max(10, CGFloat(score0) / 120.0 * 280.0), height: 16)
                    
                    Rectangle()
                        .fill(score1 >= 61 ? Color.red : Color.white.opacity(0.1))
                        .frame(width: max(10, CGFloat(score1) / 120.0 * 280.0), height: 16)
                }
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cardStroke, lineWidth: 1))
                .frame(width: 280)
                
                // Large Score Displays
                HStack(spacing: 0) {
                    // Player 1
                    VStack(spacing: 6) {
                        Text(p0.name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("\(score0)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(score0 >= 61 ? .red : .primary)
                        
                        Text("Punti carte")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // vs
                    Text("vs")
                        .font(.title2.italic())
                        .foregroundColor(.secondary.opacity(0.4))
                    
                    // Player 2
                    VStack(spacing: 6) {
                        Text(p1.name)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Text("\(score1)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(score1 >= 61 ? .red : .primary)
                        
                        Text("Punti carte")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Result Banner
                Group {
                    if score0 == 60 {
                        Text("Pareggio (60 - 60)")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    } else if score0 > 60 {
                        Text("Mano a \(p0.name) (+1 Segno)")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                    } else {
                        Text("Mano a \(p1.name) (+1 Segno)")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
                
                // Slider
                VStack(spacing: 10) {
                    HStack {
                        Text("0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Seleziona Punti per \(p0.name)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("120")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 24)
                    
                    Slider(value: $player1Score, in: 0...120, step: 1)
                        .tint(.red)
                        .padding(.horizontal, 24)
                }
                
                // Fast buttons for standard outcomes
                HStack(spacing: 12) {
                    Button("Pareggio (60-60)") {
                        triggerHaptic(.impact(.light))
                        player1Score = 60
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .buttonStyle(.plain)
                    
                    Button("Tutto a \(p0.name)") {
                        triggerHaptic(.impact(.light))
                        player1Score = 120
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .buttonStyle(.plain)
                    
                    Button("Tutto a \(p1.name)") {
                        triggerHaptic(.impact(.light))
                        player1Score = 0
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: {
                    triggerHaptic(.notification(.success))
                    let finalScores = [p0.id: score0, p1.id: score1]
                    onSave(finalScores)
                    dismiss()
                }) {
                    Text("Salva Smazzata")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .navigationTitle("Registra Punti Briscola")
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
    }
}

// MARK: - BRISCOLA CELEBRATION OVERLAY
struct BriscolaCelebrationOverlay: View {
    let winnerName: String
    let wins: [(name: String, wins: Int)]
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
                    
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.trophyGold)
                        .shadow(color: Color.trophyGold.opacity(0.4), radius: 12)
                }
                .scaleEffect(scale)
                
                VStack(spacing: 8) {
                    Text("MATCH COMPLETATO")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .tracking(2)
                    
                    Text("VINCITORE DELLA BRISCOLA!")
                        .font(.system(size: 20, weight: .bold))
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SEGNI VINTI FINALI")
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
                                    Text("\(item.wins) Segni 🏆")
                                        .font(.body.bold())
                                        .foregroundColor(.red)
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
                    .padding(.horizontal, 30)
                }
                .scaleEffect(scale)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Torna ai Giochi")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(14)
                        .shadow(color: Color.red.opacity(0.3), radius: 8)
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
