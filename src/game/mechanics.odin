package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:mem"

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

Bonus :: struct {
    startCell: iv2,
    endCell: iv2,

    length: int,
    symbols: [BONUS_LEN]SymbolType
}

Evaluate :: proc(reels: []Reel) -> int {
    sum := 0

    symbols: [REELS_COUNT][ROWS_COUNT]SymbolType
    points:  [REELS_COUNT][ROWS_COUNT]int

    bonusList: [dynamic]Bonus

    for &reel, x in reels {
        p := cast(int) reel.position
        for y in 0..<ROWS_COUNT {
            idx := (y + p) % reel.count
            symbol := reel.symbols[idx]

            symbols[x][y] = symbol
            points[x][y] = SYMBOLS[symbol].basePoints

            sum += SYMBOLS[symbol].basePoints
        }
    }

    // fmt.println(symbols)

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

    checkDirs := [?]iv2 {
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
                    append(&bonusList, bonus)
                }
            }
        }
    }

    fmt.println(bonusList)

    return sum
}