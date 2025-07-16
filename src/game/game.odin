package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:mem"

import sa "core:container/small_array"

v2 :: dm.v2
iv2 :: dm.iv2

GameStage :: enum {
    Menu,
    Cutscene,
    Gameplay
}

GameplayState :: enum {
    Ready,
    Spinning,
    PlayerMove,
    ScoreAnim,
    Shop
}

ScoreAnimStage :: enum {
    Base,
    Bonus,
    Points,
}

GameState :: struct {
    state: GameplayState,
    stage: GameStage,
    menuStage: MenuStage,

    symbolsAtlas: dm.SpriteAtlas,
    itemsAtlas: dm.SpriteAtlas,

    reels: [REELS_COUNT]Reel,
    evalResult: EvaluationResult,


    allPoints: int,
    money: int,

    // Rounds stuff
    roundIdx: int,
    spins:    int,
    rerolls:  int,
    moves:    int,

    // Shop
    shop: Shop,
    showShop: bool,

    // anim
    animStage: ScoreAnimStage,
    animTimer: f32,

    bonusAnimIdx: int,

    animStartPoints: int,
    animPointsCount: int,

    // 
    showReelInfo: bool,
}

gameState: ^GameState


RemoveMoney :: proc(money: int) -> bool {
    if gameState.money >= money {
        gameState.money -= money
        return true
    }

    return false
}

@export
PreGameLoad : dm.PreGameLoad : proc(assets: ^dm.Assets) {
    dm.RegisterAsset(BASIC_TILESET, dm.TextureAssetDescriptor{})


    dm.platform.SetWindowSize(1200, 900)
}

@(export)
GameHotReloaded : dm.GameHotReloaded : proc(gameState: rawptr) {
    // gameState := cast(^GameState) gameState

    // gameState.levelAllocator = mem.arena_allocator(&gameState.levelArena)
}

@(export)
GameLoad : dm.GameLoad : proc(platform: ^dm.Platform) {
    gameState = dm.AllocateGameData(platform, GameState)

    startSymbols: [REEL_SIZE]SymbolType
    symbolsCount: int
    for count, t in STARTING_SYMBOLS {
        type := cast(SymbolType) t

        for i in 0..<count {
            startSymbols[symbolsCount] = type
            symbolsCount += 1
        }
    }

    // fmt.println(startSymbols[:symbolsCount])

    for &reel in gameState.reels {
        copy(reel.symbols[:symbolsCount], startSymbols[:symbolsCount])
        reel.count = symbolsCount

        rand.shuffle(reel.symbols[:reel.count])
    }

    gameState.symbolsAtlas = dm.SpriteAtlas {
        texture = dm.GetTextureAsset(BASIC_TILESET),
        cellSize = 32,
    }

    gameState.money = START_MONEY
    BeginNextRound()

    gameState.stage = .Gameplay
}


@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    switch gameState.stage {
    case .Menu:     
    case .Cutscene: 
    case .Gameplay: GameplayUpdate()
    }

    // fmt.println()
    // fmt.println(dm.CreateUIDebugString())
}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr) {
    gameState = cast(^GameState) state
}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    gameState = cast(^GameState) state

    dm.ClearColor({0.1, 0.1, 0.3, 1})


    switch gameState.stage {
    case .Menu:     
    case .Cutscene: 
    case .Gameplay: GameplayRender()
    }

    // fmt.println()
    // fmt.println(dm.CreateUIDebugString())
}
