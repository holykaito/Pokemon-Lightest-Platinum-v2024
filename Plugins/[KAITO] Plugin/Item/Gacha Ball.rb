#===============================================================================
# Random Poké Ball
# Pokémon Essentials v21.1
# Item ID: POKEBALL1
#===============================================================================

module LP_RandomPokeBall
ITEM_IDS = [
  :POKEBALL1,
  :GREATBALL1,
  :ULTRABALL1,
  :MASTERBALL1
]
  START_LEVEL = 5
  MAX_USES    = 20

# Tong moi bang = 10000
# Poke Ball   : N 54%, R 30%, SR 15%, SSR 1%,  UR 0%
# Great Ball  : N 30%, R 40%, SR 25%, SSR 4%,  UR 1%
# Ultra Ball  : N 15%, R 25%, SR 40%, SSR 15%, UR 5%
# Master Ball : SSR 70%, UR 30%
BALL_RARITY_RATES = {
  :POKEBALL1 => {
    :N   => 5000,
    :R   => 3000,
    :SR  => 1500,
    :SSR => 400,
    :UR  => 100
  },

  :GREATBALL1 => {
    :N   => 3000,
    :R   => 4000,
    :SR  => 2500,
    :SSR => 400,
    :UR  => 100
  },

  :ULTRABALL1 => {
    :N   => 1500,
    :R   => 2500,
    :SR  => 4000,
    :SSR => 1500,
    :UR  => 500
  },

  :MASTERBALL1 => {
    :SSR => 7000,
    :UR  => 3000
  }
}

REVEAL_BG_PATH  = "Graphics/UI/RandomPokeBall/reveal_bg"
SUMMARY_BG_PATH = "Graphics/UI/RandomPokeBall/summary_bg"

