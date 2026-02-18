def getActiveInnates(pkmn)
  pkmn.active_innates || []
end

=begin
MenuHandlers.add(:pokemon_debug_menu, :set_innates, {
  "name"   => _INTL("Set Innates"),
  "parent" => :main,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    cmd = 0
    commands = [
      _INTL("Set Innate Abilities."),
      _INTL("Randomize Defined Innates"),
      _INTL("Reset Innates")
    ]
    loop do
      innates = getActiveInnates(pkmn)
      msg = _INTL("Innates are: {1}", innates.join(", "))
      cmd = screen.pbShowCommands(msg, commands, cmd)
      break if cmd < 0
      case cmd
      when 0   # Set Innate Abilities
        params = ChooseNumberParams.new
        params.setRange(1, GameData::Ability.count)
        params.setDefaultValue(1)
        max_innates = screen.pbMessageChooseNumber(_INTL("How many Innates Max? "), params)
        chosen_innates = []
        max_innates.times do |i|
          new_innate = pbChooseAbilityList
          if new_innate.nil?
            break
          end
          ability_name = GameData::Ability.get(new_innate).name
          chosen_innates << new_innate
          screen.pbMessage(_INTL("{1} ability has been set as the {2} Innate!", ability_name, i + 1))
        end
        pkmn.active_innates = chosen_innates
        pkmn.fixed_innates = chosen_innates
        screen.pbRefreshSingle(pkmnid)
      when 1   # Randomize Defined Innates
        available_innates = pkmn.getInnateList.map(&:first).uniq
        primary_ability_id = pkmn.ability_id

        # Exclude the primary ability from available innates
        available_innates.delete(primary_ability_id) if primary_ability_id

        params = ChooseNumberParams.new
        params.setRange(1, available_innates.size)
        params.setDefaultValue(1)
        max_innates = screen.pbMessageChooseNumber(_INTL("How many innates should this Pokémon have?"), params)
        
        # Ensure max_innates does not exceed available innates
        max_innates = [max_innates, available_innates.size].min

        # Use the select_random_innates method to set the random innates
        pkmn.active_innates = pkmn.select_random_innates(max_innates, primary_ability_id)
		pkmn.fixed_innates = pkmn.active_innates

        # Refresh the display for the single Pokémon
        screen.pbRefreshSingle(pkmnid)
      when 2   # Reset Innates
        available_innates = pkmn.getInnateList.map(&:first)
        params = ChooseNumberParams.new
        params.setRange(1, available_innates.size)
        params.setDefaultValue(1)
        max_innates = screen.pbMessageChooseNumber(_INTL("How many innates should this Pokémon have?"), params)
        
        pkmn.active_innates = available_innates.take(max_innates)
        pkmn.fixed_innates = pkmn.active_innates
        screen.pbRefreshSingle(pkmnid)
      end
    end
    next false
  }
})
=end

