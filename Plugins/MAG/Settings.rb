################################################################################
# Settings
################################################################################
module Settings


#===============================================================================
# M.A.G Move Settings
#===============================================================================
MAG_RESTRICTIVEWINDS  = true  # If true, Pokemon that aren't airborne will have their evasion dropped.

#===============================================================================
# M.A.G Ability Settings
#===============================================================================
MAG_DUALWIELD  = 1.75   # Slicing & Pulse move damage increase by with Dual Wield

#===============================================================================
# Move Changes
#===============================================================================
# This is a list of already exisitng moves that have been changed applied to
# them. You can change which moves you want to activate or turn off through
# the list below.
#-------------------------------------------------------------------------------
OLD_HYPERBEAM    = true # Changes recharge moves to not require a recharge if the target is knocked out.
OLD_EXPLOSION    = true # Halves the defence of the target pokemon. Changes to SpDef if it's a SpAtk.
MAG_MULTIATTACK  = true # Makes Multi Attack lore accurate and deals an extra 30% damage to Ultra Beasts.
MAG_FLYDIGDIVE   = true # Makes Fly/Dig/Dive attack the target before they are able to switch.


#===============================================================================
# Ability changes
#===============================================================================
# This is a list of already exisitng abilities that have been changed applied to
# them. You can change which abilities you want to activate or turn off through
# the list below.
#-------------------------------------------------------------------------------
MAG_GALEWINGS    = 2      # Changes the HP needed to activate. 0 = Vanilla || 1 = 50% || 2 = 75% (This also applies to clones like Hell's Blaze)
MAG_RUNAWAY      = true   # Allows to switch when trapped. Gets a +2 to speed when intimidated
MAG_LIGHTMETAL   = true   # Increases speed by 20%
MAG_HEAVYMETAL   = true   # Decreases speed by 20% and reduces fighting damage by 50%
MAG_KLUTZ        = true   # Items don't work but evasion increases by 25%.
MAG_FORECAST     = true   # Weather rocks trigger the respective weather to spawn when sent in (Holding Damp Rock acts like Drizzle)
MAG_STICKYHOLD   = true   # Traps Pokemon if they are not a Water-Type.
MAG_ANTICIPATION = 1      # Same as older Anticipation. 1 = has a chance to trigger a quick claw || 2 = 1 time speed boost
MAG_GOODASGOLD   = false  # Good as Gold only triggers once per battle
MAG_TERAVOLT     = true   # Adds the Electric type if it doesn't have it
MAG_TURBOBLAZE   = true   # Adds the Fire type if it doesn't have it
MAG_SHELLARMOR   = true   # Take half damage from ball & bomb moves
MAG_BATTLEARMOR  = true   # Take half damage from slicing moves
MAG_BALLFETCH    = true   # Copies Ball and Bomb moves and uses them immediatly. (Dancer but for bomb moves)
MAG_STENCH       = true   # Has a chance to poison the target when attacking. (Toxic Chain without the badly poison)
MAG_TRUANT       = false  # Normal Truant but also acts like Comatose.
MAG_MAGMAARMOR   = true   # Halves the damage taken from Water type moves
end

#===============================================================================
# Water Veil Plus
# Pokemon Essentials v21.1
#
# Added effects:
#   - Reduces damage taken from Fire-type moves by 25%.
#   - Creates the Aqua Ring effect when the Pokemon enters battle.
#
# Original Water Veil burn immunity is kept unchanged.
#===============================================================================

module WaterVeilPlus
  FIRE_DAMAGE_MULTIPLIER = 0.75

  def self.fire_type?(type, move = nil)
    return true if type == :FIRE

    begin
      return true if move && move.calcType == :FIRE
    rescue
    end

    return false
  end

  def self.has_aqua_ring?(battler)
    return false if !battler
    return false if !PBEffects.const_defined?(:AquaRing)

    return battler.effects[PBEffects::AquaRing]
  rescue
    return false
  end

  def self.set_aqua_ring(battler)
    return if !battler
    return if !PBEffects.const_defined?(:AquaRing)

    battler.effects[PBEffects::AquaRing] = true
  rescue
  end
end

#===============================================================================
# Reduce Fire-type move damage by 25%
#===============================================================================

Battle::AbilityEffects::DamageCalcFromTarget.add(:WATERVEIL,
  proc { |ability, user, target, move, mults, power, type|
    next if !WaterVeilPlus.fire_type?(type, move)

    mults[:final_damage_multiplier] *= WaterVeilPlus::FIRE_DAMAGE_MULTIPLIER
  }
)

#===============================================================================
# Create Aqua Ring on switch-in
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:WATERVEIL,
  proc { |ability, battler, battle, switch_in|
    next if WaterVeilPlus.has_aqua_ring?(battler)

    battle.pbShowAbilitySplash(battler)

    WaterVeilPlus.set_aqua_ring(battler)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} surrounded itself with a veil of water!", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} surrounded it with a veil of water!",
        battler.pbThis, battler.abilityName))
    end

    battle.pbHideAbilitySplash(battler)
  }
)