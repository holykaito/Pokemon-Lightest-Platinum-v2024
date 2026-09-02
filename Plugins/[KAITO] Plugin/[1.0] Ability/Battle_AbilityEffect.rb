#===============================================================================
# PriorityChange handlers
#===============================================================================

Battle::AbilityEffects::PriorityChange.add(:AGILE,
  proc { |ability, battler, move, pri|
    next pri + 1 if battler.turnCount==1
  }
)

Battle::AbilityEffects::PriorityChange.add(:HYPERCHARGE,
  proc { |ability, battler, move, pri|
    next pri + 1 if (Settings::MECHANICS_GENERATION <= 6 || battler.hp == battler.totalhp) &&
                    move.type == :ELECTRIC
  }
)

#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:HALFDRAKE,
  proc { |ability, battler, battle, switch_in|
    next if battler.fainted?

    battle.pbShowAbilitySplash(battler)

    if !battler.pbHasType?(:DRAGON)
      battler.effects[PBEffects::ExtraType] = :DRAGON
      typeName = GameData::Type.get(:DRAGON).name
      battle.pbDisplay(_INTL("{1}'s draconic blood awakened, giving it the {2} type!",
        battler.pbThis, typeName))
    end

    battle.pbHideAbilitySplash(battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:BUGBOUND,
  proc { |ability, battler, battle, switch_in|
    next if battler.fainted?

    battle.pbShowAbilitySplash(battler)

    if !battler.pbHasType?(:BUG)
      battler.effects[PBEffects::ExtraType] = :BUG
      typeName = GameData::Type.get(:BUG).name
      battle.pbDisplay(_INTL("{1}'s body became bound to insects, giving it the {2} type!",
        battler.pbThis, typeName))
    end

    battle.pbHideAbilitySplash(battler)
  }
)

#===============================================================================
# Aquatic
# Adds Water type and removes weaknesses caused by the added Water typing.
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:AQUATIC,
  proc { |ability, battler, battle, switch_in|
    next if battler.fainted?
    next if battler.pbHasType?(:WATER)

    battle.pbShowAbilitySplash(battler)

    battler.effects[PBEffects::ExtraType] = :WATER
    typeName = GameData::Type.get(:WATER).name

    battle.pbDisplay(_INTL("{1} became one with the water and gained the {2} type!",
      battler.pbThis, typeName))

    battle.pbHideAbilitySplash(battler)
  }
)

Battle::AbilityEffects::DamageCalcFromTarget.add(:AQUATIC,
  proc { |ability, user, target, move, mults, power, type|
    # Water's added weaknesses are Electric and Grass.
    # This cancels the x2 weakness caused only by Aquatic's added Water type.
    if target.effects[PBEffects::ExtraType] == :WATER &&
       [:ELECTRIC, :GRASS].include?(type)
      mults[:final_damage_multiplier] /= 2
    end
  }
)

#===============================================================================
# Seaweed
# Takes 1/2 damage from Fire-type moves.
# Grass-type moves used by this Pokémon deal x2 damage to Fire-type targets.
#===============================================================================

Battle::AbilityEffects::DamageCalcFromTarget.add(:SEAWEED,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] /= 2 if type == :FIRE
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:SEAWEED,
  proc { |ability, user, target, move, mults, power, type|
    mults[:attack_multiplier] *= 2 if move.damagingMove? && type == :GRASS && target.pbHasType?(:FIRE)
  }
)

#===============================================================================
# Hydroponic
# Increases Grass-type move damage by 30% in rain.
#===============================================================================

Battle::AbilityEffects::DamageCalcFromUser.add(:HYDROPONIC,
  proc { |ability, user, target, move, mults, power, type|
    if [:Rain, :HeavyRain].include?(user.effectiveWeather) && type == :GRASS
      mults[:power_multiplier] *= 1.3
    end
  }
)

#===============================================================================
# Rampage
# If the user K.O.s a target with a recharge move, it doesn't need to recharge.
# Shows ability splash when activated.
#===============================================================================

Battle::AbilityEffects::OnEndOfUsingMove.add(:RAMPAGE,
  proc { |ability, user, targets, move, battle|
    next if !move.damagingMove?
    next if move.function_code != "AttackAndSkipNextTurn"

    knocked_out = false

    targets.each do |b|
      next if !b
      next if !b.damageState.fainted
      knocked_out = true
      break
    end

    next if !knocked_out

    battle.pbShowAbilitySplash(user)

    user.effects[PBEffects::HyperBeam] = 0

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} kept rampaging!", user.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} removed its need to recharge!",
        user.pbThis, user.abilityName))
    end

    battle.pbHideAbilitySplash(user)
  }
)

#===============================================================================
# Distortion
# When this Pokémon hits an opposing Pokémon, lowers a random stat by 1 stage.
#===============================================================================

Battle::AbilityEffects::OnDealingHit.add(:DISTORTION,
  proc { |ability, user, target, move, battle|
    next if !target
    next if target.fainted?
    next if !target.opposes?(user)
    next if !move.damagingMove?

    stats = []
    GameData::Stat.each_battle do |s|
      next if !target.pbCanLowerStatStage?(s.id, user)
      stats.push(s.id)
    end

    next if stats.length == 0

    stat = stats[battle.pbRandom(stats.length)]

    battle.pbShowAbilitySplash(user)
    target.pbLowerStatStageByAbility(stat, 1, user, false)
    battle.pbHideAbilitySplash(user)
  }
)

#===============================================================================
# Traumatic Fist
# When this Pokémon hits with a punching move, lowers a random target stat by 1 stage.
#===============================================================================

Battle::AbilityEffects::OnDealingHit.add(:TRAUMATICFIST,
  proc { |ability, user, target, move, battle|
    next if !target
    next if target.fainted?
    next if !target.opposes?(user)
    next if !move.damagingMove?
    next if !move.punchingMove?

    stats = []
    GameData::Stat.each_battle do |s|
      next if !target.pbCanLowerStatStage?(s.id, user)
      stats.push(s.id)
    end

    next if stats.length == 0

    stat = stats[battle.pbRandom(stats.length)]

    battle.pbShowAbilitySplash(user)
    target.pbLowerStatStageByAbility(stat, 1, user, false)
    battle.pbHideAbilitySplash(user)
  }
)

#===============================================================================
# Nocturnal
# Reduces damage from Fairy-type and Dark-type moves by 30%.
#===============================================================================

Battle::AbilityEffects::DamageCalcFromTarget.add(:NOCTURNAL,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= 0.7 if [:FAIRY, :DARK].include?(type)
  }
)

#===============================================================================
# Kintsugi
# At the end of each turn, if this Pokémon was damaged by a damaging move
# this turn, it restores 1/10 of its max HP.
#===============================================================================

Battle::AbilityEffects::AfterMoveUseFromTarget.add(:KINTSUGI,
  proc { |ability, target, user, move, switched_battlers, battle|
    next if !target
    next if target.fainted?
    next if !move.damagingMove?

    hp_lost = 0

    if target.damageState.respond_to?(:totalHPLost)
      hp_lost = target.damageState.totalHPLost
    elsif target.damageState.respond_to?(:hpLost)
      hp_lost = target.damageState.hpLost
    end

    next if hp_lost <= 0

    target.effects[PBEffects::KintsugiDamaged] = true
  }
)

Battle::AbilityEffects::EndOfRoundEffect.add(:KINTSUGI,
  proc { |ability, battler, battle|
    next if !battler.effects[PBEffects::KintsugiDamaged]

    battler.effects[PBEffects::KintsugiDamaged] = false

    next if battler.fainted?
    next if !battler.canHeal?

    battle.pbShowAbilitySplash(battler)
    battler.pbRecoverHP(battler.totalhp / 10)
    battle.pbDisplay(_INTL("{1}'s cracks were mended by Kintsugi!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#===============================================================================
# Wandering Orbs
# Sets Haunted Orbs on the opposing side when this Pokémon enters battle.
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:WANDERINGORBS,
  proc { |ability, battler, battle, switch_in|
    next if battler.fainted?

    foe_side = battler.pbOpposingSide

    next if foe_side.effects[PBEffects::HauntedOrbs]

    battle.pbShowAbilitySplash(battler)
    foe_side.effects[PBEffects::HauntedOrbs] = true
    battle.pbDisplay(_INTL("Haunted orbs began floating around the opposing team!"))
    battle.pbHideAbilitySplash(battler)
  }
)

#===============================================================================
# Cheap Tactics
# Pokemon Essentials v21.1
#
# Effect:
#   When this Pokemon enters battle, it performs a fake Scratch attack
#   with 40 BP against a random opposing Pokemon.
#
# Important:
#   - This is an "ảo lượt".
#   - It does NOT use battle.choices.
#   - It does NOT consume the Pokemon's first real turn.
#   - It does NOT call pbUseMove, so it won't replace the user's action.
#===============================================================================

module CheapTactics
  MOVE_ID = :SCRATCH
  MOVE_TYPE = :NORMAL
  BASE_POWER = 40

  def self.possible_targets(user)
    battle = user.battle
    targets = []

    battle.allOtherSideBattlers(user.index).each do |b|
      next if !b
      next if b.fainted?

      # Prefer nearby targets if the method exists.
      begin
        next if b.respond_to?(:near?) && !b.near?(user)
      rescue
      end

      targets.push(b)
    end

    # Fallback: any opposing active battler.
    if targets.empty?
      battle.allOtherSideBattlers(user.index).each do |b|
        next if !b
        next if b.fainted?
        targets.push(b)
      end
    end

    return targets
  end

  def self.random_target(user)
    targets = possible_targets(user)
    return nil if targets.empty?
    return targets[user.battle.pbRandom(targets.length)]
  end

  def self.target_types(target)
    begin
      return target.pbTypes(true)
    rescue
      begin
        return target.pbTypes
      rescue
        return []
      end
    end
  end

  def self.effectiveness_multiplier(type_mod)
    return 0.0 if Effectiveness.ineffective?(type_mod)

    begin
      return Effectiveness.multiplier(type_mod)
    rescue
    end

    begin
      normal = Effectiveness.const_defined?(:NORMAL_EFFECTIVE) ? Effectiveness::NORMAL_EFFECTIVE : 8
      return type_mod.to_f / normal
    rescue
    end

    return 1.0
  end

  def self.calc_damage(user, target)
    atk = [user.attack, 1].max
    defense = [target.defense, 1].max
    level = [user.level, 1].max

    damage = (((((2 * level / 5) + 2) * BASE_POWER * atk / defense) / 50) + 2)

    # STAB for Normal-type Scratch.
    if user.pbHasType?(MOVE_TYPE)
      if user.hasActiveAbility?(:ADAPTABILITY)
        damage = (damage * 2).floor
      else
        damage = (damage * 3 / 2).floor
      end
    end

    # Type effectiveness.
    type_mod = Effectiveness.calculate(MOVE_TYPE, *target_types(target))
    mult = effectiveness_multiplier(type_mod)

    return 0 if mult <= 0

    damage = (damage * mult).floor

    # Random damage roll: 85% - 100%.
    damage = damage * (user.battle.pbRandom(16) + 85) / 100

    # Burn physical damage reduction.
    if user.burned? && !user.hasActiveAbility?(:GUTS)
      damage = damage / 2
    end

    damage = 1 if damage < 1
    return damage
  end

  def self.play_animation(user, target)
    battle = user.battle

    begin
      pkmn_move = Pokemon::Move.new(MOVE_ID)
      battle_move = Battle::Move.from_pokemon_move(battle, pkmn_move)
      battle_move.pbShowAnimation(MOVE_ID, user, [target], 0, true)
      return
    rescue
    end

    begin
      battle.scene.pbDamageAnimation(target)
    rescue
    end
  end

  def self.apply_damage(user, target, damage)
    battle = user.battle
    damage = target.hp if damage > target.hp
    return 0 if damage <= 0

    real_damage = 0

    battle.scene.pbDamageAnimation(target)

    target.pbTakeEffectDamage(damage, false) do |hp_lost|
      real_damage = hp_lost
    end

    target.pbFaint if target.fainted?
    return real_damage
  end

  def self.trigger(user)
    return if !user
    return if user.fainted?

    target = random_target(user)
    return if !target

    battle = user.battle

    battle.pbShowAbilitySplash(user)

    damage = calc_damage(user, target)

    if damage <= 0
      battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
      battle.pbHideAbilitySplash(user)
      return
    end

    play_animation(user, target)

    real_damage = apply_damage(user, target, damage)

    if real_damage > 0
      battle.pbDisplay(_INTL("{1}'s {2} struck {3} with a cheap tactic!",
        user.pbThis, user.abilityName, target.pbThis(true)))
    end

    battle.pbHideAbilitySplash(user)
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:CHEAPTACTICS,
  proc { |ability, battler, battle, switch_in|
    CheapTactics.trigger(battler)
  }
)

#===============================================================================
# Aura Manipulation
#===============================================================================

Battle::AbilityEffects::DamageCalcFromUser.add(:AURAMANIPULATION,
  proc { |ability, user, target, move, mults, power, type|
    next if move.id != :AURASPHERE
    mults[:power_multiplier] *= 1.5
  }
)

#===============================================================================
# Fatal Precision
#===============================================================================

Battle::AbilityEffects::AccuracyCalcFromUser.add(:FATALPRECISION,
  proc { |ability, mods, user, target, move, type|
    next if move.statusMove?
    next if !type
    target_types = target.pbTypes(true)
    effectiveness = Effectiveness.calculate(type, *target_types)
    next if !Effectiveness.super_effective?(effectiveness)

    mods[:base_accuracy] = 0
  }
)

#===============================================================================
# Dwarfhide
# Reduces the chance of getting additional effects from damaging attacks by half.
#===============================================================================

class Battle::Move
  if method_defined?(:pbAdditionalEffectChance)
    alias dwarven_resilience_pbAdditionalEffectChance pbAdditionalEffectChance

    def pbAdditionalEffectChance(user, target, effectChance = 0)
      ret = dwarven_resilience_pbAdditionalEffectChance(user, target, effectChance)

      if target &&
         target.hasActiveAbility?(:DWARFHIDE) &&
         damagingMove? &&
         ret > 0
        ret /= 2
      end

      return ret
    end
  end
end

#===============================================================================
# Toxic Waters
# Water-type moves have a 20% chance of poisoning the target.
#===============================================================================

Battle::AbilityEffects::OnDealingHit.add(:TOXICWATERS,
  proc { |ability, user, target, move, battle|
    next if !target
    next if target.fainted?
    next if !target.opposes?(user)
    next if !move.damagingMove?
    next if move.calcType != :WATER
    next if battle.pbRandom(100) >= 20

    battle.pbShowAbilitySplash(user)

    if target.pbCanPoison?(user, Battle::Scene::USE_ABILITY_SPLASH)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} poisoned {3}!",
          user.pbThis, user.abilityName, target.pbThis(true))
      end
      target.pbPoison(user, msg)
    end

    battle.pbHideAbilitySplash(user)
  }
)

#===============================================================================
# Grip Pincer
# Contact moves have a 50% chance to trap the target.
# Uses PBEffects::Trapping but prevents Bind/Wrap end-turn damage.
#===============================================================================

