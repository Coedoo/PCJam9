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


Evaluate :: proc(reels: []Reel) -> int {
    sum := 0

    symbols: [REELS_COUNT][ROWS_COUNT]SymbolType
    points:  [REELS_COUNT][ROWS_COUNT]int

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

    IsOk :: proc(symbols: [][]SymbolType, checkedSymbol: SymbolType, x, y: int) -> bool {
        sym := SYMBOLS[checkedSymbol]

        ret := symbols[x][y] == checkedSymbol
        ret = ret || (checkedSymbol in sym.subtypes)

        return ret
    }

    // horizontal bonus
    for y in 0..<ROWS_COUNT {
        checkedIdx := 0
        for checkedIdx < REELS_COUNT {
            checkedSymbol := symbols[checkedIdx][y]
            bonusSize := 1

            pointsOnBonus := points[checkedIdx][y]

            for i in checkedIdx+1..<REELS_COUNT {
                if symbols[i][y] == checkedSymbol {
                // if IsOk(symbols[i][y], checkedSymbol,  {
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

    // Diagonal Bonus
    checked: [REELS_COUNT][ROWS_COUNT][2]bool

    for x in 0..<REELS_COUNT {
        for y in 0..<ROWS_COUNT {

            checkedCell := iv2{i32(x), i32(y)}

            checkedSymbol := symbols[checkedCell.x][checkedCell.y]
            bonusSize := 1
            pointsOnBonus := points[checkedCell.x][checkedCell.y]

            if checked[checkedCell.x][checkedCell.y][0] == false {
                checkedCell += {1, 1}
                for checkedCell.x < REELS_COUNT && checkedCell.y < ROWS_COUNT {
                    if symbols[checkedCell.x][checkedCell.y] == checkedSymbol {
                        bonusSize += 1
                        pointsOnBonus += points[checkedCell.x][checkedCell.y]
                        checkedCell += {1, 1}
                    }
                    else {
                        break
                    }
                }

                if bonusSize >= MIN_BONUS_SIZE {
                    fmt.println("Diagonal bonus at {", x, y, "}", checkedSymbol ,"bonus Size", bonusSize)
                    sum += pointsOnBonus * bonusSize
                    
                    for i in 0..<bonusSize {
                        xIdx := x + i
                        yIdx := y + i
                        checked[xIdx][yIdx][0] = true
                    }
                }
            }
        }
    }


    for y in 0..<ROWS_COUNT {
        for x in 0..<REELS_COUNT {
            checkedCell := iv2{i32(x), i32(y)}
            checkedSymbol := symbols[checkedCell.x][checkedCell.y]
            bonusSize := 1
            pointsOnBonus := points[checkedCell.x][checkedCell.y]

            if checked[checkedCell.x][checkedCell.y][1] == false {
                checkedCell += {-1, 1}
                for checkedCell.x >= 0 && checkedCell.y < ROWS_COUNT {
                    if (symbols[checkedCell.x][checkedCell.y] == checkedSymbol &&
                        checked[checkedCell.x][checkedCell.y][1] == false)
                    {
                        bonusSize += 1
                        pointsOnBonus += points[checkedCell.x][checkedCell.y]
                        checkedCell += {-1, 1}
                    }
                    else {
                        break
                    }
                }

                if bonusSize >= MIN_BONUS_SIZE {
                    fmt.println("Diagonal back bonus at {", x, y, "}", checkedSymbol ,"bonus Size", bonusSize)
                    sum += pointsOnBonus * bonusSize
                    
                    for i in 0..<bonusSize {
                        xIdx := x - i
                        yIdx := y + i
                        checked[xIdx][yIdx][1] = true
                    }
                }
            }
        }
    }

    fmt.println()



    return sum
}