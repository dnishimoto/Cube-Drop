//
//  LaserSlashGame.swift
//  Laser + slash arcade game on a 16x16x1 grid of cubes.
//
//  Grid layout: 16 columns x 16 rows x 1 depth of "cube slots" arranged
//  as a flat wall. Each slot holds a randomly chosen shape (sphere,
//  pyramid, cylinder, torus). A laser turret slides left/right along the
//  bottom and fires upward on tap, popping the shape out of its cube.
//  Freed shapes fall under gravity; swipe across them to "slash" for
//  points before they hit the ground. Spheres are a penalty, everything
//  else scores. Slots respawn a new random shape after a short delay.
//
//  Drop this file into your project as-is. Present `ContentView()` from
//  your App entry point, or embed `GameView` directly in your own UI.
//
//  NOTE on physics: the laser bolt is a kinematic body driven by an
//  SCNAction. SceneKit re-samples kinematic transforms every physics
//  step, so contact detection against the static cube shapes works in
//  practice, but if you see missed hits at high fire rates, switch the
//  bolt to a `.dynamic` body with an applied velocity instead of an
//  SCNAction — that integrates with the physics stepping more reliably.
//

import SwiftUI
import SceneKit
import UIKit
import Combine

// MARK: - Physics Categories

struct PhysicsCategory {
    static let none: Int         = 0
    static let laserBolt: Int    = 1 << 0
    static let cubeShape: Int    = 1 << 1
    static let fallingShape: Int = 1 << 2
    static let ground: Int       = 1 << 3
}

// MARK: - Shape Type

enum ShapeType: CaseIterable {
    case sphere
    case pyramid
    case cylinder
    case torus

    /// Points awarded (or deducted) when this shape is slashed.
    var points: Int {
        switch self {
        case .sphere:   return -15   // penalty
        case .pyramid:  return 10
        case .cylinder: return 15
        case .torus:    return 20
        }
    }

    var color: UIColor {
        switch self {
        case .sphere:   return .systemRed
        case .pyramid:  return .systemYellow
        case .cylinder: return .systemGreen
        case .torus:    return .systemPurple
        }
    }

    func geometry(size: CGFloat) -> SCNGeometry {
        switch self {
        case .sphere:
            return SCNSphere(radius: size * 0.4)
        case .pyramid:
            return SCNPyramid(width: size * 0.7, height: size * 0.8, length: size * 0.7)
        case .cylinder:
            return SCNCylinder(radius: size * 0.32, height: size * 0.75)
        case .torus:
            return SCNTorus(ringRadius: size * 0.3, pipeRadius: size * 0.12)
        }
    }
}

// MARK: - Cube Slot

/// One cell in the 16x16x1 grid. Owns the (static, non-physics) container
/// node and, while loaded, the shape node living inside it.
final class CubeSlot {
    let column: Int
    let row: Int
    let containerNode: SCNNode

    var shapeNode: SCNNode?
    var isLoaded: Bool = false
    var isRespawning: Bool = false

    init(column: Int, row: Int, containerNode: SCNNode) {
        self.column = column
        self.row = row
        self.containerNode = containerNode
    }
}

// MARK: - Game State (SwiftUI-facing)

final class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var combo: Int = 0
}

// MARK: - Game View Controller

final class GameViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {

    // MARK: Config

    let gridWidth = 16
    let gridHeight = 16
    let cubeSize: CGFloat = 0.5
    let cubeSpacing: CGFloat = 0.06
    let groundY: Float = -6.0
    let wallZ: Float = 0.0

    var gameState: GameState!

    // MARK: Scene

    var sceneView: SCNView!
    var scene: SCNScene!
    var cameraNode: SCNNode!
    var laserNode: SCNNode!

    var slots: [[CubeSlot]] = []   // slots[row][column]

    var gridOriginX: Float = 0
    var gridOriginY: Float = 0
    var wallBottomY: Float = 0

    var laserColumn: Int = 8
    var isFiring = false

