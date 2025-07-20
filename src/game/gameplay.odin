package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:mem"

import sa "core:container/small_array"

BeginGameplay :: proc() {
    gameState.money = START_MONEY

    gameState.roundIdx = 0
    gameState.endlessRoundNumber = 0
    gameState.allPoints = 0
    gameState.cutsceneIdx = 0

    gameState.stage = .Gameplay
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

    rand.shuffle(reel.symbols[:reel.count])

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
    reel.spinTimer = REEL_MOVE_TIME
    reel.moveStartPos = reel.position
    reel.moveTargetPos = reel.position + direction

    gameState.moves -= 1
}

StartScoreAnim :: proc() {
    gameState.bonusAnimIdx = 0
    gameState.animTimer = 0
    gameState.state = .ScoreAnim
    gameState.animStage = .Base
    gameState.animItemIdx = 0
}

GameplayUpdate :: proc() {
    if gameState.state == .Ready {
        if gameState.allPoints >= ROUNDS[gameState.roundIdx].goal {

            // Count money
            base := BASE_MONEY_PER_ROUND
            interest := gameState.money / INTEREST_STEP
            spins := gameState.spins

            fmt.println(base, interest, spins)

            gameState.money += base + interest + spins

            BeginNextRound()
        }
        else if gameState.spins <= 0 {
            gameState.state = .GameOver
        }
    }


    if gameState.state == .Spinning {
        // update reels
        for &reel, i in gameState.reels {
            if reel.spinState == .Stopped {
                continue
            }

            if reel.spinState == .Spinning {
                reel.spinTimer -= dm.time.deltaTime
                reel.position += reel.speed * dm.time.deltaTime
            }

            if reel.spinState == .Moving {
                reel.spinTimer -= dm.time.deltaTime
                p := 1 - reel.spinTimer / REEL_MOVE_TIME
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

    if gameState.state == .ScoreAnim {
        switch gameState.animStage {
        case .Base:
            gameState.animTimer -= dm.time.deltaTime

            if gameState.animTimer <= 0 {
                gameState.animTimer = 0.5

                allChecked := true
                for i in gameState.animItemIdx+1..<len(ITEMS) {
                    itemType := cast(ItemType) i
                    item := ITEMS[itemType]

                    if HasItem(itemType) && item.affectedSymbol != .None && item.baseBonus != 0 {
                        hasAffectedSymbol := false
                        for &row, x in gameState.evalResult.points {
                            for &point, y in row {
                                if GetReelSymbol(x, y) == item.affectedSymbol {
                                    hasAffectedSymbol = true

                                    point += item.baseBonus
                                }
                            }
                        }


                        if hasAffectedSymbol {
                            gameState.animItemIdx = i
                            allChecked = false
                            break
                        }
                    }
                }

                if allChecked {
                    gameState.animStage = .Bonus
                    gameState.bonusAnimIdx = 0
                    gameState.animTimer = 0
                }
            }

        case .Bonus:
            gameState.animTimer += dm.time.deltaTime

            if gameState.animTimer >= 0.5 {
                if gameState.bonusAnimIdx < gameState.evalResult.bonus.len {
                    bonus := sa.get(gameState.evalResult.bonus, gameState.bonusAnimIdx)

                    delta := bonus.endCell - bonus.startCell
                    dir := glsl.sign(delta)

                    mainSymbol := bonus.symbols[0]
                    itemsMultiplier := GetBonusMultiplierForSymbol(mainSymbol)

                    cell := bonus.startCell
                    for {
                        multiplier := BONUS_MULTIPLIERS[bonus.length] + itemsMultiplier
                        gameState.evalResult.points[cell.x][cell.y] *= multiplier

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
}

BoardSize :: proc() -> v2 {
    x := f32(REELS_COUNT) + f32(REELS_COUNT - 1) * REELS_SPACING
    y := f32(ROWS_COUNT)  + f32(ROWS_COUNT  - 1) * SYMBOLS_SPACING

    return {x, y}
}

GetSymbolPosition :: proc(x, y: int) -> v2 {
    pos := v2{f32(x), f32(y)}

    pos.x += f32(x) * REELS_SPACING
    pos.y += f32(y) * SYMBOLS_SPACING

    pos.x -= (REELS_COUNT - 1) / f32(2) + ((REELS_COUNT - 1) * REELS_SPACING)   / f32(2)
    pos.y -= (ROWS_COUNT - 1)  / f32(2) + ((ROWS_COUNT - 1)  * SYMBOLS_SPACING) / f32(2)

    return pos
}


GameplayRender :: proc() {
    // camSize := dm.GetCameraSize(dm.renderCtx.camera)

    // tt := math.mod(dm.time.gameTime / 5, 1)
    // // dm.DrawRectBlank({5, -4}, f32(tt) * 5, shader = dm.renderCtx.defaultShaders[.Rect])
    // // dm.DrawRectBlank({5 + f32(tt) / 2 -0.1, -4}, 0.2, color = dm.BLACK, shader = dm.renderCtx.defaultShaders[.Rect])


    // dm.BeginScreenSpace()

    // dm.DrawRectBlank({20, 20}, 300 + f32(tt) * 200, shader = dm.renderCtx.defaultShaders[.Rect])

    // dm.EndScreenSpace()

    // for x := -camSize.x / 2; x <= camSize.x / 2; x += 1 {
    //     for y := -camSize.y / 2; y <= camSize.y / 2; y += 1 {
    //         c1 := dm.color{180, 216, 230, 255} / 255
    //         c2 := dm.color{230, 230, 168, 255} / 255

    //         // p := x / camSize.x + 0.5
    //         t := x + y + f32(dm.time.gameTime)
    //         p := math.sin(f32(dm.time.gameTime) * 4) * 0.5 + 0.5

    //         // size := math.lerp(f32(0.5), 1, p)

    //         dm.DrawRectBlank({x, y}, 0.5, color = math.lerp(c1, c2, p), rotation = f32(dm.time.gameTime))
    //     }
    // }



    // update reels
    for &reel, i in gameState.reels {
        dm.uiCtx.disabled = gameState.state != .PlayerMove
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
            dm.NextNodePosition(dm.ToV2(dm.WorldToScreenPoint(pos - {0, 1.8})))
            if dm.UIButton("Reroll") {
                ReelSpin(&reel, 0, true)
            }

            dm.PopId()
        dm.uiCtx.disabled = false
    }

    if gameState.state != .Shop {
        dm.DrawRectBlank({0, 0}, {7, 6}, color = {1, 1, 1, 0.05})
        for &reel, x in gameState.reels {
            startIdx := int(reel.position)
            offset := reel.position - f32(startIdx)

            for y in 0..< ROWS_COUNT {

                idx := (startIdx + y) % reel.count
                symbol := SYMBOLS[reel.symbols[idx]]
                spritePos := symbol.tilesetPos
                sprite := dm.GetSprite(gameState.symbolsAtlas, spritePos)

                if reel.symbols[idx] != .None { 
                    pos := GetSymbolPosition(x, y)
                    pos.y -= offset
                    // dm.DrawRectBlank(pos, {1, 1})
                    dm.DrawSprite(sprite, pos)

                    if y < ROWS_COUNT {
                        if gameState.state == .ScoreAnim || gameState.state == .PlayerMove {
                            points := gameState.evalResult.points[x][y]
                            dm.DrawText(fmt.tprint(points), pos, fontSize = 0.5, color = dm.BLACK)
                        }
                    }

                    if gameState.state == .PlayerMove {
                        mousePos := dm.ScreenToWorldSpace(dm.input.mousePos).xy
                        bounds := dm.CreateBounds(pos, 1)
                        if dm.IsInBounds(bounds, mousePos) {
                            SymbolTooltip(reel.symbols[idx])
                        }
                    }
                }
            }
        }

        if gameState.state == .ScoreAnim {
            if gameState.animStage == .Base {
                item := ITEMS[cast(ItemType) gameState.animItemIdx]

                for &row, x in gameState.evalResult.points {
                    for &point, y in row {
                        symbol := GetReelSymbol(x, y)
                        if symbol == item.affectedSymbol {
                            pos := GetSymbolPosition(x, y)
                            dm.DrawRectBlank(pos, {0.8, 0.8}, color = {0, 0, 1, 0.3})
                        }
                    }
                }
            }

            if gameState.animStage == .Bonus {
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
    }

    panelTex := dm.GetTextureAsset("panel_right.png")
    dm.DrawRect(panelTex, {5.8, 1.5}, size = v2{4, 3})

    if dm.UIContainer("Items", .TopRight, {-300, 250}) {
        x := 0
        y := 0

        for itemD, itemType in gameState.itemsData {
            if itemD.isBought {
                item := ITEMS[itemType]

                size :: 64
                spacing :: 18

                id := fmt.aprint(itemType, allocator = dm.uiCtx.transientAllocator)
                node := dm.AddNode(id, { .Clickable, .AnchoredPosition, .BackgroundTexture })

                node.texture = gameState.itemsAtlas.texture
                node.textureSource = dm.GetSpriteRect(gameState.itemsAtlas, item.tilesetPos)

                node.origin = {0.5, 0.5}
                node.anchoredPosPercent = {0, 0}
                node.anchoredPosOffset = {f32(x) * (size + spacing), f32(y) * (size + spacing)}

                node.preferredSize[.X] = {.Fixed, size, 1}
                node.preferredSize[.Y] = {.Fixed, size, 1}

                inter := dm.GetNodeInteraction(node)

                if inter.hovered {
                    ItemTooltip(itemType)
                }

                x += 1
                if x >= 4 {
                    x = 0
                    y += 1
                }
            }
        }
    }


    style := dm.uiCtx.textStyle
    style.fontSize = 35
    style.font = cast(dm.FontHandle) dm.GetAsset("Kenney Future Narrow.ttf")

    panelTex = dm.GetTextureAsset("panel.png")
    dm.DrawRect(panelTex, {-5.8, 0}, size = v2{4, 6})

    if dm.UIContainer("Game Stats", .MiddleLeft, {20, 0}, layoutAxis = .Y ) {
        // dm.Panel("GameStatsPanel", size = iv2{128, 192} * 3, texture = panelTex)

        dm.PushStyle(style)
        dm.UILabel("Goal:", ROUNDS[gameState.roundIdx].goal)
        dm.UILabel("Current:", gameState.allPoints)

        dm.UISpacer(20)

        dm.UILabel("Money:", gameState.money)

        dm.UISpacer(20)

        dm.UILabel("Spins:", gameState.spins)
        dm.UILabel("Reel respins:", gameState.rerolls)
        dm.UILabel("Reel moves:", gameState.moves)

        dm.PopStyle()

        dm.UISpacer(100)

        if dm.UIButton("Reel Info") {
            gameState.showReelInfo = true
        }
    }

    panelTex = dm.GetTextureAsset("panel_top.png")
    dm.DrawRect(panelTex, {0, 4.5}, size = v2{5, 1})

    dm.PushStyle(style)
    if dm.UIContainer("BoardPoints", .TopCenter, {0, 20}, layoutAxis = .Y ) {
        dm.UILabel("Board Points:", gameState.evalResult.pointsSum)
    }
    dm.PopStyle()


    if dm.UIContainer("SpinOk", .MiddleRight, {-250, 200}, layoutAxis = .Y) {
        dm.uiCtx.disabled = gameState.state != .Ready
        if dm.UIButton("spin") {
            SpinAll()
        }
    

        dm.uiCtx.disabled = gameState.state != .PlayerMove
        if dm.UIButton("Ok") {
            StartScoreAnim()
        }

        dm.uiCtx.disabled = false
    }

    if gameState.showReelInfo {
        ShowReelInfo()
    }
    else if gameState.state == .Shop {
        ShowShop(&gameState.shop)
    }

    if gameState.state == .GameOver {

        dm.DrawRect(dm.GetTextureAsset("panel_shop.png"), {0, 0}, size = v2{7, 6})
        if dm.UIContainer("ReelsInfo", .MiddleCenter, layoutAxis = .Y) {
            title := gameState.endlessRoundNumber == 0 ? "Game Over" : "Run ended"
            dm.UILabel("GAMEOVER")

            dm.UILabel("Rounds:", gameState.roundIdx + gameState.endlessRoundNumber)
            dm.UILabel("Points:", gameState.allPoints)

            if dm.UIButton("OK") {
                gameState.stage = .Menu
            }
        }
    }


    dm.DrawGrid()
}