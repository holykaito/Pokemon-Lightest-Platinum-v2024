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

#===============================================================================
# Back Stab
# Flinches the target.
# Usable on the user's first turn or while vanished.
# Does not require the user to have the Stealth ability.
#===============================================================================
class Battle::Move::FlinchTargetFailsUnlessFirstTurnOrVanished <
      Battle::Move::FlinchTarget
  def pbMoveFailed?(user, targets)
    return false if user.turnCount <= 1
    if defined?(StealthAbility) && StealthAbility.vanished?(user)
      return false
    end

    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end
end

#===============================================================================
# Captivate
# Lowers the target's Sp. Atk by 1 stage, or 2 if opposite gender.
# Deals double damage if the target is infatuated with any Pokemon.
#===============================================================================
class Battle::Move::LowerTargetSpAtk1Or2DoubleDamageIfInfatuated <
      Battle::Move::LowerTargetSpAtk1
  def pbBaseDamage(baseDmg, user, target)
    baseDmg *= 2 if target.effects[PBEffects::Attract] >= 0
    return super(baseDmg, user, target)
  end

  def pbAdditionalEffect(user, target)
    return if target.fainted?

    opposite_gender = user.gender != 2 &&
                      target.gender != 2 &&
                      user.gender != target.gender
    original_stat_down = @statDown
    begin
      @statDown = [:SPECIAL_ATTACK, opposite_gender ? 2 : 1]
      super
    ensure
      @statDown = original_stat_down
    end
  end
end

#===============================================================================
# DUAL WIELD - MAG replacement
#===============================================================================

