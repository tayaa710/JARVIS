import SwiftUI

// MARK: - Particle State

struct ParticleState {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
}

// MARK: - Particle Field View

/// Ambient background particle effect: 40 tiny blue dots drifting slowly.
struct ParticleFieldView: View {

    static let particleCount = 40

    @State private var particles: [ParticleState] = ParticleFieldView.makeInitialParticles(
        count: ParticleFieldView.particleCount,
        size: CGSize(width: 380, height: 600)
    )

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { ctx, size in
                    for particle in particles {
                        let rect = CGRect(x: particle.x - 1, y: particle.y - 1, width: 2, height: 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(JARVISTheme.jarvisBlue15))
                    }
                }
                .onChange(of: timeline.date) { _, _ in
                    let w = geo.size.width
                    let h = geo.size.height
                    for i in particles.indices {
                        particles[i].x += particles[i].vx
                        particles[i].y += particles[i].vy
                        particles[i] = ParticleFieldView.wrapped(particle: particles[i], width: w, height: h)
                    }
                }
            }
        }
    }

    // MARK: - Testable Static Helpers

    static func makeInitialParticles(count: Int, size: CGSize) -> [ParticleState] {
        (0..<count).map { _ in
            ParticleState(
                x: CGFloat.random(in: 0..<max(size.width, 1)),
                y: CGFloat.random(in: 0..<max(size.height, 1)),
                vx: CGFloat.random(in: -0.3...0.3),
                vy: CGFloat.random(in: -0.3...0.3)
            )
        }
    }

    static func wrapped(particle: ParticleState, width: CGFloat, height: CGFloat) -> ParticleState {
        var p = particle
        if p.x > width  { p.x = 0 }
        if p.x < 0      { p.x = width }
        if p.y > height { p.y = 0 }
        if p.y < 0      { p.y = height }
        return p
    }
}
