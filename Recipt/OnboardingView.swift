import SwiftUI

// MARK: - Onboarding View
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.accentColor.opacity(0.05)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                TabView(selection: $currentPage) {
                    // Page 1: Welcome
                    OnboardingPage(
                        systemImage: "receipt.fill",
                        title: "Welcome to Receipt Tracker",
                        description: "Scan receipts, track spending, and stay on budget effortlessly",
                        accentColor: .blue
                    )
                    .tag(0)

                    // Page 2: Scan
                    OnboardingPage(
                        systemImage: "camera.fill",
                        title: "Scan Any Receipt",
                        description: "Use your camera to instantly extract items, prices, and totals from any receipt",
                        accentColor: .green
                    )
                    .tag(1)

                    // Page 3: Budget
                    OnboardingPage(
                        systemImage: "chart.bar.fill",
                        title: "Set Your Budgets",
                        description: "Create category budgets and get warned when you're close to your limit",
                        accentColor: .orange
                    )
                    .tag(2)

                    // Page 4: Track
                    OnboardingPage(
                        systemImage: "eye.fill",
                        title: "Track Your Spending",
                        description: "See all your receipts in one place and watch your spending in real-time",
                        accentColor: .purple
                    )
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 450)

                // Get Started Button
                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)

                // Skip Button
                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Onboarding Page Component
struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let description: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: systemImage)
                .font(.system(size: 80))
                .foregroundStyle(accentColor)
                .padding()
                .background(accentColor.opacity(0.1))
                .clipShape(Circle())

            VStack(spacing: 12) {
                Text(title)
                    .font(.title)
                    .bold()
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}
