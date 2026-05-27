import StoreKit
import SwiftUI

// MARK: - Store Manager

@Observable
@MainActor
final class StoreManager {
    static let shared = StoreManager()

    static let removeAdsID  = "com.oneMoreFloor.removeAds"
    static let nightWatchID = "com.oneMoreFloor.nightWatch"

    private(set) var removeAdsProduct:  Product?
    private(set) var nightWatchProduct: Product?

    private(set) var hasPurchasedRemoveAds:  Bool
    private(set) var hasPurchasedNightWatch: Bool

    private var updatesTask: Task<Void, Never>?

    private init() {
        hasPurchasedRemoveAds  = UserDefaults.standard.bool(forKey: Self.removeAdsID)
        hasPurchasedNightWatch = UserDefaults.standard.bool(forKey: Self.nightWatchID)
        Task { await loadProducts() }
        Task { await verifyEntitlements() }
        updatesTask = listenForTransactions()
    }

    private func loadProducts() async {
        guard let products = try? await Product.products(for: [Self.removeAdsID, Self.nightWatchID]) else { return }
        for product in products {
            switch product.id {
            case Self.removeAdsID:  removeAdsProduct  = product
            case Self.nightWatchID: nightWatchProduct = product
            default: break
            }
        }
    }

    private func verifyEntitlements() async {
        var removeAds = false, nightWatch = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            switch tx.productID {
            case Self.removeAdsID:  removeAds  = true
            case Self.nightWatchID: nightWatch = true
            default: break
            }
        }
        persistRemoveAds(removeAds)
        persistNightWatch(nightWatch)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                switch tx.productID {
                case Self.removeAdsID:  persistRemoveAds(true)
                case Self.nightWatchID: persistNightWatch(true)
                default: break
                }
                await tx.finish()
            }
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        guard case .success(let verification) = result,
              case .verified(let tx) = verification else { return }
        switch tx.productID {
        case Self.removeAdsID:  persistRemoveAds(true)
        case Self.nightWatchID: persistNightWatch(true)
        default: break
        }
        await tx.finish()
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await verifyEntitlements()
    }

    private func persistRemoveAds(_ value: Bool) {
        hasPurchasedRemoveAds = value
        UserDefaults.standard.set(value, forKey: Self.removeAdsID)
    }

    private func persistNightWatch(_ value: Bool) {
        hasPurchasedNightWatch = value
        UserDefaults.standard.set(value, forKey: Self.nightWatchID)
    }
}

// MARK: - Store Sheet

struct StoreSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing: String? = nil
    @State private var isRestoring = false

    var body: some View {
        let store = StoreManager.shared
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    storeRow(
                        title: "Remove Ads",
                        detail: "Free revive after death. Offline gold doubled automatically. No more ad videos.",
                        icon: "xmark.circle.fill",
                        iconColor: Color(red: 1.00, green: 0.45, blue: 0.25),
                        product: store.removeAdsProduct,
                        isPurchased: store.hasPurchasedRemoveAds
                    )

                    storeRow(
                        title: "Night Watch",
                        detail: "Extend offline progress from 4 hours to 24 hours.",
                        icon: "moon.stars.fill",
                        iconColor: Color(red: 0.45, green: 0.65, blue: 1.00),
                        product: store.nightWatchProduct,
                        isPurchased: store.hasPurchasedNightWatch
                    )

                    Button {
                        isRestoring = true
                        Task {
                            await store.restorePurchases()
                            isRestoring = false
                        }
                    } label: {
                        Text(isRestoring ? "Restoring..." : "Restore Purchases")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .disabled(isRestoring)
                }
                .padding(16)
                .padding(.top, 8)
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.11).ignoresSafeArea())
            .navigationTitle("Support the Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.09, green: 0.09, blue: 0.14), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func storeRow(title: String, detail: String, icon: String, iconColor: Color,
                          product: Product?, isPurchased: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(iconColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.25, green: 0.80, blue: 0.45))
                    .padding(.top, 2)
            } else if let product {
                Button {
                    isPurchasing = product.id
                    Task {
                        try? await StoreManager.shared.purchase(product)
                        isPurchasing = nil
                    }
                } label: {
                    if isPurchasing == product.id {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(width: 60)
                    } else {
                        Text(product.displayPrice)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.20, green: 0.42, blue: 0.22))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing != nil)
                .padding(.top, 2)
            } else {
                Text("—")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.30))
                    .frame(width: 40)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPurchased ? iconColor.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
