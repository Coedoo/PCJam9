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
    side: Side,
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
    Momonga,
    Jelly,
    Ember,
    Dizzy,
    Lumi,
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
    characters: bit_set[Character],
    steps: []SequenceStep,
}

Side :: enum {
    Left,
    Right,
}

CharacterData: [Character]CharacterState

InitCharacters :: proc() {
    CharacterData[.Jelly].sprite = dm.CreateSprite(
        dm.GetTextureAsset("Jelly_anim.png"),
        dm.RectInt{0, 0, 32, 32},
        frames = 4,
    )

    CharacterData[.Ember].sprite = dm.CreateSprite(
        dm.GetTextureAsset("Ember_anim.png"),
        dm.RectInt{0, 0, 32, 32},
        frames = 4,
    )

    CharacterData[.Dizzy].sprite = dm.CreateSprite(
        dm.GetTextureAsset("Dizzy_anim.png"),
        dm.RectInt{0, 0, 32, 32},
        frames = 4,
    )

    CharacterData[.Lumi].sprite = dm.CreateSprite(
        dm.GetTextureAsset("Lumi_anim.png"),
        dm.RectInt{0, 0, 32, 32},
        frames = 4,
    )

    CharacterData[.Momonga].sprite = dm.CreateSprite(
        dm.GetTextureAsset("momonga.png"),
        dm.RectInt{0, 0, 33, 33},
        frames = 0,
    )
    CharacterData[.Momonga].sprite.scale = 0.5
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

            if s.char != .Momonga {
                animRow, flipX := GetAnimRow(s.dir)
                char.sprite.texturePos.y = animRow * char.sprite.textureSize.y
                char.sprite.flipX = flipX

                char.sprite.currentFrame = 0
            }

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
                for move in s.moves {
                    char := &CharacterData[move.char]
                    char.sprite.currentFrame = 0
                }

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
    // if(dm.GetKeyState(.R) == .JustPressed) {
    //     seq.currentIdx = 0
    //     seq.stepTime = 0
    // }

    // // if(dm.GetKeyState(.Num1) == .JustPressed) {
    // //     seq.currentIdx = max(seq.currentIdx - 1, 0)
    // //     seq.stepTime = 0
    // // }


    // if(dm.GetKeyState(.Num2) == .JustPressed) {
    //     NextStep(seq)
    // }
}

