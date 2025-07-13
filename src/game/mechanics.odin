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
}

Symbol :: struct {
    type: SymbolType,
    tilesetPos: iv2,

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


Evaluate :: proc(reels: []Reel) -> int {
    sum := 0

    symbols: [REELS_COUNT][ROWS_COUNT]SymbolType
    points: [REELS_COUNT][ROWS_COUNT]int

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

    fmt.println(symbols)

    // horizontal bonus
    for y in 0..<ROWS_COUNT {
        checkedIdx := 0
        for checkedIdx < REELS_COUNT {
            checkedSymbol := symbols[checkedIdx][y]
            bonusSize := 1

            pointsOnBonus := points[checkedIdx][y]

            for i in checkedIdx+1..<REELS_COUNT {
                if symbols[i][y] == checkedSymbol {
                    bonusSize += 1
                    pointsOnBonus += points[i][y]
                }
                else {
                    break
                }
            }


            if bonusSize >= MIN_BONUS_SIZE {
                fmt.println("Horizontal Bonus at:", checkedIdx, y, "bonus Size", bonusSize)
                sum += pointsOnBonus * bonusSize
            }

            checkedIdx += bonusSize
        }
    }

    // Vertical bonus
    for x in 0..<REELS_COUNT {
        checkedIdx := 0
        for checkedIdx < ROWS_COUNT {
            checkedSymbol := symbols[x][checkedIdx]
            bonusSize := 1

            pointsOnBonus := points[x][checkedIdx]

            for i in checkedIdx+1..<ROWS_COUNT {
                if symbols[x][i] == checkedSymbol {
                    bonusSize += 1
                    pointsOnBonus += points[x][i]
                }
                else {
                    break
                }
            }


            if bonusSize >= MIN_BONUS_SIZE {
                fmt.println("Vertical Bonus at:", x, checkedIdx, "bonus Size", bonusSize)
                sum += pointsOnBonus * bonusSize
            }

            checkedIdx += bonusSize
        }
    }


    fmt.println()



    return sum
}