package game

import dm "../dmcore"
import "core:math"
import "core:fmt"

// SequenceTermination :: enum {
//     Manual,
//     Input,
//     Timeout,
// }

SequenceStep :: union {
    SequenceStepCharMovement,
    SequenceStepDialog,
    SequenceStepCharPos,
    SequenceStepCamera,
    SequenceStepPause,
}

SequenceStepDialog :: struct {
    text: string,
    characterPortrait: string,
    charTex: dm.TexHandle,
}

SequenceStepCharMovement :: struct {
    duration: f32,
    moves: []CharacterMove,
}

SequenceStepCharPos :: struct {
    char: Character,
    pos: v2,
    dir: v2,
}

SequenceStepCamera :: struct {
    size: f32,

    duration: f32,
    posFrom: v2,
    posTo: v2,
}

SequenceStepPause :: struct {
    duration: f32,
}

Character :: enum {
    Jelly,
    Ember,
    Dizzy,
    Lumi,
    Momonga,
}

CharacterState :: struct {
    sprite: dm.Sprite,
    pos: v2,
}

CharacterMove :: struct {
    char: Character,
    from, to: v2,
}

Cutscene :: struct {
    currentIdx: int,
    stepTime: f32,
    steps: []SequenceStep,
}

CharacterData: [Character]CharacterState

InitCharacters :: proc() {
    CharacterData[.Jelly].sprite = dm.CreateSprite(
        dm.GetTextureAsset("Jelly_anim.png"),
        dm.RectInt{0, 0, 32, 32},
        frames = 4,
    )
}

NextStep :: proc(seq: ^Cutscene) {
    seq.currentIdx += 1
    seq.stepTime = 0

    if seq.currentIdx >= len(seq.steps) {
        gameState.stage = .Gameplay
        dm.renderCtx.camera.orthoSize = 5
    }
}

GetAnimRow :: proc(dir: v2) -> (animRow: i32, flipX: bool) {
    if abs(dir.x) > abs(dir.y) {
        animRow = 2
        flipX = dir.x > 0
    }
    else {
        animRow = dir.y > 0 ? 1 : 0
    }

    return 
}

UpdateCutscene :: proc(seq: ^Cutscene) {
    if seq.currentIdx >= len(seq.steps) {
        return
    }

    step := &seq.steps[seq.currentIdx]
    seq.stepTime += dm.time.deltaTime

    switch s in step {
        case SequenceStepDialog: {
            if dm.GetMouseButton(.Left) == .JustPressed {
                NextStep(seq)
            }
        }

        case SequenceStepCharPos: {
            char := &CharacterData[s.char]
            char.pos = s.pos

            animRow, flipX := GetAnimRow(s.dir)
            char.sprite.texturePos.y = animRow * char.sprite.textureSize.y
            char.sprite.flipX = flipX

            char.sprite.currentFrame = 0

            NextStep(seq)
        }

        case SequenceStepCharMovement: {
            p := seq.stepTime / s.duration if s.duration >= 0 else 1
            for move in s.moves {
                char := &CharacterData[move.char]

                delta := move.to - move.from
                
                animRow, flipX := GetAnimRow(delta)

                char.sprite.texturePos.y = animRow * char.sprite.textureSize.y
                char.sprite.flipX = flipX
                char.pos = math.lerp(move.from, move.to, p)
                dm.AnimateSprite(&char.sprite, seq.stepTime, 0.1)
            }

            if seq.stepTime >= s.duration {
                NextStep(seq)
            }
        }

        case SequenceStepCamera: {
            p := seq.stepTime / s.duration if s.duration >= 0 else 1
            
            dm.renderCtx.camera.orthoSize = s.size
            if s.posFrom != s.posTo {
                pos := math.lerp(s.posFrom, s.posTo, p)
                dm.renderCtx.camera.position = { pos.x, pos.y, 1 }
            }

            if seq.stepTime >= s.duration {
                NextStep(seq)
            }
        }

        case SequenceStepPause: {
            if seq.stepTime >= s.duration {
                NextStep(seq)
            }
        }
    }

    // Debug
    if(dm.GetKeyState(.R) == .JustPressed) {
        seq.currentIdx = 0
    }

    if(dm.GetKeyState(.Num1) == .JustPressed) {
        seq.currentIdx = max(seq.currentIdx - 1, 0)
        seq.stepTime = 0
    }


    if(dm.GetKeyState(.Num2) == .JustPressed) {
        NextStep(seq)
    }
}

