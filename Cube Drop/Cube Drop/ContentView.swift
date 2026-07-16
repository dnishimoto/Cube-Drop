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

final class KnowledgeTree {

    enum EntityKind: String {

        case playerLaser
        case player

        case cube
        case pointObject
        case bonusObject

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

        case spawnsPointObject
        case spawnsMushroom

        case causesGameOver

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
        //--------------------------------------------------

        register(
            .cube,
            behaviors: [
                .blocksLaser,
                .destroyedByLaser,
                .spawnsPointObject
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
        // BONUS OBJECT
        //--------------------------------------------------

        register(
            .bonusObject,
            behaviors: [
                .fallsWithGravity,
                .destroyedByLaser,
                .awardsScore(100)
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
                .destroyedByLaser,
                .destroyedByMissile,
                .causesGameOver
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
                .spawnsMushroom
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
                .spawnsMushroom
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
                .destroyedByLaser
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
                .causesGameOver
            ],
            scoreValue: 120,
            weakness: [
                .playerLaser
            ],
            canBeTargetedByLaser: true
        )



        //--------------------------------------------------
        // LADYBUG
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
    static let pointObject: Int = 1 << 2
    static let bonusObject: Int = 1 << 3
    static let ufo: Int = 1 << 4
    static let missile: Int = 1 << 5
    static let centipede: Int = 1 << 6
    static let mushroom: Int = 1 << 7
    static let grasshopper: Int = 1 << 8
    static let spider: Int = 1 << 9
    static let ladybug: Int = 1 << 10
    static let ground: Int = 1 << 11
    static let player: Int = 1 << 12
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

final class GameViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {

    struct CubeSlot {
        let row: Int
        let col: Int
        let container: SCNNode
        var node: SCNNode?
        var isRespawning: Bool = false
    }

    let knowledge = KnowledgeTree()
    let gameState = GameState()

    var sceneView: SCNView!
    var scene: SCNScene!
    var cameraNode = SCNNode()

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
    
    var shouldSpawnMushroom = false
    var activeLasers: [SCNNode] = []
    
    var playerNode: SCNNode?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupPlayer()
        setupLighting()
        setupCamera()
        setupWorld()
        setupGrid()
        spawnGrasshopper()
        setupGestures()
        spawnCentipedeHead()

        spawnCentipedeSegment(
            at: SCNVector3(-2, groundY + 5, 0)
        )

        spawnCentipedeSegment(
            at: SCNVector3(-1, groundY + 5, 0)
        )

        spawnSpider()

        spawnLadybug()

        spawnGrasshopper()

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
    func spawnCentipedeHead() {

        let geo = SCNSphere(radius: 0.22)
        geo.firstMaterial?.diffuse.contents = UIColor.red
        geo.firstMaterial?.emission.contents = UIColor.red


        let node = EntityNode(
            kind: .centipedeHead,
            geometry: geo
        )

        node.name = "centipedeHead"

        node.position = SCNVector3(
            -3,
            groundY + 5,
            0
        )


        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(
                geometry: geo,
                options: nil
            )
        )

        body.categoryBitMask = PhysicsCategory.centipede

        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.cube |
            PhysicsCategory.player

        body.collisionBitMask =
            PhysicsCategory.none

        node.physicsBody = body


        enemyRoot.addChildNode(node)
    }
    func spawnLadybug() {

        let geo = SCNSphere(radius: 0.2)

        geo.firstMaterial?.diffuse.contents =
            UIColor.red


        let node = EntityNode(
            kind: .ladybug,
            geometry: geo
        )

        node.name = "ladybug"

        node.position = SCNVector3(
            5,
            groundY + 4,
            0
        )


        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(
                geometry: geo,
                options: nil
            )
        )


        body.categoryBitMask =
            PhysicsCategory.ladybug


        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.player


        node.physicsBody = body


        enemyRoot.addChildNode(node)
    }
    func spawnSpider() {

        let geo = SCNSphere(radius: 0.3)

        geo.firstMaterial?.diffuse.contents =
            UIColor.black


        let node = EntityNode(
            kind: .spider,
            geometry: geo
        )

        node.name = "spider"

        node.position = SCNVector3(
            3,
            groundY + 2,
            0
        )


        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(
                geometry: geo,
                options: nil
            )
        )


        body.categoryBitMask =
            PhysicsCategory.spider


        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.player


        node.physicsBody = body


        enemyRoot.addChildNode(node)
    }
    func spawnCentipedeSegment(
        at position: SCNVector3
    ) {

        let geo = SCNSphere(radius: 0.18)

        geo.firstMaterial?.diffuse.contents =
            UIColor.orange


        let node = EntityNode(
            kind: .centipedeSegment,
            geometry: geo
        )

        node.name = "centipedeSegment"

        node.position = position


        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(
                geometry: geo,
                options: nil
            )
        )