    enum PanMode { case none, laser, slash }
    var currentPanMode: PanMode = .none

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        wallBottomY = groundY + 3.0

        setupScene()
        setupLighting()
        setupGrid()
        setupCamera()
        setupLaser()
        setupGround()
        setupGestures()

        scene.physicsWorld.contactDelegate = self
        scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        sceneView.delegate = self
    }

    // MARK: Scene / Camera / Lighting

    func setupScene() {
        scene = SCNScene()

        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.scene = scene
        sceneView.backgroundColor = .black
        sceneView.allowsCameraControl = false
        sceneView.antialiasingMode = .multisampling4X
        view.addSubview(sceneView)
    }

    func setupCamera() {
        cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 50
        camera.zFar = 100
        cameraNode.camera = camera

        let pitch = Float(cubeSize + cubeSpacing)
        let centerY = wallBottomY + Float(gridHeight) / 2 * pitch
        cameraNode.position = SCNVector3(0, centerY, 16)
        cameraNode.look(at: SCNVector3(0, centerY - 2, 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    func setupLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.35, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.color = UIColor.white
        directional.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(directional)
    }

    // MARK: Grid Setup

    func setupGrid() {
        slots = []
        let pitch = cubeSize + cubeSpacing
        let totalWidth = CGFloat(gridWidth) * pitch
        gridOriginX = -Float(totalWidth) / 2 + Float(pitch) / 2
        gridOriginY = wallBottomY

        for row in 0..<gridHeight {
            var rowSlots: [CubeSlot] = []
            for col in 0..<gridWidth {
                let x = gridOriginX + Float(col) * Float(pitch)
                let y = gridOriginY + Float(row) * Float(pitch)

                let containerNode = SCNNode()
                containerNode.position = SCNVector3(x, y, wallZ)
                containerNode.name = "container_\(row)_\(col)"

                let wireframe = makeWireframeCube(size: cubeSize, color: UIColor.white.withAlphaComponent(0.18))
                containerNode.addChildNode(wireframe)

                scene.rootNode.addChildNode(containerNode)

                let slot = CubeSlot(column: col, row: row, containerNode: containerNode)
                rowSlots.append(slot)
                loadShape(into: slot)
            }
            slots.append(rowSlots)
        }
    }

    /// Builds a thin-line wireframe cube using SceneKit's `.line` primitive type.
    func makeWireframeCube(size: CGFloat, color: UIColor) -> SCNNode {
        let s = Float(size) / 2
        let vertices: [SCNVector3] = [
            SCNVector3(-s, -s, -s), SCNVector3(s, -s, -s), SCNVector3(s, s, -s), SCNVector3(-s, s, -s),
            SCNVector3(-s, -s,  s), SCNVector3(s, -s,  s), SCNVector3(s, s,  s), SCNVector3(-s, s,  s)
        ]
        let indices: [Int32] = [
            0,1, 1,2, 2,3, 3,0,
            4,5, 5,6, 6,7, 7,4,
            0,4, 1,5, 2,6, 3,7
        ]
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.lightingModel = .constant
        return SCNNode(geometry: geometry)
    }

    // MARK: Shape Load / Respawn

    func loadShape(into slot: CubeSlot) {
        let type = ShapeType.allCases.randomElement()!
        let geo = type.geometry(size: cubeSize)
        geo.firstMaterial?.diffuse.contents = type.color
        geo.firstMaterial?.emission.contents = type.color.withAlphaComponent(0.35)

        let node = SCNNode(geometry: geo)
        node.name = "shape_\(slot.row)_\(slot.column)"
        node.position = SCNVector3(0, 0, 0)
        node.scale = SCNVector3(0.01, 0.01, 0.01)

        let body = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: geo, options: nil))
        body.categoryBitMask = PhysicsCategory.cubeShape
        body.contactTestBitMask = PhysicsCategory.laserBolt
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body

        slot.containerNode.addChildNode(node)
        slot.shapeNode = node
        slot.isLoaded = true

        node.runAction(.scale(to: 1.0, duration: 0.25))
    }

    func scheduleRespawn(for slot: CubeSlot) {
        guard !slot.isRespawning else { return }
        slot.isRespawning = true
        let delay = Double.random(in: 1.5...3.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            slot.isRespawning = false
            self.loadShape(into: slot)
        }
    }

    // MARK: Laser

    func setupLaser() {
        let pitch = Float(cubeSize + cubeSpacing)
        let laserGeo = SCNBox(width: cubeSize * 0.8, height: cubeSize * 0.3, length: cubeSize * 0.8, chamferRadius: 0.05)
        laserGeo.firstMaterial?.diffuse.contents = UIColor.cyan
        laserGeo.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.6)

        laserNode = SCNNode(geometry: laserGeo)
        let startX = gridOriginX + Float(laserColumn) * pitch
        laserNode.position = SCNVector3(startX, groundY + 0.6, wallZ)
        scene.rootNode.addChildNode(laserNode)
    }

    func moveLaser(toScreenX x: CGFloat) {
        let fraction = max(0, min(1, x / sceneView.bounds.width))
        let column = Int(fraction * CGFloat(gridWidth))
        laserColumn = max(0, min(gridWidth - 1, column))

        let pitch = Float(cubeSize + cubeSpacing)
        let targetX = gridOriginX + Float(laserColumn) * pitch

        laserNode.removeAllActions()
        let dx = CGFloat(targetX - laserNode.position.x)
        laserNode.runAction(.moveBy(x: dx, y: 0, z: 0, duration: 0.05))
    }

    func fireLaser() {
        let boltGeo = SCNCylinder(radius: 0.035, height: 0.4)
        boltGeo.firstMaterial?.diffuse.contents = UIColor.cyan
        boltGeo.firstMaterial?.emission.contents = UIColor.cyan

        let bolt = SCNNode(geometry: boltGeo)
        bolt.name = "laserBolt"
        bolt.position = laserNode.position
        bolt.position.y += 0.3

        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: boltGeo, options: nil))
        body.categoryBitMask = PhysicsCategory.laserBolt
        body.contactTestBitMask = PhysicsCategory.cubeShape
        body.collisionBitMask = PhysicsCategory.none
        bolt.physicsBody = body

        scene.rootNode.addChildNode(bolt)

        let pitch = Float(cubeSize + cubeSpacing)
        let topY = wallBottomY + Float(gridHeight) * pitch + 1.0
        let travel = CGFloat(topY - bolt.position.y)

        let move = SCNAction.moveBy(x: 0, y: travel, z: 0, duration: 0.5)
        let remove = SCNAction.removeFromParentNode()
        bolt.runAction(.sequence([move, remove]))
    }

    // MARK: Release / Falling / Landing

    func releaseShape(shapeNode: SCNNode) {
        guard let name = shapeNode.name, name.hasPrefix("shape_") else { return }
        let parts = name.split(separator: "_")
        guard parts.count == 3, let row = Int(parts[1]), let col = Int(parts[2]),
              row < slots.count, col < slots[row].count else { return }
        let slot = slots[row][col]

        let worldTransform = shapeNode.worldTransform
        shapeNode.removeFromParentNode()
        shapeNode.transform = worldTransform
        scene.rootNode.addChildNode(shapeNode)

        guard let geo = shapeNode.geometry else { return }
        let shape = SCNPhysicsShape(geometry: geo, options: nil)
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.categoryBitMask = PhysicsCategory.fallingShape
        body.contactTestBitMask = PhysicsCategory.ground
        body.collisionBitMask = PhysicsCategory.ground
        body.mass = 1.0
        body.angularVelocity = SCNVector4(Float.random(in: -1...1),
                                           Float.random(in: -1...1),
                                           Float.random(in: -1...1),
                                           Float.random(in: 2...4))
        shapeNode.physicsBody = body

        slot.shapeNode = nil
        slot.isLoaded = false
        scheduleRespawn(for: slot)
    }

    func handleShapeLanded(_ node: SCNNode) {
        node.removeFromParentNode()
        DispatchQueue.main.async { [weak self] in
            self?.gameState.combo = 0
        }
    }

    // MARK: Slash

    func shapeType(for node: SCNNode) -> ShapeType? {
        switch node.geometry {
        case is SCNSphere:   return .sphere
        case is SCNPyramid:  return .pyramid
        case is SCNCylinder: return .cylinder
        case is SCNTorus:    return .torus
        default: return nil
        }
    }

    func performSlash(at point: CGPoint) {
        let hits = sceneView.hitTest(point, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
        for hit in hits {
            let node = hit.node
            guard let name = node.name, name.hasPrefix("shape_") else { continue }
            guard node.physicsBody?.categoryBitMask == PhysicsCategory.fallingShape else { continue }
            scoreSlash(node: node)
        }
    }

    func scoreSlash(node: SCNNode) {
        guard let type = shapeType(for: node) else { return }
        node.physicsBody = nil
        node.removeFromParentNode()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.gameState.score += type.points
            if type == .sphere {
                self.gameState.combo = 0
            } else {
                self.gameState.combo += 1
            }
        }
    }

    // MARK: Ground

    func setupGround() {
        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.firstMaterial?.diffuse.contents = UIColor.darkGray

        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, groundY, 0)

        let body = SCNPhysicsBody(type: .static,
                                   shape: SCNPhysicsShape(geometry: SCNBox(width: 200, height: 0.1, length: 200, chamferRadius: 0), options: nil))
        body.categoryBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.fallingShape
        body.collisionBitMask = PhysicsCategory.fallingShape
        floorNode.physicsBody = body

        scene.rootNode.addChildNode(floorNode)
    }

    // MARK: Gestures

    func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sceneView.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tap)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        fireLaser()
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        switch gesture.state {
        case .began:
            // Bottom quarter of the screen = drag the laser. Anywhere else = slash.
            currentPanMode = location.y > sceneView.bounds.height * 0.75 ? .laser : .slash
        case .changed:
            switch currentPanMode {
            case .laser:
                moveLaser(toScreenX: location.x)
            case .slash:
                performSlash(at: location)
            case .none:
                break
            }
        case .ended, .cancelled:
            currentPanMode = .none
        default:
            break
        }
    }

    // MARK: Physics Contacts

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let a = contact.nodeA
        let b = contact.nodeB

        if a.name == "laserBolt" || b.name == "laserBolt" {
            let bolt = a.name == "laserBolt" ? a : b
            let other = a.name == "laserBolt" ? b : a
            bolt.removeFromParentNode()
            releaseShape(shapeNode: other)
            return
        }

        let aIsFalling = a.physicsBody?.categoryBitMask == PhysicsCategory.fallingShape
        let bIsFalling = b.physicsBody?.categoryBitMask == PhysicsCategory.fallingShape
        if aIsFalling || bIsFalling {
            handleShapeLanded(aIsFalling ? a : b)
        }
    }

    // MARK: Per-frame safety cleanup

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, name.hasPrefix("shape_"),
                  node.physicsBody?.categoryBitMask == PhysicsCategory.fallingShape else { return }
            if node.presentation.position.y < self.groundY - 5 {
                node.removeFromParentNode()
            }
        }
    }
}

// MARK: - SwiftUI Bridge

struct GameView: UIViewControllerRepresentable {
    @ObservedObject var gameState: GameState

    func makeUIViewController(context: Context) -> GameViewController {
        let vc = GameViewController()
        vc.gameState = gameState
        return vc
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}

// MARK: - SwiftUI HUD

struct ContentView: View {
    @StateObject private var gameState = GameState()

    var body: some View {
        ZStack(alignment: .top) {
            GameView(gameState: gameState)
                .ignoresSafeArea()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score: \(gameState.score)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Combo: \(gameState.combo)")
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                }
                .padding()
                Spacer()
            }
            .padding(.top, 40)

            VStack {
                Spacer()
                Text("Drag bottom to move laser · Tap to fire · Swipe shapes to slash")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 24)
            }
        }
        .background(Color.black)
    }
}
