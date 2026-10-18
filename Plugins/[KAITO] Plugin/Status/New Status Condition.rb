#===============================================================================
# Bleed - Pokemon Essentials v21.1
# Uses alias hooks to avoid prepend/alias recursion with other plugins.
#===============================================================================
class Battle::Battler
  unless method_defined?(:bleed_v2_init_effects)
    alias_method :bleed_v2_init_effects, :pbInitEffects
    alias_method :bleed_v2_can_heal, :canHeal?
    alias_method :bleed_v2_recover_hp, :pbRecoverHP
    alias_method :bleed_v2_begin_turn, :pbBeginTurn
    alias_method :bleed_v2_end_turn, :pbEndTurn
  end

  def pbInitEffects(batonPass)
    @kaito_bleed_token = nil
    @kaito_bleed_cure_token = nil
    return bleed_v2_init_effects(batonPass)
  end

  def pbBleedImmune?
    return pbHasType?(:ROCK) || pbHasType?(:GHOST)
  end

  def pbBleeding?
    return false if !@kaito_bleed_token

    if pbBleedImmune?
      @kaito_bleed_token = nil
      @kaito_bleed_cure_token = nil
      return false
    end

    return true
  end

  def pbCanBleed?(show_message = false)
    return false if fainted?

    if pbBleedImmune?
      if show_message
        @battle.pbDisplay(
          _INTL("{1} is immune to Bleed!", pbThis)
        )
      end
      return false
    end

    if pbBleeding?
      if show_message
        @battle.pbDisplay(
          _INTL("{1} is already bleeding!", pbThis)
        )
      end
      return false
    end

    return true
  end

  def pbInflictBleed(show_message = true)
    return false if !pbCanBleed?(show_message)

    @kaito_bleed_token = Object.new
	@battle.pbCommonAnimation("Bleed", self)
    if show_message
      @battle.pbDisplay(
        _INTL("{1} started bleeding!", pbThis)
      )
    end
    return true
  end

  def pbCureBleed(show_message = true)
    return false if !@kaito_bleed_token

    @kaito_bleed_token = nil
    @kaito_bleed_cure_token = nil

    if show_message
      @battle.pbDisplay(
        _INTL("{1} stopped bleeding!", pbThis)
      )
    end
    return true
  end

  def canHeal?
    return false if pbBleeding?
    return bleed_v2_can_heal
  end

  def pbRecoverHP(*args)
    return 0 if pbBleeding?
    return bleed_v2_recover_hp(*args)
  end

  def pbBeginTurn(choice)
    @kaito_bleed_cure_token = nil
    return bleed_v2_begin_turn(choice)
  end

  def pbBleedHealingMoveUsed
    return if !pbBleeding?
    @kaito_bleed_cure_token = @kaito_bleed_token
  end

  def pbEndTurn(choice)
    token = @kaito_bleed_cure_token
    @kaito_bleed_cure_token = nil

    if token && token.equal?(@kaito_bleed_token) && !fainted?
      pbCureBleed
    end

    return bleed_v2_end_turn(choice)
  end
end

#===============================================================================
# Mark healing moves when actually used.
# Recovery remains blocked until the action ends.
#===============================================================================
class Battle::Move
  unless method_defined?(:bleed_v2_display_use_message)
    alias_method :bleed_v2_display_use_message, :pbDisplayUseMessage
  end

  def pbDisplayUseMessage(user)
    user.pbBleedHealingMoveUsed if healingMove?
    return bleed_v2_display_use_message(user)
  end
end

#===============================================================================
# Prevent the normal recovery message while Bleed blocks healing.
#===============================================================================
class Battle::Move::HealingMove
  unless method_defined?(:bleed_v2_effect_general)
    alias_method :bleed_v2_effect_general, :pbEffectGeneral
  end

  def pbEffectGeneral(user)
    if user.pbBleeding?
      @battle.pbDisplay(
        _INTL("{1} cannot recover HP because of Bleed!", user.pbThis)
      )
      return
    end

    return bleed_v2_effect_general(user)
  end
end

#===============================================================================
# End-of-round damage: 1/8 maximum HP.
#===============================================================================
class Battle
  unless method_defined?(:bleed_v2_eor_effect_damage)
    alias_method :bleed_v2_eor_effect_damage, :pbEOREffectDamage
  end

  def pbEOREffectDamage(priority)
    result = bleed_v2_eor_effect_damage(priority)

    priority.each do |battler|
      next if battler.fainted? || !battler.pbBleeding?
      next if !battler.takesIndirectDamage?

      damage = [battler.totalhp / 8, 1].max
	  pbCommonAnimation("Bleed", battler)
      battler.pbTakeEffectDamage(damage) do |hp_lost|
        pbDisplay(
          _INTL("{1} is hurt by Bleed!", battler.pbThis)
        )
      end
    end

    return result
  end
end

#===============================================================================
# FunctionCode = BleedTarget
#===============================================================================
class Battle::Move::BleedTarget < Battle::Move
  def canMagicCoat?
    return statusMove?
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if damagingMove?
    return !target.pbCanBleed?(show_message)
  end

  def pbEffectAgainstTarget(user, target)
    return if damagingMove?
    target.pbInflictBleed
  end

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    target.pbInflictBleed(false)
  end
end