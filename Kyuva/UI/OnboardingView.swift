import SwiftUI

private let onboardingAccent = Color(red: 0.79, green: 0.81, blue: 1.0)

/// Onboarding wizard shown on first launch
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    private let totalPages = 3
    
    var body: some View {
        VStack(spacing: 0) {
            // Content - manual page switching
            Group {
                switch currentPage {
                case 0:
                    WelcomePage()
                case 1:
                    FeaturesPage()
                case 2:
                    GettingStartedPage()
                default:
                    WelcomePage()
                }
            }
            .frame(maxHeight: .infinity)
            
            // Navigation
            HStack {
                if currentPage > 0 {
                    Button(action: { currentPage -= 1 }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                } else {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? onboardingAccent : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
                .accessibilityAddTraits(.isStaticText)
                
                Spacer()
                
                if currentPage < totalPages - 1 {
                    Button(action: { currentPage += 1 }) {
                        HStack(spacing: 6) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(onboardingAccent, in: Capsule())
                            .overlay {
                                Capsule().stroke(.white.opacity(0.22))
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                } else {
                    Button(action: { completeOnboarding() }) {
                        HStack(spacing: 6) {
                            Text("Get Started")
                            Image(systemName: "arrow.right")
                        }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(onboardingAccent, in: Capsule())
                            .overlay {
                                Capsule().stroke(.white.opacity(0.22))
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.black)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
        }
        .frame(width: 650, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        isPresented = false
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
                .shadow(color: onboardingAccent.opacity(0.22), radius: 20, y: 8)
            
            Text("Welcome to Kyuva")
                .font(.largeTitle.bold())
            
            Text("Your camera-side teleprompter")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Kyuva displays your notes right next to your camera —")
                Text("so you can read while maintaining natural eye contact")
                Text("during video calls and presentations.")
            }
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            
            HStack(spacing: 12) {
                Image(systemName: "arrow.up")
                    .font(.title2)
                    .foregroundColor(onboardingAccent)
                    .accessibilityHidden(true)
                    .padding(12)
                    .background(Circle().fill(onboardingAccent.opacity(0.15)))
                
                VStack(alignment: .leading) {
                    Text("Look up at your screen")
                        .font(.headline)
                    Text("The prompter appears near your camera")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Features Page

struct FeaturesPage: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "viewfinder.circle")
                .font(.system(size: 40))
                .foregroundColor(onboardingAccent)
                .accessibilityHidden(true)
                .padding(10)
                .background(
                    Circle()
                        .fill(onboardingAccent.opacity(0.15))
                        .frame(width: 70, height: 70)
                )
            
            Text("Your Camera-Side Teleprompter")
                .font(.title2.bold())
            
            Text("Keep your notes close while you speak")
                .font(.callout)
                .foregroundColor(.secondary)
            
            // Feature grid - more compact
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FeatureCard(
                    icon: "eye",
                    iconColor: onboardingAccent,
                    title: "Natural Eye Contact",
                    description: "Text appears next to your camera"
                )
                
                FeatureCard(
                    icon: "lock.shield",
                    iconColor: onboardingAccent,
                    title: "Local by Default",
                    description: "No account, analytics, or required cloud"
                )
                
                FeatureCard(
                    icon: "speedometer",
                    iconColor: onboardingAccent,
                    title: "Flexible Pacing",
                    description: "Use fixed speed, WPM, or a target duration"
                )
                
                FeatureCard(
                    icon: "rectangle.on.rectangle",
                    iconColor: .orange,
                    title: "Honest Capture",
                    description: "The prompt may be recorded, so check your preview"
                )
            }
            .padding(.horizontal, 20)
        }
        .padding()
    }
}

struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .accessibilityHidden(true)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.15)))
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }
}

// MARK: - Getting Started Page

struct GettingStartedPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 50))
                .foregroundColor(onboardingAccent)
                .accessibilityHidden(true)
                .padding()
                .background(
                    Circle()
                        .fill(onboardingAccent.opacity(0.15))
                        .frame(width: 100, height: 100)
                )
            
            Text("Getting Started")
                .font(.title.bold())
            
            Text("How to use Kyuva")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                StepRow(number: 1, title: "Choose a script", description: "Create, import, or find it in the local library")
                StepRow(number: 2, title: "Write and tune", description: "Edit in the center and choose pace, type, and directions on the right")
                StepRow(number: 3, title: "Open the prompt", description: "Place it near your camera, then play or pause from its controls")
                StepRow(number: 4, title: "Verify your share", description: "Check your meeting or recording preview before you present")
            }
            .padding(.horizontal, 50)
            
            Spacer()
        }
        .padding()
    }
}

struct StepRow: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.black)
                .frame(width: 28, height: 28)
                .background(Circle().fill(onboardingAccent))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
