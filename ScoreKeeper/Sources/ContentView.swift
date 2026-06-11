import SwiftUI

struct ContentView: View {
    @Environment(GameStore.self) private var store
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                GamesListView()
                    .background(Color.appBackground)
            }
            .tabItem {
                Label("Giochi", systemImage: "gamecontroller.fill")
            }
            .tag(0)
            
            NavigationStack {
                HistoryView()
                    .background(Color.appBackground)
            }
            .tabItem {
                Label("Cronologia", systemImage: "clock.fill")
            }
            .tag(1)
        }
        .tint(.appAccent)
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
