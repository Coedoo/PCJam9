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
    Burger,
    Coffee,
    Lemon,

    // Special
    SpecialCherry,
    Ribbon,
}

SymbolTypesSet :: distinct bit_set[SymbolType]

Symbol :: struct {
    type: SymbolType,
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

    for b in sa.slice(&res.bonus) {
        fmt.println(b)
    }

    return res
}