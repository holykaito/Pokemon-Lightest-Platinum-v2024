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
  	next pri + 1 if (battler.hp >= battler.totalhp * 0.5) &&
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
    if CursedTerrain.quick_execute_shadow_move?(self, user)
      @powerHerb = false
      @chargingTurn = true
      @damagingTurn = true
      return false
    end

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
      battler.effects[PBEffects::ExtraType] = :ELECTRIC
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
      battler.effects[PBEffects::ExtraType] = :FIRE
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

##------------------------------------------------------------------------------
# Self-Sufficient
#------------------------------------------------------------------------------

module SelfSufficient
  def self.heal_amount(hp, totalhp)
    return [totalhp / ((hp * 2 < totalhp) ? 8 : 16), 1].max
  end
end

Battle::AbilityEffects::EndOfRoundEffect.remove(:SELFSUFFICIENT)

Battle::AbilityEffects::EndOfRoundHealing.add(:SELFSUFFICIENT,
  proc { |ability, battler, battle|
    next if !battler.canHeal?
    battle.pbShowAbilitySplash(battler)
    battler.pbRecoverHP(SelfSufficient.heal_amount(battler.hp, battler.totalhp))
    battle.pbDisplay(_INTL("{1}'s {2} restored its HP.",
                          battler.pbThis, GameData::Ability.get(ability).name))
    battle.pbHideAbilitySplash(battler)
  }
)

Battle::AI::BASE_ABILITY_RATINGS.each_value { |ids| ids.delete(:SELFSUFFICIENT) }
Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :SELFSUFFICIENT

Battle::AI::Handlers::AbilityRanking.add(:SELFSUFFICIENT,
  proc { |ability, score, battler, ai|
    next (battler.hp * 2 < battler.totalhp) ? 9 : 8
  }
)

module SelfSufficient::AIBattler
  def rough_end_of_round_damage
    damage = super
    return damage if damage >= 999_999
    return damage if !has_active_ability?(:SELFSUFFICIENT) || !battler.canHeal?
    amount = SelfSufficient.heal_amount(hp, totalhp)
    return damage - [amount, totalhp - hp].min
  end
end

Battle::AI::AIBattler.prepend(SelfSufficient::AIBattler)

if defined?(AdvancedAI::CustomContent::DEFENSIVE_ABILITIES)
  AdvancedAI::CustomContent::DEFENSIVE_ABILITIES[:SELFSUFFICIENT] = -2.0
end

if defined?(AdvancedAI) && Battle::AI.method_defined?(:score_protect_utility)
  module SelfSufficient::ProtectAI
    def score_protect_utility(move, user, target)
      score = super
      return score if !AdvancedAI.protect_move?(move.id)
      real_user = user.respond_to?(:battler) ? user.battler : user
      return score if !real_user.hasActiveAbility?(:SELFSUFFICIENT)
      return score if !real_user.canHeal? || score <= -300

      weather = real_user.effectiveWeather
      other_recovery =
        user.hasActiveItem?(:LEFTOVERS) ||
        (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON)) ||
        user.effects[PBEffects::Ingrain] ||
        user.effects[PBEffects::AquaRing] ||
        (user.hasActiveAbility?(:POISONHEAL) && user.poisoned?) ||
        (user.hasActiveAbility?([:DRYSKIN, :RAINDISH]) &&
          [:Rain, :HeavyRain].include?(weather)) ||
        (user.hasActiveAbility?(:ICEBODY) &&
          [:Hail, :Snow].include?(weather)) ||
        (@battle.field.terrain == :Grassy && real_user.affectedByTerrain?)

      return score if other_recovery || user.hp.to_f / user.totalhp >= 0.9
      score += 40
      score += 20 if user.hp * 2 < user.totalhp
      return score
    end
  end

  Battle::AI.prepend(SelfSufficient::ProtectAI)
end

#------------------------------------------------------------------------------
# Refuge
#------------------------------------------------------------------------------

module Refuge
  PopupBattler = Struct.new(:index, :name, :abilityName)

	def self.with_popup(battler, owner_name)
	  battle = battler.battle
	  enabled = Battle::Scene::USE_ABILITY_SPLASH
	  popup = PopupBattler.new(
		battler.index, owner_name, GameData::Ability.get(:REFUGE).name
	  )

	  begin
		battle.scene.pbShowAbilitySplash(popup) if enabled
		yield
	  ensure
		battle.scene.pbHideAbilitySplash(popup) if enabled
	  end
	end

  def self.ally_source(battle, index, entering = [])
    return battle.allBattlers.find do |b|
      b.index != index &&
        !entering.include?(b.index) &&
        !b.opposes?(index) &&
        !b.fainted? &&
        b.hasActiveAbility?(:REFUGE)
    end
  end

  def self.restore(battler, divisor, source = nil, source_name = nil)
    return if battler.fainted?

    battle = battler.battle
    ability_name = GameData::Ability.get(:REFUGE).name
    source_name ||= source ? source.name : ability_name

    battler.instance_variable_set(
      :@refuge_cure_pending, [battler.pokemon, source_name]
    )

    return if !battler.canHeal?

    with_popup(battler, source_name) do
      battler.pbRecoverHP([battler.totalhp / divisor, 1].max)
      battle.pbDisplay(_INTL("{1}'s {2} restored {3}'s HP!",
                            source_name, ability_name, battler.pbThis(true)))
    end
  end

  def self.ai_divisor(battle, index)
    current = battle.battlers[index]
    return 4 if battle.refuge_pending.key?(index)

    if current && !current.fainted? && current.hasActiveAbility?(:REFUGE)
      return 4
    end

    source = ally_source(battle, index)
    return nil if !source
    return nil if battle.choices[source.index][0] == :SwitchOut
    return 8
  end

  def self.preview(pkmn, divisor)
    return pkmn if !divisor || pkmn.fainted?

    copy = pkmn.dup
    amount = [copy.totalhp / divisor, 1].max
    copy.hp = [copy.hp + amount, copy.totalhp].min
    copy.status = :NONE
    copy.statusCount = 0
    return copy
  end

  def self.ai_bonus(pkmn, divisor)
    return 0 if !divisor || pkmn.fainted?

    amount = [[pkmn.totalhp / divisor, 1].max, pkmn.totalhp - pkmn.hp].min
    score = 100 * amount / [pkmn.totalhp, 1].max
    score += 20 if pkmn.status != :NONE
    return score
  end
end

class Battle
  def refuge_pending
    return @refuge_pending ||= {}
  end

  alias_method :refuge_original_entering_battle, :pbOnBattlerEnteringBattle

  def pbOnBattlerEnteringBattle(battler_index, *args)
    entering = [battler_index].flatten

    entering.each do |index|
      battler = @battlers[index]
      source_name = refuge_pending.delete(index)
      next if !battler || battler.fainted?

      if source_name
        Refuge.restore(battler, 4, nil, source_name)
      else
        source = Refuge.ally_source(self, index, entering)
        Refuge.restore(battler, 8, source) if source
      end
    end

    return refuge_original_entering_battle(battler_index, *args)
  end

  alias_method :refuge_original_entry_hazards, :pbEntryHazards

  def pbEntryHazards(battler)
    pending = battler.instance_variable_get(:@refuge_cure_pending)
    battler.instance_variable_set(:@refuge_cure_pending, nil)

    result = refuge_original_entry_hazards(battler)

    if pending &&
       battler.pokemon.equal?(pending[0]) &&
       !battler.fainted? &&
       battler.status != :NONE
      Refuge.with_popup(battler, pending[1]) do
        battler.pbCureStatus(false)
        pbDisplay(_INTL("{1}'s {2} cured {3}'s status!",
                        pending[1], GameData::Ability.get(:REFUGE).name,
                        battler.pbThis(true)))
      end
    end

    return result
  end
end

Battle::AbilityEffects::OnSwitchOut.add(:REFUGE,
  proc { |ability, battler, end_of_battle|
    next if end_of_battle || battler.fainted?
    next if !battler.hasActiveAbility?(:REFUGE)
    battler.battle.refuge_pending[battler.index] = battler.name
  }
)

Battle::AI::BASE_ABILITY_RATINGS.each_value { |ids| ids.delete(:REFUGE) }
Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :REFUGE

Battle::AI::Handlers::AbilityRanking.add(:REFUGE,
  proc { |ability, score, battler, ai|
    reserves = ai.get_non_active_party_pokemon(battler.index)
    next 0 if reserves.empty? && ai.battle.pbSideSize(battler.index) == 1
    next 8
  }
)

Battle::AI::Handlers::ShouldSwitch.add(:refuge_support,
  proc { |battler, reserves, ai, battle|
    next false if !battler.has_active_ability?(:REFUGE)
    next false if battler.hp * 2 <= battler.totalhp

    next reserves.any? { |pkmn|
      useful = pkmn.status != :NONE ||
               pkmn.totalhp - pkmn.hp >= [pkmn.totalhp / 4, 1].max

      if useful && ai.respond_to?(:ohkod_on_switch_in?)
        useful = !ai.ohkod_on_switch_in?(pkmn, battler)
      end

      useful
    }
  }
)

class Battle::AI
  alias_method :refuge_original_replacement_rating, :rate_replacement_pokemon

  def rate_replacement_pokemon(index, pkmn, score)
    divisor = Refuge.ai_divisor(@battle, index)
    preview = Refuge.preview(pkmn, divisor)
    result = refuge_original_replacement_rating(index, preview, score)
    return result + Refuge.ai_bonus(pkmn, divisor)
  end

  if method_defined?(:evaluate_switch_matchup_detailed)
    alias_method :refuge_original_matchup, :evaluate_switch_matchup_detailed

    def evaluate_switch_matchup_detailed(pkmn, current_user)
      index = get_battler_index(current_user)
      divisor = Refuge.ai_divisor(@battle, index)
      preview = Refuge.preview(pkmn, divisor)
      result = refuge_original_matchup(preview, current_user)
      return result + Refuge.ai_bonus(pkmn, divisor)
    end
  end

  if method_defined?(:evaluate_switch_candidate_detailed)
    alias_method :refuge_original_candidate, :evaluate_switch_candidate_detailed

    def evaluate_switch_candidate_detailed(pkmn, current_user, skill)
      index = get_battler_index(current_user)
      divisor = Refuge.ai_divisor(@battle, index)
      preview = Refuge.preview(pkmn, divisor)
      result = refuge_original_candidate(preview, current_user, skill)
      return result + Refuge.ai_bonus(pkmn, divisor)
    end
  end

  if method_defined?(:ohkod_on_switch_in?)
    alias_method :refuge_original_switch_survival, :ohkod_on_switch_in?

    def ohkod_on_switch_in?(pkmn, user)
      return refuge_original_switch_survival(pkmn, user) if !pkmn || !user

      index = get_battler_index(user)
      divisor = Refuge.ai_divisor(@battle, index)
      preview = Refuge.preview(pkmn, divisor)
      return refuge_original_switch_survival(preview, user)
    end
  end
end

if defined?(AdvancedAI::CustomContent::SUPPORT_ABILITIES)
  AdvancedAI::CustomContent::SUPPORT_ABILITIES[:REFUGE] = 1.5
end

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Branch Swing
#------------------------------------------------------------------------------
module BranchSwing
  def self.active?(battler)
    return !battler.fainted? &&
           battler.battle.field.terrain == :Grassy &&
           battler.hasActiveAbility?(:BRANCHSWING)
  end

  def self.floating?(battler)
    return false if !active?(battler)
    return false if battler.battle.moldBreaker
    return false if battler.hasActiveItem?(:IRONBALL)
    return false if battler.effects[PBEffects::Ingrain]
    return false if battler.effects[PBEffects::SmackDown]
    return false if battler.battle.field.effects[PBEffects::Gravity] > 0
    return true
  end

  def self.extra_terrain_healing?(battler)
    return active?(battler) &&
           !battler.semiInvulnerable? &&
           !battler.affectedByTerrain? &&
           battler.canHeal?
  end

  def self.pokemon_has_ability?(pkmn)
    return true if pkmn.hasAbility?(:BRANCHSWING)
    if pkmn.respond_to?(:set_innate_limits)
      return pkmn.set_innate_limits.include?(:BRANCHSWING)
    end
    return false
  end

  # Hiển thị đúng Pokémon sở hữu và đúng tên ability,
  # bao gồm trường hợp Branch Swing là innate.
  def self.with_popup(battler, battle)
    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(:BRANCHSWING).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battle.pbShowAbilitySplash(battler)
      yield
    ensure
      begin
        battle.pbHideAbilitySplash(battler)
      ensure
        $aamName  = old_name
        $aamName2 = old_name2
      end
    end
  end

  # Chỉ thông báo một lần trong mỗi lần sàn cỏ kích hoạt.
  def self.notify_activation(battler, battle, reset = false)
    if reset || !active?(battler)
      battler.instance_variable_set(:@branch_swing_notified, false)
    end

    return if !active?(battler)
    return if battler.instance_variable_get(:@branch_swing_notified)

    battler.instance_variable_set(:@branch_swing_notified, true)

    with_popup(battler, battle) do
      battle.pbDisplay(_INTL(
        "{1}'s {2} activated on the grassy terrain!",
        battler.pbThis,
        GameData::Ability.get(:BRANCHSWING).name
      ))
    end
  end
end

#------------------------------------------------------------------------------
# Loại bỏ hiệu ứng tăng Speed cũ
#------------------------------------------------------------------------------
Battle::AbilityEffects::SpeedCalc.remove(:BRANCHSWING)

#------------------------------------------------------------------------------
# Pop-up khi vào sân hoặc khi terrain thay đổi
#------------------------------------------------------------------------------
Battle::AbilityEffects::OnSwitchIn.add(:BRANCHSWING,
  proc { |ability, battler, battle, switch_in|
    BranchSwing.notify_activation(battler, battle, switch_in)
  }
)

Battle::AbilityEffects::OnTerrainChange.add(:BRANCHSWING,
  proc { |ability, battler, battle, ability_changed|
    BranchSwing.notify_activation(battler, battle, ability_changed)
  }
)

#------------------------------------------------------------------------------
# Lơ lửng như Levitate khi có Grassy Terrain
#------------------------------------------------------------------------------
class Battle::Battler
  alias_method :branch_swing_original_airborne, :airborne?

  def airborne?
    return true if BranchSwing.floating?(self)
    return branch_swing_original_airborne
  end
end

#------------------------------------------------------------------------------
# Miễn nhiễm chiêu Ground gây sát thương
#------------------------------------------------------------------------------
Battle::AbilityEffects::MoveImmunity.add(:BRANCHSWING,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if type != :GROUND || !move.damagingMove?
    next false if move.hitsFlyingTargets?
    next false if !BranchSwing.floating?(target)

    if show_message
      BranchSwing.with_popup(target, battle) do
        battle.pbDisplay(_INTL(
          "{1} avoided the attack with {2}!",
          target.pbThis,
          GameData::Ability.get(ability).name
        ))
      end
    end

    next true
  }
)

#------------------------------------------------------------------------------
# Tăng 10% evasion khi có Grassy Terrain
#------------------------------------------------------------------------------
Battle::AbilityEffects::AccuracyCalcFromTarget.add(:BRANCHSWING,
  proc { |ability, mods, user, target, move, type|
    next if !BranchSwing.active?(target)
    mods[:evasion_multiplier] *= 1.1
  }
)

