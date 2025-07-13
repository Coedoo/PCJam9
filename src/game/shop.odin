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

ShopItem :: struct {
    symbol: SymbolType,
    price: int,
    bought: bool,
    acquisitionType: AcquisitionType,
}

SHOP_ITEMS := []ShopItem{
    {
        symbol = .Cherry,
        price = 10,
    },
    {
        symbol = .Burger,
        price = 10,
    },
    {
        symbol = .Coffee,
        price = 10,
    },
    {
        symbol = .Lemon,
        price = 10,
    },

    {
        symbol = .SpecialCherry,
        price = 15,
    },

    {
        symbol = .Ribbon,
        price = 15,
    },
}

Shop :: struct {
    items: [SHOP_ITEMS_COUNT]ShopItem,
}

InitShop :: proc(shop: ^Shop) {
    for &item in shop.items {
        idx := rand.int_max(len(SHOP_ITEMS))
        item = SHOP_ITEMS[idx]
    }
}

ShowShop :: proc(shop: ^Shop) {
    if dm.Panel("Shop") {
        for &item, i in shop.items {
            if item.bought {
                continue
            }

            dm.PushId(i)
            if dm.Panel("Item") {
                dm.UILabel(item.symbol)
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
    }
}