RARITY_DISPLAY_NAMES = {
  :N   => "Thường",
  :R   => "Hiếm",
  :SR  => "Rất hiếm",
  :SSR => "Huyền thoại",
  :UR  => "Tối thượng"
}

  # Thay danh sách này theo Rom Hack của bạn.
  # Mỗi loài chỉ cần ghi ID species trong PBS/pokemon.txt.
  RARITY_POOLS = {
    :N => [
      :PIDGEY, :RATTATA, :CATERPIE, :WEEDLE, :SPEAROW, :EKANS, :SANDSHREW, :ZUBAT, :NIDORANfE, :NIDORANmA,
      :ODDISH, :PARAS, :DIGLETT, :MEOWTH, [:MEOWTH, 1], [:MEOWTH, 2], :PSYDUCK, :MANKEY, :POLIWAG, :MACHOP, :BELLSPROUT, :TENTACOOL,
      :GEODUDE, [:GEODUDE, 1], :KRABBY, :VOLTORB, [:VOLTORB, 1], :GOLDEEN, :SHELLDER, :PICHU, :SEEL, :SLOWPOKE, [:SLOWPOKE, 1],
      :SENTRET, :HOOTHOOT, :LEDYBA, :SPINARAK, :MAREEP, :HOPPIP, :AZURILL, :SUNKERN, :WOOPER, [:WOOPER, 1], :PINECO,
      :REMORAID, :NATU, :SLUGMA, :SWINUB,
      :POOCHYENA, :ZIGZAGOON, [:ZIGZAGOON, 1], :WURMPLE, :LOTAD, :SEEDOT, :WINGULL, :TAILLOW, :WHISMUR, :ELECTRIKE,
      :NINCADA, :SWABLU, :BUDEW, :GULPIN, :SPOINK, :NUMEL, :BARBOACH, :CORPHISH, :BALTOY, :SHUPPET, :DUSKULL, :SPHEAL,
      :STARLY, :BIDOOF, :KRICKETOT, :SHINX, :BURMY, [:BURMY, 1], [:BURMY, 2], :COMBEE, :BUIZEL, :CHERUBI, :SHELLOS, [:SHELLOS, 1],
      :BUNEARY, :GLAMEOW, :STUNKY, :CROAGUNK, :FINNEON, :SNOVER,
      :PATRAT, :LILLIPUP, :PIDOVE, :BLITZLE, :ROGGENROLA, :PURRLOIN, :PANSAGE, :PANSEAR, :PANPOUR, :WOOBAT,
      :TIMBURR, :TYMPOLE, :SEWADDLE, :VENIPEDE, :COTTONEE, :PETILIL, :SANDILE, :DARUMAKA, [:DARUMAKA, 1], :DWEBBLE, :SCRAGGY,
      :TRUBBISH, :MINCCINO, :DUCKLETT, :VANILLITE, :DEERLING, [:DEERLING, 1], [:DEERLING, 2], [:DEERLING, 3], :KARRABLAST, :FOONGUS, :SHELMET, 
      :BUNNELBY, :FLETCHLING, :SCATTERBUG, :LITLEO, :FLABEBE, :SKIDDO, :PANCHAM, :HONEDGE, :SPRITZEE, :SWIRLIX,
      :INKAY, :BINACLE, :HELIOPTILE, :BERGMITE, :SKRELP, :CLAUNCHER, :BERGMITE,
      :PIKIPEK, :YUNGOOS, :GRUBBIN, :CRABRAWLER, :CUTIEFLY, :ROCKRUFF, :MUDBRAY, :FOMANTIS, :MORELULL,
      :BOUNSWEET, :SKWOVET, :ROOKIDEE, :BLIPBUG, :NICKIT, :GOSSIFLEUR, :WOOLOO, :YAMPER, :ROLYCOLY,
      :APPLIN, :ARROKUDA, :CLOBBOPUS, :SINISTEA, :MILCERY, :LECHONK, :PAWMI, :TAROUNTULA, :NYMBLE, :FIDOUGH, :SMOLIV,
      :NACLI, :TADBULB, :WATTREL, :MASCHIFF, :TOEDSCOOL, :BRAMBLIN, :RELLOR, :WIGLETT
    ],

    :R => [
      :CLEFFA, :VULPIX, :IGGLYBUFF, :VENONAT, :ABRA, :GROWLITHE, [:GROWLITHE, 1], :PONYTA, [:PONYTA, 1], :MAGNEMITE, :DODUO, :GRIMER, [:GRIMER, 1], :GASTLE,
      :EXEGGCUTE, :CUBONE, :KOFFING, :RHYHORN, :HORSEA, :TYROGUE, :FARFETCHD, [:FARFETCHD, 1], :LICKITUNG, :KOFFING,  :ONIX, :DROWZEE,
      :RHYHORN, :TANGELA, :STARYU, :MAGIKARP, :HORSEA,
      :CHINCHOU, :BONSLY, :AIPOM, :YANMA, :MURKROW, :MISDREAVUS, :WYNAUT, :DUNSPARCE,
      :GLIGAR, :SNUBBULL, :QWILFISH, [:QWILFISH, 1], :SHUCKLE, :SNEASEL, [:SNEASEL, 1], :TEDDIURSA, :CORSOLA, [:CORSOLA, 1], :DELIBIRD,
      :MANTYKE, :HOUNDOUR, :PHANPY, :STANTLER, :SMEARGLE,
      :SURSKIT, :SHROOMISH, :SLAKOTH, :MAKUHITA, :NOSEPASS, :SKITTY, :SABLEYE, :MAWILE, :ARON,
      :MEDITITE, :RALTS, :PLUSLE, :MINUN, :VOLBEAT, :ILLUMISE, :CARVANHA, :WAILMER, :CLAMPERL, :SPINDA,
      :TORKOAL, :TRAPINCH, :CACNEA, :ZANGOOSE, :SEVIPER, :LUNATONE, :SOLROCK,
      :CHINGLING, :SNORUNT, :LUVDISC, :PACHIRISU, :DRIFLOON, :BRONZOR, :CHATOT, :HIPPOPOTAS, :SKORUPI, :CARNIVINE,
      :MUNNA, :DRILBUR, :AUDINO, :BASCULIN, :MARACTUS, :SIGILYPH, :YAMASK, [:YAMASK, 1], :GOTHITA, :SOLOSIS,
      :EMOLGA, :FRILLISH,  :JOLTIK, :FERROSEED, :TYNAMO, :ELGYEM, :KLINK, :LITWICK, :CUBCHOO,
      :CRYOGONAL, :STUNFISK, [:STUNFISK, 1], :GOLETT, :PAWNIARD, :RUFFLET, :VULLABY,
      :FURFROU, :ESPURR, :DEDENNE, :CARBINK, :PHANTUMP, :PUMPKABOO, [:PUMPKABOO, 1], [:PUMPKABOO, 2], [:PUMPKABOO, 3], 
      :NOIBAT, :ORICORIO, [:ORICORIO, 1], [:ORICORIO, 2], [:ORICORIO, 3], :WISHIWASHI, :MAREANIE, :DEWPIDER, :SALANDIT, :STUFFUL, :COMFEY, :ORANGURU, :PASSIMIAN,
      :WIMPOD, :SANDYGAST, :BRUXISH, :CHEWTLE, :SILICOBRA, :CRAMORANT, :TOXEL, :SIZZLIPEDE, :HATENNA, :IMPIDIMP,
      :SNOM, :EISCUE, :CUFANT, :MORPEKO, :TANDEMAUS, :SQUAWKABILLY, :SHROODLE, :CAPSAKID, :FLITTLE,
      :TINKATINK, :VAROOM, :GREAVARD, :CETODDLE, :POLTCHAGEIST
      # :UNOWN, :

    ],

    :SR => [
      :BULBASAUR, :CHARMANDER, :SQUIRTLE, :EEVEE, :HAPPINY, :KANGASKHAN, :MIMEJR, :SCYTHER, :PINSIR, :TAUROS, [:TAUROS, 1], [:TAUROS, 2], [:TAUROS, 3],
      :SMOOCHUM, :ELEKID, :MAGBY, :DRATINI, :LAPRAS, :MUNCHLAX, :DITTO, :PORYGON, :OMANYTE, :KABUTO, :AERODACTYL,
      :CHIKORITA, :CYNDAQUIL, :TOTODILE, :TOGEPI, :HERACROSS, :MILTANK, :LARVITAR, :GIRAFARIG, :SKARMORY,
      :TREECKO, :TORCHIC, :MUDKIP, :LILEEP, :ANORITH, :FEEBAS, :CASTFORM, :ABSOL, :RELICANTH, :BAGON, :BELDUM,
      :TROPIUS, :KECLEON,
      :TURTWIG, :CHIMCHAR, :PIPLUP, :CRANIDOS, :SHIELDON, :SPIRITOMB, :GIBLE, :RIOLU, :ROTOM,
      :SNIVY, :TEPIG, :OSHAWOTT, :TIRTOUGA, :ARCHEN, :ZORUA, [:ZORUA, 1], :DEINO, :LARVESTA, :AXEW, :BOUFFALANT,
      :HEATMOR, :DURANT, :MIENFOO, :THROH, :SAWK, :DRUDDIGON, :ALOMOMOLA,
      :CHESPIN, :FENNEKIN, :FROAKIE, :AMAURA, :GOOMY, :HAWLUCHA, :KLEFKI,
      :ROWLET, :LITTEN, :POPPLIO, :TYPENULL, :MINIOR, :KOMALA, :TURTONATOR, :TOGEDEMARU, :MIMIKYU, :DRAMPA,
      :DHELMISE, :JANGMOO, :PYUKUMUKU,
      :GROOKEY, :SCORBUNNY, :SOBBLE, :FALINKS, :PINCURCHIN, :INDEEDEE, :DRACOZOLT, :ARCTOZOLT, :DRACOVISH, :ARCTOVISH,
      :DURALUDON, :DREEPY, :STONJOURNER, :FINIZEN, :VELUZA, :BOMBIRDIER, :FLAMIGO, :CYCLIZAR,
      :SPRIGATITO, :FUECOCO, :QUAXLY, :CHARCADET, :KLAWF, :ORTHWORM, :GLIMMET, :DONDOZO, :TATSUGIRI, :FRIGIBAX, :GIMMIGHOUL
    ],

    :SSR => [
      :ARTICUNO, :ZAPDOS, :MOLTRES, :RAIKOU, :ENTEI, :SUICUNE, :REGIROCK, :REGICE, :REGISTEEL, :LATIAS, :LATIOS,
      :DEOXYS, :UXIE, :MESPRIT, :AZELF, :HEATRAN, :CRESSELIA, :PHIONE, :DARKRAI, :SHAYMIN,
      :COBALION, :TERRAKION, :VIRIZION, :TORNADUS, :THUNDURUS, :LANDORUS, :KELDEO, :GENESECT, :MELOETTA,
      :DIANCIE, :HOOPA, :VOLCANION, :TAPUKOKO, :TAPULELE, :TAPUBULU, :TAPUFINI, :NIHILEGO, :BUZZWOLE, :PHEROMOSA,
      :XURKITREE, :CELESTEELA, :KARTANA, :GUZZLORD, :MAGEARNA, :MARSHADOW, :POIPOLE, :STAKATAKA, :BLACEPHALON,
      :ZERAORA, :MELTAN, :ZARUDE, :KUBFU, :REGIELEKI, :REGIDRAGO, :GLASTRIER, :SPECTRIER, :CALYREX,
      [:ARTICUNO, 1], [:ZAPDOS, 1], [:MOLTRES, 1], :ENAMORUS, :GREATTUSK, :SCREAMTAIL, :BRUTEBONNET, :FLUTTERMANE, 
      :SLITHERWING, :SANDYSHOCKS, :IRONTREAD, :IRONBUNDLE, :IRONMOTH, :IRONHAND, :IRONJUGULIS, :IRONTHORNS,
      :WOCHIEN, :CHIENPAO, :TINGLU, :CHIYU, :ROARINGMOON, :IRONVALIANT, :WALKINGWAKE, :IRONLEAVES, :OKIDOGI,
      :MUNKIDORI, :FEZANDIPITI, :OGERPON, :GOUGINGFIRE, :RAGINGBOLT, :IRONBOULDER, :IRONCROWN, :TERAPAGOS, :PECHARUNT,
      :MEW, :CELEBI, :JIRACHI, :MANAPHY, :VICTINI
    ],

    :UR => [
      :MEWTWO, :LUGIA, :HO_OH, :KYOGRE, :GROUDON, :RAYQUAZA, 
      :DIALGA, :PALKIA, :REGIGIGAS, :GIRATINA, :ARCEUS, :RESHIRAM, :ZEKROM, :KYUREM,
      :XERNEAS, :YVELTAL, :ZYGARDE, :SOLGALEO, :LUNALA, :NECROZMA, :ZACIAN, :ZAMAZENTA, :ETERNATUS,
      :KORAIDON, :MIRAIDON
    ]
  }

  RARITY_NAMES = {
    :N   => "N",
    :R   => "R",
    :SR  => "SR",
    :SSR => "SSR",
    :UR  => "UR"
  }

  RARITY_COLORS = {
    :N   => Color.new(161, 161, 161),
    :R   => Color.new(96, 176, 255),
    :SR  => Color.new(184, 96, 255),
    :SSR => Color.new(255, 184, 64),
    :UR  => Color.new(255, 72, 72)
  }

