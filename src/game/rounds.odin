package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:mem"

Round :: struct {
    goal: int,
    cutsceneIdx: int,
}

ROUNDS := []Round {
    {},

    {
        goal = 800,
        cutsceneIdx = 1,
    },
    {
        goal = 1200
    },
    {
        goal = 1600
    }
}

BeginNextRound :: proc() {
    if gameState.roundIdx < len(ROUNDS) - 1 {
        gameState.roundIdx += 1
    }
    else {
        ROUNDS[gameState.roundIdx].goal *= 2
    }

    if ROUNDS[gameState.roundIdx].cutsceneIdx != 0 && SKIP_CUTSCENES == false {
        gameState.stage = .Cutscene
        gameState.cutsceneIdx = ROUNDS[gameState.roundIdx].cutsceneIdx
    }
    else {
        gameState.stage = .Gameplay
    }

    gameState.spins = SPINS_PER_ROUND
    gameState.allPoints = 0

    if HasItem(.FakeJorb) {
        gameState.spins += 1
    }

    gameState.state = .Shop
    InitShop(&gameState.shop)
}