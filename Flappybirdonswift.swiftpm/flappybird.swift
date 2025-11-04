import SwiftUI
import Combine

// MARK: - Game Models
struct Bird {
    var position: CGPoint
    var velocity: CGFloat = 0
    let size: CGFloat = 40
}

struct Pipe {
    var x: CGFloat
    let gapY: CGFloat
    let gapHeight: CGFloat = 200
    let width: CGFloat = 80
    var passed: Bool = false
}

// MARK: - Game State
class GameState: ObservableObject {
    @Published var bird: Bird
    @Published var pipes: [Pipe] = []
    @Published var score: Int = 0
    @Published var gameOver: Bool = false
    @Published var gameStarted: Bool = false
    
    let screenWidth: CGFloat = 820
    let screenHeight: CGFloat = 1180
    let gravity: CGFloat = 0.8
    let jumpVelocity: CGFloat = -15
    
    private var timer: Timer?
    private var pipeTimer: Timer?
    
    init() {
        bird = Bird(position: CGPoint(x: 200, y: screenHeight / 2))
    }
    
    func startGame() {
        gameStarted = true
        gameOver = false
        score = 0
        bird = Bird(position: CGPoint(x: 200, y: screenHeight / 2))
        pipes = []
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            self.updateGame()
        }
        
        pipeTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            self.addPipe()
        }
    }
    
    func jump() {
        if !gameStarted {
            startGame()
        } else if !gameOver {
            bird.velocity = jumpVelocity
        }
    }
    
    func resetGame() {
        gameStarted = false
        gameOver = false
        score = 0
        bird = Bird(position: CGPoint(x: 200, y: screenHeight / 2))
        pipes = []
        timer?.invalidate()
        pipeTimer?.invalidate()
    }
    
    private func updateGame() {
        guard !gameOver else { return }
        
        // Update bird
        bird.velocity += gravity
        bird.position.y += bird.velocity
        
        // Check bounds
        if bird.position.y <= 0 || bird.position.y >= screenHeight - bird.size {
            endGame()
            return
        }
        
        // Update pipes
        for i in 0..<pipes.count {
            pipes[i].x -= 4
            
            // Check if bird passed pipe
            if !pipes[i].passed && pipes[i].x + pipes[i].width < bird.position.x {
                pipes[i].passed = true
                score += 1
            }
            
            // Check collision
            if checkCollision(pipe: pipes[i]) {
                endGame()
                return
            }
        }
        
        // Remove off-screen pipes
        pipes.removeAll { $0.x < -100 }
    }
    
    private func addPipe() {
        let minGapY: CGFloat = 300
        let maxGapY = screenHeight - 300
        let randomGapY = CGFloat.random(in: minGapY...maxGapY)
        
        let pipe = Pipe(x: screenWidth, gapY: randomGapY)
        pipes.append(pipe)
    }
    
    private func checkCollision(pipe: Pipe) -> Bool {
        let birdRect = CGRect(
            x: bird.position.x,
            y: bird.position.y,
            width: bird.size,
            height: bird.size
        )
        
        let topPipeRect = CGRect(
            x: pipe.x,
            y: 0,
            width: pipe.width,
            height: pipe.gapY - pipe.gapHeight / 2
        )
        
        let bottomPipeRect = CGRect(
            x: pipe.x,
            y: pipe.gapY + pipe.gapHeight / 2,
            width: pipe.width,
            height: screenHeight - (pipe.gapY + pipe.gapHeight / 2)
        )
        
        return birdRect.intersects(topPipeRect) || birdRect.intersects(bottomPipeRect)
    }
    
    private func endGame() {
        gameOver = true
        timer?.invalidate()
        pipeTimer?.invalidate()
    }
}

// MARK: - Bird View
struct BirdView: View {
    let bird: Bird
    let rotation: Double
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [.yellow, .orange]),
                    center: .center,
                    startRadius: 5,
                    endRadius: 20
                )
            )
            .frame(width: bird.size, height: bird.size)
            .overlay(
                HStack(spacing: 8) {
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .fill(.black)
                                .frame(width: 6, height: 6)
                        )
                }
                .offset(x: 8, y: -5)
            )
            .overlay(
                Triangle()
                    .fill(.orange)
                    .frame(width: 15, height: 10)
                    .offset(x: 25, y: 0)
            )
            .rotationEffect(.degrees(rotation))
            .position(bird.position)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Pipe View
struct PipeView: View {
    let pipe: Pipe
    let screenHeight: CGFloat
    
    var body: some View {
        ZStack {
            // Top pipe
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.green, Color.green.opacity(0.7)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: pipe.width, height: pipe.gapY - pipe.gapHeight / 2)
                .border(.green.opacity(0.5), width: 3)
                .position(x: pipe.x + pipe.width / 2, y: (pipe.gapY - pipe.gapHeight / 2) / 2)
            
            // Bottom pipe
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.green, Color.green.opacity(0.7)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: pipe.width,
                    height: screenHeight - (pipe.gapY + pipe.gapHeight / 2)
                )
                .border(.green.opacity(0.5), width: 3)
                .position(
                    x: pipe.x + pipe.width / 2,
                    y: pipe.gapY + pipe.gapHeight / 2 + (screenHeight - (pipe.gapY + pipe.gapHeight / 2)) / 2
                )
        }
    }
}

// MARK: - Main Game View
struct FlappyBirdGame: View {
    @StateObject private var gameState = GameState()
    
    var birdRotation: Double {
        min(max(Double(gameState.bird.velocity) * 3, -45), 90)
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.cyan.opacity(0.6), Color.blue.opacity(0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Clouds
            ForEach(0..<5) { i in
                Cloud()
                    .offset(x: CGFloat(i) * 200 - 100, y: CGFloat(i) * 100 + 50)
            }
            
            // Pipes
            ForEach(gameState.pipes.indices, id: \.self) { index in
                PipeView(pipe: gameState.pipes[index], screenHeight: gameState.screenHeight)
            }
            
            // Bird
            BirdView(bird: gameState.bird, rotation: birdRotation)
            
            // Score
            VStack {
                Text("\(gameState.score)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    .padding(.top, 60)
                
                Spacer()
            }
            
            // Start screen
            if !gameState.gameStarted {
                VStack(spacing: 30) {
                    Text("Flappy Bird")
                        .font(.system(size: 70, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    
                    Text("Tocca per iniziare")
                        .font(.system(size: 35, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                }
            }
            
            // Game Over screen
            if gameState.gameOver {
                VStack(spacing: 40) {
                    Text("Game Over")
                        .font(.system(size: 70, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    
                    VStack(spacing: 15) {
                        Text("Punteggio: \(gameState.score)")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        gameState.resetGame()
                    }) {
                        Text("Riprova")
                            .font(.system(size: 35, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 50)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.green)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.black.opacity(0.7))
                )
            }
        }
        .frame(width: gameState.screenWidth, height: gameState.screenHeight)
        .onTapGesture {
            gameState.jump()
        }
    }
}

struct Cloud: View {
    var body: some View {
        HStack(spacing: -20) {
            Circle()
                .fill(.white.opacity(0.7))
                .frame(width: 60, height: 60)
            Circle()
                .fill(.white.opacity(0.7))
                .frame(width: 80, height: 80)
            Circle()
                .fill(.white.opacity(0.7))
                .frame(width: 60, height: 60)
        }
    }
}

// MARK: - App Entry Point
@main
struct FlappyBirdApp: App {
    var body: some Scene {
        WindowGroup {
            FlappyBirdGame()
        }
    }
}