def self.pbDrawRevealRarityCircle(bitmap, cx, cy, rarity_color)
  # Vong mau rarity nam tren nen reveal_bg
  pbDrawSoftCircle(bitmap, cx, cy, 132, rarity_color, 90)
  pbDrawSoftCircle(bitmap, cx, cy, 104, rarity_color, 135)
  pbDrawSoftCircle(bitmap, cx, cy, 76,  rarity_color, 185)
  pbDrawSoftCircle(bitmap, cx, cy, 46,  Color.new(255, 255, 255), 75)
end

def self.pbAddImageBackground(sprites, key, viewport, path)
  if pbResolveBitmap(path)
    sprites[key] = IconSprite.new(0, 0, viewport)
    sprites[key].setBitmap(path)
  else
    sprites[key] = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
    sprites[key].bitmap.fill_rect(
      0, 0, Graphics.width, Graphics.height,
      Color.new(0, 0, 0)
    )
  end
  sprites[key].z = 0
  sprites[key].opacity = 255
end

def self.pbDrawCenteredMixedText(bitmap, y, left_text, color_text, right_text, color, base, shadow)
  full_text = left_text + color_text + right_text
  total_w = bitmap.text_size(full_text).width
  left_w  = bitmap.text_size(left_text).width
  color_w = bitmap.text_size(color_text).width
  x = (Graphics.width - total_w) / 2

  pbDrawTextPositions(
    bitmap,
    [
      [left_text, x, y, :left, base, shadow],
      [color_text, x + left_w, y, :left, color, shadow],
      [right_text, x + left_w + color_w, y, :left, base, shadow]
    ]
  )
