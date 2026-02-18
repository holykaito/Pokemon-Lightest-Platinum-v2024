#########################################################################
#This is an example of an item that toggles abilityMutation on a Pokemon
=begin
ItemHandlers::UseOnPokemon.add(:EXAMPLEAAM, proc { |item, qty, pokemon, scene, screen, msg|
    scene.pbDisplay(_INTL("After consuming the [placeholder], {1} has awakened its untapped potential!",pokemon.name))
	pokemon.toggleAbilityMutation
})

ItemHandlers::UseOnPokemon.add(:MUTANTGENE, proc { |item, qty, pokemon, scene, screen, msg|
    scene.pbDisplay(_INTL("After consuming the gene, {1} has awakened its untapped potential!",pokemon.name))
	pokemon.toggleAbilityMutation
})

ItemHandlers::UseOnPokemon.add(:INNATESHUFFLER, proc { |item, qty, pokemon, scene, screen, msg|
  # Get available innates
  available_innates = pokemon.getInnateList.map(&:first)
  # Get the maximum number of innates from Settings::INNATE_MAX_AMOUNT
  max_innates = Settings::INNATE_MAX_AMOUNT
  # Ensure max_innates does not exceed the number of available innates
  max_innates = [max_innates, available_innates.size].min
  # Randomly select the innates
  chosen_innates = available_innates.sample(max_innates)
  # Set the chosen innates and mark them as already shuffled
  pokemon.instance_variable_set(:@active_innates, chosen_innates)
  pokemon.instance_variable_set(:@fixed_innates, chosen_innates)
  scene.pbDisplay(_INTL("{1} has shuffled it's innates!", pokemon.name))
})


ItemHandlers::UseOnPokemon.add(:INNATESHUFFLER, proc { |item, qty, pokemon, scene, screen, msg|
  max_innates = Settings::INNATE_MAX_AMOUNT
  pokemon.select_random_innates(max_innates, pokemon.ability_id)
  
  scene.pbDisplay(_INTL("{1} has shuffled its innates!", pokemon.name))
})
=end

ItemHandlers::UseOnPokemon.add(:INNATESHUFFLER, proc { |item, qty, pokemon, scene, screen, msg|
  if scene.pbConfirm(_INTL("Do you want to shuffle {1}'s Innates?", pkmn.name))
  # Reset innates for all forms
  available_innates = pokemon.getInnateList.flatten.uniq # Flatten if it returns nested arrays
  pokemon.form_innates.each_key do |form|
    pokemon.form_innates[form] = available_innates.take(Settings::INNATE_MAX_AMOUNT)
  end

  # If randomization is enabled, apply the appropriate randomizer
  if Settings::INNATE_RANDOMIZER == true
    if Settings::MAX_INNATE_RANDOMIZER
      # Use max_innate_randomizer for fully randomized innates
      pokemon.active_innates = pokemon.max_innate_randomizer(Settings::INNATE_MAX_AMOUNT, pokemon.ability_id)
    else
      # Use select_random_innates for possible randomized innates
      pokemon.active_innates = pokemon.select_random_innates(Settings::INNATE_MAX_AMOUNT, pokemon.ability_id)
    end
  end

  # Update the form's innates with the new active ones
  pokemon.form_innates[pokemon.form] = pokemon.active_innates

  # Display message indicating innates were shuffled
  scene.pbDisplay(_INTL("{1} has shuffled its innates!", pokemon.name))
  next true
  end
  next false
})

=begin
ItemHandlers::UseOnPokemon.add(:ABILITYCAPSULE, proc { |item, qty, pkmn, scene|
  if scene.pbConfirm(_INTL("Do you want to change {1}'s Ability?", pkmn.name))
    abils = pkmn.getAbilityList
    abil1 = nil
    abil2 = nil
    abils.each do |i|
      abil1 = i[0] if i[1] == 0
      abil2 = i[0] if i[1] == 1
    end
    if abil1.nil? || abil2.nil? || pkmn.hasHiddenAbility? || pkmn.isSpecies?(:ZYGARDE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    newabil = (pkmn.ability_index + 1) % 2
    newabilname = GameData::Ability.get((newabil == 0) ? abil1 : abil2).name
    pkmn.ability_index = newabil
    pkmn.ability = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s Ability changed! Its Ability is now {2}!", pkmn.name, newabilname))
	max_innates = Settings::INNATE_MAX_AMOUNT
	pkmn.select_random_innates(max_innates, pkmn.ability_id)
    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:ABILITYPATCH, proc { |item, qty, pkmn, scene|
  if scene.pbConfirm(_INTL("Do you want to change {1}'s Ability?", pkmn.name))
    abils = pkmn.getAbilityList
    new_ability_id = nil
    abils.each { |a| new_ability_id = a[0] if a[1] == 2 }
    if !new_ability_id || pkmn.hasHiddenAbility? || pkmn.isSpecies?(:ZYGARDE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    new_ability_name = GameData::Ability.get(new_ability_id).name
    pkmn.ability_index = 2
    pkmn.ability = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s Ability changed! Its Ability is now {2}!", pkmn.name, new_ability_name))
	max_innates = Settings::INNATE_MAX_AMOUNT
	pkmn.select_random_innates(max_innates, pkmn.ability_id)
    next true
  end
  next false
})
=end

ItemHandlers::UseOnPokemon.add(:ABILITYCAPSULE, proc { |item, qty, pkmn, scene|
  if scene.pbConfirm(_INTL("Do you want to change {1}'s Ability?", pkmn.name))
    abils = pkmn.getAbilityList
    abil1 = nil
    abil2 = nil
    abils.each do |i|
      abil1 = i[0] if i[1] == 0
      abil2 = i[0] if i[1] == 1
    end
    if abil1.nil? || abil2.nil? || pkmn.hasHiddenAbility? || pkmn.isSpecies?(:ZYGARDE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end

    # Change the ability
    newabil = (pkmn.ability_index + 1) % 2
    newabilname = GameData::Ability.get((newabil == 0) ? abil1 : abil2).name
    pkmn.ability_index = newabil
    pkmn.ability = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s Ability changed! Its Ability is now {2}!", pkmn.name, newabilname))

    # Reset all forms' innates and re-roll them
    pkmn.form_innates.each_key do |form|
      pkmn.reset_innates_for_form(form)  # Custom method to reset and re-roll innates for the form
    end

    next true
  end
  next false
})

ItemHandlers::UseOnPokemon.add(:ABILITYPATCH, proc { |item, qty, pkmn, scene|
  if scene.pbConfirm(_INTL("Do you want to change {1}'s Ability?", pkmn.name))
    abils = pkmn.getAbilityList
    new_ability_id = nil
    abils.each { |a| new_ability_id = a[0] if a[1] == 2 }
    if !new_ability_id || pkmn.hasHiddenAbility? || pkmn.isSpecies?(:ZYGARDE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end

    # Change the ability to the hidden one
    new_ability_name = GameData::Ability.get(new_ability_id).name
    pkmn.ability_index = 2
    pkmn.ability = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s Ability changed! Its Ability is now {2}!", pkmn.name, new_ability_name))

    # Reset all forms' innates and re-roll them
    pkmn.form_innates.each_key do |form|
      pkmn.reset_innates_for_form(form)  # Custom method to reset and re-roll innates for the form
    end

    next true
  end
  next false
})
