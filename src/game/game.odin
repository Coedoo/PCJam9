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

    boardSprite: dm.Sprite,

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
    animPointsCount: int

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
    dm.RegisterAsset("Board.png", dm.TextureAssetDescriptor{})


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

    boardTex := dm.GetTextureAsset("Board.png")
    gameState.boardSprite = dm.CreateSprite(boardTex)
    gameState.boardSprite.scale = dm.GetSpriteScale(gameState.boardSprite, 32)

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

    BeginNextRound()
}

SpinAll :: proc() {
    if gameState.spins == 0 {
        return
    }

    gameState.spins -= 1

    gameState.rerolls = 0
    gameState.moves = 0

    for &reel, i in gameState.reels {
        rand.shuffle(reel.symbols[:reel.count])
        ReelSpin(&reel, f32(i) * REEL_TIME_OFFSET, false)
    }


    gameState.rerolls = REROLLS_PER_SPIN
    gameState.moves = MOVES_PER_SPIN
}

ReelSpin :: proc(reel: ^Reel, timeOffset: f32, useReroll: bool) {
    if useReroll && gameState.rerolls == 0 {
        return
    }

    gameState.state = .Spinning

    reel.speed = rand.float32_range(SPEED_RAND_RANGE.x, SPEED_RAND_RANGE.y)
    reel.spinTimer = rand.float32_range(TIME_RAND_RANGE.x, TIME_RAND_RANGE.y) + timeOffset

    reel.spinState = .Spinning

    if useReroll {
        gameState.rerolls -= 1
    }
}

ReelMove :: proc(reel: ^Reel, direction: f32) {
    if gameState.moves == 0 {
        return
    }

    gameState.state = .Spinning

    reel.spinState = .Moving
    reel.spinTimer = 0.5
    reel.moveStartPos = reel.position
    reel.moveTargetPos = reel.position + direction

    gameState.moves -= 1
}

StartScoreAnim :: proc() {
    gameState.bonusAnimIdx = 0
    gameState.animTimer = 0
    gameState.state = .ScoreAnim
    gameState.animStage = .Base
}

