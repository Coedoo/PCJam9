package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:mem"

v2 :: dm.v2
iv2 :: dm.iv2

GameState :: struct {
    reels: [REELS_COUNT]Reel,
    allReelsStopped: bool,

    currentPoints: int,
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

        rand.shuffle(reel.symbols[:reel.count])
    }
}

ReelSpin :: proc(reel: ^Reel, timeOffset: f32) {
    reel.speed = rand.float32_range(SPEED_RAND_RANGE.x, SPEED_RAND_RANGE.y)
    reel.spinTimer = rand.float32_range(TIME_RAND_RANGE.x, TIME_RAND_RANGE.y) + timeOffset
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    if dm.GetKeyState(.Space) == .JustPressed {
        gameState.allReelsStopped = false

        for &reel, i in gameState.reels {
            rand.shuffle(reel.symbols[:reel.count])
            ReelSpin(&reel, f32(i) * REEL_TIME_OFFSET)
        }

        // gameState.currentPoints = Evaluate(gameState.reels[:])
    }

    // update reels
    stoppedReelsCount := 0
    for &reel, i in gameState.reels {
        if reel.spinTimer > 0 {
            reel.position += reel.speed * dm.time.deltaTime
            if int(reel.position) > reel.count {
                reel.position -= f32(reel.count)
            }

            reel.spinTimer -= dm.time.deltaTime
            if reel.spinTimer <= 0 {
                reel.position = f32(int(reel.position))
            }
        }

        if reel.spinTimer <= 0 {
            stoppedReelsCount += 1
        }
    }

    if gameState.allReelsStopped == false {
        if stoppedReelsCount == REELS_COUNT {
            gameState.allReelsStopped = true

            gameState.currentPoints = Evaluate(gameState.reels[:])
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

    posOffset := v2{REELS_COUNT, ROWS_COUNT} / 2

    // startingIdx := cast(int) anim
    // offset := anim - f32(startingIdx)

    for &reel, x in gameState.reels {
        startIdx := int(reel.position)
        offset := reel.position - f32(startIdx)

        for y in 0..< ROWS_COUNT {

            idx := (startIdx + y) % reel.count
            pos := SYMBOLS[reel.symbols[idx]].tilesetPos
            sprite := dm.GetSprite(tileSet, pos)

            dm.DrawSprite(sprite, {f32(x), f32(y) - offset} - posOffset)
        }
    }

    dm.DrawText(fmt.tprint("Points: ", gameState.currentPoints), {0, -1}, fontSize = 0.7)
}