MenuHandlers.add(:pokemon_debug_menu, :set_innates, {
  "name"   => _INTL("Set Innates"),
  "parent" => :main,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    cmd = 0
    commands = [
      _INTL("Set Innate Abilities"),
      _INTL("Randomize Defined Innates"),
      _INTL("Randomize Innates MAX"),
      _INTL("Reset Innates")
    ]
    loop do
      innates = pkmn.form_innates[pkmn.form] || pkmn.active_innates || []
      msg = _INTL("Current innates for form {1}: {2}", pkmn.form, innates.join(", "))
      cmd = screen.pbShowCommands(msg, commands, cmd)
      break if cmd < 0
      case cmd
      when 0   # Set Innate Abilities
        params = ChooseNumberParams.new
        params.setRange(1, GameData::Ability.count)
        params.setDefaultValue(1)
        max_innates = screen.pbMessageChooseNumber(_INTL("Set the max number of innates for form {1}: ", pkmn.form), params)
        chosen_innates = []

        max_innates.times do |i|
          new_innate = pbChooseAbilityList
          break if new_innate.nil?
          chosen_innates << new_innate
          screen.pbMessage(_INTL("{1} set as innate {2} for form {3}.", GameData::Ability.get(new_innate).name, i + 1, pkmn.form))
        end

        # Store form-specific innates
        pkmn.active_innates = chosen_innates
		pkmn.form_innates[pkmn.form] = pkmn.active_innates
		#pkmn.Innates = chosen_innates
		#pkmn.assign_innate_abilities
        screen.pbRefreshSingle(pkmnid)

      when 1   # Randomize Defined Innates (Using select_random_innates)
        primary_ability_id = pkmn.ability_id
        max_innates = Settings::INNATE_MAX_AMOUNT

        pkmn.active_innates = pkmn.select_random_innates(max_innates, primary_ability_id)
        pkmn.form_innates[pkmn.form] = pkmn.active_innates
        screen.pbRefreshSingle(pkmnid)

      when 2   # Randomize Innates MAX (Using max_innate_randomizer)
        primary_ability_id = pkmn.ability_id
        max_innates = Settings::INNATE_MAX_AMOUNT

        pkmn.active_innates = pkmn.max_innate_randomizer(max_innates, primary_ability_id)
        pkmn.form_innates[pkmn.form] = pkmn.active_innates
        screen.pbRefreshSingle(pkmnid)

      when 3   # Reset Innates
        available_innates = pkmn.getInnateList#.map(&:first)
        params = ChooseNumberParams.new
        params.setRange(1, available_innates.size)
        params.setDefaultValue(1)
        max_innates = screen.pbMessageChooseNumber(_INTL("Reset innates for form {1} to how many?", pkmn.form), params)
		
		# Reset innates for all forms
		pkmn.form_innates.each_key do |form|
		pkmn.form_innates[form] = available_innates.take(max_innates)
		end

        pkmn.active_innates = available_innates.take(max_innates)
        pkmn.form_innates[pkmn.form] = pkmn.active_innates
        screen.pbRefreshSingle(pkmnid)
      end
    end
    next false
  }
})

#=========================================================
#Adding pokemon
#==========================================================
# Alias the original pbAddPokemon method
alias original_pbAddPokemon pbAddPokemon
def pbAddPokemon(pkmn, level = 1, see_form = true)
  # Call the original method
  result = original_pbAddPokemon(pkmn, level, see_form)
  
  # Assign innate abilities
  pkmn.assign_innate_abilities  if pkmn.is_a?(Pokemon)

  return result
end

# Alias the original pbAddPokemonSilent method
alias original_pbAddPokemonSilent pbAddPokemonSilent
def pbAddPokemonSilent(pkmn, level = 1, see_form = true)
  # Call the original method
  result = original_pbAddPokemonSilent(pkmn, level, see_form)
  
  # Assign innate abilities
  pkmn.assign_innate_abilities  if pkmn.is_a?(Pokemon)

  return result
end
=begin
# Alias the original pbAddTemporalPkmn method
alias original_pbAddTemporalPkmn pbAddTemporalPkmn
def pbAddTemporalPkmn(pkmn, level = 1, see_form = true)
  # Call the original method
  result = original_pbAddTemporalPkmn(pkmn, level, see_form)
  
  # Assign innate abilities
  pkmn.assign_innate_abilities# if pkmn.is_a?(Pokemon)

  return result
end
=end

#==========================================================
#Deoxys form methods TEST
#==========================================================
def pbNormalDeoxys
  $player.pokemon_party.each do |pkmn|
	next if !pkmn.isSpecies?(:DEOXYS)
	pkmn.form = 0 #Normal form
	pkmn.assign_innate_abilities #<- Code that re-rolls innates
	pbSet(1, pkmn.name)
	break
  end
end

def pbAttackDeoxys
  $player.pokemon_party.each do |pkmn|
	next if !pkmn.isSpecies?(:DEOXYS)
	pkmn.form = 1 #Attack form
	pkmn.assign_innate_abilities #<- Code that re-rolls innates
	pbSet(1, pkmn.name)
	break
  end
end

def pbDefenseDeoxys
  $player.pokemon_party.each do |pkmn|
	next if !pkmn.isSpecies?(:DEOXYS)
	pkmn.form = 2 #Defense form
	pkmn.assign_innate_abilities #<- Code that re-rolls innates
	pbSet(1, pkmn.name)
	break
  end
end

def pbSpeedDeoxys
  $player.pokemon_party.each do |pkmn|
	next if !pkmn.isSpecies?(:DEOXYS)
	pkmn.form = 3 #Speed form
	pkmn.assign_innate_abilities #<- Code that re-rolls innates
	pbSet(1, pkmn.name)
	break
  end
end