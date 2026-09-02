#===============================================================================
# AAM Innate Abilities Compatibility Fix
# Pokemon Essentials v21.1
#
# Fixes:
#   wrong number of arguments (given 1, expected 2)
#
# Methods fixed:
#   pbAbilityTriggered?
#   pbSetAbilityTrigger
#
# This uses prepend, so it takes priority over the original AAM methods.
#===============================================================================

module AAM_Compatibility_BattlePatch
  def aam_compat_ability_id(ability)
    return nil if ability.nil?
    return ability.id if ability.respond_to?(:id)
    return ability
  end

  def aam_compat_init_trigger_array
    @abils_triggered ||= [[], []]
  end

  def aam_compat_current_battler
    return instance_variable_get(:@aam_compat_current_battler)
  end

  def aam_compat_current_ability
    return instance_variable_get(:@aam_compat_current_ability)
  end

  def aam_compat_find_battler_for_ability(check_ability)
    check_ability = aam_compat_ability_id(check_ability)

    # Best source: context from triggerOnSwitchIn.
    context_battler = aam_compat_current_battler
    return context_battler if context_battler && !context_battler.fainted?

    return nil if !@battlers

    @battlers.each do |b|
      next if !b
      next if b.fainted?

      begin
        return b if b.hasActiveAbility?(check_ability)
      rescue
      end

      begin
        if b.respond_to?(:abilityMutationList) &&
           b.abilityMutationList &&
           b.abilityMutationList.include?(check_ability)
          return b
        end
      rescue
      end
    end

    return nil
  end

  #---------------------------------------------------------------------------
  # Supports:
  #   pbAbilityTriggered?(battler)
  #   pbAbilityTriggered?(battler, ability)
  #---------------------------------------------------------------------------

  def pbAbilityTriggered?(*args)
    battler = args[0]
    check_ability = args[1]

    return false if !battler

    aam_compat_init_trigger_array

    side = battler.index & 1
    idx  = battler.pokemonIndex

    @abils_triggered[side] ||= []
    @abils_triggered[side][idx] ||= []

    if check_ability.nil?
      return !@abils_triggered[side][idx].empty?
    end

    check_ability = aam_compat_ability_id(check_ability)
    return @abils_triggered[side][idx].include?(check_ability)
  end

  #---------------------------------------------------------------------------
  # Supports:
  #   pbSetAbilityTrigger(battler, ability)
  #   pbSetAbilityTrigger(ability)
  #   pbSetAbilityTrigger(battler)
  #---------------------------------------------------------------------------

  def pbSetAbilityTrigger(*args)
    battler = nil
    check_ability = nil

    if args.length >= 2
      battler = args[0]
      check_ability = args[1]
    elsif args.length == 1
      arg = args[0]

      # If only a battler was passed.
      if arg.respond_to?(:pokemonIndex) && arg.respond_to?(:index)
        battler = arg
        check_ability = aam_compat_current_ability
      else
        # If only an ability was passed.
        check_ability = arg
        battler = aam_compat_find_battler_for_ability(check_ability)
      end
    end

    return if !battler
    return if !check_ability

    check_ability = aam_compat_ability_id(check_ability)

    aam_compat_init_trigger_array

    side = battler.index & 1
    idx  = battler.pokemonIndex

    @abils_triggered[side] ||= []
    @abils_triggered[side][idx] ||= []

    return if @abils_triggered[side][idx].include?(check_ability)

    @abils_triggered[side][idx].push(check_ability)
  end
end

Battle.prepend(AAM_Compatibility_BattlePatch)

#===============================================================================
# Battle::Battler compatibility
#===============================================================================

module AAM_Compatibility_BattlerPatch
  def ability_triggered?(check_ability = nil)
    return @battle.pbAbilityTriggered?(self, check_ability)
  end
end

Battle::Battler.prepend(AAM_Compatibility_BattlerPatch)

#===============================================================================
# Context patch for Battle::AbilityEffects.triggerOnSwitchIn
#===============================================================================
# Some plugins call:
#   pbSetAbilityTrigger(ability)
# without passing the battler.
#
# This patch stores the current battler/ability temporarily, so the Battle patch
# above can infer the missing battler.
#===============================================================================

module AAM_Compatibility_AbilityEffectsPatch
  def triggerOnSwitchIn(ability, battler, battle, switch_in = false)
    if battle
      battle.instance_variable_set(:@aam_compat_current_battler, battler)
      battle.instance_variable_set(:@aam_compat_current_ability, ability)
    end

    ret = nil

    begin
      ret = super
    ensure
      if battle
        battle.instance_variable_set(:@aam_compat_current_battler, nil)
        battle.instance_variable_set(:@aam_compat_current_ability, nil)
      end
    end

    return ret
  end
end

class << Battle::AbilityEffects
  prepend AAM_Compatibility_AbilityEffectsPatch
end