package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:mem"

import "../ldtk"

v2 :: dm.v2
iv2 :: dm.iv2

SymbolType :: enum {
    None,
    Cherry,
    Seven,
    Star,
    Lemon,
}

Symbol :: struct {
    type: SymbolType,
    tilesetName: string,
    tilesetPos: iv2,
}

Reel :: struct {
    symbols: [REEL_SIZE]SymbolType,
    count: int,
}


GameState :: struct {
    reels: [REELS_COUNT]Reel,
}

gameState: ^GameState


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
    }
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    if dm.GetKeyState(.Space) == .JustPressed {
        for &reel in gameState.reels {
            rand.shuffle(reel.symbols[:reel.count])
            fmt.println(reel.symbols[:reel.count])
        }
    }
}

@(export)
GameUpdateDebug : dm.GameUpdateDebug : proc(state: rawptr) {
    gameState = cast(^GameState) state
}

@(export)
GameRender : dm.GameRender : proc(state: rawptr) {
    gameState = cast(^GameState) state
    dm.ClearColor({0.1, 0.1, 0.3, 1})

    tileSet := dm.SpriteAtlas {
        texture = dm.GetTextureAsset(BASIC_TILESET),
        cellSize = 48,
    }

    for &reel, x in gameState.reels {
        for y in 0..<5 {
            pos := SYMBOLS[reel.symbols[y]].tilesetPos
            sprite := dm.GetSprite(tileSet, pos)

            dm.DrawSprite(sprite, {f32(x), f32(y)})
        }
    }
}
