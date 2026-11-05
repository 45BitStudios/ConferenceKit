import ConferenceKit
import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif
#if os(iOS) && canImport(PassKit)
import PassKit
import UIKit
#endif

struct PassScreen: View {
    let store: ConferenceStore
    @State private var walletMessage: String?
    #if os(iOS) && canImport(PassKit)
    @State private var walletPass: WalletPassItem?
    #endif

    var body: some View {
        Group {
            if let pass = store.conferencePass {
                ticket(pass)
            } else {
                EmptyPane(title: "Pass", systemImage: "ticket", message: "No ticket is in this manifest.")
            }
        }
        .navigationTitle("Pass")
        .alert("Wallet", isPresented: walletPresented) {
            Button("OK", role: .cancel) { walletMessage = nil }
        } message: {
            Text(walletMessage ?? "")
        }
        #if os(iOS) && canImport(PassKit)
        .sheet(item: $walletPass) { item in
            WalletAddSheet(pass: item.pass)
        }
        #endif
    }

    private var walletPresented: Binding<Bool> {
        Binding(get: { walletMessage != nil }, set: { if !$0 { walletMessage = nil } })
    }

    private func ticket(_ pass: ConferencePass) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pass.conferenceName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(pass.attendeeName)
                        .font(.title.weight(.semibold))
                    Text(pass.seatOrTicketType)
                        .font(.headline)
                }
                LabeledContent("When", value: pass.relevantDate.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Venue", value: pass.venueName)
                if let address = pass.venueAddress {
                    Text(address).foregroundStyle(.secondary)
                }
                TicketBarcodeView(payload: pass.barcodePayload)
                    .frame(maxWidth: .infinity)
                Text(pass.barcodePayload)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity)
                walletControl(pass)
            }
            .padding()
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func walletControl(_ pass: ConferencePass) -> some View {
        #if os(iOS) && canImport(PassKit)
        Button {
            addToWallet(pass)
        } label: {
            Label("Add to Wallet", systemImage: "wallet.pass")
        }
        .buttonStyle(.borderedProminent)
        Text(PassBuilder.signingRequirement)
            .font(.footnote)
            .foregroundStyle(.secondary)
        #else
        Text("Show this code at registration.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        #endif
    }

    #if os(iOS) && canImport(PassKit)
    private func addToWallet(_ pass: ConferencePass) {
        let package: PassPackage
        do {
            package = try PassBuilder.build(pass: pass)
        } catch {
            walletMessage = error.localizedDescription
            return
        }
        guard package.isSigned else {
            walletMessage = PassBuilder.signingRequirement
            return
        }
        guard PKAddPassesViewController.canAddPasses() else {
            walletMessage = "Wallet isn’t available on this device. The ticket code above still works."
            return
        }
        do {
            let pkPass = try PKPass(data: package.archive)
            guard PKAddPassesViewController(pass: pkPass) != nil else {
                walletMessage = "Wallet couldn’t open this pass."
                return
            }
            walletPass = WalletPassItem(pass: pkPass)
        } catch {
            walletMessage = error.localizedDescription
        }
    }
    #endif
}

#if os(iOS) && canImport(PassKit)
struct WalletPassItem: Identifiable {
    let id = UUID()
    let pass: PKPass
}

struct WalletAddSheet: UIViewControllerRepresentable {
    let pass: PKPass

    func makeUIViewController(context: Context) -> UIViewController {
        PKAddPassesViewController(pass: pass) ?? UIViewController()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
#endif

struct TicketBarcodeView: View {
    var payload: String

    var body: some View {
        #if canImport(CoreImage)
        if let image = TicketBarcode.image(payload: payload) {
            image
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .accessibilityLabel("Ticket barcode")
        } else {
            fallback
        }
        #else
        fallback
        #endif
    }

    private var fallback: some View {
        Text(payload)
            .font(.caption.monospaced())
            .accessibilityLabel("Ticket barcode")
    }
}

#if canImport(CoreImage)
enum TicketBarcode {
    static func image(payload: String) -> Image? {
        guard let data = payload.data(using: .isoLatin1) ?? payload.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}
#endif
