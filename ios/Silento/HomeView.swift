import SwiftUI

struct HomeView: View {
    let onCreateRoom: () -> Void
    let onJoinRoom: () -> Void
    
    @State private var showFeaturePills = false
    @State private var showButtons = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Hero section
            VStack(spacing: 30) {
                // Logo and tagline
                VStack(spacing: 16) {
                    Text("Silento")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .blue.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)
                    
                    Text("Anonymous messaging that disappears")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Feature pills
                HStack(spacing: 12) {
                    FeaturePill(icon: "🔒", text: "End-to-End Encrypted")
                    FeaturePill(icon: "👻", text: "No Registration")
                    FeaturePill(icon: "💨", text: "Auto-Delete")
                }
                .opacity(showFeaturePills ? 1 : 0)
                .offset(y: showFeaturePills ? 0 : 20)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                ActionButton(
                    icon: "plus.circle",
                    title: "Create Room",
                    subtitle: "Start a new secure conversation",
                    isPrimary: true,
                    action: onCreateRoom
                )
                
                ActionButton(
                    icon: "arrow.right.circle",
                    title: "Join Room",
                    subtitle: "Enter an existing conversation",
                    isPrimary: false,
                    action: onJoinRoom
                )
            }
            .padding(.horizontal, 20)
            .opacity(showButtons ? 1 : 0)
            .offset(y: showButtons ? 0 : 30)
            
            Spacer()
            
            // Security info
            HStack(spacing: 40) {
                SecurityItem(icon: "🔒", label: "Encrypted")
                SecurityItem(icon: "⏱️", label: "Temporary")
                SecurityItem(icon: "🙈", label: "Anonymous")
            }
            .opacity(showButtons ? 1 : 0)
            
            Spacer()
            
            // Premium badge
            HStack {
                Spacer()
                Text("v2.0 Premium")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).delay(0.2)) {
                showFeaturePills = true
            }
            withAnimation(.easeInOut(duration: 0.6).delay(0.4)) {
                showButtons = true
            }
        }
    }
}

struct FeaturePill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isPrimary: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isPrimary ? .blue : .white)
                    .frame(width: 32, height: 32)
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isPrimary ? .blue : .white)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isPrimary ? .blue.opacity(0.7) : .white.opacity(0.7))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isPrimary ? Color.white : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isPrimary ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(
                        color: isPrimary ? .blue.opacity(0.3) : .clear,
                        radius: isPrimary ? 10 : 0,
                        x: 0,
                        y: isPrimary ? 4 : 0
                    )
            )
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

struct SecurityItem: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.title2)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    HomeView(
        onCreateRoom: {},
        onJoinRoom: {}
    )
    .background(Color.black)
} 