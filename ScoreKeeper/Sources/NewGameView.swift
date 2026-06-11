import SwiftUI

struct NewGameView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedIndividualIds = Set<UUID>()
    @State private var quickPlayerName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Nome Nuovo Giocatore", text: $quickPlayerName)
                            .textInputAutocapitalization(.words)
                            .foregroundColor(.primary)
                        
                        Button("Aggiungi") {
                            if !quickPlayerName.isEmpty {
                                let newPlayer = store.addPlayer(name: quickPlayerName)
                                selectedIndividualIds.insert(newPlayer.id)
                                quickPlayerName = ""
                                triggerHaptic(.notification(.success))
                            }
                        }
                        .foregroundColor(.appAccent)
                        .disabled(quickPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Aggiungi Giocatore Rapido")
                }
                .listRowBackground(Color.cardBackground)
                
                Section {
                    if store.players.isEmpty {
                        Text("Nessun giocatore salvato. Aggiungine uno sopra per iniziare.")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(store.players) { player in
                            HStack {
                                Image(systemName: "person.crop.circle")
                                    .foregroundColor(selectedIndividualIds.contains(player.id) ? .appAccent : .secondary)
                                Text(player.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedIndividualIds.contains(player.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.appAccent)
                                        .fontWeight(.bold)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                triggerHaptic(.impact(.light))
                                if selectedIndividualIds.contains(player.id) {
                                    selectedIndividualIds.remove(player.id)
                                } else {
                                    selectedIndividualIds.insert(player.id)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Seleziona Giocatori (Min. 2)")
                }
                .listRowBackground(Color.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Nuova Partita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Inizia") {
                        store.startNewGame(participantIds: Array(selectedIndividualIds))
                        triggerHaptic(.notification(.success))
                        dismiss()
                    }
                    .disabled(selectedIndividualIds.count < 2)
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
