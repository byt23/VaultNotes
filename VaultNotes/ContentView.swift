//
//  ContentView.swift
//  VaultNotes
//
//  Created by BERKAY TURAN on 19.04.2026.
//

import SwiftUI
import SwiftData
import LocalAuthentication

// MARK: - Model
@Model
class SifreliNot {
    var baslik: String
    var icerik: String
    var ozelSifre: String
    var tarih: Date
    var kilitliMi: Bool
    
    init(baslik: String, icerik: String, ozelSifre: String) {
        self.baslik = baslik
        self.icerik = icerik
        self.ozelSifre = ozelSifre
        self.tarih = Date.now
        self.kilitliMi = true
    }
}

// MARK: - Ana Ekran
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Query(sort: \SifreliNot.tarih, order: .reverse) private var notlar: [SifreliNot]
    
    @State private var eklemeModu = false
    @State private var yeniBaslik = ""
    @State private var yeniIcerik = ""
    @State private var yeniOzelSifre = ""
    
    @State private var sifreCheckModu = false
    @State private var silmeOnayModu = false
    @State private var girilenSifre = ""
    @State private var hedefNot: SifreliNot?
    @State private var duzenlenecekNot: SifreliNot?

    var body: some View {
        NavigationStack {
            List {
                ForEach(notlar) { not in
                    HStack {
                        Button { dogrulamaBaslat(not: not) } label: {
                            HStack {
                                Image(systemName: not.kilitliMi ? "lock.fill" : "lock.open.fill")
                                    .foregroundColor(not.kilitliMi ? .red : .green)
                                VStack(alignment: .leading) {
                                    Text(not.baslik).font(.headline)
                                    Text(not.kilitliMi ? "••••••••" : not.icerik)
                                        .font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        if !not.kilitliMi {
                            Button { duzenlenecekNot = not } label: {
                                Image(systemName: "pencil.circle").foregroundColor(.blue)
                            }
                        }
                    }
                    // Standart onDelete yerine swipe actions ile özel silme
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            hedefNot = not
                            silmeOnayModu = true
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("VaultNotes")
            .toolbar {
                Button { eklemeModu = true } label: { Image(systemName: "plus.circle.fill") }
            }
            // Görüntüleme İçin Şifre Sor
            .alert("Görüntüleme Şifresi", isPresented: $sifreCheckModu) {
                SecureField("Şifre", text: $girilenSifre)
                Button("Aç") { sifreKontrolEt() }
                Button("İptal", role: .cancel) { girilenSifre = "" }
            }
            // Silme İçin Şifre Sor
            .alert("Silme İşlemini Onayla", isPresented: $silmeOnayModu) {
                SecureField("Bu notun şifresini girin", text: $girilenSifre)
                Button("Sil", role: .destructive) { guvenliSil() }
                Button("Vazgeç", role: .cancel) { girilenSifre = "" }
            } message: {
                Text("Notu silmek için geçerli şifreyi girmelisiniz.")
            }
            .sheet(isPresented: $eklemeModu) {
                eklemeSayfasi
            }
            .sheet(item: $duzenlenecekNot) { not in
                EditNoteView(not: not)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                for not in notlar { not.kilitliMi = true }
            }
        }
    }

    // MARK: - Mantık Fonksiyonları
    func dogrulamaBaslat(not: SifreliNot) {
        if !not.kilitliMi { withAnimation { not.kilitliMi = true }; return }
        
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Kilidi Aç") { success, _ in
                if success {
                    DispatchQueue.main.async { withAnimation { not.kilitliMi = false } }
                } else {
                    DispatchQueue.main.async { hedefNot = not; sifreCheckModu = true }
                }
            }
        } else {
            hedefNot = not; sifreCheckModu = true
        }
    }

    func sifreKontrolEt() {
        if girilenSifre == hedefNot?.ozelSifre {
            withAnimation { hedefNot?.kilitliMi = false }
        }
        girilenSifre = ""
    }

    func guvenliSil() {
        if let not = hedefNot, girilenSifre == not.ozelSifre {
            modelContext.delete(not)
            try? modelContext.save()
        }
        girilenSifre = ""
        hedefNot = nil
    }

    func ekle() {
        let yeni = SifreliNot(baslik: yeniBaslik, icerik: yeniIcerik, ozelSifre: yeniOzelSifre)
        modelContext.insert(yeni)
        try? modelContext.save()
        yeniBaslik = ""; yeniIcerik = ""; yeniOzelSifre = ""; eklemeModu = false
    }

    var eklemeSayfasi: some View {
        NavigationStack {
            Form {
                Section("Not") {
                    TextField("Başlık", text: $yeniBaslik)
                    TextField("İçerik", text: $yeniIcerik)
                }
                Section("Şifre") {
                    SecureField("Nota Özel Şifre", text: $yeniOzelSifre)
                }
            }
            .navigationTitle("Yeni Kasa Notu")
            .toolbar {
                Button("Ekle") { ekle() }.disabled(yeniBaslik.isEmpty || yeniOzelSifre.isEmpty)
            }
        }
    }
}

// MARK: - Düzenleme Görünümü (Çift Doğrulamalı)
struct EditNoteView: View {
    @Bindable var not: SifreliNot
    @Environment(\.dismiss) var dismiss
    
    @State private var eskiSifreGiris = ""
    @State private var yeniSifreGiris = ""
    @State private var hataMesaji = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("İçerik") {
                    TextField("Başlık", text: $not.baslik)
                    TextField("İçerik", text: $not.icerik)
                }
                
                Section(header: Text("Şifre Güncelle"), footer: Text(hataMesaji).foregroundColor(.red)) {
                    SecureField("Mevcut Şifre", text: $eskiSifreGiris)
                    SecureField("Yeni Şifre (Değiştirmek istemiyorsanız boş bırakın)", text: $yeniSifreGiris)
                }
            }
            .navigationTitle("Düzenle")
            .toolbar {
                Button("Güncelle") {
                    if eskiSifreGiris == not.ozelSifre {
                        if !yeniSifreGiris.isEmpty {
                            not.ozelSifre = yeniSifreGiris
                        }
                        not.kilitliMi = true // Güvenlik için geri kilitle
                        dismiss()
                    } else {
                        hataMesaji = "Mevcut şifre hatalı!"
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SifreliNot.self, inMemory: true)
}