#------------------------------------------------------------------------------
# Vẫn nhận hồi phục từ Grassy Terrain khi đang lơ lửng
#------------------------------------------------------------------------------
class Battle
  alias_method :branch_swing_original_terrain_healing, :pbEORTerrainHealing

  def pbEORTerrainHealing(battler)
    result = branch_swing_original_terrain_healing(battler)
    return result if !BranchSwing.extra_terrain_healing?(battler)

    battler.pbRecoverHP([battler.totalhp / 16, 1].max)
    pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    return result
  end
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:BRANCHSWING)
end

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
Battle::AI::BASE_ABILITY_RATINGS[7] << :BRANCHSWING

Battle::AI::Handlers::AbilityRanking.add(:BRANCHSWING,
  proc { |ability, score, battler, ai|
    next 8 if ai.battle.field.terrain == :Grassy
    next 5 if battler.has_move_with_function?("StartGrassyTerrain")
    next 3
  }
)

#------------------------------------------------------------------------------
# AI: Tính lượng hồi phục cuối lượt
#------------------------------------------------------------------------------
class Battle::AI::AIBattler
  alias_method :branch_swing_original_eor_damage, :rough_end_of_round_damage

  def rough_end_of_round_damage
    damage = branch_swing_original_eor_damage
    return damage if damage >= 999_999
    return damage if !BranchSwing.extra_terrain_healing?(battler)

    amount = [totalhp / 16, 1].max
    return damage - [amount, totalhp - hp].min
  end
end

#------------------------------------------------------------------------------
# AI: Trạng thái lơ lửng và đánh giá Grassy Terrain
#------------------------------------------------------------------------------
class Battle::AI
  alias_method :branch_swing_original_pokemon_airborne, :pokemon_airborne?

  def pokemon_airborne?(pkmn)
    return true if branch_swing_original_pokemon_airborne(pkmn)
    return false if @battle.field.terrain != :Grassy
    return false if pkmn.hasItem?(:IRONBALL)
    return false if @battle.field.effects[PBEffects::Gravity] > 0
    return false if !BranchSwing.pokemon_has_ability?(pkmn)

    if @battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS) &&
       !pkmn.hasItem?(:ABILITYSHIELD)
      return false
    end

    return true
  end

  alias_method :branch_swing_original_terrain_score, :get_score_for_terrain

  def get_score_for_terrain(terrain, move_user, starting = false)
    score = branch_swing_original_terrain_score(terrain, move_user, starting)
    return score if terrain != :Grassy

    each_battler do |b, i|
      next if !b.has_active_ability?(:BRANCHSWING)
      score += b.opposes?(move_user) ? -12 : 12
    end

    return score
  end
end

#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Poseidon Guard
#------------------------------------------------------------------------------
module PoseidonGuard
  def self.above_threshold?(battler)
    return !battler.fainted? &&
           battler.hp * 3 > battler.totalhp * 2
  end

  def self.active?(battler)
    return above_threshold?(battler) &&
           battler.hasActiveAbility?(:POSEIDONGUARD)
  end
end

#------------------------------------------------------------------------------
# Miễn nhiễm trạng thái chính khi HP trên 2/3
#------------------------------------------------------------------------------
Battle::AbilityEffects::StatusImmunity.add(:POSEIDONGUARD,
  proc { |ability, battler, status|
    next PoseidonGuard.active?(battler)
  }
)

#------------------------------------------------------------------------------
# Giảm 25% sát thương từ chiêu thức khi HP trên 2/3
#------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromTarget.add(:POSEIDONGUARD,
  proc { |ability, user, target, move, mults, power, type|
    next if !PoseidonGuard.active?(target)
    mults[:final_damage_multiplier] *= 0.75
  }
)

#------------------------------------------------------------------------------
# AI: Giá trị cơ bản của ability
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:POSEIDONGUARD)
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :POSEIDONGUARD

#------------------------------------------------------------------------------
# AI: Đánh giá theo HP hiện tại
#------------------------------------------------------------------------------
Battle::AI::Handlers::AbilityRanking.add(:POSEIDONGUARD,
  proc { |ability, score, battler, ai|
    next 9 if PoseidonGuard.above_threshold?(battler.battler)
    next 4
  }
)

#------------------------------------------------------------------------------
# Spell Fist
#------------------------------------------------------------------------------
module SpellFist
  def self.converts?(user, move)
    return user &&
           move.damagingMove? &&
           move.punchingMove? &&
           user.hasActiveAbility?(:SPELLFIST)
  end
end

#------------------------------------------------------------------------------
# Chuyển chiêu đấm sang special trước khi tính chỉ số và các hiệu ứng liên quan.
# Không thay đổi category gốc trong PBS.
#------------------------------------------------------------------------------
class Battle::Move
  attr_accessor :spell_fist_user

  alias_method :spell_fist_original_calc_type, :pbCalcType
  def pbCalcType(user)
    @spell_fist_user = user
    return spell_fist_original_calc_type(user)
  end

  alias_method :spell_fist_original_physical_move, :physicalMove?
  def physicalMove?(thisType = nil)
    return false if SpellFist.converts?(@spell_fist_user, self)
    return spell_fist_original_physical_move(thisType)
  end

  alias_method :spell_fist_original_special_move, :specialMove?
  def specialMove?(thisType = nil)
    return true if SpellFist.converts?(@spell_fist_user, self)
    return spell_fist_original_special_move(thisType)
  end

  alias_method :spell_fist_original_category, :category
  def category
    return 1 if SpellFist.converts?(@spell_fist_user, self)
    return spell_fist_original_category
  end
end

#------------------------------------------------------------------------------
# Spell Fist: +20%; cùng Iron Fist: tổng cộng +30%.
#------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:SPELLFIST,
  proc { |ability, user, target, move, mults, power, type|
    next if !SpellFist.converts?(user, move)

    bonus = user.hasActiveAbility?(:IRONFIST) ? 1.3 : 1.2
    mults[:power_multiplier] *= bonus
  }
)

#------------------------------------------------------------------------------
# Iron Fist: nhường phần tăng sát thương cho Spell Fist nếu cả hai hoạt động.
# Iron Fist đứng riêng vẫn tăng 20% như bình thường.
#------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:IRONFIST,
  proc { |ability, user, target, move, mults, power, type|
    next if !move.damagingMove? || !move.punchingMove?
    next if user.hasActiveAbility?(:SPELLFIST)

    mults[:power_multiplier] *= 1.2
  }
)

#------------------------------------------------------------------------------
# AI: xác định người sử dụng trước khi đánh giá loại chiêu.
# Bao gồm AI cấp thấp không gọi pbCalcType khi set_up.
#------------------------------------------------------------------------------
class Battle::AI::AIMove
  alias_method :spell_fist_original_set_up, :set_up

  def set_up(move)
    move.spell_fist_user = @ai.user.battler
    spell_fist_original_set_up(move)
  end
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:SPELLFIST)
end

Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
Battle::AI::BASE_ABILITY_RATINGS[6] << :SPELLFIST

Battle::AI::Handlers::AbilityRanking.add(:SPELLFIST,
  proc { |ability, score, battler, ai|
    has_punch = battler.moves.any? do |move|
      move.damagingMove? &&
        move.punchingMove? &&
        (move.pp > 0 || move.total_pp == 0)
    end

    next 0 if !has_punch
    next 8 if battler.battler.spatk >= battler.battler.attack
    next 3
  }
)

#------------------------------------------------------------------------------
# Bloodlust
#------------------------------------------------------------------------------
module Bloodlust
  def self.heal_amount(totalhp)
    return [totalhp / 5, 1].max
  end
end

Battle::AbilityEffects::OnEndOfUsingMove.add(:BLOODLUST,
  proc { |ability, user, targets, move, battle|
    next if !move.damagingMove?
    next if !user.hasActiveAbility?(:BLOODLUST)
    next if !user.canHeal?

    # Chỉ tính đối thủ bị chiêu vừa sử dụng hạ gục.
    num_fainted = targets.count do |target|
      target.opposes?(user) && target.damageState.fainted
    end
    next if num_fainted == 0

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(ability).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battle.pbShowAbilitySplash(user)
      user.pbRecoverHP(Bloodlust.heal_amount(user.totalhp) * num_fainted)
      battle.pbDisplay(_INTL(
        "{1}'s {2} restored its HP!",
        user.pbThis, ability_name
      ))
    ensure
      begin
        battle.pbHideAbilitySplash(user)
      ensure
        $aamName  = old_name
        $aamName2 = old_name2
      end
    end
  }
)

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:BLOODLUST)
end

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
Battle::AI::BASE_ABILITY_RATINGS[7] << :BLOODLUST

Battle::AI::Handlers::AbilityRanking.add(:BLOODLUST,
  proc { |ability, score, battler, ai|
    next 0 if !battler.moves.any? { |move| move.damagingMove? }
    next 8 if battler.battler.canHeal?
    next 6
  }
)

#------------------------------------------------------------------------------
# AI: Ưu tiên đòn kết liễu khi có thể hồi HP.
#------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
  :bloodlust_knockout_healing,
  proc { |score, move, user, target, ai, battle|
    next score if !ai.trainer.medium_skill?
    next score if !user.has_active_ability?(:BLOODLUST)
    next score if !user.battler.canHeal?
    next score if !target.opposes?(user)
    next score if !move.damagingMove?
    next score if target.effects[PBEffects::Substitute] > 0
    next score if move.rough_damage < target.hp
    next score if target.effects[PBEffects::DestinyBond]

    amount = Bloodlust.heal_amount(user.totalhp)
    recovered = [amount, user.totalhp - user.hp].min

    # Điểm thưởng tăng theo lượng HP thực sự có thể hồi.
    score += (20.0 * recovered / amount).round
    next score
  }
)

#------------------------------------------------------------------------------
# Battle Genes
#------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:BATTLEGENES,
  proc { |ability, user, target, move, mults, power, type|
    next if !move.damagingMove?
    next if !user.hasActiveAbility?(:BATTLEGENES)
    next if !type || !target.pbHasType?(type)

    mults[:final_damage_multiplier] *= 1.3
  }
)

#------------------------------------------------------------------------------
# AI: Ability rating
# AI tính sát thương bằng cùng handler phía trên.
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:BATTLEGENES)
end

Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
Battle::AI::BASE_ABILITY_RATINGS[6] << :BATTLEGENES

Battle::AI::Handlers::AbilityRanking.add(:BATTLEGENES,
  proc { |ability, score, battler, ai|
    next 0 if !battler.moves.any? { |move| move.damagingMove? }
    next score
  }
)

#------------------------------------------------------------------------------
# Flying Nimbus
#------------------------------------------------------------------------------
module FlyingNimbus
  def self.floating?(battler)
    return false if battler.fainted?
    return false if !battler.hasActiveAbility?(:FLYINGNIMBUS)
    return false if battler.battle.moldBreaker
    return false if battler.hasActiveItem?(:IRONBALL)
    return false if battler.effects[PBEffects::Ingrain]
    return false if battler.effects[PBEffects::SmackDown]
    return false if battler.battle.field.effects[PBEffects::Gravity] > 0
    return true
  end

  def self.pokemon_has_ability?(pkmn)
    return true if pkmn.hasAbility?(:FLYINGNIMBUS)
    if pkmn.respond_to?(:set_innate_limits)
      return pkmn.set_innate_limits.include?(:FLYINGNIMBUS)
    end
    return false
  end

  def self.with_popup(battler, battle)
    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(:FLYINGNIMBUS).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battle.pbShowAbilitySplash(battler)
      yield
    ensure
      begin
        battle.pbHideAbilitySplash(battler)
      ensure
        $aamName  = old_name
        $aamName2 = old_name2
      end
    end
  end
end

#------------------------------------------------------------------------------
# Lơ lửng như Levitate
#------------------------------------------------------------------------------
class Battle::Battler
  alias_method :flying_nimbus_original_airborne, :airborne?

  def airborne?
    return true if FlyingNimbus.floating?(self)
    return flying_nimbus_original_airborne
  end
end

#------------------------------------------------------------------------------
# Miễn nhiễm chiêu Ground gây sát thương
#------------------------------------------------------------------------------
Battle::AbilityEffects::MoveImmunity.add(:FLYINGNIMBUS,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if type != :GROUND || !move.damagingMove?
    next false if move.hitsFlyingTargets?
    next false if !FlyingNimbus.floating?(target)

    if show_message
      FlyingNimbus.with_popup(target, battle) do
        battle.pbDisplay(_INTL(
          "{1} avoided the attack with {2}!",
          target.pbThis,
          GameData::Ability.get(ability).name
        ))
      end
    end

    next true
  }
)

#------------------------------------------------------------------------------
# Tăng 20% sát thương nếu ra đòn trước mục tiêu
#------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:FLYINGNIMBUS,
  proc { |ability, user, target, move, mults, power, type|
    next if !move.damagingMove?
    next if !user.hasActiveAbility?(:FLYINGNIMBUS)

    # AI đặt giá trị dự đoán tạm thời khi tính rough_damage.
    first = move.instance_variable_get(:@flying_nimbus_ai_first)
    first = !target.movedThisRound? if first.nil?
    next if !first

    mults[:final_damage_multiplier] *= 1.2
  }
)

#------------------------------------------------------------------------------
# AI: Dự đoán thứ tự hành động khi tính sát thương
#------------------------------------------------------------------------------
class Battle::AI::AIMove
  alias_method :flying_nimbus_original_rough_damage, :rough_damage

  def rough_damage
    user   = @ai.user
    target = @ai.target

    return flying_nimbus_original_rough_damage if !target
    if !user.has_active_ability?(:FLYINGNIMBUS)
      return flying_nimbus_original_rough_damage
    end

    old_first = @move.instance_variable_get(:@flying_nimbus_ai_first)

    begin
      first = false

      if !target.battler.movedThisRound?
        user_priority = rough_priority(user)

        # Nếu mục tiêu đã chọn chiêu, lấy priority của chiêu đó.
        # Khi chưa biết chiêu của mục tiêu, giả định priority = 0.
        target_priority = 0
        choice = @ai.battle.choices[target.index]

        if choice && choice[0] == :UseMove && choice[2]
          target_move = choice[2]
          target_priority = target_move.pbPriority(target.battler)

          if target.ability_active?
            target_priority = Battle::AbilityEffects.triggerPriorityChange(
              target.ability,
              target.battler,
              target_move,
              target_priority
            )
          end
        end

        if choice && [:SwitchOut, :UseItem].include?(choice[0])
          first = false
        elsif user_priority != target_priority
          first = user_priority > target_priority
        else
          first = user.faster_than?(target)
        end
      end

      @move.instance_variable_set(:@flying_nimbus_ai_first, first)
      return flying_nimbus_original_rough_damage
    ensure
      @move.instance_variable_set(:@flying_nimbus_ai_first, old_first)
    end
  end
end

