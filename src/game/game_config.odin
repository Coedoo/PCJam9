package game

import "core:mem"
import "core:fmt"

import dm "../dmcore"

BASIC_TILESET :: "symbols.png"

START_MONEY :: 10

REELS_COUNT :: 5
ROWS_COUNT :: 5
REEL_SIZE :: 64

MIN_BONUS_LEN :: 3
BONUS_MULTIPLIERS := []int {0, 1, 1, 3, 5, 8}
AWA_MULTIPLIERS := []int {0, 1, 1, 5, 5, 10}

//

REELS_SPACING   :: 10 / f32(32)
SYMBOLS_SPACING :: 5 / f32(32)

//

SPEED_RAND_RANGE :: v2{20, 22}
TIME_RAND_RANGE  :: v2{1, 1.2}

REEL_TIME_OFFSET :: 0.5

REEL_MOVE_TIME :: 0.3

BONUS_LEN :: max(REELS_COUNT, ROWS_COUNT)

//
SPINS_PER_ROUND :: 4
REROLLS_PER_SPIN :: 2
MOVES_PER_SPIN :: 5

//
BASE_MONEY_PER_ROUND :: 10
INTEREST_STEP :: 5

when ODIN_DEBUG {
SKIP_CUTSCENES :: false
}
else {
SKIP_CUTSCENES :: false
}


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

    .Burger = {
        tilesetPos = {0, 1},
        basePoints = 50,
        text = "I run out of ideas :<"
    },

    .Pipe = {
        tilesetPos = {1, 1},
        basePoints = 1,

        subtypes = ~{},

        text = "Counts as every other symbol"
    },

    .A = {
        tilesetPos = {2, 1},
        basePoints = 15,

        subtypes = { .W },

        text = "Grants big bonus when spells\na word in the alien language"
    },

    .W = {
        tilesetPos = {3, 1},
        basePoints = 15,

        subtypes = { .A },

        text = "Grants big bonus when spells\na word in the alien language"
    },
}

STARTING_SYMBOLS := #partial #sparse [SymbolType]int {
    .Cherry = 5,
    .Star = 5,
    .Coffee = 5,
    .Ribbon = 5,
}

ITEMS := [ItemType]Item {
    .None = {},

    .FakeJorb = {
        name = "Fake Jorb",
        desc = "Grants one more spin per round.\n\nThe real one spins.\nBut, as a certain company, \nwe don't have the tech for that",
        tilesetPos = {0, 0},

        price = 10,
    },

    .PhaseCoffee = {
        name = "Phase Coffe",
        desc = "Gives bonus points for coffee symbols\nAvailble now at... you know the drill",
        tilesetPos = {1, 0},

        affectedSymbols = { .Coffee },
        baseBonus = 10,

        price = 10,
    },

    .TwoCoinMachine = {
        name = "Two Coin Machine",
        tilesetPos = {2, 0},
        desc = "Gives bonus points for Cherry symbols\n\nJerry!",

        affectedSymbols = { .Cherry },
        baseBonus = 10,

        price = 10,
    },

    .Luminary = {
        name = "Luminary",
        tilesetPos = {3, 0},
        desc = "Gives bonus points for Star symbols\n\nI love this song",

        affectedSymbols = { .Star },
        baseBonus = 10,

        price = 10,
    },

    .RingPop = {
        name = "Ring Pop",
        tilesetPos = {0, 1},
        desc = "Gives bonus points for Ribbon symbols\n\nApparently it's a diamond ring but no one believes that",

        affectedSymbols = { .Ribbon },
        baseBonus = 10,

        price = 10,
    },

    .AlienDictionary = {
        name = "Alien Dictionary",
        tilesetPos = {1, 1},
        desc = "Gives additional multiplier for AWA bonuses\n\nIt's full of just two letters...",

        affectedSymbols = { .A },
        // baseBonus = 10,
        multiplierBonus = 2,

        price = 10,
    },
}