module GripPincer
  def self.contact_move?(move, user)
    return false if !move
    return true if move.respond_to?(:pbContactMove?) && move.pbContactMove?(user)
    return true if move.respond_to?(:contactMove?) && move.contactMove?
    return false
  end

  def self.trapped_by_user?(target, user)
    return false if !target || !user
    return false if target.effects[PBEffects::Trapping].to_i <= 0
    return target.effects[PBEffects::TrappingUser] == user.index &&
           target.instance_variable_get(:@grip_pincer_trap)
  end

  def self.stage_multiplier(stage)
    return 1.0 if stage <= 0
    return (2.0 + stage) / 2.0
  end
end

Battle::AbilityEffects::OnEndOfUsingMove.add(:GRIPPINCER,
  proc { |ability, user, targets, move, battle|
    next if !user
    next if user.fainted?
    next if !move
    next if !move.damagingMove?
    next if !GripPincer.contact_move?(move, user)

    targets.each do |target|
      next if !target
      next if target.fainted?
      next if !target.opposes?(user)
      next if target.effects[PBEffects::Trapping].to_i > 0
      next if target.damageState.unaffected
      next if target.damageState.substitute
      next if target.damageState.calcDamage <= 0
      next if battle.pbRandom(100) >= 50

      battle.pbShowAbilitySplash(user)

      target.effects[PBEffects::Trapping]     = 4
      target.effects[PBEffects::TrappingMove] = :BIND
      target.effects[PBEffects::TrappingUser] = user.index
      target.instance_variable_set(:@grip_pincer_trap, true)

      battle.pbDisplay(_INTL("{1} was caught by {2}'s Grip Pincer!",
        target.pbThis, user.pbThis(true)))

      battle.pbHideAbilitySplash(user)
    end
  }
)

Battle::AbilityEffects::AccuracyCalcFromUser.add(:GRIPPINCER,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if GripPincer.trapped_by_user?(target, user)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:GRIPPINCER,
  proc { |ability, user, target, move, mults, power, type|
    next if !GripPincer.trapped_by_user?(target, user)

    if move.physicalMove?
      stage = target.stages[:DEFENSE]
      mults[:defense_multiplier] /= GripPincer.stage_multiplier(stage) if stage > 0
    elsif move.specialMove?
      stage = target.stages[:SPECIAL_DEFENSE]
      mults[:defense_multiplier] /= GripPincer.stage_multiplier(stage) if stage > 0
    end
  }
)

#===============================================================================
# Tidiness
#===============================================================================

module Tidiness_HazardCleaner
  HAZARDS = {
    :StealthRock => false,
    :Spikes      => 0,
    :ToxicSpikes => 0,
    :StickyWeb   => false,
    :Steelsurge  => false
  }

  #---------------------------------------------------------------------------
  # Gets PBEffects constant safely.
  # Returns nil if the effect doesn't exist in your project.
  #---------------------------------------------------------------------------
  def self.effect_key(effect_name)
    return nil if !PBEffects.const_defined?(effect_name)
    return PBEffects.const_get(effect_name)
  end

  #---------------------------------------------------------------------------
  # Checks whether a hazard value is active.
  #---------------------------------------------------------------------------
  def self.active_value?(value, empty_value)
    case empty_value
    when 0
      return value.to_i > 0
    when false
      return value == true
    else
      return value != empty_value
    end
  end

  #---------------------------------------------------------------------------
  # Checks whether a side has any entry hazards.
  #---------------------------------------------------------------------------
  def self.hazards_on_side?(side)
    HAZARDS.each do |effect_name, empty_value|
      effect = effect_key(effect_name)
      next if effect.nil?
      return true if active_value?(side.effects[effect], empty_value)
    end
    return false
  end

  def self.clear_side!(side)
    cleared = false

    HAZARDS.each do |effect_name, empty_value|
      effect = effect_key(effect_name)
      next if effect.nil?
      next if !active_value?(side.effects[effect], empty_value)

      side.effects[effect] = empty_value
      cleared = true
    end

    return cleared
  end

  def self.hazard_score(side)
    score = 0

    HAZARDS.each do |effect_name, empty_value|
      effect = effect_key(effect_name)
      next if effect.nil?

      value = side.effects[effect]
      next if !active_value?(value, empty_value)

      case effect_name
      when :Spikes
        score += 12 * value.to_i
      when :ToxicSpikes
        score += 15 * value.to_i
      when :StealthRock
        score += 24
      when :StickyWeb
        score += 18
      when :Steelsurge
        score += 20
      else
        score += 15
      end
    end

    return score
  end
end

Battle::AbilityEffects::OnSwitchIn.add(:TIDINESS,
  proc { |ability, battler, battle, switch_in|
    own_side = battler.pbOwnSide

    # Do nothing if this side has no hazards.
    next if !Tidiness_HazardCleaner.hazards_on_side?(own_side)

    battle.pbShowAbilitySplash(battler)

    Tidiness_HazardCleaner.clear_side!(own_side)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("The entry hazards on {1}'s side were tidied away!",
         battler.pbTeam(true)))
    else
      battle.pbDisplay(_INTL("{1}'s {2} tidied away the entry hazards on its side!",
         battler.pbThis, battler.abilityName))
    end

    battle.pbHideAbilitySplash(battler)
  }
)

if defined?(Battle::AI)
  #-----------------------------------------------------------------------------
  # Replacement Pokémon scoring.
  #-----------------------------------------------------------------------------
  if Battle::AI.method_defined?(:rate_replacement_pokemon)
    class Battle::AI
      alias tidiness_rate_replacement_pokemon rate_replacement_pokemon

      def rate_replacement_pokemon(idxBattler, pkmn, score)
        score = tidiness_rate_replacement_pokemon(idxBattler, pkmn, score)

        if pkmn.hasAbility?(:TIDINESS) &&
           !@battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS)
          own_side = @battle.sides[idxBattler & 1]
          own_score = Tidiness_HazardCleaner.hazard_score(own_side)

          if own_score > 0
            score += own_score
            PBDebug.log_ai("     + Tidiness clears own-side hazards: #{own_score}")
          end
        end

        return score
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Switch decision handler.
  #-----------------------------------------------------------------------------
  if defined?(Battle::AI::Handlers) &&
     defined?(Battle::AI::Handlers::ShouldSwitch)
    Battle::AI::Handlers::ShouldSwitch.add(:tidiness_hazard_control,
      proc { |battler, reserves, ai, battle|
        next false if !ai.trainer.medium_skill?
        next false if battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS)

        own_side = battle.sides[battler.index & 1]
        own_score = Tidiness_HazardCleaner.hazard_score(own_side)

        # Don't switch for Tidiness if there are no hazards to clear.
        next false if own_score <= 0

        # Only consider this if a reserve Pokémon has Tidiness.
        has_tidiness_reserve = reserves.any? { |pkmn| pkmn.hasAbility?(:TIDINESS) }
        next false if !has_tidiness_reserve

        # Medium AI sometimes skips this line; high AI is more willing.
        chance_to_skip = ai.trainer.high_skill? ? 30 : 60
        next false if ai.pbAIRandom(100) < chance_to_skip

        PBDebug.log_ai("#{battler.name} wants to switch to clear hazards with Tidiness")
        next true
      }
    )
  end
end

#===============================================================================
# Zen Aura
#===============================================================================

module ZenAura
  DAMAGE_FRACTION = 8

  def self.can_trigger?(user, target, move, battle)
    return false if user.nil?
    return false if target.nil?
    return false if move.nil?

    # Only enemies are punished.
    return false if !user.opposes?(target)

    # Only special moves trigger Zen Aura.
    return false if !move.specialMove?

    # No effect if the attacker is already unable to be damaged.
    return false if user.fainted?
    return false if user.dummy if user.respond_to?(:dummy)

    # Do not trigger if the move didn't really affect the Zen Aura user.
    return false if target.damageState.unaffected
    return false if target.damageState.substitute

    # Respect Magic Guard-style/indirect damage protection.
    return false if !user.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)

    return true
  end

  def self.damage_amount(user)
    return [1, user.totalhp / DAMAGE_FRACTION].max
  end

  def self.apply_damage(user, target, battle)
    battle.scene.pbDamageAnimation(user)
    user.pbReduceHP(damage_amount(user), false)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} was hurt by the aura!", user.pbThis))
    else
      battle.pbDisplay(_INTL("{1} was hurt by {2}'s {3}!",
         user.pbThis, target.pbThis(true), target.abilityName))
    end

    user.pbItemHPHealCheck
    user.pbFaint if user.fainted?
  end

  # Small scoring helper for optional AI hooks below.
  def self.ai_penalty(user)
    return 0 if user.nil?
    hp_loss = damage_amount(user)
    # Bigger penalty if losing 1/8 HP is a large chunk of current HP.
    return 35 if hp_loss >= user.hp
    return 25 if hp_loss >= user.hp / 2
    return 15
  end
end

Battle::AbilityEffects::OnBeingHit.add(:ZENAURA,
  proc { |ability, user, target, move, battle|
    next if !ZenAura.can_trigger?(user, target, move, battle)

    battle.pbShowAbilitySplash(target)
    ZenAura.apply_damage(user, target, battle)
    battle.pbHideAbilitySplash(target)
  }
)


if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    alias zen_aura_pbGetMoveScore pbGetMoveScore

    def pbGetMoveScore(*args)
      score = zen_aura_pbGetMoveScore(*args)

      # Try to infer move/user/target safely across different Essentials AI
      # signatures. If anything is unclear, don't alter the score.
      move = nil
      user = nil
      target = nil

      args.each do |arg|
        if arg.respond_to?(:specialMove?) && arg.respond_to?(:damagingMove?)
          move = arg
        elsif arg.respond_to?(:index) && arg.respond_to?(:opposes?) &&
              arg.respond_to?(:hasActiveAbility?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end

      if score.is_a?(Numeric) &&
         move && user && target &&
         move.specialMove? &&
         target.hasActiveAbility?(:ZENAURA) &&
         user.opposes?(target) &&
         !@battle.moldBreaker
        penalty = ZenAura.ai_penalty(user)
        score -= penalty
        PBDebug.log_ai("     - Zen Aura punishes special move: #{penalty}") if defined?(PBDebug)
      end

      return score
    end
  end
end

#===============================================================================
# Mighty Horn#===============================================================================

module MightyHorn
  BOOST_MULTIPLIER = 1.3
  BOOSTED_FLAGS = ["Horn", "Drill"]

  def self.move_flags(move)
    return [] if move.nil?

    # Some projects expose flags directly.
    if move.respond_to?(:flags)
      return move.flags || []
    end

    # Pokemon Essentials Battle::Move stores PBS flags internally as @flags.
    if move.instance_variable_defined?(:@flags)
      return move.instance_variable_get(:@flags) || []
    end

    return []
  end

  def self.horn_or_drill_move?(move)
    flags = move_flags(move)
    return false if flags.empty?

    flags.each do |flag|
      return true if BOOSTED_FLAGS.include?(flag.to_s.upcase)
    end

    return false
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::DamageCalcFromUser.add(:MIGHTYHORN,
  proc { |ability, user, target, move, mults, power, type|
    next if !MightyHorn.horn_or_drill_move?(move)

    mults[:power_multiplier] *= MightyHorn::BOOST_MULTIPLIER
  }
)

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    alias mighty_horn_pbGetMoveScore pbGetMoveScore

    def pbGetMoveScore(*args)
      score = mighty_horn_pbGetMoveScore(*args)

      move = nil
      user = nil

      args.each do |arg|
        if arg.respond_to?(:damagingMove?) &&
           (arg.instance_variable_defined?(:@flags) || arg.respond_to?(:flags))
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?)
          user = arg if user.nil?
        end
      end

      if score.is_a?(Numeric) &&
         user &&
         move &&
         user.hasActiveAbility?(:MIGHTYHORN) &&
         MightyHorn.horn_or_drill_move?(move)
        score += 20
        PBDebug.log_ai("     + Mighty Horn boosts this horn/drill move: 20") if defined?(PBDebug)
      end

      return score
    end
  end
end

#===============================================================================
# Charge Rush
#===============================================================================

module ChargeRush
  BOOST_MULTIPLIER = 1.2

  def self.active?(battler)
    return false if battler.nil?
    return battler.turnCount == 0
  end
end

Battle::AbilityEffects::OnSwitchIn.add(:CHARGERUSH,
  proc { |ability, battler, battle, switch_in|
    battle.pbShowAbilitySplash(battler)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} is ready to rush in!", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} raised its momentum!",
         battler.pbThis, battler.abilityName))
    end

    battle.pbHideAbilitySplash(battler)
  }
)

Battle::AbilityEffects::SpeedCalc.add(:CHARGERUSH,
  proc { |ability, battler, mult|
    next if !ChargeRush.active?(battler)

    next mult * ChargeRush::BOOST_MULTIPLIER
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:CHARGERUSH,
  proc { |ability, user, target, move, mults, power, type|
    next if !ChargeRush.active?(user)
    next if !move.physicalMove?

    mults[:attack_multiplier] *= ChargeRush::BOOST_MULTIPLIER
  }
)

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    alias charge_rush_pbGetMoveScore pbGetMoveScore

    def pbGetMoveScore(*args)
      score = charge_rush_pbGetMoveScore(*args)

      move = nil
      user = nil

      args.each do |arg|
        if arg.respond_to?(:physicalMove?) && arg.respond_to?(:damagingMove?)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) &&
              arg.respond_to?(:turnCount)
          user = arg if user.nil?
        end
      end

      if score.is_a?(Numeric) &&
         user &&
         move &&
         user.hasActiveAbility?(:CHARGERUSH) &&
         ChargeRush.active?(user) &&
         move.physicalMove?
        score += 15
        PBDebug.log_ai("     + Charge Rush boosts physical damage this turn: 15") if defined?(PBDebug)
      end

      return score
    end
  end
end

#===============================================================================
# Outbreak
#
# Effect:
#   When this Pokemon inflicts a major status problem on an opposing active
#   Pokemon, the target's Attack is lowered by 1 stage and the same status
#   spreads to a random non-active Pokemon in that target's party.
#===============================================================================