module MAGDualWieldFix
  SECOND_HIT_DAMAGE = 0.25

  #-----------------------------------------------------------------------------
  # Unwrap AI objects.
  #-----------------------------------------------------------------------------
  def self.move(object)
    return object.move if object.respond_to?(:move)
    return object
  end

  def self.battler(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  #-----------------------------------------------------------------------------
  # Supported move flags.
  #-----------------------------------------------------------------------------
  def self.flagged?(attack)
    attack = move(attack)
    return false if !attack

    return true if attack.respond_to?(:slicingMove?) &&
                   attack.slicingMove?

    return true if attack.respond_to?(:pulseMove?) &&
                   attack.pulseMove?

    return true if attack.respond_to?(:bombMove?) &&
                   attack.bombMove?

    return false
  end

  def self.special_move?(attack)
    return true if attack.respond_to?(:zMove?) && attack.zMove?

    return true if attack.respond_to?(:dynamaxMove?) &&
                   attack.dynamaxMove?

    return false
  end

  #-----------------------------------------------------------------------------
  # Eligibility. Does not roll RNG or change battle state.
  #-----------------------------------------------------------------------------
  def self.eligible?(attack, user)
    attack = move(attack)
    user   = battler(user)

    return false if !attack || !user
    return false if !user.respond_to?(:hasActiveAbility?)
    return false if !user.hasActiveAbility?(:DUALWIELD)
    return false if !attack.damagingMove?
    return false if !flagged?(attack)
    return false if attack.multiHitMove?
    return false if attack.pbRepeatHit?
    return false if special_move?(attack)
    return false if attack.is_a?(Battle::Move::OHKO)

    return true
  end

  #-----------------------------------------------------------------------------
  # Identify the second hit of THIS move's Dual Wield activation.
  #-----------------------------------------------------------------------------
  def self.second_hit?(attack, user)
    return attack.instance_variable_get(:@mag_dual_wield_user) == user &&
           user.effects[PBEffects::ParentalBond] == 1
  end

  #-----------------------------------------------------------------------------
  # Some move subclasses suppress later-hit animations without calling super.
  # Wrap the actual move instance so they also replay the original animation.
  #-----------------------------------------------------------------------------
  def self.install_animation_hook(attack)
    return if attack.instance_variable_get(
      :@mag_dual_wield_animation_hook
    )

    original = attack.method(:pbShowAnimation)

    attack.define_singleton_method(:pbShowAnimation) do |
      id, user, targets, hitNum = 0, showAnimation = true
    |
      if MAGDualWieldFix.second_hit?(self, user)
        if showAnimation
          @battle.pbAnimation(id, user, targets, 0)
        end
      else
        original.call(
          id, user, targets, hitNum, showAnimation
        )
      end
    end

    attack.instance_variable_set(
      :@mag_dual_wield_animation_hook, true
    )
  end

  #-----------------------------------------------------------------------------
  # Estimated total damage multiplier for AI.
  #-----------------------------------------------------------------------------
  def self.ai_factor(attack, user)
    attack = move(attack)
    user   = battler(user)

    return 1.0 if !eligible?(attack, user)

    factor = 1.0 + SECOND_HIT_DAMAGE

    # Existing estimators already include Parental Bond for its holder.
    # Dual Wield replaces that extra hit rather than stacking with it.
    if user.hasActiveAbility?(:PARENTALBOND)
      factor /= (Settings::MECHANICS_GENERATION >= 7) ? 1.25 : 1.5
    end

    return factor
  end
end

#===============================================================================
# Remove MAG's old x1.75 Slicing/Pulse power boost.
#===============================================================================

Battle::AbilityEffects::DamageCalcFromUser.remove(:DUALWIELD)

#===============================================================================
# Hit count
# Replaces MAG's broken pbNumHits implementation.
#===============================================================================

class Battle::Move
  def pbNumHits(user, targets)
    @mag_dual_wield_user = nil

    return 1 if MAGDualWieldFix.special_move?(self)

    if MAGDualWieldFix.eligible?(self, user) &&
       pbDamagingMove? &&
       !targets.empty? &&
       !user.effects[PBEffects::TwoTurnAttack]

      @mag_dual_wield_user = user
      MAGDualWieldFix.install_animation_hook(self)

      # Engine decrements this before each hit:
      # first hit = 2, second hit = 1.
      user.effects[PBEffects::ParentalBond] = 3

      return 2
    end

	# Calculate the standard hit count directly.
	# Avoid calling MAG's alias, which loops through DBK wrappers.
	original_hits = 1

	if user.hasActiveAbility?(:PARENTALBOND) &&
	   pbDamagingMove? &&
	   !chargingTurnMove? &&
	   targets.length == 1
	  user.effects[PBEffects::ParentalBond] = 3
	  original_hits = 2
	end

    return original_hits if original_hits != 1
    return original_hits if multiHitMove? || pbRepeatHit?

    # Preserve Double Cross.
    # Check the ability before rolling RNG.
    if user.hasActiveAbility?(:DOUBLECROSS) &&
       pbDamagingMove? &&
       !chargingTurnMove? &&
       targets.length == 1 &&
       @battle.pbRandom(100) < 30

      @battle.pbShowAbilitySplash(user)
      @battle.pbHideAbilitySplash(user)

      user.effects[PBEffects::ParentalBond] = 3

      return 2
    end

    return original_hits
  end

  #-----------------------------------------------------------------------------
  # Clear activation state at the start of each move usage.
  #-----------------------------------------------------------------------------
  unless method_defined?(:mag_dual_wield_original_usage_counters)
    alias_method :mag_dual_wield_original_usage_counters,
                 :pbChangeUsageCounters
  end

  def pbChangeUsageCounters(user, specialUsage)
    @mag_dual_wield_user = nil

    return mag_dual_wield_original_usage_counters(
      user, specialUsage
    )
  end

  #-----------------------------------------------------------------------------
  # Second hit: calculate normal damage, then apply x0.5 final damage.
  # Temporarily suppress the engine's ordinary Parental Bond reduction.
  #-----------------------------------------------------------------------------
  unless method_defined?(:mag_dual_wield_original_damage_multipliers)
    alias_method :mag_dual_wield_original_damage_multipliers,
                 :pbCalcDamageMultipliers
  end

  def pbCalcDamageMultipliers(
    user, target, numTargets, type, baseDmg, multipliers
  )
    if !MAGDualWieldFix.second_hit?(self, user)
      return mag_dual_wield_original_damage_multipliers(
        user, target, numTargets, type, baseDmg, multipliers
      )
    end

    saved_bond = user.effects[PBEffects::ParentalBond]

    begin
      user.effects[PBEffects::ParentalBond] = 0

      result = mag_dual_wield_original_damage_multipliers(
        user, target, numTargets, type, baseDmg, multipliers
      )

      multipliers[:final_damage_multiplier] *=
        MAGDualWieldFix::SECOND_HIT_DAMAGE

      return result
    ensure
      user.effects[PBEffects::ParentalBond] = saved_bond
    end
  end

  #-----------------------------------------------------------------------------
  # Use the original move animation instead of Parental Bond's animation.
  #-----------------------------------------------------------------------------
  unless method_defined?(:mag_dual_wield_original_animation)
    alias_method :mag_dual_wield_original_animation,
                 :pbShowAnimation
  end

  def pbShowAnimation(
    id, user, targets, hitNum = 0, showAnimation = true
  )
    if MAGDualWieldFix.second_hit?(self, user)
      return if !showAnimation

      return @battle.pbAnimation(id, user, targets, 0)
    end

    return mag_dual_wield_original_animation(
      id, user, targets, hitNum, showAnimation
    )
  end
end

#===============================================================================
# Fixed-damage moves skip pbCalcDamageMultipliers.
# Apply the second-hit reduction separately.
#===============================================================================

class Battle::Move::FixedDamageMove
  unless method_defined?(:mag_dual_wield_original_fixed_damage)
    alias_method :mag_dual_wield_original_fixed_damage,
                 :pbCalcDamage
  end

  def pbCalcDamage(user, target, numTargets = 1)
    result = mag_dual_wield_original_fixed_damage(
      user, target, numTargets
    )

    if MAGDualWieldFix.second_hit?(self, user)
      damage = target.damageState.calcDamage

      if damage > 0
        target.damageState.calcDamage = [
          (damage * MAGDualWieldFix::SECOND_HIT_DAMAGE).round,
          1
        ].max
      end
    end

    return result
  end
end

#===============================================================================
# Native AI damage estimation.
# Does not call pbNumHits or roll battle RNG.
#===============================================================================

class Battle::AI::AIMove
  unless method_defined?(:mag_dual_wield_original_rough_damage)
    alias_method :mag_dual_wield_original_rough_damage,
                 :rough_damage
  end

  def rough_damage
    damage = mag_dual_wield_original_rough_damage

    factor = MAGDualWieldFix.ai_factor(
      @move, @ai.user.battler
    )

    # Fixed-damage estimates don't include Parental Bond's multiplier.
    if @move.is_a?(Battle::Move::FixedDamageMove) &&
       MAGDualWieldFix.eligible?(@move, @ai.user.battler)

      factor = 1.0 + MAGDualWieldFix::SECOND_HIT_DAMAGE
    end

    return damage if factor == 1.0
    return (damage * factor).round
  end
end

#===============================================================================
# Native AI ability ranking.
#===============================================================================

Battle::AI::BASE_ABILITY_RATINGS.each_value do |abilities|
  abilities.delete(:DUALWIELD)
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :DUALWIELD

Battle::AI::Handlers::AbilityRanking.add(:DUALWIELD,
  proc { |ability, score, battler, ai|
    useful = battler.check_for_move do |attack|
      real_move = MAGDualWieldFix.move(attack)

      real_move.damagingMove? &&
        MAGDualWieldFix.flagged?(real_move) &&
        !real_move.multiHitMove? &&
        !real_move.pbRepeatHit? &&
        !MAGDualWieldFix.special_move?(real_move) &&
        !real_move.is_a?(Battle::Move::OHKO)
    end

    next useful ? score : 0
  }
)

#===============================================================================
# Advanced AI: separate shared damage estimator.
#===============================================================================

if defined?(AdvancedAI::CombatUtilities)
  module AdvancedAI::CombatUtilities
    class << self
      if method_defined?(:ability_damage_modifier)
        unless method_defined?(:mag_dual_wield_original_ability_modifier)
          alias_method :mag_dual_wield_original_ability_modifier,
                       :ability_damage_modifier
        end

        def ability_damage_modifier(
          attacker, target, type, physical, effectiveness,
          move = nil, physical_defense = physical
        )
          result = mag_dual_wield_original_ability_modifier(
            attacker, target, type, physical, effectiveness,
            move, physical_defense
          )

          return result * MAGDualWieldFix.ai_factor(move, attacker)
        end
      end
    end
  end
end

#===============================================================================
# Witchcraft
# Changes the target to pure Dragon type and lowers its Attack by 2 stages.
# Either effect can succeed independently.
# Can be reflected by Magic Coat/Magic Bounce.
#===============================================================================
class Battle::Move::SetTargetTypeDragonLowerTargetAttack2 <
      Battle::Move::LowerTargetAttack2
  def canMagicCoat?; return true; end

  def can_change_to_dragon?(target)
    return target.canChangeType? &&
           GameData::Type.exists?(:DRAGON) &&
           target.pbHasOtherType?(:DRAGON)
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if can_change_to_dragon?(target)
    return super
  end

  def pbEffectAgainstTarget(user, target)
    if can_change_to_dragon?(target)
      target.pbChangeTypes(:DRAGON)
      @battle.pbDisplay(
        _INTL("{1}'s type changed to {2}!",
              target.pbThis, GameData::Type.get(:DRAGON).name)
      )
    end
    super
  end
end

#===============================================================================
# Clay Dart
# Super effective against Flying types.
# Other type matchups are calculated normally.
#===============================================================================
class Battle::Move::SuperEffectiveAgainstFlying < Battle::Move
  def pbCalcTypeModSingle(moveType, defType, user, target)
    if defType == :FLYING
      return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
    end
    return super
  end
end

#===============================================================================
# Fae Core
# Turn 1: charges and temporarily traps the target.
# Turn 2: deals damage.
# Does not hook pbInitEffects, avoiding Community Abilities alias recursion.
#===============================================================================
module KaitoFaeCore
  module BattlerHooks
    def pbFaeCoreTrapped?
      data = @kaito_fae_core_trap
      return false if !data

      source, source_pokemon, target_pokemon, expires = data

      valid = !fainted? &&
              pokemon.equal?(target_pokemon) &&
              source &&
              !source.fainted? &&
              source.pokemon.equal?(source_pokemon) &&
              @battle.battlers[source.index].equal?(source) &&
              @battle.turnCount <= expires &&
              source.effects[PBEffects::TwoTurnAttack] == :FAECORE

      @kaito_fae_core_trap = nil if !valid
      return !!valid
    end

    def pbTrapWithFaeCore(user)
      @kaito_fae_core_trap = [
        user,
        user.pokemon,
        pokemon,
        @battle.turnCount + 1
      ]
    end

    def trappedInBattle?
      return true if pbFaeCoreTrapped?
      return super
    end
  end
end

unless Battle::Battler.ancestors.include?(KaitoFaeCore::BattlerHooks)
  Battle::Battler.prepend(KaitoFaeCore::BattlerHooks)
end

#===============================================================================
# FunctionCode = TwoTurnAttackTrapTargetFaeCore
# Power Herb allows immediate damage without the temporary trapping phase.
#===============================================================================
class Battle::Move::TwoTurnAttackTrapTargetFaeCore <
      Battle::Move::TwoTurnMove
  def pbChargingTurnMessage(user, targets)
    @battle.pbDisplay(
      _INTL("{1} is forming a core of fairy energy!", user.pbThis)
    )
  end

  def pbChargingTurnEffect(user, target)
    return if @damagingTurn
    return if target.fainted?
    return if target.effects[PBEffects::Substitute] > 0
    return if target.pbHasType?(:GHOST) &&
              Settings::MORE_TYPE_EFFECTS

    target.pbTrapWithFaeCore(user)
    @battle.pbDisplay(
      _INTL("{1} was trapped inside the fairy core!", target.pbThis)
    )
  end

  def pbAttackingTurnMessage(user, targets)
    @battle.pbDisplay(_INTL("The fairy core exploded!"))
  end
end

#===============================================================================
# Severe Poison
# Poison statusCount:
#   0 = regular poison
#   1 = standard bad poison
#   2 = accelerated bad poison
#===============================================================================
class Battle::Move::BadPoisonTargetFasterIgnoreTargetAbility <
      Battle::Move::IgnoreTargetAbility

  def canMagicCoat?
    return true
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    return !target.pbCanPoison?(user, show_message, self)
  end

  def pbEffectAgainstTarget(user, target)
    target.pbPoison(user, nil, true)

    # Only mark the status if poisoning remains after its callbacks.
    if target.status == :POISON && target.statusCount > 0
      target.statusCount = 2
    end
  end
end

#===============================================================================
# Severe Poison: accelerate Toxic without prepending the Battle class.
#===============================================================================
class Battle
  unless method_defined?(:kaito_severe_poison_v2_eor_status_damage)
    alias_method :kaito_severe_poison_v2_eor_status_damage,
                 :pbEORStatusProblemDamage

    def pbEORStatusProblemDamage(priority)
      priority.each do |battler|
        next if battler.fainted?
        next if battler.status != :POISON
        next if battler.statusCount != 2

        battler.effects[PBEffects::Toxic] = [
          battler.effects[PBEffects::Toxic] + 1, 16
        ].min
      end

      return kaito_severe_poison_v2_eor_status_damage(priority)
    end
  end
end

#===============================================================================
# Neurotoxin: prevents Psychic-type moves for 2 more rounds.
#===============================================================================
class Battle::Move::DisableTargetPsychicMoves < Battle::Move
  def pbAdditionalEffect(user, target)
    return if target.fainted? || target.damageState.substitute

    if target.kaito_neurotoxin_turns.to_i == 0
      @battle.pbDisplay(_INTL(
        "{1} can no longer use Psychic-type moves!", target.pbThis
      ))
    end
    target.kaito_neurotoxin_turns = 3
  end
end

#===============================================================================
# Track the effect and prevent selecting/using Psychic-type moves.
#===============================================================================
module KaitoNeurotoxinBattler
  attr_accessor :kaito_neurotoxin_turns

  def pbInitEffects(batonPass)
    super
    @kaito_neurotoxin_turns = 0
  end

  def pbCanChooseMove?(move, commandPhase, showMessages = true,
                       specialUsage = false)
    if @kaito_neurotoxin_turns.to_i > 0 && move.type == :PSYCHIC
      if showMessages
        msg = _INTL(
          "{1} can't use {2} because of Neurotoxin!",
          pbThis, move.name
        )
        if commandPhase
          @battle.pbDisplayPaused(msg)
        else
          @battle.pbDisplay(msg)
        end
      end
      return false
    end
    super
  end
end

#===============================================================================
# Count down at the end of each round.
#===============================================================================
module KaitoNeurotoxinBattle
  def pbEOREndBattlerEffects(priority)
    super
    priority.each do |battler|
      next if battler.fainted?
      next if battler.kaito_neurotoxin_turns.to_i <= 0

      battler.kaito_neurotoxin_turns -= 1
      next if battler.kaito_neurotoxin_turns > 0

      pbDisplay(_INTL(
        "{1} can use Psychic-type moves again!", battler.pbThis
      ))
    end
  end
end

#===============================================================================
# Neurotoxin: install hooks after every plugin has finished loading.
# Avoids prepend/alias recursion with Community Abilities.
#===============================================================================
module KaitoNeurotoxinLoadFix
  def self.install!
    unless Battle::Battler.ancestors.include?(KaitoNeurotoxinBattler)
      Battle::Battler.prepend(KaitoNeurotoxinBattler)
    end

    unless Battle.ancestors.include?(KaitoNeurotoxinBattle)
      Battle.prepend(KaitoNeurotoxinBattle)
    end
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoNeurotoxinLoadFix.install!
      super(*args, &block)
    end
  end
end

unless Battle.singleton_class.ancestors.include?(
  KaitoNeurotoxinLoadFix::BattleConstruction
)
  Battle.singleton_class.prepend(
    KaitoNeurotoxinLoadFix::BattleConstruction
  )
end

#===============================================================================
# Gloat: raises all five main stats by 1 stage if a foe is below half HP.
#===============================================================================
class Battle::Move::RaiseUserMainStats1IfFoeBelowHalf <
      Battle::Move::MultiStatUpMove

  def initialize(battle, move)
    super
    @statUp = [
      :ATTACK,         1,
      :DEFENSE,        1,
      :SPECIAL_ATTACK, 1,
      :SPECIAL_DEFENSE,1,
      :SPEED,          1
    ]
  end

  def pbMoveFailed?(user, targets)
    eligible = @battle.allOtherSideBattlers(user).any? do |b|
      !b.fainted? && b.hp * 2 < b.totalhp
    end

    if !eligible
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end

    return super
  end
end

#===============================================================================
# Stand Together
# Singles: user's Defense +2.
# Other formats: user's Defense +3, active allies' Attack +1.
#===============================================================================
class Battle::Move::RaiseUserDef2AlliesAtk1 < Battle::Move
  def canSnatch?
    return true
  end

  def pbMoveFailed?(user, targets)
    can_raise = user.pbCanRaiseStatStage?(:DEFENSE, user, self)

    if !@battle.singleBattle?
      user.allAllies.each do |ally|
        next if ally.fainted?
        if ally.pbCanRaiseStatStage?(:ATTACK, user, self)
          can_raise = true
          break
        end
      end
    end

    if !can_raise
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    defense_boost = 2

    if user.pbCanRaiseStatStage?(:DEFENSE, user, self)
      user.pbRaiseStatStage(:DEFENSE, defense_boost, user)
    end

    return if @battle.singleBattle?

    user.allAllies.each do |ally|
      next if ally.fainted?
      next if !ally.pbCanRaiseStatStage?(:ATTACK, user, self)
      ally.pbRaiseStatStage(:ATTACK, 1, user)
    end
  end
end

#===============================================================================
# Chaos Wheel: randomly poisons, drenches or seeds the target.
# PBS EffectChance handles the initial 45% activation chance.
#===============================================================================
class Battle::Move::PoisonDrenchOrSeedTarget < Battle::Move
  def pbAdditionalEffect(user, target)
    return if target.fainted? || target.damageState.substitute

    case @battle.pbRandom(3)
    when 0
      if target.pbCanPoison?(user, false, self)
        target.pbPoison(user)
      end
    when 1
      if target.pbCanDrenched?(user, false, self)
        target.pbDrenched(user)
      end
    when 2
      return if target.pbHasType?(:GRASS)
      return if target.effects[PBEffects::LeechSeed] >= 0

      target.effects[PBEffects::LeechSeed] = user.index
      @battle.pbDisplay(_INTL("{1} was seeded!", target.pbThis))
    end
  end
end

#===============================================================================
# Odor Sleuth: original effect + raises Attack and Accuracy by 1 stage.
#===============================================================================
class Battle::Move::IdentifyTargetRaiseUserAtkAcc1 <
      Battle::Move::StartNegateTargetEvasionStatStageAndGhostImmunity

  def pbEffectAgainstTarget(user, target)
    super
    show_anim = true
    [:ATTACK, :ACCURACY].each do |stat|
      next if !user.pbCanRaiseStatStage?(stat, user, self)
      if user.pbRaiseStatStage(stat, 1, user, show_anim)
        show_anim = false
      end
    end
  end
end

#===============================================================================
# Ready or Not: hides, then attacks with a chance to flinch.
#===============================================================================
class Battle::Move::TwoTurnHideThenAttackFlinchTarget <
      Battle::Move::TwoTurnAttackFlinchTarget

  def pbChargingTurnMessage(user, targets)
    @battle.pbDisplay(_INTL("{1} hid out of sight!", user.pbThis))
  end
end

#===============================================================================
# Recognize the hiding turn as semi-invulnerable.
# Reuses the engine's existing checks for vanished targets.
#===============================================================================
module KaitoReadyOrNotHiding
  def inTwoTurnAttack?(*functions)
    move_id = @effects[PBEffects::TwoTurnAttack]

    if move_id &&
       functions.include?("TwoTurnAttackInvulnerableRemoveProtections")
      move_data = GameData::Move.try_get(move_id)
      if move_data &&
         move_data.function_code == "TwoTurnHideThenAttackFlinchTarget"
        return true
      end
    end

    return super
  end
end

unless Battle::Battler.ancestors.include?(KaitoReadyOrNotHiding)
  Battle::Battler.prepend(KaitoReadyOrNotHiding)
end

#===============================================================================
# AI: reuse the existing two-turn attack + flinch scoring.
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy(
  "TwoTurnAttackFlinchTarget",
  "TwoTurnHideThenAttackFlinchTarget"
)

#===============================================================================
# Ready or Not - Keep the user hidden between turns.
# Pokemon Essentials v21.1 + DBK Animated Pokemon System
#===============================================================================
class Battle::Move::TwoTurnHideThenAttackFlinchTarget <
      Battle::Move::TwoTurnAttackFlinchTarget

  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    # Use the actual charging state so Power Herb can skip the hiding turn.
    hiding = @chargingTurn && !@damagingTurn

    # Play the existing animation first.
    result = super

    # DBK manages both the Pokemon sprite and its shadow.
    # 1 = completely hidden; 0 = visible again.
    @battle.scene.pbChangePokemon(
      user,
      user.visiblePokemon,
      hiding ? 1 : 0
    )

    return result
  end
end

#===============================================================================
# Inverse Room - Uses DBK's existing Inverse Battle mechanic.
#===============================================================================
class Battle
  attr_accessor :kaito_inverse_room_turns

  def kaito_end_inverse_room
    $game_temp.inverse_battle = @kaito_inverse_room_previous
    @kaito_inverse_room_previous = nil
    @kaito_inverse_room_turns = 0
    pbDisplay(_INTL("Inverse Room wore off!"))
  end

  def kaito_start_inverse_room
    @kaito_inverse_room_previous = $game_temp.inverse_battle
    @kaito_inverse_room_turns = 5
    $game_temp.inverse_battle = true
    pbDisplay(_INTL("The type matchups were reversed!"))
  end

  unless method_defined?(:kaito_inverse_room_original_end_field)
    alias_method :kaito_inverse_room_original_end_field,
                 :pbEOREndFieldEffects

    def pbEOREndFieldEffects(priority)
      kaito_inverse_room_original_end_field(priority)
      return if @kaito_inverse_room_turns.to_i <= 0
      @kaito_inverse_room_turns -= 1
      kaito_end_inverse_room if @kaito_inverse_room_turns == 0
    end
  end
end

#===============================================================================
# Starts Inverse Room, or ends it if already active.
#===============================================================================
class Battle::Move::StartInverseRoom < Battle::Move
  def pbEffectGeneral(user)
    if @battle.kaito_inverse_room_turns.to_i > 0
      @battle.kaito_end_inverse_room
    else
      @battle.kaito_start_inverse_room
    end
  end
end

#===============================================================================
# Razor Edge counter. Resets on switching, including Baton Pass.
#===============================================================================
class Battle::Battler
  attr_accessor :kaito_razor_edge_uses

  unless method_defined?(:kaito_razor_edge_original_init)
    alias_method :kaito_razor_edge_original_init, :pbInitEffects

    def pbInitEffects(batonPass)
      @kaito_razor_edge_uses = 0
      kaito_razor_edge_original_init(batonPass)
    end
  end
end

#===============================================================================
# Any other move resets the counter, including Hone Claws.
#===============================================================================
class Battle::Move
  unless method_defined?(:kaito_razor_edge_original_usage)
    alias_method :kaito_razor_edge_original_usage,
                 :pbChangeUsageCounters

    def pbChangeUsageCounters(user, specialUsage)
      if @id != :RAZOREDGE
        user.kaito_razor_edge_uses = 0
      end
      kaito_razor_edge_original_usage(user, specialUsage)
    end
  end
end

#===============================================================================
# Power: 100 -> 80 -> 60 -> 40 -> 20.
# Counts once per use, regardless of number of hits.
#===============================================================================
class Battle::Move::LowerPower20EachConsecutiveUse < Battle::Move
  def pbChangeUsageCounters(user, specialUsage)
    super
    user.kaito_razor_edge_uses =
      [user.kaito_razor_edge_uses.to_i + 1, 5].min
  end

  def pbBaseDamage(baseDmg, user, target)
    previous_uses = [user.kaito_razor_edge_uses.to_i - 1, 0].max
    return [baseDmg - 20 * previous_uses, 20].max
  end
end

#===============================================================================
# AI predicts the power of the next use.
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add(
  "LowerPower20EachConsecutiveUse",
  proc { |power, move, user, target, ai, battle|
    uses = user.battler.kaito_razor_edge_uses.to_i
    next [power - 20 * uses, 20].max
  }
)

#===============================================================================
# Restores 25% max HP and raises Defense by 1 stage.
#===============================================================================
class Battle::Move::HealUserQuarterRaiseUserDef1 < Battle::Move::HealingMove
  def pbHealAmount(user)
    return [(user.totalhp / 4.0).round, 1].max
  end

  def pbMoveFailed?(user, targets)
    can_heal = user.canHeal?
    can_raise = user.pbCanRaiseStatStage?(:DEFENSE, user, self)
    return false if can_heal || can_raise
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectGeneral(user)
    if user.canHeal?
      recovered = user.pbRecoverHP(pbHealAmount(user))
      if recovered > 0
        @battle.pbDisplay(_INTL("{1}'s HP was restored.", user.pbThis))
      end
    end
    if user.pbCanRaiseStatStage?(:DEFENSE, user, self)
      user.pbRaiseStatStage(:DEFENSE, 1, user)
    end
  end
end

#===============================================================================
# Mud Bath shield. Removed on switching, including Baton Pass.
#===============================================================================
class Battle::Battler
  attr_accessor :kaito_mud_bath_shield

  unless method_defined?(:kaito_mud_bath_original_init)
    alias_method :kaito_mud_bath_original_init, :pbInitEffects

    def pbInitEffects(batonPass)
      @kaito_mud_bath_shield = false
      kaito_mud_bath_original_init(batonPass)
    end
  end

  # Consume after all hits, so a multi-hit move is weakened for every hit.
  unless method_defined?(:kaito_mud_bath_original_after_move)
    alias_method :kaito_mud_bath_original_after_move,
                 :pbEffectsAfterMove

    def pbEffectsAfterMove(user, targets, move, numHits)
      if move.damagingMove? && numHits > 0
        targets.each do |target|
          next if !target.kaito_mud_bath_shield
          next if target.damageState.unaffected
          next if target.damageState.totalHPLost <= 0
          target.kaito_mud_bath_shield = false
          @battle.pbDisplay(
            _INTL("The mud protecting {1} wore off!", target.pbThis(true))
          )
        end
      end
      kaito_mud_bath_original_after_move(user, targets, move, numHits)
    end
  end
end

#===============================================================================
# Halve incoming move power without consuming the shield during calculations.
#===============================================================================
class Battle::Move
  unless method_defined?(:kaito_mud_bath_original_damage_multipliers)
    alias_method :kaito_mud_bath_original_damage_multipliers,
                 :pbCalcDamageMultipliers

    def pbCalcDamageMultipliers(user, target, numTargets, type,
                                baseDmg, multipliers)
      result = kaito_mud_bath_original_damage_multipliers(
        user, target, numTargets, type, baseDmg, multipliers
      )
      if target.kaito_mud_bath_shield
        multipliers[:power_multiplier] *= 0.5
      end
      return result
    end
  end
end

#===============================================================================
# Cure the user and active allies; shield only the user.
#===============================================================================
class Battle::Move::CureUserAndAlliesStatusWeakenNextAttack < Battle::Move
  def canSnatch?; return true; end

  def pbMoveFailed?(user, targets)
    affected = [user] + user.allAllies
    can_cure = affected.any? { |b| !b.fainted? && b.status != :NONE }
    return false if can_cure || !user.kaito_mud_bath_shield
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectGeneral(user)
    ([user] + user.allAllies).each do |battler|
      next if battler.fainted? || battler.status == :NONE
      battler.pbCureStatus
    end
    if !user.kaito_mud_bath_shield
      user.kaito_mud_bath_shield = true
      @battle.pbDisplay(
        _INTL("{1} became protected by mud!", user.pbThis)
      )
    end
  end
end

#===============================================================================
# Soul Trap
# - Sets a trap at the target's position.
# - Triggers once when a conscious Pokemon switches out of that position.
# - Does not trigger when replacing a fainted Pokemon.
# - Remains effective even if the original user switches out or faints.
#===============================================================================
class Battle
  def kaito_soul_traps
    @kaito_soul_traps ||= {}
    return @kaito_soul_traps
  end

  #-----------------------------------------------------------------------------
  # Resolve the delayed attack.
  #-----------------------------------------------------------------------------
  def kaito_trigger_soul_trap(index, data)
    target = @battlers[index]
    return if !target || target.fainted?

    user_index, party_index, move_id = data

    # Use the original battler if it is still active and conscious.
    source = allBattlers.find do |b|
      !b.fainted? &&
        !b.opposes?(user_index) &&
        b.pokemonIndex == party_index
    end

    # Otherwise, create a temporary attacker from the original Pokemon.
    if !source
      original = pbParty(user_index)[party_index]
      return if !original

      attacker_copy = original.clone
      attacker_copy.hp = 1 if attacker_copy.hp <= 0

      source = Battle::Battler.new(self, user_index)
      source.pbInitDummyPokemon(attacker_copy, party_index)
    end

    pbDisplay(
      _INTL("A spectral trap exploded around {1}!",
            target.pbThis(true))
    )

    previous_future_sight = @futureSight
    previous_failure = source.lastMoveFailed

    begin
      # Reuse the engine's delayed-attack handling.
      @futureSight = true
      source.pbUseMoveSimple(move_id, index)
    ensure
      @futureSight = previous_future_sight
      source.lastMoveFailed = previous_failure
    end

    target.pbFaint if target.fainted?
  end

  #-----------------------------------------------------------------------------
  # Trigger after the replacement Pokemon has been sent out.
  #-----------------------------------------------------------------------------
  unless method_defined?(:kaito_soul_trap_original_replace)
    alias_method :kaito_soul_trap_original_replace,
                 :pbRecallAndReplace

	def pbRecallAndReplace(idxBattler, idxParty,
						   randomReplacement = false, batonPass = false)
	  outgoing = @battlers[idxBattler]
	  trap_data = nil

	  # Trigger on replacement, including replacement after fainting.
	  if outgoing && outgoing.pokemonIndex != idxParty
		trap_data = kaito_soul_traps.delete(idxBattler)
	  end

	  result = kaito_soul_trap_original_replace(
		idxBattler, idxParty, randomReplacement, batonPass
	  )

	  if trap_data
		kaito_trigger_soul_trap(idxBattler, trap_data)
	  end

	  return result
	end
  end
end

#===============================================================================
# Soul Trap move effect.
# Inherits delayed-attack handling to avoid damage during setup.
#===============================================================================
class Battle::Move::SetSoulTrapOnTargetPosition <
      Battle::Move::AttackTwoTurnsLater

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if @battle.futureSight

    if !user.opposes?(target)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end

    if @battle.kaito_soul_traps.key?(target.index)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end

    return false
  end

  def pbEffectAgainstTarget(user, target)
    return if @battle.futureSight

    @battle.kaito_soul_traps[target.index] = [
      user.index, user.pokemonIndex, @id
    ]

    @battle.pbDisplay(
      _INTL("{1} set a spectral trap around {2}!",
            user.pbThis, target.pbThis(true))
    )
  end

  # Show the assigned SOULTRAP animation during setup and explosion.
  def pbShowAnimation(id, user, targets, hitNum = 0,
                      showAnimation = true)
    return if !showAnimation
    @battle.pbAnimation(id, user, targets, hitNum)
  end
end

#===============================================================================
# Double power while Grassy Terrain is active.
#===============================================================================
class Battle::Move::DoublePowerInGrassyTerrain < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    baseDmg *= 2 if @battle.field.terrain == :Grassy
    return baseDmg
  end
end

#===============================================================================
# AI power calculation.
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add(
  "DoublePowerInGrassyTerrain",
  proc { |power, move, user, target, ai, battle|
    next (battle.field.terrain == :Grassy) ? power * 2 : power
  }
)

#===============================================================================
# More power against faster targets, up to double power.
# Uses normal Special Attack vs. Special Defense.
#===============================================================================
class Battle::Move::PowerUpIfTargetFaster < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    user_speed = [user.pbSpeed, 1].max
    ratio = target.pbSpeed.to_f / user_speed
    multiplier = [[ratio, 1.0].max, 2.0].min
    return (baseDmg * multiplier).round
  end
end

#===============================================================================
# AI power calculation.
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add(
  "PowerUpIfTargetFaster",
  proc { |power, move, user, target, ai, battle|
    user_speed = [user.battler.pbSpeed, 1].max
    ratio = target.battler.pbSpeed.to_f / user_speed
    multiplier = [[ratio, 1.0].max, 2.0].min
    next (power * multiplier).round
  }
)

#===============================================================================
# Creep Out vulnerability. Resets on switching, including Baton Pass.
#===============================================================================
class Battle::Battler
  attr_accessor :kaito_creep_out

  unless method_defined?(:kaito_creep_out_original_init)
    alias_method :kaito_creep_out_original_init, :pbInitEffects

    def pbInitEffects(batonPass)
      @kaito_creep_out = false
      kaito_creep_out_original_init(batonPass)
    end
  end
end

#===============================================================================
# Double damage received from Bug-type moves.
#===============================================================================
class Battle::Move
  unless method_defined?(:kaito_creep_out_original_multipliers)
    alias_method :kaito_creep_out_original_multipliers,
                 :pbCalcDamageMultipliers

    def pbCalcDamageMultipliers(user, target, numTargets, type,
                                baseDmg, multipliers)
      result = kaito_creep_out_original_multipliers(
        user, target, numTargets, type, baseDmg, multipliers
      )

      if type == :BUG && target.kaito_creep_out
        multipliers[:final_damage_multiplier] *= 2
      end

      return result
    end
  end
end

#===============================================================================
# Apply vulnerability after dealing damage.
#===============================================================================
class Battle::Move::MakeTargetWeakerToBug < Battle::Move
  def pbAdditionalEffect(user, target)
    return if target.fainted?
    return if target.damageState.substitute
    return if target.kaito_creep_out

    target.kaito_creep_out = true
    @battle.pbDisplay(
      _INTL("{1} became weaker to Bug-type moves!", target.pbThis)
    )
  end
end