import SwiftUI

public struct PrimieraPlayerInfo: Identifiable, Equatable {
    public let id: UUID
    public let name: String
    
    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

enum PrimieraSuit: String, CaseIterable, Identifiable {
    case denari = "Denari"
    case coppe = "Coppe"
    case spade = "Spade"
    case bastoni = "Bastoni"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .denari: return "🪙"
        case .coppe: return "🏆"
        case .spade: return "⚔️"
        case .bastoni: return "🪵"
        }
    }
    
    var color: Color {
        switch self {
        case .denari: return Color(red: 1.0, green: 0.73, blue: 0.0) // Gold/Yellow
        case .coppe: return Color(red: 1.0, green: 0.23, blue: 0.18) // Red
        case .spade: return Color(red: 0.0, green: 0.48, blue: 1.0) // Blue
        case .bastoni: return Color(red: 0.18, green: 0.8, blue: 0.44) // Green
        }
    }
}

enum PrimieraCardRank: Int, CaseIterable, Identifiable {
    case asso = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case fante = 8
    case cavallo = 9
    case re = 10
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        switch self {
        case .asso: return "Asso"
        case .fante: return "Fante"
        case .cavallo: return "Cavallo"
        case .re: return "Re"
        default: return "\(self.rawValue)"
        }
    }
    
    var shortName: String {
        switch self {
        case .asso: return "1"
        case .fante: return "8"
        case .cavallo: return "9"
        case .re: return "10"
        default: return "\(self.rawValue)"
        }
    }
    
    var primieraPoints: Int {
        switch self {
        case .seven: return 21
        case .six: return 18
        case .asso: return 16
        case .five: return 15
        case .four: return 14
        case .three: return 13
        case .two: return 12
        case .fante, .cavallo, .re: return 10
        }
    }
}