module Outbreak
  STATUSES = [:SLEEP, :POISON, :BURN, :PARALYSIS, :FROZEN]

  def self.valid_status?(status)
    return STATUSES.include?(status)
  end

  def self.status_name(status)
    case status
    when :SLEEP     then return "sleep"
    when :POISON    then return "poison"
    when :BURN      then return "burn"
    when :PARALYSIS then return "paralysis"
    when :FROZEN    then return "freeze"
    end
    return status.to_s
  end

  def self.pokemon_has_type?(pkmn, type)
    return false if !pkmn
    return pkmn.hasType?(type) if pkmn.respond_to?(:hasType?)
    return pkmn.pbHasType?(type) if pkmn.respond_to?(:pbHasType?)
    return pkmn.types.include?(type) if pkmn.respond_to?(:types) && pkmn.types
    return false
  end

  def self.pokemon_has_ability?(pkmn, abilities)
    return false if !pkmn
    abilities = [abilities].flatten
    return abilities.any? { |a| pkmn.hasAbility?(a) } if pkmn.respond_to?(:hasAbility?)
    return abilities.include?(pkmn.ability_id) if pkmn.respond_to?(:ability_id)
    return false
  end

  def self.status_immune?(pkmn, status, source)
    case status
    when :POISON
      if !source || !source.hasActiveAbility?(:CORROSION)
        return true if pokemon_has_type?(pkmn, :POISON)
        return true if pokemon_has_type?(pkmn, :STEEL)
      end
      return true if pokemon_has_ability?(pkmn, [:IMMUNITY, :PASTELVEIL])
    when :BURN
      return true if pokemon_has_type?(pkmn, :FIRE)
      return true if pokemon_has_ability?(pkmn, [:WATERVEIL, :WATERBUBBLE])
    when :PARALYSIS
      return true if pokemon_has_type?(pkmn, :ELECTRIC) && Settings::MORE_TYPE_EFFECTS
      return true if pokemon_has_ability?(pkmn, :LIMBER)
    when :SLEEP
      return true if pokemon_has_ability?(pkmn, [:INSOMNIA, :VITALSPIRIT, :SWEETVEIL])
    when :FROZEN
      return true if pokemon_has_type?(pkmn, :ICE)
      return true if pokemon_has_ability?(pkmn, :MAGMAARMOR)
    end
    return false
  end

  def self.can_spread_to?(pkmn, status, source)
    return false if !pkmn
    return false if pkmn.egg? if pkmn.respond_to?(:egg?)
    return false if pkmn.fainted? if pkmn.respond_to?(:fainted?)
    return false if pkmn.status != :NONE
    return false if status_immune?(pkmn, status, source)
    return true
  end

  def self.active_pokemon(battle)
    ret = []
    battle.allBattlers.each do |b|
      next if !b || b.fainted?
      ret.push(b.pokemon) if b.pokemon
    end
    return ret
  end

  def self.random_party_target(source, target, status)
    battle = target.battle
    party = battle.pbParty(target)
    active = active_pokemon(battle)

    candidates = []
    party.each do |pkmn|
      next if active.include?(pkmn)
      next if !can_spread_to?(pkmn, status, source)
      candidates.push(pkmn)
    end

    return nil if candidates.empty?
    return candidates[battle.pbRandom(candidates.length)]
  end

  def self.give_party_status(pkmn, status, status_count)
    pkmn.status = status
    pkmn.statusCount = status_count if pkmn.respond_to?(:statusCount=)
  end

  def self.trigger(source, target, status, status_count = 0)
    return if !source || !target
    return if !source.hasActiveAbility?(:OUTBREAK)
    return if !source.opposes?(target)
    return if !valid_status?(status)

    battle = target.battle
    spread_target = random_party_target(source, target, status)
    can_lower_attack = target.pbCanLowerStatStage?(:ATTACK, source, nil, false)

    return if !spread_target && !can_lower_attack

    battle.pbShowAbilitySplash(source)

    if can_lower_attack
      target.pbLowerStatStageByAbility(:ATTACK, 1, source, false)
    end

    if spread_target
      give_party_status(spread_target, status, status_count)
      battle.pbDisplay(_INTL("{1}'s {2} spread {3} to {4}!",
        source.pbThis, source.abilityName, status_name(status), spread_target.name))
      PBDebug.log("[Status change] #{spread_target.name} got #{status} from Outbreak") if defined?(PBDebug)
    end

    battle.pbHideAbilitySplash(source)
  end
end

class Battle::Battler
  alias outbreak_pbCanInflictStatus pbCanInflictStatus?

  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    ret = outbreak_pbCanInflictStatus(newStatus, user, showMessages, move, ignoreStatus)
    if ret && user && Outbreak.valid_status?(newStatus)
      @outbreak_status_source = user
      @outbreak_status_kind = newStatus
    end
    return ret
  end

  alias outbreak_pbPoison pbPoison

  def pbPoison(user = nil, msg = nil, toxic = false)
    old_status = self.status
    outbreak_pbPoison(user, msg, toxic)
    if old_status != :POISON && self.status == :POISON
      Outbreak.trigger(user, self, :POISON, self.statusCount)
    end
  end

  alias outbreak_pbBurn pbBurn

  def pbBurn(user = nil, msg = nil)
    old_status = self.status
    outbreak_pbBurn(user, msg)
    if old_status != :BURN && self.status == :BURN
      Outbreak.trigger(user, self, :BURN, self.statusCount)
    end
  end

  alias outbreak_pbParalyze pbParalyze

  def pbParalyze(user = nil, msg = nil)
    old_status = self.status
    outbreak_pbParalyze(user, msg)
    if old_status != :PARALYSIS && self.status == :PARALYSIS
      Outbreak.trigger(user, self, :PARALYSIS, self.statusCount)
    end
  end

  alias outbreak_pbSleep pbSleep

  def pbSleep(msg = nil)
    old_status = self.status
    source = (@outbreak_status_kind == :SLEEP) ? @outbreak_status_source : nil
    outbreak_pbSleep(msg)
    if old_status != :SLEEP && self.status == :SLEEP
      Outbreak.trigger(source, self, :SLEEP, self.statusCount)
    end
    @outbreak_status_source = nil
    @outbreak_status_kind = nil
  end

  alias outbreak_pbFreeze pbFreeze

  def pbFreeze(msg = nil)
    old_status = self.status
    source = (@outbreak_status_kind == :FROZEN) ? @outbreak_status_source : nil
    outbreak_pbFreeze(msg)
    if old_status != :FROZEN && self.status == :FROZEN
      Outbreak.trigger(source, self, :FROZEN, self.statusCount)
    end
    @outbreak_status_source = nil
    @outbreak_status_kind = nil
  end
end

#===============================================================================
# Amplifier
# Pokemon Essentials v21.1
#
# Effect:
#   - Increases damage dealt with sound moves by 30%.
#   - Reduces damage taken from sound moves by 50%.
#
# Notes:
#   - Uses move.soundMove?, same as Soundproof/Punk Rock.
#   - Damage boost: x1.3.
#   - Damage reduction: x0.5.
#===============================================================================

module Amplifier
  OFFENSE_MULTIPLIER = 1.3
  DEFENSE_MULTIPLIER = 0.5

  def self.sound_move?(move)
    return false if move.nil?
    return false if !move.respond_to?(:soundMove?)
    return move.soundMove?
  end
end


Battle::AbilityEffects::DamageCalcFromUser.add(:AMPLIFIER,
  proc { |ability, user, target, move, mults, power, type|
    next if !Amplifier.sound_move?(move)

    mults[:attack_multiplier] *= Amplifier::OFFENSE_MULTIPLIER
  }
)

Battle::AbilityEffects::DamageCalcFromTarget.add(:AMPLIFIER,
  proc { |ability, user, target, move, mults, power, type|
    next if !Amplifier.sound_move?(move)

    mults[:final_damage_multiplier] *= Amplifier::DEFENSE_MULTIPLIER
  }
)


# Guarded so it won't crash if your project uses a different AI structure.
# Gives sound moves a bonus if the user has Amplifier.
# Slightly penalizes using sound moves into a known Amplifier target.

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:amplifier_pbGetMoveScore)
      alias amplifier_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = amplifier_pbGetMoveScore(*args)

      move = nil
      user = nil
      target = nil

      args.each do |arg|
        if arg.respond_to?(:soundMove?) && arg.respond_to?(:damagingMove?)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) && arg.respond_to?(:opposes?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end

      if score.is_a?(Numeric) && move && Amplifier.sound_move?(move)
        if user && user.hasActiveAbility?(:AMPLIFIER)
          score += 20
          PBDebug.log_ai("     + Amplifier boosts this sound move: 20") if defined?(PBDebug)
        end

        if target && target.hasActiveAbility?(:AMPLIFIER)
          score -= 20
          PBDebug.log_ai("     - Target's Amplifier resists sound move: 20") if defined?(PBDebug)
        end
      end

      return score
    end
  end
end

#===============================================================================
# Loud Bang
#===============================================================================

module LoudBang
  CHANCE = 50

  def self.sound_attack?(move)
    return false if move.nil?
    return false if !move.respond_to?(:soundMove?)
    return false if !move.soundMove?
    return false if move.respond_to?(:damagingMove?) && !move.damagingMove?
    return true
  end

  def self.can_confuse?(target, user, show_message = false)
    return false if target.nil?
    return false if target.fainted?
    return false if target.effects[PBEffects::Confusion] > 0

    # Different Essentials/custom builds can have slightly different signatures.
    begin
      return target.pbCanConfuse?(user, show_message)
    rescue ArgumentError
      begin
        return target.pbCanConfuse?(user, show_message, nil)
      rescue ArgumentError
        return target.pbCanConfuse?(show_message)
      end
    end
  end

  def self.confuse_target(target, user)
    msg = _INTL("{1} became confused from the loud bang!", target.pbThis)

    begin
      target.pbConfuse(msg)
    rescue ArgumentError
      begin
        target.pbConfuse(user, msg)
      rescue ArgumentError
        target.pbConfuse
        target.battle.pbDisplay(msg)
      end
    end
  end
end

Battle::AbilityEffects::OnDealingHit.add(:LOUDBANG,
  proc { |ability, user, target, move, battle|
    next if !LoudBang.sound_attack?(move)
    next if target.nil?
    next if target.damageState.unaffected
    next if target.damageState.substitute
    next if battle.pbRandom(100) >= LoudBang::CHANCE
    next if !LoudBang.can_confuse?(target, user, Battle::Scene::USE_ABILITY_SPLASH)

    battle.pbShowAbilitySplash(user)

    if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      battle.pbShowAbilitySplash(target)
      battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis)) if !Battle::Scene::USE_ABILITY_SPLASH
      battle.pbHideAbilitySplash(target)
    else
      LoudBang.confuse_target(target, user)
    end

    battle.pbHideAbilitySplash(user)
  }
)

