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

    // Items 
    itemsData: [ItemType]ItemData,

    // Shop
    shop: Shop,
    showShop: bool,

    // Cutscene
    cutsceneIdx: int,

    // anim
    animStage: ScoreAnimStage,
    animTimer: f32,

    bonusAnimIdx: int,

    animStartPoints: int,
    animPointsCount: int,

    // Menu state
    showReelInfo: bool,
}

gameState: ^GameState


HasItem :: proc(item: ItemType) -> bool {
    return gameState.itemsData[item].isBought
}

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
    dm.RegisterAsset("items.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("Jelly_anim.png", dm.TextureAssetDescriptor{})
    
    dm.RegisterAsset("enviro.png", dm.TextureAssetDescriptor{})
    
    // UI
    dm.RegisterAsset("enviro.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("panel.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("panel_top.png", dm.TextureAssetDescriptor{})
    dm.RegisterAsset("panel_right.png", dm.TextureAssetDescriptor{})


    dm.RegisterAsset("jelly_curious.png", dm.TextureAssetDescriptor{filter = .Bilinear})
    dm.RegisterAsset("jelly_happy.png", dm.TextureAssetDescriptor{filter = .Bilinear})

    dm.RegisterAsset("Kenney Future Narrow.ttf", dm.FontAssetDescriptor{.SDF, 50})
    dm.RegisterAsset("Kenney Future.ttf",        dm.FontAssetDescriptor{.SDF, 50})
    dm.RegisterAsset("Kenney Mini Square.ttf",   dm.FontAssetDescriptor{.SDF, 50})

    dm.platform.SetWindowSize(1400, 900)
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

    gameState.itemsAtlas = dm.SpriteAtlas {
        texture = dm.GetTextureAsset("items.png"),
        cellSize = 32,
        spacing = 1,
        padding = 1,
    }


    InitCharacters()

    BeginGameplay()
}


@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    if dm.GetKeyState(.A) == .JustPressed {
        for &i in gameState.itemsData {
            i.isBought = true
        }
    }

    switch gameState.stage {
    case .Menu:     MenuUpdate()
    case .Cutscene: UpdateCutscene(&Cutscenes[gameState.cutsceneIdx])
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

    // dm.BeginScreenSpace()
    // tex := dm.GetTextureAsset("jelly_curious.png")
    // dm.DrawRectPos(tex, {600, 800}, size = v2{450, 600}, origin = v2{0.5, 1})
    // dm.EndScreenSpace()

    switch gameState.stage {
    case .Menu:     MenuRender()
    case .Cutscene: DrawCutscene(&Cutscenes[gameState.cutsceneIdx])
    case .Gameplay: GameplayRender()
    }

    // fmt.println()
    // fmt.println(dm.CreateUIDebugString())
}
