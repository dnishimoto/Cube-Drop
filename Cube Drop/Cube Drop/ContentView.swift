/*
 Knowledge and Behavior Specification

 The game world is built around a defensive cube structure that separates the player from an advancing group of enemies. The player controls a laser weapon capable of detecting and destroying any destructible object in the environment. Every object in the game has a defined knowledge set, including its movement rules, collision responses, weaknesses, and interactions with other objects. The game engine uses these behaviors to create an intelligent battlefield where enemies react to the changing cube structure and player actions.

 The **player** is positioned at the bottom of the arena and serves as the primary survival objective. The player is protected by the cube field, which acts as a defensive barrier. The player's laser is a universal weapon system that can detect and destroy all hostile objects and special objects. When the laser contacts an object, the object determines its own destruction behavior. A cube creates a falling point object, a missile explodes, a UFO awards a large score bonus, a centipede segment creates a mushroom, and special enemies trigger their own effects. Every laser impact creates visual feedback through explosions, particles, and sound effects.

 The **cube grid** is the primary defensive structure. Cubes begin arranged in a formation above the player and gradually descend toward the ground. Their movement speed is controlled by the difficulty system and increases as the player's score increases. Each cube has collision awareness and can detect laser impacts, enemy interactions, and ground proximity. When a player's laser destroys a cube, the cube disappears and is replaced at the exact impact location by a falling point object. These point objects fall under gravity, have no reflective behavior, and are removed when they pass below the ground boundary. If a cube reaches the player ground level, the defensive wall has failed and the game ends. When all cubes in the field have been destroyed, the cube grid rebuilds itself and the game continues with increased difficulty.

 The **point object system** creates the reward mechanism of the game. Normal point objects are generated from destroyed cubes and fall through the battlefield. Players can collect or interact with these objects for score opportunities. Bonus point objects are rare special objects that provide a powerful reward. When the player destroys a bonus object, it activates a burst effect that destroys all nearby point objects within a defined radius, creating a chain reaction and a large score increase. Bonus objects create strategic decisions because the player must decide whether to target immediate threats or pursue a larger reward.

 The **flying saucer (UFO)** is an airborne enemy that operates above the cube field. It moves horizontally across the upper portion of the sky and is not blocked by cubes. The UFO periodically launches enemy missiles toward the player. The UFO has its own movement pattern, changing direction when it reaches the edge of the arena. When hit by the player's laser, the UFO is destroyed, creates a large explosion, plays a sound effect, and awards bonus points.

 The **enemy missile** is a direct threat to the player. Missiles originate from the UFO and travel downward toward the player's location. A missile is designed specifically as an anti-player weapon and does not damage the cube structure. Cubes act as a protective shield against missiles. If a missile encounters a cube, it cannot pass through it and cannot destroy it. Instead, the missile is blocked and explodes. If the missile successfully reaches the player, it causes damage or immediately triggers game over depending on the selected game mode. The player's laser can destroy missiles before they reach the cube wall or player.

 The **centipede enemy** is a six-segment intelligent crawling enemy consisting of one head and five body segments. The centipede moves through the cube field by following available paths. It does not simply move directly toward the player; it analyzes openings and obstacles within the cube structure. When mushrooms appear, the centipede recognizes them as obstacles and changes direction to navigate around them. Each segment can be destroyed independently by the player's laser. When a segment is destroyed, a mushroom is created at that location, changing the future movement path of the remaining centipede segments.

 The **mushroom object** is both an obstacle and a tactical object. Mushrooms are created when the player destroys centipede segments. They remain in the arena and influence enemy movement by blocking paths. The centipede AI must calculate alternative routes around mushrooms. The player can destroy mushrooms with the laser to clear paths and reduce enemy advantages. Mushrooms create a changing battlefield where player decisions affect enemy navigation.

 The **grasshopper enemy** uses a unique cube-based movement system. Unlike flying enemies, grasshoppers cannot freely move through the air. They must jump from cube to cube while searching for a path toward the player. The grasshopper analyzes nearby cubes and determines which cubes are reachable based on its maximum jump distance and jump height. It selects the safest and most efficient path toward the player. If no reachable cube exists, the grasshopper attempts a leap and falls. If it reaches the ground without landing on a cube, it disappears. The grasshopper becomes more dangerous as the cube structure weakens because fewer cubes create fewer defensive routes for the player.

 The **spider enemy** attacks using vertical movement rather than cube navigation. Spiders enter through openings above the battlefield and descend slowly on a visible thread. They search for openings in the cube structure and move downward toward the player. The thread creates a visual warning system, allowing the player to react. If the spider reaches the player, it causes a game-ending attack. The player can destroy the spider or break the threat by hitting it with the laser.

 The **ladybug enemy** is a slower but valuable target. Ladybugs descend gradually from the upper battlefield while drifting horizontally. They are designed to create moments where the player chooses between attacking immediate threats and collecting bonus rewards. Destroying a ladybug provides increased points and may release bonus objects or special rewards.

 The **difficulty system** controls the intelligence and pressure of the game. As the player score increases, the system increases cube descent speed, enemy spawn frequency, enemy movement speed, and attack patterns. The goal is to create a continuously increasing challenge where the player's skill determines survival time. Higher scores represent not only player success but also increased environmental danger.

 The **sound and effects system** provides feedback for every important action. Laser firing, cube destruction, missile impacts, enemy destruction, bonus activation, explosions, and game-over events each have unique sounds. Particle systems and visual effects communicate impacts and rewards. The result is a dynamic arcade environment where every object has a purpose, every enemy follows specific rules, and the battlefield evolves based on player decisions.

 The overall intelligence model is based on three principles: the player laser is universal, the cube field is a changing defensive terrain, and enemies use specialized behaviors rather than simple movement patterns. The combination of pathfinding, collision awareness, adaptive difficulty, and object-specific behaviors creates a living battlefield that continuously changes as the player fights for survival.

 */

import SwiftUI
import SceneKit
import UIKit
import Combine
import AudioToolbox

//======================================================================
// SOUND SYSTEM
// Lightweight wrapper around iOS system sounds so every important
// action gets audible feedback without needing bundled audio assets.
//======================================================================

enum GameSound: SystemSoundID {
    case laserFire      = 1104
    case cubeHit        = 1105
    case missileHit      = 1106
    case enemyDestroyed = 1111
    case bonus          = 1025
    case gameOver        = 1073
}

func playSound(_ id: SystemSoundID) {
    AudioServicesPlaySystemSound(id)
}


final class KnowledgeTree {

    enum EntityKind: String {

        case playerLaser
        case player

        case cube
        case pointObject
        case bonusPointObject

        case ufo
        case missile

        case centipedeHead
        case centipedeSegment

        case mushroom

        case grasshopper
        case spider
        case ladybug
    }


    enum Behavior {

        case blocksLaser
        case blocksMissile

        case destroyedByLaser
        case destroyedByMissile

        case fallsWithGravity

        case awardsScore(Int)

        case spawnsMushroom

        case burstOnDestroy(radius: Float)

        case causesGameOverOnContact

        case pathfindingObstacle

        case hostile
        case friendly
    }



    struct NodeProfile {

        let kind: EntityKind

        var behaviors: [Behavior]

        var scoreValue: Int = 0

        var weakness: [EntityKind] = []

        var canBeTargetedByLaser: Bool = false

        var blocks: [EntityKind] = []
    }



    private(set) var profiles:
        [EntityKind: NodeProfile] = [:]