# Guarded so it won't crash if your project uses a different AI structure.
# Gives sound attacks a small bonus if Loud Bang can confuse the target.

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:loud_bang_pbGetMoveScore)
      alias loud_bang_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = loud_bang_pbGetMoveScore(*args)

      move = nil
      user = nil
      target = nil

      args.each do |arg|
        if arg.respond_to?(:soundMove?) && arg.respond_to?(:damagingMove?)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) && arg.respond_to?(:opposes?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end

      if score.is_a?(Numeric) &&
         user &&
         move &&
         user.hasActiveAbility?(:LOUDBANG) &&
         LoudBang.sound_attack?(move)
        bonus = 10
        bonus += 10 if target && target.effects[PBEffects::Confusion] == 0
        score += bonus
        PBDebug.log_ai("     + Loud Bang can confuse with sound attack: #{bonus}") if defined?(PBDebug)
      end

      return score
    end
  end
end

#===============================================================================
# Multi Headed - Fallback Version
# Pokemon Essentials v21.1
#
# Effect:
#   After a damaging single-target move hits, this ability adds extra follow-up
#   hits based on the user's heads.
#
# Damage:
#   2 heads:
#     Main hit = 100%
#     Extra hit = 20% of the damage dealt by the main hit
#
#   3 heads:
#     Main hit = 100%
#     Extra hit 1 = 10% of the damage dealt by the main hit
#     Extra hit 2 = 10% of the damage dealt by the main hit
#
# Important:
#   This fallback does not modify pbNumHits. It manually applies follow-up
#   damage after the move, so it is safer for projects where pbNumHits is
#   overridden by another battle plugin.
#===============================================================================

module MultiHeaded
  DEBUG_MESSAGES = true
  DEFAULT_HEADS = 2

  TWO_HEADED_SPECIES = [
    :DODUO,
    :ZWEILOUS,
    :BINACLE,
    :KROOKODILE
  ]

  THREE_HEADED_SPECIES = [
    :DODRIO,
    :DUGTRIO,
    :MAGNETON,
    :HYDREIGON,
    :WUGTRIO,
    :IRONJUGULIS
  ]

  def self.species_in_list?(battler, list)
    return false if !battler
    list.each do |species|
      return true if battler.respond_to?(:isSpecies?) && battler.isSpecies?(species)
      return true if battler.respond_to?(:species) && battler.species == species
    end
    return false
  end

  def self.head_count(battler)
    return 3 if species_in_list?(battler, THREE_HEADED_SPECIES)
    return 2 if species_in_list?(battler, TWO_HEADED_SPECIES)
    return DEFAULT_HEADS
  end

  def self.damaging_move?(move)
    return false if !move
    return move.pbDamagingMove? if move.respond_to?(:pbDamagingMove?)
    return move.damagingMove? if move.respond_to?(:damagingMove?)
    return false
  end

  def self.usable_move?(move)
    return false if !damaging_move?(move)
    return false if move.respond_to?(:chargingTurnMove?) && move.chargingTurnMove?

    # Don't add extra hits to natural multi-hit moves.
    return false if move.respond_to?(:multiHitMove?) && move.multiHitMove?

    return true
  end

  def self.valid_damaged_targets(targets)
    ret = []

    targets.each do |target|
      next if !target
      next if target.fainted?
      next if target.damageState.unaffected
      next if target.damageState.substitute
      next if target.damageState.totalHPLost <= 0
      ret.push(target)
    end

    return ret
  end

  def self.extra_damage(base_damage, heads)
    multiplier = (heads >= 3) ? 0.1 : 0.2
    damage = (base_damage * multiplier).round
    damage = 1 if damage < 1
    return damage
  end

  def self.reduce_hp(target, damage)
    damage = target.hp if damage > target.hp

    begin
      target.pbReduceHP(damage, false, true, false)
    rescue ArgumentError
      begin
        target.pbReduceHP(damage, false)
      rescue ArgumentError
        target.pbReduceHP(damage)
      end
    end

    return damage
  end

def self.extra_hit(user, target, battle, move, base_damage, heads, hit_number)
  return false if !target
  return false if target.fainted?
  return false if base_damage <= 0

  damage = extra_damage(base_damage, heads)
  damage = target.hp if damage > target.hp
  return false if damage <= 0

  # Lặp lại hoạt ảnh của chính move đang dùng.
  begin
    move.pbShowAnimation(move.id, user, [target], hit_number - 1, true)
  rescue
    begin
      move.pbShowAnimation(move.id, user, [target])
    rescue
      battle.scene.pbDamageAnimation(target)
    end
  end

  real_damage = 0
  target.pbTakeEffectDamage(damage, false) do |hp_lost|
    real_damage = hp_lost
  end

  if DEBUG_MESSAGES
    battle.pbDisplay(_INTL("Debug: Extra hit should deal {1}, actually dealt {2}.",
      damage, real_damage))
  end

  PBDebug.log("[Multi Headed] Extra hit #{hit_number} should deal #{damage}, actually dealt #{real_damage}") if defined?(PBDebug)

  target.pbFaint if target.fainted?
  return true
end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::OnEndOfUsingMove.add(:MULTIHEADED,
  proc { |ability, user, targets, move, battle|
    next if !user.hasActiveAbility?(:MULTIHEADED)
    next if !MultiHeaded.usable_move?(move)

    heads = MultiHeaded.head_count(user)
    heads = [[heads, 2].max, 3].min

    damaged_targets = MultiHeaded.valid_damaged_targets(targets)

    # Like Parental Bond, only apply to single-target successful hits.
    next if damaged_targets.length != 1

    target = damaged_targets[0]
    base_damage = target.damageState.totalHPLost
    next if base_damage <= 0

    battle.pbShowAbilitySplash(user)

    extra_hits = heads - 1
    extra_hits.times do |i|
      break if target.fainted?
      MultiHeaded.extra_hit(user, target, battle, move, base_damage, heads, i + 2)
    end

    battle.pbHideAbilitySplash(user)
  }
)

#===============================================================================
# Cursed Surge + Cursed Terrain
# Pokemon Essentials v21.1
#===============================================================================

module CursedTerrain
  TERRAIN_ID = :Cursed
  MOVE_ID    = :CURSEDTERRAIN
  DURATION   = 5
  GHOST_MULT = 1.3

  #=============================================================================
  # Basic helpers
  #=============================================================================

  def self.field_terrain(battle)
    return nil if !battle || !battle.field
    begin
      return battle.field.terrain
    rescue
      return nil
    end
  end

  def self.set_field_terrain(battle, terrain)
    return if !battle || !battle.field
    begin
      battle.field.terrain = terrain
    rescue
    end
  end

  def self.duration(battle)
    return 0 if !battle || !battle.field
    return battle.field.instance_variable_get(:@cursed_terrain_duration).to_i
  end

  def self.set_duration(battle, value)
    return if !battle || !battle.field

    value = value.to_i
    battle.field.instance_variable_set(:@cursed_terrain_duration, value)

    begin
      battle.field.terrainDuration = value
    rescue
    end
  end

  def self.active?(battle)
    return false if !battle || !battle.field

    terrain = field_terrain(battle)
    return true if terrain == TERRAIN_ID

    # Nếu terrain khác đang tồn tại, Cursed Terrain không active.
    return false if terrain

    # Fallback nếu custom terrain symbol không được field.terrain lưu đúng.
    return duration(battle) > 0
  end

  def self.grounded?(battler)
    return false if !battler
    return battler.affectedByTerrain? if battler.respond_to?(:affectedByTerrain?)
    return !battler.airborne? if battler.respond_to?(:airborne?)
    return true
  end

  def self.ghost_or_dark?(battler)
    return false if !battler
    return true if battler.pbHasType?(:GHOST)
    return true if battler.pbHasType?(:DARK)
    return false
  end

  def self.blocks_healing?(battler)
    return false if !battler || !battler.battle
    return false if !active?(battler.battle)
    return false if !grounded?(battler)
    return false if ghost_or_dark?(battler)
    return true
  end

  #=============================================================================
  # Animation
  #=============================================================================

  def self.animation_user(battle)
    return nil if !battle

    battle.allBattlers.each do |b|
      next if !b
      next if b.fainted?
      return b
    end

    return nil
  end

  def self.play_animation(battle, user)
    return false if !battle || !user

    # Dùng đúng animation của move CURSEDTERRAIN, giống khi dùng move thật.
    begin
      pkmn_move = Pokemon::Move.new(MOVE_ID)
      battle_move = Battle::Move.from_pokemon_move(battle, pkmn_move)
      battle_move.pbShowAnimation(MOVE_ID, user, [user], 0, true)
      return true
    rescue
    end

    # Fallback nếu signature pbShowAnimation của project khác.
    begin
      pkmn_move = Pokemon::Move.new(MOVE_ID)
      battle_move = Battle::Move.from_pokemon_move(battle, pkmn_move)
      battle_move.pbShowAnimation(MOVE_ID, user, [user])
      return true
    rescue
    end

    # Fallback Common Animation nếu bạn tự tạo.
    ["CursedTerrainField", "Cursed Terrain Field",
     "CursedTerrain", "Cursed Terrain", "CURSEDTERRAIN"].each do |anim_name|
      begin
        battle.pbCommonAnimation(anim_name, user)
        return true
      rescue
      end
    end

    return false
  end

  def self.play_field_animation(battle)
    user = animation_user(battle)
    return false if !user
    return play_animation(battle, user)
  end

  #=============================================================================
  # Start / refresh terrain
  #=============================================================================

  def self.duration_with_item(battle, user)
    ret = DURATION

    if user &&
       user.respond_to?(:itemActive?) &&
       user.itemActive? &&
       defined?(Battle::ItemEffects)
      begin
        ret = Battle::ItemEffects.triggerTerrainExtender(
          user.item, TERRAIN_ID, ret, user, battle
        )
      rescue
        ret = DURATION
      end
    end

    return ret || DURATION
  end

  def self.start(battle, user = nil, from_ability = false, play_anim = false)
    return false if !battle || !battle.field

    old_terrain = field_terrain(battle)
    new_duration = duration_with_item(battle, user)

    if from_ability && user
      battle.pbShowAbilitySplash(user)
      battle.pbHideAbilitySplash(user)
    end

    set_field_terrain(battle, TERRAIN_ID)
    set_duration(battle, new_duration)

    # Chỉ tự gọi animation khi ability dựng terrain hoặc khi được yêu cầu.
    # Khi dùng move Cursed Terrain, engine đã tự chạy move animation rồi.
    play_animation(battle, user) if play_anim && user

    if old_terrain == TERRAIN_ID
      battle.pbDisplay(_INTL("The cursed terrain was refreshed!"))
    else
      battle.pbDisplay(_INTL("The battlefield became cursed!"))
    end

    return true
  end

  def self.tick_down(battle)
    return if !battle || !battle.field

    current_duration = duration(battle)
    return if current_duration <= 0

    terrain = field_terrain(battle)

    # Nếu terrain khác thay thế Cursed Terrain, dừng duration phụ.
    if terrain && terrain != TERRAIN_ID
      set_duration(battle, 0)
      return
    end

    current_duration -= 1
    set_duration(battle, current_duration)

    if current_duration <= 0
      set_field_terrain(battle, nil) if field_terrain(battle) == TERRAIN_ID
      battle.pbDisplay(_INTL("The cursed terrain disappeared."))
    else
      # Terrain còn hiệu lực thì phát lại animation cuối lượt.
      play_field_animation(battle)
    end
  end

  #=============================================================================
  # Phantom Force / Shadow Force helper
  #=============================================================================

  def self.phantom_shadow_force?(move)
    return false if !move

    move_id = nil
    begin
      move_id = move.id
    rescue
      move_id = nil
    end

    return true if [:PHANTOMFORCE, :SHADOWFORCE].include?(move_id)

    code = ""
    begin
      code = move.function_code.to_s.upcase
    rescue
      code = ""
    end

    return true if code.include?("PHANTOMFORCE")
    return true if code.include?("SHADOWFORCE")
    return false
  end

  def self.quick_execute_shadow_move?(move, user)
    return false if !move || !user || !user.battle
    return false if !active?(user.battle)
    return false if !grounded?(user)
    return false if !phantom_shadow_force?(move)
    return true
  end
end

#===============================================================================
# Ability: Cursed Surge
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:CURSEDSURGE,
  proc { |ability, battler, battle, switch_in|
    CursedTerrain.start(battle, battler, true, true)
  }
)

# Safety aliases nếu lỡ đặt nhầm ability ID.
Battle::AbilityEffects::OnSwitchIn.add(:CURSESURGE,
  proc { |ability, battler, battle, switch_in|
    CursedTerrain.start(battle, battler, true, true)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:CURRSEDSURGE,
  proc { |ability, battler, battle, switch_in|
    CursedTerrain.start(battle, battler, true, true)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:CURSEDTERRAIN,
  proc { |ability, battler, battle, switch_in|
    CursedTerrain.start(battle, battler, true, true)
  }
)

#===============================================================================
# Move effect: Cursed Terrain
# PBS:
#   FunctionCode = StartCursedTerrain
#===============================================================================

class Battle::Move::StartCursedTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    # Không fail. Nếu Cursed Terrain đang active thì refresh duration.
    return false
  end

  def pbEffectGeneral(user)
    # Không tự play animation ở đây, vì move animation đã được engine gọi.
    CursedTerrain.start(@battle, user, false, false)
  end
end

# Typo support: FunctionCode = StartCurrsedTerrain
class Battle::Move::StartCurrsedTerrain < Battle::Move::StartCursedTerrain
end

#===============================================================================
# Ghost-type damage boost under Cursed Terrain
#===============================================================================

class Battle::Move
  if !method_defined?(:cursed_terrain_clean_pbCalcDamageMultipliers)
    alias cursed_terrain_clean_pbCalcDamageMultipliers pbCalcDamageMultipliers
  end

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    cursed_terrain_clean_pbCalcDamageMultipliers(
      user, target, numTargets, type, baseDmg, multipliers
    )

    if CursedTerrain.active?(@battle) &&
       type == :GHOST &&
       CursedTerrain.grounded?(user)
      multipliers[:power_multiplier] *= CursedTerrain::GHOST_MULT
    end
  end
end

#===============================================================================
# Healing prevention
#===============================================================================

class Battle::Battler
  if !method_defined?(:cursed_terrain_clean_canHeal)
    alias cursed_terrain_clean_canHeal canHeal?
  end

  def canHeal?
    return false if CursedTerrain.blocks_healing?(self)
    return cursed_terrain_clean_canHeal
  end

  if !method_defined?(:cursed_terrain_clean_pbRecoverHP)
    alias cursed_terrain_clean_pbRecoverHP pbRecoverHP
  end

  def pbRecoverHP(*args)
    if CursedTerrain.blocks_healing?(self)
      battle.pbDisplay(_INTL("{1} couldn't heal because of the cursed terrain!", pbThis))
      return 0
    end

    return cursed_terrain_clean_pbRecoverHP(*args)
  end
end

#===============================================================================
# Phantom Force / Shadow Force immediate execution
#===============================================================================

module CursedTerrain_TwoTurnPatch
  def pbIsChargingTurn?(user)
    return false if CursedTerrain.quick_execute_shadow_move?(self, user)
    return super
  end

  def pbDisplayChargeMessage(user)
    return if CursedTerrain.quick_execute_shadow_move?(self, user)
    super
  end
end

ObjectSpace.each_object(Class) do |klass|
  next if !defined?(Battle::Move)
  next if !(klass < Battle::Move)
  next if !klass.method_defined?(:pbIsChargingTurn?)
  next if klass.ancestors.include?(CursedTerrain_TwoTurnPatch)

  klass.prepend(CursedTerrain_TwoTurnPatch)
end

#===============================================================================
# Backup duration countdown
#===============================================================================

class Battle
  if method_defined?(:pbEndOfRoundPhase) &&
     !method_defined?(:cursed_terrain_clean_pbEndOfRoundPhase)
    alias cursed_terrain_clean_pbEndOfRoundPhase pbEndOfRoundPhase
  end

  def pbEndOfRoundPhase
    cursed_terrain_clean_pbEndOfRoundPhase

    CursedTerrain.tick_down(self) if CursedTerrain.active?(self)
  end
end

#===============================================================================
# Stealth
# Pokemon Essentials v21.1
#
# Effect:
#   The first time this Pokemon enters battle, it vanishes.
#   While vanished:
#     - It avoids entry hazards on switch-in.
#     - It avoids attacks/moves from opposing Pokemon.
#   After it uses any move, it reappears.
#
# Extra:
#   If it uses Phantom Force or Shadow Force while vanished, the move is executed
#   immediately and ignores its first-turn charge.
#===============================================================================

module StealthAbility
  ABILITY = :STEALTH

  HAZARDS = {
    :StealthRock => false,
    :Spikes      => 0,
    :ToxicSpikes => 0,
    :StickyWeb   => false,
    :Steelsurge  => false
  }

  #-----------------------------------------------------------------------------
  # Battle/Pokemon tracking
  #-----------------------------------------------------------------------------

  def self.pokemon_key(battler)
    return nil if !battler || !battler.pokemon
    return battler.pokemon.object_id
  end

  def self.used_hash(battle)
    hash = battle.instance_variable_get(:@stealth_ability_used)
    if !hash
      hash = {}
      battle.instance_variable_set(:@stealth_ability_used, hash)
    end
    return hash
  end

  def self.used?(battler)
    return true if !battler || !battler.battle
    key = pokemon_key(battler)
    return true if !key
    return used_hash(battler.battle)[key] == true
  end

  def self.mark_used(battler)
    return if !battler || !battler.battle
    key = pokemon_key(battler)
    return if !key
    used_hash(battler.battle)[key] = true
  end

  def self.can_activate?(battler)
    return false if !battler
    return false if battler.fainted?
    return false if used?(battler)
    return false if !battler.hasActiveAbility?(ABILITY)
    return true
  end

  #-----------------------------------------------------------------------------
  # Vanish/reappear state
  #-----------------------------------------------------------------------------

  def self.vanished?(battler)
    return false if !battler
    return battler.instance_variable_get(:@stealth_vanished) == true
  end

  def self.set_vanished(battler, value)
    return if !battler
    battler.instance_variable_set(:@stealth_vanished, value)
  end

  def self.activate(battler, show_message = true)
    return false if !can_activate?(battler)

    mark_used(battler)
    set_vanished(battler, true)

    battle = battler.battle

    if show_message
      battle.pbShowAbilitySplash(battler)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} vanished into the shadows!", battler.pbThis))
      else
        battle.pbDisplay(_INTL("{1}'s {2} made it vanish into the shadows!",
          battler.pbThis, battler.abilityName))
      end
      battle.pbHideAbilitySplash(battler)
    end

    return true
  end

  def self.reappear(battler, show_message = true)
    return false if !vanished?(battler)

    set_vanished(battler, false)

    return true if !show_message
    return true if battler.fainted?

    battle = battler.battle
    battle.pbDisplay(_INTL("{1} reappeared!", battler.pbThis))
    return true
  end

  #-----------------------------------------------------------------------------
  # Entry hazard suppression
  #-----------------------------------------------------------------------------

  def self.effect_key(effect_name)
    return nil if !PBEffects.const_defined?(effect_name)
    return PBEffects.const_get(effect_name)
  end

  def self.suppress_hazards_for_entry(battler)
    side = battler.pbOwnSide
    stored = {}

    HAZARDS.each do |effect_name, empty_value|
      effect = effect_key(effect_name)
      next if effect.nil?
      stored[effect] = side.effects[effect]
      side.effects[effect] = empty_value
    end

    return stored
  end

  def self.restore_hazards_after_entry(battler, stored)
    return if !battler || !stored
    side = battler.pbOwnSide
    stored.each do |effect, value|
      side.effects[effect] = value
    end
  end

  #-----------------------------------------------------------------------------
  # Phantom Force / Shadow Force
  #-----------------------------------------------------------------------------

  def self.phantom_shadow_force?(move)
    return false if !move

    move_id = nil
    begin
      move_id = move.id
    rescue
      move_id = nil
    end

    return true if [:PHANTOMFORCE, :SHADOWFORCE].include?(move_id)

    code = ""
    begin
      code = move.function_code.to_s.upcase
    rescue
      code = ""
    end

    return true if code.include?("PHANTOMFORCE")
    return true if code.include?("SHADOWFORCE")
    return false
  end

  def self.skip_charge_turn?(move, user)
    return false if !user
    return false if !vanished?(user)
    return false if !phantom_shadow_force?(move)
    return true
  end
end

# Activate before entry hazards are processed
# pbOnBattlerEnteringBattle is the safest hook because hazards and switch-in
# effects are usually handled inside this switch-in flow.

class Battle
  if method_defined?(:pbOnBattlerEnteringBattle) &&
     !method_defined?(:stealth_ability_safe_pbOnBattlerEnteringBattle)
    alias stealth_ability_safe_pbOnBattlerEnteringBattle pbOnBattlerEnteringBattle
  end

  def pbOnBattlerEnteringBattle(idxBattler, *args)
    # Some projects pass an Array of battler indexes here.
    battler_indexes = idxBattler.is_a?(Array) ? idxBattler : [idxBattler]

    stealth_battlers = []
    stored_hazards = {}

    battler_indexes.each do |idx|
      next if !idx.is_a?(Integer)
      battler = @battlers[idx]
      next if !StealthAbility.can_activate?(battler)

      StealthAbility.activate(battler, true)
      stealth_battlers.push(battler)
      stored_hazards[battler.index] = StealthAbility.suppress_hazards_for_entry(battler)
    end

    begin
      ret = stealth_ability_safe_pbOnBattlerEnteringBattle(idxBattler, *args)
    ensure
      stealth_battlers.each do |battler|
        next if !battler
        StealthAbility.restore_hazards_after_entry(
          battler,
          stored_hazards[battler.index]
        )
      end
    end

    return ret
  end
end
# Fallback OnSwitchIn handler
# If another plugin changes the switch-in flow and the Battle patch above misses,
# this still lets Stealth activate. It may be after hazards, but it prevents the
# ability from doing nothing.


Battle::AbilityEffects::OnSwitchIn.add(:STEALTH,
  proc { |ability, battler, battle, switch_in|
    StealthAbility.activate(battler, true)
  }
)

# Avoid attacks while vanished

Battle::AbilityEffects::MoveImmunity.add(:STEALTH,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if !StealthAbility.vanished?(target)
    next false if !user
    next false if !user.opposes?(target)

    if show_message
      battle.pbShowAbilitySplash(target)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} avoided the attack while vanished!", target.pbThis))
      else
        battle.pbDisplay(_INTL("{1} avoided the attack with {2}!",
          target.pbThis, target.abilityName))
      end
      battle.pbHideAbilitySplash(target)
    end

    next true
  }
)