#------------------------------------------------------------------------------
# AI: Nhận biết Pokémon ngoài sân đang lơ lửng
#------------------------------------------------------------------------------
class Battle::AI
  alias_method :flying_nimbus_original_pokemon_airborne, :pokemon_airborne?

  def pokemon_airborne?(pkmn)
    return true if flying_nimbus_original_pokemon_airborne(pkmn)
    return false if pkmn.hasItem?(:IRONBALL)
    return false if @battle.field.effects[PBEffects::Gravity] > 0
    return false if !FlyingNimbus.pokemon_has_ability?(pkmn)

    if @battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS) &&
       !pkmn.hasItem?(:ABILITYSHIELD)
      return false
    end

    return true
  end
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:FLYINGNIMBUS)
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :FLYINGNIMBUS

#------------------------------------------------------------------------------
# Worldroot
#------------------------------------------------------------------------------
module Worldroot
  def self.affects?(target)
    return false if !target || target.fainted?

    return target.battle.allBattlers.any? do |owner|
      owner.opposes?(target) &&
        owner.hasActiveAbility?(:WORLDROOT)
    end
  end

  # Tạm bỏ trạng thái airborne trong bước kiểm tra chiêu Ground.
  # Không làm Pokémon bị grounded trong những cơ chế khác.
  def self.with_ground_check(target)
    old_value = target.instance_variable_get(:@worldroot_ground_check)

    begin
      target.instance_variable_set(:@worldroot_ground_check, true)
      return yield
    ensure
      target.instance_variable_set(:@worldroot_ground_check, old_value)
    end
  end
end

#------------------------------------------------------------------------------
# Bỏ miễn nhiễm Ground do trạng thái airborne trong bước kiểm tra chiêu.
# Prepend để áp dụng trước cả Branch Swing/Flying Nimbus.
#------------------------------------------------------------------------------
module WorldrootBattlerAirborne
  def airborne?
    if @worldroot_ground_check && Worldroot.affects?(self)
      return false
    end
    return super
  end
end

Battle::Battler.prepend(WorldrootBattlerAirborne)

#------------------------------------------------------------------------------
# Trận đấu: kiểm tra mục tiêu của chiêu Ground
#------------------------------------------------------------------------------
class Battle::Battler
  alias_method :worldroot_original_success_check, :pbSuccessCheckAgainstTarget

  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    if move.calcType == :GROUND && Worldroot.affects?(target)
      return Worldroot.with_ground_check(target) do
        worldroot_original_success_check(move, user, target, targets)
      end
    end

    return worldroot_original_success_check(move, user, target, targets)
  end
end

#------------------------------------------------------------------------------
# Hệ Flying không còn miễn nhiễm Ground.
# Vẫn tính kháng/yếu từ các hệ còn lại của mục tiêu.
#------------------------------------------------------------------------------
class Battle::Move
  alias_method :worldroot_original_type_mod_single, :pbCalcTypeModSingle

  def pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :GROUND && defType == :FLYING &&
       Worldroot.affects?(target)
      return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    end

    return worldroot_original_type_mod_single(moveType, defType, user, target)
  end

  #----------------------------------------------------------------------------
  # Bỏ miễn nhiễm Ground từ ability, ngoại trừ Earth Eater.
  # Các hệ chiêu khác giữ nguyên cơ chế hiện tại.
  #----------------------------------------------------------------------------
  alias_method :worldroot_original_immunity_by_ability, :pbImmunityByAbility

  def pbImmunityByAbility(user, target, show_message)
    if @calcType == :GROUND && Worldroot.affects?(target)
      # Giữ nguyên quy tắc Mold Breaker của game.
      return false if @battle.moldBreaker
      return false if !target.hasActiveAbility?(:EARTHEATER)

      # Gọi riêng Earth Eater, không gọi lại các innate miễn nhiễm khác.
      return Battle::AbilityEffects::MoveImmunity.trigger(
        :EARTHEATER, user, target, self, @calcType,
        @battle, show_message
      )
    end

    return worldroot_original_immunity_by_ability(user, target, show_message)
  end
end

#------------------------------------------------------------------------------
# Pop-up khi người sở hữu vào sân
#------------------------------------------------------------------------------
Battle::AbilityEffects::OnSwitchIn.add(:WORLDROOT,
  proc { |ability, battler, battle, switch_in|
    next if !battler.hasActiveAbility?(:WORLDROOT)
    next if !battle.allBattlers.any? { |b| b.opposes?(battler) }

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(ability).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL(
        "{1}'s roots stripped opposing Pokémon of their Ground immunity!",
        battler.pbThis
      ))
    ensure
      begin
        battle.pbHideAbilitySplash(battler)
      ensure
        $aamName  = old_name
        $aamName2 = old_name2
      end
    end
  }
)

#------------------------------------------------------------------------------
# AI: nhận biết chiêu Ground có thể đánh trúng mục tiêu
#------------------------------------------------------------------------------
class Battle::AI
  alias_method :worldroot_original_predict_failure, :pbPredictMoveFailureAgainstTarget

  def pbPredictMoveFailureAgainstTarget
    if @target && @move.rough_type == :GROUND &&
       Worldroot.affects?(@target.battler)
      return Worldroot.with_ground_check(@target.battler) do
        worldroot_original_predict_failure
      end
    end

    return worldroot_original_predict_failure
  end
end

#------------------------------------------------------------------------------
# AI: tính hiệu quả Ground đối với hệ Flying
#------------------------------------------------------------------------------
class Battle::AI::AIBattler
  alias_method :worldroot_original_single_type_effectiveness,
               :effectiveness_of_type_against_single_battler_type

  def effectiveness_of_type_against_single_battler_type(
    type, defend_type, user = nil
  )
    if type == :GROUND && defend_type == :FLYING &&
       Worldroot.affects?(battler)
      return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    end

    return worldroot_original_single_type_effectiveness(
      type, defend_type, user
    )
  end

  private :effectiveness_of_type_against_single_battler_type
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:WORLDROOT)
end

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
Battle::AI::BASE_ABILITY_RATINGS[7] << :WORLDROOT

Battle::AI::Handlers::AbilityRanking.add(:WORLDROOT,
  proc { |ability, score, battler, ai|
    next 8 if battler.has_damaging_move_of_type?(:GROUND)
    next score
  }
)

#------------------------------------------------------------------------------
# Run Away - Complete effects
#------------------------------------------------------------------------------

module RunAwayEnhanced
  def self.trigger_count(battler)
    return battler.instance_variable_get(:@run_away_trigger_count) || 0
  end

  def self.raise_speed(battler)
    return if !battler.hasActiveAbility?(:RUNAWAY)

    # Ghi nhận cả khi Speed không thể tăng thêm để tránh kích hoạt lặp.
    battler.instance_variable_set(
      :@run_away_trigger_count, trigger_count(battler) + 1
    )

    return if !battler.pbCanRaiseStatStage?(:SPEED, battler)

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(:RUNAWAY).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battler.pbRaiseStatStageByAbility(:SPEED, 2, battler)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
end

#------------------------------------------------------------------------------
# Chắc chắn thoát trận hoang dã khi bị giữ chân.
# Không phụ thuộc MAG_RUNAWAY hoặc CHAMPIONS_MECHANICS.
#------------------------------------------------------------------------------
Battle::AbilityEffects::CertainEscapeFromBattle.add(:RUNAWAY,
  proc { |ability, battler|
    next true
  }
)

#------------------------------------------------------------------------------
# Cho phép đổi Pokémon khi bị giữ chân.
#------------------------------------------------------------------------------
Battle::AbilityEffects::CertainSwitching.add(:RUNAWAY,
  proc { |ability, battler, battle|
    next true
  }
)

#------------------------------------------------------------------------------
# Sửa bước kiểm tra giữ chân bổ sung của Innate Abilities.
# Giữ nguyên kiểm tra Pokémon thay thế và các giới hạn khác của trận đấu.
#------------------------------------------------------------------------------
class << Battle::AbilityEffects
  alias_method :run_away_original_trapping_by_target,
               :triggerTrappingByTarget

  def triggerTrappingByTarget(ability, switcher, bearer, battle)
    return false if switcher.hasActiveAbility?(:RUNAWAY)

    return run_away_original_trapping_by_target(
      ability, switcher, bearer, battle
    )
  end
end

#------------------------------------------------------------------------------
# Speed +2 khi bị Intimidate.
# Thay handler cũ, không cộng thêm một lần tăng thứ hai.
#------------------------------------------------------------------------------
Battle::AbilityEffects::OnIntimidated.add(:RUNAWAY,
  proc { |ability, battler, battle|
    RunAwayEnhanced.raise_speed(battler)
  }
)

#------------------------------------------------------------------------------
# Bổ sung phản ứng với Terror Sower.
# Giữ nguyên handler Terror Sower hiện có, gồm phần kiểm tra Overwhelm.
# Không tăng Speed lần nữa nếu handler cũ đã kích hoạt Run Away.
#------------------------------------------------------------------------------
run_away_terror_sower_handler =
  Battle::AbilityEffects::OnSwitchIn[:TERRORSOWER]

if run_away_terror_sower_handler
  Battle::AbilityEffects::OnSwitchIn.add(:TERRORSOWER,
    proc { |ability, battler, battle, switch_in|
      snapshots = []

      battle.allOtherSideBattlers(battler.index).each do |target|
        next if target.fainted?

        snapshots << [
          target,
          target.stages[:SPECIAL_ATTACK],
          RunAwayEnhanced.trigger_count(target)
        ]
      end

      run_away_terror_sower_handler.call(
        ability, battler, battle, switch_in
      )

      snapshots.each do |target, old_spatk_stage, old_count|
        next if target.fainted?
        next if !target.hasActiveAbility?(:RUNAWAY)
        next if target.stages[:SPECIAL_ATTACK] == old_spatk_stage
        next if RunAwayEnhanced.trigger_count(target) != old_count

        RunAwayEnhanced.raise_speed(target)
      end
    }
  )
end

#------------------------------------------------------------------------------
# AI: Run Away có giá trị chiến đấu cả với Pokémon hoang dã.
# Thay đánh giá cũ vốn cho Run Away điểm 0 khi Pokémon là wild.
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:RUNAWAY)
end

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
Battle::AI::BASE_ABILITY_RATINGS[7] << :RUNAWAY

Battle::AI::Handlers::AbilityRanking.add(:RUNAWAY,
  proc { |ability, score, battler, ai|
    next score
  }
)

#------------------------------------------------------------------------------
# Cheek Pouch - Generates a random Berry when empty-handed
#------------------------------------------------------------------------------
module CheekPouchEnhanced
  BERRIES = [
    :LUMBERRY,
    :ORANBERRY,
    :SITRUSBERRY,
    :FIGYBERRY,
    :WIKIBERRY,
    :MAGOBERRY,
    :AGUAVBERRY,
    :IAPAPABERRY,
    :ENIGMABERRY,
    :MICLEBERRY,
    :LIECHIBERRY,
    :GANLONBERRY,
    :SALACBERRY,
    :PETAYABERRY,
    :APICOTBERRY,
    :LANSATBERRY,
    :STARFBERRY,
    :CUSTAPBERRY,
    :JABOCABERRY,
    :ROWAPBERRY,
    :KEEBERRY,
    :MARANGABERRY
  ].freeze
end

Battle::AbilityEffects::EndOfRoundGainItem.add(:CHEEKPOUCH,
  proc { |ability, battler, battle|
    next if battler.fainted?
    next if !battler.hasActiveAbility?(:CHEEKPOUCH)
    next if battler.item

    # Chỉ tạo tối đa một Berry mỗi lượt, kể cả khi ăn ngay.
    last_turn = battler.instance_variable_get(:@cheek_pouch_berry_turn)
    next if last_turn == battle.turnCount

    berry = CheekPouchEnhanced::BERRIES[
      battle.pbRandom(CheekPouchEnhanced::BERRIES.length)
    ]

    battler.instance_variable_set(
      :@cheek_pouch_berry_turn, battle.turnCount
    )

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(ability).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battle.pbShowAbilitySplash(battler)
      battler.item = berry

      battle.pbDisplay(_INTL(
        "{1} obtained a {2}!",
        battler.pbThis,
        GameData::Item.get(berry).name
      ))
    ensure
      begin
        battle.pbHideAbilitySplash(battler)
      ensure
        $aamName  = old_name
        $aamName2 = old_name2
      end
    end

    # Berry vừa nhận có thể được ăn ngay nếu đủ điều kiện.
    # Hiệu ứng Cheek Pouch gốc sẽ tự hồi thêm HP khi ăn Berry.
    # Berry vừa nhận có thể được ăn ngay nếu đủ điều kiện.
    battler.pbHeldItemTriggerCheck

    # Nếu ăn xong vẫn không có item, bổ sung ngay một Berry khác.
    if !battler.fainted? &&
       battler.hasActiveAbility?(:CHEEKPOUCH) &&
       !battler.item

      replacement = CheekPouchEnhanced::BERRIES[
        battle.pbRandom(CheekPouchEnhanced::BERRIES.length)
      ]

      battler.item = replacement

      battle.pbDisplay(_INTL(
        "{1} obtained another {2}!",
        battler.pbThis,
        GameData::Item.get(replacement).name
      ))

      # Giữ Berry bổ sung trong ô item.
      # Không kiểm tra ăn ngay lần nữa để tránh vòng lặp tạo–ăn vô hạn.
    end
  }
)

#------------------------------------------------------------------------------
# AI: Nâng giá trị của Cheek Pouch
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:CHEEKPOUCH)
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :CHEEKPOUCH

Battle::AI::Handlers::AbilityRanking.add(:CHEEKPOUCH,
  proc { |ability, score, battler, ai|
    next 9 if !battler.battler.item
    next 8 if battler.battler.item.is_berry?
    next 4
  }
)

#------------------------------------------------------------------------------
# Gnawing
#------------------------------------------------------------------------------
module Gnawing
  # Các chiêu này có hai lần kiểm tra hiệu ứng phụ riêng,
  # dù EffectChance bên ngoài có thể là 100.
  FANG_FUNCTIONS = [
    "BurnFlinchTarget",
    "FreezeFlinchTarget",
    "ParalyzeFlinchTarget"
  ].freeze

  def self.boostable?(move)
    return false if !move.damagingMove? || !move.bitingMove?
    return true if FANG_FUNCTIONS.include?(move.function_code)
    return move.addlEffect > 0 && move.addlEffect < 100
  end
end

#------------------------------------------------------------------------------
# Nhân đôi xác suất sau các điều chỉnh hiện có.
# Giữ nguyên Shield Dust, Covert Cloak và các hiệu ứng chặn khác.
#------------------------------------------------------------------------------
class Battle::Move
  alias_method :gnawing_original_additional_effect_chance,
               :pbAdditionalEffectChance

  def pbAdditionalEffectChance(user, target, effectChance = 0)
    chance = gnawing_original_additional_effect_chance(
      user, target, effectChance
    )

    return chance if !damagingMove? || !bitingMove?
    return chance if !user.hasActiveAbility?(:GNAWING)
    return chance if chance <= 0 || chance >= 100

    return [chance * 2, 100].min
  end
end