end

def self.rarity_rates_for_item(item)
  return BALL_RARITY_RATES[item] || BALL_RARITY_RATES[:POKEBALL1]
end

def self.valid_rarities(item = :POKEBALL1)
  rates = rarity_rates_for_item(item)
  return rates.keys.select { |r| RARITY_POOLS[r] && RARITY_POOLS[r].length > 0 && rates[r] && rates[r] > 0 }
end

def self.roll_rarity(item = :POKEBALL1)
  rates = rarity_rates_for_item(item)
  rarities = valid_rarities(item)
  return nil if rarities.empty?

  total = 0
  rarities.each { |r| total += rates[r] }

  roll = rand(total)
  rarities.each do |rarity|
    roll -= rates[rarity]
    return rarity if roll < 0
  end

  return rarities.first
end

def self.roll_species(item = :POKEBALL1)
  rarity = roll_rarity(item)
  return [nil, nil] if !rarity
  species_data = RARITY_POOLS[rarity].sample
  return [rarity, species_data]
end

def self.create_pokemon(species_data)
  species = species_data
  form = 0

  if species_data.is_a?(Array)
    species = species_data[0]
    form = species_data[1] || 0
  end

  pkmn = Pokemon.new(species, START_LEVEL)
  pkmn.form = form if pkmn.respond_to?(:form=)
  pkmn.poke_ball = :POKEBALL if pkmn.respond_to?(:poke_ball=)
  pkmn.calc_stats
  return pkmn