# Reappear after using any move

class Battle::Battler
  if !method_defined?(:stealth_ability_pbEndTurn)
    alias stealth_ability_pbEndTurn pbEndTurn
  end

  def pbEndTurn(choice)
    stealth_ability_pbEndTurn(choice)

    # Reappear after attempting to use any move, even if the move failed.
    if choice && choice[0] == :UseMove
      StealthAbility.reappear(self, true)
    end
  end

  if method_defined?(:pbAbilitiesOnSwitchOut) &&
     !method_defined?(:stealth_ability_pbAbilitiesOnSwitchOut)
    alias stealth_ability_pbAbilitiesOnSwitchOut pbAbilitiesOnSwitchOut
  end

  def pbAbilitiesOnSwitchOut(*args)
    StealthAbility.reappear(self, false)
    return stealth_ability_pbAbilitiesOnSwitchOut(*args)
  end
end

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:stealth_ability_pbGetMoveScore)
      alias stealth_ability_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = stealth_ability_pbGetMoveScore(*args)

      move = nil
      user = nil
      target = nil

      args.each do |arg|
        if arg.respond_to?(:damagingMove?) || arg.respond_to?(:pbDamagingMove?)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) && arg.respond_to?(:opposes?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end

      if score.is_a?(Numeric) &&
         user &&
         target &&
         user.opposes?(target) &&
         StealthAbility.vanished?(target)
        score -= 80
        PBDebug.log_ai("     - Target is vanished by Stealth: 80") if defined?(PBDebug)
      end

      return score
    end
  end
end

#===============================================================================
# Dreamcatcher
# Pokemon Essentials v21.1
#
# Effect:
#   Damage is increased by 30% if any active Pokemon on the field is asleep.
#
# Notes:
#   - Counts any active battler: user, ally, or foe.
#   - Does not count fainted Pokemon.
#   - Only boosts damaging moves.
#   - Boost is x1.3 final damage.
#===============================================================================

module Dreamcatcher
  DAMAGE_MULTIPLIER = 1.5

  def self.asleep_on_field?(battle)
    return false if !battle

    battle.allBattlers.each do |battler|
      next if !battler
      next if battler.fainted?
      return true if battler.asleep?
    end

    return false
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::DamageCalcFromUser.add(:DREAMCATCHER,
  proc { |ability, user, target, move, mults, power, type|
    next if !move.pbDamagingMove?
    next if !Dreamcatcher.asleep_on_field?(user.battle)

    mults[:final_damage_multiplier] *= Dreamcatcher::DAMAGE_MULTIPLIER
  }
)

#===============================================================================
# Optional AI support
#===============================================================================

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:dreamcatcher_pbGetMoveScore)
      alias dreamcatcher_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = dreamcatcher_pbGetMoveScore(*args)

      move = nil
      user = nil

      args.each do |arg|
        if arg.respond_to?(:pbDamagingMove?) || arg.respond_to?(:damagingMove?)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) && arg.respond_to?(:battle)
          user = arg if user.nil?
        end
      end

      if score.is_a?(Numeric) &&
         user &&
         move &&
         user.hasActiveAbility?(:DREAMCATCHER) &&
         Dreamcatcher.asleep_on_field?(user.battle)
        is_damaging = move.respond_to?(:pbDamagingMove?) ? move.pbDamagingMove? : move.damagingMove?
        if is_damaging
          score += 20
          PBDebug.log_ai("     + Dreamcatcher boosts damage: 20") if defined?(PBDebug)
        end
      end

      return score
    end
  end
end

#===============================================================================
# Chaos Space
# Pokemon Essentials v21.1
#
# Effect:
#   When this Pokemon enters battle, it creates Trick Room for 4 turns.
#
# Notes:
#   - Uses battle.field.effects[PBEffects::TrickRoom].
#   - Compatible with Room Service and normal Trick Room checks.
#   - If Trick Room is already active, this refreshes it to 4 turns.
#===============================================================================

module ChaosSpace
  DURATION = 3

  def self.trick_room_active?(battle)
    return false if !battle || !battle.field
    return battle.field.effects[PBEffects::TrickRoom].to_i > 0
  end

  def self.start(battle, user, from_ability = true)
    return false if !battle || !battle.field

    old_duration = battle.field.effects[PBEffects::TrickRoom].to_i

    battle.pbShowAbilitySplash(user) if from_ability && user

    battle.field.effects[PBEffects::TrickRoom] = DURATION

    if old_duration > 0
      battle.pbDisplay(_INTL("The twisted dimensions were refreshed!"))
    else
      battle.pbDisplay(_INTL("The dimensions were twisted!"))
    end

    battle.pbHideAbilitySplash(user) if from_ability && user
    return true
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:CHAOSSPACE,
  proc { |ability, battler, battle, switch_in|
    ChaosSpace.start(battle, battler, true)
  }
)

#===============================================================================
# Optional AI support
#===============================================================================
# Helps AI value switching in Chaos Space if Trick Room is not active.
#===============================================================================

if defined?(Battle::AI) && Battle::AI.method_defined?(:rate_replacement_pokemon)
  class Battle::AI
    if !method_defined?(:chaos_space_rate_replacement_pokemon)
      alias chaos_space_rate_replacement_pokemon rate_replacement_pokemon
    end

    def rate_replacement_pokemon(idxBattler, pkmn, score)
      score = chaos_space_rate_replacement_pokemon(idxBattler, pkmn, score)

      if pkmn.hasAbility?(:CHAOSSPACE) &&
         !ChaosSpace.trick_room_active?(@battle)
        score += 25
        PBDebug.log_ai("     + Chaos Space can create Trick Room: 25") if defined?(PBDebug)
      end

      return score
    end
  end
end

#===============================================================================
# Comatose Plus
# Pokemon Essentials v21.1
#
# Added effect:
#   While the Pokemon is asleep/drowsing, damage taken is reduced by 20%.
#
# Notes:
#   - Damage taken becomes x0.8.
#   - Because Comatose means the Pokemon is always drowsing, this effect is active
#     whenever Comatose is active.
#===============================================================================

module ComatosePlus
  DAMAGE_MULTIPLIER = 0.8

  def self.asleep_or_drowsing?(battler)
    return false if !battler

    # Real sleep status.
    return true if battler.respond_to?(:asleep?) && battler.asleep?

    # Comatose pseudo-sleep/drowsing state.
    return true if battler.hasActiveAbility?(:COMATOSE)

    return false
  end
end

Battle::AbilityEffects::DamageCalcFromTarget.add(:COMATOSE,
  proc { |ability, user, target, move, mults, power, type|
    next if !ComatosePlus.asleep_or_drowsing?(target)

    # Reduce final damage by 20%.
    mults[:final_damage_multiplier] *= ComatosePlus::DAMAGE_MULTIPLIER
  }
)

#===============================================================================
# Liquify
# Pokemon Essentials v21.1
#
# Effect:
#   - Reduces damage taken from contact moves by 1/3.
#     Damage becomes x2/3.
#
#   - Increases damage taken from Water-type moves by 1/3.
#     Damage becomes x4/3.
#
# Notes:
#   - If a move is both Water-type and contact, both modifiers apply.
#   - Uses DamageCalcFromTarget, same style as defensive abilities like Fluffy.
#===============================================================================

module Liquify
  CONTACT_DAMAGE_MULTIPLIER = 2.0 / 3.0
  WATER_DAMAGE_MULTIPLIER   = 4.0 / 3.0

  def self.contact_move?(move, user)
    return false if !move
    begin
      return move.pbContactMove?(user)
    rescue
      begin
        return move.contactMove?
      rescue
        return false
      end
    end
  end

  def self.water_type?(type, move = nil)
    return true if type == :WATER

    begin
      return true if move && move.calcType == :WATER
    rescue
    end

    return false
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::DamageCalcFromTarget.add(:LIQUIFY,
  proc { |ability, user, target, move, mults, power, type|
    # Contact damage reduction.
    if Liquify.contact_move?(move, user)
      mults[:final_damage_multiplier] *= Liquify::CONTACT_DAMAGE_MULTIPLIER
    end

    # Water-type damage weakness.
    if Liquify.water_type?(type, move)
      mults[:final_damage_multiplier] *= Liquify::WATER_DAMAGE_MULTIPLIER
    end
  }
)

#===============================================================================
# Optional AI support
#===============================================================================

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:liquify_pbGetMoveScore)
      alias liquify_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = liquify_pbGetMoveScore(*args)

      move = nil
      user = nil
      target = nil

      args.each do |arg|
        if arg.respond_to?(:pbContactMove?) || arg.respond_to?(:contactMove?) ||
           arg.respond_to?(:calcType)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) && arg.respond_to?(:opposes?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end

      if score.is_a?(Numeric) &&
         move &&
         user &&
         target &&
         target.hasActiveAbility?(:LIQUIFY)
        if Liquify.contact_move?(move, user)
          score -= 20
          PBDebug.log_ai("     - Target's Liquify resists contact damage: 20") if defined?(PBDebug)
        end

        if Liquify.water_type?(nil, move)
          score += 20
          PBDebug.log_ai("     + Target's Liquify is weak to Water damage: 20") if defined?(PBDebug)
        end
      end

      return score
    end
  end
end

#===============================================================================
# Sweet Dreams Fix
# Heals sleeping Pokemon, including Pokemon with Innate Comatose.
#===============================================================================

module SweetDreamsFix
  SWEET_DREAMS = :SWEETDREAMS
  COMATOSE     = :COMATOSE
  HEAL_DENOM   = 12
  DEBUG        = false

  def self.normalize_ability_id(value)
    return "" if value.nil?
    return value.id.to_s.upcase.gsub(/[^A-Z0-9]/, "") if value.respond_to?(:id)
    return value.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def self.same_ability?(value, ability)
    return normalize_ability_id(value) == normalize_ability_id(ability)
  end

  def self.call_ability_check(obj, method_name, ability)
    return false if !obj || !obj.respond_to?(method_name)

    begin
      return true if obj.send(method_name, ability)
    rescue
    end

    begin
      return true if obj.send(method_name, [ability])
    rescue
    end

    return false
  end

  def self.object_contains_ability?(obj, ability, depth = 0)
    return false if obj.nil?
    return false if depth > 3

    return true if same_ability?(obj, ability)

    if obj.is_a?(Array)
      obj.each do |v|
        return true if object_contains_ability?(v, ability, depth + 1)
      end
    elsif obj.is_a?(Hash)
      obj.each do |k, v|
        return true if object_contains_ability?(k, ability, depth + 1)
        return true if object_contains_ability?(v, ability, depth + 1)
      end
    elsif obj.respond_to?(:id)
      return true if same_ability?(obj.id, ability)
    end

    return false
  end

  def self.scan_instance_variables_for_ability?(obj, ability)
    return false if !obj

    obj.instance_variables.each do |ivar|
      begin
        value = obj.instance_variable_get(ivar)
        return true if object_contains_ability?(value, ability)
      rescue
      end
    end

    return false
  end

  def self.has_ability_or_innate?(battler, ability)
    return false if !battler

    # Normal active ability.
    return true if call_ability_check(battler, :hasActiveAbility?, ability)
    return true if call_ability_check(battler, :hasAbility?, ability)

    # Common innate ability plugin method names.
    [
      :hasInnateAbility?,
      :hasActiveInnateAbility?,
      :hasInnate?,
      :hasActiveInnate?,
      :pbHasInnateAbility?,
      :innateAbility?,
      :hasExtraAbility?,
      :hasActiveExtraAbility?
    ].each do |method_name|
      return true if call_ability_check(battler, method_name, ability)
    end

    # Some plugins store innates on battler or Pokemon instance variables.
    return true if scan_instance_variables_for_ability?(battler, ability)

    begin
      return true if battler.pokemon &&
                     scan_instance_variables_for_ability?(battler.pokemon, ability)
    rescue
    end

    return false
  end

  def self.asleep_or_comatose?(battler)
    return false if !battler
    return true if battler.asleep?
    return true if has_ability_or_innate?(battler, COMATOSE)
    return false
  end

  def self.sweet_dreams_user?(battler)
    return has_ability_or_innate?(battler, SWEET_DREAMS)
  end

  def self.trigger_for_user(battler, battle)
    return if !battler || battler.fainted?
    return if !sweet_dreams_user?(battler)

    targets = []
    battle.allBattlers.each do |b|
      next if !b
      next if b.fainted?
      next if !asleep_or_comatose?(b)
      next if !b.canHeal?
      targets.push(b)
    end

    return if targets.empty?

    battle.pbShowAbilitySplash(battler)

    targets.each do |b|
      amount = [1, b.totalhp / HEAL_DENOM].max
      healed = b.pbRecoverHP(amount)

      next if healed && healed <= 0

      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} is relaxed!", b.pbThis))
      else
        battle.pbDisplay(_INTL("{1} is relaxed by {2}'s {3}!",
          b.pbThis, battler.pbThis(true), battler.abilityName))
      end
    end

    battle.pbHideAbilitySplash(battler)
  end

  def self.trigger_all(battle)
    return if !battle

    battle.allBattlers.each do |battler|
      trigger_for_user(battler, battle)
    end
  end
end

#===============================================================================
# End of round hook
#===============================================================================

class Battle
  if method_defined?(:pbEndOfRoundPhase) &&
     !method_defined?(:sweet_dreams_fix_pbEndOfRoundPhase)
    alias sweet_dreams_fix_pbEndOfRoundPhase pbEndOfRoundPhase
  end

  def pbEndOfRoundPhase(*args)
    ret = sweet_dreams_fix_pbEndOfRoundPhase(*args)

    SweetDreamsFix.trigger_all(self)

    return ret
  end
end

#===============================================================================
# Spellcaster
# Pokemon Essentials v21.1
#
# Effect:
#   Increases damage of Fire-, Ice-, Electric-, and Psychic-type moves by 25%.
#   This boost does not activate if the target is Dark-type.
#
# Notes:
#   - Uses calculated move type via the `type` parameter.
#   - Dark-type targets are NOT immune; they simply ignore the Spellcaster boost.
#===============================================================================

