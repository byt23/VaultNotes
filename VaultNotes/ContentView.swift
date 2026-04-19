//
//  ContentView.swift
//  VaultNotes
//
//  Created by BERKAY TURAN on 19.04.2026.
//

import SwiftUI
import SwiftData
import LocalAuthentication

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

extension Color {
    static let vaultDark = Color(red: 0.05, green: 0.07, blue: 0.12)
    static let vaultSilver = Color(red: 0.75, green: 0.75, blue: 0.8)
}

struct MatrixBackground: View {
    let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 12) {
                ForEach(0..<Int(proxy.size.width / 15), id: \.self) { _ in
                    MatrixColumn(proxy: proxy, characters: characters)
                }
            }
            .mask(LinearGradient(colors: [.clear, .black, .clear], startPoint: .top, endPoint: .bottom))
            .opacity(0.15)
        }
    }
}

struct MatrixColumn: View {
    let proxy: GeometryProxy
    let characters: [Character]
    @State private var position: CGFloat = 0
    @State private var columnChars = ""
    
    var body: some View {
        Text(columnChars)
            .font(.system(size: 12, weight: .light, design: .monospaced))
            .foregroundColor(.vaultSilver)
            .onAppear {
                for _ in 0..<30 { columnChars += String(characters.randomElement()!) + "\n" }
                position = -proxy.size.height
                withAnimation(Animation.linear(duration: Double.random(in: 10...20)).repeatForever(autoreverses: false)) {
                    position = proxy.size.height
                }
            }
            .offset(y: position)
    }
}

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
            ZStack {
                Color.vaultDark.ignoresSafeArea()
                
                MatrixBackground()
                    .ignoresSafeArea()
                
                List {
                    ForEach(notlar) { not in
                        HStack(spacing: 15) {
                            Button { dogrulamaBaslat(not: not) } label: {
                                HStack(spacing: 15) {
                                    Image(systemName: not.kilitliMi ? "lock.fill" : "lock.open.fill")
                                        .foregroundColor(not.kilitliMi ? .vaultSilver : .green)
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(not.baslik)
                                            .font(.system(.headline, design: .monospaced))
                                            .foregroundColor(.white)
                                        
                                        Text(not.kilitliMi ? "••••••••" : not.icerik)
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundColor(.vaultSilver.opacity(0.7))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            if !not.kilitliMi {
                                Button { duzenlenecekNot = not } label: {
                                    Image(systemName: "pencil.circle")
                                        .foregroundColor(.vaultSilver)
                                        .font(.title2)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.vaultSilver.opacity(0.2), lineWidth: 1)
                                )
                                .padding(.vertical, 4)
                        )
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                hedefNot = not
                                girilenSifre = ""
                                silmeOnayModu = true
                            } label: { Label("Sil", systemImage: "trash") }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("VaultNotes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { eklemeModu = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.vaultSilver)
                    }
                }
            }
            .alert("Not Şifresi", isPresented: $sifreCheckModu) {
                SecureField("Şifre", text: $girilenSifre)
                Button("Aç") { sifreKontrolEt() }
                Button("İptal", role: .cancel) { girilenSifre = "" }
            }
            .alert("Silme İşlemini Onayla", isPresented: $silmeOnayModu) {
                SecureField("Notun şifresini girin", text: $girilenSifre)
                Button("Sil", role: .destructive) { guvenliSil() }
                Button("Vazgeç", role: .cancel) { girilenSifre = "" }
            } message: { Text("Notu silmek için şifresini girmelisiniz.") }
            .sheet(isPresented: $eklemeModu) { eklemeSayfasi }
            .sheet(item: $duzenlenecekNot) { not in EditNoteView(not: not) }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                for not in notlar { not.kilitliMi = true }
            }
        }
    }

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
        } else { hedefNot = not; sifreCheckModu = true }
    }

    func sifreKontrolEt() {
        if girilenSifre == hedefNot?.ozelSifre { withAnimation { hedefNot?.kilitliMi = false } }
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
                Section("Güvenlik") { SecureField("Nota Özel Şifre", text: $yeniOzelSifre) }
            }
            .navigationTitle("Yeni Kasa Notu")
            .toolbar { Button("Ekle") { ekle() }.disabled(yeniBaslik.isEmpty || yeniOzelSifre.isEmpty) }
        }
    }
}

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
                Section(header: Text("Güvenlik"), footer: Text(hataMesaji).foregroundColor(.red)) {
                    SecureField("Mevcut Şifre", text: $eskiSifreGiris)
                    SecureField("Yeni Şifre (Opsiyonel)", text: $yeniSifreGiris)
                }
            }
            .navigationTitle("Düzenle")
            .toolbar {
                Button("Güncelle") {
                    if eskiSifreGiris == not.ozelSifre {
                        if !yeniSifreGiris.isEmpty { not.ozelSifre = yeniSifreGiris }
                        not.kilitliMi = true
                        dismiss()
                    } else { hataMesaji = "Mevcut şifre hatalı!" }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SifreliNot.self, inMemory: true)
}
