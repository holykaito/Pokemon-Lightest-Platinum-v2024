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

#===============================================================================
# Cotton Punch
# Lowers Speed by 1 stage and applies Leech Seed.
#===============================================================================
class Battle::Move::LowerTargetSpeed1SeedTarget <
      Battle::Move::LowerTargetSpeed1

  def pbAdditionalEffect(user, target)
    return if target.fainted?
    return if target.damageState.substitute

    # Standard Speed reduction, including ability interactions.
    super

    # Seed independently of whether Speed can be lowered.
    return if target.pbHasType?(:GRASS)
    return if target.effects[PBEffects::LeechSeed] >= 0

    target.effects[PBEffects::LeechSeed] = user.index
    @battle.pbDisplay(_INTL("{1} was seeded!", target.pbThis))
  end
end

#===============================================================================
# Sylph Spell
# Raises Special Attack, Speed and Accuracy by 1 stage each.
#===============================================================================
class Battle::Move::RaiseUserSpAtkSpdAcc1 < Battle::Move::MultiStatUpMove
  def initialize(battle, move)
    super
    @statUp = [:SPECIAL_ATTACK, 1, :SPEED, 1, :ACCURACY, 1]
  end
end

#===============================================================================
# Smite
# Grounds the target like Smack Down. Has a chance to paralyze.
#===============================================================================
class Battle::Move::HitsTargetInSkyGroundsTargetParalyzeTarget <
      Battle::Move::HitsTargetInSkyGroundsTarget

  def pbAdditionalEffect(user, target)
    return if target.fainted?
    return if target.damageState.substitute

    if target.pbCanParalyze?(user, false, self)
      target.pbParalyze(user)
    end
  end
end

#===============================================================================
# Storm Drive
# Two-turn attack. Skips the charging turn in rain or heavy rain.
#===============================================================================
class Battle::Move::TwoTurnAttackOneTurnInRainstorm <
      Battle::Move::TwoTurnMove

  def pbIsChargingTurn?(user)
    ret = super
    if !user.effects[PBEffects::TwoTurnAttack] &&
       [:Rain, :HeavyRain].include?(user.effectiveWeather)
      @powerHerb = false
      @chargingTurn = true
      @damagingTurn = true
      return false
    end
    return ret
  end

  def pbChargingTurnMessage(user, targets)
    @battle.pbDisplay(_INTL("{1} gathered storm energy!", user.pbThis))
  end
end

#===============================================================================
# Dragon Current
# Uses Dive's underwater mechanics and traps the target after attacking.
#===============================================================================
module DragonCurrentVortex
  def pbEffectAfterAllHits(user, target)
    super
    return if @id != :DRAGONCURRENT
    return if !@damagingTurn
    return if target.fainted?
    return if target.damageState.unaffected
    return if target.damageState.substitute
    return if target.effects[PBEffects::Trapping] > 0

    # Includes the end-of-round damage on the turn the move hits.
    duration = 2 + @battle.pbRandom(4)
    if user.hasActiveItem?(:GRIPCLAW)
      duration = (Settings::MECHANICS_GENERATION >= 5) ? 7 : 5
    end

    target.effects[PBEffects::Trapping] = duration + 1
    target.effects[PBEffects::TrappingMove] = @id
    target.effects[PBEffects::TrappingUser] = user.index

    @battle.pbDisplay(_INTL("{1} became trapped in the vortex!",
                           target.pbThis))
  end
end

Battle::Move::TwoTurnAttackInvulnerableUnderwater.prepend(
  DragonCurrentVortex
)

#===============================================================================
# Mystic Dance
# Raises Special Attack and Speed by 1 stage each.
#===============================================================================
class Battle::Move::RaiseUserSpAtkSpd1 < Battle::Move::MultiStatUpMove
  def initialize(battle, move)
    super
    @statUp = [:SPECIAL_ATTACK, 1, :SPEED, 1]
  end
end

#===============================================================================
# Fish Harpoon
# Super effective against Water.
# Ignores the target's Defense/Sp. Def stat stages.
#===============================================================================
class Battle::Move::SuperEffectiveAgainstWaterIgnoreDefenseStages <
      Battle::Move

  def pbCalcTypeModSingle(moveType, defType, user, target)
    if defType == :WATER
      return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
    end
    return super
  end

  def pbGetDefenseStats(user, target)
    defense, _stage = super
    return defense, Battle::Battler::STAT_STAGE_MAXIMUM
  end
end

#===============================================================================
# Hyper Drill - bypasses protection.
#===============================================================================
class Battle::Move::IgnoreProtections < Battle::Move
  def canProtectAgainst?
    return false
  end
end

