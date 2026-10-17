#===============================================================================
# Bleed - Volatile status
# Pokemon Essentials v21.1
# - Loses 1/8 maximum HP at the end of each round.
# - Prevents HP recovery.
# - Cured after using a healing move; that use cannot restore HP.
# - Rock/Ghost types are immune.
# - Cleared on switching, including Baton Pass.
#===============================================================================
module KaitoBleed
  module BattlerHooks
    def pbInitEffects(batonPass)
      @kaito_bleed_token = nil
      @kaito_bleed_cure_token = nil
      super
    end

    #---------------------------------------------------------------------------
    # Immunity and application
    #---------------------------------------------------------------------------
    def pbBleedImmune?
      return pbHasType?(:ROCK) || pbHasType?(:GHOST)
    end

    def pbBleeding?
      # Gaining either immune type also removes Bleed.
      @kaito_bleed_token = nil if pbBleedImmune?
      return !@kaito_bleed_token.nil?
    end

    def pbCanBleed?(show_message = false)
      return false if fainted?

      if pbBleedImmune?
        if show_message
          @battle.pbDisplay(_INTL("{1} is immune to Bleed!", pbThis))
        end
        return false
      end

      if pbBleeding?
        if show_message
          @battle.pbDisplay(_INTL("{1} is already bleeding!", pbThis))
        end
        return false
      end

      return true
    end

    def pbInflictBleed(show_message = true)
      return false if !pbCanBleed?(show_message)

      @kaito_bleed_token = Object.new
      if show_message
        @battle.pbDisplay(_INTL("{1} started bleeding!", pbThis))
      end
      return true
    end

    def pbCureBleed(show_message = true)
      return false if !@kaito_bleed_token

      @kaito_bleed_token = nil
      @kaito_bleed_cure_token = nil

      if show_message
        @battle.pbDisplay(_INTL("{1} stopped bleeding!", pbThis))
      end
      return true
    end

    #---------------------------------------------------------------------------
    # Block HP recovery without preventing healing move selection.
    # Do not use PBEffects::HealBlock: it would prevent using those moves.
    #---------------------------------------------------------------------------
    def canHeal?
      return false if pbBleeding?
      super
    end

    def pbRecoverHP(*args)
      return 0 if pbBleeding?
      super
    end

    #---------------------------------------------------------------------------
    # Cure only after actually using a healing move.
    # Being unable to act does not cure Bleed.
    # Tokens prevent clearing a newly applied Bleed or a replacement Pokemon.
    #---------------------------------------------------------------------------
    def pbBeginTurn(choice)
      @kaito_bleed_cure_token = nil
      super
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

      super
    end
  end

  #-----------------------------------------------------------------------------
  # Mark healing moves when the Pokemon actually uses them.
  # Also works when the healing move fails because HP is already full.
  #-----------------------------------------------------------------------------
  module MoveHooks
    def pbDisplayUseMessage(user)
      user.pbBleedHealingMoveUsed if healingMove?
      super
    end
  end

  #-----------------------------------------------------------------------------
  # Prevent the default recovery message for standard healing moves.
  #-----------------------------------------------------------------------------
  module HealingMoveHooks
    def pbEffectGeneral(user)
      if user.pbBleeding?
        @battle.pbDisplay(
          _INTL("{1} cannot recover HP because of Bleed!", user.pbThis)
        )
        return
      end

      super
    end
  end

  #-----------------------------------------------------------------------------
  # End-of-round damage
  #-----------------------------------------------------------------------------
  module BattleHooks
    def pbEOREffectDamage(priority)
      super

      priority.each do |battler|
        next if battler.fainted? || !battler.pbBleeding?
        next if !battler.takesIndirectDamage?

        damage = [battler.totalhp / 8, 1].max
        battler.pbTakeEffectDamage(damage) do |hp_lost|
          pbDisplay(_INTL("{1} is hurt by Bleed!", battler.pbThis))
        end
      end
    end
  end
end

Battle::Battler.prepend(KaitoBleed::BattlerHooks)
Battle::Move.prepend(KaitoBleed::MoveHooks)
Battle::Move::HealingMove.prepend(KaitoBleed::HealingMoveHooks)
Battle.prepend(KaitoBleed::BattleHooks)

#===============================================================================
# FunctionCode = BleedTarget
# Status move: inflicts Bleed directly.
# Damaging move: inflicts Bleed according to EffectChance.
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