public struct PrimieraCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let players: [PrimieraPlayerInfo]
    let onApplyWinner: (UUID?) -> Void
    
    @State private var selectedPlayerId: UUID
    // Selections format: [PlayerID: [Suit: SelectedCardRank]]
    @State private var selections: [UUID: [PrimieraSuit: PrimieraCardRank]] = [:]
    @State private var lastClickedInfo: String? = nil
    
    public init(
        players: [PrimieraPlayerInfo],
        currentWinnerId: UUID? = nil,
        settebelloWinnerId: UUID? = nil,
        onApplyWinner: @escaping (UUID?) -> Void
    ) {
        self.players = players
        self.onApplyWinner = onApplyWinner
        
        // Default select the first player (or current winner if set)
        if let currentWinnerId = currentWinnerId, players.contains(where: { $0.id == currentWinnerId }) {
            self._selectedPlayerId = State(initialValue: currentWinnerId)
        } else {
            self._selectedPlayerId = State(initialValue: players.first?.id ?? UUID())
        }
        
        // Pre-fill Settebello (7 of Denari) if the player won it
        var initialSelections: [UUID: [PrimieraSuit: PrimieraCardRank]] = [:]
        if let settebelloWinnerId = settebelloWinnerId, players.contains(where: { $0.id == settebelloWinnerId }) {
            initialSelections[settebelloWinnerId] = [.denari: .seven]
        }
        self._selections = State(initialValue: initialSelections)
    }
    
    private func getScore(for playerId: UUID) -> Int {
        let playerSelections = selections[playerId] ?? [:]
        return playerSelections.values.reduce(0) { $0 + $1.primieraPoints }
    }
    
    private var winningPlayer: PrimieraPlayerInfo? {
        guard players.count == 2 else { return nil }
        let s0 = getScore(for: players[0].id)
        let s1 = getScore(for: players[1].id)
        if s0 > s1 { return players[0] }
        if s1 > s0 { return players[1] }
        return nil
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Info Banner
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.appAccent)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calcolo della Primiera")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        Text("Seleziona la carta più alta che hai per ciascun seme.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.cardBackground.opacity(0.4))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.cardStroke),
                    alignment: .bottom
                )
                
                // Player Selection Cards
                HStack(spacing: 12) {
                    ForEach(players) { player in
                        let isSelected = selectedPlayerId == player.id
                        let score = getScore(for: player.id)
                        
                        Button(action: {
                            triggerHaptic(.impact(.light))
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPlayerId = player.id
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(player.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(isSelected ? .white : .secondary)
                                    .lineLimit(1)
                                
                                Text("\(score) pt")
                                    .font(.title2.bold())
                                    .foregroundColor(isSelected ? .appAccent : .primary)
                                
                                // Suit indicators
                                HStack(spacing: 4) {
                                    ForEach(PrimieraSuit.allCases) { suit in
                                        let hasCard = selections[player.id]?[suit] != nil
                                        Text(suit.icon)
                                            .font(.caption2)
                                            .grayscale(hasCard ? 0.0 : 1.0)
                                            .opacity(hasCard ? 1.0 : 0.25)
                                    }
                                }
                                .padding(.top, 2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? Color.appAccent.opacity(0.1) : Color.cardBackground)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(isSelected ? Color.appAccent : Color.cardStroke, lineWidth: isSelected ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                
                // Last Clicked Card Value Toast Info
                if let info = lastClickedInfo {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.trophyGold)
                            .font(.caption)
                        Text(info)
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cardBackground)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.cardStroke, lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .scale))
                    .padding(.bottom, 10)
                }
                
                // Scrollable Grid of Suit Rows
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(PrimieraSuit.allCases) { suit in
                            // Find which ranks are selected by other players for this suit
                            let takenRanks = Set(
                                selections.filter { $0.key != selectedPlayerId }
                                          .compactMap { $0.value[suit] }
                            )
                            
                            PrimieraSuitSelectorView(
                                suit: suit,
                                selectedRank: selections[selectedPlayerId]?[suit],
                                takenRanks: takenRanks,
                                onSelect: { rank in
                                    triggerHaptic(.impact(.light))
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if let rank = rank {
                                            selections[selectedPlayerId, default: [:]][suit] = rank
                                            lastClickedInfo = "Selezionato: \(rank.displayName) di \(suit.rawValue) (\(rank.primieraPoints) pt)"
                                        } else {
                                            selections[selectedPlayerId, default: [:]].removeValue(forKey: suit)
                                            lastClickedInfo = "Rimosso: \(suit.rawValue)"
                                        }
                                    }
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                // Footer
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PUNTEGGIO DI PRIMIERA")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                                .tracking(1)
                            
                            HStack(spacing: 8) {
                                ForEach(players) { player in
                                    let score = getScore(for: player.id)
                                    Text("\(player.name): \(score)")
                                        .font(.subheadline.bold())
                                        .foregroundColor(selectedPlayerId == player.id ? .appAccent : .primary)
                                    if player != players.last {
                                        Text("•")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        Spacer()
                        
                        // Result message
                        if let winner = winningPlayer {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.trophyGold)
                                Text("Vince \(winner.name)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.trophyGold)
                            }
                        } else {
                            Text("Pareggio")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        let winner = winningPlayer
                        onApplyWinner(winner?.id)
                        dismiss()
                    }) {
                        Text(winningPlayer == nil ? "Applica Pareggio / Nessuno" : "Applica Vincitore: \(winningPlayer!.name)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.scorePositive)
                            .cornerRadius(12)
                            .shadow(color: Color.scorePositive.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 14)
                .background(Color.cardBackground)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.cardStroke),
                    alignment: .top
                )
            }
            .background(Color.appBackground)
            .navigationTitle("Calcolatore Primiera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SUIT SELECTOR GRID VIEW
struct PrimieraSuitSelectorView: View {
    let suit: PrimieraSuit
    let selectedRank: PrimieraCardRank?
    let takenRanks: Set<PrimieraCardRank>
    let onSelect: (PrimieraCardRank?) -> Void
    
    // Ordered by Priority (7, 6, Asso, then 5, 4, 3, 2, then Figures)
    private let row1: [PrimieraCardRank] = [.seven, .six, .asso]
    private let row2: [PrimieraCardRank] = [.five, .four, .three, .two]
    private let row3: [PrimieraCardRank] = [.fante, .cavallo, .re]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Suit Header
            HStack {
                HStack(spacing: 6) {
                    Text(suit.icon)
                        .font(.title3)
                    Text(suit.rawValue)
                        .font(.headline.bold())
                        .foregroundColor(suit.color)
                }
                
                Spacer()
                
                if let selectedRank = selectedRank {
                    Text("\(selectedRank.displayName) (\(selectedRank.primieraPoints) pt)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(suit.color)
                        .cornerRadius(6)
                } else {
                    Text("Nessuna")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 4)
            
            // Grid of ranks
            VStack(spacing: 8) {
                // Row 1 (High priority: 7, 6, Asso)
                HStack(spacing: 6) {
                    ForEach(row1) { rank in
                        rankButton(rank, isLarge: true, isTaken: takenRanks.contains(rank))
                    }
                }
                
                // Row 2 (Medium priority: 5, 4, 3, 2)
                HStack(spacing: 6) {
                    ForEach(row2) { rank in
                        rankButton(rank, isLarge: false, isTaken: takenRanks.contains(rank))
                    }
                }
                
                // Row 3 (Figures + Nessuna/Cancella)
                HStack(spacing: 6) {
                    ForEach(row3) { rank in
                        rankButton(rank, isLarge: false, isTaken: takenRanks.contains(rank))
                    }
                    
                    // "Nessuna" card option
                    Button(action: {
                        onSelect(nil)
                    }) {
                        VStack(spacing: 2) {
                            Text("Cancella")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(selectedRank == nil ? .secondary : .secondary.opacity(0.6))
                            Text("0 pt")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(selectedRank == nil ? Color.secondary.opacity(0.12) : Color.white.opacity(0.03))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedRank == nil ? Color.secondary.opacity(0.4) : Color.cardStroke, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(selectedRank != nil ? suit.color.opacity(0.3) : Color.cardStroke, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func rankButton(_ rank: PrimieraCardRank, isLarge: Bool, isTaken: Bool) -> some View {
        let isSelected = selectedRank == rank
        
        Button(action: {
            onSelect(rank)
        }) {
            VStack(spacing: isLarge ? 2 : 1) {
                Text(rank.displayName)
                    .font(.system(size: isLarge ? 13 : 11, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : (isTaken ? .secondary.opacity(0.5) : .primary))
                Text("\(rank.primieraPoints) pt")
                    .font(.system(size: isLarge ? 10 : 8, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : (isTaken ? .secondary.opacity(0.3) : .secondary))
            }
            .frame(maxWidth: .infinity)
            .frame(height: isLarge ? 48 : 38)
            .background(
                isSelected ?
                suit.color :
                (isTaken ? Color.white.opacity(0.01) : (isLarge ? suit.color.opacity(0.08) : Color.white.opacity(0.03)))
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? suit.color : (isLarge && !isTaken ? suit.color.opacity(0.2) : Color.cardStroke.opacity(isTaken ? 0.3 : 1.0)), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isTaken)
        .opacity(isTaken ? 0.4 : 1.0)
    }
}