#------------------------------------------------------------------------------
# AI: Đánh giá cao hiệu ứng phụ được tăng xác suất.
#------------------------------------------------------------------------------
class Battle::AI::AIMove
  alias_method :gnawing_original_additional_effect_score,
               :get_score_change_for_additional_effect

  def get_score_change_for_additional_effect(user, target = nil)
    score = gnawing_original_additional_effect_score(user, target)

    return score if score < 0
    return score if !user.has_active_ability?(:GNAWING)
    return score if !Gnawing.boostable?(@move)

    if target && user.index != target.index &&
       target.has_active_item?(:COVERTCLOAK)
      return score
    end

    return score + 5
  end
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:GNAWING)
end

Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
Battle::AI::BASE_ABILITY_RATINGS[6] << :GNAWING

Battle::AI::Handlers::AbilityRanking.add(:GNAWING,
  proc { |ability, score, battler, ai|
    next 0 if !battler.moves.any? { |move| Gnawing.boostable?(move) }
    next score
  }
)

#------------------------------------------------------------------------------
# Debilitate
#------------------------------------------------------------------------------
module Debilitate
  STATS = [:ATTACK, :SPECIAL_ATTACK, :SPEED].freeze

  def self.apply(user, target, battle)
    return if user.fainted? || target.fainted?
    return if !user.hasActiveAbility?(:DEBILITATE)

    # Không kích hoạt lặp trên cùng mục tiêu trong một lần dùng chiêu.
    affected = user.instance_variable_get(:@debilitate_affected)
    affected ||= {}
    user.instance_variable_set(:@debilitate_affected, affected)

    key = target.object_id
    return if affected[key]
    affected[key] = true

    return if !STATS.any? do |stat|
      target.pbCanLowerStatStage?(stat, user)
    end

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(:DEBILITATE).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battle.pbShowAbilitySplash(user)

      STATS.each do |stat|
        target.pbLowerStatStageByAbility(stat, 1, user, false)
      end
    ensure
      begin
        battle.pbHideAbilitySplash(user)
      ensure
        $aamName  = old_name
        $aamName2 = old_name2
      end
    end
  end
end

class Battle::Battler
  #----------------------------------------------------------------------------
  # Mỗi lần dùng chiêu có một danh sách mục tiêu đã kích hoạt riêng.
  #----------------------------------------------------------------------------
  alias_method :debilitate_original_use_move, :pbUseMove

  def pbUseMove(choice, specialUsage = false)
    old_affected = @debilitate_affected

    begin
      @debilitate_affected = {}
      return debilitate_original_use_move(choice, specialUsage)
    ensure
      @debilitate_affected = old_affected
    end
  end

  #----------------------------------------------------------------------------
  # Xử lý sau mỗi hit, khi hiệu ứng phụ của hit đã được áp dụng.
  #----------------------------------------------------------------------------
  alias_method :debilitate_original_process_hit, :pbProcessMoveHit

  def pbProcessMoveHit(move, user, targets, hitNum, skipAccuracyCheck)
    old_context = @battle.instance_variable_get(:@debilitate_hit_context)

    context = {
      :user       => user,
      :targets    => targets,
      :inflicted  => {}
    }

    previous_status = {}
    targets.each do |target|
      previous_status[target.object_id] = target.status != :NONE
    end

    begin
      @battle.instance_variable_set(:@debilitate_hit_context, context)

      result = debilitate_original_process_hit(
        move, user, targets, hitNum, skipAccuracyCheck
      )

      if result && move.damagingMove? &&
		 move.pbContactMove?(user) &&
         user.hasActiveAbility?(:DEBILITATE)

        targets.each do |target|
          next if target.index == user.index
          next if target.fainted?
          next if target.damageState.unaffected
          next if target.damageState.substitute
          next if target.damageState.disguise || target.damageState.iceFace
          next if target.damageState.calcDamage <= 0

          key = target.object_id
          eligible = previous_status[key] ||
                     context[:inflicted][key] ||
                     target.status != :NONE

          next if !eligible
          Debilitate.apply(user, target, @battle)
        end
      end

      return result
    ensure
      @battle.instance_variable_set(
        :@debilitate_hit_context, old_context
      )
    end
  end

  #----------------------------------------------------------------------------
  # Ghi nhận trạng thái vừa gây ra.
  # Vẫn ghi nhận nếu Lum Berry chữa trạng thái ngay sau đó.
  #----------------------------------------------------------------------------
  alias_method :debilitate_original_inflict_status, :pbInflictStatus

  def pbInflictStatus(newStatus, newStatusCount = 0, msg = nil, user = nil)
    context = @battle.instance_variable_get(:@debilitate_hit_context)

    if context && newStatus != :NONE &&
       context[:targets].include?(self) &&
       self.index != context[:user].index &&
       (!user || user == context[:user])

      context[:inflicted][object_id] = true
    end

    return debilitate_original_inflict_status(
      newStatus, newStatusCount, msg, user
    )
  end
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:DEBILITATE)
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :DEBILITATE

Battle::AI::Handlers::AbilityRanking.add(:DEBILITATE,
  proc { |ability, score, battler, ai|
    next 0 if !battler.moves.any? { |move| move.damagingMove? }
    next score
  }
)

#------------------------------------------------------------------------------
# AI: Ưu tiên đánh mục tiêu đã có trạng thái.
# Không giả định đòn đánh chắc chắn gây thêm trạng thái.
#------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
  :debilitate_statused_target,
  proc { |score, move, user, target, ai, battle|
    next score if !user.has_active_ability?(:DEBILITATE)
    next score if !move.damagingMove?
	next score if !move.move.pbContactMove?(user.battler)
    next score if !target.opposes?(user)
    next score if target.status == :NONE
    next score if target.effects[PBEffects::Substitute] > 0
    next score if move.rough_damage >= target.hp

    # Tránh giúp mục tiêu tăng chỉ số hoặc phản lại hiệu ứng.
    if target.has_active_ability?([:CONTRARY, :MIRRORARMOR])
      next score - 15
    end

    usable_stats = Debilitate::STATS.count do |stat|
      target.battler.pbCanLowerStatStage?(stat, user.battler)
    end

    next score if usable_stats == 0
    score += usable_stats * 5

    if target.has_active_ability?([:DEFIANT, :COMPETITIVE])
      score -= 15
    end

    next score
  }
)

#------------------------------------------------------------------------------
# Berry Bulk
#------------------------------------------------------------------------------
class Battle::Battler
  alias_method :berry_bulk_original_held_item_triggered,
               :pbHeldItemTriggered

  def pbHeldItemTriggered(item_to_use, own_item = true, fling = false)
    is_berry = GameData::Item.get(item_to_use).is_berry?

    # Xử lý hiệu ứng gốc, Cheek Pouch và tiêu thụ vật phẩm.
    result = berry_bulk_original_held_item_triggered(
      item_to_use, own_item, fling
    )

    return result if !is_berry || fainted?
    return result if !hasActiveAbility?(:BERRYBULK)

    stats = [:DEFENSE, :SPECIAL_DEFENSE]
    return result if !stats.any? do |stat|
      pbCanRaiseStatStage?(stat, self)
    end

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(:BERRYBULK).name
      $aamName  = ability_name
      $aamName2 = ability_name

      @battle.pbShowAbilitySplash(self)

      stats.each do |stat|
        pbRaiseStatStageByAbility(stat, 1, self, false)
      end
    ensure
      begin
        @battle.pbHideAbilitySplash(self)
      ensure
        $aamName  = old_name
        $aamName2 = old_name2
      end
    end

    return result
  end
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:BERRYBULK)
end

Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
Battle::AI::BASE_ABILITY_RATINGS[6] << :BERRYBULK

Battle::AI::Handlers::AbilityRanking.add(:BERRYBULK,
  proc { |ability, score, battler, ai|
    b = battler.battler

    next 8 if b.hasActiveAbility?(:CHEEKPOUCH)
    next 7 if b.item && b.item.is_berry?
    next 6 if b.hasActiveAbility?([:HARVEST, :CUDCHEW])
    next 2
  }
)

#------------------------------------------------------------------------------
# Infiltrator Enhanced
#------------------------------------------------------------------------------
module InfiltratorEnhanced
  PERSONAL_PROTECTION = [
    :Protect,
    :KingsShield,
    :SpikyShield,
    :BanefulBunker,
    :Obstruct,
    :SilkTrap,
    :BurningBulwark
  ].freeze

  SIDE_PROTECTION = [
    :CraftyShield,
    :MatBlock,
    :QuickGuard,
    :WideGuard
  ].freeze

  # Tạm bỏ các lớp bảo vệ trong quá trình xử lý chiêu của Infiltrator.
  # Khôi phục sau đó để không ảnh hưởng đòn đánh của Pokémon khác.
  def self.with_bypass(user, targets)
    return yield if !user || !user.hasActiveAbility?(:INFILTRATOR)

    snapshots = []
    recorded = {}

    save_effect = proc do |effects, key, temporary_value|
      identity = [effects.object_id, key]
      next if recorded[identity]

      recorded[identity] = true
      snapshots << [effects, key, effects[key]]
      effects[key] = temporary_value
    end

    begin
      targets.compact.uniq.each do |target|
        next if target.index == user.index

        PERSONAL_PROTECTION.each do |name|
          next if !PBEffects.const_defined?(name)
          save_effect.call(
            target.effects, PBEffects.const_get(name), false
          )
        end

        SIDE_PROTECTION.each do |name|
          next if !PBEffects.const_defined?(name)
          save_effect.call(
            target.pbOwnSide.effects, PBEffects.const_get(name), false
          )
        end

        # Bao gồm cả những hiệu ứng phụ kiểm tra Substitute trực tiếp.
        save_effect.call(target.effects, PBEffects::Substitute, 0)
      end

      return yield
    ensure
      snapshots.reverse_each do |effects, key, original_value|
        effects[key] = original_value
      end
    end
  end
end

#------------------------------------------------------------------------------
# Khai báo khả năng xuyên Substitute cho các kiểm tra thông thường.
#------------------------------------------------------------------------------
class Battle::Move
  alias_method :infiltrator_enhanced_original_ignores_substitute,
               :ignoresSubstitute?

  def ignoresSubstitute?(user)
    return true if user && user.hasActiveAbility?(:INFILTRATOR)
    return infiltrator_enhanced_original_ignores_substitute(user)
  end
end

#------------------------------------------------------------------------------
# Trận đấu: xuyên Protect và Substitute ở bước kiểm tra mục tiêu.
#------------------------------------------------------------------------------
class Battle::Battler
  alias_method :infiltrator_enhanced_original_success_check,
               :pbSuccessCheckAgainstTarget

  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    return InfiltratorEnhanced.with_bypass(user, [target]) do
      infiltrator_enhanced_original_success_check(
        move, user, target, targets
      )
    end
  end

  #----------------------------------------------------------------------------
  # Xử lý toàn bộ hit, bao gồm sát thương và hiệu ứng phụ.
  # Substitute được giữ nguyên lượng HP sau khi xử lý.
  #----------------------------------------------------------------------------
  alias_method :infiltrator_enhanced_original_process_hit,
               :pbProcessMoveHit

  def pbProcessMoveHit(move, user, targets, hitNum, skipAccuracyCheck)
    return InfiltratorEnhanced.with_bypass(user, targets) do
      infiltrator_enhanced_original_process_hit(
        move, user, targets, hitNum, skipAccuracyCheck
      )
    end
  end
end

#------------------------------------------------------------------------------
# AI: Kiểm tra khả năng đánh trúng và chấm điểm theo cùng cơ chế.
#------------------------------------------------------------------------------
class Battle::AI
  alias_method :infiltrator_enhanced_original_predict_failure,
               :pbPredictMoveFailureAgainstTarget

  def pbPredictMoveFailureAgainstTarget
    return infiltrator_enhanced_original_predict_failure if !@target

    return InfiltratorEnhanced.with_bypass(
      @user.battler, [@target.battler]
    ) do
      infiltrator_enhanced_original_predict_failure
    end
  end

  alias_method :infiltrator_enhanced_original_target_score,
               :pbGetMoveScoreAgainstTarget

  def pbGetMoveScoreAgainstTarget
    return infiltrator_enhanced_original_target_score if !@target

    return InfiltratorEnhanced.with_bypass(
      @user.battler, [@target.battler]
    ) do
      infiltrator_enhanced_original_target_score
    end
  end
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:INFILTRATOR)
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :INFILTRATOR


#------------------------------------------------------------------------------
# Leaf Guard Enhanced
#------------------------------------------------------------------------------
module LeafGuardEnhanced
  def self.conditions_met?(battler)
    return [:Sun, :HarshSun].include?(battler.effectiveWeather) ||
           battler.battle.field.terrain == :Grassy
  end

  def self.active?(battler)
    return !battler.fainted? &&
           battler.hasActiveAbility?(:LEAFGUARD) &&
           conditions_met?(battler)
  end
end

#------------------------------------------------------------------------------
# Miễn nhiễm trạng thái khi có nắng hoặc Grassy Terrain
#------------------------------------------------------------------------------
Battle::AbilityEffects::StatusImmunity.add(:LEAFGUARD,
  proc { |ability, battler, status|
    next LeafGuardEnhanced.active?(battler)
  }
)

#------------------------------------------------------------------------------
# Giảm 20% sát thương từ chiêu thức
#------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromTarget.add(:LEAFGUARD,
  proc { |ability, user, target, move, mults, power, type|
    next if !LeafGuardEnhanced.active?(target)
    mults[:final_damage_multiplier] *= 0.8
  }
)

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:LEAFGUARD)
end

Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
Battle::AI::BASE_ABILITY_RATINGS[6] << :LEAFGUARD

Battle::AI::Handlers::AbilityRanking.add(:LEAFGUARD,
  proc { |ability, score, battler, ai|
    next 8 if LeafGuardEnhanced.conditions_met?(battler.battler)

    if battler.has_move_with_function?(
      "StartSunWeather", "StartGrassyTerrain"
    )
      next 6
    end

    next 3
  }
)

#------------------------------------------------------------------------------
# Shell Armor - Preserve existing effects, add special damage reduction
#------------------------------------------------------------------------------
shell_armor_previous_handler =
  Battle::AbilityEffects::DamageCalcFromTarget[:SHELLARMOR]

Battle::AbilityEffects::DamageCalcFromTarget.add(:SHELLARMOR,
  proc { |ability, user, target, move, mults, power, type|
    if shell_armor_previous_handler
      shell_armor_previous_handler.call(
        ability, user, target, move, mults, power, type
      )
    end

    if move.specialMove?
      mults[:final_damage_multiplier] *= 0.85
    end
  }
)

#------------------------------------------------------------------------------
# Battle Armor - Preserve existing effects, add physical damage reduction
#------------------------------------------------------------------------------
battle_armor_previous_handler =
  Battle::AbilityEffects::DamageCalcFromTarget[:BATTLEARMOR]

Battle::AbilityEffects::DamageCalcFromTarget.add(:BATTLEARMOR,
  proc { |ability, user, target, move, mults, power, type|
    if battle_armor_previous_handler
      battle_armor_previous_handler.call(
        ability, user, target, move, mults, power, type
      )
    end

    if move.physicalMove?
      mults[:final_damage_multiplier] *= 0.85
    end
  }
)