end

def self.pbBlendColor(c1, c2, t)
  t = [[t, 0.0].max, 1.0].min
  r = (c1.red   + ((c2.red   - c1.red)   * t)).to_i
  g = (c1.green + ((c2.green - c1.green) * t)).to_i
  b = (c1.blue  + ((c2.blue  - c1.blue)  * t)).to_i
  return Color.new(r, g, b)
end

def self.pbDrawPixelStar(bitmap, x, y, color)
  bitmap.fill_rect(x, y, 2, 2, color)
  bitmap.fill_rect(x - 2, y, 2, 2, color)
  bitmap.fill_rect(x + 2, y, 2, 2, color)
  bitmap.fill_rect(x, y - 2, 2, 2, color)
  bitmap.fill_rect(x, y + 2, 2, 2, color)
end

def self.pbDrawPixelCircle(bitmap, cx, cy, radius, color, step = 8, size = 3)
  angle = 0
  while angle < 360
    rad = angle * Math::PI / 180.0
    x = cx + (Math.cos(rad) * radius).to_i
    y = cy + (Math.sin(rad) * radius).to_i
    bitmap.fill_rect(x - size / 2, y - size / 2, size, size, color)
    angle += step
  end
end

def self.pbDrawRewardBackground(bitmap, rarity = nil)
  w = bitmap.width
  h = bitmap.height

  top_color    = Color.new(40, 56, 96)
  mid_color    = Color.new(64, 104, 144)
  bottom_color = Color.new(32, 48, 80)

  accent = Color.new(96, 176, 255)
  accent = RARITY_COLORS[rarity] if rarity && RARITY_COLORS[rarity]

  # Pixel block background
  block = 8
  y = 0
  while y < h
    ratio = y.to_f / h
    base = (ratio < 0.55) ? pbBlendColor(top_color, mid_color, ratio / 0.55) :
                            pbBlendColor(mid_color, bottom_color, (ratio - 0.55) / 0.45)

    x = 0
    while x < w
      cx = w / 2
      cy = h / 2
      dist = Math.sqrt(((x - cx) * (x - cx)) + ((y - cy) * (y - cy)))
      glow = [1.0 - (dist / 270.0), 0.0].max

      noise = ((x * 13 + y * 7) % 18) - 9
      r = [[base.red   + noise + (accent.red   * glow * 0.18), 255].min, 0].max.to_i
      g = [[base.green + noise + (accent.green * glow * 0.18), 255].min, 0].max.to_i
      b = [[base.blue  + noise + (accent.blue  * glow * 0.18), 255].min, 0].max.to_i

      bitmap.fill_rect(x, y, block, block, Color.new(r, g, b))
      x += block
    end
    y += block
  end

  # Dark vignette edges
  10.times do |i|
    alpha = 12
    bitmap.fill_rect(i * 4, 0, 4, h, Color.new(0, 0, 0, alpha))
    bitmap.fill_rect(w - 4 - (i * 4), 0, 4, h, Color.new(0, 0, 0, alpha))
    bitmap.fill_rect(0, i * 4, w, 4, Color.new(0, 0, 0, alpha))
    bitmap.fill_rect(0, h - 4 - (i * 4), w, 4, Color.new(0, 0, 0, alpha))
  end

  # Simple pixel border
  border_dark  = Color.new(16, 24, 48)
  border_light = Color.new(168, 208, 248)

  bitmap.fill_rect(8, 8, w - 16, 4, border_light)
  bitmap.fill_rect(8, h - 12, w - 16, 4, border_light)
  bitmap.fill_rect(8, 8, 4, h - 16, border_light)
  bitmap.fill_rect(w - 12, 8, 4, h - 16, border_light)

  bitmap.fill_rect(16, 16, w - 32, 2, border_dark)
  bitmap.fill_rect(16, h - 18, w - 32, 2, border_dark)
  bitmap.fill_rect(16, 16, 2, h - 32, border_dark)
  bitmap.fill_rect(w - 18, 16, 2, h - 32, border_dark)

  # Pixel summoning platform
  platform_y = h - 86
  pbDrawPixelCircle(bitmap, w / 2, platform_y, 72, Color.new(accent.red, accent.green, accent.blue, 150), 6, 4)
  pbDrawPixelCircle(bitmap, w / 2, platform_y, 48, Color.new(232, 248, 255, 120), 8, 3)
  pbDrawPixelCircle(bitmap, w / 2, platform_y, 24, Color.new(accent.red, accent.green, accent.blue, 170), 10, 3)

  bitmap.fill_rect((w / 2) - 88, platform_y - 2, 176, 4, Color.new(accent.red, accent.green, accent.blue, 90))
  bitmap.fill_rect((w / 2) - 44, platform_y - 18, 88, 2, Color.new(232, 248, 255, 80))
  bitmap.fill_rect((w / 2) - 44, platform_y + 16, 88, 2, Color.new(232, 248, 255, 80))

  # Pixel sparkles
  32.times do |i|
    sx = 24 + ((i * 67) % (w - 48))
    sy = 24 + ((i * 43) % (h - 120))
    next if sx > (w / 2 - 70) && sx < (w / 2 + 70) && sy > 90 && sy < 230
    color = (i % 5 == 0) ? Color.new(accent.red, accent.green, accent.blue, 170) :
                            Color.new(220, 240, 255, 120)
    pbDrawPixelStar(bitmap, sx, sy, color)
  end
