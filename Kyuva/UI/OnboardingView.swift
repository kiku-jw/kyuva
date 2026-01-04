import SwiftUI

/// Onboarding wizard shown on first launch
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("useVoiceControl") private var useVoiceControl = false // Default: Manual
    
    private let totalPages = 4
    
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
                case 3:
                    VoiceChoicePage(useVoiceControl: $useVoiceControl)
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
                            .fill(index == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                if currentPage < totalPages - 1 {
                    Button(action: { currentPage += 1 }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { completeOnboarding() }) {
                        HStack {
                            Text("Get Started")
                            Image(systemName: "arrow.right")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
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
            
            // Icon
            Image(systemName: "text.alignleft")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding()
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                )
            
            Text("Welcome to Kyuva")
                .font(.largeTitle.bold())
            
            Text("Your invisible teleprompter")
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
                    .foregroundColor(.accentColor)
                    .padding(12)
                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
                
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
            // Icon
            Image(systemName: "eye")
                .font(.system(size: 40))
                .foregroundColor(.green)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 70, height: 70)
                )
            
            Text("Your Invisible Teleprompter")
                .font(.title2.bold())
            
            Text("Read without anyone knowing")
                .font(.callout)
                .foregroundColor(.secondary)
            
            // Feature grid - more compact
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FeatureCard(
                    icon: "person.fill",
                    iconColor: .blue,
                    title: "Natural Eye Contact",
                    description: "Text appears next to your camera"
                )
                
                FeatureCard(
                    icon: "rectangle.on.rectangle.slash",
                    iconColor: .orange,
                    title: "Hidden from Others",
                    description: "Excluded from screen sharing"
                )
                
                FeatureCard(
                    icon: "text.alignleft",
                    iconColor: .purple,
                    title: "Auto-Scrolling",
                    description: "Focus on speaking, not scrolling"
                )
                
                FeatureCard(
                    icon: "macwindow.on.rectangle",
                    iconColor: .cyan,
                    title: "Always on Top",
                    description: "Visible above all windows"
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
            
            // Icon
            Image(systemName: "gearshape.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .padding()
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 100, height: 100)
                )
            
            Text("Getting Started")
                .font(.title.bold())
            
            Text("How to use Kyuva")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                StepRow(number: 1, title: "Add your notes", description: "Write your scripts, bullet points, or meeting notes in the editor")
                StepRow(number: 2, title: "Press Play", description: "Click the Play button to show the teleprompter near your camera")
                StepRow(number: 3, title: "Control the scroll", description: "Hover to pause, scroll manually, or adjust speed with keyboard shortcuts")
                StepRow(number: 4, title: "Press Stop", description: "Click Stop to hide the teleprompter when you're done")
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
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))
            
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

// MARK: - Voice Choice Page

struct VoiceChoicePage: View {
    @Binding var useVoiceControl: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: "mic.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 70, height: 70)
                )
            
            Text("Voice Activation")
                .font(.title2.bold())
            
            Text("How would you like to control the prompter?")
                .font(.callout)
                .foregroundColor(.secondary)
            
            Text("Voice Activation automatically scrolls when you speak\nand pauses when you stop.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Icons row - more compact
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Detects Speech")
                        .font(.caption2)
                }
                
                VStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("Auto-Scrolls")
                        .font(.caption2)
                }
                
                VStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text("Auto-Pauses")
                        .font(.caption2)
                }
            }
            .padding(.vertical, 8)
            
            // Choice buttons
            HStack(spacing: 12) {
                Button(action: { useVoiceControl = true }) {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "mic.fill")
                            Text("Enable Voice")
                        }
                        Text("Coming Soon")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(useVoiceControl ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(useVoiceControl ? .white : .primary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: { useVoiceControl = false }) {
                    HStack {
                        Image(systemName: "hand.point.up.fill")
                        Text("Manual Control")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(!useVoiceControl ? Color.accentColor : Color.gray.opacity(0.2))
                    .foregroundColor(!useVoiceControl ? .white : .primary)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            
            // Privacy note
            HStack {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                Text("Audio is only used to detect speaking — nothing is recorded")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.1)))
        }
        .padding()
    }
}