#------------------------------------------------------------------------------
# Florescence
#------------------------------------------------------------------------------
Battle::AbilityEffects::PriorityChange.add(:FLORESCENCE,
  proc { |ability, battler, move, priority|
    next priority if battler.hp * 2 <= battler.totalhp
    next priority if move.type != :GRASS

    next priority + 1
  }
)

#------------------------------------------------------------------------------
# AI: Ability rating
# AI dùng chung PriorityChange để tính thứ tự hành động.
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:FLORESCENCE)
end

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
Battle::AI::BASE_ABILITY_RATINGS[7] << :FLORESCENCE

Battle::AI::Handlers::AbilityRanking.add(:FLORESCENCE,
  proc { |ability, score, battler, ai|
    next 0 if !battler.check_for_move { |move| move.type == :GRASS }
    next 8 if battler.hp * 2 > battler.totalhp
    next 4
  }
)

#------------------------------------------------------------------------------
# Spore Veil - Once per move, not once per hit
#------------------------------------------------------------------------------
class Battle::Battler
  alias_method :spore_veil_original_use_move, :pbUseMove

  def pbUseMove(choice, specialUsage = false)
    old_targets = @spore_veil_targets_hit

    begin
      @spore_veil_targets_hit = {}
      return spore_veil_original_use_move(choice, specialUsage)
    ensure
      @spore_veil_targets_hit = old_targets
    end
  end
end

Battle::AbilityEffects::OnBeingHit.add(:SPOREVEIL,
  proc { |ability, user, target, move, battle|
    next if target.fainted?
    next if !target.hasActiveAbility?(:SPOREVEIL)
    next if !move.damagingMove?
    next if target.damageState.substitute
    next if target.damageState.calcDamage <= 0

    # Danh sách được làm mới mỗi lần người tấn công dùng chiêu.
    affected = user.instance_variable_get(:@spore_veil_targets_hit)
    affected ||= {}
    user.instance_variable_set(:@spore_veil_targets_hit, affected)

    key = [target.index, target.pokemon.object_id]
    next if affected[key]
    affected[key] = true

    next if !target.pbCanRaiseStatStage?(:EVASION, target)

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(ability).name
      $aamName  = ability_name
      $aamName2 = ability_name

      target.pbRaiseStatStageByAbility(:EVASION, 1, target)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  }
)

#------------------------------------------------------------------------------
# Wind Rider Enhanced
#------------------------------------------------------------------------------
Battle::AbilityEffects::MoveImmunity.add(:WINDRIDER,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if user.index == target.index
    next false if !target.hasActiveAbility?(:WINDRIDER)
    next false if type != :FLYING && !move.windMove?

    # Khi AI chỉ kiểm tra miễn nhiễm, không thay đổi chỉ số.
    if show_message
      old_name  = $aamName
      old_name2 = $aamName2

      begin
        ability_name = GameData::Ability.get(ability).name
        $aamName  = ability_name
        $aamName2 = ability_name

        battle.pbShowAbilitySplash(target)

        stats = [:ATTACK]
        stats << :SPEED if move.windMove?

        raised = false

        stats.each do |stat|
          next if !target.pbCanRaiseStatStage?(stat, target)

          changed = target.pbRaiseStatStageByAbility(
            stat, 1, target, false
          )
          raised = true if changed
        end

        if !raised
          battle.pbDisplay(_INTL(
            "{1}'s {2} made {3} ineffective!",
            target.pbThis, ability_name, move.name
          ))
        end
      ensure
        begin
          battle.pbHideAbilitySplash(target)
        ensure
          $aamName  = old_name
          $aamName2 = old_name2
        end
      end
    end

    next true
  }
)

#------------------------------------------------------------------------------
# AI: Nhận biết miễn nhiễm Flying/Wind khi đánh giá Pokémon đổi vào.
# Bao gồm Wind Rider là innate.
#------------------------------------------------------------------------------
class Battle::AI
  alias_method :wind_rider_enhanced_original_absorb_move,
               :pokemon_can_absorb_move?

  def pokemon_can_absorb_move?(pkmn, move, move_type)
    wind_rider = false

    if pkmn.is_a?(Battle::AI::AIBattler)
      wind_rider = pkmn.has_active_ability?(:WINDRIDER)
    else
      wind_rider = pkmn.hasAbility?(:WINDRIDER)

      if !wind_rider && pkmn.respond_to?(:set_innate_limits)
        wind_rider = pkmn.set_innate_limits.include?(:WINDRIDER)
      end
    end

    if wind_rider
      move_data = GameData::Move.get(move.id)
      return true if move_type == :FLYING || move_data.has_flag?("Wind")
    end

    return wind_rider_enhanced_original_absorb_move(
      pkmn, move, move_type
    )
  end
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:WINDRIDER)
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :WINDRIDER

#------------------------------------------------------------------------------
# Seed Stimulus
#------------------------------------------------------------------------------

# Xóa hiệu ứng cũ kích hoạt theo từng hit.
Battle::AbilityEffects::OnDealingHit.remove(:SEEDSTIMULUS)

Battle::AbilityEffects::OnEndOfUsingMove.add(:SEEDSTIMULUS,
  proc { |ability, user, targets, move, battle|
    next if user.fainted?
    next if !user.hasActiveAbility?(:SEEDSTIMULUS)
    next if user.status != :NONE
    next if move.calcType != :GRASS

    # Không kích hoạt ở lượt tích lực của Solar Beam/Solar Blade.
    next if user.effects[PBEffects::TwoTurnAttack]

    stats = [:ATTACK, :SPECIAL_ATTACK]
    next if !stats.any? do |stat|
      user.pbCanRaiseStatStage?(stat, user)
    end

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(ability).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battle.pbShowAbilitySplash(user)

      stats.each do |stat|
        user.pbRaiseStatStageByAbility(stat, 1, user, false)
      end
    ensure
      begin
        battle.pbHideAbilitySplash(user)
      ensure
        $aamName  = old_name
        $aamName2 = old_name2
      end
    end
  }
)

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:SEEDSTIMULUS)
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :SEEDSTIMULUS

Battle::AI::Handlers::AbilityRanking.add(:SEEDSTIMULUS,
  proc { |ability, score, battler, ai|
    next 0 if !battler.check_for_move { |move| move.type == :GRASS }
    next 8 if battler.status == :NONE
    next 3
  }
)

#------------------------------------------------------------------------------
# AI: Ưu tiên chiêu Grass khi có thể nhận tăng chỉ số.
#------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(:seed_stimulus_boost,
  proc { |score, move, user, ai, battle|
    next score if !user.has_active_ability?(:SEEDSTIMULUS)
    next score if user.status != :NONE
    next score if move.rough_type != :GRASS

    if user.has_active_ability?(:CONTRARY)
      next score - 15
    end

    [:ATTACK, :SPECIAL_ATTACK].each do |stat|
      if user.battler.pbCanRaiseStatStage?(stat, user.battler)
        score += 8
      end
    end

    next score
  }
)

#------------------------------------------------------------------------------
# False Front
#------------------------------------------------------------------------------
module FalseFront
  TYPES = [:FIGHTING, :FAIRY, :DARK].freeze

  def self.choose_type(battler, battle)
    if battler.pbOwnedByPlayer?
      commands = TYPES.map { |type| GameData::Type.get(type).name }

      loop do
        choice = battle.pbShowCommands(
          _INTL("Choose an additional type for {1}.", battler.pbThis(true)),
          commands,
          -1
        )

        return TYPES[choice] if choice && choice >= 0 &&
                                      choice < TYPES.length
      end
    end

    return choose_ai_type(battler, battle)
  end

  # AI cân nhắc hệ phòng thủ trước chiêu của đối thủ
  # và khả năng nhận STAB cho các chiêu đang có.
  def self.choose_ai_type(battler, battle)
    scores = TYPES.map do |type|
      types = (battler.pbTypes + [type]).uniq
      score = 0.0

      battle.allOtherSideBattlers(battler.index).each do |foe|
        next if foe.fainted?

        threats = foe.moves.select { |move| move.damagingMove? }
        next if threats.empty?

        worst = threats.map do |move|
          effectiveness = Effectiveness.calculate(move.type, *types)
          stab = foe.pbHasType?(move.type) ? 1.5 : 1.0
          effectiveness * stab
        end.max

        score -= worst * 10
      end

      if !battler.pbHasType?(type) &&
         battler.moves.any? { |move| move.damagingMove? && move.type == type }
        score += 8
      end

      score
    end

    best = scores.max
    candidates = TYPES.each_index.select { |i| scores[i] == best }
    return TYPES[candidates[battle.pbRandom(candidates.length)]]
  end
end

#------------------------------------------------------------------------------
# Reset lựa chọn khi chuẩn bị một lần vào sân mới.
# Bao gồm cả trường hợp Baton Pass.
#------------------------------------------------------------------------------
class Battle::Battler
  attr_accessor :false_front_chosen_type

  alias_method :false_front_original_init_effects, :pbInitEffects

  def pbInitEffects(batonPass)
    false_front_original_init_effects(batonPass)
    @false_front_chosen_type = nil
  end
end

#------------------------------------------------------------------------------
# Chọn và thêm hệ khi vào sân.
# Chặn việc mở lại menu nhiều lần trong cùng một lần ở trên sân.
#------------------------------------------------------------------------------
Battle::AbilityEffects::OnSwitchIn.add(:FALSEFRONT,
  proc { |ability, battler, battle, switch_in|
    next if battler.fainted?
    next if !battler.hasActiveAbility?(:FALSEFRONT)
    next if battler.false_front_chosen_type
    next if !battler.canChangeType?

    chosen_type = FalseFront.choose_type(battler, battle)
    battler.false_front_chosen_type = chosen_type

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      ability_name = GameData::Ability.get(ability).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battle.pbShowAbilitySplash(battler)

      # Giữ nguyên hệ gốc, sử dụng ô hệ bổ sung của Essentials.
      battler.effects[PBEffects::ExtraType] =
        battler.pbTypes.include?(chosen_type) ? nil : chosen_type

      battle.pbDisplay(_INTL(
        "{1} gained the {2} type!",
        battler.pbThis,
        GameData::Type.get(chosen_type).name
      ))
    ensure
      begin
        battle.pbHideAbilitySplash(battler)
      ensure
        $aamName  = old_name
        $aamName2 = old_name2
      end
    end
  }
)

#------------------------------------------------------------------------------
# Xóa hệ do False Front thêm khi rút về.
# Không xóa hệ bổ sung khác nếu nó đã thay thế hệ của False Front.
#------------------------------------------------------------------------------
Battle::AbilityEffects::OnSwitchOut.add(:FALSEFRONT,
  proc { |ability, battler, end_of_battle|
    chosen_type = battler.false_front_chosen_type

    if chosen_type &&
       battler.effects[PBEffects::ExtraType] == chosen_type
      battler.effects[PBEffects::ExtraType] = nil
    end

    battler.false_front_chosen_type = nil
  }
)

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:FALSEFRONT)
end

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
Battle::AI::BASE_ABILITY_RATINGS[7] << :FALSEFRONT

#------------------------------------------------------------------------------
# Thick Fat - Boosts Slam and Body Slam
#------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:THICKFAT,
  proc { |ability, user, target, move, mults, power, type|
    next if ![:SLAM, :BODYSLAM].include?(move.id)

    mults[:final_damage_multiplier] *= 1.5
  }
)

#------------------------------------------------------------------------------
# Ball Fetch - Copies opposing ball and bomb moves
#------------------------------------------------------------------------------
module BallFetchEnhanced
  def self.copy_move(battler, source, move, battle)
    return if battler.fainted?
    return if !battler.hasActiveAbility?(:BALLFETCH)

    copied_move = Battle::Move.from_pokemon_move(
      battle, Pokemon::Move.new(move.id)
    )

    # Kiểm tra các giới hạn dùng chiêu theo cơ chế gọi chiêu.
    return if !battler.pbCanChooseMove?(
      copied_move, false, false, true
    )

    old_name         = $aamName
    old_name2        = $aamName2
    old_round_moved  = battler.lastRoundMoved
    old_current_move = battler.currentMove
    old_outrage      = battler.effects[PBEffects::Outrage]
    old_dancer       = battler.effects[PBEffects::Dancer]

    begin
      ability_name = GameData::Ability.get(:BALLFETCH).name
      $aamName  = ability_name
      $aamName2 = ability_name

      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL(
        "{1} fetched and returned {2}!",
        battler.pbThis, move.name
      ))
      battle.pbHideAbilitySplash(battler)

      # Giống cơ chế gọi chiêu của Dancer:
      # không biến đòn sao chép thành hành động chính của lượt.
      battler.effects[PBEffects::Dancer] = true
      if old_outrage > 0
        battler.effects[PBEffects::Outrage] += 1
      end

      battler.pbUseMoveSimple(move.id, source.index)
    ensure
      battler.lastRoundMoved = old_round_moved
      battler.currentMove = old_current_move
      battler.effects[PBEffects::Outrage] = old_outrage
      battler.effects[PBEffects::Dancer] = old_dancer

      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
end

#------------------------------------------------------------------------------
# Ghi nhận Bomb/Ball move khi chiêu được tung ra, trước kiểm tra trúng/trượt.
#------------------------------------------------------------------------------
class Battle::Move
  alias_method :ball_fetch_original_display_use_message,
               :pbDisplayUseMessage

  def pbDisplayUseMessage(user)
    result = ball_fetch_original_display_use_message(user)

    if bombMove? &&
       !@battle.instance_variable_get(:@ball_fetch_copying)

      fetchers = @battle.pbPriority(true).select do |battler|
        battler.opposes?(user) &&
          !battler.fainted? &&
          battler.hasActiveAbility?(:BALLFETCH)
      end

      # Lưu cả Pokémon để tránh nhầm khi slot đã đổi chủ.
      fetchers = fetchers.map do |battler|
        [battler, battler.pokemon]
      end

      user.instance_variable_set(
        :@ball_fetch_announced_move,
        [self, fetchers]
      )
    end

    return result
  end
end

#------------------------------------------------------------------------------
# Sau khi xử lý xong chiêu gốc, thực hiện các đòn sao chép.
# Không yêu cầu chiêu gốc đánh trúng.
#------------------------------------------------------------------------------
class Battle::Battler
  alias_method :ball_fetch_original_use_move, :pbUseMove

  def pbUseMove(choice, specialUsage = false)
    old_record = @ball_fetch_announced_move

    begin
      @ball_fetch_announced_move = nil
      result = ball_fetch_original_use_move(choice, specialUsage)
      record = @ball_fetch_announced_move

      return result if !record
      return result if @battle.decision > 0
      return result if @battle.instance_variable_get(:@ball_fetch_copying)

      copied_move, fetchers = record
      return result if fetchers.empty?

      begin
        @battle.instance_variable_set(:@ball_fetch_copying, true)

        fetchers.each do |battler, original_pokemon|
          break if @battle.decision > 0
          next if battler.pokemon != original_pokemon
          next if battler.fainted?
          next if !battler.hasActiveAbility?(:BALLFETCH)

          BallFetchEnhanced.copy_move(
            battler, self, copied_move, @battle
          )

          @battle.pbJudge
        end
      ensure
        @battle.instance_variable_set(:@ball_fetch_copying, false)
      end

      return result
    ensure
      @ball_fetch_announced_move = old_record
    end
  end