    init() {


        //--------------------------------------------------
        // PLAYER LASER
        //--------------------------------------------------

        register(
            .playerLaser,
            behaviors: [
                .friendly
            ]
        )



        //--------------------------------------------------
        // PLAYER
        //--------------------------------------------------

        register(
            .player,
            behaviors: [
                .friendly
            ]
        )



        //--------------------------------------------------
        // CUBE
        // Destroyed cubes drop a falling point object (handled
        // explicitly in resolveHit, since the drop type is randomized
        // between normal / bonus / reward-enemy).
        //--------------------------------------------------

        register(
            .cube,
            behaviors: [
                .blocksLaser,
                .destroyedByLaser,
                .awardsScore(10)
            ],
            scoreValue: 10,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true,
            blocks: [
                .missile,
                .centipedeSegment,
                .grasshopper,
                .spider
            ]
        )



        //--------------------------------------------------
        // POINT OBJECT
        //--------------------------------------------------

        register(
            .pointObject,
            behaviors: [
                .fallsWithGravity,
                .destroyedByLaser,
                .awardsScore(5)
            ],
            scoreValue: 5,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // BONUS POINT OBJECT
        // Rare, high-value, bursts nearby point objects when destroyed.
        //--------------------------------------------------

        register(
            .bonusPointObject,
            behaviors: [
                .fallsWithGravity,
                .destroyedByLaser,
                .awardsScore(100),
                .burstOnDestroy(radius: 2.2)
            ],
            scoreValue: 100,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // UFO
        //--------------------------------------------------

        register(
            .ufo,
            behaviors: [
                .hostile,
                .destroyedByLaser,
                .awardsScore(300)
            ],
            scoreValue: 300,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // MISSILE
        //--------------------------------------------------

        register(
            .missile,
            behaviors: [
                .hostile,
                .destroyedByLaser
            ],
            scoreValue: 0,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // CENTIPEDE HEAD
        //--------------------------------------------------

        register(
            .centipedeHead,
            behaviors: [
                .hostile,
                .destroyedByLaser,
                .spawnsMushroom,
                .causesGameOverOnContact,
                .awardsScore(50)
            ],
            scoreValue: 50,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // CENTIPEDE SEGMENT
        //--------------------------------------------------

        register(
            .centipedeSegment,
            behaviors: [
                .hostile,
                .destroyedByLaser,
                .spawnsMushroom,
                .causesGameOverOnContact,
                .awardsScore(25)
            ],
            scoreValue: 25,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // MUSHROOM
        //--------------------------------------------------

        register(
            .mushroom,
            behaviors: [
                .pathfindingObstacle,
                .blocksLaser,
                .destroyedByLaser
            ],
            scoreValue: 0,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // GRASSHOPPER
        //--------------------------------------------------

        register(
            .grasshopper,
            behaviors: [
                .hostile,
                .destroyedByLaser,
                .causesGameOverOnContact,
                .awardsScore(80)
            ],
            scoreValue: 80,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // SPIDER
        //--------------------------------------------------

        register(
            .spider,
            behaviors: [
                .hostile,
                .destroyedByLaser,
                .causesGameOverOnContact,
                .awardsScore(120)
            ],
            scoreValue: 120,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // LADYBUG
        // Slower, valuable, non-lethal target.
        //--------------------------------------------------

        register(
            .ladybug,
            behaviors: [
                .hostile,
                .destroyedByLaser,
                .awardsScore(150)
            ],
            scoreValue: 150,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )
    }



    //--------------------------------------------------
    // Register entity
    //--------------------------------------------------

    private func register(
        _ kind: EntityKind,
        behaviors: [Behavior],
        scoreValue: Int = 0,
        weakness: [EntityKind] = [],
        canBeTargetedByLaser: Bool = false,
        blocks: [EntityKind] = []
    ) {

        profiles[kind] = NodeProfile(
            kind: kind,
            behaviors: behaviors,
            scoreValue: scoreValue,
            weakness: weakness,
            canBeTargetedByLaser: canBeTargetedByLaser,
            blocks: blocks
        )
    }



    //--------------------------------------------------
    // Lookup
    //--------------------------------------------------

    func profile(
        for kind: EntityKind
    ) -> NodeProfile? {

        profiles[kind]
    }
}

struct PhysicsCategory {
    static let none: Int = 0
    static let laser: Int = 1 << 0
    static let cube: Int = 1 << 1
    // bonusPointObject reuses the pointObject category on purpose -
    // they behave identically at the physics layer (fall, get
    // removed on ground contact, targetable by laser). The
    // distinction that matters (score, burst-on-destroy) lives in
    // KnowledgeTree / EntityNode.kind, not in the physics category.
    static let pointObject: Int = 1 << 2
    static let ufo: Int = 1 << 3
    static let missile: Int = 1 << 4
    static let centipede: Int = 1 << 5
    static let mushroom: Int = 1 << 6
    static let grasshopper: Int = 1 << 7
    static let spider: Int = 1 << 8
    static let ladybug: Int = 1 << 9
    static let ground: Int = 1 << 10
    static let player: Int = 1 << 11
}

final class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var isGameOver: Bool = false
    @Published var difficulty: Double = 1.0
}

final class EntityNode: SCNNode {
    let kind: KnowledgeTree.EntityKind

    init(kind: KnowledgeTree.EntityKind, geometry: SCNGeometry? = nil) {
        self.kind = kind
        super.init()
        self.geometry = geometry
        self.name = kind.rawValue
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class GameViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate, UIGestureRecognizerDelegate {
    let knowledge = KnowledgeTree()
    var gameState: GameState

    var longPressFireTimer: Timer?
    var longPressFireInterval: TimeInterval = 0.10

    init(gameState: GameState) {
        self.gameState = gameState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    struct CubeSlot {
        let row: Int
        let col: Int
        let container: SCNNode
        var node: SCNNode?
        var isRespawning: Bool = false
    }

    var sceneView: SCNView!
    var scene: SCNScene!
    var cameraNode = SCNNode()
    
    func topOfGridY() -> Float {
    let pitch = Float(cubeSize + cubeSpacing)
    return groundY + 3.0 + Float(gridHeight - 1) * pitch
    }
    var pointObjectSpawnChance: Int = 18
    var centipedeFollowTarget: [ObjectIdentifier: SCNNode] = [:]
    var centipedeTrailSpacing: Float = 0.55

    var gridRoot = SCNNode()
    var enemyRoot = SCNNode()
    var effectsRoot = SCNNode()

    var slots: [[CubeSlot]] = []
    var slotMap: [ObjectIdentifier: (row: Int, col: Int)] = [:]

    var lastUpdateTime: TimeInterval = 0
    var lastFireTime: TimeInterval = 0

    var laserColumn: Int = 8
    var gridDirection: Float = 1
    var gridOffset: Float = 0
    var gridSpeed: Float = 0.18
    var gridMaxOffset: Float = 2.0

    var cubeSize: CGFloat = 0.5
    var cubeSpacing: CGFloat = 0.06
    var groundY: Float = -6.0
    var wallZ: Float = 0.0

    var gridWidth: Int = 16
    var gridHeight: Int = 4

    var autoFireEnabled: Bool = true
    var autoFireInterval: TimeInterval = 1.5
    var lastAutoFireTime: TimeInterval = 0

    var gameSessionID = UUID()

    var activeLasers: [SCNNode] = []

    var playerNode: SCNNode?
    
    // Visual platform that shows the player's firing base
    var platformNode: SCNNode?

    // Grasshopper AI state
    var grasshopperJumping = Set<ObjectIdentifier>()

    // Centipede AI state
    var centipedeDirection: [ObjectIdentifier: Float] = [:]
    var centipedeDropping = Set<ObjectIdentifier>()

    // Spider AI state
    var spiderAnchorY: [ObjectIdentifier: Float] = [:]
    var spiderThreads: [ObjectIdentifier: SCNNode] = [:]

    // Ladybug AI state
    var ladybugDirection: [ObjectIdentifier: Float] = [:]

    private var slashStartScreenPoint: CGPoint?
    private var slashEndScreenPoint: CGPoint?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupPlayer()
        setupPlayerPlatform()
        setupLighting()
        setupCamera()
        setupWorld()
        setupGrid()
        setupGestures()

        spawnGrasshopper()
        let headNode = spawnCentipedeHead(at: SCNVector3(-2.0, topOfGridY(), 0.0))
        spawnCentipedeSegment(at: SCNVector3(-2.0, topOfGridY(), 0.0), follow: headNode)
        
             spawnSpider()
        spawnLadybug()

        scene.physicsWorld.contactDelegate = self
        scene.physicsWorld.gravity = SCNVector3Zero
        sceneView.delegate = self
        sceneView.isPlaying = true
        sceneView.loops = true
    }

    func setupScene() {
        scene = SCNScene()

        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.scene = scene
        sceneView.backgroundColor = .black
        sceneView.allowsCameraControl = false
        sceneView.antialiasingMode = .multisampling4X
        view.addSubview(sceneView)

        scene.rootNode.addChildNode(gridRoot)
        scene.rootNode.addChildNode(enemyRoot)
        scene.rootNode.addChildNode(effectsRoot)
    }
    func setupPlayer() {

        let geo = SCNCapsule(
            capRadius: 0.25,
            height: 0.8
        )

        geo.firstMaterial?.diffuse.contents = UIColor.cyan
        geo.firstMaterial?.emission.contents = UIColor.cyan

        let player = EntityNode(
            kind: .player,
            geometry: geo
        )

        player.name = "player"

        player.position = SCNVector3(
            0,
            groundY + 0.4,
            wallZ
        )

        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(
                geometry: geo,
                options: nil
            )
        )

        body.categoryBitMask = PhysicsCategory.player

        body.contactTestBitMask =
            PhysicsCategory.missile |
            PhysicsCategory.grasshopper |
            PhysicsCategory.spider |
            PhysicsCategory.centipede

        body.collisionBitMask = PhysicsCategory.none

        player.physicsBody = body

        // Save a reference for AI (grasshopper, spider, etc.)
        playerNode = player

        scene.rootNode.addChildNode(player)
    }
    
    func setupPlayerPlatform() {
        // A small base at ground level that tracks the laser's X position
        let width = CGFloat(cubeSize + cubeSpacing) * 0.9
        let height: CGFloat = 0.12
        let depth: CGFloat = 0.4
        let box = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.06)
        box.firstMaterial?.diffuse.contents = UIColor(white: 0.25, alpha: 1.0)
        box.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.6)
        box.firstMaterial?.lightingModel = .blinn

        let node = SCNNode(geometry: box)
        node.name = "playerPlatform"
        let x = laserWorldPosition().x
        node.position = SCNVector3(x, groundY + Float(height * 0.5), wallZ)
        node.renderingOrder = 10
        // purely visual; no physics body

        scene.rootNode.addChildNode(node)
        platformNode = node
    }

    func setupCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 50
        camera.zFar = 120
        cameraNode.camera = camera

        let centerY = groundY + 3.0 + Float(gridHeight) / 2 * Float(cubeSize + cubeSpacing)
        cameraNode.position = SCNVector3(0, centerY, 16)
        cameraNode.look(at: SCNVector3(0, centerY - 2, 0))

        scene.rootNode.addChildNode(cameraNode)
    }
    @discardableResult
    func spawnCentipedeHead(at worldPosition: SCNVector3) -> SCNNode {
        let size = cubeSize * 1.2
        let plane = makeLabelBillboard(text: "CH", color: .white, worldSize: size)
        let node = EntityNode(kind: .centipedeHead, geometry: plane)
        node.name = "CH"
        node.position = worldPosition
        node.renderingOrder = 100

        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.centipede
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.cube | PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        centipedeDirection[ObjectIdentifier(node)] = 1.0
        enemyRoot.addChildNode(node)
        return node
    }

    func spawnCentipedeSegment(at position: SCNVector3, follow target: SCNNode?) {
        let size = cubeSize * 1.2
        let plane = makeLabelBillboard(text: "CS", color: .white, worldSize: size)
        let node = EntityNode(kind: .centipedeSegment, geometry: plane)
        node.name = "CS"
        node.renderingOrder = 100

        if let target = target {
            let targetPos = target.presentation.worldPosition
            node.position = SCNVector3(targetPos.x - 1.0, targetPos.y, targetPos.z)
        } else {
            node.position = SCNVector3(position.x - 1.0, position.y, position.z)
        }

        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.centipede
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.cube | PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        centipedeDirection[ObjectIdentifier(node)] = Bool.random() ? 1.0 : -1.0
        if let target = target {
            centipedeFollowTarget[ObjectIdentifier(node)] = target
        }
        enemyRoot.addChildNode(node)
    }
    func spawnLadybug() {
        let size = cubeSize * 1.2
        let plane = makeLabelBillboard(text: "L", color: .white, worldSize: size)
        let node = EntityNode(kind: .ladybug, geometry: plane)
        node.name = "L"
        node.position = SCNVector3(5, groundY + 4, 0)
        node.renderingOrder = 100
        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.ladybug
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]
        ladybugDirection[ObjectIdentifier(node)] = Bool.random() ? 1.0 : -1.0
        enemyRoot.addChildNode(node)
    }

    func spawnLadybug(at worldPosition: SCNVector3) {
        let size = cubeSize * 1.2
        let plane = makeLabelBillboard(text: "L", color: .white, worldSize: size)
        let node = EntityNode(kind: .ladybug, geometry: plane)
        node.name = "L"
        node.position = worldPosition
        node.renderingOrder = 100
        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.ladybug
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]
        ladybugDirection[ObjectIdentifier(node)] = Bool.random() ? 1.0 : -1.0
        enemyRoot.addChildNode(node)
    }

    //---------------------------------------------------------
    // Picks an x position over a gap in the top row of cubes so
    // the spider looks like it is "entering through an opening".
    // Falls back to a random column if the top row is fully intact.
    //---------------------------------------------------------
    func topRowOpeningX() -> Float {
        let pitch = Float(cubeSize + cubeSpacing)
        let originX = -Float(gridWidth) * pitch / 2 + pitch / 2

        let row = gridHeight - 1
        if slots.indices.contains(row) {
            var openColumns: [Int] = []
            for col in 0..<slots[row].count {
                if slots[row][col].node == nil {
                    openColumns.append(col)
                }
            }
            if let col = openColumns.randomElement() {
                return originX + Float(col) * pitch
            }
        }

        let col = Int.random(in: 0..<max(gridWidth, 1))
        return originX + Float(col) * pitch
    }

    func spiderSpawnY() -> Float {
        groundY + 3.0 + Float(gridHeight) * Float(cubeSize + cubeSpacing) + 1.5
    }

    func spawnSpider() {
        let x = topRowOpeningX()
        spawnSpider(at: SCNVector3(x, spiderSpawnY(), wallZ))
    }

    func spawnSpider(at worldPosition: SCNVector3) {
        let size = cubeSize * 1.2
        let plane = makeLabelBillboard(text: "S", color: .white, worldSize: size)
        let node = EntityNode(kind: .spider, geometry: plane)
        node.name = "S"
        node.position = worldPosition
        node.renderingOrder = 100
        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.spider
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        spiderAnchorY[ObjectIdentifier(node)] = worldPosition.y

        enemyRoot.addChildNode(node)
    }

 
    func spawnRewardEnemy(at worldPosition: SCNVector3) {
        let safeY = min(worldPosition.y, topOfGridY() - 0.5)
        let safeX = max(-6.0, min(6.0, worldPosition.x))
        let spawnPoint = SCNVector3(safeX, safeY, worldPosition.z)

        let choice = Int.random(in: 0...2)
        switch choice {
        case 0:
            spawnSpider(at: spawnPoint)
        case 1:
            spawnLadybug(at: spawnPoint)
        default:
            let headNode = spawnCentipedeHead(at: spawnPoint)
            spawnCentipedeSegment(at: spawnPoint, follow: headNode)
        }
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

    func setupWorld() {
        let floor = SCNFloor()
        floor.firstMaterial?.diffuse.contents = UIColor.darkGray

        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, groundY, 0)

        let body = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: SCNBox(width: 200, height: 0.1, length: 200, chamferRadius: 0), options: nil))
        body.categoryBitMask = PhysicsCategory.ground

        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.missile |
            PhysicsCategory.pointObject

        body.collisionBitMask =
            PhysicsCategory.none

        floorNode.physicsBody = body

        scene.rootNode.addChildNode(floorNode)
    }

    func setupGrid() {
        slots.removeAll()
        slotMap.removeAll()

        let pitch = cubeSize + cubeSpacing
        let totalWidth = CGFloat(gridWidth) * pitch
        let originX = -Float(totalWidth) / 2 + Float(pitch) / 2
        let originY = groundY + 3.0

        for row in 0..<gridHeight {
            var rowSlots: [CubeSlot] = []

            for col in 0..<gridWidth {
                let x = originX + Float(col) * Float(pitch)
                let y = originY + Float(row) * Float(pitch)

                let container = SCNNode()
                container.position = SCNVector3(x, y, wallZ)
                container.name = "container_\(row)_\(col)"

                let wireframe = makeWireframeCube(size: cubeSize, color: UIColor.white.withAlphaComponent(0.18))
                wireframe.name = "wireframe"
                container.addChildNode(wireframe)

                gridRoot.addChildNode(container)

                var slot = CubeSlot(row: row, col: col, container: container, node: nil, isRespawning: false)
                rowSlots.append(slot)
                loadCube(into: &slot, animated: false)
                rowSlots[rowSlots.count - 1] = slot
            }

            slots.append(rowSlots)
        }
    }

    func makeWireframeCube(size: CGFloat, color: UIColor) -> SCNNode {
        let s = Float(size) / 2
        let vertices: [SCNVector3] = [
            SCNVector3(-s, -s, -s), SCNVector3(s, -s, -s), SCNVector3(s, s, -s), SCNVector3(-s, s, -s),
            SCNVector3(-s, -s, s), SCNVector3(s, -s, s), SCNVector3(s, s, s), SCNVector3(-s, s, s)
        ]
        let indices: [Int32] = [0,1,1,2,2,3,3,0, 4,5,5,6,6,7,7,4, 0,4,1,5,2,6,3,7]

        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.lightingModel = .constant

        return SCNNode(geometry: geometry)
    }

    func loadCube(into slot: inout CubeSlot, animated: Bool) {
        guard slot.node == nil else { return }


        let cubeGeo = SCNBox(
            width: cubeSize * 0.88,
            height: cubeSize * 0.88,
            length: cubeSize * 0.88,
            chamferRadius: cubeSize * 0.05
        )
        cubeGeo.firstMaterial?.diffuse.contents = UIColor(white: 0.72, alpha: 1.0)
        cubeGeo.firstMaterial?.emission.contents = UIColor(white: 0.08, alpha: 1.0)

        let node = EntityNode(kind: .cube, geometry: cubeGeo)
        node.name = "cube_\(slot.row)_\(slot.col)"

        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(geometry: cubeGeo, options: nil)
        )

        body.categoryBitMask = PhysicsCategory.cube

        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.missile |
            PhysicsCategory.ground

        body.collisionBitMask =
            PhysicsCategory.missile |
            PhysicsCategory.ground

        node.physicsBody = body


        if animated {
            let dropStart = Float(gridHeight - slot.row) * Float(cubeSize + cubeSpacing) + 2.0
            node.position = SCNVector3(0, dropStart, 0)
            slot.container.addChildNode(node)
            let fall = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.35)
            fall.timingMode = .easeIn
            node.runAction(fall)
        } else {
            node.position = SCNVector3Zero
            slot.container.addChildNode(node)
        }

        slot.node = node
        slot.isRespawning = false
        slotMap[ObjectIdentifier(node)] = (slot.row, slot.col)
    }

func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        sceneView.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        tap.require(toFail: pan)
        sceneView.addGestureRecognizer(tap)

