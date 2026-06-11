import SwiftUI
import UIKit

// MARK: - Celebration Data Models
enum CelebrationState: Equatable {
    case none
    case round(winnerName: String, score: Int, roundNumber: Int)
    case game(winnerName: String, wins: Int, score: Int, leaderboard: [LeaderboardEntry])
}

struct LeaderboardEntry: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let wins: Int
    let score: Int
    let place: Int
}

struct GameView: View {
    @Environment(GameStore.self) private var store
    @Binding var showingNewGame: Bool
    @Binding var showingPlayerAdd: Bool
    
    @State private var showingResetAlert = false
    @State private var showingEndAlert = false
    @State private var showingRoundSummary = false
    @State private var activeCelebration: CelebrationState = .none
    
    init(showingNewGame: Binding<Bool>, showingAddPlayer: Binding<Bool>) {
        self._showingNewGame = showingNewGame
        self._showingPlayerAdd = showingAddPlayer
    }
    
    var body: some View {
        ZStack {
            // Main app layout
            VStack {
                if let game = store.currentGame {
                    activeGameView(game)
                } else {
                    noActiveGameView
                }
            }
            .blur(radius: activeCelebration != .none ? 8 : 0)
            
            // Celebration overlay
            if activeCelebration != .none {
                CelebrationOverlay(state: activeCelebration) {
                    let prevCelebration = activeCelebration
                    withAnimation(.easeOut(duration: 0.3)) {
                        activeCelebration = .none
                    }
                    if case .round = prevCelebration {
                        showingRoundSummary = true
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .background(Color.appBackground)
        .navigationTitle(store.currentGame != nil ? "Partita Attiva" : "ScoreKeeper")
        .toolbar {
            if store.currentGame != nil {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingResetAlert = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                            .padding(7)
                            .background(Color.cardBackground)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.cardStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showingEndAlert = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 11, weight: .bold))
                            Text("Termina Partita")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.scoreNegative)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .alert("Azzera Punteggi?", isPresented: $showingResetAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Azzera tutto", role: .destructive) {
                triggerHaptic(.notification(.warning))
                store.resetScores()
            }
        } message: {
            Text("Sei sicuro di voler azzerare tutti i punteggi e i round di questa partita? I dati andranno persi.")
        }
        .alert("Termina Partita?", isPresented: $showingEndAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Termina e Salva", role: .none) {
                if let game = store.currentGame {
                    let sorted = game.participantIds.sorted { id1, id2 in
                        let wins1 = game.roundWins(for: id1)
                        let wins2 = game.roundWins(for: id2)
                        if wins1 == wins2 {
                            return game.totalScore(for: id1) > game.totalScore(for: id2)
                        }
                        return wins1 > wins2
                    }
                    let leaderboard = sorted.enumerated().map { index, id in
                        LeaderboardEntry(
                            name: getParticipantName(id: id),
                            wins: game.roundWins(for: id),
                            score: game.totalScore(for: id),
                            place: index + 1
                        )
                    }
                    if !leaderboard.isEmpty {
                        activeCelebration = .game(winnerName: leaderboard[0].name, wins: leaderboard[0].wins, score: leaderboard[0].score, leaderboard: leaderboard)
                        triggerGameWinHaptics()
                    }
                }
                store.endCurrentGame()
            }
            Button("Annulla Partita", role: .destructive) {
                triggerHaptic(.notification(.error))
                store.cancelCurrentGame()
            }
        } message: {
            if store.activeRoundScores.values.contains(where: { $0 != 0 }) {
                Text("Attenzione: hai dei punteggi non salvati nel round in corso. Se termini la partita adesso, questi punteggi andranno persi.\n\nVuoi terminare e salvare la partita nello storico, o annullarla del tutto?")
            } else {
                Text("Vuoi terminare e salvare la partita nello storico, oppure annullarla del tutto? Il vincitore sarà chi ha vinto più round.")
            }
        }
        .sheet(isPresented: $showingRoundSummary) {
            if let game = store.currentGame {
                RoundSummarySheet(game: game, activeCelebration: $activeCelebration)
            }
        }
    }
    
    private func activeGameView(_ game: Game) -> some View {
        VStack(spacing: 0) {
            // Summary header
            HStack {
                Text("Giocatori in partita: \(game.participantIds.count)")
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
                
                Text("Round: \(game.rounds.count + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            // Round wins counter - prominent visual bar
            VStack(alignment: .leading, spacing: 6) {
                Text("ROUND VINTI")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(game.participantIds, id: \.self) { participantId in
                            let name = getParticipantName(id: participantId)
                            let wins = game.roundWins(for: participantId)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(wins > 0 ? .trophyGold : .secondary.opacity(0.3))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(name)
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Text("\(wins)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(wins > 0 ? .trophyGold : .primary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.cardBackground)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(wins > 0 ? Color.trophyGold.opacity(0.4) : Color.cardStroke, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 12)
            
            // Active players list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(game.participantIds, id: \.self) { participantId in
                        let name = getParticipantName(id: participantId)
                        let total = game.totalScore(for: participantId)
                        let currentRound = store.activeRoundScores[participantId] ?? 0
                        
                        ParticipantCard(
                            name: name,
                            totalScore: total,
                            roundScore: currentRound,
                            onIncrement: { val in
                                triggerHaptic(.impact(.light))
                                store.updateActiveScore(for: participantId, by: val)
                            }
                        )
                    }
                }
                .padding()
                
                // Completed rounds list
                if !game.rounds.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Storico Round")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        LazyVStack(spacing: 10) {
                            ForEach(game.rounds.reversed()) { round in
                                RoundHistoryRow(round: round, game: game, store: store)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Bottom Action Bar
            VStack(spacing: 8) {
                Button(action: {
                    triggerHaptic(.impact(.medium))
                    let activeScores = store.activeRoundScores
                    let maxEntry = activeScores.max(by: { $0.value < $1.value })
                    let winnerId = maxEntry?.key
                    let winnerName = winnerId != nil ? getParticipantName(id: winnerId!) : "Nessuno"
                    let winnerScore = winnerId != nil ? (activeScores[winnerId!] ?? 0) : 0
                    let roundNumber = game.rounds.count + 1
                    
                    store.activeRoundWinnerId = winnerId
                    
                    activeCelebration = .round(
                        winnerName: winnerName,
                        score: winnerScore,
                        roundNumber: roundNumber
                    )
                    triggerRoundWinHaptics()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Termina Round")
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.appAccent)
                    .cornerRadius(14)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                .padding(.top, 10)
            }
            .background(Color.appBackground.opacity(0.85))
        }
    }
    
    // MARK: - No Active Game View
    private var noActiveGameView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Minimal Apple-style trophy logo
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(white: 0.14), Color(white: 0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 100, height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.trophyGold, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Nessuna Partita Attiva")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Text("Crea una nuova partita per iniziare a tracciare i punteggi.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Ripeti Ultima Partita Card
            if let lastGame = store.gamesHistory.first {
                let lastPlayerNames = lastGame.participantIds.map { id -> String in
                    store.players.first(where: { $0.id == id })?.name ?? "Giocatore"
                }.joined(separator: ", ")
                
                VStack(spacing: 10) {
                    Text("Gioca di nuovo con")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)
                    
                    Button(action: {
                        triggerHaptic(.notification(.success))
                        store.startNewGame(participantIds: lastGame.participantIds)
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.appAccent)
                                Text("Ultimi Giocatori")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.appAccent)
                                    .font(.title3)
                            }
                            
                            Text(lastPlayerNames)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.cardStroke, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 40)
                }
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    triggerHaptic(.impact(.medium))
                    showingNewGame = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Nuova Partita")
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.appAccent)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    private func getParticipantName(id: UUID) -> String {
        return store.players.first(where: { $0.id == id })?.name ?? "Sconosciuto"
    }
}

// MARK: - Participant Card Component
struct ParticipantCard: View {
    let name: String
    let totalScore: Int
    let roundScore: Int
    let onIncrement: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("Totale: \(totalScore)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Large score adjustment controls with subtle apple-style buttons
            HStack(spacing: 16) {
                Button(action: { onIncrement(-1) }) {
                    Image(systemName: "minus")
                        .font(.title3.bold())
                        .foregroundColor(.scoreNegative)
                        .frame(width: 44, height: 44)
                        .background(Color.scoreNegative.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.scoreNegative.opacity(0.2), lineWidth: 1))
                }
                
                Text("\(roundScore >= 0 ? "+" : "")\(roundScore)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(roundScore > 0 ? .scorePositive : (roundScore < 0 ? .scoreNegative : .secondary))
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                
                Button(action: { onIncrement(1) }) {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                        .foregroundColor(.scorePositive)
                        .frame(width: 44, height: 44)
                        .background(Color.scorePositive.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.scorePositive.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
    }
}

// MARK: - Round Summary Sheet
struct RoundSummarySheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let game: Game
    @Binding var activeCelebration: CelebrationState
    
    @State private var selectedWinnerId: UUID?
    @State private var roundNote = ""
    
    init(game: Game, activeCelebration: Binding<CelebrationState>) {
        self.game = game
        self._activeCelebration = activeCelebration
        _selectedWinnerId = State(initialValue: nil)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Chi ha vinto il round?")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                List {
                    ForEach(game.participantIds, id: \.self) { participantId in
                        let name = getParticipantName(id: participantId)
                        let score = store.activeRoundScores[participantId] ?? 0
                        let sign = score >= 0 ? "+" : ""
                        let isWinner = selectedWinnerId == participantId
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Punti in questo round: \(sign)\(score)")
                                    .font(.subheadline)
                                    .foregroundColor(score > 0 ? .scorePositive : (score < 0 ? .scoreNegative : .secondary))
                            }
                            
                            Spacer()
                            
                            if isWinner {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.trophyGold)
                                    .font(.title2)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            triggerHaptic(.impact(.medium))
                            if selectedWinnerId == participantId {
                                selectedWinnerId = nil
                            } else {
                                selectedWinnerId = participantId
                            }
                        }
                        .listRowBackground(isWinner ? Color.appAccent.opacity(0.12) : Color.cardBackground)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
                
                VStack(spacing: 12) {
                    TextField("Nota opzionale (es. 'Mano fortunata')", text: $roundNote)
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(Color.cardBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cardStroke, lineWidth: 1))
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            // 1. Calculate leaderboard including the current round
                            var tempGame = game
                            let tempRound = Round(
                                roundNumber: game.rounds.count + 1,
                                scores: store.activeRoundScores,
                                winnerId: selectedWinnerId,
                                note: roundNote.isEmpty ? nil : roundNote
                            )
                            tempGame.rounds.append(tempRound)
                            
                            let sorted = tempGame.participantIds.sorted { id1, id2 in
                                let wins1 = tempGame.roundWins(for: id1)
                                let wins2 = tempGame.roundWins(for: id2)
                                if wins1 == wins2 {
                                    return tempGame.totalScore(for: id1) > tempGame.totalScore(for: id2)
                                }
                                return wins1 > wins2
                            }
                            
                            let leaderboard = sorted.enumerated().map { index, id in
                                LeaderboardEntry(
                                    name: getParticipantName(id: id),
                                    wins: tempGame.roundWins(for: id),
                                    score: tempGame.totalScore(for: id),
                                    place: index + 1
                                )
                            }
                            
                            // 2. Trigger game wins celebration overlay & haptics
                            if !leaderboard.isEmpty {
                                activeCelebration = .game(
                                    winnerName: leaderboard[0].name,
                                    wins: leaderboard[0].wins,
                                    score: leaderboard[0].score,
                                    leaderboard: leaderboard
                                )
                                triggerGameWinHaptics()
                            }
                            
                            // 3. Save round and end game
                            store.activeRoundWinnerId = selectedWinnerId
                            store.saveActiveRound(note: roundNote.isEmpty ? nil : roundNote)
                            store.endCurrentGame()
                            
                            dismiss()
                        }) {
                            Text("Termina Partita")
                                .font(.subheadline.bold())
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        Button(action: {
                            triggerHaptic(.notification(.success))
                            
                            // Save active round in store and reset active score accumulators
                            store.activeRoundWinnerId = selectedWinnerId
                            store.saveActiveRound(note: roundNote.isEmpty ? nil : roundNote)
                            
                            dismiss()
                        }) {
                            Text("Nuovo Round")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Fine Round \(game.rounds.count + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let preselected = store.activeRoundWinnerId {
                    selectedWinnerId = preselected
                } else {
                    let activeScores = store.activeRoundScores
                    let maxEntry = activeScores.max(by: { $0.value < $1.value })
                    if let max = maxEntry, max.value > 0 {
                        selectedWinnerId = max.key
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func getParticipantName(id: UUID) -> String {
        return store.players.first(where: { $0.id == id })?.name ?? "Sconosciuto"
    }
}

// MARK: - Round History Row
struct RoundHistoryRow: View {
    let round: Round
    let game: Game
    let store: GameStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Round \(round.roundNumber)")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                if let note = round.note {
                    Text("•  \(note)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if let winnerId = round.winnerId {
                    let winnerName = getParticipantName(id: winnerId)
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.trophyGold)
                            .font(.caption)
                        Text(winnerName)
                            .font(.caption.bold())
                            .foregroundColor(.trophyGold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.trophyGold.opacity(0.12))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.trophyGold.opacity(0.35), lineWidth: 1)
                    )
                }
            }
            
            // Round scores list
            let participants = game.participantIds
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(participants, id: \.self) { partId in
                        let name = getParticipantName(id: partId)
                        let pts = round.scores[partId] ?? 0
                        
                        HStack(spacing: 4) {
                            Text(name)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(pts >= 0 ? "+" : "")\(pts)")
                                .font(.caption.bold())
                                .foregroundColor(pts > 0 ? .scorePositive : (pts < 0 ? .scoreNegative : .secondary))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardStroke, lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                triggerHaptic(.notification(.warning))
                withAnimation {
                    if let index = game.rounds.firstIndex(where: { $0.id == round.id }) {
                        store.deleteRound(at: IndexSet(integer: index))
                    }
                }
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }
    
    private func getParticipantName(id: UUID) -> String {
        return store.players.first(where: { $0.id == id })?.name ?? "Sconosciuto"
    }
}

// MARK: - Celebration Overlay View
struct CelebrationOverlay: View {
    let state: CelebrationState
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var rotate: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                switch state {
                case .none:
                    EmptyView()
                case .round(let name, let score, let roundNumber):
                    roundCelebrationView(name: name, score: score, roundNumber: roundNumber)
                case .game(let name, let wins, let score, let leaderboard):
                    gameCelebrationView(name: name, wins: wins, score: score, leaderboard: leaderboard)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text(buttonText)
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
    
    private var buttonText: String {
        switch state {
        case .none: return ""
        case .round: return "Vedi Riassunto Punti"
        case .game: return "Torna alla Home"
        }
    }
    
    private func roundCelebrationView(name: String, score: Int, roundNumber: Int) -> some View {
        VStack(spacing: 24) {
            // Spinning glow crown
            ZStack {
                Circle()
                    .stroke(Color.trophyGold.opacity(0.12), lineWidth: 4)
                    .frame(width: 150, height: 150)
                
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
                    .frame(width: 136, height: 136)
                    .rotationEffect(.degrees(rotate))
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.trophyGold)
                    .shadow(color: Color.trophyGold.opacity(0.4), radius: 10)
            }
            .scaleEffect(scale)
            
            VStack(spacing: 8) {
                Text("ROUND \(roundNumber) COMPLETATO")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .tracking(2)
                
                Text("VINCITORE DEL ROUND!")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                Text(name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Punti guadagnati: \(score >= 0 ? "+" : "")\(score)")
                    .font(.title3.bold())
                    .foregroundColor(.scorePositive)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, 30)
            .scaleEffect(scale)
        }
    }
    
    private func gameCelebrationView(name: String, wins: Int, score: Int, leaderboard: [LeaderboardEntry]) -> some View {
        VStack(spacing: 20) {
            // Glowing trophy circle
            ZStack {
                Circle()
                    .stroke(Color.trophyGold.opacity(0.15), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.trophyGold)
                    .shadow(color: Color.trophyGold.opacity(0.4), radius: 12)
            }
            .scaleEffect(scale)
            
            VStack(spacing: 4) {
                Text("VINCITORE DELLA PARTITA!")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.trophyGold)
                    .tracking(1)
                
                Text(name)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("\(wins) Round Vinti  •  \(score) Punti Totali")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
            }
            .scaleEffect(scale)
            
            // Leaderboard standings list
            VStack(alignment: .leading, spacing: 10) {
                Text("CLASSIFICA GENERALE")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .padding(.horizontal, 8)
                
                VStack(spacing: 8) {
                    ForEach(leaderboard) { entry in
                        HStack(spacing: 12) {
                            Text("\(entry.place)°")
                                .font(.headline.bold())
                                .foregroundColor(entry.place == 1 ? .trophyGold : .secondary)
                                .frame(width: 30, alignment: .leading)
                            
                            Text(entry.name)
                                .font(.body.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(entry.wins) 🏆")
                                .font(.body.bold())
                                .foregroundColor(entry.place == 1 ? .trophyGold : .secondary)
                            
                            Text("(\(entry.score >= 0 ? "+" : "")\(entry.score))")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(entry.place == 1 ? Color.trophyGold.opacity(0.1) : Color.white.opacity(0.02))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(entry.place == 1 ? Color.trophyGold.opacity(0.3) : Color.cardStroke, lineWidth: 1)
                        )
                    }
                }
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.cardStroke, lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .scaleEffect(scale)
        }
    }
}