end

#------------------------------------------------------------------------------
# AI: Ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:BALLFETCH)
end

Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
Battle::AI::BASE_ABILITY_RATINGS[6] << :BALLFETCH

#------------------------------------------------------------------------------
# AI: Hạn chế dùng chiêu Bomb/Ball khi đối thủ có thể sao chép.
#------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveScore.add(
  :ball_fetch_opposing_copy,
  proc { |score, move, user, ai, battle|
    next score if !move.move.bombMove?

    battle.allOtherSideBattlers(user.index).each do |opponent|
      next if opponent.fainted?
      next if !opponent.hasActiveAbility?(:BALLFETCH)

      score -= 15
    end

    next score
  }
)

#------------------------------------------------------------------------------
# Dodge - AI ability rating
#------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:DODGE)
end

Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
Battle::AI::BASE_ABILITY_RATINGS[6] << :DODGE

Battle::AI::Handlers::AbilityRanking.add(:DODGE,
  proc { |ability, score, battler, ai|
    next score
  }
)

#===============================================================================
# Wild Tantrum - AI
#===============================================================================
module WildTantrumAI
  def self.physical_attacker?(battler)
    return battler.moves.any? { |m| m.damagingMove? && m.physicalMove? }
  end

  # Estimate hit count without calling pbNumHits or consuming battle RNG.
  def self.expected_hits(move, user)
    function = move.function_code

    return 2.0 if function.start_with?("HitTwoTimes")
    return 3.0 if function.start_with?("HitThreeTimes")

    if function.start_with?("HitTwoToFiveTimes")
      if function == "HitTwoToFiveTimesOrThreeForAshGreninja" &&
         user.isSpecies?(:GRENINJA) && user.form == 2
        return 3.0
      end
      return 5.0 if user.hasActiveAbility?(:SKILLLINK)
      return 4.5 if user.hasActiveItem?(:LOADEDDICE)
      return 3.1
    end

    return 10.0 if function.start_with?("HitTenTimes")
    return move.multiHitMove? ? 3.0 : 1.0
  end

  # Positive = Attack increases; negative = Contrary lowers Attack.
  def self.attack_change(target, battle)
    change = 1
    if !battle.moldBreaker
      change = -1 if target.hasActiveAbility?(:CONTRARY)
      change *= 2 if target.hasActiveAbility?(:SIMPLE)
    end

    limit = Battle::Battler::STAT_STAGE_MAXIMUM
    stage = target.stages[:ATTACK]

    return [change, limit - stage].min if change > 0
    return -[-change, stage + limit].min
  end

  def self.relevant?(move, user, target)
    return false if !user || !target || target.fainted?
    return false if !user.opposes?(target)
    return false if !move.damagingMove?
    return false if !target.hasActiveAbility?(:WILDTANTRUM)
    return false if !physical_attacker?(target)

    # Conservative estimate: don't predict breaking a Substitute.
    if target.effects[PBEffects::Substitute] > 0 &&
       !move.ignoresSubstitute?(user)
      return false
    end

    return true
  end

  def self.score_change(move, user, target, battle, damage)
    return 0 if damage <= 0
    return 0 if damage >= target.hp

    change = attack_change(target, battle)
    return 0 if change == 0

    hits = expected_hits(move, user)
    expected_change = 0.30 * hits * change.abs
    penalty = [(10 * expected_change).round, 18].min

    # Lowering an opposing physical attacker's Attack is beneficial.
    return change > 0 ? -penalty : penalty
  end
end

#-------------------------------------------------------------------------------
# Ability value
#-------------------------------------------------------------------------------
Battle::AI::Handlers::AbilityRanking.add(:WILDTANTRUM,
  proc { |ability, score, battler, ai|
    next 0 if !WildTantrumAI.physical_attacker?(battler.battler)
    next(-3) if battler.has_active_ability?(:CONTRARY)
    next 1 if battler.statStageAtMax?(:ATTACK)
    next 8 if battler.has_active_ability?(:SIMPLE)
    next 6
  }
)

#-------------------------------------------------------------------------------
# Remove the generic OnBeingHit penalty for a primary Wild Tantrum.
# Its specific scoring below replaces that penalty.
# Preserve the existing handling of other abilities and items.
#-------------------------------------------------------------------------------
wild_tantrum_previous_hit_score =
  Battle::AI::Handlers::GeneralMoveAgainstTargetScore[
    :trigger_target_ability_or_item_upon_hit
  ]

if wild_tantrum_previous_hit_score
  Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
    :trigger_target_ability_or_item_upon_hit,
    proc { |score, move, user, target, ai, battle|
      score = wild_tantrum_previous_hit_score.call(
        score, move, user, target, ai, battle
      )

      if ai.trainer.high_skill? && move.damagingMove? &&
         target.effects[PBEffects::Substitute] == 0 &&
         target.ability_active? &&
         target.battler.ability_id == :WILDTANTRUM
        score += 8
      end

      next score
    }
  )
end

#-------------------------------------------------------------------------------
# Essentials AI
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:wild_tantrum,
  proc { |score, move, user, target, ai, battle|
    next score if !ai.trainer.medium_skill?

    attacker = user.battler
    defender = target.battler
    native_move = move.move

    next score if !WildTantrumAI.relevant?(
      native_move, attacker, defender
    )

    score += WildTantrumAI.score_change(
      native_move, attacker, defender, battle, move.rough_damage
    )

    next score
  }
)

#-------------------------------------------------------------------------------
# Advanced AI - uses a separate scoring pipeline.
#-------------------------------------------------------------------------------
if defined?(AdvancedAI) &&
   Battle::AI.method_defined?(:score_move_advanced)
  class Battle::AI
    alias_method :wild_tantrum_original_advanced_score,
                 :score_move_advanced

    def score_move_advanced(move, user, target, skill)
      score = wild_tantrum_original_advanced_score(
        move, user, target, skill
      )
      return score if score <= 0

      attacker = user.respond_to?(:battler) ? user.battler : user
      defender = target.respond_to?(:battler) ? target.battler : target
      native_move = move.respond_to?(:move) ? move.move : move

      return score if !WildTantrumAI.relevant?(
        native_move, attacker, defender
      )

      damage = AdvancedAI::CombatUtilities.estimate_damage(
        attacker, native_move, defender
      )

      return score + WildTantrumAI.score_change(
        native_move, attacker, defender, @battle, damage
      )
    end
  end
end

#===============================================================================
# Added types retain their benefits without adding weaknesses.
# Uses the same damage-compensation approach as Aquatic.
#===============================================================================
{
  :HALFDRAKE => {
    :type       => :DRAGON,
    :weaknesses => [:ICE, :DRAGON, :FAIRY]
  },
  :BUGBOUND => {
    :type       => :BUG,
    :weaknesses => [:FIRE, :FLYING, :ROCK]
  },
  :FIERYSPIRIT => {
    :type       => :FIRE,
    :weaknesses => [:WATER, :GROUND, :ROCK]
  }
}.each do |ability_id, data|
  Battle::AbilityEffects::DamageCalcFromTarget.add(ability_id,
    proc { |ability, user, target, move, mults, power, type|
      added_type = data[:type]

      # Only compensate when this is the currently added type.
      next if target.effects[PBEffects::ExtraType] != added_type

      # The type must actually be present as an additional type,
      # rather than already being part of the Pokémon's current base types.
      next if !target.pbHasType?(added_type)
      next if target.pbTypes(false).include?(added_type)

      next if !data[:weaknesses].include?(type)

      # Cancel the added type's x2 weakness.
      mults[:final_damage_multiplier] /= 2.0
    }
  )
end


#===============================================================================
# Half Drake / Bugbound / Fiery Spirit - AI
#===============================================================================
module AddedTypeGuardAI
  DATA = {
    :HALFDRAKE   => [:DRAGON, [:ICE, :DRAGON, :FAIRY]],
    :BUGBOUND    => [:BUG,    [:FIRE, :FLYING, :ROCK]],
	:AQUATIC     => [:WATER,  [:ELECTRIC, :GRASS]],
    :FIERYSPIRIT => [:FIRE,   [:WATER, :GROUND, :ROCK]]
  }

  def self.real_battler(value)
    return value.respond_to?(:battler) ? value.battler : value
  end

  # Compensation for the weakness caused by the added type.
  def self.damage_factor(attacker, target, move, type)
    attacker = real_battler(attacker)
    target   = real_battler(target)
    return 1.0 if !attacker || !target
    return 1.0 if !target.respond_to?(:effects)
    return 1.0 if !target.respond_to?(:hasActiveAbility?)

    if AdvancedAI::Utilities.ignores_ability?(attacker, move, target)
      return 1.0
    end

    DATA.each do |ability, data|
      added_type, weaknesses = data

      next if target.effects[PBEffects::ExtraType] != added_type
      next if !target.hasActiveAbility?(ability)
      next if !target.pbHasType?(added_type)
      next if target.pbTypes(false).include?(added_type)
      next if !weaknesses.include?(type)

      return 0.5
    end

    return 1.0
  end
end

#-------------------------------------------------------------------------------
# Essentials AI - ability ranking
#-------------------------------------------------------------------------------
AddedTypeGuardAI::DATA.each do |ability_id, data|
  Battle::AI::Handlers::AbilityRanking.add(ability_id,
    proc { |ability, score, battler, ai|
      added_type, weaknesses = data
      real = battler.battler
      base_types = real.pbTypes(false)

      # No benefit if the Pokémon already has this type naturally/currently.
      next 0 if base_types.include?(added_type)
      next 0 if real.respond_to?(:tera?) && real.tera?

      # Additional typing without its added weaknesses.
      value = 7

      # Offensive value: an additional STAB.
      if battler.check_for_move { |m|
           m.damagingMove? && m.type == added_type
         }
        value += 2
      end

      # Defensive value against the opponents' damaging moves.
      defensive_value = 0
      real.allOpposing.each do |foe|
        useful_resistance = foe.moves.any? do |m|
          next false if !m.damagingMove?

          # Weaknesses of the added type are compensated, not resisted.
          next false if weaknesses.include?(m.type)

          before = Effectiveness.calculate(m.type, *base_types)
          after  = Effectiveness.calculate(
            m.type, *(base_types + [added_type]).uniq
          )

          next after < before
        end

        defensive_value += 1 if useful_resistance
      end

      value += [defensive_value, 2].min
      next value
    }
  )
end

#-------------------------------------------------------------------------------
# Advanced AI - shared damage estimator
#-------------------------------------------------------------------------------
if defined?(AdvancedAI::CombatUtilities)
  module AddedTypeGuardAdvancedModifier
    def ability_damage_modifier(attacker, target, type, physical,
                                effectiveness, move = nil,
                                physical_defense = physical)
      result = super
      return result * AddedTypeGuardAI.damage_factor(
        attacker, target, move, type
      )
    end
  end

  AdvancedAI::CombatUtilities.singleton_class.prepend(
    AddedTypeGuardAdvancedModifier
  )
end

#-------------------------------------------------------------------------------
# Advanced AI - separate rough damage calculation
#-------------------------------------------------------------------------------
if defined?(AdvancedAI) &&
   Battle::AI.method_defined?(:calculate_rough_damage)
  module AddedTypeGuardAdvancedDamage
    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = super
      return result if result <= 0

      native_move = move.respond_to?(:move) ? move.move : move

      # Fixed damage and OHKO moves don't use damage multipliers.
      return result if native_move.is_a?(Battle::Move::FixedDamageMove)
      return result if native_move.function_code.start_with?("OHKO")

      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      factor = AddedTypeGuardAI.damage_factor(
        user, target, native_move, type
      )

      return result if factor == 1.0
      return [(result * factor).to_i, 1].max
    end
  end

  Battle::AI.prepend(AddedTypeGuardAdvancedDamage)
end

