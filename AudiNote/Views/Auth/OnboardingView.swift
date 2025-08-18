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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("AudiNote")
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(.primary)
                        .tracking(-0.5)

                    Text("Record, transcribe, and share your moments.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Sign in with Apple
                VStack(spacing: 12) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            session.handleAppleSignIn(result: result)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 56)
                    .clipShape(Capsule())
                    .shadow(radius: 10, y: 6)
                    .accessibilityLabel("Sign in with Apple")

                    Text(attributedLegalText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
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
                center: .center,
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
        .init(symbol: "waveform", tint: .red),
        .init(symbol: "text.bubble.fill", tint: .indigo),
        .init(symbol: "bookmark.fill", tint: .teal),
        .init(symbol: "square.and.arrow.up.fill", tint: .orange)
    ]

    private let mid: [OrbitItem] = [
        .init(symbol: "calendar", tint: .purple),
        .init(symbol: "mappin.and.ellipse", tint: .pink),
        .init(symbol: "note.text", tint: .blue),
        .init(symbol: "sparkles", tint: .mint)
    ]

    private let outer: [OrbitItem] = [
        .init(symbol: "person.2.fill", tint: .green),
        .init(symbol: "globe.americas.fill", tint: .cyan),
        .init(symbol: "ticket.fill", tint: .orange),
        .init(symbol: "party.popper.fill", tint: .pink)
    ]

    @State private var rotateOuter = false
    @State private var rotateMid = false
    @State private var rotateInner = false

    var body: some View {
        ZStack {
            // Faint concentric rings
            OrbitRings()

            // Center app icon (slightly smaller)
            Image("AudiNoteIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)

            // OUTER ring (slow, clockwise)
            OrbitLayer(radius: 190, items: outer) // was 150
                .rotationEffect(.degrees(rotateOuter ? 360 : 0))
                .animation(.linear(duration: 48).repeatForever(autoreverses: false), value: rotateOuter)

            // MIDDLE ring (medium, counter-clockwise)
            OrbitLayer(radius: 150, items: mid) // was 110
                .rotationEffect(.degrees(rotateMid ? -360 : 0))
                .animation(.linear(duration: 36).repeatForever(autoreverses: false), value: rotateMid)

            // INNER ring (faster, clockwise)
            OrbitLayer(radius: 95, items: inner) // was 70
                .rotationEffect(.degrees(rotateInner ? 360 : 0))
                .animation(.linear(duration: 24).repeatForever(autoreverses: false), value: rotateInner)
        }
        .onAppear {
            rotateOuter = true
            rotateMid = true
            rotateInner = true
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

// MARK: - Circular badge view (smaller badges)
private struct CircleBadge: View {
    let symbol: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle().stroke(.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)

            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold)) // was 22
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, tint.opacity(0.35))
        }
        .frame(width: 46, height: 46) // was 52
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

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                ForEach(items.indices, id: \.self) { i in
                    let angle = Angle.degrees(Double(i) / Double(items.count) * 360)
                    
                    CircleBadge(symbol: items[i].symbol, tint: items[i].tint)
                        .rotationEffect(-angle) // counter-rotate so icon stays upright
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
