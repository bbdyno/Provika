//
//  SupportDeveloperView.swift
//  Provika
//
//  설정 내 "개발자 후원" 화면 — 3종 팁 상품(consumable) 표시 및 구매 플로우.
//

import StoreKit
import SwiftUI

struct SupportDeveloperView: View {
    @State private var store = TipStore()

    var body: some View {
        List {
            Section {
                Text(ProvikaStrings.Localizable.Support.footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                if store.isLoading && store.products.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 8)
                        Spacer()
                    }
                } else if store.products.isEmpty {
                    ContentUnavailableView(
                        ProvikaStrings.Localizable.Support.Unavailable.title,
                        systemImage: "heart.slash",
                        description: Text(ProvikaStrings.Localizable.Support.Unavailable.message)
                    )
                } else {
                    ForEach(store.products, id: \.id) { product in
                        tipRow(for: product)
                    }
                }
            }

            if let error = store.lastError {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(ProvikaStrings.Localizable.Support.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadProducts()
        }
        .alert(
            ProvikaStrings.Localizable.Support.Thanks.title,
            isPresented: $store.showThankYou
        ) {
            Button(ProvikaStrings.Localizable.Common.ok, role: .cancel) {}
        } message: {
            Text(ProvikaStrings.Localizable.Support.Thanks.message)
        }
    }

    @ViewBuilder
    private func tipRow(for product: Product) -> some View {
        let tier = TipStore.Tier(rawValue: product.id)
        let symbol = tier?.symbol ?? "❤️"
        let isPurchasing = store.purchasingProductID == product.id
        let isDisabled = store.purchasingProductID != nil

        HStack(alignment: .center, spacing: 14) {
            Text(symbol)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName)
                    .font(.body)
                    .fontWeight(.semibold)
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            Button {
                Task { await store.purchase(product) }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .frame(minWidth: 56)
                } else {
                    Text(product.displayPrice)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(isDisabled)
        }
        .padding(.vertical, 4)
    }
}
