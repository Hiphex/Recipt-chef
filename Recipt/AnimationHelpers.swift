import SwiftUI

// MARK: - Haptic Feedback Manager
class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

// MARK: - Custom Animations
extension Animation {
    static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.85)
}

// MARK: - View Extensions for Animations
extension View {
    func cardAppearance(delay: Double = 0) -> some View {
        self
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
            .animation(.smooth.delay(delay), value: UUID())
    }

    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }

    func shake(isShaking: Bool) -> some View {
        self.modifier(ShakeEffect(shakes: isShaking ? 3 : 0))
    }
}

// MARK: - Shimmer Effect (for loading states)
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.3),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

// MARK: - Shake Effect
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 10 * sin(shakes * .pi * 2), y: 0)
        )
    }
}

// MARK: - Gradient Backgrounds
extension LinearGradient {
    static let budgetGradient = LinearGradient(
        colors: [Color.accentColor.opacity(0.1), Color.accentColor.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardGradient = LinearGradient(
        colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
        startPoint: .top,
        endPoint: .bottom
    )

    static func categoryGradient(for color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.2), color.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Card Shadow Style
extension View {
    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    func glassMorphism() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Progress Bar Animation
struct AnimatedProgressBar: View {
    let progress: Double
    let color: Color
    let height: CGFloat

    @State private var animatedProgress: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(.systemGray5))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: min(geometry.size.width * CGFloat(animatedProgress / 100), geometry.size.width),
                        height: height
                    )
                    .animation(.smooth, value: animatedProgress)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.smooth.delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.smooth) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Skeleton Loading View
struct SkeletonLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { index in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                        .shimmer()

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 150, height: 16)
                            .shimmer()

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 100, height: 12)
                            .shimmer()
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 16)
                        .shimmer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
    }
}

// MARK: - Confetti Effect
struct ConfettiView: View {
    @State private var isAnimating = false
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]

    var body: some View {
        ZStack {
            ForEach(0..<50) { index in
                ConfettiPiece(color: colors.randomElement() ?? .blue)
                    .offset(
                        x: isAnimating ? CGFloat.random(in: -200...200) : 0,
                        y: isAnimating ? CGFloat.random(in: -500...500) : -50
                    )
                    .opacity(isAnimating ? 0 : 1)
                    .rotationEffect(.degrees(isAnimating ? Double.random(in: 0...720) : 0))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                isAnimating = true
            }
        }
    }
}

struct ConfettiPiece: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 8, height: 8)
    }
}
