class Pokemon
#Adds the innates to a species datta
	def species=(species_id)
		new_species_data = GameData::Species.get(species_id)
		return if @species == new_species_data.species
		@species     = new_species_data.species
		default_form = new_species_data.default_form
		if default_form >= 0
			@form      = default_form
			elsif new_species_data.form > 0
			@form      = new_species_data.form
		end
		@forced_form = nil
		@gender      = nil if singleGendered?
		@level       = nil   # In case growth rate is different for the new species
		@ability     = nil
		@innate      = nil
		calc_stats
	end
#=============================================================================
# Stuff related to innate abilities. Basically a copy of Ability
#=============================================================================

  # The index of this Pokémon's ability (0, 1 are natural abilities, 2+ are
  # hidden abilities) as defined for its species/form. An ability may not be
  # defined at this index. Is recalculated (as 0 or 1) if made nil.
  # @return [Integer] the index of this Pokémon's ability
  def innate_index
    @innate_index = (@personalID & 1) if !@innate_index
    return @innate_index
  end

  # @param value [Integer, nil] forced ability index (nil if none is set)
  def innate_index=(value)
    @innate_index = value
    @innate = nil
  end

  # @return [GameData::Ability, nil] an Ability object corresponding to this Pokémon's ability
  def innate
    return GameData::Innate.try_get(innate_id)
  end

  # @return [Symbol, nil] the ability symbol of this Pokémon's ability
  def innate_id
    if !@innate
      sp_data = species_data
      inna_index = innate_index
      #if abil_index >= 2   # Hidden ability
      #  @ability = sp_data.hidden_abilities[abil_index - 2]
      #  abil_index = (@personalID & 1) if !@ability
      #end
      if !@innate   # Natural ability or no hidden ability defined
        @innate = sp_data.innates[inna_index] || sp_data.innates[0]
      end
    end
    return @innate
  end

  # @param value [Symbol, String, GameData::Ability, nil] ability to set
  def innate=(value)
    return if value && !GameData::Innate.exists?(value)
    @innate = (value) ? GameData::Innate.get(value).id : value
  end

  # Returns whether this Pokémon has a particular ability. If no value
  # is given, returns whether this Pokémon has an ability set.
  # @param check_ability [Symbol, String, GameData::Ability, nil] ability ID to check
  # @return [Boolean] whether this Pokémon has a particular ability or
  #   an ability at all
  def hasInnate?(check_innate = nil)
    current_innate = self.innate
    return !current_innate.nil? if check_innate.nil?
    return current_innate == check_innate
  end


  # @return [Array<Array<Symbol,Integer>>] the abilities this Pokémon can have,
  #   where every element is [ability ID, ability index]
  def getInnateList
    ret = []
    sp_data = species_data
    sp_data.innates.each_with_index { |a, i| ret.push([a, i]) if a }
   # sp_data.hidden_abilities.each_with_index { |a, i| ret.push([a, i + 2]) if a }
    return ret
  end
  
  def getInnateListName
    ret = []
    sp_data = species_data
    sp_data.innates.each_with_index { |a, i| ret.push(a) if a }
   # sp_data.hidden_abilities.each_with_index { |a, i| ret.push([a, i + 2]) if a }
    return ret
  end
end