        let slashPan = UIPanGestureRecognizer(target: self, action: #selector(handleSlashPan(_:)))
        slashPan.minimumNumberOfTouches = 2
        slashPan.cancelsTouchesInView = false
        sceneView.addGestureRecognizer(slashPan)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.20
        longPress.allowableMovement = 35
        longPress.cancelsTouchesInView = false
        longPress.delaysTouchesBegan = false
        longPress.delegate = self
        sceneView.addGestureRecognizer(longPress)

        // Prefer long press over tap so continuous fire is reliable
        tap.require(toFail: longPress)
        // Removed the line: pan.require(toFail: longPress)
    }
    private func longPressRecognizer() -> UILongPressGestureRecognizer? {
        return sceneView.gestureRecognizers?.compactMap { $0 as? UILongPressGestureRecognizer }.first
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard !gameState.isGameOver else { return }
        let location = gesture.location(in: sceneView)
        // If the tap is on/near the platform (or player as fallback), fire a manual shot in addition to auto-fire
        if let anchorNode = platformNode ?? playerNode {
            let anchorScreen = sceneView.projectPoint(anchorNode.presentation.worldPosition)
            let dx = CGFloat(anchorScreen.x) - location.x
            let dy = CGFloat(anchorScreen.y) - location.y
            let dist = sqrt(dx*dx + dy*dy)
            // Increased radius to make tapping near the platform more forgiving
            if dist <= 120 { // screen-space radius in points
                fireLaser()
                return
            }
        }
        if let target = bestTarget(at: location) {
            let world = worldPointFromScreen(location, yPlane: target.presentation.worldPosition.y)
            resolveHit(attacker: .playerLaser, target: target, contactPoint: world)
        }
    }


    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !gameState.isGameOver else { return }
        let location = gesture.location(in: sceneView)
        moveLaser(toScreenX: location.x)
    }

    @objc func handleSlashPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            slashStartScreenPoint = gesture.location(in: sceneView)
        case .changed:
            slashEndScreenPoint = gesture.location(in: sceneView)
        case .ended, .cancelled, .failed:
            let start = slashStartScreenPoint
            let end = slashEndScreenPoint ?? gesture.location(in: sceneView)
            slashStartScreenPoint = nil
            slashEndScreenPoint = nil
            if let start, start != end {
                performSlash(from: start, to: end)
            }
        default:
            break
        }
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            longPressFireTimer?.invalidate()
            let timer = Timer(timeInterval: longPressFireInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.gameState.isGameOver {
                    self.longPressFireTimer?.invalidate()
                    self.longPressFireTimer = nil
                    return
                }
                self.fireLaser()
            }
            self.longPressFireTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        case .ended, .cancelled, .failed:
            longPressFireTimer?.invalidate()
            longPressFireTimer = nil
        default:
            break
        }
    }

    private func distanceFromPoint(_ p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ax = a.x, ay = a.y, bx = b.x, by = b.y
        let px = p.x, py = p.y
        let dx = bx - ax, dy = by - ay
        let len2 = dx*dx + dy*dy
        if len2 == 0 { return hypot(px - ax, py - ay) }
        let t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / len2))
        let sx = ax + t * dx
        let sy = ay + t * dy
        return hypot(px - sx, py - sy)
    }

    private func performSlash(from start: CGPoint, to end: CGPoint) {
        guard !gameState.isGameOver else { return }
        // Visuals at the mid-point using an approximate y-plane
        let midScreen = CGPoint(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5)
        let approxY: Float = groundY + 2.0
        let midWorld = worldPointFromScreen(midScreen, yPlane: approxY)
        spawnSlashSprite(at: midWorld, color: .cyan)
        spawnSlashShockwave(at: midWorld, color: .cyan)

        // Hit test in screen-space: destroy any targetable entity close to the slash path
        let threshold: CGFloat = 60
        scene.rootNode.enumerateChildNodes { [weak self] node, _ in
            guard let self = self else { return }
            guard let entityNode = self.findEntityParent(node),
                  let kind = self.kind(of: entityNode),
                  let profile = self.knowledge.profile(for: kind),
                  profile.canBeTargetedByLaser else { return }

            let worldPos = entityNode.presentation.worldPosition
            let screenPos = self.sceneView.projectPoint(worldPos)
            let p = CGPoint(x: CGFloat(screenPos.x), y: CGFloat(screenPos.y))
            let d = self.distanceFromPoint(p, toSegment: start, end)
            if d <= threshold {
                let contact = self.worldPointFromScreen(p, yPlane: worldPos.y)
                self.resolveHit(attacker: .playerLaser, target: entityNode, contactPoint: contact)
            }
        }
    }

    func moveLaser(toScreenX x: CGFloat) {
        let fraction = max(0, min(1, x / sceneView.bounds.width))
        let newColumn = Int(round(fraction * CGFloat(gridWidth - 1)))
        laserColumn = max(0, min(gridWidth - 1, newColumn))
        // Keep the platform aligned with the firing column
        if let platform = platformNode {
            platform.position.x = laserWorldPosition().x
        }
    }

    func bestTarget(at screenPoint: CGPoint) -> SCNNode? {

        var bestNode: SCNNode?
        var closestDistance: Float = 9999


        scene.rootNode.enumerateChildNodes { [weak self] node, _ in

            guard let self = self else {
                return
            }


            // Find the EntityNode parent
            guard let entityNode = self.findEntityParent(node),
                  let kind = self.kind(of: entityNode),
                  let profile = self.knowledge.profile(for: kind),
                  profile.canBeTargetedByLaser
            else {
                return
            }


            //--------------------------------------------------
            // Project world position to screen
            //--------------------------------------------------

            let worldPosition =
                entityNode.presentation.worldPosition


            let projected =
                self.sceneView.projectPoint(worldPosition)



            let dx =
                projected.x - Float(screenPoint.x)

            let dy =
                projected.y - Float(screenPoint.y)


            let distance =
                sqrt(
                    dx * dx +
                    dy * dy
                )


            //--------------------------------------------------
            // Select closest object under tap
            //--------------------------------------------------

            if distance < 80 &&
               distance < closestDistance {

                closestDistance = distance
                bestNode = entityNode
            }
        }


        return bestNode
    }
    func kind(of node: SCNNode) -> KnowledgeTree.EntityKind? {

        if let entity = node as? EntityNode {
            return entity.kind
        }

        return nil
    }

    //--------------------------------------------------
    // Removes any AI tracking state associated with a node
    // before it leaves the scene, so dictionaries/sets never
    // accumulate stale entries.
    //--------------------------------------------------

    func cleanupTrackingState(for node: SCNNode, kind: KnowledgeTree.EntityKind) {
        let id = ObjectIdentifier(node)

        switch kind {
        case .spider:
            removeSpiderThread(for: node)

        case .ladybug:
            ladybugDirection.removeValue(forKey: id)

        case .grasshopper:
            grasshopperJumping.remove(id)

        case .centipedeHead, .centipedeSegment:
            centipedeDirection.removeValue(forKey: id)
            centipedeDropping.remove(id)

        default:
            break
        }
    }

    func resolveHit(
        attacker: KnowledgeTree.EntityKind,
        target: SCNNode,
        contactPoint: SCNVector3
    ) {
        guard let targetKind = kind(of: target),
              let profile = knowledge.profile(for: targetKind) else {
            return
        }

        var shouldDestroy = false
        var scoreDelta = 0
       // var burstRadius: Float? = nil

        for behavior in profile.behaviors {
            switch behavior {
            case .destroyedByLaser:
                if attacker == .playerLaser {
                    shouldDestroy = true
                }

            case .destroyedByMissile:
                if attacker == .missile {
                    shouldDestroy = true
                }

            case .awardsScore(let value):
                scoreDelta += value

           // case .burstOnDestroy(let radius):
           //     burstRadius = radius

            default:
                break
            }
        }

        if shouldDestroy {
            destroy(node: target, kind: targetKind, at: contactPoint)

            if targetKind == .cube, attacker == .playerLaser {
                    let roll = Int.random(in: 0..<100)

                    if roll == 0 {
                        spawnBonusPointObject(at: contactPoint)
                    } else {
                        spawnRewardEnemy(at: contactPoint)
                    }
                }

            //else if targetKind == .centipedeHead || targetKind == .centipedeSegment {
            //    spawnMushroomFunc(at: contactPoint)
            //}

            //else if let radius = burstRadius {
            //    burstNearbyPointObjects(at: contactPoint, radius: radius)
           // }
        }

        if scoreDelta > 0 {
            DispatchQueue.main.async {
                self.gameState.score += scoreDelta
                self.gameState.combo += 1
            }
        }
    }

    //--------------------------------------------------
    // Bonus-object burst effect: destroys nearby falling point
    // objects and awards extra score for each one caught in the blast.
    //--------------------------------------------------

    func burstNearbyPointObjects(at position: SCNVector3, radius: Float) {
        var destroyedCount = 0

        enemyRoot.enumerateChildNodes { node, _ in
            guard let k = self.kind(of: node), k == .pointObject else { return }

            let d = self.distanceBetween(node.presentation.worldPosition, position)
            if d <= radius {
                node.removeFromParentNode()
                destroyedCount += 1
            }
        }

        if destroyedCount > 0 {
            gameState.score += destroyedCount * 5
            spawnExplosion(at: position, color: .yellow)
            playSound(GameSound.bonus.rawValue)
        }
    }

    func spawnMushroomFunc(at worldPosition: SCNVector3) {

        let geo = SCNCylinder(
            radius: 0.18,
            height: 0.25
        )

        geo.firstMaterial?.diffuse.contents = UIColor.systemGreen
        geo.firstMaterial?.emission.contents =
            UIColor.systemGreen.withAlphaComponent(0.2)


        let node = EntityNode(
            kind: .mushroom,
            geometry: geo
        )

        node.name = "mushroom"

        node.position = worldPosition


        let body = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(
                geometry: geo,
                options: nil
            )
        )


        body.categoryBitMask =
            PhysicsCategory.mushroom


        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.missile


        body.collisionBitMask =
            PhysicsCategory.none


        node.physicsBody = body


        enemyRoot.addChildNode(node)
    }
    func destroy(
        node: SCNNode,
        kind: KnowledgeTree.EntityKind,
        at point: SCNVector3
    ) {

        cleanupTrackingState(for: node, kind: kind)

        let color =
            (node.geometry?.firstMaterial?.emission.contents as? UIColor)
            ?? .cyan

        if kind != .cube {
           /* spawnExplosion(
                at: point,
                color: color
            )
            */
        }

        playSound(
            kind == .missile
                ? GameSound.missileHit.rawValue
                : GameSound.enemyDestroyed.rawValue
        )

        //--------------------------------------------------
        // REMOVE OBJECT
        //--------------------------------------------------

        node.removeFromParentNode()



        //--------------------------------------------------
        // CUBE DESTROYED
        //--------------------------------------------------

        if kind == .cube {

            if let slot = slotForNode(node) {

                slots[slot.row][slot.col].node = nil

                slotMap.removeValue(
                    forKey: ObjectIdentifier(node)
                )
            }

            playSound(GameSound.cubeHit.rawValue)
        }



        //--------------------------------------------------
        // CENTIPEDE DESTROYED
        //--------------------------------------------------

        if kind == .centipedeHead ||
           kind == .centipedeSegment {

            spawnMushroomFunc(
                at: point
            )
        }

    }
    func distanceBetween(_ a: SCNVector3, _ b: SCNVector3) -> Float {

        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z

        return sqrt(
            dx * dx +
            dy * dy +
            dz * dz
        )
    }
    struct GridIndex {
        let row: Int
        let col: Int
    }

    func slotForNode(_ node: SCNNode) -> GridIndex? {
        guard let mapped = slotMap[ObjectIdentifier(node)] else { return nil }
        return GridIndex(row: mapped.row, col: mapped.col)
    }

    func scheduleCubeRespawn(row: Int, col: Int) {
        let sessionID = gameSessionID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.gameSessionID == sessionID else { return }
            self.respawnCube(row: row, col: col)
        }
    }

    func activeCubeNodes() -> [SCNNode] {

        var cubes: [SCNNode] = []

        for row in 0..<slots.count {

            for col in 0..<slots[row].count {

                if let cube = slots[row][col].node {

                    cubes.append(cube)
                }
            }
        }

        return cubes
    }

    //---------------------------------------------------------
    // Finds the best reachable cube for a grasshopper jump: any
    // active cube within max jump range, preferring whichever
    // lands the grasshopper closest to the player.
    //---------------------------------------------------------
    func nextJumpTarget(
        from current: SCNNode,
        toward player: SCNNode
    ) -> SCNNode? {

        let maxJump: Float = 2.4

        let currentPos = current.presentation.worldPosition
        let playerPos = player.presentation.worldPosition

        let cubes = activeCubeNodes()

        var best: SCNNode?
        var bestScore = Float.greatestFiniteMagnitude

        for cube in cubes {

            let cubePos = cube.presentation.worldPosition

            let dx = cubePos.x - currentPos.x
            let dy = cubePos.y - currentPos.y

            let distance = sqrt(dx*dx + dy*dy)

            guard distance <= maxJump, distance > 0.05 else { continue }

            // score = distance from this cube to player
            let score = distanceBetween(
                cubePos,
                playerPos
            )

            if score < bestScore {
                bestScore = score
                best = cube
            }
        }

        return best
    }
    func respawnCube(row: Int, col: Int) {
        guard slots.indices.contains(row),
              slots[row].indices.contains(col),
              slots[row][col].node == nil else { return }

        var slot = slots[row][col]
        loadCube(into: &slot, animated: true)
        slots[row][col] = slot
    }

    func spawnPointObject(at worldPosition: SCNVector3) {

        let geo = SCNSphere(radius: 0.22)
        geo.firstMaterial?.diffuse.contents = UIColor.systemOrange
        geo.firstMaterial?.emission.contents =
            UIColor.systemOrange.withAlphaComponent(0.45)

        let node = EntityNode(
            kind: .pointObject,
            geometry: geo
        )

        node.position = worldPosition

        let body = SCNPhysicsBody(
            type: .dynamic,
            shape: SCNPhysicsShape(
                geometry: geo,
                options: nil
            )
        )

        body.categoryBitMask = PhysicsCategory.pointObject

        body.contactTestBitMask =
            PhysicsCategory.ground |
            PhysicsCategory.laser

        body.collisionBitMask =
            PhysicsCategory.none

        body.isAffectedByGravity = false

        body.velocity = SCNVector3(
            0,
            -3.0,
            0
        )

        body.damping = 0.2
        body.angularDamping = 0.5

        node.physicsBody = body

        enemyRoot.addChildNode(node)
    }

    func spawnBonusPointObject(at worldPosition: SCNVector3) {
        let size = cubeSize * 1.2
        let plane = makeLabelBillboard(text: "$$$", color: .yellow, worldSize: size)
        let node = EntityNode(kind: .bonusPointObject, geometry: plane)
        node.name = "$$$"
        node.position = worldPosition
        node.renderingOrder = 100

        let body = SCNPhysicsBody(
            type: .dynamic,
            shape: labelPhysicsShape(size: size)
        )

        body.categoryBitMask = PhysicsCategory.pointObject
        body.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.laser
        body.collisionBitMask = PhysicsCategory.none
        body.isAffectedByGravity = false
        body.velocity = SCNVector3(0, -2.2, 0)
        body.damping = 0.2
        body.angularDamping = 0.5

        node.physicsBody = body
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        enemyRoot.addChildNode(node)
    }
    func spawnExplosion(at position: SCNVector3, color: UIColor) {
        let ps = SCNParticleSystem()
        ps.birthRate = 220
        ps.emissionDuration = 0.05
        ps.particleLifeSpan = 0.35
        ps.particleSize = 0.03
        ps.particleColor = color
        ps.spreadingAngle = 160
        ps.particleVelocity = 1.8
        ps.particleVelocityVariation = 1.0
        ps.acceleration = SCNVector3(0, -2.0, 0)
        ps.blendMode = .additive

        let node = SCNNode()
        node.position = position
        node.addParticleSystem(ps)
        effectsRoot.addChildNode(node)
        node.runAction(.sequence([.wait(duration: 0.8), .removeFromParentNode()]))
    }

    func currentAutoFireInterval() -> TimeInterval {
        let scoreFactor = min(Double(gameState.score) / 120.0, 1.0)
        return max(0.08, 1.6 - (1.2 * scoreFactor))
    }

    func fireLaser() {

        if gameState.isGameOver { return }

        let boltGeo = SCNCylinder(
            radius: 0.035,
            height: 0.4
        )

        boltGeo.firstMaterial?.diffuse.contents = UIColor.cyan
        boltGeo.firstMaterial?.emission.contents = UIColor.cyan


        let bolt = EntityNode(
            kind: .playerLaser,
            geometry: boltGeo
        )

        bolt.name = "laserBolt"

        bolt.position = laserWorldPosition()


        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(
                geometry: boltGeo,
                options: nil
            )
        )


        body.categoryBitMask = PhysicsCategory.laser

        body.contactTestBitMask =
            PhysicsCategory.cube |
            PhysicsCategory.pointObject |
            PhysicsCategory.ufo |
            PhysicsCategory.missile |
            PhysicsCategory.centipede |
            PhysicsCategory.mushroom |
            PhysicsCategory.grasshopper |
            PhysicsCategory.spider |
            PhysicsCategory.ladybug


        body.collisionBitMask = PhysicsCategory.none

        bolt.physicsBody = body


        scene.rootNode.addChildNode(bolt)

        activeLasers.append(bolt)

        playSound(GameSound.laserFire.rawValue)
    }
    func laserWorldPosition() -> SCNVector3 {
        let pitch = Float(cubeSize + cubeSpacing)
        let x = -Float(gridWidth) * pitch / 2 + Float(laserColumn) * pitch + pitch / 2
        return SCNVector3(x, groundY + 0.6, wallZ)
    }

    //---------------------------------------------------------
    // Grasshopper falls to the ground and disappears when no
    // reachable cube exists, per spec.
    //---------------------------------------------------------
    func fallToGround(_ grasshopper: SCNNode) {

        let targetY = groundY

        let fall = SCNAction.move(
            to: SCNVector3(
                grasshopper.position.x,
                targetY,
                grasshopper.position.z
            ),
            duration: 0.45
        )

        fall.timingMode = .easeIn

        let impact = SCNAction.run { [weak self] node in
            guard let self = self else { return }
            self.spawnExplosion(at: node.position, color: .brown)
        }

        let remove = SCNAction.removeFromParentNode()

        grasshopper.runAction(
            .sequence([
                fall,
                impact,
                remove
            ])
        )
    }
    func worldPointFromScreen(_ point: CGPoint, yPlane: Float) -> SCNVector3 {
        let near = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let far = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let dy = far.y - near.y
        if abs(dy) < 0.0001 { return near }
        let t = (yPlane - near.y) / dy
        return SCNVector3(
            near.x + (far.x - near.x) * t,
            yPlane,
            near.z + (far.z - near.z) * t
        )
    }

    //---------------------------------------------------------
    // GRASSHOPPER AI
    // Jumps from cube to cube toward the player. If the player is
    // within direct leap range it jumps straight at them. If no
    // cube is in jump range, it leaps and falls to its death.
    //---------------------------------------------------------
    func updateGrasshopper(_ grasshopper: SCNNode) {

        let id = ObjectIdentifier(grasshopper)

        if grasshopperJumping.contains(id) {
            return
        }

        guard let player = playerNode else {
            return
        }

        let playerDistance = distanceBetween(
            grasshopper.presentation.worldPosition,
            player.presentation.worldPosition
        )

        let directLeapDistance: Float = 1.8

        grasshopperJumping.insert(id)

        //--------------------------------------------------
        // PLAYER IS DIRECTLY REACHABLE
        //--------------------------------------------------

        if playerDistance < directLeapDistance {

            arcJump(
                grasshopper: grasshopper,
                target: player.presentation.worldPosition
            ) { [weak self] in
                guard let self = self else { return }
                self.grasshopperJumping.remove(id)
                self.checkGrasshopperLanding(grasshopper)
            }

            return
        }


        //--------------------------------------------------
        // HOP TO THE BEST REACHABLE CUBE
        //--------------------------------------------------

        if let targetCube = nextJumpTarget(from: grasshopper, toward: player) {

            let cubePos = targetCube.presentation.worldPosition
            let landing = SCNVector3(
                cubePos.x,
                cubePos.y + Float(cubeSize) * 0.6,
                cubePos.z
            )

            arcJump(
                grasshopper: grasshopper,
                target: landing
            ) { [weak self] in
                self?.grasshopperJumping.remove(id)
            }

            return
        }


        //--------------------------------------------------
        // NO REACHABLE CUBE -> LEAP AND FALL
        //--------------------------------------------------

        grasshopperJumping.remove(id)
        fallToGround(grasshopper)
    }

    func checkGrasshopperLanding(
        _ grasshopper: SCNNode
    ) {

        guard let player = playerNode else {
            return
        }


        let distance = distanceBetween(
            grasshopper.presentation.worldPosition,
            player.presentation.worldPosition
        )


        if distance < 0.45 {
            triggerGameOverFromEnemyContact(node: grasshopper, at: player.position)
        }
    }
    func arcJump(
        grasshopper: SCNNode,
        target: SCNVector3,
        completion: (() -> Void)? = nil
    ) {

        let start =
            grasshopper.presentation.worldPosition


        let height: Float = 1.8


        let mid = SCNVector3(
            (start.x + target.x) / 2,
            max(start.y,target.y) + height,
            (start.z + target.z) / 2
        )


        let moveUp = SCNAction.move(
            to: mid,
            duration: 0.25
        )

        moveUp.timingMode = .easeOut


        let moveDown = SCNAction.move(
            to: target,
            duration: 0.25
        )

        moveDown.timingMode = .easeIn


        let finish = SCNAction.run { _ in
            completion?()
        }


        grasshopper.runAction(
            .sequence([
                moveUp,
                moveDown,
                finish
            ])
        )
    }

    func updateDifficulty() {
        let s = Double(gameState.score)
        gameState.difficulty = min(5.0, 1.0 + s / 250.0)
        gridSpeed = Float(0.18 * gameState.difficulty)
        autoFireInterval = currentAutoFireInterval()
    }

    func allCubesGone() -> Bool {
        for row in 0..<slots.count {
            for col in 0..<slots[row].count {
                if slots[row][col].node != nil {
                    return false
                }
            }
        }
        return true
    }

    func respawnAllCubes() {
        for row in 0..<slots.count {
            for col in 0..<slots[row].count {
                if let current = slots[row][col].node {
                    current.removeFromParentNode()
                }
                var slot = slots[row][col]
                slot.node = nil
                slot.isRespawning = false
                loadCube(into: &slot, animated: true)
                slots[row][col] = slot
            }
        }
    }
    func updateLasers(dt: TimeInterval) {

        let speed: Float = 18.0


        for laser in activeLasers {

            guard laser.parent != nil else {
                continue
            }


            laser.position.y += Float(dt) * speed


            // keep physics body synchronized
            laser.physicsBody?.resetTransform()


            // remove if above arena
            if laser.position.y > groundY + 20 {

                laser.removeFromParentNode()

            }
        }


        activeLasers.removeAll {
            $0.parent == nil
        }
    }

    //--------------------------------------------------
    // Cleanup pass for entities whose movement is driven elsewhere
    // (SCNActions for missile/UFO, dedicated AI functions for
    // grasshopper/centipede/spider/ladybug). This just removes
    // anything that fell out of the arena without triggering its
    // normal removal path.
    //--------------------------------------------------
    func updateEntities(dt: TimeInterval) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let kind = self.kind(of: node) else { return }

            switch kind {
            case .pointObject, .bonusPointObject:
                if node.position.y < self.groundY - 6 {
                    node.removeFromParentNode()
                }

            default:
                break
            }
        }
    }

    func fireMissile(from ufo: SCNNode) {
        let geo = SCNCylinder(radius: 0.05, height: 0.45)
        geo.firstMaterial?.diffuse.contents = UIColor.systemRed
        geo.firstMaterial?.emission.contents = UIColor.systemRed

        let missile = EntityNode(kind: .missile, geometry: geo)
        missile.position = ufo.presentation.worldPosition
        missile.position.y -= 0.6

        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: geo, options: nil))
        body.categoryBitMask = PhysicsCategory.missile
        body.contactTestBitMask = PhysicsCategory.cube | PhysicsCategory.player | PhysicsCategory.ground | PhysicsCategory.laser
        body.collisionBitMask = PhysicsCategory.none
        missile.physicsBody = body

        enemyRoot.addChildNode(missile)
        missile.runAction(.sequence([
            .moveBy(x: 0, y: -12, z: 0, duration: 2.0 / gameState.difficulty),
            .removeFromParentNode()
        ]))
    }

    func spawnSlashShockwave(at position: SCNVector3, color: UIColor) {
        let ring = SCNTorus(ringRadius: cubeSize * 0.2, pipeRadius: cubeSize * 0.04)
        ring.firstMaterial?.diffuse.contents = UIColor.clear
        ring.firstMaterial?.emission.contents = color
        ring.firstMaterial?.lightingModel = .constant

        let node = SCNNode(geometry: ring)
        node.position = position
        node.eulerAngles.x = Float.pi / 2
        node.opacity = 0.85

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = [.X, .Y]
        node.constraints = [billboard]

        scene.rootNode.addChildNode(node)

        let expand = SCNAction.scale(to: 3.5, duration: 0.25)
        let fade = SCNAction.fadeOut(duration: 0.25)
        node.runAction(.sequence([.group([expand, fade]), .removeFromParentNode()]))
    }

    func spawnSlashSprite(at position: SCNVector3, color: UIColor) {
        let plane = SCNPlane(width: cubeSize * 1.4, height: cubeSize * 0.45)
        let image = drawSlashImage(size: CGSize(width: 256, height: 128), color: color)

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.clear
        material.emission.contents = image
        material.blendMode = .add
        material.lightingModel = .constant
        material.isDoubleSided = true
        plane.materials = [material]

        let node = SCNNode(geometry: plane)
        node.position = position
        node.eulerAngles.z = Float.random(in: -0.7...0.7)

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        node.opacity = 0
        scene.rootNode.addChildNode(node)

        let appear = SCNAction.group([
            .fadeOpacity(to: 1.0, duration: 0.04),
            .scale(to: 1.2, duration: 0.04)
        ])
        let settle = SCNAction.scale(to: 1.0, duration: 0.07)
        let fade = SCNAction.fadeOut(duration: 0.2)

        node.runAction(.sequence([appear, settle, .wait(duration: 0.1), fade, .removeFromParentNode()]))
    }

    private func drawSlashImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            let path = UIBezierPath()
            let inset = size.height * 0.2
            path.move(to: CGPoint(x: inset, y: size.height - inset))
            path.addLine(to: CGPoint(x: size.width - inset, y: inset))

            c.setLineCap(.round)
            c.setLineWidth(size.height * 0.38)
            c.setStrokeColor(color.withAlphaComponent(0.9).cgColor)
            c.addPath(path.cgPath)
            c.strokePath()

            c.setLineWidth(size.height * 0.22)
            c.setStrokeColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            c.addPath(path.cgPath)
            c.strokePath()
        }
    }

    private func drawLabelImage(text: String, size: CGSize, color: UIColor, bgColor: UIColor = .clear) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            bgColor.setFill()
            ctx.fill(rect)

            let fontSize = min(size.width, size.height) * 0.8
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
            let attributed = NSAttributedString(string: text, attributes: attrs)
            let textSize = attributed.size()
            let drawRect = CGRect(
                x: (size.width - textSize.width) * 0.5,
                y: (size.height - textSize.height) * 0.5,
                width: textSize.width,
                height: textSize.height
            )
            attributed.draw(in: drawRect)
        }
    }

    private func makeLabelBillboard(text: String, color: UIColor, worldSize: CGFloat) -> SCNPlane {
        let plane = SCNPlane(width: worldSize, height: worldSize)
        let img = drawLabelImage(text: text, size: CGSize(width: 384, height: 384), color: color)

        let mat = SCNMaterial()
        mat.diffuse.contents = img
        mat.emission.contents = UIColor.white
        mat.lightingModel = .constant
        mat.blendMode = .alpha
        mat.isDoubleSided = true
        mat.readsFromDepthBuffer = true
        mat.writesToDepthBuffer = false

        plane.materials = [mat]
        return plane
    }

    private func labelPhysicsShape(size: CGFloat) -> SCNPhysicsShape {
        let thickness = max(0.01, size * 0.05)
        let box = SCNBox(width: size, height: size, length: thickness, chamferRadius: 0)
        return SCNPhysicsShape(geometry: box, options: nil)
    }

    func allTargetNodes() -> [SCNNode] {
        var nodes: [SCNNode] = []
        scene.rootNode.enumerateChildNodes { node, _ in
            if self.kind(of: node) != nil {
                nodes.append(node)
            }
        }
        return nodes
    }
    func findEntityParent(_ node: SCNNode) -> SCNNode? {

        var current: SCNNode? = node

        while let n = current {

            if kind(of: n) != nil {
                return n
            }

            current = n.parent
        }

        return nil
    }

    //--------------------------------------------------
    // Shared game-over trigger for any hostile entity that
    // physically reaches the player (spider, centipede, grasshopper).
    // Guarded against double-firing.
    //--------------------------------------------------
    func triggerGameOverFromEnemyContact(node: SCNNode, at point: SCNVector3) {
        guard !gameState.isGameOver else { return }

        if let k = kind(of: node) {
            cleanupTrackingState(for: node, kind: k)
        }

        gameState.isGameOver = true
        spawnExplosion(at: point, color: .red)
        playSound(GameSound.gameOver.rawValue)

        node.removeFromParentNode()
    }

    func physicsWorld(
        _ world: SCNPhysicsWorld,
        didBegin contact: SCNPhysicsContact
    ) {

        let a = contact.nodeA
        let b = contact.nodeB

        let kindA = kind(of: a)
        let kindB = kind(of: b)

        let categoryA =
            a.physicsBody?.categoryBitMask ?? PhysicsCategory.none

        let categoryB =
            b.physicsBody?.categoryBitMask ?? PhysicsCategory.none


        //--------------------------------------------------
        // PLAYER LASER HITS OBJECT
        //--------------------------------------------------

        let isLaserA =
            categoryA == PhysicsCategory.laser

        let isLaserB =
            categoryB == PhysicsCategory.laser


        if isLaserA, kindB != nil {

            resolveHit(
                attacker: .playerLaser,
                target: b,
                contactPoint: contact.contactPoint
            )

            destroyLaser(
                a,
                at: contact.contactPoint
            )

            return
        }


        if isLaserB, kindA != nil {

            resolveHit(
                attacker: .playerLaser,
                target: a,
                contactPoint: contact.contactPoint
            )

            destroyLaser(
                b,
                at: contact.contactPoint
            )

            return
        }


        //--------------------------------------------------
        // MISSILE HITS CUBE -> remove missile, cube unaffected
        //--------------------------------------------------
        let isMissileA =
            categoryA == PhysicsCategory.missile

        let isMissileB =
            categoryB == PhysicsCategory.missile

        if isMissileA && categoryB == PhysicsCategory.cube {
            spawnExplosion(at: contact.contactPoint, color: .systemRed)
            a.removeFromParentNode()
            return
        }

        if isMissileB && categoryA == PhysicsCategory.cube {
            spawnExplosion(at: contact.contactPoint, color: .systemRed)
            b.removeFromParentNode()
            return
        }


        //--------------------------------------------------
        // MISSILE HITS PLAYER -> GAME OVER
        //--------------------------------------------------

    
        if isMissileA && categoryB == PhysicsCategory.player {

            if !gameState.isGameOver {
                gameState.isGameOver = true
                spawnExplosion(at: contact.contactPoint, color: .red)
                playSound(GameSound.gameOver.rawValue)
            }

            a.removeFromParentNode()
            return
        }
       

        if isMissileB && categoryA == PhysicsCategory.player {

            if !gameState.isGameOver {
                gameState.isGameOver = true
                spawnExplosion(at: contact.contactPoint, color: .red)
                playSound(GameSound.gameOver.rawValue)
            }

            b.removeFromParentNode()
            return
        }
        

        //--------------------------------------------------
        // SPIDER / CENTIPEDE / GRASSHOPPER TOUCHES PLAYER -> GAME OVER
        //--------------------------------------------------

     
        let dangerousCategories =
            PhysicsCategory.spider |
            PhysicsCategory.centipede |
            PhysicsCategory.grasshopper

        if (categoryA & dangerousCategories) != 0 && categoryB == PhysicsCategory.player {
            triggerGameOverFromEnemyContact(node: a, at: contact.contactPoint)
            return
        }

        if (categoryB & dangerousCategories) != 0 && categoryA == PhysicsCategory.player {
            triggerGameOverFromEnemyContact(node: b, at: contact.contactPoint)
            return
        }


        //--------------------------------------------------
        // POINT / BONUS OBJECT HITS GROUND
        //--------------------------------------------------

        if let kA = kindA, (kA == .pointObject || kA == .bonusPointObject),
           categoryB == PhysicsCategory.ground {

            a.removeFromParentNode()
            return
        }


        if let kB = kindB, (kB == .pointObject || kB == .bonusPointObject),
           categoryA == PhysicsCategory.ground {

            b.removeFromParentNode()
            return
        }
    }
    func updateGrid(dt: TimeInterval) {
        let delta = Float(dt)

        //--------------------------------------------------
        // MOVE CUBE GRID
        //--------------------------------------------------

        gridOffset +=
            gridDirection *
            gridSpeed *
            Float(dt)

        gridRoot.position.x = gridOffset

        if abs(gridOffset) >= gridMaxOffset {

            gridDirection *= -1

            gridOffset =
                max(
                    min(gridOffset, gridMaxOffset),
                    -gridMaxOffset
                )

            gridRoot.position.y -= 0.5

            if gridRoot.position.y <= -4.5 {

                if !gameState.isGameOver {
                    gameState.isGameOver = true
                    playSound(GameSound.gameOver.rawValue)
                }
            }
        }

        if allCubesGone() {
            respawnAllCubes()
        }
    }
    func updateGrasshoppers(dt: TimeInterval) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let entity = node as? EntityNode, entity.kind == .grasshopper else { return }
            updateGrasshopper(node)
        }
    }
    func updateCentipedes(dt: TimeInterval) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let entity = node as? EntityNode else { return }
            switch entity.kind {
            case .centipedeHead, .centipedeSegment:
                updateCentipedeSegment(node, dt: dt)
            default:
                break
            }
        }
    }
    func updateCentipedeSegment(_ node: SCNNode, dt: TimeInterval) {
        let id = ObjectIdentifier(node)
        if centipedeDropping.contains(id) { return }

        if let target = centipedeFollowTarget[id] {
            if target.parent == nil {
                centipedeFollowTarget.removeValue(forKey: id)
            } else {
                let targetPos = target.presentation.worldPosition
                let currentPos = node.presentation.worldPosition

                let dx = targetPos.x - currentPos.x
                let dy = targetPos.y - currentPos.y
                let dist = sqrt(dx * dx + dy * dy)

                if dist > centipedeTrailSpacing {
                    let move: Float = min(2.0 * Float(dt), dist - centipedeTrailSpacing)
                    let nx = dx / dist
                    let ny = dy / dist
                    node.position.x += nx * move
                    node.position.y += ny * move
                    return
                }
            }
        }

        let direction = centipedeDirection[id] ?? 1.0
        let speed: Float = 1.1 * Float(gameState.difficulty)
        let step = direction * speed * Float(dt)

        let current = node.position
        let next = SCNVector3(current.x + step, current.y, current.z)

        let pitch = Float(cubeSize + cubeSpacing)
        let halfWidth = Float(gridWidth) * pitch / 2
        let hitsEdge = next.x > halfWidth - pitch / 2 || next.x < -halfWidth + pitch / 2

        if hitsEdge || isCentipedePathBlocked(at: next, excluding: node) {
            centipedeDirection[id] = -direction
            dropCentipedeRow(node)
        } else {
            node.position = next
        }
    }
    func updateUFOs(dt: TimeInterval) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let entity = node as? EntityNode, entity.kind == .ufo else { return }
            updateUFO(node, dt: dt)
        }
    }
    func updateUFO(_ ufo: SCNNode, dt: TimeInterval) {
        let speed: Float = 2.0 * Float(gameState.difficulty)
        let bounds: Float = Float(gridWidth) * Float(cubeSize + cubeSpacing) * 0.5 + Float(2.0)

        var pos = ufo.position
        pos.x += ufo.name == "ufoLeft" ? -speed * Float(dt) : speed * Float(dt)

        if pos.x > bounds {
            pos.x = bounds
            ufo.scale.x = -1
            fireMissile(from: ufo)
        } else if pos.x < -bounds {
            pos.x = -bounds
            ufo.scale.x = 1
            fireMissile(from: ufo)
        }

        ufo.position = pos
    }
    func updateLadybugs(dt: TimeInterval) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let entity = node as? EntityNode, entity.kind == .ladybug else { return }
            updateLadybugMovement(node, dt: dt)
        }
    }
    func updateSpiders(dt: TimeInterval) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let entity = node as? EntityNode, entity.kind == .spider else { return }
            updateSpider(node, dt: dt)
        }
    }
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : time - lastUpdateTime
        lastUpdateTime = time
        guard dt > 0, !gameState.isGameOver else { return }

        //updateDifficulty()
        //if allCubesGone() { respawnAllCubes() }
        
        updateGrid(dt: dt)

        gridOffset += gridDirection * gridSpeed * Float(dt)
        gridRoot.position.x = gridOffset

        scene.rootNode.enumerateChildNodes { node, _ in
            guard let entity = node as? EntityNode else { return }
            switch entity.kind {
            case .grasshopper:
                self.updateGrasshopper(entity)
            case .centipedeHead, .centipedeSegment:
                self.updateCentipedeSegment(entity, dt: dt)
            case .spider:
                self.updateSpider(entity, dt: dt)
            case .ladybug:
                self.updateLadybugMovement(entity, dt: dt)
            default:
                break
            }
        }

        updateEntities(dt: dt)
        updateLasers(dt: dt)

        if autoFireEnabled, time - lastAutoFireTime >= autoFireInterval {
            fireLaser()
            lastAutoFireTime = time
        }

        if time - lastFireTime > max(0.6, 2.5 / gameState.difficulty) {
            lastFireTime = time
            spawnUFOIfNeeded()
        }
    }

    //---------------------------------------------------------
    // CENTIPEDE AI
    // Crawls sideways; when blocked by a cube, mushroom, or the
    // arena edge it reverses direction and drops down one row.
    // Destroyed segments become mushrooms (handled in destroy()).
    //---------------------------------------------------------

    func isCentipedePathBlocked(at position: SCNVector3, excluding node: SCNNode) -> Bool {
        let threshold = Float(cubeSize) * 0.9

        for cube in activeCubeNodes() {
            if distanceBetween(cube.presentation.worldPosition, position) < threshold {
                return true
            }
        }

        var blocked = false
        enemyRoot.enumerateChildNodes { candidate, stop in
            guard candidate != node,
                  let k = self.kind(of: candidate),
                  k == .mushroom else { return }

            if self.distanceBetween(candidate.presentation.worldPosition, position) < threshold {
                blocked = true
                stop.pointee = true
            }
        }
        return blocked
    }

    func dropCentipedeRow(_ node: SCNNode) {
        let id = ObjectIdentifier(node)
        guard !centipedeDropping.contains(id) else { return }
        centipedeDropping.insert(id)

        let pitch = Float(cubeSize + cubeSpacing)

        let drop = SCNAction.moveBy(x: 0, y: CGFloat(-pitch), z: 0, duration: 0.2)
        drop.timingMode = .easeInEaseOut

        let finish = SCNAction.run { [weak self, weak node] _ in
            guard let self = self, let node = node else { return }
            self.centipedeDropping.remove(ObjectIdentifier(node))
            self.checkCentipedeReachedBottom(node)
        }

        node.runAction(.sequence([drop, finish]))
    }

    func checkCentipedeReachedBottom(_ node: SCNNode) {
        guard let player = playerNode else { return }

        // If it's dropped below the player's row, send it back upward and reverse
        if node.presentation.worldPosition.y <= player.presentation.worldPosition.y + 0.6 {
            let riseBack = SCNAction.moveBy(
                x: 0,
                y: CGFloat(Float(gridHeight) * Float(cubeSize + cubeSpacing)),
                z: 0,
                duration: 0.5
            )
            node.runAction(riseBack)
        }
    }

    //---------------------------------------------------------
    // SPIDER AI
    // Descends slowly on a visible thread from the opening it
    // entered through. Removed if it reaches the ground without
    // hitting the player; ends the game on player contact
    // (handled in physicsWorld / triggerGameOverFromEnemyContact).
    //---------------------------------------------------------

    func updateSpider(_ node: SCNNode, dt: TimeInterval) {
        let speed: Float = 0.55 * Float(gameState.difficulty)
        node.position.y -= speed * Float(dt)

        updateSpiderThread(for: node)

        if node.position.y < groundY - 1 {
            removeSpiderThread(for: node)
            node.removeFromParentNode()
        }
    }

    func updateSpiderThread(for spider: SCNNode) {
        let id = ObjectIdentifier(spider)
        guard let anchorY = spiderAnchorY[id] else { return }

        let current = spider.presentation.worldPosition
        let length = max(0.02, anchorY - current.y)

        let thread: SCNNode
        if let existing = spiderThreads[id] {
            thread = existing
        } else {
            let cyl = SCNCylinder(radius: 0.012, height: 1)
            cyl.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
            cyl.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.3)
            cyl.firstMaterial?.lightingModel = .constant
            thread = SCNNode(geometry: cyl)
            effectsRoot.addChildNode(thread)
            spiderThreads[id] = thread
        }

        thread.scale = SCNVector3(1, length, 1)
        thread.position = SCNVector3(current.x, anchorY - length / 2, current.z)
    }

    func removeSpiderThread(for spider: SCNNode) {
        let id = ObjectIdentifier(spider)
        spiderThreads[id]?.removeFromParentNode()
        spiderThreads.removeValue(forKey: id)
        spiderAnchorY.removeValue(forKey: id)
    }

    //---------------------------------------------------------
    // LADYBUG AI
    // Descends gradually while drifting side to side, bouncing
    // off the arena edges. Non-lethal, high-value target.
    //---------------------------------------------------------

    func updateLadybugMovement(_ node: SCNNode, dt: TimeInterval) {
        let id = ObjectIdentifier(node)

        var dir = ladybugDirection[id]
        if dir == nil {
            dir = Bool.random() ? 1.0 : -1.0
        }

        let descendSpeed: Float = 0.22 * Float(gameState.difficulty)
        let driftSpeed: Float = 0.5

        var pos = node.position
        pos.y -= descendSpeed * Float(dt)
        pos.x += dir! * driftSpeed * Float(dt)

        let pitch = Float(cubeSize + cubeSpacing)
        let halfWidth = Float(gridWidth) * pitch / 2

        if pos.x > halfWidth {
            dir = -1.0
        } else if pos.x < -halfWidth {
            dir = 1.0
        }

        ladybugDirection[id] = dir
        node.position = pos

        if pos.y < groundY - 1 {
            ladybugDirection.removeValue(forKey: id)
            node.removeFromParentNode()
        }
    }

    func spawnGrasshopper() {
        let size = cubeSize * 1.2
        let plane = makeLabelBillboard(text: "H", color: .white, worldSize: size)
        let grasshopper = EntityNode(kind: .grasshopper, geometry: plane)
        grasshopper.name = "H"
        grasshopper.position = SCNVector3(0, groundY + 5, 0)
        grasshopper.renderingOrder = 100
        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.grasshopper
        body.contactTestBitMask = PhysicsCategory.cube | PhysicsCategory.player | PhysicsCategory.laser
        body.collisionBitMask = PhysicsCategory.none
        grasshopper.physicsBody = body
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        grasshopper.constraints = [billboard]
        enemyRoot.addChildNode(grasshopper)
    }

    //---------------------------------------------------------
    // UFO AI
    // Bounces back and forth across the top of the arena, firing
    // a missile at each turnaround point.
    //---------------------------------------------------------
    func spawnUFOIfNeeded() {
        let chance = Int.random(in: 0...1000)
        let threshold = max(1, 950 - Int(gameState.difficulty * 120))
        guard chance > threshold else { return }

        let geo = SCNTorus(ringRadius: 0.45, pipeRadius: 0.12)
        geo.firstMaterial?.diffuse.contents = UIColor.systemPurple
        geo.firstMaterial?.emission.contents = UIColor.systemPurple.withAlphaComponent(0.4)

        let ufo = EntityNode(kind: .ufo, geometry: geo)
        ufo.position = SCNVector3(-8, groundY + 8.0, 0)

        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: geo, options: nil))
        body.categoryBitMask = PhysicsCategory.ufo
        body.contactTestBitMask = PhysicsCategory.cube | PhysicsCategory.ground | PhysicsCategory.laser
        body.collisionBitMask = PhysicsCategory.none
        ufo.physicsBody = body

        enemyRoot.addChildNode(ufo)

        let travelDuration = Double(8.0 / gameState.difficulty)

        let moveRight = SCNAction.moveBy(x: 16, y: 0, z: 0, duration: travelDuration)
        let moveLeft = SCNAction.moveBy(x: -16, y: 0, z: 0, duration: travelDuration)

        let fire = SCNAction.run { [weak self, weak ufo] _ in
            guard let self = self, let ufo = ufo else { return }
            self.fireMissile(from: ufo)
        }

        let cycle = SCNAction.sequence([
            moveRight, .wait(duration: 0.4), fire, .wait(duration: 0.4),
            moveLeft, .wait(duration: 0.4), fire, .wait(duration: 0.4)
        ])

        ufo.runAction(.repeatForever(cycle))
    }

    func restartGame() {

        //--------------------------------------------------
        // Reset session
        //--------------------------------------------------

        gameSessionID = UUID()

        gameState.score = 0
        gameState.combo = 0
        gameState.isGameOver = false
        gameState.difficulty = 1.0


        //--------------------------------------------------
        // Reset grid movement
        //--------------------------------------------------

        gridDirection = 1
        gridOffset = 0
        gridRoot.position = SCNVector3Zero



        //--------------------------------------------------
        // Remove active objects
        //--------------------------------------------------

        enemyRoot.childNodes.forEach {
            $0.removeFromParentNode()
        }

        effectsRoot.childNodes.forEach {
            $0.removeFromParentNode()
        }

        gridRoot.childNodes.forEach {
            $0.removeFromParentNode()
        }


        //--------------------------------------------------
        // Remove lasers
        //--------------------------------------------------

        activeLasers.forEach {
            $0.removeFromParentNode()
        }

        activeLasers.removeAll()



        //--------------------------------------------------
        // Reset cube data
        //--------------------------------------------------

        slots.removeAll()
        slotMap.removeAll()



        //--------------------------------------------------
        // Reset AI tracking state
        //--------------------------------------------------

        grasshopperJumping.removeAll()
        centipedeDirection.removeAll()
        centipedeDropping.removeAll()
        spiderThreads.removeAll()
        spiderAnchorY.removeAll()
        ladybugDirection.removeAll()



        //--------------------------------------------------
        // Rebuild world
        //--------------------------------------------------

        setupGrid()



        //--------------------------------------------------
        // Respawn enemies
        //--------------------------------------------------

        spawnGrasshopper()

        spawnSpider()

        spawnLadybug()

        let headNode=spawnCentipedeHead(at: SCNVector3(-3, groundY + 5, 0))

        spawnCentipedeSegment(
            at: SCNVector3(
                -1,
                groundY + 5,
                wallZ
            ), follow:headNode
        )
        
        platformNode?.position.x = laserWorldPosition().x
    }
    func destroyLaser(
        _ laser: SCNNode,
        at position: SCNVector3
    ) {
        laser.physicsBody = nil
        laser.removeFromParentNode()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow pan and long press to work together so the player can aim while holding to fire
        let types: Set<String> = [String(describing: UILongPressGestureRecognizer.self), String(describing: UIPanGestureRecognizer.self)]
        let g1 = String(describing: type(of: gestureRecognizer))
        let g2 = String(describing: type(of: otherGestureRecognizer))
        if types.contains(g1) && types.contains(g2) {
            return true
        }
        return false
    }
}