end

def self.pbRevealPokemon(pkmn, rarity)
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 999999
  sprites = {}

pbAddImageBackground(sprites, "bg", viewport, REVEAL_BG_PATH)
rarity_color = RARITY_COLORS[rarity] || Color.new(248, 248, 248)

sprites["rarity_circle"] = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
sprites["rarity_circle"].z = 2
pbDrawRevealRarityCircle(
  sprites["rarity_circle"].bitmap,
  Graphics.width / 2,
  186,
  rarity_color
)

  sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
  sprites["overlay"].z = 20
  pbSetSystemFont(sprites["overlay"].bitmap)
  overlay = sprites["overlay"].bitmap

  rarity_name  = RARITY_DISPLAY_NAMES[rarity] || RARITY_NAMES[rarity] || "?"
  species_name = GameData::Species.get(pkmn.species).name
  base         = Color.new(48, 48, 48)
  shadow       = Color.new(220, 220, 220)

  overlay.font.bold = false
  overlay.font.size = 24

  pbDrawCenteredMixedText(
    overlay,
    24,
    _INTL("Bạn đã nhận được Pokemon "),
    rarity_name,
    _INTL("!"),
    rarity_color,
    base,
    shadow
  )

  begin
    sprites["pokemon"] = PokemonSprite.new(viewport)
    sprites["pokemon"].setPokemonBitmap(pkmn)
  rescue
    sprites["pokemon"].dispose if sprites["pokemon"] && !sprites["pokemon"].disposed?
    sprites["pokemon"] = PokemonIconSprite.new(pkmn, viewport)
  end

  sprites["pokemon"].z = 10
  sprites["pokemon"].x = Graphics.width / 2
  sprites["pokemon"].y = 198

  if sprites["pokemon"].bitmap
    sprites["pokemon"].ox = sprites["pokemon"].bitmap.width / 2
    sprites["pokemon"].oy = sprites["pokemon"].bitmap.height / 2
  end

  sprites["pokemon"].zoom_x = 0.2
  sprites["pokemon"].zoom_y = 0.2
  sprites["pokemon"].opacity = 0

  pbSEPlay("Battle ball shake") rescue nil

  target_zoom = 0.92
  22.times do |i|
    t = i / 21.0
    zoom = 0.2 + ((target_zoom - 0.2) * t)
    sprites["pokemon"].opacity = (255 * t).to_i
    sprites["pokemon"].zoom_x = zoom
    sprites["pokemon"].zoom_y = zoom
    Graphics.update
    Input.update
    pbUpdateSpriteHash(sprites)
  end

  8.times do |i|
    zoom = target_zoom + (Math.sin(i / 8.0 * Math::PI) * 0.06)
    sprites["pokemon"].zoom_x = zoom
    sprites["pokemon"].zoom_y = zoom
    Graphics.update
    Input.update
    pbUpdateSpriteHash(sprites)
  end

  sprites["pokemon"].opacity = 255
  sprites["pokemon"].zoom_x = target_zoom
  sprites["pokemon"].zoom_y = target_zoom

  overlay.font.bold = true
  overlay.font.size = 34
  pbDrawTextPositions(
    overlay,
    [
      [species_name.upcase, Graphics.width / 2, 298, :center,
       Color.new(48, 48, 48), Color.new(220, 220, 220)]
    ]
  )
  overlay.font.bold = false

  pbMEPlay("Pkmn get") rescue nil

  pbWaitForConfirm(sprites, "pokemon", 198)

  pbDisposeSpriteHash(sprites)
  viewport.dispose
