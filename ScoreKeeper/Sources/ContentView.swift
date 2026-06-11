import SwiftUI

struct ContentView: View {
    @Environment(GameStore.self) private var store
    @State private var selectedTab = 0
    @State private var showingNewGame = false
    @State private var showingAddPlayer = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                GameView(showingNewGame: $showingNewGame, showingAddPlayer: $showingAddPlayer)
                    .background(Color.appBackground)
            }
            .tabItem {
                Label("Partita", systemImage: "play.circle.fill")
            }
            .tag(0)
            
            NavigationStack {
                BiscaView()
                    .background(Color.appBackground)
            }
            .tabItem {
                Label("Bisca", systemImage: "suit.spade.fill")
            }
            .tag(1)
            
            NavigationStack {
                CiccopaoloView()
                    .background(Color.appBackground)
            }
            .tabItem {
                Label("Ciccopaolo", systemImage: "suit.club.fill")
            }
            .tag(2)
            
            NavigationStack {
                HistoryView()
                    .background(Color.appBackground)
            }
            .tabItem {
                Label("Cronologia", systemImage: "clock.fill")
            }
            .tag(3)
        }
        .tint(.appAccent)
        .sheet(isPresented: $showingNewGame) {
            NewGameView()
        }
        .sheet(isPresented: $showingAddPlayer) {
            QuickAddPlayerView()
        }
    }
}

// Quick Add Player Sheet
struct QuickAddPlayerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome Giocatore", text: $name)
                        .textInputAutocapitalization(.words)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        if !name.isEmpty {
                            store.addPlayer(name: name)
                            name = ""
                            dismiss()
                        }
                    }) {
                        Text("Salva Giocatore")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .disabled(name.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .tint(.appAccent)
                } header: {
                    Text("Nuovo Giocatore")
                }
                .listRowBackground(Color.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Aggiungi Giocatore")
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
