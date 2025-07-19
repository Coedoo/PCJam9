package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:mem"

import sa "core:container/small_array"

SymbolType :: enum {
    None,
    Cherry,
    Star,
    Coffee,
    Ribbon,

    // Special
    SpecialCherry,
    Pipe,

    A,
    W,
}

SymbolTypesSet :: distinct bit_set[SymbolType]

Symbol :: struct {
    tilesetPos: iv2,

    subtypes: SymbolTypesSet,

    basePoints: int,
}

ReelSpinState :: enum {
    Stopped,
    Spinning,
    Moving,
}

Reel :: struct {
    symbols: [REEL_SIZE]SymbolType,
    count: int,

    spinState: ReelSpinState,
    position: f32,

    speed: f32,
    spinTimer: f32,

    moveStartPos: f32,
    moveTargetPos: f32,
}

EvaluationResult :: struct {
    bonus: sa.Small_Array(128, Bonus),

    points: [REELS_COUNT][ROWS_COUNT]int,
    pointsSum: int,
}

Bonus :: struct {
    startCell: iv2,
    endCell: iv2,

    length: int,
    symbols: [BONUS_LEN]SymbolType
}


ItemType :: enum {
    FakeJorb,
    Item2,
    Item3,
    Item4,
}

ItemData :: struct {
    isBought: bool,
}

Item :: struct {
    name: string,
    desc: string,

    tilesetPos: iv2,

    price: int,
    weight: int,
}


GetReelSymbol :: proc(x, y: int) -> SymbolType {
    reel := gameState.reels[x]

    startIdx := int(reel.position)
    idx := (startIdx + y) % reel.count

    return reel.symbols[idx]
}

AddSymbolToReel :: proc(reel: ^Reel, symbol: SymbolType) -> bool {
    if reel.count < REEL_SIZE {
        reel.symbols[reel.count] = symbol
        reel.count += 1

        return true
    }

    return false
}

CountReelSymbols :: proc(reel: Reel) -> (ret: [SymbolType]int) {
    for i in 0..<reel.count {
        ret[reel.symbols[i]] += 1
    }

    return
}

IsOk :: proc(first, other: SymbolType) -> bool {
    if first == other {
        return true
    }

    firstSymbol := SYMBOLS[first]
    otherSymbol := SYMBOLS[other]

    firstSet := firstSymbol.subtypes + { first }
    otherSet := otherSymbol.subtypes + { other }

    return card(firstSet & otherSet) > 0
}

RefreshPoints :: proc(eval: ^EvaluationResult) {
    sum := 0

    for col in eval.points {
        for points in col {
            sum += points
        }
    }

    eval.pointsSum = sum
}

