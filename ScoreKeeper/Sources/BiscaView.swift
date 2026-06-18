import SwiftUI

struct BiscaView: View {
    @Environment(GameStore.self) private var store
    
    // Setup state
    @State private var selectedPlayerIds = Set<UUID>()
    @State private var maxLives = 5
    @State private var newPlayerName = ""
    @State private var showingExitAlert = false
    @State private var showingResetAlert = false
    
    var body: some View {
        Group {
            if let game = store.biscaGame, game.isActive {
                activeGameView(game)
            } else {
                setupGameView
            }
        }
        .background(Color.appBackground)
        .navigationTitle("Bisca")
        .alert("Termina Bisca?", isPresented: $showingExitAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Termina", role: .destructive) {
                triggerHaptic(.notification(.error))
                store.endBiscaGame()
            }
        } message: {
            Text("Sei sicuro di voler terminare il gioco Bisca corrente? I dati andranno persi.")
        }
        .alert("Azzera Vite?", isPresented: $showingResetAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Ripristina", role: .destructive) {
                triggerHaptic(.notification(.warning))
                store.resetBiscaGame()
            }
        } message: {
            Text("Sei sicuro di voler ripristinare le vite di tutti i giocatori al massimo?")
        }
    }
    
    // MARK: - SETUP GAME VIEW
    private var setupGameView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vite di partenza per giocatore:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach([3, 5, 7, 10], id: \.self) { val in
                            Button(action: {
                                triggerHaptic(.impact(.light))
                                maxLives = val
                            }) {
                                Text("\(val)")
                                    .font(.title3.bold())
                                    .foregroundColor(maxLives == val ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(maxLives == val ? Color.appAccent : Color.cardBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(maxLives == val ? Color.appAccent : Color.cardStroke, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Stepper(value: $maxLives, in: 1...99) {
                        HStack {
                            Text("Personalizzate:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(maxLives)")
                                .font(.body.bold())
                                .foregroundColor(.appAccent)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Impostazioni Vite")
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                HStack {
                    TextField("Nome Giocatore Rapido", text: $newPlayerName)
                        .textInputAutocapitalization(.words)
                        .foregroundColor(.primary)
                    
                    Button("Aggiungi") {
                        if !newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let newPlayer = store.addPlayer(name: newPlayerName)
                            selectedPlayerIds.insert(newPlayer.id)
                            newPlayerName = ""
                            triggerHaptic(.notification(.success))
                        }
                    }
                    .foregroundColor(.appAccent)
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(selectedPlayerIds.contains(player.id) ? .appAccent : .secondary)
                            Text(player.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedPlayerIds.contains(player.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appAccent)
                                    .fontWeight(.bold)
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
                    }
                }
            } header: {
                Text("Seleziona Partecipanti (Min. 2)")
            }
            .listRowBackground(Color.cardBackground)
            
            Section {
                Button(action: {
                    let selected = store.players.filter { selectedPlayerIds.contains($0.id) }
                    store.startBiscaGame(maxLives: maxLives, players: selected)
                    triggerHaptic(.notification(.success))
                }) {
                    Text("Inizia Bisca")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .disabled(selectedPlayerIds.count < 2)
                .listRowBackground(selectedPlayerIds.count >= 2 ? Color.appAccent : Color.cardBackground.opacity(0.5))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
    }
    
    // MARK: - ACTIVE GAME VIEW
    private func activeGameView(_ game: BiscaGame) -> some View {
        VStack(spacing: 0) {
            // Stats Header
            let activeCount = game.players.filter { !$0.isEliminated }.count
            let totalCount = game.players.count
            
            HStack {
                Text("Giocatori in vita: \(activeCount) / \(totalCount)")
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
                
                Text("Vite Max: \(game.maxLives)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            // Check for winner
            let survivors = game.players.filter { !$0.isEliminated }
            
            if survivors.count == 1, totalCount > 1 {
                // We have a winner!
                let winner = survivors[0]
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer(minLength: 40)
                        
                        // Winner trophy card
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color.trophyGold.opacity(0.15), lineWidth: 4)
                                    .frame(width: 140, height: 140)
                                
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.trophyGold)
                                    .shadow(color: Color.trophyGold.opacity(0.4), radius: 12)
                            }
                            
                            VStack(spacing: 8) {
                                Text("VINCITORE DELLA BISCA!")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(.trophyGold)
                                    .tracking(2)
                                
                                Text(winner.name)
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Text("Sopravvissuto con \(winner.lives) \(winner.lives == 1 ? "vita" : "vite")!")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 40)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .background(Color.cardBackground)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.trophyGold.opacity(0.4), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        
                        // Bottom buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                triggerHaptic(.notification(.success))
                                store.resetBiscaGame()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Gioca di nuovo")
                                }
                                .frame(maxWidth: .infinity)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.appAccent)
                                .cornerRadius(14)
                            }
                            .padding(.horizontal, 40)
                            
                            Button(action: {
                                triggerHaptic(.impact(.medium))
                                store.endBiscaGame()
                            }) {
                                Text("Termina Bisca")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            } else {
                // Game in progress list
                // Sort players: active at the top, eliminated at the bottom, keeping original order within groups
                let sortedPlayers = game.players.enumerated().sorted { el1, el2 in
                    let p1 = el1.element
                    let p2 = el2.element
                    if !p1.isEliminated && p2.isEliminated {
                        return true
                    } else if p1.isEliminated && !p2.isEliminated {
                        return false
                    } else {
                        return el1.offset < el2.offset
                    }
                }.map { $0.element }
                
                List {
                    ForEach(sortedPlayers) { player in
                        BiscaPlayerCard(
                            player: player,
                            maxLives: game.maxLives,
                            alivePlayers: game.players.filter { !$0.isEliminated },
                            onIncrement: {
                                triggerHaptic(.impact(.light))
                                store.updateBiscaLives(playerId: player.id, by: 1)
                            },
                            onDecrement: {
                                let newLives = player.lives - 1
                                if newLives <= 0 {
                                    triggerHaptic(.notification(.error))
                                } else {
                                    triggerHaptic(.impact(.light))
                                }
                                store.updateBiscaLives(playerId: player.id, by: -1)
                            },
                            onResurrect: { donor in
                                triggerHaptic(.notification(.success))
                                store.donateBiscaLife(from: donor.id, to: player.id)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                // Bottom control buttons for active game
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
                        .padding()
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
                        .padding()
                        .background(Color.scoreNegative)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.appBackground.opacity(0.85))
            }
        }
    }
}

// MARK: - BISCA PLAYER CARD COMPONENT
struct BiscaPlayerCard: View {
    let player: BiscaPlayer
    let maxLives: Int
    let alivePlayers: [BiscaPlayer]
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onResurrect: (BiscaPlayer) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                // Name (with strikethrough if eliminated)
                if player.isEliminated {
                    Text(player.name)
                        .font(.title3.bold())
                        .foregroundColor(.scoreNegative)
                        .strikethrough(true, color: .scoreNegative)
                        .lineLimit(1)
                } else {
                    Text(player.name)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                // Hearts visual representation
                if player.isEliminated {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.slash.fill")
                            .font(.caption)
                            .foregroundColor(.scoreNegative)
                        Text("ELIMINATO")
                            .font(.caption2.bold())
                            .foregroundColor(.scoreNegative)
                    }
                } else {
                    if player.lives <= 15 {
                        HStack(spacing: 3) {
                            ForEach(0..<max(maxLives, player.lives), id: \.self) { index in
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(index < player.lives ? .scoreNegative : Color.white.opacity(0.12))
                            }
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.scoreNegative)
                            Text("Vite: \(player.lives) / \(maxLives)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Increment/Decrement controls
            HStack(spacing: 14) {
                if player.isEliminated {
                    if alivePlayers.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.slash")
                            Text("No Donatori")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    } else {
                        Menu {
                            ForEach(alivePlayers) { donor in
                                Button(action: {
                                    onResurrect(donor)
                                }) {
                                    Label("Prendi da \(donor.name) (\(donor.lives) \(donor.lives == 1 ? "vita" : "vite"))", systemName: "heart.fill")
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.text.square")
                                Text("Resuscita")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.scorePositive)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.scorePositive.opacity(0.12))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.scorePositive.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // Regular live controls
                    Button(action: onDecrement) {
                        Image(systemName: "minus")
                            .font(.title3.bold())
                            .foregroundColor(.scoreNegative)
                            .frame(width: 40, height: 40)
                            .background(Color.scoreNegative.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.scoreNegative.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(player.lives)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(width: 40)
                        .multilineTextAlignment(.center)
                    
                    Button(action: onIncrement) {
                        Image(systemName: "plus")
                            .font(.title3.bold())
                            .foregroundColor(.scorePositive)
                            .frame(width: 40, height: 40)
                            .background(Color.scorePositive.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.scorePositive.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(player.isEliminated ? Color.scoreNegative.opacity(0.05) : Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(player.isEliminated ? Color.scoreNegative.opacity(0.2) : Color.cardStroke, lineWidth: 1)
        )
    }
}
