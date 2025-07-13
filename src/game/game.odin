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
    reelsSpinning: bool,

    currentPoints: int,

    money: int,
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

    gameState.money = START_MONEY
}

SpinAll :: proc() {
    for &reel, i in gameState.reels {
        rand.shuffle(reel.symbols[:reel.count])
        ReelSpin(&reel, f32(i) * REEL_TIME_OFFSET)
    }
}

ReelSpin :: proc(reel: ^Reel, timeOffset: f32) {
    gameState.reelsSpinning = true

    reel.speed = rand.float32_range(SPEED_RAND_RANGE.x, SPEED_RAND_RANGE.y)
    reel.spinTimer = rand.float32_range(TIME_RAND_RANGE.x, TIME_RAND_RANGE.y) + timeOffset

    reel.spinState = .Spinning
}

ReelMove :: proc(reel: ^Reel, direction: f32) {
    gameState.reelsSpinning = true

    reel.spinState = .Moving
    reel.spinTimer = 0.5
    reel.moveStartPos = reel.position
    reel.moveTargetPos = reel.position + direction
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    if dm.GetKeyState(.Space) == .JustPressed {
        SpinAll()
    }


    dm.NextNodePosition(dm.ToV2(dm.WorldToScreenPoint({3, 0})))
    if dm.UIButton("spin") {
        SpinAll()
    }

    // update reels
    for &reel, i in gameState.reels {
        posOffset := v2{REELS_COUNT, ROWS_COUNT} / 2

        dm.PushId(i)
        pos := v2{f32(i), -1.8} - posOffset

        uiPos := dm.WorldToScreenPoint(pos)
        dm.NextNodePosition(dm.ToV2(uiPos))
        if dm.UIButton("Reroll") {
            ReelSpin(&reel, 0)
        }

        pos.y = -3.3
        uiPos = dm.WorldToScreenPoint(pos)
        dm.NextNodePosition(dm.ToV2(uiPos))
        if dm.UIButton("Move Down") {
            ReelMove(&reel, 1)
        }

        pos.y = 2.3
        uiPos = dm.WorldToScreenPoint(pos)
        dm.NextNodePosition(dm.ToV2(uiPos))
        if dm.UIButton("Move Up") {
            ReelMove(&reel, -1)
        }


        dm.PopId()


        if reel.spinState == .Stopped {
            continue
        }

        if reel.spinState == .Spinning {
            reel.spinTimer -= dm.time.deltaTime
            reel.position += reel.speed * dm.time.deltaTime
        }

        if reel.spinState == .Moving {
            reel.spinTimer -= dm.time.deltaTime
            p := 1 - reel.spinTimer / 0.5
            reel.position = math.lerp(reel.moveStartPos, reel.moveTargetPos, p)
        }

        if reel.spinTimer <= 0 {
            reel.spinState = .Stopped

            // handle overflow
            reel.position = f32(math.round(reel.position))
            if int(reel.position) > reel.count {
                reel.position -= f32(reel.count)
            }
            if int(reel.position) < 0 {
                reel.position += f32(reel.count)
            }
        }
    }

    // check if reels stopped
    if gameState.reelsSpinning {
        allStopped := true
        for &reel, i in gameState.reels {
            if reel.spinState != .Stopped {
                allStopped = false
                break
            }
        }

        if allStopped {
            gameState.reelsSpinning = false
            gameState.currentPoints = Evaluate(gameState.reels[:])
        }
    }

    /////////////
    // DEBUG
    ////////////

    if dm.GetKeyState(.Z) == .JustPressed {
        gameState.currentPoints = Evaluate(gameState.reels[:])
    }

    mousePos := dm.ScreenToWorldSpace(dm.input.mousePos).xy

    posOffset := v2{REELS_COUNT, ROWS_COUNT} / 2
    for &reel, x in gameState.reels {

        for y in 0..< ROWS_COUNT {
            pos := v2{f32(x), f32(y)} - posOffset
            bounds := dm.CreateBounds(pos, 1)

            if dm.IsInBounds(bounds, mousePos) {
                scroll := dm.input.scroll
                startIdx := int(reel.position)
                idx := (startIdx + y) % reel.count

                if scroll != 0 {
                    
                    i := cast(int) reel.symbols[idx]
                    i = (i + scroll) % len(SymbolType)
                    if i < 0 {
                        i = len(SymbolType) - 1
                    }

                    reel.symbols[idx] = cast(SymbolType) i
                }

                dm.NextNodePosition(dm.ToV2(dm.input.mousePos), {0, 0})
                if dm.Panel("Tooltip") {
                    symbol := SYMBOLS[reel.symbols[idx]]
                    dm.UILabel(reel.symbols[idx])
                    dm.UILabel("Base points:", symbol.basePoints)
                }
            }
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

            if reel.symbols[idx] != .None {
                dm.DrawSprite(sprite, {f32(x), f32(y) - offset} - posOffset)
            }
        }
    }

    dm.DrawText(fmt.tprint("Points: ", gameState.currentPoints), {2.5, 0}, fontSize = 0.7)
}