#===============================================================================
# Pack Leader - effect and AI
#===============================================================================
module PackLeader
  def self.real_battler(value)
    return value.respond_to?(:battler) ? value.battler : value
  end

  # Check the owner's team, not all Pokémon on the same side.
  def self.team_ready?(value)
    battler = real_battler(value)
    return false if !battler || battler.fainted?

    battle = battler.battle
    index  = battler.index
    first, last = battle.pbTeamIndexRangeFromBattlerIndex(index)
    party = battle.pbParty(index)

    return false if party[first] != battler.pokemon

    able_count = 0
    (first...last).each do |i|
      able_count += 1 if party[i] && party[i].able?
    end

    return able_count >= 3
  end

  def self.active?(value)
    battler = real_battler(value)
    return false if !battler
    return false if !battler.hasActiveAbility?(:PACKLEADER)
    return team_ready?(battler)
  end

  def self.show_message(battler, battle)
    old_name  = $aamName
    old_name2 = $aamName2

    begin
      name = GameData::Ability.get(:PACKLEADER).name
      $aamName  = name
      $aamName2 = name

      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("{1} leads the pack!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
end

#-------------------------------------------------------------------------------
# Battle effect
#-------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:PACKLEADER,
  proc { |ability, user, target, move, mults, power, type|
    next if !PackLeader.team_ready?(user)
    mults[:attack_multiplier] *= 1.3
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:PACKLEADER,
  proc { |ability, battler, battle, switch_in|
    next if !PackLeader.team_ready?(battler)
    PackLeader.show_message(battler, battle)
  }
)

#-------------------------------------------------------------------------------
# Essentials AI
# Native damage prediction already uses DamageCalcFromUser.
#-------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:PACKLEADER)
end
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
Battle::AI::BASE_ABILITY_RATINGS[6] << :PACKLEADER

Battle::AI::Handlers::AbilityRanking.add(:PACKLEADER,
  proc { |ability, score, battler, ai|
    next 0 if !PackLeader.team_ready?(battler)
    next 0 if !battler.check_for_move { |m| m.damagingMove? }
    next 9
  }
)

#-------------------------------------------------------------------------------
# Advanced AI - shared damage estimator
#-------------------------------------------------------------------------------
if defined?(AdvancedAI::CombatUtilities)
  module PackLeaderAdvancedModifier
    def ability_damage_modifier(attacker, target, type, physical,
                                effectiveness, move = nil,
                                physical_defense = physical)
      result = super
      result *= 1.3 if PackLeader.active?(attacker)
      return result
    end
  end

  AdvancedAI::CombatUtilities.singleton_class.prepend(
    PackLeaderAdvancedModifier
  )
end

#-------------------------------------------------------------------------------
# Advanced AI - separate rough damage calculation
#-------------------------------------------------------------------------------
if defined?(AdvancedAI) &&
   Battle::AI.method_defined?(:calculate_rough_damage)
  module PackLeaderAdvancedDamage
    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = super
      return result if result <= 0
      return result if !PackLeader.active?(user)

      native_move = move.respond_to?(:move) ? move.move : move

      # Fixed damage and OHKO moves don't benefit from offensive stats.
      return result if native_move.is_a?(Battle::Move::FixedDamageMove)
      return result if native_move.function_code.start_with?("OHKO")

      return (result * 1.3).to_i
    end
  end

  Battle::AI.prepend(PackLeaderAdvancedDamage)
end

#===============================================================================
# Pack Leader - only works during the Pokémon's first appearance per battle.
#===============================================================================
class Battle
  def pack_leader_entry_counts
    @pack_leader_entry_counts ||= {}
    return @pack_leader_entry_counts
  end
end

# Track actual entries, including entries made while the ability is suppressed.
module PackLeaderFirstEntryTracking
  def pbInitialize(pkmn, idxParty, batonPass = false)
    result = super

    # Exclude temporary battlers created for AI simulations.
    if idxParty >= 0 && @battle.battlers[@index].equal?(self)
      counts = @battle.pack_leader_entry_counts
      key = pkmn.object_id
      counts[key] = (counts[key] || 0) + 1
    end

    return result
  end
end

Battle::Battler.prepend(PackLeaderFirstEntryTracking)

# Extend the shared condition used by battle effects and AI.
module PackLeader
  class << self
    alias_method :team_ready_without_entry_limit?, :team_ready?

    def team_ready?(value)
      battler = real_battler(value)
      return false if !battler || !battler.pokemon

      counts = battler.battle.pack_leader_entry_counts
      entries = counts[battler.pokemon.object_id] || 0

      return false if entries > 1
      return team_ready_without_entry_limit?(battler)
    end
  end
end

#===============================================================================
# Tenacity
#===============================================================================
module Tenacity
  CHANCE = 30

  def self.show_message(target, battle)
    old_name  = $aamName
    old_name2 = $aamName2

    begin
      name = GameData::Ability.get(:TENACITY).name
      $aamName  = name
      $aamName2 = name

      battle.pbShowAbilitySplash(target)
      battle.pbDisplay(_INTL("{1} held on with {2}!",
                            target.pbThis, name))
      battle.pbHideAbilitySplash(target)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
end

#-------------------------------------------------------------------------------
# Battle effect
#-------------------------------------------------------------------------------
module TenacityMoveEffects
  def pbReduceDamage(user, target)
    state = target.damageState
    state.instance_variable_set(:@tenacity_triggered, false)

    result = super

    return result if target.fainted?
    return result if !user || user.index == target.index
    return result if state.substitute || state.disguise || state.iceFace
    return result if !target.hasActiveAbility?(:TENACITY)
    return result if @battle.moldBreaker

    # Existing survival effects take precedence.
    return result if state.hpLost < target.hp
    return result if @battle.pbRandom(100) >= Tenacity::CHANCE

    old_damage = state.hpLost
    state.hpLost = [target.hp - 1, 0].max
    state.totalHPLost -= old_damage - state.hpLost
    state.instance_variable_set(:@tenacity_triggered, true)

    return result
  end

  def pbEndureKOMessage(target)
    result = super
    state = target.damageState

    if state.instance_variable_get(:@tenacity_triggered)
      state.instance_variable_set(:@tenacity_triggered, false)
      Tenacity.show_message(target, @battle)
    end

    return result
  end
end

Battle::Move.prepend(TenacityMoveEffects)

#-------------------------------------------------------------------------------
# AI helpers
#-------------------------------------------------------------------------------
module TenacityAI
  def self.score_change(user, target, move, battle, damage)
    attacker = user.respond_to?(:battler) ? user.battler : user
    defender = target.respond_to?(:battler) ? target.battler : target
    native = move.respond_to?(:move) ? move.move : move

    return 0 if !attacker || !defender
    return 0 if !attacker.opposes?(defender)
    return 0 if !native.damagingMove?
    return 0 if !defender.hasActiveAbility?(:TENACITY)
    return 0 if damage < defender.hp

    if defender.effects[PBEffects::Substitute] > 0 &&
       !native.ignoresSubstitute?(attacker)
      return 0
    end

    if defined?(AdvancedAI::Utilities)
      return 0 if AdvancedAI::Utilities.ignores_ability?(
        attacker, native, defender
      )
    else
      return 0 if battle.moldBreaker
    end

    # A predicted KO is less reliable. Multi-hit attacks can finish
    # the target after an earlier hit activates Tenacity.
    return native.multiHitMove? ? -1 : -3
  end
end

#-------------------------------------------------------------------------------
# Essentials AI
#-------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:TENACITY)
end
Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
Battle::AI::BASE_ABILITY_RATINGS[7] << :TENACITY

Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:tenacity,
  proc { |score, move, user, target, ai, battle|
    next score if !ai.trainer.medium_skill?
    next score if !move.damagingMove?
    next score if !target.has_active_ability?(:TENACITY)

    score += TenacityAI.score_change(
      user, target, move, battle, move.rough_damage
    )
    next score
  }
)

#-------------------------------------------------------------------------------
# Advanced AI
#-------------------------------------------------------------------------------
if defined?(AdvancedAI::CombatUtilities) &&
   Battle::AI.method_defined?(:score_move_advanced)
  module TenacityAdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= 0 || !user || !target

      attacker = user.respond_to?(:battler) ? user.battler : user
      defender = target.respond_to?(:battler) ? target.battler : target
      native = move.respond_to?(:move) ? move.move : move

      return score if !native.damagingMove?
      return score if !defender.hasActiveAbility?(:TENACITY)

      damage = AdvancedAI::CombatUtilities.estimate_damage(
        attacker, native, defender
      )

      return score + TenacityAI.score_change(
        attacker, defender, native, @battle, damage
      )
    end
  end

  Battle::AI.prepend(TenacityAdvancedScoring)
end

#===============================================================================
# Water Veil - protect allies from Fire-type damage
#===============================================================================
Battle::AbilityEffects::DamageCalcFromTargetAlly.add(:WATERVEIL,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :FIRE
    mults[:final_damage_multiplier] *= 0.75
  }
)

#===============================================================================
# AI
#===============================================================================
module WaterVeilAI
  def self.real_battler(value)
    return value.respond_to?(:battler) ? value.battler : value
  end

  def self.fire_damage_factor(attacker, target, move, type)
    return 1.0 if type != :FIRE

    attacker = real_battler(attacker)
    target   = real_battler(target)
    return 1.0 if !attacker || !target
    return 1.0 if !target.respond_to?(:allAllies)

    return 1.0 if AdvancedAI::Utilities.ignores_ability?(
      attacker, move, target
    )

    protectors = [target] + target.allAllies.to_a
    count = protectors.count do |b|
      !b.fainted? && b.hasActiveAbility?(:WATERVEIL)
    end

    return 0.75 ** count
  end
end

#-------------------------------------------------------------------------------
# Essentials AI
# Damage handlers and Aqua Ring healing are already predicted natively.
#-------------------------------------------------------------------------------
Battle::AI::Handlers::AbilityRanking.add(:WATERVEIL,
  proc { |ability, score, battler, ai|
    value = 7
    value += 1 if battler.battler.allAllies.any? { |b| !b.fainted? }

    fire_threat = battler.battler.allOpposing.any? do |foe|
      foe.moves.any? { |m| m.damagingMove? && m.type == :FIRE }
    end

    value += 1 if fire_threat
    next value
  }
)

#-------------------------------------------------------------------------------
# Advanced AI - shared damage estimator
#-------------------------------------------------------------------------------
if defined?(AdvancedAI::CombatUtilities)
  module WaterVeilAdvancedModifier
    def ability_damage_modifier(attacker, target, type, physical,
                                effectiveness, move = nil,
                                physical_defense = physical)
      result = super

      return result * WaterVeilAI.fire_damage_factor(
        attacker, target, move, type
      )
    end
  end

  AdvancedAI::CombatUtilities.singleton_class.prepend(
    WaterVeilAdvancedModifier
  )
end

#-------------------------------------------------------------------------------
# Advanced AI - separate rough damage calculation
#-------------------------------------------------------------------------------
if defined?(AdvancedAI::CombatUtilities) &&
   Battle::AI.method_defined?(:calculate_rough_damage)
  module WaterVeilAdvancedDamage
    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = super
      return result if result <= 0

      native = move.respond_to?(:move) ? move.move : move
      return result if native.is_a?(Battle::Move::FixedDamageMove)
      return result if native.function_code.start_with?("OHKO")

      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      factor = WaterVeilAI.fire_damage_factor(
        user, target, native, type
      )

      return result if factor == 1.0
      return [(result * factor).to_i, 1].max
    end
  end

  Battle::AI.prepend(WaterVeilAdvancedDamage)
end

#===============================================================================
# Pierce Armor - corrected effect
#===============================================================================
module PierceArmorAI
  def self.eligible_move?(move)
    native = move.respond_to?(:move) ? move.move : move
    return native.damagingMove? &&
           (native.hornMove? || native.drillMove?)
  end
end

Battle::AbilityEffects::OnDealingHit.add(:PIERCEARMOR,
  proc { |ability, user, target, move, battle|
    next if user.fainted? || target.fainted?
    next if !PierceArmorAI.eligible_move?(move)
    next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
    next if !target.pbCanLowerStatStage?(:DEFENSE, user, move)

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      name = GameData::Ability.get(ability).name
      $aamName  = name
      $aamName2 = name

      battle.pbShowAbilitySplash(user)
      target.pbLowerStatStage(:DEFENSE, 1, user)
      battle.pbHideAbilitySplash(user)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  }
)

#===============================================================================
# Pierce Armor - AI
#===============================================================================
module PierceArmorAI
  def self.real_battler(value)
    return value.respond_to?(:battler) ? value.battler : value
  end

  def self.score_change(user, target, move, battle, damage)
    user   = real_battler(user)
    target = real_battler(target)
    native = move.respond_to?(:move) ? move.move : move

    return 0 if !user || !target || target.fainted?
    return 0 if !user.opposes?(target)
    return 0 if !user.hasActiveAbility?(:PIERCEARMOR)
    return 0 if !native.damagingMove?
    return 0 if !eligible_move?(native)
    return 0 if damage <= 0 || damage >= target.hp

    if target.effects[PBEffects::Substitute] > 0 &&
       !native.ignoresSubstitute?(user)
      return 0
    end

    old_mold_breaker = battle.moldBreaker

    begin
      if defined?(AdvancedAI::Utilities)
        battle.moldBreaker = AdvancedAI::Utilities.ignores_ability?(
          user, native, target
        )
      end

      return 0 if target.hasActiveAbility?(:SHIELDDUST) &&
                  !battle.moldBreaker
      return 0 if !target.pbCanLowerStatStage?(:DEFENSE, user, native)

      unless battle.moldBreaker
        return -10 if target.hasActiveAbility?(:CONTRARY)
        return -10 if target.hasActiveAbility?(:MIRRORARMOR)
      end

      # More useful if the user can exploit the reduced Defense.
      physical = user.moves.any? do |m|
        m.damagingMove? && m.physicalMove?
      end

      value = physical ? 8 : 3
      value += 3 if native.multiHitMove?

      unless battle.moldBreaker
        value += 2 if target.hasActiveAbility?(:SIMPLE)
        value -= 12 if target.hasActiveAbility?([:DEFIANT, :COMPETITIVE])
      end

      return value
    ensure
      battle.moldBreaker = old_mold_breaker
    end
  end
end

#-------------------------------------------------------------------------------
# Ability ranking
#-------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:PIERCEARMOR)
end
Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
Battle::AI::BASE_ABILITY_RATINGS[7] << :PIERCEARMOR

Battle::AI::Handlers::AbilityRanking.add(:PIERCEARMOR,
  proc { |ability, score, battler, ai|
	useful = battler.check_for_move do |m|
	  PierceArmorAI.eligible_move?(m)
	end

    next 0 if !useful
    next 8 if battler.check_for_move { |m|
      m.damagingMove? && m.physicalMove?
    }
    next 5
  }
)

#-------------------------------------------------------------------------------
# Essentials AI
#-------------------------------------------------------------------------------
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:pierce_armor,
  proc { |score, move, user, target, ai, battle|
    next score if !ai.trainer.medium_skill?
    next score if !user.has_active_ability?(:PIERCEARMOR)
    next score if !move.damagingMove?
    next score if !PierceArmorAI.eligible_move?(move)

    score += PierceArmorAI.score_change(
      user, target, move, battle, move.rough_damage
    )
    next score
  }
)

#-------------------------------------------------------------------------------
# Advanced AI
#-------------------------------------------------------------------------------
if defined?(AdvancedAI::CombatUtilities) &&
   Battle::AI.method_defined?(:score_move_advanced)
  module PierceArmorAdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= 0 || !user || !target

      attacker = PierceArmorAI.real_battler(user)
      defender = PierceArmorAI.real_battler(target)
      native = move.respond_to?(:move) ? move.move : move

      return score if !attacker.hasActiveAbility?(:PIERCEARMOR)
      return score if !native.damagingMove?
      return score if !PierceArmorAI.eligible_move?(native)

      damage = AdvancedAI::CombatUtilities.estimate_damage(
        attacker, native, defender
      )

      return score + PierceArmorAI.score_change(
        attacker, defender, native, @battle, damage
      )
    end
  end

  Battle::AI.prepend(PierceArmorAdvancedScoring)
end

#===============================================================================
# Kamen Rider
#===============================================================================
module KamenRider
  def self.real_battler(value)
    return value.respond_to?(:battler) ? value.battler : value
  end

  def self.ready?(value)
    battler = real_battler(value)
    return false if !battler || battler.fainted?

    battle = battler.battle
    previous_round = battle.turnCount - 1
    records = battle.kamen_rider_faints[previous_round] || []

    return records.any? do |side, pokemon|
      side == battler.idxOwnSide &&
        !pokemon.equal?(battler.pokemon)
    end
  end

  def self.active?(value)
    battler = real_battler(value)
    return false if !battler
    return battler.hasActiveAbility?(:KAMENRIDER) && ready?(battler)
  end
end

class Battle
  def kamen_rider_faints
    @kamen_rider_faints ||= {}
    return @kamen_rider_faints
  end
end

# Record fainting independently of LastRoundFainted, so a new faint
# this round won't erase the record needed from the previous round.
module KamenRiderFaintTracking
  def pbFaint(showMessage = true)
    if fainted? && !@fainted && @pokemon
      history = @battle.kamen_rider_faints
      round   = @battle.turnCount
      history[round] ||= []

      record = [idxOwnSide, @pokemon]
      history[round] << record if !history[round].include?(record)
    end

    return super
  end
end

Battle::Battler.prepend(KamenRiderFaintTracking)

Battle::AbilityEffects::DamageCalcFromUser.add(:KAMENRIDER,
  proc { |ability, user, target, move, mults, power, type|
    next if !move.damagingMove?
    next if !KamenRider.ready?(user)

    mults[:final_damage_multiplier] *= 1.5
  }
)

#===============================================================================
# Essentials AI
# Native damage prediction uses the ability's damage handler.
#===============================================================================
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:KAMENRIDER)
end
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
Battle::AI::BASE_ABILITY_RATINGS[6] << :KAMENRIDER

Battle::AI::Handlers::AbilityRanking.add(:KAMENRIDER,
  proc { |ability, score, battler, ai|
    next 0 if !battler.check_for_move { |m| m.damagingMove? }
    next KamenRider.ready?(battler) ? 9 : 4
  }
)