end

#===============================================================================
# Bag command text
#===============================================================================
LP_RandomPokeBall::ITEM_IDS.each do |ball_item|
  ItemHandlers::UseText.add(ball_item,
    proc { |item|
      next _INTL("Open")
    }
  )
end

#===============================================================================
# Use from Bag
#===============================================================================
LP_RandomPokeBall::ITEM_IDS.each do |ball_item|
  ItemHandlers::UseFromBag.add(ball_item,
    proc { |item|
    if LP_RandomPokeBall.valid_rarities(item).empty?
      pbMessage(_INTL("There are no Pokémon in the reward pool."))
      next 0
    end

    owned = $bag.quantity(item)
    max_qty = [owned, LP_RandomPokeBall::MAX_USES].min

    if max_qty <= 0
      pbMessage(_INTL("You don't have any Poké Balls."))
      next 0
    end

    qty = 1
    if max_qty > 1
      params = ChooseNumberParams.new
      params.setRange(1, max_qty)
      params.setDefaultValue(1)
      qty = pbMessageChooseNumber(
        _INTL("Use how many Poké Balls?"),
        params
      )
      next 0 if qty <= 0
    end

    used = 0
    results = []

    qty.times do
      rarity, species = LP_RandomPokeBall.roll_species(item)
      if !rarity || !species
        pbMessage(_INTL("There are no Pokémon in the reward pool."))
        break
      end

      pkmn = LP_RandomPokeBall.create_pokemon(species)

      added = pbAddPokemonSilent(pkmn)
      if !added
        pbMessage(_INTL("There is no more room for Pokémon."))
        break
      end

      $bag.remove(item)
      used += 1
      results << { rarity: rarity, pokemon: pkmn }

      LP_RandomPokeBall.pbRevealPokemon(pkmn, rarity)
    end

    if used > 1
      LP_RandomPokeBall.pbShowSummary(results)
    end

    next (used > 0) ? 1 : 0
    }
  )
