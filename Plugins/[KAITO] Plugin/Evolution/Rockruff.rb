#===============================================================================
# Zenith - One Rockruff, three Lycanroc forms
# Pokemon Essentials v21.1
#===============================================================================

# Rockruff always uses its base form.
MultipleForms.register(:ROCKRUFF, {
  "getForm" => proc { |pkmn|
    next 0
  }
})

class PokemonEvolutionScene
  #-----------------------------------------------------------------------------
  # Evolution screen and target form
  #-----------------------------------------------------------------------------
  unless method_defined?(:zenith_rockruff_original_pbStartScreen)
    alias_method :zenith_rockruff_original_pbStartScreen, :pbStartScreen
  end

  def pbStartScreen(pokemon, newspecies)
    @zenith_lycanroc_form = nil

    target = GameData::Species.get(newspecies)

    if pokemon.species == :ROCKRUFF && target.species == :LYCANROC
      @zenith_lycanroc_form =
        if PBDayNight.isEvening?
          2   # Dusk
        elsif PBDayNight.isNight?
          1   # Midnight
        else
          0   # Midday
        end

      newspecies = GameData::Species.get_species_form(
        :LYCANROC, @zenith_lycanroc_form
      ).id
    end

    result = zenith_rockruff_original_pbStartScreen(pokemon, newspecies)

    unless @zenith_lycanroc_form.nil?
      preview = pokemon.clone
      preview.forced_form = @zenith_lycanroc_form

      @sprites["rsprite2"].setPokemonBitmapSpecies(
        preview, newspecies, false
      )
    end

    return result
  end

  #-----------------------------------------------------------------------------
  # Successful evolution
  #-----------------------------------------------------------------------------
  unless method_defined?(:zenith_rockruff_original_pbEvolutionSuccess)
    alias_method :zenith_rockruff_original_pbEvolutionSuccess,
                 :pbEvolutionSuccess
  end

  def pbEvolutionSuccess
    if @zenith_lycanroc_form.nil?
      return zenith_rockruff_original_pbEvolutionSuccess
    end

    old_forced_form = @pokemon.forced_form

    begin
      @pokemon.forced_form = @zenith_lycanroc_form
      return zenith_rockruff_original_pbEvolutionSuccess
    ensure
      @pokemon.forced_form = old_forced_form
    end
  end
end