module SpellcasterAbility
  BOOST_MULTIPLIER = 1.25
  BOOST_TYPES = [:FIRE, :ICE, :ELECTRIC, :PSYCHIC]

  def self.boosted_type?(type)
    return BOOST_TYPES.include?(type)
  end

  def self.target_is_dark?(target)
    return false if !target
    return target.pbHasType?(:DARK)
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::DamageCalcFromUser.add(:SPELLCASTER,
  proc { |ability, user, target, move, mults, power, type|
    next if !SpellcasterAbility.boosted_type?(type)

    # No boost against Dark-type targets.
    next if SpellcasterAbility.target_is_dark?(target)

    mults[:power_multiplier] *= SpellcasterAbility::BOOST_MULTIPLIER
  }
)

#===============================================================================
# Optional AI support
#===============================================================================

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:spellcaster_pbGetMoveScore)
      alias spellcaster_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = spellcaster_pbGetMoveScore(*args)

      move = nil
      user = nil
      target = nil

      args.each do |arg|
        if arg.respond_to?(:calcType) || arg.respond_to?(:type)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) && arg.respond_to?(:opposes?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end

      if score.is_a?(Numeric) &&
         user &&
         move &&
         user.hasActiveAbility?(:SPELLCASTER)
        move_type = nil

        begin
          move_type = move.calcType
        rescue
          begin
            move_type = move.type
          rescue
            move_type = nil
          end
        end

        if SpellcasterAbility.boosted_type?(move_type)
          if target && SpellcasterAbility.target_is_dark?(target)
            score -= 5
            PBDebug.log_ai("     - Spellcaster boost blocked by Dark-type target: 5") if defined?(PBDebug)
          else
            score += 20
            PBDebug.log_ai("     + Spellcaster boosts this move: 20") if defined?(PBDebug)
          end
        end
      end

      return score
    end
  end
end

#===============================================================================
# Carrion Feast
# Pokemon Essentials v21.1
#
# Effect:
#   - Reduces damage taken from super-effective moves by 25%.
#     Damage becomes x0.75.
#
#   - When this Pokemon KO's an opposing Pokemon with a move, it restores
#     25% of its maximum HP.
#
# Notes:
#   - The defensive effect works like Filter/Solid Rock.
#   - The healing effect triggers at the end of using a move.
#   - In double battles, if it KO's multiple foes at once, it heals once per foe.
#===============================================================================

module CarrionFeast
  DAMAGE_MULTIPLIER = 0.75
  HEAL_FRACTION     = 5

  def self.heal_amount(user)
    return [1, user.totalhp / HEAL_FRACTION].max
  end

  def self.fainted_foes_from_move(user, targets)
    count = 0

    targets.each do |target|
      next if !target
      next if !target.opposes?(user)
      next if !target.damageState.fainted
      count += 1
    end

    return count
  end

  def self.heal_after_ko(user, battle, count)
    return if count <= 0
    return if !user
    return if user.fainted?
    return if !user.canHeal?

    battle.pbShowAbilitySplash(user)

    count.times do
      break if !user.canHeal?

      hp_healed = user.pbRecoverHP(heal_amount(user))

      next if hp_healed <= 0

      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} restored HP from the fallen foe!", user.pbThis))
      else
        battle.pbDisplay(_INTL("{1}'s {2} restored its HP from the fallen foe!",
          user.pbThis, user.abilityName))
      end
    end

    battle.pbHideAbilitySplash(user)
  end
end

#===============================================================================
# Reduce super-effective damage by 25%
#===============================================================================

Battle::AbilityEffects::DamageCalcFromTarget.add(:CARRIONFEAST,
  proc { |ability, user, target, move, mults, power, type|
    next if !Effectiveness.super_effective?(target.damageState.typeMod)

    mults[:final_damage_multiplier] *= CarrionFeast::DAMAGE_MULTIPLIER
  }
)

#===============================================================================
# Heal 25% HP after KOing opposing Pokemon
#===============================================================================

Battle::AbilityEffects::OnEndOfUsingMove.add(:CARRIONFEAST,
  proc { |ability, user, targets, move, battle|
    next if battle.pbAllFainted?(user.idxOpposingSide)
    next if user.fainted?

    num_fainted = CarrionFeast.fainted_foes_from_move(user, targets)
    next if num_fainted <= 0

    CarrionFeast.heal_after_ko(user, battle, num_fainted)
  }
)

#===============================================================================
# Optional AI support
#===============================================================================

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:carrion_feast_pbGetMoveScore)
      alias carrion_feast_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = carrion_feast_pbGetMoveScore(*args)

      move = nil
      user = nil
      target = nil

      args.each do |arg|
        if arg.respond_to?(:pbDamagingMove?) || arg.respond_to?(:damagingMove?)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) && arg.respond_to?(:opposes?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end

      if score.is_a?(Numeric) &&
         user &&
         move &&
         user.hasActiveAbility?(:CARRIONFEAST)
        is_damaging = move.respond_to?(:pbDamagingMove?) ? move.pbDamagingMove? : move.damagingMove?

        if is_damaging
          score += 8
          score += 12 if user.hp < user.totalhp
          PBDebug.log_ai("     + Carrion Feast can heal after KO: 20") if defined?(PBDebug)
        end
      end

      return score
    end
  end
end

#===============================================================================
# Ninja Style
# Pokemon Essentials v21.1
#
# Effect:
#   When this Pokemon uses Spikes or Toxic Spikes, it sets 2 layers at once.
#
# FunctionCode supported:
#   AddSpikesToFoeSide
#   AddToxicSpikesToFoeSide
#===============================================================================

module NinjaStyle
  ABILITY = :NINJASTYLE

  DATA = {
    :Spikes => {
      :effect => :Spikes,
      :max    => 3,
      :name   => "Spikes"
    },
    :ToxicSpikes => {
      :effect => :ToxicSpikes,
      :max    => 2,
      :name   => "Toxic Spikes"
    }
  }

  def self.effect_key(effect_name)
    return nil if !PBEffects.const_defined?(effect_name)
    return PBEffects.const_get(effect_name)
  end

  def self.foe_side(user)
    return user.pbOpposingSide if user.respond_to?(:pbOpposingSide)
    return user.battle.sides[user.idxOpposingSide]
  rescue
    return nil
  end

  def self.layer_count(user, hazard)
    data = DATA[hazard]
    return 0 if !data

    effect = effect_key(data[:effect])
    return 0 if !effect

    side = foe_side(user)
    return 0 if !side

    return side.effects[effect].to_i
  end

  def self.set_layer_count(user, hazard, value)
    data = DATA[hazard]
    return if !data

    effect = effect_key(data[:effect])
    return if !effect

    side = foe_side(user)
    return if !side

    side.effects[effect] = value
  end

  def self.apply_extra_layer(user, hazard, before_count, after_count)
    return if !user
    return if user.fainted?
    return if !user.hasActiveAbility?(ABILITY)

    data = DATA[hazard]
    return if !data

    max_layers = data[:max]

    # Move gốc phải thật sự rải thêm 1 lớp thì Ninja Style mới thêm lớp phụ.
    return if after_count <= before_count

    # Nếu move gốc đã đưa hazard lên max thì không thêm được nữa.
    return if after_count >= max_layers

    new_count = [after_count + 1, max_layers].min
    set_layer_count(user, hazard, new_count)

    battle = user.battle
    battle.pbShowAbilitySplash(user)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} set an extra layer!", data[:name]))
    else
      battle.pbDisplay(_INTL("{1}'s {2} set an extra layer of {3}!",
        user.pbThis, user.abilityName, data[:name]))
    end

    battle.pbHideAbilitySplash(user)
  end
end

#===============================================================================
# Patch Spikes: FunctionCode = AddSpikesToFoeSide
#===============================================================================

class Battle::Move::AddSpikesToFoeSide
  if !method_defined?(:ninja_style_spikes_pbEffectGeneral)
    alias ninja_style_spikes_pbEffectGeneral pbEffectGeneral
  end

  def pbEffectGeneral(user)
    before_count = NinjaStyle.layer_count(user, :Spikes)

    ret = ninja_style_spikes_pbEffectGeneral(user)

    after_count = NinjaStyle.layer_count(user, :Spikes)

    NinjaStyle.apply_extra_layer(user, :Spikes, before_count, after_count)

    return ret
  end
end

#===============================================================================
# Patch Toxic Spikes: FunctionCode = AddToxicSpikesToFoeSide
#===============================================================================

class Battle::Move::AddToxicSpikesToFoeSide
  if !method_defined?(:ninja_style_toxic_spikes_pbEffectGeneral)
    alias ninja_style_toxic_spikes_pbEffectGeneral pbEffectGeneral
  end

  def pbEffectGeneral(user)
    before_count = NinjaStyle.layer_count(user, :ToxicSpikes)

    ret = ninja_style_toxic_spikes_pbEffectGeneral(user)

    after_count = NinjaStyle.layer_count(user, :ToxicSpikes)

    NinjaStyle.apply_extra_layer(user, :ToxicSpikes, before_count, after_count)

    return ret
  end
end

#===============================================================================
# Brave Heart
# Pokemon Essentials v21.1
#
# Effect:
#   When an opposing Pokemon gains any stat stage, this Pokemon's Attack rises
#   by 1 stage.
#
# Notes:
#   - Triggers only if the stat gain actually happened.
#   - Triggers once per successful stat-raising call.
#   - Does not chain infinitely with opposing Brave Heart users.
#   - Includes basic support for Innate Abilities-style plugins.
#===============================================================================

module BraveHeart
  ABILITY = :BRAVEHEART

  def self.has_brave_heart?(battler)
    return false if !battler
    return false if battler.fainted?

    begin
      return true if battler.hasActiveAbility?(ABILITY)
    rescue
    end

    begin
      return true if battler.hasAbility?(ABILITY)
    rescue
    end

    # Innate Abilities plugin support.
    begin
      return true if battler.respond_to?(:abilityMutationList) &&
                     battler.abilityMutationList &&
                     battler.abilityMutationList.include?(ABILITY)
    rescue
    end

    [
      :hasInnateAbility?,
      :hasActiveInnateAbility?,
      :hasInnate?,
      :hasActiveInnate?,
      :pbHasInnateAbility?
    ].each do |method_name|
      begin
        return true if battler.respond_to?(method_name) &&
                       battler.send(method_name, ABILITY)
      rescue
      end
    end

    return false
  end

  def self.stat_stage(battler, stat)
    return 0 if !battler
    return battler.stages[stat].to_i
  rescue
    return 0
  end

  def self.trigger_for_stat_gain(stat_gainer, source = nil)
    return if !stat_gainer
    return if stat_gainer.fainted?

    battle = stat_gainer.battle
    return if !battle

    # Prevent Brave Heart from chaining into itself forever.
    return if battle.instance_variable_get(:@brave_heart_resolving)

    brave_users = []
    battle.allOtherSideBattlers(stat_gainer.index).each do |b|
      next if !has_brave_heart?(b)
      next if !b.pbCanRaiseStatStage?(:ATTACK, b)
      brave_users.push(b)
    end

    return if brave_users.empty?

    battle.instance_variable_set(:@brave_heart_resolving, true)

    brave_users.each do |b|
      battle.pbShowAbilitySplash(b)

      # Use ByAbility if available; fallback to normal stat raise.
      begin
        b.pbRaiseStatStageByAbility(:ATTACK, 1, b)
      rescue
        b.pbRaiseStatStage(:ATTACK, 1, b)
      end

      battle.pbHideAbilitySplash(b)
    end

    battle.instance_variable_set(:@brave_heart_resolving, false)
  ensure
    battle.instance_variable_set(:@brave_heart_resolving, false) if battle
  end
end

#===============================================================================
# Patch stat gain
#===============================================================================
# Most stat-raising effects eventually call pbRaiseStatStage.
# This checks whether the target's stat stage actually increased.
#===============================================================================

class Battle::Battler
  if !method_defined?(:brave_heart_pbRaiseStatStage)
    alias brave_heart_pbRaiseStatStage pbRaiseStatStage
  end

  def pbRaiseStatStage(stat, increment, user = nil, showAnim = true, *args)
    old_stage = BraveHeart.stat_stage(self, stat)

    ret = brave_heart_pbRaiseStatStage(stat, increment, user, showAnim, *args)

    new_stage = BraveHeart.stat_stage(self, stat)

    if new_stage > old_stage
      BraveHeart.trigger_for_stat_gain(self, user)
    end

    return ret
  end
end

#===============================================================================
# Teravolt / Turboblaze custom type addition
# - Teravolt: thêm Electric-type cho Pokemon sở hữu khi vào sân.
# - Turboblaze: thêm Fire-type cho Pokemon sở hữu khi vào sân.
# - Vẫn giữ vai trò Mold Breaker-style của ability vì ability ID vẫn là
#   :TERAVOLT / :TURBOBLAZE.
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:TERAVOLT,
  proc { |ability, battler, battle, switch_in|
    battle.pbShowAbilitySplash(battler)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} is radiating a bursting electric aura!", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} is radiating a bursting electric aura!",
         battler.pbThis, battler.abilityName))
    end

    if !battler.pbHasType?(:ELECTRIC)
      battler.pbAddType(:ELECTRIC)
      battle.pbDisplay(_INTL("{1} gained the Electric type!", battler.pbThis))
    end

    battle.pbHideAbilitySplash(battler)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:TURBOBLAZE,
  proc { |ability, battler, battle, switch_in|
    battle.pbShowAbilitySplash(battler)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} is radiating a blazing aura!", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} is radiating a blazing aura!",
         battler.pbThis, battler.abilityName))
    end

    if !battler.pbHasType?(:FIRE)
      battler.pbAddType(:FIRE)
      battle.pbDisplay(_INTL("{1} gained the Fire type!", battler.pbThis))
    end

    battle.pbHideAbilitySplash(battler)
  }
)

#===============================================================================
# Overwhelm
# - Damage-dealing Dragon-type moves used by this Pokemon can hit Fairy-type
#   Pokemon.
# - Blocks Intimidate.
# - Blocks Terror Sower.
#
# Ability ID mặc định: :OVERWHELM
# Nếu PBS của bạn dùng :OVERHELM thì đổi hằng bên dưới.
#===============================================================================

OVERWHELM_ABILITY = :OVERWHELM

#===============================================================================
# 1. Dragon-type damaging moves can hit Fairy-type Pokemon
#===============================================================================
class Battle::Move
  alias overwhelm_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:overwhelm_pbCalcTypeModSingle)

  def pbCalcTypeModSingle(moveType, defType, user, target)
    if user &&
       user.hasActiveAbility?(OVERWHELM_ABILITY) &&
       moveType == :DRAGON &&
       defType == :FAIRY &&
       self.damagingMove?
      # Dragon vs Fairy bình thường là 0x.
      # Overwhelm biến phần Fairy immunity thành neutral.
      # Nếu target là Fairy/Steel, kết quả cuối sẽ còn tính phần Steel resist.
      return Effectiveness.calculate_one(:NORMAL, :NORMAL)
    end

    return overwhelm_pbCalcTypeModSingle(moveType, defType, user, target)
  end
end

#===============================================================================
# 2. Blocks Intimidate
#===============================================================================
Battle::AbilityEffects::OnIntimidated.add(OVERWHELM_ABILITY,
  proc { |ability, battler, battle|
    battle.pbShowAbilitySplash(battler)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} cannot be intimidated!", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} prevents intimidation!",
                             battler.pbThis, battler.abilityName))
    end

    battle.pbHideAbilitySplash(battler)
    next true
  }
)