struct GameView: UIViewControllerRepresentable {
    @ObservedObject var gameState: GameState

    func makeUIViewController(context: Context) -> GameViewController {
        GameViewController(gameState: gameState)
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
        uiViewController.gameState = gameState
    }
}
struct ContentView: View {
    @StateObject private var gameState = GameState()
    @State private var restartNonce = UUID()

    var body: some View {
        ZStack(alignment: .top) {
            GameView(gameState: gameState)
                .id(restartNonce)
                .ignoresSafeArea()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score: \(gameState.score)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Combo: \(gameState.combo)x")
                        .font(.subheadline)
                        .foregroundColor(.cyan)
                }
                .padding()
                Spacer()
            }
            .padding(.top, 40)

            VStack {
                Spacer()
                Text("Tap to fire • Pan to move laser • Two-finger slash for AoE")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
                    .padding(.bottom, 12)
            }
            .allowsHitTesting(false)

            if gameState.isGameOver {
                Color.black.opacity(0.75).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("GAME OVER")
                        .font(.largeTitle.bold())
                        .foregroundColor(.red)

                    Text("Final Score: \(gameState.score)")
                        .font(.title2)
                        .foregroundColor(.white)

                    Button {
                        gameState.score = 0
                        gameState.combo = 0
                        gameState.isGameOver = false
                        restartNonce = UUID()
                    } label: {
                        Text("Restart")
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    }
                }
            }
        }
        .background(Color.black)
    }
}

