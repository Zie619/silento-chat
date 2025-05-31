import SwiftUI

struct LoadingView: View {
    @State private var progress: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo section
            VStack(spacing: 20) {
                // Main logo
                Text("Silento")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                
                // Subtitle
                Text("Secure Messaging")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(textOpacity)
            }
            
            Spacer()
            
            // Loading section
            VStack(spacing: 24) {
                // Progress bar
                VStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        
                        // Progress bar
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: CGFloat(progress) * 280, height: 8)
                            .shadow(color: .blue.opacity(0.5), radius: 4)
                    }
                    .frame(width: 280)
                }
                
                // Loading text
                Text("Initializing secure connection...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(textOpacity)
            }
            
            Spacer()
        }
        .onAppear {
            startLoadingAnimation()
        }
    }
    
    private func startLoadingAnimation() {
        // Text fade in
        withAnimation(.easeInOut(duration: 0.8)) {
            textOpacity = 1.0
        }
        
        // Progress bar animation
        withAnimation(.easeInOut(duration: 1.5)) {
            progress = 1.0
        }
    }
}

#Preview {
    LoadingView()
        .background(Color.black)
} 