#===============================================================================
# 3. Terror Sower with Overwhelm check
# Đặt đoạn này SAU handler Terror Sower cũ, hoặc dùng đoạn này để thay handler cũ.
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:TERRORSOWER,
  proc { |ability, battler, battle, switch_in|
    affected = false

    battle.allOtherSideBattlers(battler.index).each do |b|
      next if !b || b.fainted?
      next if !b.near?(battler)

      # Overwhelm chặn Terror Sower.
      if b.hasActiveAbility?(OVERWHELM_ABILITY)
        battle.pbShowAbilitySplash(b)

        if Battle::Scene::USE_ABILITY_SPLASH
          battle.pbDisplay(_INTL("{1} is not terrified!", b.pbThis))
        else
          battle.pbDisplay(_INTL("{1}'s {2} blocks {3}'s Terror Sower!",
                                 b.pbThis, b.abilityName, battler.pbThis(true)))
        end

        battle.pbHideAbilitySplash(b)
        next
      end

      next if !b.pbCanLowerStatStage?(:SPECIAL_ATTACK, battler)

      battle.pbShowAbilitySplash(battler) if !affected
      affected = true
      b.pbLowerStatStageByAbility(:SPECIAL_ATTACK, 1, battler, false)
    end

    battle.pbHideAbilitySplash(battler) if affected
  }
)

#===============================================================================
# Juggernaut
# Pokemon Essentials v21.1
#
# Effect:
#   Damaging contact moves use 20% of the user's Defense stat in addition to
#   the default attacking stat for damage calculation only.
#
# Notes:
#   - Only works with damaging contact moves.
#   - Works by converting the added Defense into an attack_multiplier ratio.
#   - Defense stage modifiers are included.
#   - Some Defense-boosting items/abilities are included for the bonus portion.
#===============================================================================

module Juggernaut
  ABILITY = :JUGGERNAUT
  DEFENSE_PORTION = 0.20

  #-----------------------------------------------------------------------------
  # Ability / innate helper
  #-----------------------------------------------------------------------------

  def self.has_ability_or_innate?(battler, ability)
    return false if !battler

    begin
      return true if battler.hasActiveAbility?(ability)
    rescue
    end

    begin
      return true if battler.hasAbility?(ability)
    rescue
    end

    begin
      return true if battler.respond_to?(:abilityMutationList) &&
                     battler.abilityMutationList &&
                     battler.abilityMutationList.include?(ability)
    rescue
    end

    [
      :hasInnateAbility?,
      :hasActiveInnateAbility?,
      :hasInnate?,
      :hasActiveInnate?,
      :pbHasInnateAbility?,
      :hasExtraAbility?,
      :hasActiveExtraAbility?
    ].each do |method_name|
      begin
        return true if battler.respond_to?(method_name) &&
                       battler.send(method_name, ability)
      rescue
      end
    end

    return false
  end

  #-----------------------------------------------------------------------------
  # Move helper
  #-----------------------------------------------------------------------------

  def self.contact_move?(move, user)
    return false if !move

    begin
      return move.pbContactMove?(user)
    rescue
    end

    begin
      return move.contactMove?
    rescue
    end

    return false
  end

  def self.damaging_move?(move)
    return false if !move

    begin
      return move.pbDamagingMove?
    rescue
    end

    begin
      return move.damagingMove?
    rescue
    end

    return false
  end

  def self.can_apply?(user, move)
    return false if !user
    return false if user.fainted?
    return false if !damaging_move?(move)
    return false if !contact_move?(move, user)
    return true
  end

  #-----------------------------------------------------------------------------
  # Stat helpers
  #-----------------------------------------------------------------------------

  def self.raw_stat(battler, stat)
    case stat
    when :ATTACK
      return battler.attack
    when :DEFENSE
      return battler.defense
    when :SPECIAL_ATTACK
      return battler.spatk
    when :SPECIAL_DEFENSE
      return battler.spdef
    when :SPEED
      return battler.speed
    end

    return 1
  rescue
    return 1
  end

  def self.apply_stage(value, stage)
    value = [value.to_i, 1].max
    stage = stage.to_i

    if stage >= 0
      return (value * (2 + stage) / 2.0).floor
    else
      return (value * 2.0 / (2 - stage)).floor
    end
  end

  def self.stage_for(battler, stat)
    return battler.stages[stat].to_i
  rescue
    return 0
  end

  def self.transformed?(battler)
    return false if !PBEffects.const_defined?(:Transform)

    begin
      return battler.effects[PBEffects::Transform]
    rescue
      return false
    end
  end

  def self.can_evolve?(pkmn)
    return false if !pkmn

    begin
      return pkmn.species_data.get_evolutions(true).length > 0
    rescue
      return false
    end
  end

  def self.item_active?(battler, item)
    return false if !battler

    begin
      return false if !battler.itemActive?
    rescue
    end

    begin
      return battler.item == item
    rescue
      return false
    end
  end

  # Defense stat used for the Juggernaut bonus.
  # This includes stage modifiers and common Defense modifiers.
  def self.modified_defense_for_bonus(user)
    defense = raw_stat(user, :DEFENSE)
    defense = apply_stage(defense, stage_for(user, :DEFENSE))

    # Eviolite: Defense x1.5 if the Pokémon can evolve.
    if item_active?(user, :EVIOLITE) && can_evolve?(user.pokemon)
      defense = (defense * 1.5).floor
    end

    # Metal Powder: Ditto Defense x1.5 if not transformed.
    if item_active?(user, :METALPOWDER) &&
       user.respond_to?(:isSpecies?) &&
       user.isSpecies?(:DITTO) &&
       !transformed?(user)
      defense = (defense * 1.5).floor
    end

    # Fur Coat / Cotton Cloak-style Defense modifiers.
    if has_ability_or_innate?(user, :FURCOAT) ||
       has_ability_or_innate?(user, :COTTONCLOAK)
      defense *= 2
    end

    # Marvel Scale-style Defense boost while statused.
    if has_ability_or_innate?(user, :MARVELSCALE)
      begin
        defense = (defense * 1.5).floor if user.pbHasAnyStatus?
      rescue
      end
    end

    # Grass Pelt-style Defense boost in Grassy Terrain.
    if has_ability_or_innate?(user, :GRASSPELT)
      begin
        defense = (defense * 1.5).floor if user.battle.field.terrain == :Grassy
      rescue
      end
    end

    return [defense, 1].max
  end

  # The default attacking stat that the move would normally use.
  def self.default_offensive_stat(user, target, move)
    stat = :ATTACK

    # Body Press-style moves use user's Defense as the default attacking stat.
    begin
      if move.function_code == "UseUserDefenseInsteadOfUserAttack"
        return modified_defense_for_bonus(user)
      end
    rescue
    end

    # Foul Play-style moves use target's Attack.
    begin
      if move.function_code == "UseTargetAttackInsteadOfUserAttack" && target
        attack = raw_stat(target, :ATTACK)
        return [apply_stage(attack, stage_for(target, :ATTACK)), 1].max
      end
    rescue
    end

    # Normal physical/special move split.
    begin
      stat = :SPECIAL_ATTACK if move.specialMove?
    rescue
      stat = :ATTACK
    end

    value = raw_stat(user, stat)
    value = apply_stage(value, stage_for(user, stat))

    return [value, 1].max
  end

  def self.attack_multiplier(user, target, move)
    offense = default_offensive_stat(user, target, move)
    defense = modified_defense_for_bonus(user)

    bonus = defense * DEFENSE_PORTION
    return 1.0 + (bonus / offense.to_f)
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::DamageCalcFromUser.add(:JUGGERNAUT,
  proc { |ability, user, target, move, mults, power, type|
    next if !Juggernaut.can_apply?(user, move)

    mults[:attack_multiplier] *= Juggernaut.attack_multiplier(user, target, move)
  }
)

#===============================================================================
# Optional AI support
#===============================================================================

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:juggernaut_pbGetMoveScore)
      alias juggernaut_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = juggernaut_pbGetMoveScore(*args)

      move = nil
      user = nil

      args.each do |arg|
        if arg.respond_to?(:pbContactMove?) ||
           arg.respond_to?(:contactMove?) ||
           arg.respond_to?(:pbDamagingMove?) ||
           arg.respond_to?(:damagingMove?)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?)
          user = arg if user.nil?
        end
      end

      if score.is_a?(Numeric) &&
         user &&
         move &&
         user.hasActiveAbility?(:JUGGERNAUT) &&
         Juggernaut.can_apply?(user, move)
        score += 20
        PBDebug.log_ai("     + Juggernaut adds Defense to contact damage: 20") if defined?(PBDebug)
      end

      return score
    end
  end
end

#===============================================================================
# Ice Dew
# Pokemon Essentials v21.1
#
# Effect:
#   - The Pokemon is immune to Ice-type moves.
#   - When hit by an Ice-type move, its own Ice-type moves are powered up by 50%.
#
# Notes:
#   - Works like Flash Fire.
#   - Uses PBEffects::FlashFire as the stored "charged" state, because this
#     effect already exists and resets properly when switching.
#   - Does not activate if the attacker ignores abilities via Mold Breaker-style
#     effects.
#===============================================================================

module IceDew
  BOOST_MULTIPLIER = 1.5

  def self.ice_type?(type, move = nil)
    return true if type == :ICE

    begin
      return true if move && move.calcType == :ICE
    rescue
    end

    return false
  end

  def self.charged?(battler)
    return false if !battler
    return false if !PBEffects.const_defined?(:FlashFire)

    return battler.effects[PBEffects::FlashFire]
  rescue
    return false
  end

  def self.set_charged(battler)
    return if !battler
    return if !PBEffects.const_defined?(:FlashFire)

    battler.effects[PBEffects::FlashFire] = true
  rescue
  end
end

#===============================================================================
# Ice-type immunity + charge
#===============================================================================

Battle::AbilityEffects::MoveImmunity.add(:ICEDEW,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if battle.moldBreaker
    next false if !IceDew.ice_type?(type, move)

    if show_message
      battle.pbShowAbilitySplash(target)

      if IceDew.charged?(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          battle.pbDisplay(_INTL("{1} absorbed the icy attack!", target.pbThis))
        else
          battle.pbDisplay(_INTL("{1}'s {2} absorbed the icy attack!",
            target.pbThis, target.abilityName))
        end
      else
        IceDew.set_charged(target)

        if Battle::Scene::USE_ABILITY_SPLASH
          battle.pbDisplay(_INTL("{1}'s Ice-type moves were powered up!", target.pbThis))
        else
          battle.pbDisplay(_INTL("{1}'s {2} powered up its Ice-type moves!",
            target.pbThis, target.abilityName))
        end
      end

      battle.pbHideAbilitySplash(target)
    else
      IceDew.set_charged(target)
    end

    # Immune to the Ice-type move.
    next true
  }
)

#===============================================================================
# Boost user's Ice-type moves after being charged
#===============================================================================

Battle::AbilityEffects::DamageCalcFromUser.add(:ICEDEW,
  proc { |ability, user, target, move, mults, power, type|
    next if !IceDew.charged?(user)
    next if !IceDew.ice_type?(type, move)

    mults[:power_multiplier] *= IceDew::BOOST_MULTIPLIER
  }
)

#===============================================================================
# Optional AI support
#===============================================================================

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:ice_dew_pbGetMoveScore)
      alias ice_dew_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = ice_dew_pbGetMoveScore(*args)

      move = nil
      user = nil
      target = nil

      args.each do |arg|
        if arg.respond_to?(:calcType) || arg.respond_to?(:type)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) && arg.respond_to?(:opposes?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end

      if score.is_a?(Numeric) && move
        move_type = nil

        begin
          move_type = move.calcType
        rescue
          begin
            move_type = move.type
          rescue
            move_type = nil
          end
        end

        # Avoid using Ice moves into Ice Dew.
        if target && target.hasActiveAbility?(:ICEDEW) && move_type == :ICE
          score -= 80
          PBDebug.log_ai("     - Target's Ice Dew absorbs Ice moves: 80") if defined?(PBDebug)
        end

        # Value Ice moves more if Ice Dew is charged.
        if user &&
           user.hasActiveAbility?(:ICEDEW) &&
           IceDew.charged?(user) &&
           move_type == :ICE
          score += 25
          PBDebug.log_ai("     + Ice Dew boosts this Ice move: 25") if defined?(PBDebug)
        end
      end

      return score
    end
  end
end

#===============================================================================
# Heavy Metal Plus
# Pokemon Essentials v21.1
#
# Added effect:
#   Heavy Metal increases Defense by 20%.
#
# Notes:
#   - This affects damage calculation only.
#   - It boosts the defensive stat used against physical moves.
#   - The original Heavy Metal weight effect is kept unchanged.
#===============================================================================

Battle::AbilityEffects::DamageCalcFromTarget.add(:HEAVYMETAL,
  proc { |ability, user, target, move, mults, power, type|
    next if !move.physicalMove?

    mults[:defense_multiplier] *= 1.2
  }
)

#===============================================================================
# Powder Burst
# Pokemon Essentials v21.1
#
# Effect:
#   Powder moves gain +1 priority.
#
# Notes:
#   - Uses move.powderMove? if available.
#   - Also checks the PBS move flag "Powder" as fallback.
#   - Works with Sleep Powder, Stun Spore, Poison Powder, Spore, Rage Powder,
#     Cotton Spore, Powder, and custom moves with the Powder flag.
#===============================================================================

module PowderBurst
  ABILITY = :POWDERBURST

  def self.move_flags(move)
    return [] if !move

    begin
      return move.flags || [] if move.respond_to?(:flags)
    rescue
    end

    begin
      return move.instance_variable_get(:@flags) || [] if move.instance_variable_defined?(:@flags)
    rescue
    end

    return []
  end

  def self.powder_move?(move)
    return false if !move

    # Essentials' built-in powder move check.
    begin
      return true if move.respond_to?(:powderMove?) && move.powderMove?
    rescue
    end

    # Fallback: check PBS flag.
    move_flags(move).each do |flag|
      return true if flag.to_s.upcase == "POWDER"
    end

    return false
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::PriorityBracketChange.add(:POWDERBURST,
  proc { |ability, battler, battle|
    next 0 if !battler
    next 0 if battler.fainted?

    choice = battle.choices[battler.index]
    next 0 if !choice
    next 0 if choice[0] != :UseMove

    move = choice[2]
    next 0 if !PowderBurst.powder_move?(move)

    next 1
  }
)

#===============================================================================
# Optional AI support
#===============================================================================

if defined?(Battle::AI) && Battle::AI.method_defined?(:pbGetMoveScore)
  class Battle::AI
    if !method_defined?(:powder_burst_pbGetMoveScore)
      alias powder_burst_pbGetMoveScore pbGetMoveScore
    end

    def pbGetMoveScore(*args)
      score = powder_burst_pbGetMoveScore(*args)

      move = nil
      user = nil

      args.each do |arg|
        if arg.respond_to?(:powderMove?) ||
           arg.instance_variable_defined?(:@flags) ||
           arg.respond_to?(:flags)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?)
          user = arg if user.nil?
        end
      end

      if score.is_a?(Numeric) &&
         user &&
         move &&
         user.hasActiveAbility?(:POWDERBURST) &&
         PowderBurst.powder_move?(move)
        score += 15
        PBDebug.log_ai("     + Powder Burst gives powder move priority: 15") if defined?(PBDebug)
      end

      return score
    end
  end