DrawCutscene :: proc(seq: ^Cutscene) {
    if seq.currentIdx >= len(seq.steps) {
        return
    }

    step := &seq.steps[seq.currentIdx]

    enviroSprite := dm.CreateSprite(dm.GetTextureAsset("enviro.png"))
    enviroSprite.scale = f32(enviroSprite.textureSize.x)/32
    dm.DrawSprite(enviroSprite, v2{0, 0})

    for c, type in CharacterData {
        if type in seq.characters {
            dm.DrawSprite(c.sprite, c.pos)
        }
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

                x :f32= s.side == .Right ? 1000 : 300
                dm.DrawRectPos(tex, {x, 660}, origin = v2{0.5, 1})

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

    // dm.DrawGrid()
}

Cutscenes := []Cutscene{
    {},

    // First Scene
    {
        characters = { .Jelly, .Momonga },
        steps = {
            SequenceStepCamera {size = 2.2},
            // SequenceStepCharPos{.Jelly, {-4}}
            SequenceStepCharPos{.Momonga, {-1, -0.05}, {0, 1}},
            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Jelly, {-4, -0.5}, {-2, -0.5}}
                }
            },
            SequenceStepDialog{
                text = "Phew, finally got to the festival.\nLet's see what attractions are here", 
                characterPortrait = "jelly_curious.png"
            },
            SequenceStepCharMovement{
                duration = 1,
                moves = {
                    {.Jelly, {-2, -0.5}, {-1, -0.5}}
                }
            },
            SequenceStepCharMovement{
                duration = 0.5,
                moves = {
                    {.Jelly, {-1, -0.5}, {-1, -1}}
                }
            },

            SequenceStepDialog{
                text = "Air gun shooting, goldfish scooping...", 
                characterPortrait = "jelly_curious.png"
            },
            SequenceStepCharMovement{
                duration = 0.5,
                moves = {
                    {.Jelly, {-1, -1}, {-1, -0.5}}
                }
            },
            SequenceStepDialog{
                text = "MOMONGA", 
                characterPortrait = "jelly_happy.png",
                side = .Right,
            },

            SequenceStepCharMovement{
                duration = 0.5,
                moves = {
                    {.Jelly, {-1, -0.5}, {-1.5, -0.5}}
                }
            },
            SequenceStepCharPos{.Jelly, {-1.5, -0.5}, {0, 1}},

            SequenceStepDialog{
                text = "\"All the items are bought with tickets won on the festival stalls\".\nThat's an unusal one. But I need the plushie.", 
                characterPortrait = "jelly_curious.png",
                side = .Right,
            },

            SequenceStepCharMovement{
                duration = 0.5,
                moves = {
                    {.Jelly, {-1.5, -0.5}, {-1.5, -1}}
                }
            },
            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Jelly, {-1.5, -1}, {1, -1}}
                }
            },
            SequenceStepCharMovement{
                duration = 0.5,
                moves = {
                    {.Jelly, {1, -1}, {1, -0.5}}
                }
            },

            SequenceStepDialog{
                text = "A slot machine?", 
                characterPortrait = "jelly_wow.png"
            },
            SequenceStepDialog{
                text = "That's another unusual one.\nBut you can win the tickes...\nWell, let's try it", 
                characterPortrait = "jelly_happy.png"
            },
        },
    },


    // Scond Scene
    {
        characters = { .Jelly, .Ember },
        steps = {
            SequenceStepCamera {size = 2.2},
            SequenceStepCharPos{.Jelly, {1, -0.5}, {0, 1}},
            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Ember, {4, -0.5}, {2, -0.5}}
                }
            },
            SequenceStepCharPos{.Jelly, {1, -0.5}, {1, 0}},

            SequenceStepDialog{
                text = "Oh hi Ember", 
                characterPortrait = "jelly_smile.png"
            },
            SequenceStepDialog{
                text = "Hey Jelly! Have you seen the ticket shop?", 
                characterPortrait = "ember_smile.png"
            },
            SequenceStepDialog{
                text = "Yeah, I'm currently farming tickes for the Momonga plushie.", 
                characterPortrait = "jelly_happy.png"
            },
            SequenceStepDialog{
                text = "Cool, I wanted to win some too, but I'm getting distracted\nwith all the food stalls. They have GREAT Takoyaki over there,\nyou should check it out!", 
                characterPortrait = "ember_happy.png"
            },
            SequenceStepDialog{
                text = "Thanks, I try it later. If you want some stuff from the shop\nI can share my tickets with you", 
                characterPortrait = "jelly_curious.png"
            },

            SequenceStepDialog{
                text = "Really? But your plushie...", 
                characterPortrait = "ember_curious.png"
            },

            SequenceStepDialog{
                text = "It's ok, this game is really fun, so I can just farm more", 
                characterPortrait = "jelly_smile.png"
            },

            SequenceStepDialog{
                text = "Thank you so much!", 
                characterPortrait = "ember_happy.png"
            },

            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Ember, {2, -0.5}, {4, -0.5}}
                }
            },

            SequenceStepCharPos{.Jelly, {1, -0.5}, {0, 1}},
            SequenceStepDialog{
                text = "Ok, back to the mines", 
                characterPortrait = "jelly_curious.png"
            },
        },
    },


    // third Scene
    {
        characters = { .Jelly, .Dizzy },
        steps = {
            SequenceStepCamera {size = 2.2},
            SequenceStepCharPos{.Jelly, {1, -0.5}, {0, 1}},
            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Dizzy, {4, -0.5}, {2, -0.5}}
                }
            },
            SequenceStepCharPos{.Jelly, {1, -0.5}, {1, 0}},

            SequenceStepDialog{
                text = "Dizzy?! What happened?", 
                characterPortrait = "jelly_sad.png"
            },
            SequenceStepDialog{
                text = "Waah, I tripped and fell ony my face :<", 
                characterPortrait = "dizzy_cry.png"
            },
            SequenceStepDialog{
                text = "Did you get hurt?!", 
                characterPortrait = "jelly_curious.png"
            },

            SequenceStepCharPos{.Dizzy, {2, -0.5}, {0, 1}},
            SequenceStepDialog{
                text = "No... but, but... My tickets fell into the river ;_;", 
                characterPortrait = "dizzy_cry2.png"
            },
            SequenceStepCharPos{.Dizzy, {2, -0.5}, {-1, 0}},
            SequenceStepDialog{
                text = "That must have beer quite a scene...", 
                characterPortrait = "jelly_sad.png"
            },

            SequenceStepDialog{
                text = "Now I can't buy that special, summer edition coffee :(", 
                characterPortrait = "dizzy_neutral.png"
            },
            
            SequenceStepCharPos{.Dizzy, {2, -0.5}, {0, -1}},
            SequenceStepDialog{
                text = "Dizzy Dizzy Coffe Coffee Time!", 
                characterPortrait = "dizzy_happy.png"
            },
            SequenceStepCharPos{.Dizzy, {2, -0.5}, {-1, 0}},

            SequenceStepDialog{
                text = ":<", 
                characterPortrait = "dizzy_neutral.png"
            },

            SequenceStepDialog{
                text = "It's ok, you can have those", 
                characterPortrait = "jelly_smile.png"
            },
            
            SequenceStepDialog{
                text = "REALLY? :>", 
                characterPortrait = "dizzy_happy.png"
            },

            SequenceStepDialog{
                text = "Yeah, I will just get more, it's not that hard", 
                characterPortrait = "jelly_smile.png"
            },

            SequenceStepDialog{
                text = "THANK YOU \\o/ I will repay you somehow", 
                characterPortrait = "dizzy_cry3.png"
            },

            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Dizzy, {2, -0.5}, {4, -0.5}}
                }
            },

            SequenceStepCharPos{.Jelly, {1, -0.5}, {0, 1}},
            SequenceStepPause{0.5},
        },
    },


    // 4th Scene
    {
        characters = { .Jelly, .Lumi },
        steps = {
            SequenceStepCamera {size = 2.2},
            SequenceStepCharPos{.Jelly, {1, -0.5}, {0, 1}},
            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Lumi, {4, -0.5}, {2, -0.5}}
                }
            },
            SequenceStepCharPos{.Jelly, {1, -0.5}, {1, 0}},

            SequenceStepDialog{
                text = "IF I GET HIM I WILL...", 
                characterPortrait = "lumi_angry.png"
            },
            SequenceStepDialog{
                text = "Lumi? You look like you had an argument with your viewers again", 
                characterPortrait = "jelly_curious.png"
            },
            SequenceStepDialog{
                text = "I did! But it's not about that. Someone stole my tickets!", 
                characterPortrait = "lumi_angry2.png"
            },
            SequenceStepDialog{
                text = "What? Aren't you the thief here?", 
                characterPortrait = "jelly_sad.png"
            },
            SequenceStepDialog{
                text = "Yes, but that's not the point!", 
                characterPortrait = "lumi_angry.png"
            },

            SequenceStepDialog{
                text = "Did you see who stole it?", 
                characterPortrait = "jelly_curious.png"
            },

            SequenceStepDialog{
                text = "Yeah, he was wearing an armor and had star shaped helmet.\nAnd he was yelling something in an language I don't understand.", 
                characterPortrait = "lumi_angry.png"
            },
            
            SequenceStepDialog{
                text = "Probably swears", 
                characterPortrait = "lumi_angry2.png"
            },

            SequenceStepDialog{
                text = "Whad da hell..?", 
                characterPortrait = "jelly_sad.png"
            },

            SequenceStepDialog{
                text = "Anyway, have these. You can give them back if you find the thief", 
                characterPortrait = "jelly_smile.png"
            },

            SequenceStepDialog{
                text = "Thanks, but what about you?", 
                characterPortrait = "lumi_curious.png"
            },

            SequenceStepDialog{
                text = "I'm sure I have enough time to get\neverything I want.\nI don't think I will meet any more people today", 
                characterPortrait = "jelly_happy.png"
            },

            SequenceStepDialog{
                text = "Are you sure? We have more Invaders now", 
                characterPortrait = "lumi_smile.png"
            },

            SequenceStepDialog{
                text = "Yes, but they are not in this game", 
                characterPortrait = "jelly_happy.png"
            },
            SequenceStepDialog{
                text = "OK, thanks wife", 
                characterPortrait = "lumi_happy.png"
            },

            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Lumi, {2, -0.5}, {4, -0.5}}
                }
            },

            SequenceStepCharPos{.Jelly, {1, -0.5}, {0, 1}},
            SequenceStepPause{0.5},
        },
    },


    // Final Scene
    {
        characters = ~{},
        steps = {
            SequenceStepCamera {size = 2.2},
            SequenceStepCharPos{.Jelly, {1.2, -0.5}, {0, 1}},
            SequenceStepCharPos{.Dizzy, {0, 10}, {0, 1}},
            SequenceStepCharPos{.Ember, {0, 10}, {0, 1}},
            SequenceStepCharPos{.Lumi,  {0, 10}, {0, 1}},
            SequenceStepCharPos{.Momonga, {-100, -0.05}, {0, 1}},

            SequenceStepDialog{
                text = "That should be enough", 
                characterPortrait = "jelly_curious.png"
            },
            SequenceStepCharMovement{
                duration = 0.5,
                moves = {
                    {.Jelly, {1.2, -0.5}, {1.2, -1}}
                }
            },
            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Jelly, {1.1, -1}, {-1, -1}}
                }
            },
            SequenceStepCharMovement{
                duration = 0.5,
                moves = {
                    {.Jelly, {-1, -1}, {-1, -0.5}}
                }
            },
            SequenceStepCharPos{.Jelly, {-1, -0.5}, {0, 1}},
            SequenceStepDialog{
                text = "The Momonga plushie plea...", 
                characterPortrait = "jelly_happy.png"
            },

            SequenceStepDialog{
                text = "Wait, it's closed already?", 
                characterPortrait = "jelly_sad.png"
            },

            SequenceStepDialog{
                text = "I played for too long?!", 
                characterPortrait = "jelly_cry.png"
            },

            SequenceStepDialog{
                text = "Waaah!", 
                characterPortrait = "jelly_cry.png"
            },

            SequenceStepCharMovement{
                duration = 2,
                moves = {
                    {.Ember, {-4.2, -0.4}, {-2.3, -0.4}},
                    {.Dizzy, {-4, -0.6}, {-2, -0.6}},
                    {.Lumi,  {-4.3, -0.8}, {-2.2, -0.8}},
                }
            },

            SequenceStepCharPos{.Jelly, {-1, -0.5}, {-1, 0}},

            SequenceStepDialog{
                text = "Huh?", 
                characterPortrait = "jelly_curious.png",
                side = .Right
            },

            SequenceStepDialog{
                text = "Hey Jelly, we got you this", 
                characterPortrait = "dizzy_smile.png",
                side = .Right
            },

            SequenceStepCharPos{.Momonga, {-1.5, -0.8}, {0, 1}},
            SequenceStepDialog{
                text = "Momonga!?", 
                characterPortrait = "jelly_happy.png",
                side = .Right
            },

            SequenceStepDialog{
                text = "Yeah, you gave us all those tickets\nand we were worried that you won't be able but buy the plushie",
                characterPortrait = "lumi_smile.png",
                side = .Right
            },

            SequenceStepDialog{
                text = "So we got to work and got all the tickets ourselfs!",
                characterPortrait = "ember_happy.png",
                side = .Right
            },

            SequenceStepDialog{
                text = "And it looks like it was a good idea!",
                characterPortrait = "dizzy_smile.png",
                side = .Right
            },

            SequenceStepDialog{
                text = "THANK YOU GUYS!", 
                characterPortrait = "jelly_cry.png",
                side = .Right
            },

            SequenceStepDialog{
                text = "The rounds are now played in endless mode", 
                characterPortrait = "",
                side = .Right
            },
        }
    }
}