Evaluate :: proc(reels: []Reel) -> EvaluationResult {
    res: EvaluationResult

    symbols: [REELS_COUNT][ROWS_COUNT]SymbolType

    for &reel, x in reels {
        p := cast(int) reel.position
        for y in 0..<ROWS_COUNT {
            idx := (y + p) % reel.count
            symbol := reel.symbols[idx]

            symbols[x][y] = symbol
            res.points[x][y] = SYMBOLS[symbol].basePoints

            res.pointsSum += SYMBOLS[symbol].basePoints
        }
    }


    checkDirs :: [?]iv2 {
        {1, 0},
        {0, 1},
        {1, 1},
        {1, -1},
    }

    for &column, x in symbols {
        for symbol, y in column {
            checkeSymbol := symbols[x][y]

            for dir in checkDirs {
                // check if it's the first symbol in sequence
                prevCell := iv2{i32(x), i32(y)} - dir
                if (prevCell.x >= 0 && prevCell.x < REELS_COUNT && 
                    prevCell.y >= 0 && prevCell.y < ROWS_COUNT &&
                    IsOk(checkeSymbol, symbols[prevCell.x][prevCell.y]))
                {
                    continue
                }


                bonus: Bonus

                cell := iv2{i32(x), i32(y)}
                bonus.startCell = cell

                if symbols[cell.x][cell.y] == .Pipe {
                    continue
                }

                for (cell.x >= 0 && cell.x < REELS_COUNT && 
                     cell.y >= 0 && cell.y < ROWS_COUNT &&
                     IsOk(checkeSymbol, symbols[cell.x][cell.y]))
                {
                    bonus.symbols[bonus.length] = symbols[cell.x][cell.y]
                    bonus.length += 1
                    bonus.endCell = cell

                    cell += dir
                }

                if bonus.length >= MIN_BONUS_LEN {
                    sa.append(&res.bonus, bonus)
                }
            }
        }
    }

    // Fix bonuses for special cases
    for &bonus in sa.slice(&res.bonus) {
        startSymbol := bonus.symbols[0]

        delta := bonus.endCell - bonus.startCell
        dir := glsl.sign(delta)

        // I want it to only score when forms AWA or AWAWA
        if startSymbol == .A || startSymbol == .W {

            startIdx := 0
            for i in 0..<bonus.length {
                if bonus.symbols[i] == .A && bonus.symbols[i + 1] == .W {
                    startIdx = i
                    break
                }
            }

            endIdx := 0
            i := startIdx + 1
            for {
                if i + 1 >= bonus.length {
                    break
                }

                if bonus.symbols[i] == .W && bonus.symbols[i + 1] == .A {
                    endIdx = i + 1
                }

                i += 2
            }

            len := endIdx - startIdx

            // fix bonus
            copy(bonus.symbols[:], bonus.symbols[startIdx:startIdx + len])
            bonus.startCell = bonus.startCell + dir * i32(startIdx)
            bonus.endCell = bonus.startCell + dir * i32(len)
            bonus.length = len
        }
    }

    for b in sa.slice(&res.bonus) {
        fmt.println(b)
    }

    return res
}

SymbolTooltip :: proc(type: SymbolType) {
    symbol := SYMBOLS[type]

    dm.NextNodePosition(dm.ToV2(dm.input.mousePos), {0, 0})
    if dm.Panel("Tooltip") {
        dm.UILabel(type)
        dm.UILabel("Base points:", symbol.basePoints)
    }
}

ItemTooltip :: proc(type: ItemType) {
    item := ITEMS[type]

    dm.NextNodePosition(dm.ToV2(dm.input.mousePos), {1, 0})
    if dm.Panel("Tooltip") {
        dm.UILabel(item.name)
        dm.UISpacer(10)
        dm.UILabel(item.desc)
    }
}

ShowReelInfo :: proc() {
    dm.DrawRect(dm.GetTextureAsset("panel_shop.png"), {0, 0}, size = v2{7, 6})

    if dm.UIContainer("ReelsInfo", .MiddleCenter) {

        if dm.Panel("REELSINFO", aligment = dm.Aligment{.Middle, .Middle}) {
            dm.BeginLayout("reelslayout1", axis = .X)

            for &reel, rIdx in gameState.reels {
                count := CountReelSymbols(reel)
                
                dm.PushId(rIdx)
                dm.BeginLayout("reelslayout2", axis = .Y)

                for c, i in count {
                    if c != 0 {
                        symbol := SYMBOLS[i]

                        rect := dm.GetSpriteRect(gameState.symbolsAtlas, symbol.tilesetPos)
                        dm.PushId(int(i))
                        dm.BeginLayout("reelslayout3", axis = .X)
                        dm.UIImage(gameState.symbolsAtlas.texture, source = rect, size = 64)
                        dm.UILabel(fmt.tprintf("x%v", c))
                        dm.EndLayout()
                        dm.PopId()

                    }
                }

                dm.EndLayout()
                dm.PopId()
            }

            dm.EndLayout()

            // dm.UISpacer(30)
            if dm.UIButton("OK") {
                gameState.showReelInfo = false
            }
        }
    }
}