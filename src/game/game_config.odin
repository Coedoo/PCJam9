package game

import "core:mem"

import dm "../dmcore"

BASIC_TILESET :: "symbols.png"

START_MONEY :: 1000

REELS_COUNT :: 5
REEL_SIZE :: 64

SYMBOLS := [SymbolType]Symbol {
    .None = {},

    .Cherry = {
        tilesetName = BASIC_TILESET,
        tilesetPos = {0, 0},
    },

    .Seven = {
        tilesetName = BASIC_TILESET,
        tilesetPos = {1, 0},
    },

    .Star = {
        tilesetName = BASIC_TILESET,
        tilesetPos = {2, 0},
    },

    .Lemon = {
        tilesetName = BASIC_TILESET,
        tilesetPos = {3, 0},
    },
}

STARTING_SYMBOLS := #partial #sparse [SymbolType]int {
    .Cherry = 5,
    .Seven  = 5,
    .Star   = 5,
    .Lemon  = 5,
}