end

def self.pbDrawSoftCircle(bitmap, cx, cy, radius, color, max_alpha = 90)
  r = color.red
  g = color.green
  b = color.blue

  x_start = [cx - radius, 0].max
  y_start = [cy - radius, 0].max
  x_end   = [cx + radius, bitmap.width - 1].min
  y_end   = [cy + radius, bitmap.height - 1].min

  (x_start..x_end).each do |x|
    dx2 = (x - cx) * (x - cx)
    (y_start..y_end).each do |y|
      dy2 = (y - cy) * (y - cy)
      dist = Math.sqrt(dx2 + dy2)
      next if dist > radius
      ratio = 1.0 - (dist.to_f / radius)
      alpha = (max_alpha * (ratio ** 1.4)).to_i
      next if alpha <= 0
      bitmap.fill_rect(x, y, 1, 1, Color.new(r, g, b, alpha))
    end
  end
end

def self.pbWaitForConfirm(sprites = nil, bob_key = nil, base_y = nil)
  frame = 0
  loop do
    Graphics.update
    Input.update

    if sprites
      if bob_key && sprites[bob_key] && base_y
        sprites[bob_key].y = base_y + (Math.sin(frame / 8.0) * 4).to_i
      end
      pbUpdateSpriteHash(sprites)
    end

    frame += 1
    break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
  end
end

def self.pbShowSummary(results)
  return if !results || results.empty?

  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 999999
  sprites = {}

  pbAddImageBackground(sprites, "bg", viewport, SUMMARY_BG_PATH)

  sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
  sprites["overlay"].z = 20
  pbSetSystemFont(sprites["overlay"].bitmap)
  overlay = sprites["overlay"].bitmap

  base = Color.new(48, 48, 48)
  no_shadow = Color.new(0, 0, 0, 0)

  # Tieu de "Tong ket" ha xuong mot chut cho can giua hon
  overlay.font.bold = false
  overlay.font.size = 26
  pbDrawTextPositions(
    overlay,
    [
      [_INTL("Tổng kết"), Graphics.width / 2, 20, :center, base, Color.new(220, 220, 220)]
    ]
  )

  cols = 5
  cell_w = 97
  cell_h = 74
  start_x = 12
  start_y = 64

  results.each_with_index do |data, i|
    break if i >= 20

    pkmn   = data[:pokemon]
    rarity = data[:rarity]
    next if !pkmn

    col = i % cols
    row = i / cols

    x = start_x + (col * cell_w)
    y = start_y + (row * cell_h)

    rarity_color = RARITY_COLORS[rarity] || base

    begin
      icon = PokemonIconSprite.new(pkmn, viewport)
      icon.z = 10
      icon.x = x + 48 - 32
      icon.y = y - 16
      icon.zoom_x = 0.85
      icon.zoom_y = 0.85
      sprites["pkmn_#{i}"] = icon
    rescue
      spr = PokemonSprite.new(viewport)
      spr.setPokemonBitmap(pkmn)
      spr.z = 10
      spr.x = x + 48
      spr.y = y + 14
      if spr.bitmap
        spr.ox = spr.bitmap.width / 2
        spr.oy = spr.bitmap.height / 2
      end
      spr.zoom_x = 0.35
      spr.zoom_y = 0.35
      sprites["pkmn_#{i}"] = spr
    end

    species_name = GameData::Species.get(pkmn.species).name.upcase
    species_name = species_name[0, 10] if species_name.length > 10

    overlay.font.bold = false
    overlay.font.size = 16

    # Chi hien ten Pokemon
    # Mau ten dua theo rarity
    # Khong co shadow
    pbDrawTextPositions(
      overlay,
      [
        [species_name, x + 48, y + 52, :center, rarity_color, no_shadow]
      ]
    )
  end

  loop do
    Graphics.update
    Input.update
    pbUpdateSpriteHash(sprites)
    break if Input.trigger?(Input::USE) || Input.trigger?(Input::BACK)
  end

  pbDisposeSpriteHash(sprites)
  viewport.dispose
end
end