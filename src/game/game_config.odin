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
TIME_RAND_RANGE  :: v2{1, 1.2}

REEL_TIME_OFFSET :: 0.5

BONUS_LEN :: max(REELS_COUNT, ROWS_COUNT)

//
SPINS_PER_ROUND :: 4
REROLLS_PER_SPIN :: 2
MOVES_PER_SPIN :: 5

SKIP_CUTSCENES :: true


SYMBOLS := [SymbolType]Symbol {
    .None = {},

    .Cherry = {
        tilesetPos = {0, 0},
        basePoints = 10,
    },

    .Star = {
        tilesetPos = {1, 0},
        basePoints = 10,
    },

    .Coffee = {
        tilesetPos = {2, 0},
        basePoints = 10,
    },

    .Ribbon = {
        tilesetPos = {3, 0},
        basePoints = 10,
    },


    .SpecialCherry = {
        tilesetPos = {0, 1},
        basePoints = 10,
    },

    .Pipe = {
        tilesetPos = {1, 1},
        basePoints = 1,

        subtypes = ~{}
    },

    .A = {
        tilesetPos = {2, 1},
        basePoints = 1,

        subtypes = { .W },
    },

    .W = {
        tilesetPos = {3, 1},
        basePoints = 1,

        subtypes = { .A },
    },
}

STARTING_SYMBOLS := #partial #sparse [SymbolType]int {
    .Cherry = 5,
    .Star  = 5,
    .Coffee   = 5,
    .Ribbon  = 5,
}

ITEMS := [ItemType]Item {
    .FakeJorb = {
        name = "Fake Jorb",
        desc = "Grants one more spin per round.\n\nThe real one spins.\nBut, as a certain company, \nwe don't have the tech for that",
        tilesetPos = {0, 0}
    }
}