#===============================================================================
# Hone Horns
# Raises Attack by 1 stage and critical-hit ratio by 1 stage.
#===============================================================================
class Battle::Move::RaiseUserAtk1CriticalHitRate1 < Battle::Move
  attr_reader :statUp

  def initialize(battle, move)
    super
    @statUp = [:ATTACK, 1]
  end

  def canSnatch?; return true; end

  def pbMoveFailed?(user, targets)
    can_raise_attack = user.pbCanRaiseStatStage?(:ATTACK, user, self)
    can_raise_critical = user.effects[PBEffects::FocusEnergy] < 3
    return false if can_raise_attack || can_raise_critical

    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectGeneral(user)
    if user.pbCanRaiseStatStage?(:ATTACK, user, self)
      user.pbRaiseStatStage(:ATTACK, 1, user)
    end

    if user.effects[PBEffects::FocusEnergy] < 3
      user.effects[PBEffects::FocusEnergy] += 1
      @battle.pbDisplay(_INTL("{1} is getting pumped!", user.pbThis))
    end
  end
end

#===============================================================================
# Sky Kick
# First turn: 1.5x power and +1 priority.
# Crash damage follows High Jump Kick's mechanics.
#===============================================================================
class Battle::Move::CrashDamageFirstTurnBoostSkyKick <
      Battle::Move::CrashDamageIfFailsUnusableInGravity

  def pbPriority(user)
    ret = super
    ret += 1 if user.turnCount <= 1
    return ret
  end

  def pbBaseDamage(baseDmg, user, target)
    baseDmg = super
    baseDmg = (baseDmg * 1.5).round if user.turnCount <= 1
    return baseDmg
  end
end

#===============================================================================
# Punishing Kick
# Reversal/Flail power scaling, with crash damage on failure.
#===============================================================================
class Battle::Move::PowerLowerWithUserHPCrashIfMiss <
      Battle::Move::PowerLowerWithUserHP

  def recoilMove?; return true; end

  def pbCrashDamage(user)
    return if user.fainted?
    return if !user.takesIndirectDamage?

    @battle.pbDisplay(_INTL("{1} kept going and crashed!", user.pbThis))
    @battle.scene.pbDamageAnimation(user)
    user.pbReduceHP([user.totalhp / 2, 1].max, false)
    user.pbItemHPHealCheck
    user.pbFaint if user.fainted?
  end
end

#===============================================================================
# Shadow Fangs
# May inflict the Ghost-type Curse effect without costing the user HP.
#===============================================================================
class Battle::Move::DamageTargetMayCurse < Battle::Move
  def pbAdditionalEffect(user, target)
    return if target.fainted?
    return if target.damageState.substitute
    return if target.effects[PBEffects::Curse]

    target.effects[PBEffects::Curse] = true
    @battle.pbDisplay(_INTL("{1} was afflicted by a curse!",
                           target.pbThis))
  end
end

#===============================================================================
# Shadow Fangs
# May inflict the Ghost-type Curse effect without costing the user HP.
#===============================================================================

class Battle::Move::LowerTargetDefenseOrSpeed1 < Battle::Move
  def pbAdditionalEffect(user, target)
    return if target.fainted?
    return if target.damageState.substitute

    stat = [:DEFENSE, :SPEED][@battle.pbRandom(2)]
    return if !target.pbCanLowerStatStage?(stat, user, self)

    target.pbLowerStatStage(stat, 1, user)
  end
end

#===============================================================================
# Tough It Out
# Protects the user and raises its Speed by 1 stage if successful.
# Repeated use follows Protect's success rate.
#===============================================================================
class Battle::Move::ProtectUserRaiseSpeed1 < Battle::Move::ProtectUser
  def pbEffectGeneral(user)
    super
    return if !user.effects[PBEffects::Protect]
    return if !user.pbCanRaiseStatStage?(:SPEED, user, self)

    user.pbRaiseStatStage(:SPEED, 1, user)
  end
end

#===============================================================================
# Rip and Tear
# Lowers the user's Speed by 1 stage upon hitting.
# May inflict Bleed according to EffectChance.
#===============================================================================
class Battle::Move::LowerUserSpeed1BleedTarget < Battle::Move::LowerUserSpeed1
  def pbAdditionalEffect(user, target)
    return if target.fainted?
    return if target.damageState.substitute
    return if !target.pbCanBleed?

    target.pbInflictBleed
  end
end

#===============================================================================
# Nightfelling
# Always hits while Gloom Moonlight is active.
# Uses normal accuracy otherwise.
#===============================================================================
class Battle::Move::AlwaysHitsInGloomMoonlight < Battle::Move
  def pbBaseAccuracy(user, target)
    return 0 if user.effectiveWeather == :GloomMoonlight
    return super
  end
end

#===============================================================================
# Deep Breathing
# Raises the user's Speed and critical-hit ratio by 1 stage each.
# Critical-hit boosts stack up to 3 stages.
#===============================================================================
class Battle::Move::RaiseUserSpeed1CriticalHitRate1 < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if user.pbCanRaiseStatStage?(:SPEED, user, self)
    return false if user.effects[PBEffects::FocusEnergy] < 3

    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectGeneral(user)
    if user.pbCanRaiseStatStage?(:SPEED, user, self)
      user.pbRaiseStatStage(:SPEED, 1, user)
    end

    if user.effects[PBEffects::FocusEnergy] < 3
      user.effects[PBEffects::FocusEnergy] += 1
      @battle.pbDisplay(
        _INTL("{1} is getting pumped!", user.pbThis)
      )
    end
  end
end