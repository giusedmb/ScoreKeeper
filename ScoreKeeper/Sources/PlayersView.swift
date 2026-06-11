import SwiftUI

struct PlayersView: View {
    @Environment(GameStore.self) private var store
    @State private var newPlayerName = ""
    
    var body: some View {
        List {
            // Section 1: Add Player
            Section {
                HStack {
                    TextField("Nome Giocatore", text: $newPlayerName)
                        .textInputAutocapitalization(.words)
                        .foregroundColor(.primary)
                    
                    Button(action: addPlayer) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.appAccent)
                    }
                    .disabled(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("Aggiungi Giocatore")
            }
            .listRowBackground(Color.cardBackground)
            
            // Section 2: Individual Players list
            Section {
                if store.players.isEmpty {
                    Text("Nessun giocatore salvato. Aggiungine uno sopra.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .padding(.vertical, 8)
                } else {
                    ForEach(store.players) { player in
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.appAccent)
                            Text(player.name)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .onDelete(perform: deletePlayer)
                }
            } header: {
                Text("Giocatori Salvati (\(store.players.count))")
            }
            .listRowBackground(Color.cardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Giocatori")
    }
    
    private func addPlayer() {
        triggerHaptic(.notification(.success))
        store.addPlayer(name: newPlayerName)
        newPlayerName = ""
    }
    
    private func deletePlayer(at offsets: IndexSet) {
        triggerHaptic(.notification(.warning))
        store.deletePlayer(at: offsets)
    }
}
