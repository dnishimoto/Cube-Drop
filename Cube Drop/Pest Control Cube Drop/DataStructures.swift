//
//  DataStructures.swift
//  Cube Drop
//
//  Created by David Nishimoto on 7/20/26.
//

import Foundation
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
    case missileHit     = 1106
    case enemyDestroyed = 1111
    case bonus          = 1025
    case gameOver       = 1073
}

// Global sound preference backed by UserDefaults so UI can toggle sound.
private enum SoundPreferences {
    static let soundEnabledKey = "soundEnabled"

    static var isSoundEnabled: Bool {
        // Default to true if the key hasn't been set yet.
        if let value = UserDefaults.standard.object(forKey: soundEnabledKey) as? Bool {
            return value
        } else {
            return true
        }
    }
}

func playSound(_ id: SystemSoundID) {
    guard SoundPreferences.isSoundEnabled else { return }
    AudioServicesPlaySystemSound(id)
}

func playSound(_ sound: GameSound) {
    playSound(sound.rawValue)
}


struct PhysicsCategory {
    static let none: Int = 0

       static let laser: Int = 1 << 0
       static let cube: Int = 1 << 1
       static let pointObject: Int = 1 << 2
       static let ufo: Int = 1 << 3
       static let missile: Int = 1 << 4
       static let centipedeHead: Int = 1 << 5
       static let mushroom: Int = 1 << 6
       static let grasshopper: Int = 1 << 7
       static let spider: Int = 1 << 8
       static let ladybug: Int = 1 << 9
       static let ground: Int = 1 << 10
       static let centipedeSegment: Int = 1 << 11
       static let player: Int = 1 << 12
       static let fly: Int = 1 << 13
       static let wasp: Int = 1 << 14
}


final class KnowledgeTree {

    enum EntityKind: String {

        case playerLaser
        case player
        case platform

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
        case fly
        case wasp
    }


    enum Behavior {

        case blocksLaser
        case blocksMissile

        case destroyedByLaser
        case destroyedByMissile

        case fallsWithGravity

        case awardsScore(Int)

        case deductsScoreOnContact(Int)

        case dropsMissiles

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
        
        register(
            .wasp,
            behaviors: [
                .hostile,
                .destroyedByMissile,
                .destroyedByLaser,
                .causesGameOverOnContact,
                .awardsScore(200)
            ],
            scoreValue: 200,
            weakness: [
                .playerLaser,
                .missile
            ],
            canBeTargetedByLaser: true
        )

        register(
            .fly,
            behaviors: [
                .hostile,
                .destroyedByLaser,
                .deductsScoreOnContact(25),
                .awardsScore(90)
            ],
            scoreValue: 90,
            weakness: [.playerLaser],
            canBeTargetedByLaser: true
        )
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
                .dropsMissiles,
                .causesGameOverOnContact,
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


// Ensure all @Published properties are updated on the main actor to avoid data races with SwiftUI.
@MainActor
final class GameState: ObservableObject {
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var isGameOver: Bool = false
    @Published var difficulty: Double = 1.0
    @Published var playSoundFlag = true

    var cameraLower: (() -> Void)?
    var cameraRaise: (() -> Void)?
    var setPlaySoundFlag: ((Bool) -> Void)?

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