@(export)
GameUpdate : dm.GameUpdate : proc(state: rawptr) {
    gameState = cast(^GameState) state

    // if dm.GetKeyState(.Q) == .JustPressed {
    //     InitShop(&gameState.shop)
    //     gameState.showShop = true
    // }

    // if gameState.showShop {
    //     ShowShop(&gameState.shop)
    // }

    if gameState.state == .Ready {
        if gameState.allPoints >= ROUNDS[gameState.roundIdx].goal {
            BeginNextRound()
        }
    }

    // update reels
    for &reel, i in gameState.reels {

        if gameState.state == .PlayerMove {
            dm.PushId(i)

            pos := GetSymbolPosition(i, ROWS_COUNT - 1)

            dm.NextNodePosition(dm.ToV2(dm.WorldToScreenPoint(pos + {0, 1})))
            if dm.UIButton("Move Up") {
                ReelMove(&reel, -1)
            }


            pos = GetSymbolPosition(i, 0)
            dm.NextNodePosition(dm.ToV2(dm.WorldToScreenPoint(pos - {0, 1})))
            if dm.UIButton("Move Down") {
                ReelMove(&reel, 1)
            }

            pos = GetSymbolPosition(i, 0)
            dm.NextNodePosition(dm.ToV2(dm.WorldToScreenPoint(pos - {0, 1.4})))
            if dm.UIButton("Reroll") {
                ReelSpin(&reel, 0, true)
            }

            dm.PopId()
        }


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
    if gameState.state == .Spinning {
        allStopped := true
        for &reel, i in gameState.reels {
            if reel.spinState != .Stopped {
                allStopped = false
                break
            }
        }

        if allStopped {
            gameState.state = .PlayerMove
            gameState.evalResult = Evaluate(gameState.reels[:])
        }
    }

    //
    if gameState.state == .Ready {
        dm.NextNodePosition(dm.ToV2(dm.WorldToScreenPoint({4, 0})))
        if dm.UIButton("spin") {

            SpinAll()
        }
    }

    if gameState.state == .PlayerMove {
        dm.NextNodePosition(dm.ToV2(dm.WorldToScreenPoint({4, -1})))
        if dm.UIButton("Ok") {
            // gameState.allPoints += gameState.evalResult.pointsSum
            // gameState.evalResult.pointsSum = 0

            StartScoreAnim()
        }
    }

    if gameState.state == .ScoreAnim {
        switch gameState.animStage {
        case .Base:
            gameState.animStage = .Bonus
            gameState.bonusAnimIdx = 0

        case .Bonus:
            gameState.animTimer += dm.time.deltaTime

            if gameState.animTimer >= 0.5 {
                if gameState.bonusAnimIdx < gameState.evalResult.bonus.len {
                    bonus := sa.get(gameState.evalResult.bonus, gameState.bonusAnimIdx)

                    delta := bonus.endCell - bonus.startCell
                    dir := glsl.sign(delta)

                    cell := bonus.startCell
                    for {
                        gameState.evalResult.points[cell.x][cell.y] *= bonus.length

                        if cell == bonus.endCell {
                            break
                        }
                        cell += dir
                    }

                    RefreshPoints(&gameState.evalResult)
                }


                gameState.bonusAnimIdx += 1
                gameState.animTimer = 0
            }

            if gameState.bonusAnimIdx >= gameState.evalResult.bonus.len {
                gameState.animStartPoints = gameState.allPoints
                gameState.animPointsCount = gameState.evalResult.pointsSum

                gameState.animStage = .Points
                gameState.animTimer = 0
            }

        case .Points:
            p := gameState.animTimer / 0.5
            gameState.evalResult.pointsSum = cast(int) math.lerp(f32(gameState.animPointsCount), 0, p)
            gameState.allPoints = cast(int) math.lerp(f32(gameState.animStartPoints), f32(gameState.animStartPoints + gameState.animPointsCount), p)

            if p >= 1 {
                gameState.allPoints = gameState.animStartPoints + gameState.animPointsCount
                gameState.state = .Ready
            }

            gameState.animTimer += dm.time.deltaTime
        }
    }

    /////////////
    // DEBUG
    ////////////

    if dm.GetKeyState(.Z) == .JustPressed {
        gameState.evalResult = Evaluate(gameState.reels[:])
        StartScoreAnim()
    }

    if dm.GetKeyState(.S) == .JustPressed {
        BeginNextRound()
    }

    mousePos := dm.ScreenToWorldSpace(dm.input.mousePos).xy

    for &reel, x in gameState.reels {
        for y in 0..< ROWS_COUNT + 1 {
            pos := GetSymbolPosition(x, y)
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
            }
        }
    }

    // if dm.Panel("SymbolsCount") {
    //     dm.BeginLayout(axis = .X)

    //     for &reel, rIdx in gameState.reels {
    //         count := CountReelSymbols(reel)

    //         dm.BeginLayout(axis = .Y)

    //         for c, i in count {
    //             dm.PushId(rIdx)
    //             if c != 0 {
    //                 dm.UILabel(cast(SymbolType) i, c)
    //             }
    //             dm.PopId()
    //         }

    //         dm.EndLayout()
    //     }

    //     dm.EndLayout()
    // }

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


    tileSet := dm.SpriteAtlas {
        texture = dm.GetTextureAsset(BASIC_TILESET),
        cellSize = 32,
    }

    if gameState.state != .Shop {
        for &reel, x in gameState.reels {
            startIdx := int(reel.position)
            offset := reel.position - f32(startIdx)

            for y in 0..< ROWS_COUNT {

                idx := (startIdx + y) % reel.count
                symbol := SYMBOLS[reel.symbols[idx]]
                spritePos := symbol.tilesetPos
                sprite := dm.GetSprite(tileSet, spritePos)

                if reel.symbols[idx] != .None { 
                    pos := GetSymbolPosition(x, y)
                    pos.y -= offset
                    dm.DrawSprite(sprite, pos)

                    if y < ROWS_COUNT {
                        // if gameState.state == .ScoreAnim {
                            points := gameState.evalResult.points[x][y]
                            dm.DrawText(fmt.tprint(points), pos, fontSize = 0.5)
                        // }
                    }


                    mousePos := dm.ScreenToWorldSpace(dm.input.mousePos).xy
                    bounds := dm.CreateBounds(pos, 1)
                    if dm.IsInBounds(bounds, mousePos) {
                        dm.NextNodePosition(dm.ToV2(dm.input.mousePos), {0, 0})
                        if dm.Panel("Tooltip") {
                            dm.UILabel(reel.symbols[idx])
                            dm.UILabel("Base points:", symbol.basePoints)
                        }
                    }
                }
            }
        }

        if gameState.state == .ScoreAnim {
            if gameState.bonusAnimIdx < gameState.evalResult.bonus.len {
                bonus := sa.get(gameState.evalResult.bonus, gameState.bonusAnimIdx)
                delta := bonus.endCell - bonus.startCell
                dir := glsl.sign(delta)

                cell := bonus.startCell
                for {
                    pos := GetSymbolPosition(int(cell.x), int(cell.y))
                    dm.DrawRectBlank(pos, {0.8, 0.8}, color = {0, 1, 1, 0.3})

                    if cell == bonus.endCell {
                        break
                    }

                    cell += dir
                }
            }
        }
    }

    if gameState.state == .Shop {
        ShowShop(&gameState.shop)
    }

    dm.DrawGrid()
    // dm.DrawSprite(gameState.boardSprite, {0, 0})

    dm.DrawText(fmt.tprint("Goal: ", ROUNDS[gameState.roundIdx].goal), {-3, 4.6}, fontSize = 0.4)
    dm.DrawText(fmt.tprint("Current Points: ", gameState.allPoints), {-3, 4.0}, fontSize = 0.4)
    dm.DrawTextCentered(fmt.tprint("Board Points: ", gameState.evalResult.pointsSum), {0, -3}, fontSize = 0.4)
    // dm.DrawTextCentered(fmt.tprint("Spins left: ", gameState.spins), {2.5, -2}, fontSize = 0.4)
    // dm.DrawTextCentered(fmt.tprint("Rerolls: ", gameState.rerolls), {2.5, -3}, fontSize = 0.4)
    // dm.DrawTextCentered(fmt.tprint("Moves: ", gameState.moves), {2.5, -4}, fontSize = 0.4)
}