#===============================================================================
# Advanced AI - shared damage estimator
#===============================================================================
if defined?(AdvancedAI::CombatUtilities)
  module KamenRiderAdvancedModifier
    def ability_damage_modifier(attacker, target, type, physical,
                                effectiveness, move = nil,
                                physical_defense = physical)
      result = super
      result *= 1.5 if KamenRider.active?(attacker)
      return result
    end
  end

  AdvancedAI::CombatUtilities.singleton_class.prepend(
    KamenRiderAdvancedModifier
  )
end

#===============================================================================
# Advanced AI - separate rough damage calculation
#===============================================================================
if defined?(AdvancedAI) &&
   Battle::AI.method_defined?(:calculate_rough_damage)
  module KamenRiderAdvancedDamage
    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = super
      return result if result <= 0
      return result if !KamenRider.active?(user)

      native = move.respond_to?(:move) ? move.move : move
      return result if native.is_a?(Battle::Move::FixedDamageMove)
      return result if native.function_code.start_with?("OHKO")

      return (result * 1.5).to_i
    end
  end

  Battle::AI.prepend(KamenRiderAdvancedDamage)
end

#===============================================================================
# Showdown Mode
#===============================================================================
module ShowdownModePlus
  STATS = [
    :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED
  ]

  def self.real_battler(value)
    return value.respond_to?(:battler) ? value.battler : value
  end

  def self.running?(value)
    b = real_battler(value)
    return b && !b.fainted? &&
           b.hasActiveAbility?(:SHOWDOWNMODE) &&
           b.effects[PBEffects::ShowdownMode] == true
  end

  def self.hp_loss(value)
    b = real_battler(value)
    return 0 if !running?(b)
    return 0 if !b.takesIndirectDamage?
    return 0 if b.hp <= 1

    return [[b.totalhp / 18, 1].max, b.hp - 1].min
  end

  def self.with_splash(battler, battle)
    old_name  = $aamName
    old_name2 = $aamName2

    begin
      name = GameData::Ability.get(:SHOWDOWNMODE).name
      $aamName  = name
      $aamName2 = name

      battle.pbShowAbilitySplash(battler)
      yield
      battle.pbHideAbilitySplash(battler)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end

  # Additional scoring when an attack is predicted to activate the ability.
  def self.score_change(user, target, move, damage, battle)
    user   = real_battler(user)
    target = real_battler(target)
    native = move.respond_to?(:move) ? move.move : move

    return 0 if !user || !target
    return 0 if !user.opposes?(target)
    return 0 if !native.damagingMove?
    return 0 if !target.hasActiveAbility?(:SHOWDOWNMODE)
    return 0 if target.effects[PBEffects::ShowdownMode] == true
    return 0 if target.hp * 2 <= target.totalhp
    return 0 if damage <= 0 || damage >= target.hp
    return 0 if (target.hp - damage) * 2 > target.totalhp

    if target.effects[PBEffects::Substitute] > 0 &&
       !native.ignoresSubstitute?(user)
      return 0
    end

    useful_stats = STATS.count do |stat|
      target.pbCanRaiseStatStage?(stat, target)
    end
    return 0 if useful_stats == 0

    # Contrary turns the self-inflicted increases into decreases.
    if target.hasActiveAbility?(:CONTRARY) && !battle.moldBreaker
      return 8
    end

    penalty = [useful_stats * 2, 10].min
    if target.hasActiveAbility?(:SIMPLE) && !battle.moldBreaker
      penalty += 4
    end

    # The continuing HP cost offsets some of the benefit.
    penalty -= 2 if target.takesIndirectDamage?
    return -penalty
  end
end

#-------------------------------------------------------------------------------
# Reset on entry, including Baton Pass.
#-------------------------------------------------------------------------------
module ShowdownModeReset
  def pbInitEffects(batonPass)
    super
    @effects[PBEffects::ShowdownMode] = false
    @showdown_mode_eor_round = nil
  end
end

Battle::Battler.prepend(ShowdownModeReset)

#-------------------------------------------------------------------------------
# Activate once per stay on the field.
#-------------------------------------------------------------------------------
Battle::AbilityEffects::AfterMoveUseFromTarget.add(:SHOWDOWNMODE,
  proc { |ability, target, user, move, switched_battlers, battle|
    next if target.fainted?
    next if !move.damagingMove?
    next if target.damageState.substitute
    next if !target.droppedBelowHalfHP
    next if target.effects[PBEffects::ShowdownMode] == true

    next if !ShowdownModePlus::STATS.any? { |stat|
      target.pbCanRaiseStatStage?(stat, target)
    }

    target.effects[PBEffects::ShowdownMode] = true

    ShowdownModePlus.with_splash(target, battle) do
      ShowdownModePlus::STATS.each do |stat|
        next if !target.pbCanRaiseStatStage?(stat, target)
        target.pbRaiseStatStageByAbility(stat, 1, target, false)
      end
    end
  }
)

#-------------------------------------------------------------------------------
# Only damage this ability's owner, at most once each round.
#-------------------------------------------------------------------------------
Battle::AbilityEffects::EndOfRoundEffect.add(:SHOWDOWNMODE,
  proc { |ability, battler, battle|
    loss = ShowdownModePlus.hp_loss(battler)
    next if loss <= 0

    previous_round = battler.instance_variable_get(
      :@showdown_mode_eor_round
    )
    next if previous_round == battle.turnCount

    battler.instance_variable_set(
      :@showdown_mode_eor_round, battle.turnCount
    )

    ShowdownModePlus.with_splash(battler, battle) do
      battle.pbDisplay(_INTL("{1} is losing health from Showdown Mode!",
                            battler.pbThis))
      battler.pbReduceHP(loss)
    end

    battler.pbItemHPHealCheck
  }
)

#===============================================================================
# Essentials AI
#===============================================================================
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:SHOWDOWNMODE)
end
Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] << :SHOWDOWNMODE

Battle::AI::Handlers::AbilityRanking.add(:SHOWDOWNMODE,
  proc { |ability, score, battler, ai|
    next(-4) if battler.has_active_ability?(:CONTRARY)
    next 0 if battler.effects[PBEffects::ShowdownMode] == true
    next 10 if battler.has_active_ability?(:SIMPLE)
    next battler.hp * 2 > battler.totalhp ? 8 : 3
  }
)

# Predict the continuing HP cost.
module ShowdownModeEndOfRoundAI
  def rough_end_of_round_damage
    damage = super
    return damage if damage >= 999_999
    return damage + ShowdownModePlus.hp_loss(battler)
  end
end

Battle::AI::AIBattler.prepend(ShowdownModeEndOfRoundAI)

Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:showdown_mode,
  proc { |score, move, user, target, ai, battle|
    next score if !ai.trainer.medium_skill?
    next score if !move.damagingMove?
    next score if !target.has_active_ability?(:SHOWDOWNMODE)

    score += ShowdownModePlus.score_change(
      user, target, move, move.rough_damage, battle
    )
    next score
  }
)

#===============================================================================
# Advanced AI - activation scoring
#===============================================================================
if defined?(AdvancedAI::CombatUtilities) &&
   Battle::AI.method_defined?(:score_move_advanced)
  module ShowdownModeAdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= 0 || !user || !target

      attacker = ShowdownModePlus.real_battler(user)
      defender = ShowdownModePlus.real_battler(target)
      native = move.respond_to?(:move) ? move.move : move

      return score if !native.damagingMove?
      return score if !defender.hasActiveAbility?(:SHOWDOWNMODE)

      damage = AdvancedAI::CombatUtilities.estimate_damage(
        attacker, native, defender
      )

      return score + ShowdownModePlus.score_change(
        attacker, defender, native, damage, @battle
      )
    end
  end

  Battle::AI.prepend(ShowdownModeAdvancedScoring)
end

#===============================================================================
# Subjugate
# Moves that lower an opponent's stats raise the user's matching stats
# by the number of stages actually lowered.
#===============================================================================
module Subjugate
  class << self
    attr_accessor :move_user, :non_move_depth
  end

  def self.real_battler(value)
    return value.respond_to?(:battler) ? value.battler : value
  end

  def self.move_source?(user)
    return user && move_user.equal?(user) &&
           (non_move_depth || 0) == 0
  end

  def self.activate(user, target, stat, amount)
    return if amount <= 0 || !move_source?(user)
    return if !user.opposes?(target)
    return if user.fainted?
    return if !user.hasActiveAbility?(:SUBJUGATE)
    return if !user.pbCanRaiseStatStage?(stat, user)

    old_name  = $aamName
    old_name2 = $aamName2

    begin
      name = GameData::Ability.get(:SUBJUGATE).name
      $aamName  = name
      $aamName2 = name

      user.battle.pbShowAbilitySplash(user)
      user.pbRaiseStatStageByAbility(stat, amount, user, false)
      user.battle.pbHideAbilitySplash(user)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
end

#-------------------------------------------------------------------------------
# Track the move's user and actual stat reductions.
#-------------------------------------------------------------------------------
module SubjugateBattlerEffects
  def pbUseMove(choice, specialUsage = false)
    old_user  = Subjugate.move_user
    old_depth = Subjugate.non_move_depth

    begin
      Subjugate.move_user = self
      Subjugate.non_move_depth = 0
      return super
    ensure
      Subjugate.move_user = old_user
      Subjugate.non_move_depth = old_depth
    end
  end

  def subjugate_track_drop(user)
    @subjugate_frames ||= []
    frame = {
      :changes  => [],
      :captured => false,
      :eligible => Subjugate.move_source?(user)
    }
    @subjugate_frames.push(frame)

    begin
      result = yield
    ensure
      @subjugate_frames.pop
    end

    if frame[:eligible]
      frame[:changes].each do |stat, amount|
        Subjugate.activate(user, self, stat, amount)
      end
    end

    return result
  end

  def pbLowerStatStage(stat, increment, user, *args)
    return subjugate_track_drop(user) { super }
  end

  def pbLowerStatStageByCause(stat, increment, user, cause, *args)
    return subjugate_track_drop(user) { super }
  end

  def pbLowerStatStageBasic(stat, increment, ignoreContrary = false)
    frame = @subjugate_frames && @subjugate_frames.last
    capture = frame && !frame[:captured]
    frame[:captured] = true if capture

    before = @stages[stat]
    result = super
    reduction = before - @stages[stat]

    if capture && reduction > 0
      frame[:changes].push([stat, reduction])
    end

    return result
  end
end

Battle::Battler.prepend(SubjugateBattlerEffects)

#-------------------------------------------------------------------------------
# Exclude Ability/item effects, including those triggered during a move.
#-------------------------------------------------------------------------------
module SubjugateNonMoveEffects
  def trigger(*args)
    old_depth = Subjugate.non_move_depth || 0

    begin
      Subjugate.non_move_depth = old_depth + 1
      return super
    ensure
      Subjugate.non_move_depth = old_depth
    end
  end
end

AbilityHandlerHash.prepend(SubjugateNonMoveEffects)
ItemHandlerHash.prepend(SubjugateNonMoveEffects)

#===============================================================================
# AI
#===============================================================================
module SubjugateAI
  def self.stat_lowering_move?(move)
    return move.is_a?(Battle::Move::TargetStatDownMove) ||
           move.is_a?(Battle::Move::TargetMultiStatDownMove)
  end

  def self.bonus(user, target, native, changes, battle)
    user   = Subjugate.real_battler(user)
    target = Subjugate.real_battler(target)

    return 0 if !user || !target
    return 0 if !user.opposes?(target)
    return 0 if !user.hasActiveAbility?(:SUBJUGATE)

    old_mold_breaker = battle.moldBreaker

    begin
      if defined?(AdvancedAI::Utilities)
        battle.moldBreaker = AdvancedAI::Utilities.ignores_ability?(
          user, native, target
        )
      end

      unless battle.moldBreaker
        return 0 if target.hasActiveAbility?([:CONTRARY, :MIRRORARMOR])
      end

      chance = 100
      if native.damagingMove?
        return 0 if user.hasActiveAbility?(:SHEERFORCE) &&
                    native.addlEffect > 0
        return 0 if target.hasActiveItem?(:COVERTCLOAK)
        return 0 if target.hasActiveAbility?(:SHIELDDUST) &&
                    !battle.moldBreaker

        chance = [native.addlEffect, 100].min
        return 0 if chance <= 0
        if user.hasActiveAbility?(:SERENEGRACE) ||
           user.pbOwnSide.effects[PBEffects::Rainbow] > 0
          chance = [chance * 2, 100].min
        end
      end

      value = 0
      limit = Battle::Battler::STAT_STAGE_MAXIMUM

      changes.each_slice(2) do |stat, amount|
        next if !stat || !amount
        next if !target.pbCanLowerStatStage?(stat, user, native)
        next if !user.pbCanRaiseStatStage?(stat, user)

        drop = amount
        if target.hasActiveAbility?(:SIMPLE) && !battle.moldBreaker
          drop *= 2
        end
        drop = [drop, target.stages[stat] + limit].min
        next if drop <= 0

        if user.hasActiveAbility?(:CONTRARY) && !battle.moldBreaker
          loss = [drop, user.stages[stat] + limit].min
          value -= 5 * loss
        else
          gain = drop
          gain *= 2 if user.hasActiveAbility?(:SIMPLE) &&
                       !battle.moldBreaker
          gain = [gain, limit - user.stages[stat]].min
          value += 5 * gain
        end
      end

      value = (value * chance / 100.0).round
      return [[value, -20].max, 20].min
    ensure
      battle.moldBreaker = old_mold_breaker
    end
  end
end

#-------------------------------------------------------------------------------
# Ability ranking
#-------------------------------------------------------------------------------
Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
  ids.delete(:SUBJUGATE)
end
Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
Battle::AI::BASE_ABILITY_RATINGS[7] << :SUBJUGATE

Battle::AI::Handlers::AbilityRanking.add(:SUBJUGATE,
  proc { |ability, score, battler, ai|
    useful = battler.check_for_move do |move|
      SubjugateAI.stat_lowering_move?(move)
    end

    next 0 if !useful
    next(-3) if battler.has_active_ability?(:CONTRARY)
    next 9 if battler.has_active_ability?(:SIMPLE)
    next 7
  }
)

#-------------------------------------------------------------------------------
# Essentials AI - augment existing stat-drop scoring.
#-------------------------------------------------------------------------------
module SubjugateNativeScoring
  def get_score_for_target_stat_drop(score, target, stat_changes, *args)
    result = super
    return result if result == Battle::AI::MOVE_USELESS_SCORE
    return result if !@user || !@move

    return result + SubjugateAI.bonus(
      @user, target, @move.move, stat_changes, @battle
    )
  end
end

Battle::AI.prepend(SubjugateNativeScoring)

#-------------------------------------------------------------------------------
# Advanced AI - standard target stat-lowering moves.
#-------------------------------------------------------------------------------
if defined?(AdvancedAI) &&
   Battle::AI.method_defined?(:score_move_advanced)
  module SubjugateAdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= 0 || !user || !target

      native = move.respond_to?(:move) ? move.move : move
      return score if !SubjugateAI.stat_lowering_move?(native)

      return score + SubjugateAI.bonus(
        user, target, native, native.statDown, @battle
      )
    end
  end

  Battle::AI.prepend(SubjugateAdvancedScoring)
end