end

#===============================================================================
# Parasite Host
# Pokémon Essentials v21.1
#
# Effect:
#   If this Pokémon would faint before it takes its chosen action, it survives
#   at 1 HP temporarily, still takes its turn, then faints immediately after
#   resolving that turn.
#
# Notes:
#   - Does not consume or replace the Pokémon's real move.
#   - Does not activate after the Pokémon has already acted.
#   - Does not activate if the Pokémon has no move selected.
#   - Uses a temporary 1 HP state because Essentials normally skips fainted
#     battlers before they can act.
#===============================================================================

module ParasiteHost
  ABILITY = :PARASITEHOST

  def self.has_ability?(battler)
    return false if !battler
    return false if battler.fainted?

    begin
      return true if battler.hasActiveAbility?(ABILITY)
    rescue
    end

    # Optional support for innate ability plugins.
    begin
      return true if battler.respond_to?(:abilityMutationList) &&
                     battler.abilityMutationList &&
                     battler.abilityMutationList.include?(ABILITY)
    rescue
    end

    [
      :hasInnateAbility?,
      :hasActiveInnateAbility?,
      :hasInnate?,
      :hasActiveInnate?,
      :pbHasInnateAbility?
    ].each do |method_name|
      begin
        return true if battler.respond_to?(method_name) &&
                       battler.send(method_name, ABILITY)
      rescue
      end
    end

    return false
  end

  def self.pending?(battler)
    return false if !battler
    return battler.instance_variable_get(:@parasite_host_pending_faint) == true
  end

  def self.set_pending(battler, value)
    return if !battler
    battler.instance_variable_set(:@parasite_host_pending_faint, value)
  end

  def self.forcing_faint?(battler)
    return false if !battler
    return battler.instance_variable_get(:@parasite_host_forcing_faint) == true
  end

  def self.set_forcing_faint(battler, value)
    return if !battler
    battler.instance_variable_set(:@parasite_host_forcing_faint, value)
  end

  def self.has_move_choice?(battler)
    return false if !battler || !battler.battle

    choice = battler.battle.choices[battler.index]
    return false if !choice
    return false if choice[0] != :UseMove

    return true
  rescue
    return false
  end

  def self.already_acted?(battler)
    begin
      return true if battler.movedThisRound?
    rescue
    end

    return false
  end

  def self.can_activate?(battler, damage)
    return false if !battler
    return false if forcing_faint?(battler)
    return false if pending?(battler)
    return false if battler.hp <= 0
    return false if damage.to_i < battler.hp
    return false if !has_ability?(battler)
    return false if !has_move_choice?(battler)
    return false if already_acted?(battler)

    # Avoid triggering during end-of-round residual damage.
    begin
      return false if battler.battle.endOfRound
    rescue
    end

    return true
  end

  def self.activate(battler)
    return if !battler
    return if pending?(battler)

    set_pending(battler, true)

    battle = battler.battle
    battle.pbShowAbilitySplash(battler)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} clung to its turn through the parasite!", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} let it cling to its turn!",
        battler.pbThis, battler.abilityName))
    end

    battle.pbHideAbilitySplash(battler)
  end

  def self.force_faint(battler)
    return if !battler
    return if !pending?(battler)

    battle = battler.battle

    set_pending(battler, false)
    set_forcing_faint(battler, true)

    begin
      battle.pbDisplay(_INTL("{1}'s borrowed time ran out!", battler.pbThis)) if !battler.fainted?

      if battler.hp > 0
        begin
          battler.pbReduceHP(battler.hp, false)
        rescue ArgumentError
          begin
            battler.pbReduceHP(battler.hp)
          rescue
            battler.hp = 0 if battler.respond_to?(:hp=)
          end
        end
      end

      battler.hp = 0 if battler.respond_to?(:hp=) && battler.hp > 0
      battler.pbFaint if battler.fainted?
    ensure
      set_forcing_faint(battler, false)
    end
  end
end

#===============================================================================
# Keep the Pokémon alive at 1 HP if it would faint before acting
#===============================================================================

class Battle::Battler
  if !method_defined?(:parasite_host_pbReduceHP)
    alias parasite_host_pbReduceHP pbReduceHP
  end

  def pbReduceHP(*args)
    damage = args[0].to_i

    # If already being sustained by Parasite Host, don't let further damage
    # remove the temporary 1 HP before it acts.
    if ParasiteHost.pending?(self) && !ParasiteHost.forcing_faint?(self)
      return 0 if damage > 0
    end

    if ParasiteHost.can_activate?(self, damage)
      ParasiteHost.activate(self)

      # Reduce only to 1 HP instead of fainting immediately.
      adjusted_damage = self.hp - 1
      adjusted_damage = 0 if adjusted_damage < 0

      if adjusted_damage > 0
        new_args = args.clone
        new_args[0] = adjusted_damage
        return parasite_host_pbReduceHP(*new_args)
      end

      return 0
    end

    return parasite_host_pbReduceHP(*args)
  end
end

#===============================================================================
# After attempting to use its chosen move, the Pokémon faints
#===============================================================================

class Battle::Battler
  if !method_defined?(:parasite_host_pbEndTurn)
    alias parasite_host_pbEndTurn pbEndTurn
  end

  def pbEndTurn(*args)
    ret = parasite_host_pbEndTurn(*args)

    choice = args[0]

    if ParasiteHost.pending?(self)
      # If it had a move selected, faint after its action attempt finishes,
      # even if the move failed, missed, flinched, etc.
      if choice && choice[0] == :UseMove
        ParasiteHost.force_faint(self)
      end
    end

    return ret
  end
end

#===============================================================================
# Safety cleanup at end of round
#===============================================================================

class Battle
  if method_defined?(:pbEndOfRoundPhase) &&
     !method_defined?(:parasite_host_pbEndOfRoundPhase)
    alias parasite_host_pbEndOfRoundPhase pbEndOfRoundPhase
  end

  def pbEndOfRoundPhase(*args)
    ret = parasite_host_pbEndOfRoundPhase(*args)

    @battlers.each do |b|
      next if !b
      ParasiteHost.force_faint(b) if ParasiteHost.pending?(b)
    end

    return ret
  end
end

#===============================================================================
# Parasite Host - No Healing While Borrowed Time
#===============================================================================
# While Parasite Host is keeping the Pokemon alive at 1 HP, it cannot heal.
# This prevents healing moves, draining moves, berries, Leftovers, Aqua Ring, etc.
# The Pokemon will still faint after its action.
#===============================================================================

class Battle::Battler
  if !method_defined?(:parasite_host_no_heal_canHeal)
    alias parasite_host_no_heal_canHeal canHeal?
  end

  def canHeal?
    return false if ParasiteHost.pending?(self)
    return parasite_host_no_heal_canHeal
  end

  if !method_defined?(:parasite_host_no_heal_pbRecoverHP)
    alias parasite_host_no_heal_pbRecoverHP pbRecoverHP
  end

  def pbRecoverHP(*args)
    if ParasiteHost.pending?(self)
      return 0
    end

    return parasite_host_no_heal_pbRecoverHP(*args)
  end

  if !method_defined?(:parasite_host_no_heal_pbItemHPHealCheck)
    alias parasite_host_no_heal_pbItemHPHealCheck pbItemHPHealCheck
  end

  def pbItemHPHealCheck(*args)
    return false if ParasiteHost.pending?(self)
    return parasite_host_no_heal_pbItemHPHealCheck(*args)
  end
end

#===============================================================================
# Seed Parasite
# Pokemon Essentials v21.1
#
# Effect:
#   If this Pokemon is knocked out by a contact move, the attacker is afflicted
#   with Leech Seed.
#
# Notes:
#   - Does not affect Grass-type Pokemon.
#   - Does not affect a target already affected by Leech Seed.
#   - Only triggers if the Seed Parasite user was knocked out by that hit.
#===============================================================================

module SeedParasite
  ABILITY = :SEEDPARASITE

  def self.contact_move?(move, user)
    return false if !move

    begin
      return move.pbContactMove?(user)
    rescue
    end

    begin
      return move.contactMove?
    rescue
    end

    return false
  end

  def self.grass_type?(battler)
    return false if !battler

    begin
      return battler.pbHasType?(:GRASS)
    rescue
    end

    return false
  end

  def self.leech_seed_effect
    return nil if !PBEffects.const_defined?(:LeechSeed)
    return PBEffects.const_get(:LeechSeed)
  end

  def self.seeded?(battler)
    effect = leech_seed_effect
    return false if !effect || !battler

    return battler.effects[effect] >= 0
  rescue
    return false
  end

  def self.set_seeded(attacker, source)
    effect = leech_seed_effect
    return false if !effect || !attacker || !source

    attacker.effects[effect] = source.index
    return true
  rescue
    return false
  end

  def self.knocked_out_by_hit?(target)
    return false if !target

    begin
      return true if target.damageState.fainted
    rescue
    end

    return target.fainted?
  end

  def self.can_apply?(attacker, target, move)
    return false if !attacker || !target || !move
    return false if attacker.fainted?
    return false if !target.hasActiveAbility?(ABILITY)
    return false if !knocked_out_by_hit?(target)
    return false if !contact_move?(move, attacker)

    # Contact effects don't apply if attacker is protected from contact effects.
    begin
      return false if !attacker.affectedByContactEffect?
    rescue
    end

    # Grass-type Pokemon are immune to Leech Seed.
    return false if grass_type?(attacker)

    # Don't overwrite an existing Leech Seed.
    return false if seeded?(attacker)

    return true
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::OnBeingHit.add(:SEEDPARASITE,
  proc { |ability, user, target, move, battle|
    # user   = attacker
    # target = Pokemon with Seed Parasite
    next if !SeedParasite.can_apply?(user, target, move)

    battle.pbShowAbilitySplash(target)

    if SeedParasite.set_seeded(user, target)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} was seeded by the parasite!", user.pbThis))
      else
        battle.pbDisplay(_INTL("{1}'s {2} seeded {3}!",
          target.pbThis, target.abilityName, user.pbThis(true)))
      end
    end

    battle.pbHideAbilitySplash(target)
  }
)

#===============================================================================
# Ancient Slumber
# Pokemon Essentials v21.1
#
# Effect:
#   While this Pokemon is asleep, every 2 turns it has a 25% chance to raise
#   all main stats by 1 stage.
#
# Main stats:
#   Attack, Defense, Special Attack, Special Defense, Speed
#===============================================================================

module AncientSlumber
  CHANCE = 25
  TURN_INTERVAL = 2

  def self.counter(battler)
    return battler.instance_variable_get(:@ancient_slumber_counter).to_i
  end

  def self.set_counter(battler, value)
    battler.instance_variable_set(:@ancient_slumber_counter, value.to_i)
  end

  def self.reset_counter(battler)
    set_counter(battler, 0)
  end

  def self.asleep?(battler)
    return false if !battler
    return battler.asleep?
  rescue
    return false
  end

  def self.raise_all_stats(battler, battle)
    stats = []

    GameData::Stat.each_main_battle do |s|
      next if !battler.pbCanRaiseStatStage?(s.id, battler)
      stats.push(s.id)
    end

    return false if stats.empty?

    battle.pbShowAbilitySplash(battler)

    show_anim = true
    stats.each do |stat|
      begin
        battler.pbRaiseStatStageByAbility(stat, 1, battler, show_anim)
      rescue
        battler.pbRaiseStatStage(stat, 1, battler, show_anim)
      end
      show_anim = false
    end

    battle.pbHideAbilitySplash(battler)
    return true
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::EndOfRoundEffect.add(:ANCIENTSLUMBER,
  proc { |ability, battler, battle|
    if !AncientSlumber.asleep?(battler)
      AncientSlumber.reset_counter(battler)
      next
    end

    count = AncientSlumber.counter(battler) + 1
    AncientSlumber.set_counter(battler, count)

    # Only checks every 2 turns while asleep.
    next if count % AncientSlumber::TURN_INTERVAL != 0

    # 25% chance.
    next if battle.pbRandom(100) >= AncientSlumber::CHANCE

    AncientSlumber.raise_all_stats(battler, battle)
  }
)

#===============================================================================
# Cleanup on switch out
#===============================================================================

class Battle::Battler
  if method_defined?(:pbAbilitiesOnSwitchOut) &&
     !method_defined?(:ancient_slumber_pbAbilitiesOnSwitchOut)
    alias ancient_slumber_pbAbilitiesOnSwitchOut pbAbilitiesOnSwitchOut
  end

  def pbAbilitiesOnSwitchOut(*args)
    AncientSlumber.reset_counter(self)
    return ancient_slumber_pbAbilitiesOnSwitchOut(*args)
  end
end

#===============================================================================
# Stone Scatter
# Pokemon Essentials v21.1
#
# Effect:
#   The first time this Pokemon enters battle, it sets Stealth Rock on the
#   opposing side of the field.
#
# Notes:
#   - Only activates once per Pokemon per battle.
#   - Does nothing if the opposing side already has Stealth Rock.
#   - Does not consume the Pokemon's turn.
#===============================================================================

module StoneScatter
  ABILITY = :STONESCATTER

  def self.effect_key
    return nil if !PBEffects.const_defined?(:StealthRock)
    return PBEffects.const_get(:StealthRock)
  end

  def self.pokemon_key(battler)
    return nil if !battler || !battler.pokemon
    return battler.pokemon.object_id
  end

  def self.used_hash(battle)
    hash = battle.instance_variable_get(:@stone_scatter_used)
    if !hash
      hash = {}
      battle.instance_variable_set(:@stone_scatter_used, hash)
    end
    return hash
  end

  def self.used?(battler)
    return true if !battler || !battler.battle
    key = pokemon_key(battler)
    return true if !key
    return used_hash(battler.battle)[key] == true
  end

  def self.mark_used(battler)
    return if !battler || !battler.battle
    key = pokemon_key(battler)
    return if !key
    used_hash(battler.battle)[key] = true
  end

  def self.opposing_side(battler)
    return battler.pbOpposingSide if battler.respond_to?(:pbOpposingSide)

    begin
      return battler.battle.sides[battler.idxOpposingSide]
    rescue
      return nil
    end
  end

  def self.stealth_rock_active?(battler)
    effect = effect_key
    return false if !effect

    side = opposing_side(battler)
    return false if !side

    return side.effects[effect] == true
  end

  def self.set_stealth_rock(battler)
    effect = effect_key
    return false if !effect

    side = opposing_side(battler)
    return false if !side

    side.effects[effect] = true
    return true
  end

  def self.trigger(battler, battle)
    return if !battler
    return if battler.fainted?

    return if stealth_rock_active?(battler)

    battle.pbShowAbilitySplash(battler)

    set_stealth_rock(battler)

    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("Pointed stones float in the air around the opposing team!"))
    else
      battle.pbDisplay(_INTL("{1}'s {2} scattered pointed stones around the opposing team!",
        battler.pbThis, battler.abilityName))
    end

    battle.pbHideAbilitySplash(battler)
  end
end

#===============================================================================
# Ability effect
#===============================================================================

Battle::AbilityEffects::OnSwitchIn.add(:STONESCATTER,
  proc { |ability, battler, battle, switch_in|
    StoneScatter.trigger(battler, battle)
  }
)