import GGSBrand
import SwiftUI

/// Settings → About ConciergeClock: version, privacy promises, open-source licences, terms.
struct AboutConciergeClockView: View {
    @Environment(\.l10n) private var l10n
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ButlerNetworkMark(style: colorScheme == .dark ? .onDark : .standard)
                    .frame(height: 96)
                    .padding(.top, 20)
                Text(verbatim: "ConciergeClock")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.focus)
                Text(l10n("about.version", version, build))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)

                VStack(alignment: .leading, spacing: 16) {
                    promise("airplane", "about.offline")
                    promise("eye.slash", "about.tracking")
                    promise("externaldrive", "about.data")
                    promise("tag", "about.price")
                    promise("cpu", "about.onDevice")
                    promise("mic.slash", "about.voice")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                NavigationLink {
                    LegalTextView(title: l10n["about.acknowledgements"], text: Acknowledgements.text)
                } label: {
                    linkRow("doc.text", l10n["about.acknowledgements"])
                }
                NavigationLink {
                    LegalTextView(title: l10n["about.terms"], text: l10n["terms.body"])
                } label: {
                    linkRow("checkmark.shield", l10n["about.terms"])
                }

                BrandLockup(height: 48)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.top, 8)
                Text(l10n["about.product"])
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .background(Theme.background)
        .navigationTitle(l10n["about.title"])
        .navigationBarTitleDisplayMode(.inline)
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func promise(_ icon: String, _ key: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(ConciergeStyle.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n[key + ".title"])
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(l10n[key + ".detail"])
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func linkRow(_ icon: String, _ title: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(ConciergeStyle.tint)
            Text(title).foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .cardStyle(padding: 14)
    }
}

/// A scrolling page of legal text.
struct LegalTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Open-source licences of everything bundled in the app. The offline AI model (Gemma) is not
/// bundled: the person downloads it, and its licence is shown in Settings › Offline AI.
enum Acknowledgements {
    static let text = """
    GRDB.swift — https://github.com/groue/GRDB.swift

    Copyright (C) 2015-2025 Gwendal Roué

    Permission is hereby granted, free of charge, to any person obtaining a copy of this \
    software and associated documentation files (the "Software"), to deal in the Software \
    without restriction, including without limitation the rights to use, copy, modify, \
    merge, publish, distribute, sublicense, and/or sell copies of the Software, and to \
    permit persons to whom the Software is furnished to do so, subject to the following \
    conditions:

    The above copyright notice and this permission notice shall be included in all copies \
    or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, \
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A \
    PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT \
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF \
    CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE \
    OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

    ———

    LiteRT-LM — https://github.com/google-ai-edge/LiteRT-LM

    Copyright 2025 Google LLC

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this \
    file except in compliance with the License. You may obtain a copy of the License at \
    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under \
    the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY \
    KIND, either express or implied. See the License for the specific language governing \
    permissions and limitations under the License.

    ———

    Gemma 4 (downloaded on request, not bundled) — Google, Apache License 2.0.
    """
}

/// "About Greater Good Software", opened by tapping the logo in the top bar. Same text as
/// PrepPilot, FocusFound and FotoPhilter, with ConciergeClock added to "Our apps".
struct AboutCompanyView: View {
    @Environment(\.l10n) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Brand lockup: always left-to-right, never translated.
                    BrandLockup(height: 80)
                        .environment(\.layoutDirection, .leftToRight)
                        .padding(.top, 20)

                    Text(l10n["company.tagline"])
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.textPrimary)

                    Text(l10n["company.mission"])
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 16) {
                        Text(l10n["company.principles"].uppercased(with: l10n.locale))
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(Theme.textSecondary)
                        principle("lock.shield", "company.privacy")
                        principle("tag", "company.fair")
                        principle("globe", "company.access")
                        principle("leaf", "company.lasting")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 16) {
                        Text(l10n["company.products"].uppercased(with: l10n.locale))
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(Theme.textSecondary)
                        product(name: "ConciergeClock", displayName: "ConciergeClock", detailKey: "company.conciergeclock")
                        product(name: "PrepPilot", detailKey: "company.preppilot")
                        product(name: "FocusFound", detailKey: "company.focusfound")
                        product(name: "FotoPhilter", detailKey: "company.fotophilter")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()

                    Text(l10n["company.footer"])
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
            .background(Theme.background)
            .navigationTitle(l10n["company.title"])
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n["common.done"]) { dismiss() }
                }
            }
        }
        .tint(ConciergeStyle.tint)
    }

    private func principle(_ icon: String, _ key: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(ConciergeStyle.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n[key + ".title"])
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(l10n[key + ".detail"])
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Each app shown with its real Home Screen icon (Assets: ProductIcon-<name>).
    private func product(name: String, displayName: String? = nil, detailKey: String) -> some View {
        HStack(spacing: 14) {
            Image("ProductIcon-" + name)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 0.5))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                // Product names are never translated.
                Text(verbatim: displayName ?? name)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(l10n[detailKey])
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
