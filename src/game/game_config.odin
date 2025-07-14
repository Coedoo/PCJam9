package game

import "core:mem"
import "core:fmt"

import dm "../dmcore"

BASIC_TILESET :: "symbols.png"

START_MONEY :: 1000

REELS_COUNT :: 5
ROWS_COUNT :: 5
REEL_SIZE :: 64

MIN_BONUS_LEN :: 3

SPEED_RAND_RANGE :: v2{20, 22}
TIME_RAND_RANGE  :: v2{2, 2.2}

REEL_TIME_OFFSET :: 0.5

BONUS_LEN :: max(REELS_COUNT, ROWS_COUNT)

//
SPINS_PER_ROUND :: 4
REROLLS_PER_SPIN :: 2
MOVES_PER_SPIN :: 5

SYMBOLS := [SymbolType]Symbol {
    .None = {},

    .Cherry = {
        tilesetPos = {0, 0},
        basePoints = 10,
    },

    .Burger = {
        tilesetPos = {1, 0},
        basePoints = 15,
    },

    .Coffee = {
        tilesetPos = {2, 0},
        basePoints = 10,
    },

    .Lemon = {
        tilesetPos = {3, 0},
        basePoints = 10,
    },


    .SpecialCherry = {
        tilesetPos = {0, 1},
        basePoints = 10,
    },

    .Ribbon = {
        tilesetPos = {1, 1},
        basePoints = 10,

        subtypes = ~{}
    }
}

STARTING_SYMBOLS := #partial #sparse [SymbolType]int {
    .Cherry = 5,
    .Burger  = 5,
    .Coffee   = 5,
    .Lemon  = 5,
}
