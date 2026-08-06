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

final class GameViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate, UIGestureRecognizerDelegate {
    let knowledge = KnowledgeTree()
    var gameState: GameState

    var longPressFireTimer: Timer?
    var longPressFireInterval: TimeInterval = 0.10

    init(gameState: GameState) {
        self.gameState = gameState
  
        super.init(nibName: nil, bundle: nil)
      
        self.gameState.setPlaySoundFlag = { [weak self] value in
            self?.setPlaySoundFlag(paramPlaySoundFlag: value)
        }
        self.gameState.cameraLower = { [weak self] in
            self?.cameraLower()
        }

        self.gameState.cameraRaise = { [weak self] in
            self?.cameraRaise()
        }
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
    return groundY + cubeDistanceFromGround + Float(gridHeight - 1) * pitch
    }
    var pointObjectSpawnChance: Int = 18
    var centipedeFollowTarget: [ObjectIdentifier: SCNNode] = [:]
    var centipedeTrailSpacing: Float = 0.55
    var centipedeLastPosition: [ObjectIdentifier: SCNVector3] = [:]

    var gridRoot = SCNNode()
    var enemyRoot = SCNNode()
    var effectsRoot = SCNNode()

    var slots: [[CubeSlot]] = []
    var slotMap: [ObjectIdentifier: (row: Int, col: Int)] = [:]

    var lastUpdateTime: TimeInterval = 0
    var lastFireTime: TimeInterval = 0

    var lastFlySpawnTime: TimeInterval = 0
    var flySpawnInterval: TimeInterval = 6.0
    
    private var lastUFOCheckTime: TimeInterval = 0
    private var ufoCheckInterval: TimeInterval = 2.0  // check every 2 seconds
    
    var centipedeBounces: [ObjectIdentifier: Int] = [:]
    var centipedeBounceTargetX: [ObjectIdentifier: Float] = [:]
    var centipedeJustHitGround: [ObjectIdentifier: Bool] = [:]  // new

    var laserColumn: Int = 8
    var gridDirection: Float = 1
    var gridOffset: Float = 0
    var gridSpeed: Float = 0.18
    var gridMaxOffset: Float = 2.0

    var cubeSize: CGFloat = 0.5
    var cubeSpacing: CGFloat = 0.06
    var groundY: Float = -6.0
    var wallZ: Float = 0.0

    var fliesToRemove: [SCNNode] = []

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
    var removeQueue: [SCNNode] = []

    // Centipede AI state
    var centipedeDirection: [ObjectIdentifier: Float] = [:]
    var centipedeDropping = Set<ObjectIdentifier>()
    var grasshopperLeaping = Set<ObjectIdentifier>()

    // Spider AI state
    var spiderAnchorY: [ObjectIdentifier: Float] = [:]
    var spiderThreads: [ObjectIdentifier: SCNNode] = [:]

    // Ladybug AI state
    var ladybugDirection: [ObjectIdentifier: Float] = [:]

    private var slashStartScreenPoint: CGPoint?
    private var slashEndScreenPoint: CGPoint?

    var flyWobble: [ObjectIdentifier: Float] = [:]
    var flyChaos: [ObjectIdentifier: Float] = [:]

    var cameraTarget = SCNVector3(0, 0, 0)
    var cameraDistance: Float = 16
    var cameraHeight: Float = -5
    var cameraYaw: Float = 0
    var cameraPitch: Float = -0.12
    private var lastGrasshopperSpawnTime: TimeInterval = 0
    private var grasshopperSpawnInterval: TimeInterval = 6.0
    
    private var isProcessingFrame = false
    private var pendingRestart = false
    private var pendingRespawnAllCubes = false
    //private var pendingNodeRemovals = [SCNNode]()
    private var skySphere: SCNNode?
    
    // Add these properties to your class:
    var centipedeFalling = Set<ObjectIdentifier>()
    var grasshopperFalling = Set<ObjectIdentifier>()
    let gravity: Float = -4.0


    var cubeDistanceFromGround: Float = 5.0
    private lazy var cubeNormalMap: UIImage? = {
        noiseTexture(size: 256)   // 256 is plenty; smaller = faster
    }()
    @State var topY : Float = 0
    private var entityIndex: [ObjectIdentifier: EntityNode] = [:]
    
    var centipedeLeaders = Set<ObjectIdentifier>()          // <-- add this
    
    @Published var playSoundFlag: Bool = false
  
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
        spawnSpider()
        spawnLadybug()
        spawnFly()
        scene.physicsWorld.contactDelegate = self
        scene.physicsWorld.gravity =  SCNVector3(0, gravity, 0)
        sceneView.delegate = self
        sceneView.isPlaying = true
        sceneView.loops = true
    }
    func setPlaySoundFlag(paramPlaySoundFlag : Bool)
    {
        self.playSoundFlag = paramPlaySoundFlag
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

        setupSkySphere()
    }
    func replaceSegmentWithHead(_ segment: SCNNode, inheritFrom oldHead: SCNNode?) -> SCNNode {
        let oldHeadID = oldHead.map { ObjectIdentifier($0) }
        let segmentID = ObjectIdentifier(segment)

        // Remember position & direction
        let worldPos = segment.presentation.worldPosition
        let direction = oldHeadID.flatMap { centipedeDirection[$0] } ?? centipedeDirection[segmentID] ?? 1.0

        // Remove old segment from tracking
        centipedeFollowTarget.removeValue(forKey: segmentID)
        centipedeDirection.removeValue(forKey: segmentID)
        centipedeLastPosition.removeValue(forKey: segmentID)

        // Remove segment from scene (it will be cleaned up via removeQueue)
        removeQueue.append(segment)

        // Spawn a new head at the same position
        let newHead = spawnCentipedeHead(at: worldPos)
        let newHeadID = ObjectIdentifier(newHead)

        // Set direction
        centipedeDirection[newHeadID] = direction

        // Update any segment that was following the old head OR this segment to follow the new head
        for (segID, target) in centipedeFollowTarget {
            let targetID = ObjectIdentifier(target)
            if let oldID = oldHeadID, targetID == oldID || targetID == segmentID {
                centipedeFollowTarget[segID] = newHead
            }
        }

        // Update leaders set
        if let oldID = oldHeadID {
            centipedeLeaders.remove(oldID)
        }
        centipedeLeaders.insert(newHeadID)

        return newHead
    }
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let a = contact.nodeA
        let b = contact.nodeB

        let kindA = kind(of: a)
        let kindB = kind(of: b)

        let categoryA = a.physicsBody?.categoryBitMask ?? PhysicsCategory.none
        let categoryB = b.physicsBody?.categoryBitMask ?? PhysicsCategory.none

        // --------------------------------------------------
        // PLAYER LASER HITS OBJECT
        // --------------------------------------------------
        let isLaserA = categoryA == PhysicsCategory.laser
        let isLaserB = categoryB == PhysicsCategory.laser

        if isLaserA, kindB != nil {
            resolveHit(attacker: .playerLaser, target: b, contactPoint: contact.contactPoint)
            destroyLaser(a, at: contact.contactPoint)
            return
        }

        if isLaserB, kindA != nil {
            resolveHit(attacker: .playerLaser, target: a, contactPoint: contact.contactPoint)
            destroyLaser(b, at: contact.contactPoint)
            return
        }

        // --------------------------------------------------
        // MISSILE HITS CUBE
        // --------------------------------------------------
        let isMissileA = categoryA == PhysicsCategory.missile
        let isMissileB = categoryB == PhysicsCategory.missile

        if isMissileA && categoryB == PhysicsCategory.cube {
            spawnExplosion(at: contact.contactPoint, color: .systemRed)
            removeQueue.append(a)
            return
        }

        if isMissileB && categoryA == PhysicsCategory.cube {
            spawnExplosion(at: contact.contactPoint, color: .systemRed)
            removeQueue.append(b)
            return
        }

        if isMissileA, let kindB = kindB, kindB == .pointObject {
            removeQueue.append(b)
            removeQueue.append(a)
            return
        }

        if isMissileB, let kindA = kindA, kindA == .pointObject {
            removeQueue.append(a)
            removeQueue.append(b)
            return
        }

        // --------------------------------------------------
        // MISSILE HITS PLAYER -> GAME OVER
        // --------------------------------------------------
        if isMissileA && categoryB == PhysicsCategory.player {
            if !gameState.isGameOver {
                gameState.isGameOver = true
                spawnExplosion(at: contact.contactPoint, color: .red)
                if playSoundFlag {
                    playSound(GameSound.gameOver.rawValue)
                }
                
            }
            removeQueue.append(a)
            return
        }

        if isMissileB && categoryA == PhysicsCategory.player {
            if !gameState.isGameOver {
                gameState.isGameOver = true
                spawnExplosion(at: contact.contactPoint, color: .red)
                if playSoundFlag {
                    playSound(GameSound.gameOver.rawValue)}
            }
            removeQueue.append(b)
            return
        }

        // --------------------------------------------------
        // SPIDER / CENTIPEDE / GRASSHOPPER TOUCHES PLAYER -> GAME OVER
        // --------------------------------------------------
        let dangerousCategories =
            PhysicsCategory.spider |
            PhysicsCategory.centipedeHead |
            PhysicsCategory.centipedeSegment |
            PhysicsCategory.grasshopper

        if (categoryA & dangerousCategories) != 0 && categoryB == PhysicsCategory.player {
            triggerGameOverFromEnemyContact(node: a, at: contact.contactPoint)
            return
        }

        if (categoryB & dangerousCategories) != 0 && categoryA == PhysicsCategory.player {
            triggerGameOverFromEnemyContact(node: b, at: contact.contactPoint)
            return
        }

        // --------------------------------------------------
        // FLY HITS PLAYER -> DEDUCT POINTS, REMOVE FLY
        // --------------------------------------------------
        if categoryA == PhysicsCategory.fly && categoryB == PhysicsCategory.player {
            handleFlyHitPlayer(fly: a)
            return
        }

        if categoryB == PhysicsCategory.fly && categoryA == PhysicsCategory.player {
            handleFlyHitPlayer(fly: b)
            return
        }
        // --------------------------------------------------
        // FLY HITS GROUND -> DEDUCT POINTS, REMOVE FLY
        // --------------------------------------------------
        if categoryA == PhysicsCategory.fly && categoryB == PhysicsCategory.ground {
            handleFlyHitGround(fly: a)
            return
        }

        if categoryB == PhysicsCategory.fly && categoryA == PhysicsCategory.ground {
            handleFlyHitGround(fly: b)
            return
        }
        // --------------------------------------------------
        // POINT / BONUS OBJECT HITS GROUND
        // --------------------------------------------------
        if let kA = kindA, (kA == .pointObject || kA == .bonusPointObject),
           categoryB == PhysicsCategory.ground {
            removeQueue.append(a)
            return
        }

        if let kB = kindB, (kB == .pointObject || kB == .bonusPointObject),
           categoryA == PhysicsCategory.ground {
            removeQueue.append(b)
            return
        }
    }
    private func skyGradientWithStars(size: Int) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let cg = ctx.cgContext

            // Blue → purple vertical gradient
            let topColor = UIColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1.0).cgColor
            let bottomColor = UIColor(red: 0.4, green: 0.1, blue: 0.6, alpha: 1.0).cgColor

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [topColor, bottomColor] as CFArray,
                                      locations: [0.0, 1.0])!

            let startPoint = CGPoint(x: size / 2, y: 0)
            let endPoint = CGPoint(x: size / 2, y: size)

            cg.drawLinearGradient(gradient,
                                  start: startPoint,
                                  end: endPoint,
                                  options: [])

            // Draw stars
            let starCount = size * size / 250
            for _ in 0..<starCount {
                let x = CGFloat.random(in: 0..<CGFloat(size))
                let y = CGFloat.random(in: 0..<CGFloat(size))
                let r = CGFloat.random(in: 0.4...1.2)

                let alpha = CGFloat.random(in: 0.5...1.0)
                UIColor(white: 1.0, alpha: alpha).setFill()

                let starRect = CGRect(x: x - r, y: y - r, width: 2*r, height: 2*r)
                cg.fillEllipse(in: starRect)
            }
        }
    }
    private func setupSkySphere() {
        let radius: CGFloat = 120.0
        let sphere = SCNSphere(radius: radius)
        sphere.segmentCount = 64

        // Create stars-only texture (transparent background)
        if let starsImage = starsTexture(size: 1024) {
            let material = SCNMaterial()

            // Base blue–purple gradient as diffuse
            if let gradientImage = skyGradientTexture(size: 1024) {
                material.diffuse.contents = gradientImage
            } else {
                material.diffuse.contents = UIColor(red: 0.2, green: 0.15, blue: 0.5, alpha: 1.0)
            }

            // Stars as emission so they glow
            material.emission.contents = starsImage
            material.emission.intensity = 1.2

            material.isDoubleSided = true
            material.lightingModel = .constant

            sphere.materials = [material]
        } else {
            // Fallback: just gradient sky, no stars
            let material = SCNMaterial()
            if let gradientImage = skyGradientTexture(size: 1024) {
                material.diffuse.contents = gradientImage
            } else {
                material.diffuse.contents = UIColor(red: 0.2, green: 0.15, blue: 0.5, alpha: 1.0)
            }
            material.lightingModel = .constant
            material.isDoubleSided = true
            sphere.materials = [material]
        }

        let skyNode = SCNNode(geometry: sphere)
        skyNode.position = SCNVector3(0, 0, 0)
        skyNode.renderingOrder = -100

        scene.rootNode.addChildNode(skyNode)
        skySphere = skyNode
    }
    private func skyGradientTexture(size: Int) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let width = CGFloat(size)
            let height = CGFloat(size)
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            let cg = ctx.cgContext

            // Blue → purple vertical gradient
            let topColor = UIColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1.0).cgColor
            let bottomColor = UIColor(red: 0.4, green: 0.1, blue: 0.6, alpha: 1.0).cgColor

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [topColor, bottomColor] as CFArray,
                                      locations: [0.0, 1.0])!

            let startPoint = CGPoint(x: width / 2, y: 0)
            let endPoint = CGPoint(x: width / 2, y: height)

            cg.drawLinearGradient(gradient,
                                  start: startPoint,
                                  end: endPoint,
                                  options: [])
        }
    }
    private func starsTexture(size: Int) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let width = CGFloat(size)
            let height = CGFloat(size)
            let rect = CGRect(x: 0, y: 0, width: width, height: height)

            // Transparent background
            ctx.cgContext.clear(rect)

            // Draw many small white stars
            let starCount = Int(width * height) / 180  // increase if you want more stars
            for _ in 0..<starCount {
                let x = CGFloat.random(in: 0..<width)
                let y = CGFloat.random(in: 0..<height)
                let r = CGFloat.random(in: 0.5...1.5)

                let alpha = CGFloat.random(in: 0.7...1.0)
                UIColor(white: 1.0, alpha: alpha).setFill()

                let starRect = CGRect(x: x - r, y: y - r, width: 2*r, height: 2*r)
                ctx.cgContext.fillEllipse(in: starRect)
            }
        }
    }
    @discardableResult
      func addEntity(_ node: EntityNode, to parent: SCNNode? = nil) -> EntityNode {
         // registerEntity(node)
          let targetParent = parent ?? enemyRoot
          targetParent.addChildNode(node)
          return node
      }
