#########################################################################
#This is an example of an item that toggles abilityMutation on a Pokemon

ItemHandlers::UseOnPokemon.add(:EXAMPLEAAM, proc { |item, qty, pokemon, scene, screen, msg|
    scene.pbDisplay(_INTL("After consuming the [placeholder], {1} has awakened its untapped potential!",pokemon.name))
	pokemon.toggleAbilityMutation
})

ItemHandlers::UseOnPokemon.add(:MUTANTGENE, proc { |item, qty, pokemon, scene, screen, msg|
    scene.pbDisplay(_INTL("After consuming the gene, {1} has awakened its untapped potential!",pokemon.name))
	pokemon.toggleAbilityMutation
})