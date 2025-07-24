package game

import dm "../dmcore"
import "core:math"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:fmt"
import "core:slice"
import "core:mem"

MenuStage :: enum {
    Main,
    LevelSelect,
    Settings,
    Tutorial,
    Credits,
}

MenuUpdate :: proc() {
    style := dm.uiCtx.textStyle
    style.fontSize = 110
    style.textColor = {0, 0, 0, 1}

    dm.NextNodeStyle(style)
    dm.NextNodePosition({60, 100}, origin = {0, 0.5})
    dm.UILabel("Summer\nSlots Adventure")

    style = dm.uiCtx.panelStyle
    style.bgColor = {0, 0, 0, 0.9}

    dm.NextNodeStyle(style)
    dm.NextNodePosition({70, 300}, origin = {0, 0})
    if dm.Panel("Menu", aligment = dm.Aligment{.Middle, .Left}) {

        style = dm.uiCtx.buttonStyle
        style.fontSize = 50
        style.bgColor     = {0, 0, 0, 0.6}
        style.activeColor = {0, 0.05, 0.5, 0.7}
        style.hotColor    = {0, 0, 0.3, 0.7}
        dm.PushStyle(style)

        switch gameState.menuStage {
        case .Main:

            if dm.UIButton("Play")     do BeginGameplay()
            // if dm.UIButton("Tutorial") do gameState.menuStage = .Tutorial
            // if dm.UIButton("Settings") do gameState.menuStage = .Settings
            if dm.UIButton("Credits")  do gameState.menuStage = .Credits

            // dm.UISpacer(20)
            // if dm.UIButton("Quit") {}

        case .LevelSelect:
            // for level in gameState.levels {
            //     if dm.UIButton(level.name) {
            //         OpenLevel(level.name)
            //         gameState.stage = .Gameplay
            //     }
            // }

            dm.UISpacer(20)
            if dm.UIButton("Back") do gameState.menuStage = .Main

        case .Tutorial:
            dm.UILabel("TUTORIAL")
            dm.UISpacer(10)

            dm.UILabel("It's literally Balatro")

            dm.UISpacer(20)
            if dm.UIButton("Back") do gameState.menuStage = .Main

        case .Settings:
            @static test: f32
            // dm.UISlider("Main Audio", &gameState.masterVolume, 0, 1)
            // dm.UISlider("Sounds",     &gameState.sfxVolume,    0, 1)

            // if dm.UISlider("Music", &gameState.musicVolume, 0, 1) {
            //     // dm.SetVolume(gameState.luminary, gameState.musicVolume)
            // }

            dm.UISpacer(20)
            if dm.UIButton("Back") do gameState.menuStage = .Main

        case .Credits:
            dm.UILabel("Programming and Pixel art: Coedo")
            dm.UILabel("Characters art: Peppy")
            dm.UILabel("Menu art: Kairo")

            dm.UISpacer(20)
            if dm.UIButton("Back") do gameState.menuStage = .Main
        }
        dm.PopStyle()
    }
}

MenuRender :: proc() {
    camSize := dm.GetCameraSize(dm.renderCtx.camera) + 1

    mouseOffset := dm.ToV2(dm.input.mousePos) / dm.ToV2(dm.renderCtx.frameSize)

    dm.DrawRect(dm.GetTextureAsset("jellycover.png"), {0,0}, size = camSize, shader = dm.renderCtx.defaultShaders[.Rect])
    // dm.DrawRect(dm.GetTextureAsset("menu/BackgroundBullet1.png"), mouseOffset * 0.2, size = camSize)
    // dm.DrawRect(dm.GetTextureAsset("menu/Crossfire.png"),         mouseOffset * 0.3, size = camSize)
    // dm.DrawRect(dm.GetTextureAsset("menu/Tower1.png"),            mouseOffset * 0.4, size = camSize)
    // dm.DrawRect(dm.GetTextureAsset("menu/Tower2.png"),            mouseOffset * 0.5, size = camSize)
    // dm.DrawRect(dm.GetTextureAsset("menu/JellyShip.png"),         mouseOffset * 0.8, size = camSize)
}