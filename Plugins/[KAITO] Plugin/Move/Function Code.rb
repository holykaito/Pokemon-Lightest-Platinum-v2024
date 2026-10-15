#===============================================================================
# Hydro Pump: Always hits in rain
#===============================================================================
class Battle::Move::AlwaysHitsInRain < Battle::Move
  def pbBaseAccuracy(user, target)
    # Accuracy = 0 means the move bypasses the accuracy check.
    return 0 if [:Rain, :HeavyRain].include?(user.effectiveWeather)
    return super
  end
end

#===============================================================================
# Sovereign Slide
# Lowers the target's Speed by 1 stage.
# Also causes flinching on the user's first turn after entering battle.
#===============================================================================
class Battle::Move::LowerTargetSpeed1FlinchTargetIfUserFirstTurn <
      Battle::Move::LowerTargetSpeed1

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute

    # Apply flinching independently of whether Speed can be lowered.
    if user.turnCount <= 1 && !target.fainted?
      target.pbFlinch(user)
    end

    # Inherit the standard Speed-lowering effect.
    super
  end
end

#===============================================================================
# Fragmentation
# Uses Steel Beam's HP-loss mechanics, costing 1/8 of maximum HP.
#===============================================================================
class Battle::Move::UserLosesEighthOfTotalHP < Battle::Move
  def pbEffectAfterAllHits(user, target)
    return if user.fainted?
    return if !user.takesIndirectDamage?

    amt = [(user.totalhp / 4.0).ceil, 1].max
    user.pbReduceHP(amt, false)
    @battle.pbDisplay(_INTL("{1} is damaged by recoil!", user.pbThis))
    user.pbItemHPHealCheck
  end
end

#===============================================================================
# Fertile Fangs - damages the target and adds the Grass type.
#===============================================================================
class Battle::Move::DamageTargetAddGrassType < Battle::Move
  def pbAdditionalEffect(user, target)
    return if target.fainted?
    return if target.damageState.substitute
    return if !GameData::Type.exists?(:GRASS)
    return if !target.canChangeType?
    return if target.pbHasType?(:GRASS)

    target.effects[PBEffects::ExtraType] = :GRASS
    @battle.pbDisplay(_INTL("{1} gained the {2} type!",
                           target.pbThis,
                           GameData::Type.get(:GRASS).name))
  end
end

#===============================================================================
# Lovely Bite
# Inherits Attract's additional effect without bypassing Substitute.
#===============================================================================
class Battle::Move::AttractTargetContactBite < Battle::Move::AttractTarget
  def ignoresSubstitute?(user)
    return false
  end

  def canMagicCoat?
    return false
  end
end

#===============================================================================
# Frantic Fang
# Doubles power if the user's current HP is strictly below half.
#===============================================================================
class Battle::Move::DoubleDamageUserBelowHalf < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    baseDmg *= 2 if user.hp * 2 < user.totalhp
    return baseDmg
  end
end