import SwiftUI

struct GamesListView: View {
    @Environment(GameStore.self) private var store
    
    // Binding parameters to pass down to GameView sheets
    @State private var showingNewGame = false
    @State private var showingAddPlayer = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header banner
                VStack(alignment: .leading, spacing: 8) {
                    Text("SCEGLI UN GIOCO")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                    
                    Text("Score Tracker")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // Games Grid/List
                VStack(spacing: 16) {
                    // SCOPA
                    let isScopaActive = store.scopaGame?.isActive == true
                    NavigationLink(destination: ScopaView().background(Color.appBackground)) {
                        GameCard(
                            title: "Scopa",
                            subtitle: "Carte, Primiera, Settebello, Denari, Scope.",
                            icon: "suit.diamond.fill",
                            color: Color.orange,
                            isActive: isScopaActive
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // BRISCOLA
                    let isBriscolaActive = store.briscolaGame?.isActive == true
                    NavigationLink(destination: BriscolaView().background(Color.appBackground)) {
                        GameCard(
                            title: "Briscola",
                            subtitle: "Traccia i punti della smazzata (120 pt totali).",
                            icon: "suit.heart.fill",
                            color: Color.red,
                            isActive: isBriscolaActive
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // BISCA
                    let isBiscaActive = store.biscaGame?.isActive == true
                    NavigationLink(destination: BiscaView().background(Color.appBackground)) {
                        GameCard(
                            title: "Bisca",
                            subtitle: "Gioco ad eliminazione a vite. L'ultimo sopravvissuto vince.",
                            icon: "suit.spade.fill",
                            color: Color.purple,
                            isActive: isBiscaActive
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // CICCOPAOLO
                    let isCiccopaoloActive = store.ciccopaoloGame?.isActive == true
                    NavigationLink(destination: CiccopaoloView().background(Color.appBackground)) {
                        GameCard(
                            title: "Ciccopaolo",
                            subtitle: "Variante Scopa con calcolo smazzate alla meglio di 3.",
                            icon: "suit.club.fill",
                            color: Color.green,
                            isActive: isCiccopaoloActive
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // SCALA 40
                    let isScalaQuarantaActive = store.scalaQuarantaGame?.isActive == true
                    NavigationLink(destination: ScalaQuarantaView().background(Color.appBackground)) {
                        GameCard(
                            title: "Scala 40",
                            subtitle: "Traccia i punti di Scala Quaranta con calcolatore di carte in mano e rientri.",
                            icon: "square.stack.3d.up.fill",
                            color: Color.teal,
                            isActive: isScalaQuarantaActive
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // STANDARD POINTS
                    let isStandardActive = store.currentGame != nil
                    NavigationLink(destination: GameView(showingNewGame: $showingNewGame, showingAddPlayer: $showingAddPlayer).background(Color.appBackground)) {
                        GameCard(
                            title: "Punti (Standard)",
                            subtitle: "Calcolo generico dei punti a round per qualsiasi gioco.",
                            icon: "list.bullet.circle.fill",
                            color: Color.blue,
                            isActive: isStandardActive
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Active player overview quick shortcut
                VStack(alignment: .leading, spacing: 12) {
                    Text("GIOCATORI REGISTRATI")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                        .padding(.horizontal)
                    
                    if store.players.isEmpty {
                        HStack {
                            Text("Nessun giocatore registrato.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Aggiungi") {
                                triggerHaptic(.impact(.light))
                                showingAddPlayer = true
                            }
                            .font(.footnote.bold())
                            .foregroundColor(.appAccent)
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardStroke, lineWidth: 1))
                        .padding(.horizontal)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(store.players) { player in
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.crop.circle")
                                            .foregroundColor(.appAccent)
                                        Text(player.name)
                                            .font(.footnote.bold())
                                            .foregroundColor(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.cardBackground)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cardStroke, lineWidth: 1))
                                }
                                
                                Button(action: {
                                    triggerHaptic(.impact(.light))
                                    showingAddPlayer = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("Nuovo")
                                    }
                                    .font(.footnote.bold())
                                    .foregroundColor(.appAccent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.appAccent.opacity(0.12))
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appAccent.opacity(0.3), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 16)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showingNewGame) {
            NewGameView()
        }
        .sheet(isPresented: $showingAddPlayer) {
            QuickAddPlayerView()
        }
    }
}

// MARK: - GAME CARD COMPONENT
struct GameCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isActive: Bool
    
    @State private var pulse = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon frame
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if isActive {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.scorePositive)
                                .frame(width: 6, height: 6)
                                .opacity(pulse ? 0.3 : 1.0)
                            
                            Text("ATTIVO")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(Color.scorePositive)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.scorePositive.opacity(0.12))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.scorePositive.opacity(0.3), lineWidth: 1))
                    }
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary.opacity(0.5))
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isActive ? color.opacity(0.4) : Color.cardStroke, lineWidth: 1)
        )
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}
