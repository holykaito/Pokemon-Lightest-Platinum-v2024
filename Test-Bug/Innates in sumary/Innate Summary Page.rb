#===============================================================================
# Adds/edits various Summary utilities.
#===============================================================================
class PokemonSummary_Scene
  def drawPageINNATES
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(248, 248, 248)
    shadow = Color.new(104, 104, 104)
    # Determine which stats are boosted and lowered by the Pokémon's nature
    statshadows = {}
    GameData::Stat.each_main { |s| statshadows[s.id] = shadow }
    # Write various bits of text
    textpos = [
      [_INTL("Skill 1"), 224, 80, :left, base, shadow],
	  [_INTL("Skill 2"), 224, 180, :left, base, shadow],
	  [_INTL("Skill 3"), 224, 280, :left, base, shadow]
    ]
	# Draw innate name and description
	innat1 = @pokemon.getInnateListName[0]
	innat2 = @pokemon.getInnateListName[1]
	innat3 = @pokemon.getInnateListName[2]
    innate1 = GameData::Innate.try_get(innat1)
	innate2 = GameData::Innate.try_get(innat2)
	innate3 = GameData::Innate.try_get(innat3)
    if innate1
      textpos.push([innate1.name, 362, 80, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)])
      drawTextEx(overlay, 224, 112, 282, 2, innate1.description, Color.new(64, 64, 64), Color.new(176, 176, 176))
    end
	if innate2
      textpos.push([innate2.name, 362, 180, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)])
      drawTextEx(overlay, 224, 212, 282, 2, innate2.description, Color.new(64, 64, 64), Color.new(176, 176, 176))
    end
	if innate3
      textpos.push([innate3.name, 362, 280, :left, Color.new(64, 64, 64), Color.new(176, 176, 176)])
      drawTextEx(overlay, 224, 312, 282, 2, innate3.description, Color.new(64, 64, 64), Color.new(176, 176, 176))
    end
    # Draw all text
    pbDrawTextPositions(overlay, textpos)
  end
end