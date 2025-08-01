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
        goal = 1000,
    },
    {
        goal = 1200,
        cutsceneIdx = 2,
    },
    {
        goal = 1400,
    },

    {
        goal = 1600,
        cutsceneIdx = 3,
    },

    {
        goal = 1800,
    },

    {
        goal = 2000,
        cutsceneIdx = 4,
    },

    {
        goal = 2200,
        cutsceneIdx = 5,
    },
    // Endless round
    {
        goal = 0
    }
}

// RoundResult :: struct {
//     poin
//     money:int
// }

BeginNextRound :: proc() {
    assert(len(ROUNDS) >= 2)

    if gameState.roundIdx < len(ROUNDS) - 1 {
        gameState.roundIdx += 1
    }

    if gameState.roundIdx == len(ROUNDS) - 1 {
        gameState.endlessRoundNumber += 1

        prevGoal := ROUNDS[len(ROUNDS) - 2].goal
        ROUNDS[len(ROUNDS) - 1].goal = prevGoal * int(math.pow(1.5, f32(gameState.endlessRoundNumber)))
    }

    if ROUNDS[gameState.roundIdx].cutsceneIdx != 0 && 
        SKIP_CUTSCENES == false
    {
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