        body.categoryBitMask =
            PhysicsCategory.centipede


        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.cube |
            PhysicsCategory.player


        node.physicsBody = body


        enemyRoot.addChildNode(node)
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
        body.categoryBitMask = PhysicsCategory.cube

        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.missile

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
        sceneView.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.require(toFail: pan)
        sceneView.addGestureRecognizer(tap)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard !gameState.isGameOver else { return }
        let location = gesture.location(in: sceneView)
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

    func moveLaser(toScreenX x: CGFloat) {
        let fraction = max(0, min(1, x / sceneView.bounds.width))
        let newColumn = Int(round(fraction * CGFloat(gridWidth - 1)))
        laserColumn = max(0, min(gridWidth - 1, newColumn))
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

        switch node.name {

        case "pointObject":
            return .pointObject

        case "bonusObject":
            return .bonusObject

        case "cube":
            return .cube

        case "ufo":
            return .ufo

        case "missile":
            return .missile

        case "mushroom":
            return .mushroom

        case "grasshopper":
            return .grasshopper

        case "spider":
            return .spider

        case "ladybug":
            return .ladybug

        default:
            return nil
        }
    }

    func resolveHit(
        attacker: KnowledgeTree.EntityKind,
        target: SCNNode,
        contactPoint: SCNVector3
    ) {

        guard let targetKind = kind(of: target),
              let profile = knowledge.profile(for: targetKind)
        else {
            return
        }


        var shouldDestroy = false
        var scoreDelta = 0
        var spawnPoint = false
        var spawnMushroom = false
        var endGame = false


        //--------------------------------------------------
        // Read target behaviors
        //--------------------------------------------------

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


            case .spawnsPointObject:

                if targetKind == .cube {
                    spawnPoint = true
                }


            case .spawnsMushroom:

                spawnMushroom = true


            case .awardsScore(let value):

                scoreDelta += value


            case .causesGameOver:

                endGame = true


            default:
                break
            }
        }



        //--------------------------------------------------
        // Destroy object
        //--------------------------------------------------

        if shouldDestroy {

            destroy(
                node: target,
                kind: targetKind,
                at: contactPoint
            )
        }



        //--------------------------------------------------
        // Cube creates falling point
        //--------------------------------------------------

        if spawnPoint {

            spawnPointObject(
                at: contactPoint
            )
        }



        //--------------------------------------------------
        // Centipede creates mushroom
        //--------------------------------------------------

        if spawnMushroom {

            spawnMushroomFunc(
                at: contactPoint
            )
        }



        //--------------------------------------------------
        // Score
        //--------------------------------------------------

        if scoreDelta > 0 {

            gameState.score += scoreDelta
            gameState.combo += 1
        }



        //--------------------------------------------------
        // Game over
        //--------------------------------------------------

        if endGame {

            gameState.isGameOver = true
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

        let color =
            (node.geometry?.firstMaterial?.emission.contents as? UIColor)
            ?? .cyan

/*
        if kind != .cube {

            spawnExplosion(
                at: point,
                color: color
            )
        }
*/

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
       
        }



        //--------------------------------------------------
        // MISSILE DESTROYED
        //--------------------------------------------------
/*
        if kind == .missile {

            spawnExplosion(
                at: point,
                color: .orange
            )
        }
*/


        //--------------------------------------------------
        // CENTIPEDE DESTROYED
        //--------------------------------------------------

        if kind == .centipedeHead ||
           kind == .centipedeSegment {

            spawnMushroomFunc(
                at: point
            )
        }



        //--------------------------------------------------
        // BONUS OBJECT DESTROYED
        //--------------------------------------------------

        if kind == .bonusObject {

            destroyNearbyPoints(
                center: point,
                radius: 3.0
            )
        }



        //--------------------------------------------------
        // SCORE
        //--------------------------------------------------

