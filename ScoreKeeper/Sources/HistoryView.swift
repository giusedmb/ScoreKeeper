import SwiftUI

struct HistoryView: View {
    @Environment(GameStore.self) private var store
    
    var body: some View {
        List {
            if store.gamesHistory.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Cronologia Vuota")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Le partite terminate e salvate appariranno qui.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 250)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(store.gamesHistory) { game in
                    HistoryGameRow(game: game, store: store)
                        .listRowBackground(Color.cardBackground)
                        .padding(.vertical, 4)
                }
                .onDelete(perform: deleteHistoryGame)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Cronologia")
    }
    
    private func deleteHistoryGame(at offsets: IndexSet) {
        triggerHaptic(.notification(.warning))
        var history = store.gamesHistory
        history.remove(atOffsets: offsets)
        store.gamesHistory = history
        store.saveAll()
    }
}

struct HistoryGameRow: View {
    let game: Game
    let store: GameStore
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Partita")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(game.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                triggerHaptic(.impact(.light))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
            
            // Leaderboard summary sorted by round wins first, then total score
            let sortedParticipants = game.participantIds.sorted { id1, id2 in
                let wins1 = game.roundWins(for: id1)
                let wins2 = game.roundWins(for: id2)
                if wins1 == wins2 {
                    return game.totalScore(for: id1) > game.totalScore(for: id2)
                }
                return wins1 > wins2
            }
            
            if !sortedParticipants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<sortedParticipants.count, id: \.self) { castIdIndex in
                            let partId = sortedParticipants[castIdIndex]
                            let name = getParticipantName(id: partId)
                            let total = game.totalScore(for: partId)
                            let wins = game.roundWins(for: partId)
                            let isWinner = castIdIndex == 0
                            
                            HStack(spacing: 4) {
                                if isWinner {
                                    Image(systemName: "trophy.fill")
                                        .font(.caption2)
                                        .foregroundColor(.trophyGold)
                                }
                                Text(name)
                                    .font(.caption.bold())
                                    .foregroundColor(isWinner ? .trophyGold : .primary)
                                Text("\(wins)🏆 (\(total >= 0 ? "+" : "")\(total))")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(isWinner ? .trophyGold.opacity(0.8) : .secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isWinner ? Color.trophyGold.opacity(0.12) : Color.white.opacity(0.04))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isWinner ? Color.trophyGold.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            
            // Details when expanded
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .background(Color.cardStroke)
                        .padding(.vertical, 4)
                    
                    Text("Dettagli dei Round:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    if game.rounds.isEmpty {
                        Text("Nessun round registrato.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(game.rounds) { round in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("R\(round.roundNumber)")
                                            .font(.caption.bold())
                                            .foregroundColor(.primary)
                                        
                                        if let note = round.note {
                                            Text("• \(note)")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if let winnerId = round.winnerId {
                                            HStack(spacing: 2) {
                                                Image(systemName: "crown.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.trophyGold)
                                                Text(getParticipantName(id: winnerId))
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.trophyGold)
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.trophyGold.opacity(0.1))
                                            .cornerRadius(4)
                                        }
                                    }
                                    
                                    HStack(spacing: 8) {
                                        ForEach(game.participantIds, id: \.self) { partId in
                                            let name = getParticipantName(id: partId)
                                            let score = round.scores[partId] ?? 0
                                            Text("\(name): \(score >= 0 ? "+" : "")\(score)")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(score > 0 ? .scorePositive : (score < 0 ? .scoreNegative : .secondary))
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color.white.opacity(0.02))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cardStroke, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getParticipantName(id: UUID) -> String {
        return store.players.first(where: { $0.id == id })?.name ?? "Sconosciuto"
    }
}
