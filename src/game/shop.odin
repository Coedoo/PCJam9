package game

import "core:fmt"
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
    items: [SHOP_ITEMS_COUNT]ShopSymbol,
}

InitShop :: proc(shop: ^Shop) {
    for &item in shop.items {
        idx := rand.int_max(len(SHOP_SYMBOLS))
        item = SHOP_SYMBOLS[idx]
    }
}

ShowShop :: proc(shop: ^Shop) {
    if dm.UIContainer("SHOOOP", .MiddleCenter) {
        if dm.Panel("Shop") {
            dm.UILabel("shop dot phase dash connect dot com")
            dm.BeginLayout("shoplayout")
            for &item, i in shop.items {
                if item.bought {
                    continue
                }

                dm.PushId(i)
                if dm.Panel("Item") {
                    dm.UILabel(item.symbol)


                    symbol := SYMBOLS[item.symbol]
                    sprite := dm.GetSprite(gameState.symbolsAtlas, symbol.tilesetPos)

                    rect := dm.RectInt{
                        sprite.texturePos.x, sprite.texturePos.y, 
                        sprite.textureSize.x, sprite.textureSize.y
                    }

                    dm.UIImage(gameState.symbolsAtlas.texture, source = rect)
                    dm.UILabel("Price:", item.price)
                    if dm.UIButton("Buy") {
                        if RemoveMoney(item.price) {
                            item.bought = true

                            switch item.acquisitionType {
                            case .OneReel: {
                                idx := rand.int_max(REELS_COUNT)
                                AddSymbolToReel(&gameState.reels[idx], item.symbol)
                            }
                            case .RandomReels: {
                                panic("TODO")
                            }
                            case .AllReels: {
                                for &reel in gameState.reels {
                                    AddSymbolToReel(&reel, item.symbol)
                                }
                            }

                            }
                        }
                    }
                }
                dm.PopId()
            }

            dm.EndLayout()

            if dm.UIButton("Exit") {
                gameState.state = .Ready
            }
        }
    }
}