DrawCutscene :: proc(seq: ^Cutscene) {
    if seq.currentIdx >= len(seq.steps) {
        return
    }

    step := &seq.steps[seq.currentIdx]

    enviroSprite := dm.CreateSprite(dm.GetTextureAsset("enviro.png"))
    enviroSprite.scale = 160.0/32
    dm.DrawSprite(enviroSprite, v2{0, 0})

    for c in CharacterData {
        dm.DrawSprite(c.sprite, c.pos)
    }

    // fmt.println(CharacterData[.Jelly])

    #partial switch s in step {
        case SequenceStepDialog: {
            screenSize := dm.ToV2(dm.renderCtx.frameSize)

            panelHeight: f32 = 250
            layout := dm.uiCtx.panelLayout
            layout.preferredSize = {
                .X = {.Fixed, screenSize.x - 20, 1},
                .Y = {.Fixed, panelHeight - 20, 1},
            }

            style := dm.uiCtx.panelStyle
            style.fontSize = 40
            style.bgColor = {0.2, 0.2, 0.2, 0.8}

            dm.NextNodeLayout(layout)
            dm.PushStyle(style)
            dm.NextNodePosition({screenSize.x / 2, screenSize.y - panelHeight / 2})
            if dm.Panel("Dialog", dm.Aligment{.Middle, .Middle}) {
                dm.UILabel(s.text)
            }
            dm.PopStyle()

            if s.characterPortrait != {} {
                dm.BeginScreenSpace()
                tex := dm.GetTextureAsset(s.characterPortrait)
                dm.DrawRectPos(tex, {950, 700}, origin = v2{0.5, 1})

                dm.EndScreenSpace()
            }
        }

        case SequenceStepCharMovement: {
            // spriteName := "Jelly_anim.png"
            // atlas := dm.SpriteAtlas {
            //     texture = dm.GetTextureAsset(spriteName),
            //     cellSize = {32, 32},
            // }

            // p := seq.stepTime / s.duration
            // for m in s.moves {
            //     delta := m.to - m.from
                
            //     animRow: i32
            //     flipX: bool
            //     if abs(delta.x) > abs(delta.y) {
            //         animRow = 2
            //         flipX = delta.x > 0
            //     }
            //     else {
            //         animRow = delta.y > 0 ? 1 : 0
            //     }

            //     sprite := dm.GetSprite(atlas, {0, animRow})
            //     sprite.frames = 4
            //     sprite.animDirection = .Horizontal
            //     sprite.flipX = flipX
            //     dm.AnimateSprite(&sprite, seq.stepTime, 0.1)

            //     pos := math.lerp(m.from, m.to, p)
            //     dm.DrawSprite(sprite, pos)
            // }
        }
    }
}

Cutscenes := []Cutscene{
    {},

    // First Scene
    {
        steps = {
            SequenceStepCamera {size = 1.75},
            SequenceStepCharPos{.Jelly , {-3, -0.5}, {0, 1}},
            // SequenceStepDialog{
            //     text = "Lorem ipsum or something", 
            //     characterPortrait = "jelly_curious.png"
            // },
            SequenceStepCharMovement {
                duration = 2.5,
                moves = {
                    {.Jelly, {-3, -0.5}, {0, -0.5}},
                }
            },
            SequenceStepCharPos{.Jelly , {0, -0.5}, {0, -1}},
            SequenceStepDialog{
                text = "Hawk Tuah!", 
                characterPortrait = "jelly_curious.png"
            },
            SequenceStepDialog{
                text = ":D", 
                characterPortrait = "jelly_happy.png"
            },
            SequenceStepPause{1},
            SequenceStepCharMovement {
                duration = 2.5,
                moves = {
                    {.Jelly, {0, -0.5}, {-3, -0.5}},
                }
            },
            SequenceStepPause{1},


            SequenceStepDialog{ text = "YAY"},
        },
    },
}
