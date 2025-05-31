import SwiftUI

struct ParticleBackgroundView: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .blue.opacity(particle.opacity),
                                    .cyan.opacity(particle.opacity * 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: particle.blur)
                }
            }
        }
        .onAppear {
            setupParticles()
            startAnimation()
        }
    }
    
    private func setupParticles() {
        particles = (0..<20).map { _ in
            Particle(
                x: Double.random(in: 0...UIScreen.main.bounds.width),
                y: Double.random(in: 0...UIScreen.main.bounds.height),
                size: Double.random(in: 4...12),
                opacity: Double.random(in: 0.1...0.4),
                blur: Double.random(in: 1...3),
                duration: Double.random(in: 15...25)
            )
        }
    }
    
    private func startAnimation() {
        for i in particles.indices {
            animateParticle(at: i)
        }
    }
    
    private func animateParticle(at index: Int) {
        let particle = particles[index]
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        withAnimation(
            .linear(duration: particle.duration)
            .repeatForever(autoreverses: false)
        ) {
            particles[index].x = Double.random(in: -50...screenWidth + 50)
            particles[index].y = Double.random(in: -50...screenHeight + 50)
        }
        
        // Opacity pulsing
        withAnimation(
            .easeInOut(duration: Double.random(in: 3...6))
            .repeatForever(autoreverses: true)
        ) {
            particles[index].opacity = Double.random(in: 0.05...0.3)
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    let size: Double
    var opacity: Double
    let blur: Double
    let duration: Double
}

#Preview {
    ParticleBackgroundView()
        .background(Color.black)
} 