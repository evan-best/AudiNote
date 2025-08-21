//
//  OnboardingView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-15.
//

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            BackgroundWash()

            VStack(spacing: 28) {
                Spacer(minLength: 20)

                // Orbit scene with concentric rings and the app icon in the middle
                OrbitScene()
                    .frame(height: 360)
                    .padding(.top, 8)

                // Title + Subtitle (below the orbit like the reference)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("AudiNote")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text("Record transcribe and share your moments, meetings and more.")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Sign in with Apple
                VStack(spacing: 14) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            session.handleAppleSignIn(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .id(colorScheme)
                    .frame(height: 56)
                    .clipShape(Capsule())
                    .shadow(radius: 10, y: 6)
                    .accessibilityLabel("Sign in with Apple")

                    Text(attributedLegalText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Legal
    private var attributedLegalText: AttributedString {
        var base = AttributedString("By continuing you agree to our ")

        if let termsURL = URL(string: "https://example.com/terms") {
            var terms = AttributedString("Terms of Service")
            terms.link = termsURL
            terms.font = .system(size: UIFont.preferredFont(forTextStyle: .footnote).pointSize, weight: .semibold)
            terms.foregroundColor = .primary
            base.append(terms)
        }

        base.append(AttributedString(" and "))

        if let privacyURL = URL(string: "https://example.com/privacy") {
            var privacy = AttributedString("Privacy Policy")
            privacy.link = privacyURL
            privacy.font = .system(size: UIFont.preferredFont(forTextStyle: .footnote).pointSize, weight: .semibold)
            privacy.foregroundColor = .primary
            base.append(privacy)
        }

        return base
    }
}

// MARK: - Background wash (soft pastel like the reference)
private struct BackgroundWash: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            RadialGradient(
                colors: [
                    Color.mint.opacity(0.18),
                    Color.cyan.opacity(0.10),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 50,
                endRadius: 600
            )
            .blur(radius: 60)

            LinearGradient(
                colors: [
                    Color.orange.opacity(0.12),
                    .clear,
                    Color.indigo.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 60)
        }
    }
}

// MARK: - Orbit Scene (rings + rotating badge layers + center icon)
private struct OrbitScene: View {
    private let inner: [OrbitItem] = [
        .init(symbol: "mic.fill", tint: .red),
        .init(symbol: "waveform", tint: .blue),
        .init(symbol: "doc.text.fill", tint: .pink),
        .init(symbol: "square.and.arrow.up.fill", tint: .accentColor),
        .init(symbol: "folder.fill", tint: .purple),
    ]

    private let outer: [OrbitItem] = [
        .init(symbol: "headphones", tint: .cyan),
        .init(symbol: "star.fill", tint: .yellow),
        .init(symbol: "quote.bubble.fill", tint: .indigo),
        .init(symbol: "textformat", tint: .mint),
        .init(symbol: "clock.fill", tint: .gray),
        .init(symbol: "magnifyingglass", tint: .teal),
        .init(symbol: "cloud.fill", tint: .blue),
        .init(symbol: "bell.fill", tint: .yellow),
        .init(symbol: "record.circle.fill", tint: .red),
        .init(symbol: "chart.bar.fill", tint: .green)
    ]

    @State private var hasExpanded = false
    @State private var rotationAngle: Double = 0
    @State private var showIcons = false

    var body: some View {
        ZStack {
            // INNER ring (behind app icon)
            OrbitLayer(
                radius: hasExpanded ? 90 : 0,
                items: inner,
                showIcons: showIcons,
                rotationAngle: rotationAngle,
                iconSize: 30
            )
            .rotationEffect(.degrees(rotationAngle))

            // OUTER ring (behind app icon)
            OrbitLayer(
                radius: hasExpanded ? 140 : 0,
                items: outer,
                showIcons: showIcons,
                rotationAngle: -rotationAngle * 0.7,
                iconSize: 24
            )
            .rotationEffect(.degrees(-rotationAngle * 0.7))
            
            // Center app icon (on top)
            Image("AudiNoteIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        }
        .onAppear {
            // Start expansion after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                    hasExpanded = true
                    showIcons = true
                }
                
                // Start rotation after expansion completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
            }
        }
    }
}

// MARK: - Orbit Rings (spaced farther apart)
private struct OrbitRings: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(.white.opacity(0.60), lineWidth: 1)
                .frame(width: 340, height: 340) // was 300
            Circle().strokeBorder(.white.opacity(0.55), lineWidth: 1)
                .frame(width: 260, height: 260) // was 240
            Circle().strokeBorder(.white.opacity(0.50), lineWidth: 1)
                .frame(width: 190, height: 190) // was 200 (slightly smaller for better spacing)
        }
        .blur(radius: 0.2)
    }
}

// MARK: - Circular badge view (no background)
private struct CircleBadge: View {
    let symbol: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(tint)
            .frame(width: size * 1.3, height: size * 1.3)
    }
}

// MARK: - Orbit Item model
private struct OrbitItem: Identifiable {
    let id = UUID()
    let symbol: String
    let tint: Color
}

// MARK: - Orbit Layer (positions items evenly around a circle, icons stay upright)
private struct OrbitLayer: View {
    let radius: CGFloat
    let items: [OrbitItem]
    let showIcons: Bool
    let rotationAngle: Double
    let iconSize: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                ForEach(items.indices, id: \.self) { i in
                    let angle = Angle.degrees(Double(i) / Double(items.count) * 360)
                    
                    CircleBadge(symbol: items[i].symbol, tint: items[i].tint, size: iconSize)
                        .rotationEffect(.degrees(-rotationAngle)) // Counter-rotate to keep icons upright
                        .opacity(showIcons ? 1 : 0)
                        .position(point(on: center, radius: radius, angle: angle))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func point(on center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        let rad = CGFloat(angle.radians)
        return CGPoint(
            x: center.x + radius * cos(rad),
            y: center.y + radius * sin(rad)
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(SessionViewModel())
}