        if let profile = knowledge.profile(for: kind) {

            gameState.score += profile.scoreValue
            gameState.combo += 1
        }
    }
    func spawnBurstRing(at position: SCNVector3, radius: Float) {

        let ring = SCNTorus(
            ringRadius: CGFloat(radius),
            pipeRadius: 0.03
        )

        ring.firstMaterial?.diffuse.contents = UIColor.yellow
        ring.firstMaterial?.emission.contents = UIColor.yellow
        ring.firstMaterial?.lightingModel = .constant


        let node = SCNNode(geometry: ring)
        node.position = position

        scene.rootNode.addChildNode(node)


        let expand = SCNAction.scale(
            to: 2.0,
            duration: 0.4
        )

        let fade = SCNAction.fadeOut(
            duration: 0.4
        )


        node.runAction(
            .sequence([
                .group([
                    expand,
                    fade
                ]),
                .removeFromParentNode()
            ])
        )
    }
    func destroyNearbyPoints(center: SCNVector3, radius: Float) {

        var pointsToDestroy: [SCNNode] = []

        enemyRoot.enumerateChildNodes { node, _ in

            guard self.kind(of: node) == .pointObject else {
                return
            }

            let distance = self.distanceBetween(
                node.worldPosition,
                center
            )

            if distance <= radius {
                pointsToDestroy.append(node)
            }
        }


        for point in pointsToDestroy {

            /*
            spawnExplosion(
                at: point.worldPosition,
                color: .yellow
            )
            */

            point.removeFromParentNode()

            gameState.score += 5
            gameState.combo += 1
        }


        spawnBurstRing(
            at: center,
            radius: radius
        )
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
    func bounceOffCube(
        grasshopper: SCNNode,
        normal: SCNVector3
    ) {

        guard let body = grasshopper.physicsBody else { return }

        let v = body.velocity

        let dot =
            v.x * normal.x +
            v.y * normal.y +
            v.z * normal.z

        body.velocity = SCNVector3(
            v.x - 2 * dot * normal.x,
            v.y,
            v.z - 2 * dot * normal.z
        )
    }
    func jumpToCube(
        grasshopper: SCNNode,
        cube: SCNNode
    ) {

        let top = cube.presentation.worldPosition

        let landing = SCNVector3(
            top.x,
            top.y + Float(cubeSize)/2 + 0.18,
            top.z
        )

        let jump = SCNAction.move(
            to: landing,
            duration: 0.45
        )

        jump.timingMode = .easeInEaseOut

        grasshopper.runAction(jump)
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
    func nextJumpTarget(
        from current: SCNNode,
        toward player: SCNNode
    ) -> SCNNode? {

        let maxJump: Float = 2.2

        let cubes = activeCubeNodes()

        var best: SCNNode?
        var bestScore = Float.greatestFiniteMagnitude

        for cube in cubes {

            let dx = cube.position.x - current.position.x
            let dy = cube.position.y - current.position.y

            let distance = sqrt(dx*dx + dy*dy)

            guard distance <= maxJump else { continue }

            // score = distance from this cube to player
            let score = distanceBetween(
                cube.position,
                player.position
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

        let geo = SCNSphere(radius: 0.25)
        geo.firstMaterial?.diffuse.contents = UIColor.systemOrange
        geo.firstMaterial?.emission.contents =
            UIColor.systemOrange.withAlphaComponent(0.45)

        let node = EntityNode(
            kind: .pointObject,
            geometry: geo
        )

        // IMPORTANT:
        // convert world position to scene coordinates
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
            PhysicsCategory.ground

        // Enable physics movement
        body.isAffectedByGravity = true

        // Add downward force because world gravity is zero
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
    func moveLasers(dt: TimeInterval) {
        guard scene != nil else { return }

        let laserNodes: [SCNNode] = scene.rootNode.childNodes(passingTest: { (node: SCNNode, _: UnsafeMutablePointer<ObjCBool>) -> Bool in
            node.name == "laserBolt"
        })

        for node in laserNodes {
            let speed : Double = 18
            node.position.y += Float(speed * dt)

            if node.position.y > 20 {
                node.removeFromParentNode()
            }
        }
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
            PhysicsCategory.bonusObject |
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
    }
    func laserWorldPosition() -> SCNVector3 {
        let pitch = Float(cubeSize + cubeSpacing)
        let x = -Float(gridWidth) * pitch / 2 + Float(laserColumn) * pitch + pitch / 2
        return SCNVector3(x, groundY + 0.6, wallZ)
    }
    //---------------------------------------------------------
    // Find the nearest cube the grasshopper can jump to
    //---------------------------------------------------------
    //---------------------------------------------------------
    // Choose the best cube toward the player
    //---------------------------------------------------------
    func nearestReachableCube(
        from position: SCNVector3,
        maxDistance: Float
    ) -> SCNNode? {

        guard let player = playerNode else { return nil }

        var bestCube: SCNNode?
        var bestScore = Float.greatestFiniteMagnitude

        for cube in activeCubeNodes() {

            let cubePos = cube.presentation.worldPosition

            let landingPoint = SCNVector3(
                cubePos.x,
                cubePos.y + Float(cubeSize) * 0.6,
                cubePos.z
            )

            // Can the grasshopper reach this cube?
            let jumpDistance = distanceBetween(
                position,
                landingPoint
            )

            guard jumpDistance <= maxDistance else {
                continue
            }

            // How close would this cube put us to the player?
            let playerDistance = distanceBetween(
                landingPoint,
                player.presentation.worldPosition
            )

            if playerDistance < bestScore {

                bestScore = playerDistance
                bestCube = cube
            }
        }

        return bestCube
    }
    //---------------------------------------------------------
    // Grasshopper falls to the ground and disappears
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

            /*self.spawnExplosion(
                at: node.position,
                color: .brown
            )*/
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
    func updateGrasshopper(_ grasshopper: SCNNode) {

        // Prevent multiple jumps at the same time
        if grasshopper.action(forKey: "jumping") != nil {
            return
        }


        let maxJump: Float = 2.5


        guard let player = playerNode else {
            return
        }


        let grasshopperPosition =
            grasshopper.presentation.worldPosition

        let playerPosition =
            player.presentation.worldPosition


        let playerDistance =
            distanceBetween(
                grasshopperPosition,
                playerPosition
            )


        //--------------------------------------------------
        // JUMP TO PLAYER
        //--------------------------------------------------

        if playerDistance <= maxJump {

            grasshopper.runAction(
                .sequence([
                    .run { [weak self, weak grasshopper] _ in
                        guard let self,
                              let grasshopper else { return }

                        self.jumpToPlayer(grasshopper)
                    }
                ]),
                forKey: "jumping"
            )

            return
        }



        //--------------------------------------------------
        // JUMP TO NEAREST CUBE
        //--------------------------------------------------

        if let cube = nearestReachableCube(
            from: grasshopperPosition,
            maxDistance: maxJump
        ) {

            grasshopper.runAction(
                .sequence([
                    .run { [weak self, weak grasshopper] _ in
                        guard let self,
                              let grasshopper else { return }

                        self.jumpToCube(
                            grasshopper: grasshopper,
                            cube: cube
                        )
                    }
                ]),
                forKey: "jumping"
            )

            return
        }



        //--------------------------------------------------
        // NO AVAILABLE TARGET
        // WAIT INSTEAD OF DYING
        //--------------------------------------------------

        grasshopper.runAction(
            .wait(duration: 0.5),
            forKey: "waiting"
        )
    }
    //---------------------------------------------------------
    // Grasshopper jumps directly to the player
    //---------------------------------------------------------
    func jumpToPlayer(_ grasshopper: SCNNode) {

        guard let player = playerNode else { return }

        let start = grasshopper.presentation.position
        let end = player.presentation.position

        let peakHeight: Float = 1.5

        let mid = SCNVector3(
            (start.x + end.x) * 0.5,
            max(start.y, end.y) + peakHeight,
            (start.z + end.z) * 0.5
        )


        //--------------------------------------------------
        // Three point jump arc
        //--------------------------------------------------

        let rise = SCNAction.move(
            to: mid,
            duration: 0.25
        )

        rise.timingMode = .easeOut


        let descend = SCNAction.move(
            to: end,
            duration: 0.30
        )

        descend.timingMode = .easeIn


        let jump = SCNAction.sequence([
            rise,
            descend
        ])


        grasshopper.runAction(jump) { [weak self, weak grasshopper] in

            guard let self = self,
                  let grasshopper = grasshopper else {
                return
            }


            let distance = self.distanceBetween(
                grasshopper.presentation.position,
                player.presentation.position
            )


            if distance < 0.35 {

                self.gameState.isGameOver = true

            } else {

                self.updateGrasshopper(grasshopper)

            }
        }
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
    func updateEntities(dt: TimeInterval) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let kind = self.kind(of: node) else { return }

            switch kind {
            case .pointObject:
                if node.position.y < self.groundY - 6 {
                    node.removeFromParentNode()
                }

            case .ufo:
                node.position.x += Float(dt) * 1.0 * Float(self.gameState.difficulty)

            case .missile:
                node.position.y -= Float(dt) * 3.5 * Float(self.gameState.difficulty)

            case .spider:
                node.position.y -= Float(dt) * 0.5 * Float(self.gameState.difficulty)

            case .ladybug:
                node.position.y -= Float(dt) * 0.2 * Float(self.gameState.difficulty)

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
        missile.position = ufo.position
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

    func spawnBonusObject(at worldPosition: SCNVector3) {
        let geo = SCNPyramid(width: 0.5, height: 0.6, length: 0.5)
        geo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        geo.firstMaterial?.emission.contents = UIColor.systemYellow.withAlphaComponent(0.35)

        let node = EntityNode(kind: .bonusObject, geometry: geo)
        node.position = worldPosition

        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geo, options: nil))
        body.categoryBitMask = PhysicsCategory.bonusObject
        body.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.laser
        body.collisionBitMask = PhysicsCategory.ground
        body.isAffectedByGravity = true
        node.physicsBody = body

        enemyRoot.addChildNode(node)
    }

    func spawnHitBurst(at position: SCNVector3, color: UIColor) {
        let ps = SCNParticleSystem()
        ps.birthRate = 280
        ps.emissionDuration = 0.05
        ps.particleLifeSpan = 0.45
        ps.particleSize = 0.028
        ps.particleColor = color
        ps.spreadingAngle = 160
        ps.particleVelocity = 1.8
        ps.particleVelocityVariation = 1.3
        ps.acceleration = SCNVector3(0, -2.5, 0)
        ps.blendMode = .additive

        let emitter = SCNNode()
        emitter.position = position
        scene.rootNode.addChildNode(emitter)
        emitter.addParticleSystem(ps)
        emitter.runAction(.sequence([.wait(duration: 1.0), .removeFromParentNode()]))
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
        // ONLY PLAYER LASER DESTROYS CUBES
        //--------------------------------------------------

        let isLaserA =
            categoryA == PhysicsCategory.laser

        let isLaserB =
            categoryB == PhysicsCategory.laser


        if isLaserA,
           let targetKind = kindB {

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


        if isLaserB,
           let targetKind = kindA {

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
        // MISSILE HITS PLAYER ONLY
        // NO MISSILE-CUBE DETECTION
        //--------------------------------------------------

        let isMissileA =
            categoryA == PhysicsCategory.missile

        let isMissileB =
            categoryB == PhysicsCategory.missile


        if isMissileA &&
           categoryB == PhysicsCategory.player {

            gameState.isGameOver = true
            /*
            spawnExplosion(
                at: contact.contactPoint,
                color: .red
            )
             */

            a.removeFromParentNode()

            return
        }


        if isMissileB &&
           categoryA == PhysicsCategory.player {

            gameState.isGameOver = true
            /*
            spawnExplosion(
                at: contact.contactPoint,
                color: .red
            )
             */
            b.removeFromParentNode()

            return
        }



        //--------------------------------------------------
        // POINT OBJECT HITS GROUND
        //--------------------------------------------------

        if categoryA == PhysicsCategory.pointObject &&
           categoryB == PhysicsCategory.ground {

            a.removeFromParentNode()

            return
        }


        if categoryB == PhysicsCategory.pointObject &&
           categoryA == PhysicsCategory.ground {

            b.removeFromParentNode()

            return
        }



        //--------------------------------------------------
        // BONUS OBJECT HITS GROUND
        //--------------------------------------------------

        if categoryA == PhysicsCategory.bonusObject &&
           categoryB == PhysicsCategory.ground {

            a.removeFromParentNode()

            return
        }


        if categoryB == PhysicsCategory.bonusObject &&
           categoryA == PhysicsCategory.ground {

            b.removeFromParentNode()

            return
        }
    }
    func renderer(
        _ renderer: SCNSceneRenderer,
        updateAtTime time: TimeInterval
    ) {

        //--------------------------------------------------
        // Calculate delta time
        //--------------------------------------------------

        let dt = lastUpdateTime == 0
            ? 0
            : time - lastUpdateTime

        lastUpdateTime = time


        //--------------------------------------------------
        // Stop updates after game over
        //--------------------------------------------------

        if gameState.isGameOver {
            return
        }


        //--------------------------------------------------
        // Difficulty scaling
        //--------------------------------------------------

        updateDifficulty()


        //--------------------------------------------------
        // Respawn cubes if all destroyed
        //--------------------------------------------------

        if allCubesGone() {
            respawnAllCubes()
        }


        //--------------------------------------------------
        // Automatic laser fire
        //--------------------------------------------------

        if autoFireEnabled,
           time - lastAutoFireTime >= autoFireInterval {

            lastAutoFireTime = time
            fireLaser()
        }


        //--------------------------------------------------
        // UFO spawning
        //--------------------------------------------------

        if time - lastFireTime >
            max(0.6, 2.5 / gameState.difficulty) {

            lastFireTime = time
            spawnUFOIfNeeded()
        }


        //--------------------------------------------------
        // Move cube grid
        //--------------------------------------------------

        gridOffset +=
            gridDirection *
            gridSpeed *
            Float(dt)

        gridRoot.position.x = gridOffset


        if abs(gridOffset) >= gridMaxOffset {

            gridDirection *= -1

            gridOffset = max(
                min(gridOffset, gridMaxOffset),
                -gridMaxOffset
            )

            gridRoot.position.y -= 0.5


            if gridRoot.position.y <= -4.5 {
                gameState.isGameOver = true
            }
        }



        //--------------------------------------------------
        // GRASSHOPPER AI UPDATE
        //--------------------------------------------------

        scene.rootNode.enumerateChildNodes { [weak self] node, _ in

            guard let self = self else {
                return
            }


            if let grasshopper = node as? EntityNode,
               grasshopper.kind == .grasshopper {


                self.updateGrasshopper(
                    grasshopper
                )
            }
        }



        //--------------------------------------------------
        // Enemy movement
        //--------------------------------------------------

        updateEntities(
            dt: dt
        )


        //--------------------------------------------------
        // Laser movement
        //--------------------------------------------------

        updateLasers(
            dt: dt
        )
    }
    func spawnGrasshopper() {

        let geo = SCNSphere(radius: 0.25)

        geo.firstMaterial?.diffuse.contents = UIColor.green
        geo.firstMaterial?.emission.contents = UIColor.green


        let grasshopper = EntityNode(
            kind: .grasshopper,
            geometry: geo
        )


        grasshopper.name = "grasshopper"


        grasshopper.position = SCNVector3(
            0,
            groundY + 5,
            0
        )


        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(
                geometry: geo,
                options: nil
            )
        )


        body.categoryBitMask =
            PhysicsCategory.grasshopper


        body.contactTestBitMask =
            PhysicsCategory.cube |
            PhysicsCategory.player |
            PhysicsCategory.laser


        body.collisionBitMask =
            PhysicsCategory.cube


        grasshopper.physicsBody = body


        enemyRoot.addChildNode(
            grasshopper
        )
    }
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

        let moveRight = SCNAction.moveBy(x: 16, y: 0, z: 0, duration: Double(8.0 / gameState.difficulty))
        let fire = SCNAction.run { [weak self, weak ufo] _ in
            guard let self, let ufo else { return }
            self.fireMissile(from: ufo)
        }
        let seq = SCNAction.sequence([moveRight, .wait(duration: 0.5), fire, .wait(duration: 0.5)])
        ufo.runAction(.repeatForever(seq))
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
        // Rebuild world
        //--------------------------------------------------

        setupGrid()



        //--------------------------------------------------
        // Respawn enemies
        //--------------------------------------------------

        spawnGrasshopper()

        spawnSpider()

        spawnLadybug()


        spawnCentipedeHead()

        spawnCentipedeSegment(
            at: SCNVector3(
                -2,
                groundY + 5,
                wallZ
            )
        )

        spawnCentipedeSegment(
            at: SCNVector3(
                -1,
                groundY + 5,
                wallZ
            )
        )
    }
    func destroyLaser(
        _ laser: SCNNode,
        at position: SCNVector3
    ) {

        //spawnExplosion(
        //    at: position,
       //     color: .cyan
       // )

        laser.physicsBody = nil
        laser.removeFromParentNode()
    }
}

struct GameView: UIViewControllerRepresentable {
    @ObservedObject var gameState: GameState

    func makeUIViewController(context: Context) -> GameViewController {
        let vc = GameViewController()
        return vc
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
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
                Text("Tap to fire • Pan to move laser")
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