/*
      func removeEntity(_ node: SCNNode) {
          unregisterEntity(node)
          if let kind = kind(of: node) {
              cleanupTrackingState(for: node, kind: kind)
          }
          node.removeAllActions()
          node.physicsBody = nil
          node.constraints = nil
          node.removeFromParentNode()
      }
 */
    func setupPlayer() {
        let size = cubeSize * 1.4
        let icon = makeLabelBillboard(text: "", color: .cyan, worldSize: size)

        let player = EntityNode(
            kind: .player,
            geometry: icon
        )

        player.name = "player"
        player.position = SCNVector3(0, groundY + 0.4, wallZ)
        player.scale = SCNVector3(1.1, 1.1, 1.1)

        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: labelPhysicsShape(size: size)
        )

        body.categoryBitMask = PhysicsCategory.player
        body.contactTestBitMask =
            PhysicsCategory.missile |
            PhysicsCategory.grasshopper |
            PhysicsCategory.spider |
            PhysicsCategory.centipedeHead |
            PhysicsCategory.centipedeSegment |
            PhysicsCategory.ladybug |
            PhysicsCategory.fly

        body.collisionBitMask = PhysicsCategory.none
        player.physicsBody = body

        playerNode = player
        addEntity(player, to: scene.rootNode)
    }

    func setupPlayerPlatform() {
        // Tank hull dimensions
        let width  = CGFloat(cubeSize + cubeSpacing) * 1.4
        let height = CGFloat(cubeSize) * 0.6
        let depth  = CGFloat(cubeSize + cubeSpacing) * 1.2

        // Convert to Float once for scene calculations
        let floatHeight = CGFloat(height)
        let floatDepth  = CGFloat(depth)

        // Hull (tank body)
        let hullBox = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.06)
        hullBox.firstMaterial?.diffuse.contents = UIColor(white: 0.25, alpha: 1.0)
        hullBox.firstMaterial?.emission.contents = UIColor(white: 0.05, alpha: 1.0)
        hullBox.firstMaterial?.lightingModel = SCNMaterial.LightingModel.physicallyBased
        hullBox.firstMaterial?.metalness.contents = 0.6
        hullBox.firstMaterial?.roughness.contents = 0.5

        let hullNode = SCNNode(geometry: hullBox)
        hullNode.name = "playerPlatform"

        let x = laserWorldPosition().x
        hullNode.position = SCNVector3(x, groundY + Float(floatHeight * 0.5), wallZ)
        hullNode.renderingOrder = 10

        // Turret (rotating part on top of hull)
        let turretRadius  = CGFloat(floatHeight * 0.35)
        let turretHeight = CGFloat(floatHeight * 0.7)
        let turretGeo = SCNCylinder(radius: turretRadius, height: turretHeight)
        turretGeo.firstMaterial?.diffuse.contents = UIColor(white: 0.35, alpha: 1.0)
        turretGeo.firstMaterial?.emission.contents = UIColor(white: 0.07, alpha: 1.0)
        turretGeo.firstMaterial?.lightingModel = SCNMaterial.LightingModel.physicallyBased
        turretGeo.firstMaterial?.metalness.contents = 0.7
        turretGeo.firstMaterial?.roughness.contents = 0.4

        let turretNode = SCNNode(geometry: turretGeo)
        turretNode.name = "playerTurret"
        turretNode.position = SCNVector3(0, floatHeight * 0.5 + turretHeight * 0.5, 0)
        hullNode.addChildNode(turretNode)

        // Gun barrel
        let barrelRadius = floatHeight * 0.12
        let barrelLength = floatDepth * 0.9
        let barrelGeo = SCNCylinder(radius: barrelRadius, height: barrelLength)
        barrelGeo.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1.0)
        barrelGeo.firstMaterial?.emission.contents = UIColor(white: 0.04, alpha: 1.0)
        barrelGeo.firstMaterial?.lightingModel = SCNMaterial.LightingModel.physicallyBased
        barrelGeo.firstMaterial?.metalness.contents = 0.8
        barrelGeo.firstMaterial?.roughness.contents = 0.3

        let barrelNode = SCNNode(geometry: barrelGeo)
        barrelNode.name = "playerBarrel"
        // Point barrel forward along +Z
        barrelNode.eulerAngles = SCNVector3(Float.pi * 0.5, 0, 0)
        barrelNode.position = SCNVector3(0, floatHeight * 0.5 + turretHeight * 0.2, floatDepth * 0.6)
        turretNode.addChildNode(barrelNode)

        // No physics body (purely visual, like before)
        scene.rootNode.addChildNode(hullNode)
        platformNode = hullNode
    }

    func setupCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 50
        camera.zFar = 120
        cameraNode.camera = camera

        scene.rootNode.addChildNode(cameraNode)
        updateCamera()
    }

    func cameraLower() {
        if cameraHeight-1 < -5 { return }
        cameraHeight -= 1
        updateCamera()
    }

    func cameraRaise() {
        if cameraHeight-1 > 10 { return }
        cameraHeight += 1
        updateCamera()
    }
    func updateCamera() {
        let x = cameraTarget.x + sin(cameraYaw) * cameraDistance
        let z = cameraTarget.z + cos(cameraYaw) * cameraDistance
        let y = cameraTarget.y + cameraHeight + cameraPitch

        cameraNode.position = SCNVector3(x, y, z)
        cameraNode.look(at: cameraTarget)
    }
    func updatePlayer() {
        guard let player = playerNode else { return }

        let targetX = laserWorldPosition().x
        let current = player.position

        let smoothing: Float = 0.22
        let newX = current.x + (targetX - current.x) * smoothing

        player.position = SCNVector3(
            newX,
            groundY + 0.4,
            wallZ
        )

        player.physicsBody?.resetTransform()

        if let platform = platformNode {
            platform.position.x = newX
        }
    }
    @discardableResult
    func spawnCentipedeHead(at worldPosition: SCNVector3) -> SCNNode {

        let size = cubeSize * 1.3

        let plane = makeLabelBillboard(
            text: "👾",
            color: nil,
            worldSize: size
        )

        let node = EntityNode(
            kind: .centipedeHead,
            geometry: plane
        )

        node.name = "CH"
        node.position = worldPosition
        node.renderingOrder = 120
        node.scale = SCNVector3(1.15, 1.15, 1.15)

        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: labelPhysicsShape(size: size * 1.1)
        )

        body.categoryBitMask = PhysicsCategory.centipedeHead
        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.cube |
            PhysicsCategory.player

        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        let id = ObjectIdentifier(node)

        centipedeDirection[id] = 1.0
        centipedeLastPosition[id] = worldPosition
        
        addEntity(node, to: enemyRoot)

        return node
    }

    func spawnCentipedeSegment(
        at position: SCNVector3,
        follow target: SCNNode?
    ) -> SCNNode {

        let size = cubeSize * 1.2

        let plane = makeLabelBillboard(
            text: "🟢",
            color: nil,
            worldSize: size
        )

        let node = EntityNode(
            kind: .centipedeSegment,
            geometry: plane
        )

        node.name = "CS"
        node.renderingOrder = 100

        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: labelPhysicsShape(size: size)
        )

        body.categoryBitMask = PhysicsCategory.centipedeSegment
        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.cube |
            PhysicsCategory.player

        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        let id = ObjectIdentifier(node)

        centipedeDirection[id] =
            centipedeDirection[ObjectIdentifier(target ?? node)] ?? 1.0

        if let target = target {
            centipedeFollowTarget[id] = target
            let targetPos = target.presentation.worldPosition
            let dir = centipedeDirection[ObjectIdentifier(target)] ?? 1.0
            let spacing = Float(cubeSize * 1.3)

            node.position = SCNVector3(
                targetPos.x - dir * spacing,
                targetPos.y,
                targetPos.z
            )

            centipedeLastPosition[id] = node.position

        } else {
            node.position = position
            centipedeLastPosition[id] = position
        }

        addEntity(node,to:enemyRoot)

        return node
    }
    func spawnLadybug() {
        let size = cubeSize * 1.35

        let plane = makeLabelBillboard(text: "🐞", color: nil, worldSize: size)

        let node = EntityNode(kind: .ladybug, geometry: plane)
        node.name = "Ladybug"
        node.position = SCNVector3(5, groundY + 4.5, 0)
        node.renderingOrder = 110
        node.scale = SCNVector3(1.1, 1.1, 1.1)

        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size * 1.1))
        body.categoryBitMask = PhysicsCategory.ladybug
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        ladybugDirection[ObjectIdentifier(node)] = Bool.random() ? 1.0 : -1.0

        addEntity(node, to:enemyRoot)
    }

    func spawnLadybug(at worldPosition: SCNVector3) {
        let size = cubeSize * 1.25

        let plane = makeLabelBillboard(text: "🐞", color: .white, worldSize: size)

        let node = EntityNode(kind: .ladybug, geometry: plane)
        node.name = "Ladybug"
        node.position = worldPosition
        node.renderingOrder = 110

        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.ladybug
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        ladybugDirection[ObjectIdentifier(node)] = Bool.random() ? 1.0 : -1.0

        addEntity(node, to:enemyRoot)
    }

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
        groundY + cubeDistanceFromGround + Float(gridHeight) * Float(cubeSize + cubeSpacing) + 1.5
    }

    func spawnSpider() {
        let x = topRowOpeningX()
        spawnSpider(at: SCNVector3(x, spiderSpawnY(), wallZ))
    }

    func spawnSpider(at worldPosition: SCNVector3) {
        let size = cubeSize * 1.3

        let plane = makeLabelBillboard(text: "🕷️", color: .white, worldSize: size)

        let node = EntityNode(kind: .spider, geometry: plane)
        node.name = "Spider"
        node.position = worldPosition
        node.renderingOrder = 120

        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.spider
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        node.constraints = [billboard]

        spiderAnchorY[ObjectIdentifier(node)] = worldPosition.y

        addEntity(node, to:enemyRoot)
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
            let bodyNode1 = spawnCentipedeSegment(at: spawnPoint, follow: headNode)
            let bodyNode2 = spawnCentipedeSegment(at: spawnPoint, follow: bodyNode1)
        }
    }

    func setupLighting() {
        // Ambient
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.35, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        // Main directional (cool white)
        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.color = UIColor.white
        directional.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(directional)

        // Secondary fill light (slightly blue)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.color = UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.6)
        fill.eulerAngles = SCNVector3(-Float.pi / 5, -Float.pi / 6, 0)
        scene.rootNode.addChildNode(fill)
    }

    func setupWorld() {
        let floorGeo = SCNBox(width: 200, height: 0.1, length: 200, chamferRadius: 0)
        floorGeo.firstMaterial?.diffuse.contents = UIColor.darkGray
        floorGeo.firstMaterial?.emission.contents = UIColor.black
        floorGeo.firstMaterial?.reflective.contents = UIColor.black

        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.position = SCNVector3(0, groundY - 0.05, 0)

        let body = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(geometry: floorGeo, options: nil)
        )
        body.categoryBitMask = PhysicsCategory.ground
        body.contactTestBitMask =
            PhysicsCategory.laser |
            PhysicsCategory.missile |
            PhysicsCategory.pointObject
        body.collisionBitMask = PhysicsCategory.none

        floorNode.physicsBody = body
        scene.rootNode.addChildNode(floorNode)
    }
    func setupGrid() {
        slots.removeAll()
        slotMap.removeAll()

        let pitch = cubeSize + cubeSpacing
        let totalWidth = CGFloat(gridWidth) * pitch
        let originX = -Float(totalWidth) / 2 + Float(pitch) / 2
        let originY = topOfGridY()

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

    func loadCube(into slot: inout CubeSlot, animated: Bool, dropFromTop: Bool = false) {
        guard slot.node == nil else { return }

        let size = cubeSize * 0.88

        let cubeGeo = SCNBox(
            width: size,
            height: size,
            length: size,
            chamferRadius: size * 0.06
        )

        let seed = slot.row * 1000 + slot.col
        let material = makeCubeMaterial(variation: seed)
        cubeGeo.materials = [material]

        let node = EntityNode(kind: .cube, geometry: cubeGeo)
        node.name = "cube_\(slot.row)_\(slot.col)"

        let body = SCNPhysicsBody(
            type: .kinematic,
            shape: SCNPhysicsShape(geometry: cubeGeo, options: nil)
        )
        body.categoryBitMask = PhysicsCategory.cube
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.missile | PhysicsCategory.ground
        body.collisionBitMask = PhysicsCategory.missile | PhysicsCategory.ground
        node.physicsBody = body

        if animated {
            let dropStartY: Float
            if dropFromTop {
                dropStartY = groundY + 18.0 + Float(slot.row) * 1.2
            } else {
                dropStartY = Float(gridHeight - slot.row) * Float(cubeSize + cubeSpacing) + 3.0
            }

            node.position = SCNVector3(0, dropStartY, 0)
            slot.container.addChildNode(node)

            let fallDuration = dropFromTop ? 0.65 : 0.45
            let fall = SCNAction.move(to: SCNVector3(0, 0, 0), duration: fallDuration)
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
    private func makeCubeMaterial(variation seed: Int) -> SCNMaterial {
        let material = SCNMaterial()

        let baseHue: CGFloat = 0.60
        let hueOffset = CGFloat((seed % 9) - 4) * 0.02   // wider spread
        let sat = 0.70 + CGFloat((seed % 6)) * 0.04
        let light = 0.50 + CGFloat((seed % 6)) * 0.05

        let color = UIColor(
            hue: baseHue + hueOffset,
            saturation: sat,
            brightness: light,
            alpha: 1.0
        )

        material.diffuse.contents = color
        material.metalness.contents = 0.9
        material.roughness.contents = 0.12
        material.specular.contents = UIColor.white
        material.specular.intensity = 1.0
        material.emission.contents = UIColor(red: 0.12, green: 0.45, blue: 1.0, alpha: 0.07)

        if let noiseImage = cubeNormalMap {
            material.normal.contents = noiseImage
            material.normal.intensity = 0.15
        }

        material.lightingModel = .physicallyBased
        material.isDoubleSided = true
        return material
    }
    private func noiseTexture(size: Int) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            UIColor.black.setFill()
            ctx.fill(rect)

            // Draw random low-contrast noise as small squares
            for _ in 0..<(size * size / 4) {
                let x = CGFloat.random(in: 0..<CGFloat(size))
                let y = CGFloat.random(in: 0..<CGFloat(size))
                let s = CGFloat.random(in: 1...3)
                let alpha = CGFloat.random(in: 0.05...0.15)
                let noiseRect = CGRect(x: x, y: y, width: s, height: s)

                UIColor(white: CGFloat.random(in: 0.4...0.6), alpha: alpha).setFill()
                ctx.cgContext.fill(noiseRect)
            }
        }
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

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.20
        longPress.allowableMovement = 35
        longPress.cancelsTouchesInView = false
        longPress.delaysTouchesBegan = false
        longPress.delegate = self
        sceneView.addGestureRecognizer(longPress)

        tap.require(toFail: longPress)
    }
    private func longPressRecognizer() -> UILongPressGestureRecognizer? {
        return sceneView.gestureRecognizers?.compactMap { $0 as? UILongPressGestureRecognizer }.first
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard !gameState.isGameOver else { return }
        let location = gesture.location(in: sceneView)
        if let anchorNode = platformNode ?? playerNode {
            let anchorScreen = sceneView.projectPoint(anchorNode.presentation.worldPosition)
            let dx = CGFloat(anchorScreen.x) - location.x
            let dy = CGFloat(anchorScreen.y) - location.y
            let dist = sqrt(dx*dx + dy*dy)
            if dist <= 120 {
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

    func moveLaser(toScreenX x: CGFloat) {
        let fraction = max(0, min(1, x / sceneView.bounds.width))
        let newColumn = Int(round(fraction * CGFloat(gridWidth - 1)))
        laserColumn = max(0, min(gridWidth - 1, newColumn))
        if let platform = platformNode {
            platform.position.x = laserWorldPosition().x
        }
    }

    func bestTarget(at screenPoint: CGPoint) -> SCNNode? {

        var bestNode: SCNNode?
        var closestDistance: Float = 9999

        scene.rootNode.enumerateChildNodes { [weak self] node, _ in

            guard let self = self else { return }

            guard let entityNode = self.findEntityParent(node),
                  let kind = self.kind(of: entityNode),
                  let profile = self.knowledge.profile(for: kind),
                  profile.canBeTargetedByLaser
            else { return }

            let worldPosition = entityNode.presentation.worldPosition
            let projected = self.sceneView.projectPoint(worldPosition)
            let dx = projected.x - Float(screenPoint.x)
            let dy = projected.y - Float(screenPoint.y)
            let distance = sqrt(dx * dx + dy * dy)

            if distance < 80 && distance < closestDistance {
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

    func cleanupTrackingState(for node: SCNNode, kind: KnowledgeTree.EntityKind) {
        let id = ObjectIdentifier(node)
        switch kind {
        case .spider:
            removeSpiderThread(for: node)
        case .ladybug:
            ladybugDirection.removeValue(forKey: id)
        case .grasshopper:
            grasshopperJumping.remove(id)
            grasshopperFalling.remove(id)   // ensure this
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
        }

        if scoreDelta > 0 {
            DispatchQueue.main.async {
                self.gameState.score += scoreDelta
                self.gameState.combo += 1
            }
        }
    }

    func spawnMushroomFunc(at worldPosition: SCNVector3) {
        let size = cubeSize * 1.1
        let geo = makeLabelBillboard(text: "🍄", color: .white, worldSize: size)

        let node = EntityNode(kind: .mushroom, geometry: geo)
        node.name = "mushroom"
        node.position = worldPosition
        node.renderingOrder = 90

        let body = SCNPhysicsBody(type: .static, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.mushroom
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.missile
        body.collisionBitMask = PhysicsCategory.none
        node.physicsBody = body
        node.constraints = [SCNBillboardConstraint()]
        if let billboard = node.constraints?.first as? SCNBillboardConstraint {
            billboard.freeAxes = .all
        }
        addEntity(node, to:enemyRoot)
    }

    func destroy(node: SCNNode, kind: KnowledgeTree.EntityKind, at point: SCNVector3) {
        cleanupTrackingState(for: node, kind: kind)

        let color = (node.geometry?.firstMaterial?.emission.contents as? UIColor) ?? .cyan

        if playSoundFlag
        {
            playSound(kind == .missile ? GameSound.missileHit.rawValue : GameSound.enemyDestroyed.rawValue)
        }

        // --------------------------------------------------
        // CUBE DESTROYED
        // --------------------------------------------------
        if kind == .cube {
            if let slot = slotForNode(node) {
                slots[slot.row][slot.col].node = nil
                removeQueue.append(node)
            }
            if playSoundFlag {
                playSound(GameSound.cubeHit.rawValue)}
            return
        }

        // --------------------------------------------------
        // CENTIPEDE HEAD DESTROYED -> PROMOTE FIRST SEGMENT TO HEAD
        // --------------------------------------------------
        if kind == .centipedeHead {
            spawnExplosion(at: point, color: .systemYellow)

            let headID = ObjectIdentifier(node)

            // Find the first segment that was following this head
            var firstSegment: SCNNode?
            for (segID, target) in centipedeFollowTarget {
                if ObjectIdentifier(target) == headID {
                    if let segNode = enemyRoot.childNodes.first(where: {
                        ObjectIdentifier($0) == segID
                    }) {
                        firstSegment = segNode
                        break
                    }
                }
            }

            // Replace that segment with a new head
            if let first = firstSegment {
                replaceSegmentWithHead(first, inheritFrom: node)
            } else {
                // No segments left; just remove head from leaders
                centipedeLeaders.remove(headID)
            }

            // Remove old head
            removeQueue.append(node)
            spawnMushroomFunc(at: point)
            return
        }

        // --------------------------------------------------
        // CENTIPEDE SEGMENT DESTROYED -> REWIRE CHAIN
        // --------------------------------------------------
        if kind == .centipedeSegment {
            spawnExplosion(at: point, color: .systemYellow)

            let segID = ObjectIdentifier(node)

            // Find the segment (if any) that was following this one
            var follower: SCNNode?
            for (fID, target) in centipedeFollowTarget {
                if ObjectIdentifier(target) == segID {
                    if let fNode = enemyRoot.childNodes.first(where: {
                        ObjectIdentifier($0) == fID
                    }) {
                        follower = fNode
                        break
                    }
                }
            }

            // Make the follower follow whatever this segment was following
            if let f = follower, let leader = centipedeFollowTarget[segID] {
                centipedeFollowTarget[ObjectIdentifier(f)] = leader
            }

            // Remove this segment
            removeQueue.append(node)
            spawnMushroomFunc(at: point)
            return
        }

        // --------------------------------------------------
        // OTHER ENEMIES THAT SHOULD BE REMOVED ON HIT
        // --------------------------------------------------
        if kind == .fly ||
           kind == .grasshopper ||
           kind == .ladybug ||
           kind == .spider ||
           kind == .ufo {
            spawnExplosion(at: point, color: .systemYellow)
            removeQueue.append(node)
            return
        }

        // --------------------------------------------------
        // MUSHROOM DESTROYED
        // --------------------------------------------------
        if kind == .mushroom {
            spawnExplosion(at: point, color: .white)
            removeQueue.append(node)
            return
        }

        // --------------------------------------------------
        // BONUS POINT OBJECT DESTROYED
        // --------------------------------------------------
        if kind == .bonusPointObject {
            spawnExplosion(at: point, color: .yellow)
            removeQueue.append(node)
            return
        }

        // --------------------------------------------------
        // OTHERS (MISSILE, PLAYER, ETC.) – OPTIONAL FALLBACK
        // --------------------------------------------------
        removeQueue.append(node)
    }

    func distanceBetween(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        return sqrt(dx * dx + dy * dy + dz * dz)
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

    func nextJumpTarget(from current: SCNNode, toward player: SCNNode) -> SCNNode? {
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
            let score = distanceBetween(cubePos, playerPos)
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
        geo.firstMaterial?.emission.contents = UIColor.systemOrange.withAlphaComponent(0.45)

        let node = EntityNode(kind: .pointObject, geometry: geo)
        node.position = worldPosition

        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geo, options: nil))
        body.categoryBitMask = PhysicsCategory.pointObject
        body.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.laser
        body.collisionBitMask = PhysicsCategory.none
        body.isAffectedByGravity = false
        body.velocity = SCNVector3(0, -3.0, 0)
        body.damping = 0.2
        body.angularDamping = 0.5
        node.physicsBody = body

        addEntity(node, to:enemyRoot)
    }

    func spawnBonusPointObject(at worldPosition: SCNVector3) {
        let geo = SCNSphere(radius: 0.22)
        geo.firstMaterial?.diffuse.contents = UIColor.systemOrange
        geo.firstMaterial?.emission.contents = UIColor.systemOrange.withAlphaComponent(0.45)
        
        let root = EntityNode(kind: .bonusPointObject, geometry: geo)
      
        let dollarColor = UIColor.yellow

        let bar = SCNBox(width: cubeSize * 0.16, height: cubeSize * 1.05, length: cubeSize * 0.16, chamferRadius: cubeSize * 0.04)
        bar.firstMaterial?.diffuse.contents = dollarColor
        bar.firstMaterial?.emission.contents = dollarColor.withAlphaComponent(0.35)

        let barNode = SCNNode(geometry: bar)
        barNode.position = SCNVector3(0, 0, 0)
        root.addChildNode(barNode)

        let topCircle = SCNSphere(radius: cubeSize * 0.22)
        topCircle.firstMaterial?.diffuse.contents = dollarColor
        topCircle.firstMaterial?.emission.contents = dollarColor.withAlphaComponent(0.35)

        let topNode = SCNNode(geometry: topCircle)
        topNode.position = SCNVector3(0, cubeSize * 0.28, 0)
        root.addChildNode(topNode)

        let bottomCircle = SCNSphere(radius: cubeSize * 0.22)
        bottomCircle.firstMaterial?.diffuse.contents = dollarColor
        bottomCircle.firstMaterial?.emission.contents = dollarColor.withAlphaComponent(0.35)

        let bottomNode = SCNNode(geometry: bottomCircle)
        bottomNode.position = SCNVector3(0, -cubeSize * 0.28, 0)
        root.addChildNode(bottomNode)

        root.position = worldPosition
        root.renderingOrder = 100

        let body = SCNPhysicsBody(type: .dynamic, shape: nil)
        body.categoryBitMask = PhysicsCategory.pointObject
        body.contactTestBitMask = PhysicsCategory.ground | PhysicsCategory.laser
        body.collisionBitMask = PhysicsCategory.none
        body.isAffectedByGravity = false
        body.velocity = SCNVector3(0, -2.2, 0)
        body.damping = 0.2
        body.angularDamping = 0.5

        root.physicsBody = body
        addEntity(root, to:enemyRoot)
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
        node.runAction(.sequence([.wait(duration: 0.8)]))
        removeQueue.append(node)
    }


    func fireLaser() {
        if gameState.isGameOver { return }

        let boltGeo = SCNCylinder(radius: 0.035, height: 0.4)
        boltGeo.firstMaterial?.diffuse.contents = UIColor.cyan
        boltGeo.firstMaterial?.emission.contents = UIColor.cyan

        let bolt = EntityNode(kind: .playerLaser, geometry: boltGeo)
        bolt.name = "laserBolt"
        bolt.position = laserWorldPosition()

        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: boltGeo, options: nil))
        body.categoryBitMask = PhysicsCategory.laser
        body.contactTestBitMask =
            PhysicsCategory.cube |
            PhysicsCategory.pointObject |
            PhysicsCategory.ufo |
            PhysicsCategory.missile |
            PhysicsCategory.centipedeHead |
            PhysicsCategory.centipedeSegment |
            PhysicsCategory.mushroom |
            PhysicsCategory.grasshopper |
            PhysicsCategory.spider |
            PhysicsCategory.ladybug
        body.collisionBitMask = PhysicsCategory.none
        bolt.physicsBody = body

        addEntity(bolt, to:scene.rootNode)
        activeLasers.append(bolt)
        if playSoundFlag {
            playSound(GameSound.laserFire.rawValue)
        }
    }

    func laserWorldPosition() -> SCNVector3 {
        let pitch = Float(cubeSize + cubeSpacing)
        let x = -Float(gridWidth) * pitch / 2 + Float(laserColumn) * pitch + pitch / 2
        return SCNVector3(x, groundY + 0.6, wallZ)
    }

    func fallToGround(_ grasshopper: SCNNode) {
        let id = ObjectIdentifier(grasshopper)
        guard grasshopper.parent != nil else { return }

        grasshopperFalling.insert(id)

        let targetY = groundY + 0.4
        let fall = SCNAction.move(
            to: SCNVector3(grasshopper.position.x, targetY, grasshopper.position.z),
            duration: 0.55
        )
        fall.timingMode = .easeIn

        let finish = SCNAction.run { [weak self, weak grasshopper] _ in
            guard let self = self, let gh = grasshopper, gh.parent != nil else { return }

            self.grasshopperFalling.remove(ObjectIdentifier(gh))

            if let player = self.playerNode {
                let dist = self.distanceBetween(
                    gh.presentation.worldPosition,
                    player.presentation.worldPosition
                )
                if dist < 1.2 {
                    self.triggerGameOverFromEnemyContact(node: gh, at: gh.presentation.worldPosition)
                    return
                }
            }

            self.spawnExplosion(at: gh.presentation.worldPosition, color: .brown)
            self.removeQueue.append(gh)
        }

        grasshopper.runAction(.sequence([fall, finish]))
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
        let id = ObjectIdentifier(grasshopper)
        guard grasshopper.parent != nil else { return }
        guard !grasshopperFalling.contains(id) else { return }
        guard let player = playerNode else { return }

        let currentPos = grasshopper.presentation.worldPosition
        let groundLevel = groundY + 0.4

        // Still in the air: let physics move it
        if currentPos.y > groundLevel {
            return
        }

        // Landed on ground
        grasshopperFalling.remove(id)
        grasshopperLeaping.remove(id)

        let playerPos = player.presentation.worldPosition
        let dist = distanceBetween(currentPos, playerPos)

        if dist < 1.2 {
            // Hit the player → game over
            triggerGameOverFromEnemyContact(node: grasshopper, at: currentPos)
        } else {
            // Landed safely → remove
            removeQueue.append(grasshopper)
        }
    }
    func physicsLeap(grasshopper: SCNNode, xDirection: Float) {

        let id = ObjectIdentifier(grasshopper)

        guard let body = grasshopper.physicsBody else {
            print("Grasshopper has no physics body")
            return
        }

        grasshopperLeaping.insert(id)

        let dir: Float = xDirection < 0 ? -1.0 : 1.0

        // Horizontal jump force
        let horizontalForce: Float = Float.random(in: 0.2...0.2)

        // Upward jump force
        let jumpForce: Float = 0.6

        // Clear old movement
        body.clearAllForces()
        body.angularVelocity = SCNVector4(0, 0, 0, 0)

        // Apply a physics impulse
        let impulse = SCNVector3(
            dir * horizontalForce,
            jumpForce,
            0
        )

        body.applyForce(impulse, asImpulse: true)

        // Make sure gravity affects it
        body.isAffectedByGravity = true

        print("""
        Grasshopper leap:
        Velocity: \(body.velocity)
        Gravity: \(body.isAffectedByGravity)
        """)
    }
 
    func checkGrasshopperLanding(_ grasshopper: SCNNode) {
        guard grasshopper.parent != nil else { return }
        guard let player = playerNode else { return }

        let distance = distanceBetween(
            grasshopper.presentation.worldPosition,
            player.presentation.worldPosition
        )

        if distance < 0.45 {
            triggerGameOverFromEnemyContact(node: grasshopper, at: player.position)
        }
    }

    func updateDifficulty() {
        let score = Double(gameState.score)

        // Tunable parameters
        let difficultyCap: Double = 5.0
        let scale: Double = 400.0        // higher = slower difficulty growth
        let exponent: Double = 0.7       // <1 = fast early, slower later; >1 = slow early, faster later

        // Smooth, non-linear difficulty curve
        let rawDifficulty = 1.0 + difficultyCap * (1.0 - exp(-score / scale)) * pow(score / (score + scale), exponent)
        let clampedDifficulty = min(difficultyCap, max(1.0, rawDifficulty))

        gameState.difficulty = clampedDifficulty

        // Grid speed scales with difficulty, but not 1:1 (so it doesn’t get insane)
        let baseGridSpeed: Float = 0.18
        let speedFactor: Float = 0.7   // how strongly grid speed follows difficulty
        gridSpeed = baseGridSpeed * (1.0 + speedFactor * Float(clampedDifficulty - 1.0))

        // Auto-fire interval gets faster with difficulty, but with a floor
        autoFireInterval = currentAutoFireInterval()
    }
    func currentAutoFireInterval() -> TimeInterval {
        let scoreFactor = min(Double(gameState.score) / 120.0, 1.0)
        // Base interval 1.6s, minimum 0.08s, but eased so it doesn’t drop too fast
        let eased = pow(scoreFactor, 0.8)
        return max(0.08, 1.6 - (1.2 * eased))
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

    private func dropAllCubesFromTop() {
        for row in 0..<slots.count {
            for col in 0..<slots[row].count {
                guard let node = slots[row][col].node else { continue }
                let startY = node.position.y + 14.0 + Float(row) * 1.2
                node.position.y = startY
                let fall = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.55)
                fall.timingMode = .easeOut
                node.runAction(fall)
            }
        }
    }

    func respawnAllCubes() {
        let previousAutoFire = autoFireEnabled
        autoFireEnabled = false

        gridRoot.position = SCNVector3Zero
        gridOffset = 0.0
        gridDirection = 1.0

        enemyRoot.childNodes.forEach { removeQueue.append($0)}
        effectsRoot.childNodes.forEach { removeQueue.append($0) }
        gridRoot.childNodes.forEach { removeQueue.append($0) }

        activeLasers.forEach { removeQueue.append($0) }


        if let player = playerNode { removeQueue.append(player) }
        if let platform = platformNode { removeQueue.append(platform) }
        removeQueue.append(cameraNode)
        activeLasers.removeAll()
        grasshopperJumping.removeAll()
        centipedeDirection.removeAll()
        centipedeDropping.removeAll()
        ladybugDirection.removeAll()
        fliesToRemove.removeAll()
        spiderThreads.removeAll()
        spiderAnchorY.removeAll()

        slots.removeAll()
        slotMap.removeAll()

        setupGrid()
        setupPlayer()
        setupPlayerPlatform()
        setupCamera()

        if cameraNode.parent == nil {
            scene.rootNode.addChildNode(cameraNode)
        }
        updateCamera()

        platformNode?.position.x = laserWorldPosition().x
        autoFireEnabled = previousAutoFire
    }

    func updateLasers(dt: TimeInterval) {
        let speed: Float = 18.0
        var removeLaserList: [SCNNode] = []

        for laser in activeLasers {
            guard laser.parent != nil else {
                removeLaserList.append(laser)
                continue
            }

            laser.position.y += Float(dt) * speed
            laser.physicsBody?.resetTransform()

            if laser.position.y > groundY + 20 {
                removeLaserList.append(laser)
            }
        }
    }

    func updateEntities(dt: TimeInterval) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let kind = self.kind(of: node) else { return }
            switch kind {
            case .pointObject, .bonusPointObject:
                if node.position.y < self.groundY - 6 {
                    removeQueue.append(node)
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

        addEntity(missile, to:enemyRoot)
        missile.runAction(.sequence([
            .moveBy(x: 0, y: -12, z: 0, duration: 2.0 / gameState.difficulty),
        ]))
        removeQueue.append(missile)
    }

    private func drawLabelImage(text: String, size: CGSize, color: UIColor? = nil) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.clear.setFill()
            ctx.fill(rect)

            let fontSize = size.width * 0.85
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: color ?? UIColor.white,
                .paragraphStyle: paragraph
            ]

            let attributedString = NSAttributedString(string: text, attributes: attrs)
            let textSize = attributedString.size()

            let drawRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )

            attributedString.draw(in: drawRect)
        }
    }

    private func makeLabelBillboard(text: String, color: UIColor? = nil, worldSize: CGFloat) -> SCNPlane {
        let plane = SCNPlane(width: worldSize, height: worldSize)
        let img = drawLabelImage(text: text, size: CGSize(width: 384, height: 384), color: color)

        let mat = SCNMaterial()
        mat.diffuse.contents = img
        mat.emission.contents = UIColor.clear
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
            if kind(of: n) != nil { return n }
            current = n.parent
        }
        return nil
    }
    func triggerGameOverFromEnemyContact(node: SCNNode, at point: SCNVector3) {
        guard !gameState.isGameOver else { return }

        if let k = kind(of: node) {
            cleanupTrackingState(for: node, kind: k)
        }
        if playSoundFlag {
            playSound(GameSound.gameOver.rawValue)
        }

        // Stage for removal; actual removal happens in cleanRemoveQueue
        if node.parent != nil {
            //node.removeAllActions
            removeQueue.append(node)
        }

        DispatchQueue.main.async { [weak self] in
            self?.gameState.isGameOver = true
        }
    }



    func updateGrid(dt: TimeInterval) {
        gridOffset += gridDirection * gridSpeed * Float(dt)
        gridRoot.position.x = gridOffset

        if abs(gridOffset) >= gridMaxOffset {
            gridDirection *= -1
            gridOffset = max(min(gridOffset, gridMaxOffset), -gridMaxOffset)
            gridRoot.position.y -= 0.5

            if gridRoot.position.y <= -4.5 {
                if !gameState.isGameOver {
                    gameState.isGameOver = true
                    if playSoundFlag {
                        playSound(GameSound.gameOver.rawValue)
                    }
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

    func updateCentipedeHead(_ node: SCNNode, dt: TimeInterval) {
        let id = ObjectIdentifier(node)
        centipedeLastPosition[id] = node.presentation.worldPosition

        if centipedeDropping.contains(id) { return }

        guard let player = playerNode else {
            updateCentipedeHeadBasic(node, dt: dt)
            return
        }

        let pitch = Float(cubeSize + cubeSpacing)
        let halfWidth = Float(gridWidth) * pitch / 2

        let current = node.position
        let playerPos = player.position

        // ------------------------------------------------------
        // GROUND BOUNCE MODE
        // ------------------------------------------------------
        let groundLevel = groundY + 0.6  // approximate ground contact Y
        let isOnGround = current.y <= groundLevel

        // If we were falling and now we're on the ground, we just landed
        if isOnGround && centipedeFalling.contains(id) {
            centipedeFalling.remove(id)          // clear falling flag
            // Start bounce mode once
            centipedeBounces[id] = 180           // ~3 seconds at 60 FPS; tune as needed
            centipedeBounceTargetX[id] = playerPos.x
        }

        if let bounces = centipedeBounces[id], bounces > 0 {
            // Horizontal movement toward player during bounce phase
            let targetX = centipedeBounceTargetX[id] ?? playerPos.x
            let speed: Float = 1.4 * Float(gameState.difficulty)

            let direction: Float = (targetX > current.x) ? 1.0 : -1.0
            let step = direction * speed * Float(dt)
            var nextX = current.x + step

            // Clamp to arena
            nextX = max(-halfWidth + pitch / 2, min(halfWidth - pitch / 2, nextX))

            node.position = SCNVector3(nextX, current.y, current.z)
            node.physicsBody?.resetTransform()
            centipedeLastPosition[id] = node.presentation.worldPosition

            // Decrement bounce counter per frame
            centipedeBounces[id] = bounces - 1
            if centipedeBounces[id] ?? 0 <= 0 {
                centipedeBounces.removeValue(forKey: id)
                centipedeBounceTargetX.removeValue(forKey: id)
            }
            return
        }

        // ------------------------------------------------------
        // NORMAL MOVEMENT (ABOVE GROUND)
        // ------------------------------------------------------
        let desiredDirection: Float = (playerPos.x > current.x) ? 1.0 : -1.0
        let currentDirection = centipedeDirection[id] ?? 1.0

        let speed: Float = 1.2 * Float(gameState.difficulty)
        let step = desiredDirection * speed * Float(dt)
        let nextTowardPlayer = SCNVector3(current.x + step, current.y, current.z)

        let hitsEdgeTowardPlayer =
            nextTowardPlayer.x > halfWidth - pitch / 2 ||
            nextTowardPlayer.x < -halfWidth + pitch / 2

        let pathBlockedTowardPlayer =
            isCentipedePathBlocked(at: nextTowardPlayer, excluding: node)

        if !hitsEdgeTowardPlayer && !pathBlockedTowardPlayer {
            centipedeDirection[id] = desiredDirection
            node.position = SCNVector3(current.x + step, current.y, current.z)
            node.physicsBody?.resetTransform()
            centipedeLastPosition[id] = node.presentation.worldPosition
            return
        }

        let stepCurrent = currentDirection * speed * Float(dt)
        let nextCurrent = SCNVector3(current.x + stepCurrent, current.y, current.z)
        let hitsEdgeCurrent =
            nextCurrent.x > halfWidth - pitch / 2 ||
            nextCurrent.x < -halfWidth + pitch / 2
        let pathBlockedCurrent =
            isCentipedePathBlocked(at: nextCurrent, excluding: node)

        if !hitsEdgeCurrent && !pathBlockedCurrent {
            node.position = nextCurrent
            node.physicsBody?.resetTransform()
            centipedeLastPosition[id] = node.presentation.worldPosition
            return
        }

        // Both directions blocked horizontally: reverse and drop
        centipedeDirection[id] = -currentDirection
        dropCentipedeRow(node)

        centipedeLastPosition[id] = node.presentation.worldPosition

        // Remove the old "start bounce here" block; landing is now handled above.
    }
    func updateCentipedeHeadBasic(_ node: SCNNode, dt: TimeInterval) {
        let id = ObjectIdentifier(node)
        centipedeLastPosition[id] = node.presentation.worldPosition

        if centipedeDropping.contains(id) { return }

        let direction = centipedeDirection[id] ?? 1.0
        let speed: Float = 1.2 * Float(gameState.difficulty)
        let step = direction * speed * Float(dt)

        let current = node.position
        let next = SCNVector3(current.x + step, current.y, current.z)

        let pitch = Float(cubeSize + cubeSpacing)
        let halfWidth = Float(gridWidth) * pitch / 2

        let hitsEdge = next.x > halfWidth - pitch / 2 || next.x < -halfWidth + pitch / 2
        let pathBlocked = isCentipedePathBlocked(at: next, excluding: node)

        if hitsEdge || pathBlocked {
            centipedeDirection[id] = -direction
            dropCentipedeRow(node)
        } else {
            node.position = next
            node.physicsBody?.resetTransform()
        }

        centipedeLastPosition[id] = node.presentation.worldPosition
    }
    func isCentipedePathBlocked(at position: SCNVector3, excluding node: SCNNode) -> Bool {
        let threshold = Float(cubeSize) * 0.9

        // Check cubes
        for cube in activeCubeNodes() {
            if distanceBetween(cube.presentation.worldPosition, position) < threshold {
                return true
            }
        }

        // Check mushrooms and other centipede segments
        var blocked = false
        enemyRoot.enumerateChildNodes { candidate, stop in
            guard candidate != node,
                  let k = self.kind(of: candidate) else { return }

            // Treat mushrooms and any centipede segments as obstacles
            if k == .mushroom || k == .centipedeSegment || k == .centipedeHead {
                if self.distanceBetween(candidate.presentation.worldPosition, position) < threshold {
                    blocked = true
                    stop.pointee = true
                }
            }
        }

        return blocked
    }
    func dropCentipedeRow(_ node: SCNNode) {
        let id = ObjectIdentifier(node)
        guard !centipedeDropping.contains(id) else { return }
        centipedeDropping.insert(id)
        centipedeFalling.insert(id)  // mark as falling

        let pitch = Float(cubeSize + cubeSpacing)
        let dropAmount: Float = pitch

        let drop = SCNAction.moveBy(x: 0, y: CGFloat(-dropAmount), z: 0, duration: 0.2)
        drop.timingMode = .easeInEaseOut

        let finish = SCNAction.run { [weak self, weak node] _ in
            guard let self = self, let node = node else { return }
            self.centipedeDropping.remove(ObjectIdentifier(node))
            self.checkCentipedeReachedBottom(node)
        }

        node.runAction(.sequence([drop, finish]))
    }
    func checkCentipedeReachedBottom(_ node: SCNNode) {
        guard let kind = kind(of: node),
              kind == .centipedeHead || kind == .centipedeSegment else { return }

        let pos = node.presentation.worldPosition
        let groundLevel = groundY + 0.6

        if pos.y <= groundLevel, let player = playerNode, kind == .centipedeHead {
            let id = ObjectIdentifier(node)

            // Start or continue bounce mode
            if centipedeBounces[id] == nil {
                centipedeBounces[id] = 180  // total bounce duration in frames; tune as needed
            }

            // On each ground hit, refresh target X toward player
            centipedeBounceTargetX[id] = player.position.x
        }
    }

    func updateCentipedeSegment(_ node: SCNNode, dt: TimeInterval) {
        let id = ObjectIdentifier(node)
        guard let parentNode = centipedeFollowTarget[id] else { return }

        let direction = centipedeDirection[id] ?? 1.0
        let speed: Float = 1.1 * Float(gameState.difficulty)
        let currentWorld = node.presentation.worldPosition

        let parentID = ObjectIdentifier(parentNode)
        guard let parentWorld = centipedeLastPosition[parentID] else { return }

        let dx = parentWorld.x - currentWorld.x
        let dy = parentWorld.y - currentWorld.y
        let dz = parentWorld.z - currentWorld.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)

        if distance > 0.001 {
            let maxStep = speed * Float(dt)
            let t = min(1.0, maxStep / distance)

            let nextWorld = SCNVector3(
                currentWorld.x + dx * t,
                currentWorld.y + dy * t,
                currentWorld.z + dz * t
            )

            if let parent = node.parent {
                node.position = parent.convertPosition(nextWorld, from: nil)
            } else {
                node.position = nextWorld
            }
        }

        centipedeDirection[id] = direction
        centipedeLastPosition[id] = node.presentation.worldPosition
        node.physicsBody?.resetTransform()
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

    func spawnFly() {
        let size = cubeSize * 1.1
        let plane = makeLabelBillboard(text: "🪰", color: .systemYellow, worldSize: size)

        let fly = EntityNode(kind: .fly, geometry: plane)
        fly.name = "FLY"
        fly.renderingOrder = 150
        fly.position = SCNVector3(Float.random(in: -7...7), groundY + 12.0, wallZ)

        let body = SCNPhysicsBody(type: .kinematic, shape: labelPhysicsShape(size: size))
        body.categoryBitMask = PhysicsCategory.fly
        body.contactTestBitMask = PhysicsCategory.laser | PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.none
        fly.physicsBody = body

        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        fly.constraints = [billboard]

        let id = ObjectIdentifier(fly)
        flyWobble[id] = Float.random(in: 8...15)
        flyChaos[id] = Float.random(in: 1.5...3.0)
        addEntity(fly, to: enemyRoot)
    }
    private func handleFlyHitPlayer(fly node: SCNNode) {
        guard let k = kind(of: node), k == .fly else { return }

        // Deduct score (e.g., 25 points) and reset combo
        DispatchQueue.main.async {
            self.gameState.score = max(0, self.gameState.score - 25)
            self.gameState.combo = 0
        }
        if playSoundFlag {
            playSound(GameSound.enemyDestroyed.rawValue)
        }
        spawnExplosion(at: node.presentation.worldPosition, color: .systemYellow)

        // Centralized destruction + staging for removal
        destroy(node: node, kind: .fly, at: node.presentation.worldPosition)
    }
    func updateFly(_ fly: SCNNode, dt: TimeInterval) {
        let id = ObjectIdentifier(fly)
        guard let player = playerNode else { return }
        guard flyWobble[id] != nil, flyChaos[id] != nil else { return }

        var pos = fly.presentation.worldPosition
        let playerPos = player.presentation.worldPosition
        let delta = Float(dt)

        let toPlayerX = playerPos.x - pos.x
        let toPlayerY = playerPos.y - pos.y

        let speed: Float = 4.2
        let seekX: Float = max(-1.0, min(1.0, toPlayerX * 0.12))
        let seekY: Float = max(-1.0, min(1.0, toPlayerY * 0.10))

        let t = Float(CACurrentMediaTime())
        let wobble = sin(t * (flyWobble[id] ?? 14.0)) * 1.6
        let chaos = cos(t * (flyChaos[id] ?? 4.5)) * 0.9

        pos.x += (seekX * 2.0 + wobble + chaos) * delta * speed
        pos.y += (-0.45 + seekY * 1.4 + sin(t * 18.0) * 0.25) * delta * speed

        if Bool.random() && Int.random(in: 0..<20) == 0 {
            flyWobble[id] = Float.random(in: 12.0...22.0)
            flyChaos[id] = Float.random(in: 3.5...7.5)
        }

        let bound: Float = 3.5
        pos.x = max(-bound, min(bound, pos.x))
        pos.y = min(groundY + 7.0, max(groundY , pos.y))

        fly.position = pos

        // Out of bounds → destroy via central path
        if pos.y < groundY - 2 {
            flyWobble.removeValue(forKey: id)
            flyChaos.removeValue(forKey: id)
            destroy(node: fly, kind: .fly, at: fly.presentation.worldPosition)
        }
    }
    func handleFlyHitGround(fly: SCNNode) {
        guard let kind = kind(of: fly), kind == .fly else { return }

        // Deduct points (tune the penalty as desired)
        let penalty = 50
        DispatchQueue.main.async {
            self.gameState.score -= penalty
        }

        // Optional: visual feedback
        spawnExplosion(at: fly.presentation.worldPosition, color: .systemGray)

        // Remove the fly
        removeQueue.append(fly)
    }
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard !isProcessingFrame else { return }
        isProcessingFrame = true
        defer { isProcessingFrame = false }

        let dt = lastUpdateTime == 0 ? 0 : time - lastUpdateTime
        lastUpdateTime = time
        guard dt > 0 else { return }

        //if gameState.isGameOver {
        //    applyPendingSceneMutations()
        //    return
        //}

        updatePlayer()
        updateGrid(dt: dt)
        updateLasers(dt: dt)
        updateEntities(dt: dt)
        
        if time - lastGrasshopperSpawnTime > grasshopperSpawnInterval {
                spawnGrasshopper()
                lastGrasshopperSpawnTime = time
        }

        spawnUFOIfNeeded()

        // ---- Search scene directly for mobile enemies ----

        var mobileEnemies: [EntityNode] = []
        enemyRoot.enumerateChildNodes { node, _ in
            guard let e = node as? EntityNode else { return }
            switch e.kind {
            case .grasshopper, .spider, .ladybug, .fly:
                mobileEnemies.append(e)
            default:
                break
            }
        }

        for entity in mobileEnemies {
            switch entity.kind {
            case .grasshopper:  updateGrasshopper(entity)
            case .spider:       updateSpider(entity, dt: dt)
            case .ladybug:      updateLadybugMovement(entity, dt: dt)
            case .fly:          updateFly(entity, dt: dt)
            default:            break
            }
        }

        // ---- Centipede heads ----

        var heads: [EntityNode] = []
        enemyRoot.enumerateChildNodes { node, _ in
            guard let e = node as? EntityNode, e.kind == .centipedeHead else { return }
            heads.append(e)
        }

        for head in heads {
            updateCentipedeHead(head, dt: dt)
        }

        // ---- Centipede segments ----

        var segments: [EntityNode] = []
        enemyRoot.enumerateChildNodes { node, _ in
            guard let e = node as? EntityNode, e.kind == .centipedeSegment else { return }
            segments.append(e)
        }

        for segment in segments {
            updateCentipedeSegment(segment, dt: dt)
        }

        // ---- Cleanup ----

        cleanRemoveQueue()
        //applyPendingSceneMutations()
    }
    func enumerateEntities(ofKind kind: KnowledgeTree.EntityKind, in root: SCNNode, body: (EntityNode) -> Void) {
        root.enumerateChildNodes { node, _ in
            guard let e = node as? EntityNode, e.kind == kind else { return }
            body(e)
        }
    }

    func enumerateEntities(ofKinds kinds: [KnowledgeTree.EntityKind],
                           in root: SCNNode,
                           body: (EntityNode) -> Void) {
        root.enumerateChildNodes { node, _ in
            guard let e = node as? EntityNode, kinds.contains(e.kind) else { return }
            body(e)
        }
    }
    func restartGame() {
        pendingRestart = true
    }

    func performRestartGame() {
        gameSessionID = UUID()
        gameState.score = 0
        gameState.combo = 0
        gameState.isGameOver = false
        gameState.difficulty = 1.0

        gridDirection = 1
        gridOffset = 0
        gridRoot.position = SCNVector3Zero

        enemyRoot.childNodes.forEach { removeQueue.append($0) }
        effectsRoot.childNodes.forEach { removeQueue.append($0) }
        gridRoot.childNodes.forEach { removeQueue.append($0) }

        activeLasers.forEach { removeQueue.append($0) }
        activeLasers.removeAll()

        slots.removeAll()
        slotMap.removeAll()

        grasshopperJumping.removeAll()
        centipedeDirection.removeAll()
        centipedeDropping.removeAll()
        spiderThreads.removeAll()
        spiderAnchorY.removeAll()
        ladybugDirection.removeAll()
        fliesToRemove.removeAll()
        flyWobble.removeAll()
        flyChaos.removeAll()

        setupGrid()
        spawnGrasshopper()
        spawnSpider()
        spawnLadybug()

        platformNode?.position.x = laserWorldPosition().x
    }

    func performRespawnAllCubes() {
        let previousAutoFire = autoFireEnabled
        autoFireEnabled = false

        gameSessionID = UUID()
        gridDirection = 1
        gridOffset = 0
        gridRoot.position = SCNVector3Zero

        let nodesToRemove = enemyRoot.childNodes
            + effectsRoot.childNodes
            + gridRoot.childNodes
            + activeLasers
            + [playerNode, platformNode, cameraNode].compactMap { $0 }

        //pendingNodeRemovals.append(contentsOf: nodesToRemove)
        activeLasers.removeAll()

        grasshopperJumping.removeAll()
        centipedeDirection.removeAll()
        centipedeDropping.removeAll()
        spiderThreads.removeAll()
        spiderAnchorY.removeAll()
        ladybugDirection.removeAll()
        flyWobble.removeAll()
        flyChaos.removeAll()
        fliesToRemove.removeAll()

        slots.removeAll()
        slotMap.removeAll()

        pendingRespawnAllCubes = false

        setupGrid()
        spawnGrasshopper()
        spawnSpider()
        spawnLadybug()

        platformNode?.position.x = laserWorldPosition().x
        autoFireEnabled = previousAutoFire
    }
/*
    func applyPendingSceneMutations() {
        let removals = pendingNodeRemovals
        pendingNodeRemovals.removeAll()

        for node in removals {
            node.removeAllActions()
            node.physicsBody = nil
            node.removeFromParentNode()
        }

        if pendingRespawnAllCubes {
            pendingRespawnAllCubes = false
            performRespawnAllCubes()
        }

        if pendingRestart {
            pendingRestart = false
            performRestartGame()
        }
    }
*/
    //func queueRemoval(_ node: SCNNode) {
     //   guard node.parent != nil else { return }
    //    pendingNodeRemovals.append(node)
   // }

    func activeEntitySnapshot(kind filterKind: KnowledgeTree.EntityKind? = nil) -> [EntityNode] {
        let localIndex = entityIndex

        var validEntities: [EntityNode] = []

        for (_, entity) in localIndex {
            guard
                entity.parent != nil,
                !entity.isHidden,
                entity.presentation != nil
            else {
                // Do NOT unregister or queue here; defer to cleanRemoveQueue
                continue
            }

            validEntities.append(entity)
        }

        return validEntities.filter { entity in
            if let filterKind, entity.kind != filterKind {
                return false
            }
            return true
        }
    }
    func forceRemove(_ node: SCNNode) {
        guard node.parent != nil else { return }
        node.removeAllActions()
        node.physicsBody = nil
        node.constraints = nil
        node.removeFromParentNode()
    }
    
    func cleanRemoveQueue() {
        var seen = Set<ObjectIdentifier>()
        
        for node in removeQueue {
            let id = ObjectIdentifier(node)
            guard seen.insert(id).inserted else { continue }
            
            if node.parent != nil {
                //unregisterEntity(node)
                if let kind = kind(of: node) {
                    cleanupTrackingState(for: node, kind: kind)
                }
                node.removeAllActions()
                node.physicsBody = nil
                node.constraints = nil
                node.removeFromParentNode()
            }
        }
        
        removeQueue.removeAll()
    }

 

   

    func updateSpider(_ node: SCNNode, dt: TimeInterval) {
        let speed: Float = 0.55 * Float(gameState.difficulty)
        var pos = node.position
        pos.y -= speed * Float(dt)
        node.position = pos

        if let player = playerNode {
            let dist = distanceBetween(node.presentation.worldPosition, player.presentation.worldPosition)
            if dist < 0.45 {
                triggerGameOverFromEnemyContact(node: node, at: player.position)
                return
            }
        }

        updateSpiderThread(for: node)

        // Reached ground without hitting player → destroy
        if node.position.y < groundY - 1 {
            removeSpiderThread(for: node)
            destroy(node: node, kind: .spider, at: node.presentation.worldPosition)
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

    //func registerEntity(_ node: EntityNode) {
    //    entityIndex[ObjectIdentifier(node)] = node
   // }

   // func unregisterEntity(_ node: SCNNode) {
    //    entityIndex.removeValue(forKey: ObjectIdentifier(node))
   // }

    func removeSpiderThread(for spider: SCNNode) {
        let id = ObjectIdentifier(spider)
        let thread = spiderThreads[id]
        spiderThreads.removeValue(forKey: id)
        spiderAnchorY.removeValue(forKey: id)

        if let thread, thread.parent != nil {
            thread.removeAllActions()
            thread.physicsBody = nil
            thread.constraints = nil
            removeQueue.append(thread)
        }
    }

    func updateLadybugMovement(_ node: SCNNode, dt: TimeInterval) {
        let id = ObjectIdentifier(node)
        var dir = ladybugDirection[id]
        if dir == nil {
            dir = Bool.random() ? 1.0 : -1.0
            ladybugDirection[id] = dir
        }

        let descendSpeed: Float = 0.22 * Float(gameState.difficulty)
        let driftSpeed: Float = 0.5

        var pos = node.position
        pos.y -= descendSpeed * Float(dt)
        pos.x += dir! * driftSpeed * Float(dt)

        let pitch = Float(cubeSize + cubeSpacing)
        let halfWidth = Float(gridWidth) * pitch * 0.5

        if pos.x > halfWidth {
            dir = -1.0
        } else if pos.x < -halfWidth {
            dir = 1.0
        }
        ladybugDirection[id] = dir

        node.position = pos

        // Fell below ground → destroy
        if pos.y < groundY - 1 {
            ladybugDirection.removeValue(forKey: id)
            destroy(node: node, kind: .ladybug, at: node.presentation.worldPosition)
        }
    }

    func spawnGrasshopper() {
        let size = cubeSize * 1.35
        let plane = makeLabelBillboard(text: "🦗", color: nil, worldSize: size)

        let pitch = Float(cubeSize + cubeSpacing)
        let halfWidth = Float(gridWidth) * pitch / 2

        let randomX = Float.random(in: (-halfWidth + pitch)...(halfWidth - pitch))

        let grasshopper = EntityNode(kind: .grasshopper, geometry: plane)
        grasshopper.name = "Grasshopper"
        grasshopper.position = SCNVector3(randomX, topOfGridY(), wallZ)
        grasshopper.renderingOrder = 115
        grasshopper.scale = SCNVector3(1.15, 1.15, 1.15)

        // Physics
        let body = SCNPhysicsBody(type: .dynamic, shape: nil)
        body.mass = 0.2
        body.isAffectedByGravity = true
        body.restitution = 0.0
        body.friction = 0.5
        body.rollingFriction = 0.5
        body.damping = 0.1
        body.angularDamping = 1.0

        body.categoryBitMask = PhysicsCategory.grasshopper
        body.contactTestBitMask =
            PhysicsCategory.cube |
            PhysicsCategory.player |
            PhysicsCategory.laser

        // Allow collisions with cubes and player
        body.collisionBitMask =
            PhysicsCategory.cube |
            PhysicsCategory.player

        grasshopper.physicsBody = body

        addEntity(grasshopper, to: enemyRoot)

        let xDirection: Float = Bool.random() ? 1.0 : -1.0
        physicsLeap(grasshopper: grasshopper, xDirection: xDirection)
    }
    func spawnUFOIfNeeded() {
        // Only check periodically, not every frame
        guard lastUFOCheckTime == 0 || CACurrentMediaTime() - lastUFOCheckTime >= ufoCheckInterval else {
            return
        }
        lastUFOCheckTime = CACurrentMediaTime()

        // Limit number of UFOs in the scene
        var ufoCount = 0
        enemyRoot.enumerateChildNodes { node, _ in
            if let e = node as? EntityNode, e.kind == .ufo {
                ufoCount += 1
            }
        }
        let maxUFOs = 1 + Int(gameState.difficulty)  // e.g. 1 at diff 1, up to ~6 at diff 5
        guard ufoCount < maxUFOs else { return }

        // Spawn chance based on difficulty
        let chance = Int.random(in: 0...1000)
        let threshold = max(1, 950 - Int(gameState.difficulty * 120))
        guard chance > threshold else {
            print("UFO spawn check: no spawn (chance \(chance) <= threshold \(threshold))")
            return
        }

        print("UFO spawn check: spawning UFO (chance \(chance) > threshold \(threshold))")

        let geo = SCNTorus(ringRadius: 0.45, pipeRadius: 0.12)
        geo.firstMaterial?.diffuse.contents = UIColor.systemPurple
        geo.firstMaterial?.emission.contents = UIColor.systemPurple.withAlphaComponent(0.4)

        let ufo = EntityNode(kind: .ufo, geometry: geo)
        ufo.position = SCNVector3(-8, topOfGridY() + 3.0, 0)

        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: geo, options: nil))
        body.categoryBitMask = PhysicsCategory.ufo
        body.contactTestBitMask = PhysicsCategory.cube | PhysicsCategory.ground | PhysicsCategory.laser
        body.collisionBitMask = PhysicsCategory.none
        ufo.physicsBody = body

        addEntity(ufo, to: enemyRoot)

        let travelDuration = Double(8.0 / gameState.difficulty)

        let moveRight = SCNAction.moveBy(x: 16, y: 0, z: 0, duration: travelDuration)
        let moveLeft  = SCNAction.moveBy(x: -16, y: 0, z: 0, duration: travelDuration)

        let fire = SCNAction.run { [weak self, weak ufo] _ in
            guard let self = self, let ufo = ufo else { return }
            self.fireMissile(from: ufo)
        }

        let cycle = SCNAction.sequence([
            moveRight, .wait(duration: 0.4), fire, .wait(duration: 0.4),
            moveLeft,  .wait(duration: 0.4), fire, .wait(duration: 0.4)
        ])

        ufo.runAction(.repeatForever(cycle))
    }

    func destroyLaser(_ laser: SCNNode, at position: SCNVector3) {
        laser.physicsBody = nil
        removeQueue.append(laser)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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
                VStack(alignment: .leading, spacing: 1) {
                    Text("Score: \(gameState.score)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text("Combo: \(gameState.combo)x")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan)

                    HStack(spacing: 6) {
                        Button("Lower Camera") {
                            gameState.cameraLower?()
                        }
                        .font(.system(size: 10))
                        .controlSize(.mini)

                        Spacer()

                        Button("Raise Camera") {
                            gameState.cameraRaise?()
                        }
                        .font(.system(size: 10))
                        .controlSize(.mini)

                        Spacer()

                        Toggle(
                            gameState.playSoundFlag ? "Sound On" : "Sound Off",
                            isOn: $gameState.playSoundFlag
                        )
                        .font(.system(size: 10))
                        .controlSize(.mini)
                        .onChange(of: gameState.playSoundFlag) { _, newValue in
                            gameState.setPlaySoundFlag?(newValue)
                        }
                    }
                }
                .padding(6)
            }
            .padding(.top, 40)

            VStack {
                Spacer()
                Text("Tap to fire • Long press for rapid fire")
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
                        gameState.cameraLower = nil
                        gameState.cameraRaise = nil
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

