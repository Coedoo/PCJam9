package game

import "core:fmt"
import "core:slice"
import "core:math/rand"

import dm "../dmcore"

SHOP_ITEMS_COUNT :: 3

AcquisitionType :: enum {
    OneReel,
    RandomReels,
    AllReels
}

ShopSymbol :: struct {
    symbol: SymbolType,
    price: int,
    bought: bool,
    acquisitionType: AcquisitionType,
}

SHOP_SYMBOLS := []ShopSymbol{ 
    {
        symbol = .SpecialCherry,
        price = 15,
    },

    {
        symbol = .Pipe,
        price = 15,
    },

    {
        symbol = .A,
        price = 15,
    },

    {
        symbol = .W,
        price = 15,
    },
}

Shop :: struct {
    symbols: [SHOP_ITEMS_COUNT]ShopSymbol,

    itemsCount: int,
    items: [5]ItemType
}

InitShop :: proc(shop: ^Shop) {
    for &symbol in shop.symbols {
        idx := rand.int_max(len(SHOP_SYMBOLS))
        symbol = SHOP_SYMBOLS[idx]
    }

    shop.itemsCount = 2
    allItems: [len(ItemType)]ItemType
    for i in 0..<len(allItems) {
        allItems[i] = cast(ItemType) i
    }

    rand.shuffle(allItems[:])

    idx := 0
    for i in 0..<shop.itemsCount {
        shop.items[i] = allItems[i]
    }
}

ShowShop :: proc(shop: ^Shop) {

    dm.DrawRect(dm.GetTextureAsset("panel_shop.png"), {0, 0}, size = v2{7, 6})

    style := dm.uiCtx.textStyle
    style.font = cast(dm.FontHandle) dm.GetAsset("Kenney Mini Square.ttf")
    style.fontSize = 30

    if dm.UIContainer("SHOOOP", .TopCenter, {0, 190}, layoutAxis = .Y, alignment = dm.Aligment{.Top, .Middle}) {
        // if dm.Panel("Shop") {

            dm.NextNodeStyle(style)
            dm.UILabel("shop dot phase dash connect dot com")
            
            dm.BeginLayout("shoplayout", axis = .X)
            for &item, i in shop.symbols {
                if item.bought {
                    continue
                }

                dm.PushId(i)
                if dm.Panel("Item") {
                    dm.NextNodeStyle(style)
                    dm.UILabel(item.symbol)

                    symbol := SYMBOLS[item.symbol]
                    rect := dm.GetSpriteRect(gameState.symbolsAtlas, symbol.tilesetPos)

                    imageNode := dm.UIImage(gameState.symbolsAtlas.texture, source = rect, size = 64)
                    dm.NextNodeStyle(style)
                    dm.UILabel("Price:", item.price)
                    if dm.UIButton("Buy") {
                        if RemoveMoney(item.price) {
                            item.bought = true

                            switch item.acquisitionType {
                            case .OneReel:
                                idx := rand.int_max(REELS_COUNT)
                                AddSymbolToReel(&gameState.reels[idx], item.symbol)

                            case .RandomReels:
                                panic("TODO")

                            case .AllReels:
                                for &reel in gameState.reels {
                                    AddSymbolToReel(&reel, item.symbol)
                                }

                            }
                        }
                    }

                    inter := dm.GetNodeInteraction(imageNode)
                    if inter.hovered {
                        SymbolTooltip(item.symbol)
                    }
                }
                dm.PopId()
            }

            dm.EndLayout()

            dm.BeginLayout("ItemsLayout", axis = .X)
            for i in 0..<shop.itemsCount {
                if gameState.itemsData[shop.items[i]].isBought {
                    continue
                }

                dm.PushId(i)
                if dm.Panel("Itemmm") {
                    item := ITEMS[shop.items[i]]

                    dm.NextNodeStyle(style)
                    dm.UILabel(item.name)

                    rect := dm.GetSpriteRect(gameState.itemsAtlas, item.tilesetPos)
                    imageNode := dm.UIImage(gameState.itemsAtlas.texture, source = rect, size = 64)

                    dm.UILabel("Price:", item.price)

                    if dm.UIButton("Buy") {
                        if RemoveMoney(item.price) {
                            gameState.itemsData[shop.items[i]].isBought = true
                        }
                    }

                    if dm.GetNodeInteraction(imageNode).hovered {
                        ItemTooltip(shop.items[i])
                    }
                }
                dm.PopId()
            }
            dm.EndLayout()


            if dm.UIButton("Exit") {
                gameState.state = .Ready
            }
        // }
    }
}