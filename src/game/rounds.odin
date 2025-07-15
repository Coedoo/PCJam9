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
}

ROUNDS := []Round {
    {},

    {
        goal = 800,
    },
    {
        goal = 2000
    }
}

BeginNextRound :: proc() {
    gameState.roundIdx += 1

    gameState.spins = SPINS_PER_ROUND
    gameState.allPoints = 0

    gameState.state = .Shop
    InitShop(&gameState.shop)
}