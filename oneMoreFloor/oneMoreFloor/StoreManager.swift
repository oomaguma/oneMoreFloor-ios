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
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            switch tx.productID {
            case Self.removeAdsID:  persistRemoveAds(true)
            case Self.nightWatchID: persistNightWatch(true)
            default: break
            }
        }
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
        Analytics.iapPurchased(productID: tx.productID)
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

/// The two one-time purchases, styled like the rest of the game: a display-font
/// header, `.gamePanel` cards tinted per product, and a chunky gold price button.
/// Honest and low-pressure on purpose (engagement chart: no dark patterns) —
/// no timers, no "best value" bait, just what each purchase does.
struct StoreSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing: String? = nil
    @State private var isRestoring = false

    var body: some View {
        let store = StoreManager.shared
        ScrollView {
            VStack(spacing: 14) {
                header

                storeCard(
                    title: "Remove Ads",
                    detail: "Free revive after death. Offline gold doubled automatically. No more ad videos.",
                    icon: "xmark.circle.fill",
                    accent: Theme.Palette.flame,
                    product: store.removeAdsProduct,
                    isPurchased: store.hasPurchasedRemoveAds
                )

                storeCard(
                    title: "Night Watch",
                    detail: "Extend offline progress from 4 hours to 24 hours.",
                    icon: "moon.stars.fill",
                    accent: Theme.Palette.frost,
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
                    Text(isRestoring ? "Restoring…" : "Restore Purchases")
                        .font(Theme.Fonts.label(13))
                        .foregroundStyle(Theme.Palette.dust)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .disabled(isRestoring)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.Palette.abyss.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            // A close button as well as the swipe, so it's obvious how to leave.
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Palette.dust)
                    .frame(width: 32, height: 32)
                    .gamePanel(cornerRadius: 10, translucent: true)
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.Palette.blood)
                .gameShadow(3)
            Text("SUPPORT THE GAME")
                .font(Theme.Fonts.display(24))
                .foregroundStyle(Theme.Palette.parchment)
                .gameShadow(3)
            Text("One More Floor is made by a three-person team. Everything here is optional — the whole dungeon is free.")
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Palette.dust)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 28)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func storeCard(title: String, detail: String, icon: String, accent: Color,
                           product: Product?, isPurchased: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.15)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(Theme.Fonts.display(17))
                        .foregroundStyle(Theme.Palette.parchment)
                    Text(detail)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Palette.dust)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // The action row: owned badge, price button, or "unavailable".
            if isPurchased {
                Label("OWNED", systemImage: "checkmark.seal.fill")
                    .font(Theme.Fonts.label(14))
                    .foregroundStyle(Theme.Palette.life)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            } else if let product {
                Button {
                    isPurchasing = product.id
                    Task {
                        try? await StoreManager.shared.purchase(product)
                        isPurchasing = nil
                    }
                } label: {
                    Group {
                        if isPurchasing == product.id {
                            ProgressView().tint(.black)
                        } else {
                            Text(product.displayPrice)
                                .font(Theme.Fonts.display(17))
                                .foregroundStyle(Color.black.opacity(0.8))
                        }
                    }
                }
                .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.gold, lip: Theme.Palette.goldDeep,
                                               cornerRadius: 12, depth: 4))
                .frame(height: 48)
                .disabled(isPurchasing != nil)
            } else {
                // Products didn't load (offline, or no App Store in the simulator).
                Text("Unavailable right now")
                    .font(Theme.Fonts.label(13))
                    .foregroundStyle(Theme.Palette.ash)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .padding(16)
        .gamePanel(tint: isPurchased ? Theme.Palette.life.opacity(0.6) : accent.opacity(0.55), cornerRadius: 16)
    }
}
