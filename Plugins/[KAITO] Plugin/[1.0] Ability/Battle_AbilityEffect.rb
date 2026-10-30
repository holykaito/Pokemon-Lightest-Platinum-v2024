# Consolidated ability effects, move patches, AI utilities, PBEffects and Sleet.
# Replaces AI_Utilities.rb, Battle_Move.rb, PBEffects.rb and Sleet.rb; remove those old files.

# --- PBEffects.rb ---
module PBEffects
   KintsugiDamaged     = 500
end

# --- AI_Utilities.rb ---
class Battle::AI
  KAITO_BASE_ABILITY_RATINGS = {
    6 => [:HYPERCHARGE, :AGILE],
    7 => [:HALFDRAKE, :FIERYSPIRIT, :BUGBOUND, :TERRORSOWER],
    8 => [:TRAUMATICFIST, :KINTSUGI, :PRECISEFIST],
    9 => [:DISTORTION]
  }
end
if defined?(Battle::AI::Handlers) &&
   defined?(Battle::AI::Handlers::AbilityRanking)
  Battle::AI::Handlers::AbilityRanking.add(:HYPERCHARGE, proc { |ability, score, battler, ai|
      next score if battler.check_for_move { |m| m.type == :ELECTRIC }
      next 0
    })
end

# --- Battle_AbilityEffect.rb ---
# Shared utilities; this file is loaded automatically by the existing plugin.
# Keep effects and AI patches in their original order. No per-ability meta entries.
module KaitoAbilitySupport
  def self.rate(ability, rating)
    Battle::AI::BASE_ABILITY_RATINGS.each_value { |ids| ids.delete(ability) }
    Battle::AI::BASE_ABILITY_RATINGS[rating] ||= []
    Battle::AI::BASE_ABILITY_RATINGS[rating] << ability
  end
end

# PriorityChange handlers

Battle::AbilityEffects::PriorityChange.add(:AGILE, proc { |ability, battler, move, pri| next pri + 1 if battler.turnCount==1 })

Battle::AbilityEffects::PriorityChange.add(:HYPERCHARGE, proc { |ability, battler, move, pri|
  next pri + 1 if (battler.hp >= battler.totalhp * 0.5) && move.type == :ELECTRIC
})

Battle::AbilityEffects::OnSwitchIn.add(:HALFDRAKE, proc { |ability, battler, battle, switch_in|
  next if battler.fainted?
  battle.pbShowAbilitySplash(battler)
  if !battler.pbHasType?(:DRAGON)
    battler.effects[PBEffects::ExtraType] = :DRAGON
    typeName = GameData::Type.get(:DRAGON).name
    battle.pbDisplay(_INTL("{1}'s draconic blood awakened, giving it the {2} type!", battler.pbThis, typeName))
  end
  battle.pbHideAbilitySplash(battler)
})

Battle::AbilityEffects::OnSwitchIn.add(:BUGBOUND, proc { |ability, battler, battle, switch_in|
  next if battler.fainted?
  battle.pbShowAbilitySplash(battler)
  if !battler.pbHasType?(:BUG)
    battler.effects[PBEffects::ExtraType] = :BUG
    typeName = GameData::Type.get(:BUG).name
    battle.pbDisplay(_INTL("{1}'s body became bound to insects, giving it the {2} type!", battler.pbThis, typeName))
  end
  battle.pbHideAbilitySplash(battler)
})

# Aquatic
# Adds Water type and removes weaknesses caused by the added Water typing.

Battle::AbilityEffects::OnSwitchIn.add(:AQUATIC, proc { |ability, battler, battle, switch_in|
  next if battler.fainted?
  next if battler.pbHasType?(:WATER)
  battle.pbShowAbilitySplash(battler)
  battler.effects[PBEffects::ExtraType] = :WATER
  typeName = GameData::Type.get(:WATER).name
  battle.pbDisplay(_INTL("{1} became one with the water and gained the {2} type!", battler.pbThis, typeName))
  battle.pbHideAbilitySplash(battler)
})

Battle::AbilityEffects::DamageCalcFromTarget.add(:AQUATIC, proc { |ability, user, target, move, mults, power, type|
  # Water's added weaknesses are Electric and Grass.
  # This cancels the x2 weakness caused only by Aquatic's added Water type.
  if target.effects[PBEffects::ExtraType] == :WATER && [:ELECTRIC, :GRASS].include?(type)
    mults[:final_damage_multiplier] /= 2
  end
})

# Rampage
# If the user K.O.s a target with a recharge move, it doesn't need to recharge.
# Shows ability splash when activated.

Battle::AbilityEffects::OnEndOfUsingMove.add(:RAMPAGE, proc { |ability, user, targets, move, battle|
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
    battle.pbDisplay(_INTL("{1}'s {2} removed its need to recharge!", user.pbThis, user.abilityName))
  end
  battle.pbHideAbilitySplash(user)
})

# Distortion
# When this Pokémon hits an opposing Pokémon, lowers a random stat by 1 stage.

Battle::AbilityEffects::OnDealingHit.add(:DISTORTION, proc { |ability, user, target, move, battle|
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
})

# Traumatic Fist
# When this Pokémon hits with a punching move, lowers a random target stat by 1 stage.

Battle::AbilityEffects::OnDealingHit.add(:TRAUMATICFIST, proc { |ability, user, target, move, battle|
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
})

# Nocturnal
# Reduces damage from Fairy-type and Dark-type moves by 30%.

Battle::AbilityEffects::DamageCalcFromTarget.add(:NOCTURNAL, proc { |ability, user, target, move, mults, power, type| mults[:power_multiplier] *= 0.7 if [:FAIRY, :DARK].include?(type) }
)

# Kintsugi
# At the end of each turn, if this Pokémon was damaged by a damaging move
# this turn, it restores 1/10 of its max HP.

Battle::AbilityEffects::AfterMoveUseFromTarget.add(:KINTSUGI, proc { |ability, target, user, move, switched_battlers, battle|
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
})

Battle::AbilityEffects::EndOfRoundEffect.add(:KINTSUGI, proc { |ability, battler, battle|
  next if !battler.effects[PBEffects::KintsugiDamaged]
  battler.effects[PBEffects::KintsugiDamaged] = false
  next if battler.fainted?
  next if !battler.canHeal?
  battle.pbShowAbilitySplash(battler)
  battler.pbRecoverHP(battler.totalhp / 10)
  battle.pbDisplay(_INTL("{1}'s cracks were mended by Kintsugi!", battler.pbThis))
  battle.pbHideAbilitySplash(battler)
})

# Wandering Orbs
# Sets Haunted Orbs on the opposing side when this Pokémon enters battle.

Battle::AbilityEffects::OnSwitchIn.add(:WANDERINGORBS, proc { |ability, battler, battle, switch_in|
  next if battler.fainted?
  foe_side = battler.pbOpposingSide
  next if foe_side.effects[PBEffects::HauntedOrbs]
  battle.pbShowAbilitySplash(battler)
  foe_side.effects[PBEffects::HauntedOrbs] = true
  battle.pbDisplay(_INTL("Haunted orbs began floating around the opposing team!"))
  battle.pbHideAbilitySplash(battler)
})

# Aura Manipulation

Battle::AbilityEffects::DamageCalcFromUser.add(:AURAMANIPULATION, proc { |ability, user, target, move, mults, power, type|
  next if move.id != :AURASPHERE
  mults[:power_multiplier] *= 1.5
})

# Dwarfhide
# Reduces the chance of getting additional effects from damaging attacks by half.

class Battle::Move
  if method_defined?(:pbAdditionalEffectChance)
    alias dwarven_resilience_pbAdditionalEffectChance pbAdditionalEffectChance

    def pbAdditionalEffectChance(user, target, effectChance = 0)
      ret = dwarven_resilience_pbAdditionalEffectChance(user, target, effectChance)
      if target && target.hasActiveAbility?(:DWARFHIDE) && damagingMove? && ret > 0
        ret /= 2
      end
      return ret
    end
  end
end

# Toxic Waters
# Water-type moves have a 20% chance of poisoning the target.

Battle::AbilityEffects::OnDealingHit.add(:TOXICWATERS, proc { |ability, user, target, move, battle|
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
      msg = _INTL("{1}'s {2} poisoned {3}!", user.pbThis, user.abilityName, target.pbThis(true))
    end
    target.pbPoison(user, msg)
  end
  battle.pbHideAbilitySplash(user)
})

# Grip Pincer
# Contact moves have a 50% chance to trap the target.
# Uses PBEffects::Trapping but prevents Bind/Wrap end-turn damage.

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
    return target.effects[PBEffects::TrappingUser] == user.index && target.instance_variable_get(:@grip_pincer_trap)
  end

  def self.stage_multiplier(stage)
    return 1.0 if stage <= 0
    return (2.0 + stage) / 2.0
  end
end

Battle::AbilityEffects::OnEndOfUsingMove.add(:GRIPPINCER, proc { |ability, user, targets, move, battle|
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
    battle.pbDisplay(_INTL("{1} was caught by {2}'s Grip Pincer!", target.pbThis, user.pbThis(true)))
    battle.pbHideAbilitySplash(user)
  end
})

Battle::AbilityEffects::AccuracyCalcFromUser.add(:GRIPPINCER, proc { |ability, mods, user, target, move, type| mods[:base_accuracy] = 0 if GripPincer.trapped_by_user?(target, user) }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:GRIPPINCER, proc { |ability, user, target, move, mults, power, type|
  next if !GripPincer.trapped_by_user?(target, user)
  if move.physicalMove?
    stage = target.stages[:DEFENSE]
    mults[:defense_multiplier] /= GripPincer.stage_multiplier(stage) if stage > 0
  elsif move.specialMove?
    stage = target.stages[:SPECIAL_DEFENSE]
    mults[:defense_multiplier] /= GripPincer.stage_multiplier(stage) if stage > 0
  end
})

# Tidiness

module Tidiness_HazardCleaner
  HAZARDS = { :StealthRock => false, :Spikes      => 0, :ToxicSpikes => 0, :StickyWeb   => false, :Steelsurge  => false }
  # Gets PBEffects constant safely.
  # Returns nil if the effect doesn't exist in your project.
  def self.effect_key(effect_name)
    return nil if !PBEffects.const_defined?(effect_name)
    return PBEffects.const_get(effect_name)
  end
  # Checks whether a hazard value is active.
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
  # Checks whether a side has any entry hazards.
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

Battle::AbilityEffects::OnSwitchIn.add(:TIDINESS, proc { |ability, battler, battle, switch_in|
  own_side = battler.pbOwnSide

  # Do nothing if this side has no hazards.
  next if !Tidiness_HazardCleaner.hazards_on_side?(own_side)
  battle.pbShowAbilitySplash(battler)
  Tidiness_HazardCleaner.clear_side!(own_side)
  if Battle::Scene::USE_ABILITY_SPLASH
    battle.pbDisplay(_INTL("The entry hazards on {1}'s side were tidied away!", battler.pbTeam(true)))
  else
    battle.pbDisplay(_INTL("{1}'s {2} tidied away the entry hazards on its side!", battler.pbThis, battler.abilityName))
  end
  battle.pbHideAbilitySplash(battler)
})
if defined?(Battle::AI)
  # Replacement Pokémon scoring.
  if Battle::AI.method_defined?(:rate_replacement_pokemon)
    class Battle::AI
      alias tidiness_rate_replacement_pokemon rate_replacement_pokemon

      def rate_replacement_pokemon(idxBattler, pkmn, score)
        score = tidiness_rate_replacement_pokemon(idxBattler, pkmn, score)
        if pkmn.hasAbility?(:TIDINESS) && !@battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS)
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
  # Switch decision handler.
  if defined?(Battle::AI::Handlers) && defined?(Battle::AI::Handlers::ShouldSwitch)
    Battle::AI::Handlers::ShouldSwitch.add(:tidiness_hazard_control, proc { |battler, reserves, ai, battle|
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
      })
  end
end

# Zen Aura

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

  def self.damage_amount(user); return [1, user.totalhp / DAMAGE_FRACTION].max; end

  def self.apply_damage(user, target, battle)
    battle.scene.pbDamageAnimation(user)
    user.pbReduceHP(damage_amount(user), false)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} was hurt by the aura!", user.pbThis))
    else
      battle.pbDisplay(_INTL("{1} was hurt by {2}'s {3}!", user.pbThis, target.pbThis(true), target.abilityName))
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

Battle::AbilityEffects::OnBeingHit.add(:ZENAURA, proc { |ability, user, target, move, battle|
  next if !ZenAura.can_trigger?(user, target, move, battle)
  battle.pbShowAbilitySplash(target)
  ZenAura.apply_damage(user, target, battle)
  battle.pbHideAbilitySplash(target)
})
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
        elsif arg.respond_to?(:index) && arg.respond_to?(:opposes?) && arg.respond_to?(:hasActiveAbility?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end
      if score.is_a?(Numeric) && move && user && target && move.specialMove? && target.hasActiveAbility?(:ZENAURA) && user.opposes?(target) &&
         !@battle.moldBreaker
        penalty = ZenAura.ai_penalty(user)
        score -= penalty
        PBDebug.log_ai("     - Zen Aura punishes special move: #{penalty}") if defined?(PBDebug)
      end
      return score
    end
  end
end

# CHARGE RUSH
# Attack and Speed x1.2 upon entry and during the first action round.
module ChargeRush
  BOOST_MULTIPLIER = 1.2

  def self.real(user); return user.respond_to?(:battler) ? user.battler : user; end

  def self.active?(user)
    user = real(user)
    return false if !user || !user.respond_to?(:turnCount)

    # Newly entered Pokemon.
    return true if user.turnCount == 0

    # First action round: the engine has already increased turnCount.
    return false if user.turnCount != 1

    # During the next command phase, the bonus has expired.
    return !user.battle.command_phase
  end

  def self.ai_factor(user, physical)
    return 1.0 if !user || !physical
    source = real(user)
    return 1.0 if !source
    return 1.0 unless AdvancedAI::Utilities.ability_active?( source, :CHARGERUSH )

    # A party Pokemon is evaluated as a proposed new entrant.
    if source.respond_to?(:turnCount)
      return 1.0 if !active?(source)
    end
    return BOOST_MULTIPLIER
  end

  def self.native_move(move, user, battle)
    native = move.respond_to?(:move) ? move.move : move
    return native if native.is_a?(Battle::Move)
    return Battle::Move.from_pokemon_move( battle, Pokemon::Move.new(native.id) )
  end

  # Shared Advanced AI damage estimator.
  module SharedDamage
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      value = super
      return value * ChargeRush.ai_factor(attacker, physical)
    end
  end

  # Advanced AI's separate move damage estimator.
  module ScorerDamage
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !value.is_a?(Numeric) || value <= 0
      return value if !move || !user

      # Extended Terrains delegates these moves to the shared estimator.
      # Its Charge Rush multiplier has already been applied there.
      if defined?(ExtendedTerrains::Advanced) && @battle.field.terrain == :Pollination &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      native = ChargeRush.native_move(move, user, @battle)
      return value if !native.damagingMove?
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      return value if native.function_code.start_with?("OHKO")
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      physical = native.physicalMove?(type)

      # Match Advanced AI's prediction for category-changing moves.
      if [:PHOTONGEYSER, :LIGHTTHATBURNSTHESKY].include?(move.id) || (move.id == :TERABLAST && tera_type)
        combat = AdvancedAI::CombatUtilities
        atk = user.attack * combat.stage_multiplier(user.stages[:ATTACK])
        spa = user.spatk * combat.stage_multiplier(user.stages[:SPECIAL_ATTACK])
        physical = atk > spa
      end
      factor = ChargeRush.ai_factor(user, physical)
      return value if factor == 1.0
      return [(value * factor).round, 1].max
    end
  end

  # Install after plugin aliases have finished loading.
  def self.install!
    return if @installed
    if defined?(AdvancedAI::CombatUtilities)
      AdvancedAI::CombatUtilities.singleton_class.prepend(SharedDamage)
    end
    if Battle::AI.method_defined?(:calculate_rough_damage)
      Battle::AI.prepend(ScorerDamage)
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      ChargeRush.install!
      super(*args, &block)
    end
  end
end

# Entry announcement
Battle::AbilityEffects::OnSwitchIn.add(:CHARGERUSH, proc { |ability, battler, battle, switch_in|
  next if battler.fainted?
  next if !battler.hasActiveAbility?(:CHARGERUSH)
  battle.pbShowAbilitySplash(battler)
  battle.pbDisplay( _INTL("{1} is ready to rush in!", battler.pbThis) )
  battle.pbHideAbilitySplash(battler)
})

# Speed
Battle::AbilityEffects::SpeedCalc.add(:CHARGERUSH, proc { |ability, battler, mult|
  next mult if !battler.hasActiveAbility?(:CHARGERUSH)
  next mult if !ChargeRush.active?(battler)
  next mult * ChargeRush::BOOST_MULTIPLIER
})

# Physical attacks
Battle::AbilityEffects::DamageCalcFromUser.add(:CHARGERUSH, proc { |ability, user, target, move, mults, power, type|
  next if !user.hasActiveAbility?(:CHARGERUSH)
  next if !ChargeRush.active?(user)
  next if !move.physicalMove?(type)
  mults[:attack_multiplier] *= ChargeRush::BOOST_MULTIPLIER
})

# Native AI ability evaluation
# Native damage and Speed predictions use the handlers above.
Battle::AI::Handlers::AbilityRanking.add(:CHARGERUSH, proc { |ability, score, battler, ai| next ChargeRush.active?(battler) ? 6 : 0 })
unless Battle.singleton_class.ancestors.include?( ChargeRush::BattleConstruction )
  Battle.singleton_class.prepend(ChargeRush::BattleConstruction)
end

# Fix Innate Abilities Speed multiplier stacking.
# Install after all plugins have finished loading.
module KaitoInnateSpeedFix
  module SpeedCalculation
    def triggerSpeedCalc(ability, battler, mult)
      return super unless battler.respond_to?(:abilityMutationList)
      battler.abilityMutationList.each do |id|
        $aamName = GameData::Ability.get(id).name
        mult = trigger(Battle::AbilityEffects::SpeedCalc, id, battler, mult, ret: mult)
      end
      return mult
    end
  end

  def self.install!
    target = Battle::AbilityEffects.singleton_class
    return if target.ancestors.include?(SpeedCalculation)
    target.prepend(SpeedCalculation)
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoInnateSpeedFix.install!
      super(*args, &block)
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoInnateSpeedFix::BattleConstruction )
  Battle.singleton_class.prepend( KaitoInnateSpeedFix::BattleConstruction )
end

# Outbreak
#
# Effect:
#   When this Pokemon inflicts a major status problem on an opposing active
#   Pokemon, the target's Attack is lowered by 1 stage and the same status
#   spreads to a random non-active Pokemon in that target's party.

module Outbreak
  STATUSES = [:SLEEP, :POISON, :BURN, :PARALYSIS, :FROZEN]

  def self.valid_status?(status); return STATUSES.include?(status); end

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
      battle.pbDisplay(_INTL("{1}'s {2} spread {3} to {4}!", source.pbThis, source.abilityName, status_name(status), spread_target.name))
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

# Amplifier
#
# Effect:
#   - Increases damage dealt with sound moves by 30%.
#   - Reduces damage taken from sound moves by 50%.
#
# Notes:
#   - Uses move.soundMove?, same as Soundproof/Punk Rock.
#   - Damage boost: x1.3.
#   - Damage reduction: x0.5.

module Amplifier
  OFFENSE_MULTIPLIER = 1.3
  DEFENSE_MULTIPLIER = 0.5

  def self.sound_move?(move)
    return false if move.nil?
    return false if !move.respond_to?(:soundMove?)
    return move.soundMove?
  end
end

Battle::AbilityEffects::DamageCalcFromUser.add(:AMPLIFIER, proc { |ability, user, target, move, mults, power, type|
  next if !Amplifier.sound_move?(move)
  mults[:attack_multiplier] *= Amplifier::OFFENSE_MULTIPLIER
})

Battle::AbilityEffects::DamageCalcFromTarget.add(:AMPLIFIER, proc { |ability, user, target, move, mults, power, type|
  next if !Amplifier.sound_move?(move)
  mults[:final_damage_multiplier] *= Amplifier::DEFENSE_MULTIPLIER
})

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

# Loud Bang

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

Battle::AbilityEffects::OnDealingHit.add(:LOUDBANG, proc { |ability, user, target, move, battle|
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
})

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
      if score.is_a?(Numeric) && user && move && user.hasActiveAbility?(:LOUDBANG) && LoudBang.sound_attack?(move)
        bonus = 10
        bonus += 10 if target && target.effects[PBEffects::Confusion] == 0
        score += bonus
        PBDebug.log_ai("     + Loud Bang can confuse with sound attack: #{bonus}") if defined?(PBDebug)
      end
      return score
    end
  end
end

# Multi Headed - Fallback Version
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

module MultiHeaded
  DEBUG_MESSAGES = true
  DEFAULT_HEADS = 2
  TWO_HEADED_SPECIES = [ :DODUO, :ZWEILOUS, :BINACLE, :KROOKODILE ]
  THREE_HEADED_SPECIES = [ :DODRIO, :DUGTRIO, :MAGNETON, :HYDREIGON, :WUGTRIO, :IRONJUGULIS ]

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
    battle.pbDisplay(_INTL("Debug: Extra hit should deal {1}, actually dealt {2}.", damage, real_damage))
  end
  PBDebug.log("[Multi Headed] Extra hit #{hit_number} should deal #{damage}, actually dealt #{real_damage}") if defined?(PBDebug)
  target.pbFaint if target.fainted?
  return true
end
end

# Ability effect

Battle::AbilityEffects::OnEndOfUsingMove.add(:MULTIHEADED, proc { |ability, user, targets, move, battle|
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
})

# Cursed Surge + Cursed Terrain

module CursedTerrain
  TERRAIN_ID = :Cursed
  MOVE_ID    = :CURSEDTERRAIN
  DURATION   = 5
  GHOST_MULT = 1.3
  # Basic helpers

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
  # Animation

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
    ["CursedTerrainField", "Cursed Terrain Field", "CursedTerrain", "Cursed Terrain", "CURSEDTERRAIN"].each do |anim_name|
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
  # Start / refresh terrain

  def self.duration_with_item(battle, user)
    ret = DURATION
    if user && user.respond_to?(:itemActive?) && user.itemActive? && defined?(Battle::ItemEffects)
      begin
        ret = Battle::ItemEffects.triggerTerrainExtender( user.item, TERRAIN_ID, ret, user, battle )
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
  # Phantom Force / Shadow Force helper

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

# Ability: Cursed Surge

Battle::AbilityEffects::OnSwitchIn.add(:CURSEDSURGE, proc { |ability, battler, battle, switch_in| CursedTerrain.start(battle, battler, true, true) }
)

# Safety aliases nếu lỡ đặt nhầm ability ID.
Battle::AbilityEffects::OnSwitchIn.copy(:CURSEDSURGE, :CURSESURGE)

Battle::AbilityEffects::OnSwitchIn.copy(:CURSEDSURGE, :CURRSEDSURGE)

Battle::AbilityEffects::OnSwitchIn.copy(:CURSEDSURGE, :CURSEDTERRAIN)

# Move effect: Cursed Terrain
# PBS:
#   FunctionCode = StartCursedTerrain

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

# Ghost-type damage boost under Cursed Terrain

class Battle::Move
  if !method_defined?(:cursed_terrain_clean_pbCalcDamageMultipliers)
    alias cursed_terrain_clean_pbCalcDamageMultipliers pbCalcDamageMultipliers
  end

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    cursed_terrain_clean_pbCalcDamageMultipliers( user, target, numTargets, type, baseDmg, multipliers )
    if CursedTerrain.active?(@battle) && type == :GHOST && CursedTerrain.grounded?(user)
      multipliers[:power_multiplier] *= CursedTerrain::GHOST_MULT
    end
  end
end

# Healing prevention

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

# Phantom Force / Shadow Force immediate execution

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

# Backup duration countdown

class Battle
  if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:cursed_terrain_clean_pbEndOfRoundPhase)
    alias cursed_terrain_clean_pbEndOfRoundPhase pbEndOfRoundPhase
  end

  def pbEndOfRoundPhase
    cursed_terrain_clean_pbEndOfRoundPhase
    CursedTerrain.tick_down(self) if CursedTerrain.active?(self)
  end
end

# Dreamcatcher
#
# Effect:
#   Damage is increased by 30% if any active Pokemon on the field is asleep.
#
# Notes:
#   - Counts any active battler: user, ally, or foe.
#   - Does not count fainted Pokemon.
#   - Only boosts damaging moves.
#   - Boost is x1.3 final damage.

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

# Ability effect

Battle::AbilityEffects::DamageCalcFromUser.add(:DREAMCATCHER, proc { |ability, user, target, move, mults, power, type|
  next if !move.pbDamagingMove?
  next if !Dreamcatcher.asleep_on_field?(user.battle)
  mults[:final_damage_multiplier] *= Dreamcatcher::DAMAGE_MULTIPLIER
})

# Optional AI support
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
      if score.is_a?(Numeric) && user && move && user.hasActiveAbility?(:DREAMCATCHER) && Dreamcatcher.asleep_on_field?(user.battle)
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

# Chaos Space
#
# Effect:
#   When this Pokemon enters battle, it creates Trick Room for 4 turns.
#
# Notes:
#   - Uses battle.field.effects[PBEffects::TrickRoom].
#   - Compatible with Room Service and normal Trick Room checks.
#   - If Trick Room is already active, this refreshes it to 4 turns.

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

# Ability effect

Battle::AbilityEffects::OnSwitchIn.add(:CHAOSSPACE, proc { |ability, battler, battle, switch_in| ChaosSpace.start(battle, battler, true) })

# Optional AI support
# Helps AI value switching in Chaos Space if Trick Room is not active.
if defined?(Battle::AI) && Battle::AI.method_defined?(:rate_replacement_pokemon)
  class Battle::AI
    if !method_defined?(:chaos_space_rate_replacement_pokemon)
      alias chaos_space_rate_replacement_pokemon rate_replacement_pokemon
    end

    def rate_replacement_pokemon(idxBattler, pkmn, score)
      score = chaos_space_rate_replacement_pokemon(idxBattler, pkmn, score)
      if pkmn.hasAbility?(:CHAOSSPACE) && !ChaosSpace.trick_room_active?(@battle)
        score += 25
        PBDebug.log_ai("     + Chaos Space can create Trick Room: 25") if defined?(PBDebug)
      end
      return score
    end
  end
end

# Comatose Plus
#
# Added effect:
#   While the Pokemon is asleep/drowsing, damage taken is reduced by 20%.
#
# Notes:
#   - Damage taken becomes x0.8.
#   - Because Comatose means the Pokemon is always drowsing, this effect is active
#     whenever Comatose is active.

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

Battle::AbilityEffects::DamageCalcFromTarget.add(:COMATOSE, proc { |ability, user, target, move, mults, power, type|
  next if !ComatosePlus.asleep_or_drowsing?(target)

  # Reduce final damage by 20%.
  mults[:final_damage_multiplier] *= ComatosePlus::DAMAGE_MULTIPLIER
})

# Liquify
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

# Ability effect

Battle::AbilityEffects::DamageCalcFromTarget.add(:LIQUIFY, proc { |ability, user, target, move, mults, power, type|
  # Contact damage reduction.
  if Liquify.contact_move?(move, user)
    mults[:final_damage_multiplier] *= Liquify::CONTACT_DAMAGE_MULTIPLIER
  end

  # Water-type damage weakness.
  if Liquify.water_type?(type, move)
    mults[:final_damage_multiplier] *= Liquify::WATER_DAMAGE_MULTIPLIER
  end
})

# Optional AI support
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
        if arg.respond_to?(:pbContactMove?) || arg.respond_to?(:contactMove?) || arg.respond_to?(:calcType)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?) && arg.respond_to?(:opposes?)
          if user.nil?
            user = arg
          elsif target.nil? && arg != user
            target = arg
          end
        end
      end
      if score.is_a?(Numeric) && move && user && target && target.hasActiveAbility?(:LIQUIFY)
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

# Sweet Dreams Fix
# Heals sleeping Pokemon, including Pokemon with Innate Comatose.

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

  def self.same_ability?(value, ability); return normalize_ability_id(value) == normalize_ability_id(ability); end

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
      return true if battler.pokemon && scan_instance_variables_for_ability?(battler.pokemon, ability)
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

  def self.sweet_dreams_user?(battler); return has_ability_or_innate?(battler, SWEET_DREAMS); end

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
        battle.pbDisplay(_INTL("{1} is relaxed by {2}'s {3}!", b.pbThis, battler.pbThis(true), battler.abilityName))
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

# End of round hook

class Battle
  if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:sweet_dreams_fix_pbEndOfRoundPhase)
    alias sweet_dreams_fix_pbEndOfRoundPhase pbEndOfRoundPhase
  end

  def pbEndOfRoundPhase(*args)
    ret = sweet_dreams_fix_pbEndOfRoundPhase(*args)
    SweetDreamsFix.trigger_all(self)
    return ret
  end
end

# Spellcaster
# Boosts Electric-, Fire-, and Ice-type moves by 25%.
# The boost does not apply against Dark-type targets.
module SpellcasterAbility
  BOOST_MULTIPLIER = 1.25
  BOOST_TYPES = [:ELECTRIC, :FIRE, :ICE].freeze

  def self.boosted_type?(type); return BOOST_TYPES.include?(type); end

  def self.target_is_dark?(target)
    target = target.battler if target.respond_to?(:battler)
    return target && target.pbHasType?(:DARK)
  end
end

Battle::AbilityEffects::DamageCalcFromUser.add(:SPELLCASTER, proc { |ability, user, target, move, mults, power, type|
  next if !SpellcasterAbility.boosted_type?(type)
  next if SpellcasterAbility.target_is_dark?(target)
  mults[:power_multiplier] *= SpellcasterAbility::BOOST_MULTIPLIER
})

# Carrion Feast
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

module CarrionFeast
  DAMAGE_MULTIPLIER = 0.75
  HEAL_FRACTION     = 5

  def self.heal_amount(user); return [1, user.totalhp / HEAL_FRACTION].max; end

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
        battle.pbDisplay(_INTL("{1}'s {2} restored its HP from the fallen foe!", user.pbThis, user.abilityName))
      end
    end
    battle.pbHideAbilitySplash(user)
  end
end

# Reduce super-effective damage by 25%

Battle::AbilityEffects::DamageCalcFromTarget.add(:CARRIONFEAST, proc { |ability, user, target, move, mults, power, type|
  next if !Effectiveness.super_effective?(target.damageState.typeMod)
  mults[:final_damage_multiplier] *= CarrionFeast::DAMAGE_MULTIPLIER
})

# Heal 25% HP after KOing opposing Pokemon

Battle::AbilityEffects::OnEndOfUsingMove.add(:CARRIONFEAST, proc { |ability, user, targets, move, battle|
  next if battle.pbAllFainted?(user.idxOpposingSide)
  next if user.fainted?
  num_fainted = CarrionFeast.fainted_foes_from_move(user, targets)
  next if num_fainted <= 0
  CarrionFeast.heal_after_ko(user, battle, num_fainted)
})

# Optional AI support
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
      if score.is_a?(Numeric) && user && move && user.hasActiveAbility?(:CARRIONFEAST)
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

# Ninja Style
#
# Effect:
#   When this Pokemon uses Spikes or Toxic Spikes, it sets 2 layers at once.
#
# FunctionCode supported:
#   AddSpikesToFoeSide
#   AddToxicSpikesToFoeSide

module NinjaStyle
  ABILITY = :NINJASTYLE
  DATA = {
    :Spikes => { :effect => :Spikes, :max    => 3, :name   => "Spikes" },
    :ToxicSpikes => { :effect => :ToxicSpikes, :max    => 2, :name   => "Toxic Spikes" }
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
      battle.pbDisplay(_INTL("{1}'s {2} set an extra layer of {3}!", user.pbThis, user.abilityName, data[:name]))
    end
    battle.pbHideAbilitySplash(user)
  end
end

# Patch Spikes: FunctionCode = AddSpikesToFoeSide

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

# Patch Toxic Spikes: FunctionCode = AddToxicSpikesToFoeSide

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

# Teravolt / Turboblaze custom type addition
# - Teravolt: thêm Electric-type cho Pokemon sở hữu khi vào sân.
# - Turboblaze: thêm Fire-type cho Pokemon sở hữu khi vào sân.
# - Vẫn giữ vai trò Mold Breaker-style của ability vì ability ID vẫn là
#   :TERAVOLT / :TURBOBLAZE.

Battle::AbilityEffects::OnSwitchIn.add(:TERAVOLT, proc { |ability, battler, battle, switch_in|
  battle.pbShowAbilitySplash(battler)
  if Battle::Scene::USE_ABILITY_SPLASH
    battle.pbDisplay(_INTL("{1} is radiating a bursting electric aura!", battler.pbThis))
  else
    battle.pbDisplay(_INTL("{1}'s {2} is radiating a bursting electric aura!", battler.pbThis, battler.abilityName))
  end
  if !battler.pbHasType?(:ELECTRIC)
    battler.effects[PBEffects::ExtraType] = :ELECTRIC
    battle.pbDisplay(_INTL("{1} gained the Electric type!", battler.pbThis))
  end
  battle.pbHideAbilitySplash(battler)
})

Battle::AbilityEffects::OnSwitchIn.add(:TURBOBLAZE, proc { |ability, battler, battle, switch_in|
  battle.pbShowAbilitySplash(battler)
  if Battle::Scene::USE_ABILITY_SPLASH
    battle.pbDisplay(_INTL("{1} is radiating a blazing aura!", battler.pbThis))
  else
    battle.pbDisplay(_INTL("{1}'s {2} is radiating a blazing aura!", battler.pbThis, battler.abilityName))
  end
  if !battler.pbHasType?(:FIRE)
    battler.effects[PBEffects::ExtraType] = :FIRE
    battle.pbDisplay(_INTL("{1} gained the Fire type!", battler.pbThis))
  end
  battle.pbHideAbilitySplash(battler)
})

# Overwhelm
# - Damage-dealing Dragon-type moves used by this Pokemon can hit Fairy-type
#   Pokemon.
# - Blocks Intimidate.
# - Blocks Terror Sower.
#
# Ability ID mặc định: :OVERWHELM
# Nếu PBS của bạn dùng :OVERHELM thì đổi hằng bên dưới.
OVERWHELM_ABILITY = :OVERWHELM

# 1. Dragon-type damaging moves can hit Fairy-type Pokemon
class Battle::Move
  alias overwhelm_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:overwhelm_pbCalcTypeModSingle)

  def pbCalcTypeModSingle(moveType, defType, user, target)
    if user && user.hasActiveAbility?(OVERWHELM_ABILITY) && moveType == :DRAGON && defType == :FAIRY && self.damagingMove?
      # Dragon vs Fairy bình thường là 0x.
      # Overwhelm biến phần Fairy immunity thành neutral.
      # Nếu target là Fairy/Steel, kết quả cuối sẽ còn tính phần Steel resist.
      return Effectiveness.calculate_one(:NORMAL, :NORMAL)
    end
    return overwhelm_pbCalcTypeModSingle(moveType, defType, user, target)
  end
end

# 2. Blocks Intimidate
Battle::AbilityEffects::OnIntimidated.add(OVERWHELM_ABILITY, proc { |ability, battler, battle|
  battle.pbShowAbilitySplash(battler)
  if Battle::Scene::USE_ABILITY_SPLASH
    battle.pbDisplay(_INTL("{1} cannot be intimidated!", battler.pbThis))
  else
    battle.pbDisplay(_INTL("{1}'s {2} prevents intimidation!", battler.pbThis, battler.abilityName))
  end
  battle.pbHideAbilitySplash(battler)
  next true
})

# 3. Terror Sower with Overwhelm check
# Đặt đoạn này SAU handler Terror Sower cũ, hoặc dùng đoạn này để thay handler cũ.
Battle::AbilityEffects::OnSwitchIn.add(:TERRORSOWER, proc { |ability, battler, battle, switch_in|
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
        battle.pbDisplay(_INTL("{1}'s {2} blocks {3}'s Terror Sower!", b.pbThis, b.abilityName, battler.pbThis(true)))
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
})

# Juggernaut
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

module Juggernaut
  ABILITY = :JUGGERNAUT
  DEFENSE_PORTION = 0.20
  # Ability / innate helper

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
      return true if battler.respond_to?(:abilityMutationList) && battler.abilityMutationList &&
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
        return true if battler.respond_to?(method_name) && battler.send(method_name, ability)
      rescue
      end
    end
    return false
  end
  # Move helper

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
  # Stat helpers

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
    if item_active?(user, :METALPOWDER) && user.respond_to?(:isSpecies?) && user.isSpecies?(:DITTO) && !transformed?(user)
      defense = (defense * 1.5).floor
    end

    # Fur Coat / Cotton Cloak-style Defense modifiers.
    if has_ability_or_innate?(user, :FURCOAT) || has_ability_or_innate?(user, :COTTONCLOAK)
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

# Ability effect

Battle::AbilityEffects::DamageCalcFromUser.add(:JUGGERNAUT, proc { |ability, user, target, move, mults, power, type|
  next if !Juggernaut.can_apply?(user, move)
  mults[:attack_multiplier] *= Juggernaut.attack_multiplier(user, target, move)
})

# Optional AI support
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
        if arg.respond_to?(:pbContactMove?) || arg.respond_to?(:contactMove?) || arg.respond_to?(:pbDamagingMove?) ||
           arg.respond_to?(:damagingMove?)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?)
          user = arg if user.nil?
        end
      end
      if score.is_a?(Numeric) && user && move && user.hasActiveAbility?(:JUGGERNAUT) && Juggernaut.can_apply?(user, move)
        score += 20
        PBDebug.log_ai("     + Juggernaut adds Defense to contact damage: 20") if defined?(PBDebug)
      end
      return score
    end
  end
end

# Ice Dew
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

# Ice-type immunity + charge

Battle::AbilityEffects::MoveImmunity.add(:ICEDEW, proc { |ability, user, target, move, type, battle, show_message|
  next false if battle.moldBreaker
  next false if !IceDew.ice_type?(type, move)
  if show_message
    battle.pbShowAbilitySplash(target)
    if IceDew.charged?(target)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} absorbed the icy attack!", target.pbThis))
      else
        battle.pbDisplay(_INTL("{1}'s {2} absorbed the icy attack!", target.pbThis, target.abilityName))
      end
    else
      IceDew.set_charged(target)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1}'s Ice-type moves were powered up!", target.pbThis))
      else
        battle.pbDisplay(_INTL("{1}'s {2} powered up its Ice-type moves!", target.pbThis, target.abilityName))
      end
    end
    battle.pbHideAbilitySplash(target)
  else
    IceDew.set_charged(target)
  end

  # Immune to the Ice-type move.
  next true
})

# Boost user's Ice-type moves after being charged

Battle::AbilityEffects::DamageCalcFromUser.add(:ICEDEW, proc { |ability, user, target, move, mults, power, type|
  next if !IceDew.charged?(user)
  next if !IceDew.ice_type?(type, move)
  mults[:power_multiplier] *= IceDew::BOOST_MULTIPLIER
})

# Optional AI support
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
        if user && user.hasActiveAbility?(:ICEDEW) && IceDew.charged?(user) && move_type == :ICE
          score += 25
          PBDebug.log_ai("     + Ice Dew boosts this Ice move: 25") if defined?(PBDebug)
        end
      end
      return score
    end
  end
end

# Heavy Metal Plus
#
# Added effect:
#   Heavy Metal increases Defense by 20%.
#
# Notes:
#   - This affects damage calculation only.
#   - It boosts the defensive stat used against physical moves.
#   - The original Heavy Metal weight effect is kept unchanged.

Battle::AbilityEffects::DamageCalcFromTarget.add(:HEAVYMETAL, proc { |ability, user, target, move, mults, power, type|
  next if !move.physicalMove?
  mults[:defense_multiplier] *= 1.2
})

# Powder Burst
#
# Effect:
#   Powder moves gain +1 priority.
#
# Notes:
#   - Uses move.powderMove? if available.
#   - Also checks the PBS move flag "Powder" as fallback.
#   - Works with Sleep Powder, Stun Spore, Poison Powder, Spore, Rage Powder,
#     Cotton Spore, Powder, and custom moves with the Powder flag.

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

# Ability effect

Battle::AbilityEffects::PriorityBracketChange.add(:POWDERBURST, proc { |ability, battler, battle|
  next 0 if !battler
  next 0 if battler.fainted?
  choice = battle.choices[battler.index]
  next 0 if !choice
  next 0 if choice[0] != :UseMove
  move = choice[2]
  next 0 if !PowderBurst.powder_move?(move)
  next 1
})

# Optional AI support
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
        if arg.respond_to?(:powderMove?) || arg.instance_variable_defined?(:@flags) || arg.respond_to?(:flags)
          move = arg
        elsif arg.respond_to?(:hasActiveAbility?)
          user = arg if user.nil?
        end
      end
      if score.is_a?(Numeric) && user && move && user.hasActiveAbility?(:POWDERBURST) && PowderBurst.powder_move?(move)
        score += 15
        PBDebug.log_ai("     + Powder Burst gives powder move priority: 15") if defined?(PBDebug)
      end
      return score
    end
  end
end

# Parasite Host
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
      return true if battler.respond_to?(:abilityMutationList) && battler.abilityMutationList &&
                     battler.abilityMutationList.include?(ABILITY)
    rescue
    end
    [ :hasInnateAbility?, :hasActiveInnateAbility?, :hasInnate?, :hasActiveInnate?, :pbHasInnateAbility? ].each do |method_name|
      begin
        return true if battler.respond_to?(method_name) && battler.send(method_name, ABILITY)
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
      battle.pbDisplay(_INTL("{1}'s {2} let it cling to its turn!", battler.pbThis, battler.abilityName))
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

# Keep the Pokémon alive at 1 HP if it would faint before acting

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

# After attempting to use its chosen move, the Pokémon faints

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

# Safety cleanup at end of round

class Battle
  if method_defined?(:pbEndOfRoundPhase) && !method_defined?(:parasite_host_pbEndOfRoundPhase)
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

# Parasite Host - No Healing While Borrowed Time
# While Parasite Host is keeping the Pokemon alive at 1 HP, it cannot heal.
# This prevents healing moves, draining moves, berries, Leftovers, Aqua Ring, etc.
# The Pokemon will still faint after its action.

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

# Seed Parasite
#
# Effect:
#   If this Pokemon is knocked out by a contact move, the attacker is afflicted
#   with Leech Seed.
#
# Notes:
#   - Does not affect Grass-type Pokemon.
#   - Does not affect a target already affected by Leech Seed.
#   - Only triggers if the Seed Parasite user was knocked out by that hit.

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

# Ability effect

Battle::AbilityEffects::OnBeingHit.add(:SEEDPARASITE, proc { |ability, user, target, move, battle|
  # user   = attacker
  # target = Pokemon with Seed Parasite
  next if !SeedParasite.can_apply?(user, target, move)
  battle.pbShowAbilitySplash(target)
  if SeedParasite.set_seeded(user, target)
    if Battle::Scene::USE_ABILITY_SPLASH
      battle.pbDisplay(_INTL("{1} was seeded by the parasite!", user.pbThis))
    else
      battle.pbDisplay(_INTL("{1}'s {2} seeded {3}!", target.pbThis, target.abilityName, user.pbThis(true)))
    end
  end
  battle.pbHideAbilitySplash(target)
})

# Ancient Slumber
#
# Effect:
#   While this Pokemon is asleep, every 2 turns it has a 25% chance to raise
#   all main stats by 1 stage.
#
# Main stats:
#   Attack, Defense, Special Attack, Special Defense, Speed

module AncientSlumber
  CHANCE = 25
  TURN_INTERVAL = 2

  def self.counter(battler); return battler.instance_variable_get(:@ancient_slumber_counter).to_i; end

  def self.set_counter(battler, value); battler.instance_variable_set(:@ancient_slumber_counter, value.to_i); end

  def self.reset_counter(battler); set_counter(battler, 0); end

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

# Ability effect

Battle::AbilityEffects::EndOfRoundEffect.add(:ANCIENTSLUMBER, proc { |ability, battler, battle|
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
})

# Cleanup on switch out

class Battle::Battler
  if method_defined?(:pbAbilitiesOnSwitchOut) && !method_defined?(:ancient_slumber_pbAbilitiesOnSwitchOut)
    alias ancient_slumber_pbAbilitiesOnSwitchOut pbAbilitiesOnSwitchOut
  end

  def pbAbilitiesOnSwitchOut(*args)
    AncientSlumber.reset_counter(self)
    return ancient_slumber_pbAbilitiesOnSwitchOut(*args)
  end
end

# Stone Scatter
#
# Effect:
#   The first time this Pokemon enters battle, it sets Stealth Rock on the
#   opposing side of the field.
#
# Notes:
#   - Only activates once per Pokemon per battle.
#   - Does nothing if the opposing side already has Stealth Rock.
#   - Does not consume the Pokemon's turn.

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
      battle.pbDisplay(_INTL("{1}'s {2} scattered pointed stones around the opposing team!", battler.pbThis, battler.abilityName))
    end
    battle.pbHideAbilitySplash(battler)
  end
end

# Ability effect

Battle::AbilityEffects::OnSwitchIn.add(:STONESCATTER, proc { |ability, battler, battle, switch_in| StoneScatter.trigger(battler, battle) })
##------------------------------------------------------------------------------
# Self-Sufficient

module SelfSufficient
  def self.heal_amount(hp, totalhp); return [totalhp / ((hp * 2 < totalhp) ? 8 : 16), 1].max; end
end

Battle::AbilityEffects::EndOfRoundEffect.remove(:SELFSUFFICIENT)

Battle::AbilityEffects::EndOfRoundHealing.add(:SELFSUFFICIENT, proc { |ability, battler, battle|
  next if !battler.canHeal?
  battle.pbShowAbilitySplash(battler)
  battler.pbRecoverHP(SelfSufficient.heal_amount(battler.hp, battler.totalhp))
  battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, GameData::Ability.get(ability).name))
  battle.pbHideAbilitySplash(battler)
})
KaitoAbilitySupport.rate(:SELFSUFFICIENT, 8)
Battle::AI::Handlers::AbilityRanking.add(:SELFSUFFICIENT, proc { |ability, score, battler, ai| next (battler.hp * 2 < battler.totalhp) ? 9 : 8 }
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
        user.hasActiveItem?(:LEFTOVERS) || (user.hasActiveItem?(:BLACKSLUDGE) && user.pbHasType?(:POISON)) ||
        user.effects[PBEffects::Ingrain] ||
        user.effects[PBEffects::AquaRing] ||
        (user.hasActiveAbility?(:POISONHEAL) && user.poisoned?) ||
        (user.hasActiveAbility?([:DRYSKIN, :RAINDISH]) && [:Rain, :HeavyRain].include?(weather)) ||
        (user.hasActiveAbility?(:ICEBODY) && [:Hail, :Snow].include?(weather)) ||
        (@battle.field.terrain == :Grassy && real_user.affectedByTerrain?)
      return score if other_recovery || user.hp.to_f / user.totalhp >= 0.9
      score += 40
      score += 20 if user.hp * 2 < user.totalhp
      return score
    end
  end
  Battle::AI.prepend(SelfSufficient::ProtectAI)
end

# Refuge

module Refuge
  PopupBattler = Struct.new(:index, :name, :abilityName)

	def self.with_popup(battler, owner_name)
	  battle = battler.battle
	  enabled = Battle::Scene::USE_ABILITY_SPLASH
	  popup = PopupBattler.new( battler.index, owner_name, GameData::Ability.get(:REFUGE).name )
	  begin
		battle.scene.pbShowAbilitySplash(popup) if enabled
		yield
	  ensure
		battle.scene.pbHideAbilitySplash(popup) if enabled
	  end
	end

  def self.ally_source(battle, index, entering = [])
    return battle.allBattlers.find do |b|
      b.index != index && !entering.include?(b.index) && !b.opposes?(index) && !b.fainted? && b.hasActiveAbility?(:REFUGE)
    end
  end

  def self.restore(battler, divisor, source = nil, source_name = nil)
    return if battler.fainted?
    battle = battler.battle
    ability_name = GameData::Ability.get(:REFUGE).name
    source_name ||= source ? source.name : ability_name
    battler.instance_variable_set( :@refuge_cure_pending, [battler.pokemon, source_name] )
    return if !battler.canHeal?
    with_popup(battler, source_name) do
      battler.pbRecoverHP([battler.totalhp / divisor, 1].max)
      battle.pbDisplay(_INTL("{1}'s {2} restored {3}'s HP!", source_name, ability_name, battler.pbThis(true)))
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
  def refuge_pending; return @refuge_pending ||= {}; end
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
    if pending && battler.pokemon.equal?(pending[0]) && !battler.fainted? && battler.status != :NONE
      Refuge.with_popup(battler, pending[1]) do
        battler.pbCureStatus(false)
        pbDisplay(_INTL("{1}'s {2} cured {3}'s status!", pending[1], GameData::Ability.get(:REFUGE).name, battler.pbThis(true)))
      end
    end
    return result
  end
end

Battle::AbilityEffects::OnSwitchOut.add(:REFUGE, proc { |ability, battler, end_of_battle|
  next if end_of_battle || battler.fainted?
  next if !battler.hasActiveAbility?(:REFUGE)
  battler.battle.refuge_pending[battler.index] = battler.name
})
KaitoAbilitySupport.rate(:REFUGE, 8)
Battle::AI::Handlers::AbilityRanking.add(:REFUGE, proc { |ability, score, battler, ai|
  reserves = ai.get_non_active_party_pokemon(battler.index)
  next 0 if reserves.empty? && ai.battle.pbSideSize(battler.index) == 1
  next 8
})
Battle::AI::Handlers::ShouldSwitch.add(:refuge_support, proc { |battler, reserves, ai, battle|
  next false if !battler.has_active_ability?(:REFUGE)
  next false if battler.hp * 2 <= battler.totalhp
  next reserves.any? { |pkmn|
    useful = pkmn.status != :NONE || pkmn.totalhp - pkmn.hp >= [pkmn.totalhp / 4, 1].max
    if useful && ai.respond_to?(:ohkod_on_switch_in?)
      useful = !ai.ohkod_on_switch_in?(pkmn, battler)
    end
    useful
  }
})

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

# Branch Swing
module BranchSwing
  def self.active?(battler)
    return !battler.fainted? && battler.battle.field.terrain == :Grassy && battler.hasActiveAbility?(:BRANCHSWING)
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
    return active?(battler) && !battler.semiInvulnerable? && !battler.affectedByTerrain? && battler.canHeal?
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
      battle.pbDisplay(_INTL( "{1}'s {2} activated on the grassy terrain!", battler.pbThis, GameData::Ability.get(:BRANCHSWING).name ))
    end
  end
end

# Loại bỏ hiệu ứng tăng Speed cũ
Battle::AbilityEffects::SpeedCalc.remove(:BRANCHSWING)

# Pop-up khi vào sân hoặc khi terrain thay đổi
Battle::AbilityEffects::OnSwitchIn.add(:BRANCHSWING, proc { |ability, battler, battle, switch_in| BranchSwing.notify_activation(battler, battle, switch_in) }
)

Battle::AbilityEffects::OnTerrainChange.add(:BRANCHSWING, proc { |ability, battler, battle, ability_changed| BranchSwing.notify_activation(battler, battle, ability_changed) }
)

# Lơ lửng như Levitate khi có Grassy Terrain
class Battle::Battler
  alias_method :branch_swing_original_airborne, :airborne?

  def airborne?
    return true if BranchSwing.floating?(self)
    return branch_swing_original_airborne
  end
end

# Miễn nhiễm chiêu Ground gây sát thương
Battle::AbilityEffects::MoveImmunity.add(:BRANCHSWING, proc { |ability, user, target, move, type, battle, show_message|
  next false if type != :GROUND || !move.damagingMove?
  next false if move.hitsFlyingTargets?
  next false if !BranchSwing.floating?(target)
  if show_message
    BranchSwing.with_popup(target, battle) do
      battle.pbDisplay(_INTL( "{1} avoided the attack with {2}!", target.pbThis, GameData::Ability.get(ability).name ))
    end
  end
  next true
})

# Tăng 10% evasion khi có Grassy Terrain
Battle::AbilityEffects::AccuracyCalcFromTarget.add(:BRANCHSWING, proc { |ability, mods, user, target, move, type|
  next if !BranchSwing.active?(target)
  mods[:evasion_multiplier] *= 1.1
})

# Vẫn nhận hồi phục từ Grassy Terrain khi đang lơ lửng
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

# AI: Ability rating
KaitoAbilitySupport.rate(:BRANCHSWING, 7)
Battle::AI::Handlers::AbilityRanking.add(:BRANCHSWING, proc { |ability, score, battler, ai|
  next 8 if ai.battle.field.terrain == :Grassy
  next 5 if battler.has_move_with_function?("StartGrassyTerrain")
  next 3
})

# AI: Tính lượng hồi phục cuối lượt
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

# AI: Trạng thái lơ lửng và đánh giá Grassy Terrain
class Battle::AI
  alias_method :branch_swing_original_pokemon_airborne, :pokemon_airborne?

  def pokemon_airborne?(pkmn)
    return true if branch_swing_original_pokemon_airborne(pkmn)
    return false if @battle.field.terrain != :Grassy
    return false if pkmn.hasItem?(:IRONBALL)
    return false if @battle.field.effects[PBEffects::Gravity] > 0
    return false if !BranchSwing.pokemon_has_ability?(pkmn)
    if @battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS) && !pkmn.hasItem?(:ABILITYSHIELD)
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

# Poseidon Guard
module PoseidonGuard
  def self.above_threshold?(battler); return !battler.fainted? && battler.hp * 3 > battler.totalhp * 2; end

  def self.active?(battler); return above_threshold?(battler) && battler.hasActiveAbility?(:POSEIDONGUARD); end
end

# Miễn nhiễm trạng thái chính khi HP trên 2/3
Battle::AbilityEffects::StatusImmunity.add(:POSEIDONGUARD, proc { |ability, battler, status| next PoseidonGuard.active?(battler) })

# Giảm 25% sát thương từ chiêu thức khi HP trên 2/3
Battle::AbilityEffects::DamageCalcFromTarget.add(:POSEIDONGUARD, proc { |ability, user, target, move, mults, power, type|
  next if !PoseidonGuard.active?(target)
  mults[:final_damage_multiplier] *= 0.75
})

# AI: Giá trị cơ bản của ability
KaitoAbilitySupport.rate(:POSEIDONGUARD, 8)

# AI: Đánh giá theo HP hiện tại
Battle::AI::Handlers::AbilityRanking.add(:POSEIDONGUARD, proc { |ability, score, battler, ai|
  next 9 if PoseidonGuard.above_threshold?(battler.battler)
  next 4
})

# Spell Fist
module SpellFist
  def self.converts?(user, move); return user && move.damagingMove? && move.punchingMove? && user.hasActiveAbility?(:SPELLFIST); end
end

# Chuyển chiêu đấm sang special trước khi tính chỉ số và các hiệu ứng liên quan.
# Không thay đổi category gốc trong PBS.
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

# Spell Fist: +20%; cùng Iron Fist: tổng cộng +30%.
Battle::AbilityEffects::DamageCalcFromUser.add(:SPELLFIST, proc { |ability, user, target, move, mults, power, type|
  next if !SpellFist.converts?(user, move)
  bonus = user.hasActiveAbility?(:IRONFIST) ? 1.3 : 1.2
  mults[:power_multiplier] *= bonus
})

# Iron Fist: nhường phần tăng sát thương cho Spell Fist nếu cả hai hoạt động.
# Iron Fist đứng riêng vẫn tăng 20% như bình thường.
Battle::AbilityEffects::DamageCalcFromUser.add(:IRONFIST, proc { |ability, user, target, move, mults, power, type|
  next if !move.damagingMove? || !move.punchingMove?
  next if user.hasActiveAbility?(:SPELLFIST)
  mults[:power_multiplier] *= 1.2
})

# AI: xác định người sử dụng trước khi đánh giá loại chiêu.
# Bao gồm AI cấp thấp không gọi pbCalcType khi set_up.
class Battle::AI::AIMove
  alias_method :spell_fist_original_set_up, :set_up

  def set_up(move)
    move.spell_fist_user = @ai.user.battler
    spell_fist_original_set_up(move)
  end
end

# AI: Ability rating
KaitoAbilitySupport.rate(:SPELLFIST, 6)
Battle::AI::Handlers::AbilityRanking.add(:SPELLFIST, proc { |ability, score, battler, ai|
  has_punch = battler.moves.any? do |move|
    move.damagingMove? && move.punchingMove? && (move.pp > 0 || move.total_pp == 0)
  end
  next 0 if !has_punch
  next 8 if battler.battler.spatk >= battler.battler.attack
  next 3
})

# Bloodlust
module Bloodlust
  def self.heal_amount(totalhp); return [totalhp / 5, 1].max; end
end

Battle::AbilityEffects::OnEndOfUsingMove.add(:BLOODLUST, proc { |ability, user, targets, move, battle|
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
    battle.pbDisplay(_INTL( "{1}'s {2} restored its HP!", user.pbThis, ability_name ))
  ensure
    begin
      battle.pbHideAbilitySplash(user)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
})

# AI: Ability rating
KaitoAbilitySupport.rate(:BLOODLUST, 7)
Battle::AI::Handlers::AbilityRanking.add(:BLOODLUST, proc { |ability, score, battler, ai|
  next 0 if !battler.moves.any? { |move| move.damagingMove? }
  next 8 if battler.battler.canHeal?
  next 6
})

# AI: Ưu tiên đòn kết liễu khi có thể hồi HP.
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
  })

# Battle Genes
Battle::AbilityEffects::DamageCalcFromUser.add(:BATTLEGENES, proc { |ability, user, target, move, mults, power, type|
  next if !move.damagingMove?
  next if !user.hasActiveAbility?(:BATTLEGENES)
  next if !type || !target.pbHasType?(type)
  mults[:final_damage_multiplier] *= 1.3
})

# AI: Ability rating
# AI tính sát thương bằng cùng handler phía trên.
KaitoAbilitySupport.rate(:BATTLEGENES, 6)
Battle::AI::Handlers::AbilityRanking.add(:BATTLEGENES, proc { |ability, score, battler, ai|
  next 0 if !battler.moves.any? { |move| move.damagingMove? }
  next score
})

# Flying Nimbus
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

# Lơ lửng như Levitate
class Battle::Battler
  alias_method :flying_nimbus_original_airborne, :airborne?

  def airborne?
    return true if FlyingNimbus.floating?(self)
    return flying_nimbus_original_airborne
  end
end

# Miễn nhiễm chiêu Ground gây sát thương
Battle::AbilityEffects::MoveImmunity.add(:FLYINGNIMBUS, proc { |ability, user, target, move, type, battle, show_message|
  next false if type != :GROUND || !move.damagingMove?
  next false if move.hitsFlyingTargets?
  next false if !FlyingNimbus.floating?(target)
  if show_message
    FlyingNimbus.with_popup(target, battle) do
      battle.pbDisplay(_INTL( "{1} avoided the attack with {2}!", target.pbThis, GameData::Ability.get(ability).name ))
    end
  end
  next true
})

# Tăng 20% sát thương nếu ra đòn trước mục tiêu
Battle::AbilityEffects::DamageCalcFromUser.add(:FLYINGNIMBUS, proc { |ability, user, target, move, mults, power, type|
  next if !move.damagingMove?
  next if !user.hasActiveAbility?(:FLYINGNIMBUS)

  # AI đặt giá trị dự đoán tạm thời khi tính rough_damage.
  first = move.instance_variable_get(:@flying_nimbus_ai_first)
  first = !target.movedThisRound? if first.nil?
  next if !first
  mults[:final_damage_multiplier] *= 1.2
})

# AI: Dự đoán thứ tự hành động khi tính sát thương
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
            target_priority = Battle::AbilityEffects.triggerPriorityChange( target.ability, target.battler, target_move, target_priority )
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

# AI: Nhận biết Pokémon ngoài sân đang lơ lửng
class Battle::AI
  alias_method :flying_nimbus_original_pokemon_airborne, :pokemon_airborne?

  def pokemon_airborne?(pkmn)
    return true if flying_nimbus_original_pokemon_airborne(pkmn)
    return false if pkmn.hasItem?(:IRONBALL)
    return false if @battle.field.effects[PBEffects::Gravity] > 0
    return false if !FlyingNimbus.pokemon_has_ability?(pkmn)
    if @battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS) && !pkmn.hasItem?(:ABILITYSHIELD)
      return false
    end
    return true
  end
end

# AI: Ability rating
KaitoAbilitySupport.rate(:FLYINGNIMBUS, 8)

# Worldroot
module Worldroot
  def self.affects?(target)
    return false if !target || target.fainted?
    return target.battle.allBattlers.any? do |owner| owner.opposes?(target) && owner.hasActiveAbility?(:WORLDROOT) end
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

# Bỏ miễn nhiễm Ground do trạng thái airborne trong bước kiểm tra chiêu.
# Prepend để áp dụng trước cả Branch Swing/Flying Nimbus.
module WorldrootBattlerAirborne
  def airborne?
    if @worldroot_ground_check && Worldroot.affects?(self)
      return false
    end
    return super
  end
end
Battle::Battler.prepend(WorldrootBattlerAirborne)

# Trận đấu: kiểm tra mục tiêu của chiêu Ground
class Battle::Battler
  alias_method :worldroot_original_success_check, :pbSuccessCheckAgainstTarget

  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    if move.calcType == :GROUND && Worldroot.affects?(target)
      return Worldroot.with_ground_check(target) do worldroot_original_success_check(move, user, target, targets) end
    end
    return worldroot_original_success_check(move, user, target, targets)
  end
end

# Hệ Flying không còn miễn nhiễm Ground.
# Vẫn tính kháng/yếu từ các hệ còn lại của mục tiêu.
class Battle::Move
  alias_method :worldroot_original_type_mod_single, :pbCalcTypeModSingle

  def pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :GROUND && defType == :FLYING && Worldroot.affects?(target)
      return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    end
    return worldroot_original_type_mod_single(moveType, defType, user, target)
  end
  # Bỏ miễn nhiễm Ground từ ability, ngoại trừ Earth Eater.
  # Các hệ chiêu khác giữ nguyên cơ chế hiện tại.
  alias_method :worldroot_original_immunity_by_ability, :pbImmunityByAbility

  def pbImmunityByAbility(user, target, show_message)
    if @calcType == :GROUND && Worldroot.affects?(target)
      # Giữ nguyên quy tắc Mold Breaker của game.
      return false if @battle.moldBreaker
      return false if !target.hasActiveAbility?(:EARTHEATER)

      # Gọi riêng Earth Eater, không gọi lại các innate miễn nhiễm khác.
      return Battle::AbilityEffects::MoveImmunity.trigger( :EARTHEATER, user, target, self, @calcType, @battle, show_message )
    end
    return worldroot_original_immunity_by_ability(user, target, show_message)
  end
end

# Pop-up khi người sở hữu vào sân
Battle::AbilityEffects::OnSwitchIn.add(:WORLDROOT, proc { |ability, battler, battle, switch_in|
  next if !battler.hasActiveAbility?(:WORLDROOT)
  next if !battle.allBattlers.any? { |b| b.opposes?(battler) }
  old_name  = $aamName
  old_name2 = $aamName2
  begin
    ability_name = GameData::Ability.get(ability).name
    $aamName  = ability_name
    $aamName2 = ability_name
    battle.pbShowAbilitySplash(battler)
    battle.pbDisplay(_INTL( "{1}'s roots stripped opposing Pokémon of their Ground immunity!", battler.pbThis ))
  ensure
    begin
      battle.pbHideAbilitySplash(battler)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
})

# AI: nhận biết chiêu Ground có thể đánh trúng mục tiêu
class Battle::AI
  alias_method :worldroot_original_predict_failure, :pbPredictMoveFailureAgainstTarget

  def pbPredictMoveFailureAgainstTarget
    if @target && @move.rough_type == :GROUND && Worldroot.affects?(@target.battler)
      return Worldroot.with_ground_check(@target.battler) do worldroot_original_predict_failure end
    end
    return worldroot_original_predict_failure
  end
end

# AI: tính hiệu quả Ground đối với hệ Flying
class Battle::AI::AIBattler
  alias_method :worldroot_original_single_type_effectiveness, :effectiveness_of_type_against_single_battler_type

  def effectiveness_of_type_against_single_battler_type( type, defend_type, user = nil )
    if type == :GROUND && defend_type == :FLYING && Worldroot.affects?(battler)
      return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    end
    return worldroot_original_single_type_effectiveness( type, defend_type, user )
  end
  private :effectiveness_of_type_against_single_battler_type
end

# AI: Ability rating
KaitoAbilitySupport.rate(:WORLDROOT, 7)
Battle::AI::Handlers::AbilityRanking.add(:WORLDROOT, proc { |ability, score, battler, ai|
  next 8 if battler.has_damaging_move_of_type?(:GROUND)
  next score
})

# Run Away - Complete effects

module RunAwayEnhanced
  def self.trigger_count(battler); return battler.instance_variable_get(:@run_away_trigger_count) || 0; end

  def self.raise_speed(battler)
    return if !battler.hasActiveAbility?(:RUNAWAY)

    # Ghi nhận cả khi Speed không thể tăng thêm để tránh kích hoạt lặp.
    battler.instance_variable_set( :@run_away_trigger_count, trigger_count(battler) + 1 )
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

# Chắc chắn thoát trận hoang dã khi bị giữ chân.
# Không phụ thuộc MAG_RUNAWAY hoặc CHAMPIONS_MECHANICS.
Battle::AbilityEffects::CertainEscapeFromBattle.add(:RUNAWAY, proc { |ability, battler| next true })

# Cho phép đổi Pokémon khi bị giữ chân.
Battle::AbilityEffects::CertainSwitching.add(:RUNAWAY, proc { |ability, battler, battle| next true })

# Sửa bước kiểm tra giữ chân bổ sung của Innate Abilities.
# Giữ nguyên kiểm tra Pokémon thay thế và các giới hạn khác của trận đấu.
class << Battle::AbilityEffects
  alias_method :run_away_original_trapping_by_target, :triggerTrappingByTarget

  def triggerTrappingByTarget(ability, switcher, bearer, battle)
    return false if switcher.hasActiveAbility?(:RUNAWAY)
    return run_away_original_trapping_by_target( ability, switcher, bearer, battle )
  end
end

# Speed +2 khi bị Intimidate.
# Thay handler cũ, không cộng thêm một lần tăng thứ hai.
Battle::AbilityEffects::OnIntimidated.add(:RUNAWAY, proc { |ability, battler, battle| RunAwayEnhanced.raise_speed(battler) })

# Bổ sung phản ứng với Terror Sower.
# Giữ nguyên handler Terror Sower hiện có, gồm phần kiểm tra Overwhelm.
# Không tăng Speed lần nữa nếu handler cũ đã kích hoạt Run Away.
run_away_terror_sower_handler = Battle::AbilityEffects::OnSwitchIn[:TERRORSOWER]
if run_away_terror_sower_handler
  Battle::AbilityEffects::OnSwitchIn.add(:TERRORSOWER, proc { |ability, battler, battle, switch_in|
      snapshots = []
      battle.allOtherSideBattlers(battler.index).each do |target|
        next if target.fainted?
        snapshots << [ target, target.stages[:SPECIAL_ATTACK], RunAwayEnhanced.trigger_count(target) ]
      end
      run_away_terror_sower_handler.call( ability, battler, battle, switch_in )
      snapshots.each do |target, old_spatk_stage, old_count|
        next if target.fainted?
        next if !target.hasActiveAbility?(:RUNAWAY)
        next if target.stages[:SPECIAL_ATTACK] == old_spatk_stage
        next if RunAwayEnhanced.trigger_count(target) != old_count
        RunAwayEnhanced.raise_speed(target)
      end
    })
end

# AI: Run Away có giá trị chiến đấu cả với Pokémon hoang dã.
# Thay đánh giá cũ vốn cho Run Away điểm 0 khi Pokémon là wild.
KaitoAbilitySupport.rate(:RUNAWAY, 7)
Battle::AI::Handlers::AbilityRanking.add(:RUNAWAY, proc { |ability, score, battler, ai| next score })

# Cheek Pouch - Generates a random Berry when empty-handed
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

Battle::AbilityEffects::EndOfRoundGainItem.add(:CHEEKPOUCH, proc { |ability, battler, battle|
  next if battler.fainted?
  next if !battler.hasActiveAbility?(:CHEEKPOUCH)
  next if battler.item

  # Chỉ tạo tối đa một Berry mỗi lượt, kể cả khi ăn ngay.
  last_turn = battler.instance_variable_get(:@cheek_pouch_berry_turn)
  next if last_turn == battle.turnCount
  berry = CheekPouchEnhanced::BERRIES[ battle.pbRandom(CheekPouchEnhanced::BERRIES.length) ]
  battler.instance_variable_set( :@cheek_pouch_berry_turn, battle.turnCount )
  old_name  = $aamName
  old_name2 = $aamName2
  begin
    ability_name = GameData::Ability.get(ability).name
    $aamName  = ability_name
    $aamName2 = ability_name
    battle.pbShowAbilitySplash(battler)
    battler.item = berry
    battle.pbDisplay(_INTL( "{1} obtained a {2}!", battler.pbThis, GameData::Item.get(berry).name ))
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
  if !battler.fainted? && battler.hasActiveAbility?(:CHEEKPOUCH) && !battler.item
    replacement = CheekPouchEnhanced::BERRIES[ battle.pbRandom(CheekPouchEnhanced::BERRIES.length) ]
    battler.item = replacement
    battle.pbDisplay(_INTL( "{1} obtained another {2}!", battler.pbThis, GameData::Item.get(replacement).name ))

    # Giữ Berry bổ sung trong ô item.
    # Không kiểm tra ăn ngay lần nữa để tránh vòng lặp tạo–ăn vô hạn.
  end
})

# AI: Nâng giá trị của Cheek Pouch
KaitoAbilitySupport.rate(:CHEEKPOUCH, 8)
Battle::AI::Handlers::AbilityRanking.add(:CHEEKPOUCH, proc { |ability, score, battler, ai|
  next 9 if !battler.battler.item
  next 8 if battler.battler.item.is_berry?
  next 4
})

# Gnawing
module Gnawing
  # Các chiêu này có hai lần kiểm tra hiệu ứng phụ riêng,
  # dù EffectChance bên ngoài có thể là 100.
  FANG_FUNCTIONS = [ "BurnFlinchTarget", "FreezeFlinchTarget", "ParalyzeFlinchTarget" ].freeze

  def self.boostable?(move)
    return false if !move.damagingMove? || !move.bitingMove?
    return true if FANG_FUNCTIONS.include?(move.function_code)
    return move.addlEffect > 0 && move.addlEffect < 100
  end
end

# Nhân đôi xác suất sau các điều chỉnh hiện có.
# Giữ nguyên Shield Dust, Covert Cloak và các hiệu ứng chặn khác.
class Battle::Move
  alias_method :gnawing_original_additional_effect_chance, :pbAdditionalEffectChance

  def pbAdditionalEffectChance(user, target, effectChance = 0)
    chance = gnawing_original_additional_effect_chance( user, target, effectChance )
    return chance if !damagingMove? || !bitingMove?
    return chance if !user.hasActiveAbility?(:GNAWING)
    return chance if chance <= 0 || chance >= 100
    return [chance * 2, 100].min
  end
end

# AI: Đánh giá cao hiệu ứng phụ được tăng xác suất.
class Battle::AI::AIMove
  alias_method :gnawing_original_additional_effect_score, :get_score_change_for_additional_effect

  def get_score_change_for_additional_effect(user, target = nil)
    score = gnawing_original_additional_effect_score(user, target)
    return score if score < 0
    return score if !user.has_active_ability?(:GNAWING)
    return score if !Gnawing.boostable?(@move)
    if target && user.index != target.index && target.has_active_item?(:COVERTCLOAK)
      return score
    end
    return score + 5
  end
end

# AI: Ability rating
KaitoAbilitySupport.rate(:GNAWING, 6)
Battle::AI::Handlers::AbilityRanking.add(:GNAWING, proc { |ability, score, battler, ai|
  next 0 if !battler.moves.any? { |move| Gnawing.boostable?(move) }
  next score
})

# Debilitate
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
  # Mỗi lần dùng chiêu có một danh sách mục tiêu đã kích hoạt riêng.
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
  # Xử lý sau mỗi hit, khi hiệu ứng phụ của hit đã được áp dụng.
  alias_method :debilitate_original_process_hit, :pbProcessMoveHit

  def pbProcessMoveHit(move, user, targets, hitNum, skipAccuracyCheck)
    old_context = @battle.instance_variable_get(:@debilitate_hit_context)
    context = { :user       => user, :targets    => targets, :inflicted  => {} }
    previous_status = {}
    targets.each do |target|
      previous_status[target.object_id] = target.status != :NONE
    end
    begin
      @battle.instance_variable_set(:@debilitate_hit_context, context)
      result = debilitate_original_process_hit( move, user, targets, hitNum, skipAccuracyCheck )
      if result && move.damagingMove? && move.pbContactMove?(user) && user.hasActiveAbility?(:DEBILITATE)
        targets.each do |target|
          next if target.index == user.index
          next if target.fainted?
          next if target.damageState.unaffected
          next if target.damageState.substitute
          next if target.damageState.disguise || target.damageState.iceFace
          next if target.damageState.calcDamage <= 0
          key = target.object_id
          eligible = previous_status[key] || context[:inflicted][key] || target.status != :NONE
          next if !eligible
          Debilitate.apply(user, target, @battle)
        end
      end
      return result
    ensure
      @battle.instance_variable_set( :@debilitate_hit_context, old_context )
    end
  end
  # Ghi nhận trạng thái vừa gây ra.
  # Vẫn ghi nhận nếu Lum Berry chữa trạng thái ngay sau đó.
  alias_method :debilitate_original_inflict_status, :pbInflictStatus

  def pbInflictStatus(newStatus, newStatusCount = 0, msg = nil, user = nil)
    context = @battle.instance_variable_get(:@debilitate_hit_context)
    if context && newStatus != :NONE && context[:targets].include?(self) && self.index != context[:user].index &&
       (!user || user == context[:user])
      context[:inflicted][object_id] = true
    end
    return debilitate_original_inflict_status( newStatus, newStatusCount, msg, user )
  end
end

# AI: Ability rating
KaitoAbilitySupport.rate(:DEBILITATE, 8)
Battle::AI::Handlers::AbilityRanking.add(:DEBILITATE, proc { |ability, score, battler, ai|
  next 0 if !battler.moves.any? { |move| move.damagingMove? }
  next score
})

# AI: Ưu tiên đánh mục tiêu đã có trạng thái.
# Không giả định đòn đánh chắc chắn gây thêm trạng thái.
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
  })

# Berry Bulk
class Battle::Battler
  alias_method :berry_bulk_original_held_item_triggered, :pbHeldItemTriggered

  def pbHeldItemTriggered(item_to_use, own_item = true, fling = false)
    is_berry = GameData::Item.get(item_to_use).is_berry?

    # Xử lý hiệu ứng gốc, Cheek Pouch và tiêu thụ vật phẩm.
    result = berry_bulk_original_held_item_triggered( item_to_use, own_item, fling )
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

# AI: Ability rating
KaitoAbilitySupport.rate(:BERRYBULK, 6)
Battle::AI::Handlers::AbilityRanking.add(:BERRYBULK, proc { |ability, score, battler, ai|
  b = battler.battler
  next 8 if b.hasActiveAbility?(:CHEEKPOUCH)
  next 7 if b.item && b.item.is_berry?
  next 6 if b.hasActiveAbility?([:HARVEST, :CUDCHEW])
  next 2
})

# Infiltrator Enhanced
module InfiltratorEnhanced
  PERSONAL_PROTECTION = [ :Protect, :KingsShield, :SpikyShield, :BanefulBunker, :Obstruct, :SilkTrap, :BurningBulwark ].freeze
  SIDE_PROTECTION = [ :CraftyShield, :MatBlock, :QuickGuard, :WideGuard ].freeze

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
          save_effect.call( target.effects, PBEffects.const_get(name), false )
        end
        SIDE_PROTECTION.each do |name|
          next if !PBEffects.const_defined?(name)
          save_effect.call( target.pbOwnSide.effects, PBEffects.const_get(name), false )
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

# Khai báo khả năng xuyên Substitute cho các kiểm tra thông thường.
class Battle::Move
  alias_method :infiltrator_enhanced_original_ignores_substitute, :ignoresSubstitute?

  def ignoresSubstitute?(user)
    return true if user && user.hasActiveAbility?(:INFILTRATOR)
    return infiltrator_enhanced_original_ignores_substitute(user)
  end
end

# Trận đấu: xuyên Protect và Substitute ở bước kiểm tra mục tiêu.
class Battle::Battler
  alias_method :infiltrator_enhanced_original_success_check, :pbSuccessCheckAgainstTarget

  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    return InfiltratorEnhanced.with_bypass(user, [target]) do infiltrator_enhanced_original_success_check( move, user, target, targets ) end
  end
  # Xử lý toàn bộ hit, bao gồm sát thương và hiệu ứng phụ.
  # Substitute được giữ nguyên lượng HP sau khi xử lý.
  alias_method :infiltrator_enhanced_original_process_hit, :pbProcessMoveHit

  def pbProcessMoveHit(move, user, targets, hitNum, skipAccuracyCheck)
    return InfiltratorEnhanced.with_bypass(user, targets) do
      infiltrator_enhanced_original_process_hit( move, user, targets, hitNum, skipAccuracyCheck )
    end
  end
end

# AI: Kiểm tra khả năng đánh trúng và chấm điểm theo cùng cơ chế.
class Battle::AI
  alias_method :infiltrator_enhanced_original_predict_failure, :pbPredictMoveFailureAgainstTarget

  def pbPredictMoveFailureAgainstTarget
    return infiltrator_enhanced_original_predict_failure if !@target
    return InfiltratorEnhanced.with_bypass( @user.battler, [@target.battler] ) do infiltrator_enhanced_original_predict_failure end
  end
  alias_method :infiltrator_enhanced_original_target_score, :pbGetMoveScoreAgainstTarget

  def pbGetMoveScoreAgainstTarget
    return infiltrator_enhanced_original_target_score if !@target
    return InfiltratorEnhanced.with_bypass( @user.battler, [@target.battler] ) do infiltrator_enhanced_original_target_score end
  end
end

# AI: Ability rating
KaitoAbilitySupport.rate(:INFILTRATOR, 8)

# Leaf Guard Enhanced
module LeafGuardEnhanced
  def self.conditions_met?(battler)
    return [:Sun, :HarshSun].include?(battler.effectiveWeather) || battler.battle.field.terrain == :Grassy
  end

  def self.active?(battler); return !battler.fainted? && battler.hasActiveAbility?(:LEAFGUARD) && conditions_met?(battler); end
end

# Miễn nhiễm trạng thái khi có nắng hoặc Grassy Terrain
Battle::AbilityEffects::StatusImmunity.add(:LEAFGUARD, proc { |ability, battler, status| next LeafGuardEnhanced.active?(battler) })

# Giảm 20% sát thương từ chiêu thức
Battle::AbilityEffects::DamageCalcFromTarget.add(:LEAFGUARD, proc { |ability, user, target, move, mults, power, type|
  next if !LeafGuardEnhanced.active?(target)
  mults[:final_damage_multiplier] *= 0.8
})

# AI: Ability rating
KaitoAbilitySupport.rate(:LEAFGUARD, 6)
Battle::AI::Handlers::AbilityRanking.add(:LEAFGUARD, proc { |ability, score, battler, ai|
  next 8 if LeafGuardEnhanced.conditions_met?(battler.battler)
  if battler.has_move_with_function?( "StartSunWeather", "StartGrassyTerrain" )
    next 6
  end
  next 3
})

# Shell Armor - Preserve existing effects, add special damage reduction
shell_armor_previous_handler = Battle::AbilityEffects::DamageCalcFromTarget[:SHELLARMOR]

Battle::AbilityEffects::DamageCalcFromTarget.add(:SHELLARMOR, proc { |ability, user, target, move, mults, power, type|
  if shell_armor_previous_handler
    shell_armor_previous_handler.call( ability, user, target, move, mults, power, type )
  end
  if move.specialMove?
    mults[:final_damage_multiplier] *= 0.85
  end
})

# Battle Armor - Preserve existing effects, add physical damage reduction
battle_armor_previous_handler = Battle::AbilityEffects::DamageCalcFromTarget[:BATTLEARMOR]

Battle::AbilityEffects::DamageCalcFromTarget.add(:BATTLEARMOR, proc { |ability, user, target, move, mults, power, type|
  if battle_armor_previous_handler
    battle_armor_previous_handler.call( ability, user, target, move, mults, power, type )
  end
  if move.physicalMove?
    mults[:final_damage_multiplier] *= 0.85
  end
})

# Florescence
Battle::AbilityEffects::PriorityChange.add(:FLORESCENCE, proc { |ability, battler, move, priority|
  next priority if battler.hp * 2 <= battler.totalhp
  next priority if move.type != :GRASS
  next priority + 1
})

# AI: Ability rating
# AI dùng chung PriorityChange để tính thứ tự hành động.
KaitoAbilitySupport.rate(:FLORESCENCE, 7)
Battle::AI::Handlers::AbilityRanking.add(:FLORESCENCE, proc { |ability, score, battler, ai|
  next 0 if !battler.check_for_move { |move| move.type == :GRASS }
  next 8 if battler.hp * 2 > battler.totalhp
  next 4
})

# Spore Veil - Once per move, not once per hit
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

Battle::AbilityEffects::OnBeingHit.add(:SPOREVEIL, proc { |ability, user, target, move, battle|
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
})

# Wind Rider Enhanced
Battle::AbilityEffects::MoveImmunity.add(:WINDRIDER, proc { |ability, user, target, move, type, battle, show_message|
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
        changed = target.pbRaiseStatStageByAbility( stat, 1, target, false )
        raised = true if changed
      end
      if !raised
        battle.pbDisplay(_INTL( "{1}'s {2} made {3} ineffective!", target.pbThis, ability_name, move.name ))
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
})

# AI: Nhận biết miễn nhiễm Flying/Wind khi đánh giá Pokémon đổi vào.
# Bao gồm Wind Rider là innate.
class Battle::AI
  alias_method :wind_rider_enhanced_original_absorb_move, :pokemon_can_absorb_move?

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
    return wind_rider_enhanced_original_absorb_move( pkmn, move, move_type )
  end
end

# AI: Ability rating
KaitoAbilitySupport.rate(:WINDRIDER, 8)

# Seed Stimulus

# Xóa hiệu ứng cũ kích hoạt theo từng hit.
Battle::AbilityEffects::OnDealingHit.remove(:SEEDSTIMULUS)

Battle::AbilityEffects::OnEndOfUsingMove.add(:SEEDSTIMULUS, proc { |ability, user, targets, move, battle|
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
})

# AI: Ability rating
KaitoAbilitySupport.rate(:SEEDSTIMULUS, 8)
Battle::AI::Handlers::AbilityRanking.add(:SEEDSTIMULUS, proc { |ability, score, battler, ai|
  next 0 if !battler.check_for_move { |move| move.type == :GRASS }
  next 8 if battler.status == :NONE
  next 3
})

# AI: Ưu tiên chiêu Grass khi có thể nhận tăng chỉ số.
Battle::AI::Handlers::GeneralMoveScore.add(:seed_stimulus_boost, proc { |score, move, user, ai, battle|
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
})

# False Front
module FalseFront
  TYPES = [:FIGHTING, :FAIRY, :DARK].freeze

  def self.choose_type(battler, battle)
    if battler.pbOwnedByPlayer?
      commands = TYPES.map { |type| GameData::Type.get(type).name }
      loop do
        choice = battle.pbShowCommands( _INTL("Choose an additional type for {1}.", battler.pbThis(true)), commands, -1 )
        return TYPES[choice] if choice && choice >= 0 && choice < TYPES.length
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

# Reset lựa chọn khi chuẩn bị một lần vào sân mới.
# Bao gồm cả trường hợp Baton Pass.
class Battle::Battler
  attr_accessor :false_front_chosen_type
  alias_method :false_front_original_init_effects, :pbInitEffects

  def pbInitEffects(batonPass)
    false_front_original_init_effects(batonPass)
    @false_front_chosen_type = nil
  end
end

# Chọn và thêm hệ khi vào sân.
# Chặn việc mở lại menu nhiều lần trong cùng một lần ở trên sân.
Battle::AbilityEffects::OnSwitchIn.add(:FALSEFRONT, proc { |ability, battler, battle, switch_in|
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
    battler.effects[PBEffects::ExtraType] = battler.pbTypes.include?(chosen_type) ? nil : chosen_type
    battle.pbDisplay(_INTL( "{1} gained the {2} type!", battler.pbThis, GameData::Type.get(chosen_type).name ))
  ensure
    begin
      battle.pbHideAbilitySplash(battler)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
})

# Xóa hệ do False Front thêm khi rút về.
# Không xóa hệ bổ sung khác nếu nó đã thay thế hệ của False Front.
Battle::AbilityEffects::OnSwitchOut.add(:FALSEFRONT, proc { |ability, battler, end_of_battle|
  chosen_type = battler.false_front_chosen_type
  if chosen_type && battler.effects[PBEffects::ExtraType] == chosen_type
    battler.effects[PBEffects::ExtraType] = nil
  end
  battler.false_front_chosen_type = nil
})

# AI: Ability rating
KaitoAbilitySupport.rate(:FALSEFRONT, 7)

# Thick Fat - Boosts Slam and Body Slam
Battle::AbilityEffects::DamageCalcFromUser.add(:THICKFAT, proc { |ability, user, target, move, mults, power, type|
  next if ![:SLAM, :BODYSLAM].include?(move.id)
  mults[:final_damage_multiplier] *= 1.5
})

# Ball Fetch - Copies opposing ball and bomb moves
module BallFetchEnhanced
  def self.copy_move(battler, source, move, battle)
    return if battler.fainted?
    return if !battler.hasActiveAbility?(:BALLFETCH)
    copied_move = Battle::Move.from_pokemon_move( battle, Pokemon::Move.new(move.id) )

    # Kiểm tra các giới hạn dùng chiêu theo cơ chế gọi chiêu.
    return if !battler.pbCanChooseMove?( copied_move, false, false, true )
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
      battle.pbDisplay(_INTL( "{1} fetched and returned {2}!", battler.pbThis, move.name ))
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

# Ghi nhận Bomb/Ball move khi chiêu được tung ra, trước kiểm tra trúng/trượt.
class Battle::Move
  alias_method :ball_fetch_original_display_use_message, :pbDisplayUseMessage

  def pbDisplayUseMessage(user)
    result = ball_fetch_original_display_use_message(user)
    if bombMove? && !@battle.instance_variable_get(:@ball_fetch_copying)
      fetchers = @battle.pbPriority(true).select do |battler|
        battler.opposes?(user) && !battler.fainted? && battler.hasActiveAbility?(:BALLFETCH)
      end

      # Lưu cả Pokémon để tránh nhầm khi slot đã đổi chủ.
      fetchers = fetchers.map do |battler|
        [battler, battler.pokemon]
      end
      user.instance_variable_set( :@ball_fetch_announced_move, [self, fetchers] )
    end
    return result
  end
end

# Sau khi xử lý xong chiêu gốc, thực hiện các đòn sao chép.
# Không yêu cầu chiêu gốc đánh trúng.
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
          BallFetchEnhanced.copy_move( battler, self, copied_move, @battle )
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

# AI: Ability rating
KaitoAbilitySupport.rate(:BALLFETCH, 6)

# AI: Hạn chế dùng chiêu Bomb/Ball khi đối thủ có thể sao chép.
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
  })

# Dodge - AI ability rating
KaitoAbilitySupport.rate(:DODGE, 6)
Battle::AI::Handlers::AbilityRanking.add(:DODGE, proc { |ability, score, battler, ai| next score })

# Wild Tantrum - AI
module WildTantrumAI
  def self.physical_attacker?(battler); return battler.moves.any? { |m| m.damagingMove? && m.physicalMove? }; end

  # Estimate hit count without calling pbNumHits or consuming battle RNG.
  def self.expected_hits(move, user)
    function = move.function_code
    return 2.0 if function.start_with?("HitTwoTimes")
    return 3.0 if function.start_with?("HitThreeTimes")
    if function.start_with?("HitTwoToFiveTimes")
      if function == "HitTwoToFiveTimesOrThreeForAshGreninja" && user.isSpecies?(:GRENINJA) && user.form == 2
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
    if target.effects[PBEffects::Substitute] > 0 && !move.ignoresSubstitute?(user)
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

# Ability value
Battle::AI::Handlers::AbilityRanking.add(:WILDTANTRUM, proc { |ability, score, battler, ai|
  next 0 if !WildTantrumAI.physical_attacker?(battler.battler)
  next(-3) if battler.has_active_ability?(:CONTRARY)
  next 1 if battler.statStageAtMax?(:ATTACK)
  next 8 if battler.has_active_ability?(:SIMPLE)
  next 6
})

# Remove the generic OnBeingHit penalty for a primary Wild Tantrum.
# Its specific scoring below replaces that penalty.
# Preserve the existing handling of other abilities and items.
wild_tantrum_previous_hit_score = Battle::AI::Handlers::GeneralMoveAgainstTargetScore[ :trigger_target_ability_or_item_upon_hit ]
if wild_tantrum_previous_hit_score
  Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
    :trigger_target_ability_or_item_upon_hit,
    proc { |score, move, user, target, ai, battle|
      score = wild_tantrum_previous_hit_score.call( score, move, user, target, ai, battle )
      if ai.trainer.high_skill? && move.damagingMove? && target.effects[PBEffects::Substitute] == 0 && target.ability_active? &&
         target.battler.ability_id == :WILDTANTRUM
        score += 8
      end
      next score
    })
end

# Essentials AI
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:wild_tantrum, proc { |score, move, user, target, ai, battle|
  next score if !ai.trainer.medium_skill?
  attacker = user.battler
  defender = target.battler
  native_move = move.move
  next score if !WildTantrumAI.relevant?( native_move, attacker, defender )
  score += WildTantrumAI.score_change( native_move, attacker, defender, battle, move.rough_damage )
  next score
})

# Advanced AI - uses a separate scoring pipeline.
if defined?(AdvancedAI) && Battle::AI.method_defined?(:score_move_advanced)
  class Battle::AI
    alias_method :wild_tantrum_original_advanced_score, :score_move_advanced

    def score_move_advanced(move, user, target, skill)
      score = wild_tantrum_original_advanced_score( move, user, target, skill )
      return score if score <= 0
      attacker = user.respond_to?(:battler) ? user.battler : user
      defender = target.respond_to?(:battler) ? target.battler : target
      native_move = move.respond_to?(:move) ? move.move : move
      return score if !WildTantrumAI.relevant?( native_move, attacker, defender )
      damage = AdvancedAI::CombatUtilities.estimate_damage( attacker, native_move, defender )
      return score + WildTantrumAI.score_change( native_move, attacker, defender, @battle, damage )
    end
  end
end

# Added types retain their benefits without adding weaknesses.
# Uses the same damage-compensation approach as Aquatic.
{
  :HALFDRAKE => { :type       => :DRAGON, :weaknesses => [:ICE, :DRAGON, :FAIRY] },
  :BUGBOUND => { :type       => :BUG, :weaknesses => [:FIRE, :FLYING, :ROCK] },
  :FIERYSPIRIT => { :type       => :FIRE, :weaknesses => [:WATER, :GROUND, :ROCK] }
}.each do |ability_id, data|
  Battle::AbilityEffects::DamageCalcFromTarget.add(ability_id, proc { |ability, user, target, move, mults, power, type|
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
    })
end

# Half Drake / Bugbound / Fiery Spirit - AI
module AddedTypeGuardAI
  DATA = {
    :HALFDRAKE   => [:DRAGON, [:ICE, :DRAGON, :FAIRY]],
    :BUGBOUND    => [:BUG,    [:FIRE, :FLYING, :ROCK]],
	:AQUATIC     => [:WATER,  [:ELECTRIC, :GRASS]],
    :FIERYSPIRIT => [:FIRE,   [:WATER, :GROUND, :ROCK]]
  }

  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

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

# Essentials AI - ability ranking
AddedTypeGuardAI::DATA.each do |ability_id, data|
  Battle::AI::Handlers::AbilityRanking.add(ability_id, proc { |ability, score, battler, ai|
      added_type, weaknesses = data
      real = battler.battler
      base_types = real.pbTypes(false)

      # No benefit if the Pokémon already has this type naturally/currently.
      next 0 if base_types.include?(added_type)
      next 0 if real.respond_to?(:tera?) && real.tera?

      # Additional typing without its added weaknesses.
      value = 7

      # Offensive value: an additional STAB.
      if battler.check_for_move { |m| m.damagingMove? && m.type == added_type }
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
          after  = Effectiveness.calculate( m.type, *(base_types + [added_type]).uniq )
          next after < before
        end
        defensive_value += 1 if useful_resistance
      end
      value += [defensive_value, 2].min
      next value
    })
end

# Advanced AI - shared damage estimator
if defined?(AdvancedAI::CombatUtilities)
  module AddedTypeGuardAdvancedModifier
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      result = super
      return result * AddedTypeGuardAI.damage_factor( attacker, target, move, type )
    end
  end
  AdvancedAI::CombatUtilities.singleton_class.prepend( AddedTypeGuardAdvancedModifier )
end

# Advanced AI - separate rough damage calculation
if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage)
  module AddedTypeGuardAdvancedDamage
    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = super
      return result if result <= 0
      native_move = move.respond_to?(:move) ? move.move : move

      # Fixed damage and OHKO moves don't use damage multipliers.
      return result if native_move.is_a?(Battle::Move::FixedDamageMove)
      return result if native_move.function_code.start_with?("OHKO")
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      factor = AddedTypeGuardAI.damage_factor( user, target, native_move, type )
      return result if factor == 1.0
      return [(result * factor).to_i, 1].max
    end
  end
  Battle::AI.prepend(AddedTypeGuardAdvancedDamage)
end

# Pack Leader - effect and AI
module PackLeader
  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

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

# Battle effect
Battle::AbilityEffects::DamageCalcFromUser.add(:PACKLEADER, proc { |ability, user, target, move, mults, power, type|
  next if !PackLeader.team_ready?(user)
  mults[:attack_multiplier] *= 1.3
})

Battle::AbilityEffects::OnSwitchIn.add(:PACKLEADER, proc { |ability, battler, battle, switch_in|
  next if !PackLeader.team_ready?(battler)
  PackLeader.show_message(battler, battle)
})

# Essentials AI
# Native damage prediction already uses DamageCalcFromUser.
KaitoAbilitySupport.rate(:PACKLEADER, 6)
Battle::AI::Handlers::AbilityRanking.add(:PACKLEADER, proc { |ability, score, battler, ai|
  next 0 if !PackLeader.team_ready?(battler)
  next 0 if !battler.check_for_move { |m| m.damagingMove? }
  next 9
})

# Advanced AI - shared damage estimator
if defined?(AdvancedAI::CombatUtilities)
  module PackLeaderAdvancedModifier
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      result = super
      result *= 1.3 if PackLeader.active?(attacker)
      return result
    end
  end
  AdvancedAI::CombatUtilities.singleton_class.prepend( PackLeaderAdvancedModifier )
end

# Advanced AI - separate rough damage calculation
if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage)
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

# Pack Leader - only works during the Pokémon's first appearance per battle.
class Battle
  def pack_leader_entry_counts
    @pack_leader_entry_counts ||= {}
    return @pack_leader_entry_counts
  end
end

# Track actual entries, including entries made while the ability is suppressed.
module PackLeaderFirstEntryTracking
  def pbInitialize(pkmn, idxParty, batonPass = false)
    # Reset Stalk whenever this battler initializes a Pokemon.
    @stealth_vanished = false
    result = super

    # Only track real battle entries, excluding temporary AI battlers.
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

# Tenacity
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
      battle.pbDisplay(_INTL("{1} held on with {2}!", target.pbThis, name))
      battle.pbHideAbilitySplash(target)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
end

# Battle effect
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

# AI helpers
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
    if defender.effects[PBEffects::Substitute] > 0 && !native.ignoresSubstitute?(attacker)
      return 0
    end
    if defined?(AdvancedAI::Utilities)
      return 0 if AdvancedAI::Utilities.ignores_ability?( attacker, native, defender )
    else
      return 0 if battle.moldBreaker
    end

    # A predicted KO is less reliable. Multi-hit attacks can finish
    # the target after an earlier hit activates Tenacity.
    return native.multiHitMove? ? -1 : -3
  end
end

# Essentials AI
KaitoAbilitySupport.rate(:TENACITY, 7)
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:tenacity, proc { |score, move, user, target, ai, battle|
  next score if !ai.trainer.medium_skill?
  next score if !move.damagingMove?
  next score if !target.has_active_ability?(:TENACITY)
  score += TenacityAI.score_change( user, target, move, battle, move.rough_damage )
  next score
})

# Advanced AI
if defined?(AdvancedAI::CombatUtilities) && Battle::AI.method_defined?(:score_move_advanced)
  module TenacityAdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= 0 || !user || !target
      attacker = user.respond_to?(:battler) ? user.battler : user
      defender = target.respond_to?(:battler) ? target.battler : target
      native = move.respond_to?(:move) ? move.move : move
      return score if !native.damagingMove?
      return score if !defender.hasActiveAbility?(:TENACITY)
      damage = AdvancedAI::CombatUtilities.estimate_damage( attacker, native, defender )
      return score + TenacityAI.score_change( attacker, defender, native, @battle, damage )
    end
  end
  Battle::AI.prepend(TenacityAdvancedScoring)
end

# Water Veil - protect allies from Fire-type damage
Battle::AbilityEffects::DamageCalcFromTargetAlly.add(:WATERVEIL, proc { |ability, user, target, move, mults, power, type|
  next if type != :FIRE
  mults[:final_damage_multiplier] *= 0.75
})

# AI
module WaterVeilAI
  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

  def self.fire_damage_factor(attacker, target, move, type)
    return 1.0 if type != :FIRE
    attacker = real_battler(attacker)
    target   = real_battler(target)
    return 1.0 if !attacker || !target
    return 1.0 if !target.respond_to?(:allAllies)
    return 1.0 if AdvancedAI::Utilities.ignores_ability?( attacker, move, target )
    protectors = [target] + target.allAllies.to_a
    count = protectors.count do |b|
      !b.fainted? && b.hasActiveAbility?(:WATERVEIL)
    end
    return 0.75 ** count
  end
end

# Essentials AI
# Damage handlers and Aqua Ring healing are already predicted natively.
Battle::AI::Handlers::AbilityRanking.add(:WATERVEIL, proc { |ability, score, battler, ai|
  value = 7
  value += 1 if battler.battler.allAllies.any? { |b| !b.fainted? }
  fire_threat = battler.battler.allOpposing.any? do |foe|
    foe.moves.any? { |m| m.damagingMove? && m.type == :FIRE }
  end
  value += 1 if fire_threat
  next value
})

# Advanced AI - shared damage estimator
if defined?(AdvancedAI::CombatUtilities)
  module WaterVeilAdvancedModifier
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      result = super
      return result * WaterVeilAI.fire_damage_factor( attacker, target, move, type )
    end
  end
  AdvancedAI::CombatUtilities.singleton_class.prepend( WaterVeilAdvancedModifier )
end

# Advanced AI - separate rough damage calculation
if defined?(AdvancedAI::CombatUtilities) && Battle::AI.method_defined?(:calculate_rough_damage)
  module WaterVeilAdvancedDamage
    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = super
      return result if result <= 0
      native = move.respond_to?(:move) ? move.move : move
      return result if native.is_a?(Battle::Move::FixedDamageMove)
      return result if native.function_code.start_with?("OHKO")
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      factor = WaterVeilAI.fire_damage_factor( user, target, native, type )
      return result if factor == 1.0
      return [(result * factor).to_i, 1].max
    end
  end
  Battle::AI.prepend(WaterVeilAdvancedDamage)
end

# Pierce Armor - corrected effect
module PierceArmorAI
  def self.eligible_move?(move)
    native = move.respond_to?(:move) ? move.move : move
    return native.damagingMove? && (native.hornMove? || native.drillMove?)
  end
end

Battle::AbilityEffects::OnDealingHit.add(:PIERCEARMOR, proc { |ability, user, target, move, battle|
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
})

# Pierce Armor - AI
module PierceArmorAI
  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

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
    if target.effects[PBEffects::Substitute] > 0 && !native.ignoresSubstitute?(user)
      return 0
    end
    old_mold_breaker = battle.moldBreaker
    begin
      if defined?(AdvancedAI::Utilities)
        battle.moldBreaker = AdvancedAI::Utilities.ignores_ability?( user, native, target )
      end
      return 0 if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
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

# Ability ranking
KaitoAbilitySupport.rate(:PIERCEARMOR, 7)
Battle::AI::Handlers::AbilityRanking.add(:PIERCEARMOR, proc { |ability, score, battler, ai|
useful = battler.check_for_move do |m|
  PierceArmorAI.eligible_move?(m)
end
  next 0 if !useful
  next 8 if battler.check_for_move { |m| m.damagingMove? && m.physicalMove? }
  next 5
})

# Essentials AI
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:pierce_armor, proc { |score, move, user, target, ai, battle|
  next score if !ai.trainer.medium_skill?
  next score if !user.has_active_ability?(:PIERCEARMOR)
  next score if !move.damagingMove?
  next score if !PierceArmorAI.eligible_move?(move)
  score += PierceArmorAI.score_change( user, target, move, battle, move.rough_damage )
  next score
})

# Advanced AI
if defined?(AdvancedAI::CombatUtilities) && Battle::AI.method_defined?(:score_move_advanced)
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
      damage = AdvancedAI::CombatUtilities.estimate_damage( attacker, native, defender )
      return score + PierceArmorAI.score_change( attacker, defender, native, @battle, damage )
    end
  end
  Battle::AI.prepend(PierceArmorAdvancedScoring)
end

# Kamen Rider
module KamenRider
  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

  def self.ready?(value)
    battler = real_battler(value)
    return false if !battler || battler.fainted?
    battle = battler.battle
    previous_round = battle.turnCount - 1
    records = battle.kamen_rider_faints[previous_round] || []
    return records.any? do |side, pokemon| side == battler.idxOwnSide && !pokemon.equal?(battler.pokemon) end
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
# Kamen Rider - faint tracking compatible with M.A.G
class Battle::Battler
  unless method_defined?(:kamen_rider_original_pbFaint)
    alias_method :kamen_rider_original_pbFaint, :pbFaint
  end

  def pbFaint(showMessage = true)
    if fainted? && !@fainted && @pokemon
      history = @battle.kamen_rider_faints
      round   = @battle.turnCount
      history[round] ||= []
      record = [idxOwnSide, @pokemon]
      unless history[round].include?(record)
        history[round] << record
      end
    end
    return kamen_rider_original_pbFaint(showMessage)
  end
end

Battle::AbilityEffects::DamageCalcFromUser.add(:KAMENRIDER, proc { |ability, user, target, move, mults, power, type|
  next if !move.damagingMove?
  next if !KamenRider.ready?(user)
  mults[:final_damage_multiplier] *= 1.5
})

# Essentials AI
# Native damage prediction uses the ability's damage handler.
KaitoAbilitySupport.rate(:KAMENRIDER, 6)
Battle::AI::Handlers::AbilityRanking.add(:KAMENRIDER, proc { |ability, score, battler, ai|
  next 0 if !battler.check_for_move { |m| m.damagingMove? }
  next KamenRider.ready?(battler) ? 9 : 4
})

# Advanced AI - shared damage estimator
if defined?(AdvancedAI::CombatUtilities)
  module KamenRiderAdvancedModifier
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      result = super
      result *= 1.5 if KamenRider.active?(attacker)
      return result
    end
  end
  AdvancedAI::CombatUtilities.singleton_class.prepend( KamenRiderAdvancedModifier )
end

# Advanced AI - separate rough damage calculation
if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage)
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

# Showdown Mode
module ShowdownModePlus
  STATS = [ :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED ]

  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

  def self.running?(value)
    b = real_battler(value)
    return b && !b.fainted? && b.hasActiveAbility?(:SHOWDOWNMODE) && b.effects[PBEffects::ShowdownMode] == true
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
    if target.effects[PBEffects::Substitute] > 0 && !native.ignoresSubstitute?(user)
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

# Reset on entry, including Baton Pass.
# Showdown Mode - reset compatible with Community Abilities
class Battle::Battler
  alias_method :showdown_mode_original_init_effects, :pbInitEffects

  def pbInitEffects(batonPass)
    showdown_mode_original_init_effects(batonPass)
    @effects[PBEffects::ShowdownMode] = false
    @showdown_mode_eor_round = nil
  end
end

# Activate once per stay on the field.
Battle::AbilityEffects::AfterMoveUseFromTarget.add(:SHOWDOWNMODE, proc { |ability, target, user, move, switched_battlers, battle|
  next if target.fainted?
  next if !move.damagingMove?
  next if target.damageState.substitute
  next if !target.droppedBelowHalfHP
  next if target.effects[PBEffects::ShowdownMode] == true
  next if !ShowdownModePlus::STATS.any? { |stat| target.pbCanRaiseStatStage?(stat, target) }
  target.effects[PBEffects::ShowdownMode] = true
ShowdownModePlus.with_splash(target, battle) do
  show_animation = true
  ShowdownModePlus::STATS.each do |stat|
  next if !target.pbCanRaiseStatStage?(stat, target)
  changed = target.pbRaiseStatStage( stat, 1, target, show_animation )
  show_animation = false if changed
  end
end
})

# Only damage this ability's owner, at most once each round.
Battle::AbilityEffects::EndOfRoundEffect.add(:SHOWDOWNMODE, proc { |ability, battler, battle|
  loss = ShowdownModePlus.hp_loss(battler)
  next if loss <= 0
  previous_round = battler.instance_variable_get( :@showdown_mode_eor_round )
  next if previous_round == battle.turnCount
  battler.instance_variable_set( :@showdown_mode_eor_round, battle.turnCount )
  ShowdownModePlus.with_splash(battler, battle) do
    battle.pbDisplay(_INTL("{1} is losing health from Showdown Mode!", battler.pbThis))
    battler.pbReduceHP(loss)
  end
  battler.pbItemHPHealCheck
})

# Essentials AI
KaitoAbilitySupport.rate(:SHOWDOWNMODE, 8)
Battle::AI::Handlers::AbilityRanking.add(:SHOWDOWNMODE, proc { |ability, score, battler, ai|
  next(-4) if battler.has_active_ability?(:CONTRARY)
  next 0 if battler.effects[PBEffects::ShowdownMode] == true
  next 10 if battler.has_active_ability?(:SIMPLE)
  next battler.hp * 2 > battler.totalhp ? 8 : 3
})

# Predict the continuing HP cost.
module ShowdownModeEndOfRoundAI
  def rough_end_of_round_damage
    damage = super
    return damage if damage >= 999_999
    return damage + ShowdownModePlus.hp_loss(battler)
  end
end
Battle::AI::AIBattler.prepend(ShowdownModeEndOfRoundAI)
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:showdown_mode, proc { |score, move, user, target, ai, battle|
  next score if !ai.trainer.medium_skill?
  next score if !move.damagingMove?
  next score if !target.has_active_ability?(:SHOWDOWNMODE)
  score += ShowdownModePlus.score_change( user, target, move, move.rough_damage, battle )
  next score
})

# Advanced AI - activation scoring
if defined?(AdvancedAI::CombatUtilities) && Battle::AI.method_defined?(:score_move_advanced)
  module ShowdownModeAdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= 0 || !user || !target
      attacker = ShowdownModePlus.real_battler(user)
      defender = ShowdownModePlus.real_battler(target)
      native = move.respond_to?(:move) ? move.move : move
      return score if !native.damagingMove?
      return score if !defender.hasActiveAbility?(:SHOWDOWNMODE)
      damage = AdvancedAI::CombatUtilities.estimate_damage( attacker, native, defender )
      return score + ShowdownModePlus.score_change( attacker, defender, native, damage, @battle )
    end
  end
  Battle::AI.prepend(ShowdownModeAdvancedScoring)
end

# Subjugate
# Moves that lower an opponent's stats raise the user's matching stats
# by the number of stages actually lowered.
module Subjugate
  class << self
    attr_accessor :move_user, :non_move_depth
  end

  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

  def self.move_source?(user); return user && move_user.equal?(user) && (non_move_depth || 0) == 0; end

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

# Track the move's user and actual stat reductions.
# Subjugate - stat reduction tracking
# Compatible with Community Abilities alias hooks.
class Battle::Battler
  unless method_defined?(:subjugate_original_pbUseMove)
    alias_method :subjugate_original_pbUseMove, :pbUseMove
    alias_method :subjugate_original_pbLowerStatStage, :pbLowerStatStage
    alias_method :subjugate_original_pbLowerStatStageByCause, :pbLowerStatStageByCause
    alias_method :subjugate_original_pbLowerStatStageBasic, :pbLowerStatStageBasic
  end

  def pbUseMove(choice, specialUsage = false)
    old_user  = Subjugate.move_user
    old_depth = Subjugate.non_move_depth
    begin
      Subjugate.move_user = self
      Subjugate.non_move_depth = 0
      return subjugate_original_pbUseMove(choice, specialUsage)
    ensure
      Subjugate.move_user = old_user
      Subjugate.non_move_depth = old_depth
    end
  end

  def subjugate_track_drop(user)
    @subjugate_frames ||= []
    frame = { :changes  => [], :captured => false, :eligible => Subjugate.move_source?(user) }
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
    return subjugate_track_drop(user) do subjugate_original_pbLowerStatStage( stat, increment, user, *args ) end
  end

  def pbLowerStatStageByCause(stat, increment, user, cause, *args)
    return subjugate_track_drop(user) do subjugate_original_pbLowerStatStageByCause( stat, increment, user, cause, *args ) end
  end

  def pbLowerStatStageBasic(stat, increment, ignoreContrary = false)
    frame = @subjugate_frames && @subjugate_frames.last
    capture = frame && !frame[:captured]
    frame[:captured] = true if capture
    before = @stages[stat]
    result = subjugate_original_pbLowerStatStageBasic( stat, increment, ignoreContrary )
    reduction = before - @stages[stat]
    if capture && reduction > 0
      frame[:changes].push([stat, reduction])
    end
    return result
  end
end

# Exclude Ability/item effects, including those triggered during a move.
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

# AI
module SubjugateAI
  def self.stat_lowering_move?(move)
    return move.is_a?(Battle::Move::TargetStatDownMove) || move.is_a?(Battle::Move::TargetMultiStatDownMove)
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
        battle.moldBreaker = AdvancedAI::Utilities.ignores_ability?( user, native, target )
      end
      unless battle.moldBreaker
        return 0 if target.hasActiveAbility?([:CONTRARY, :MIRRORARMOR])
      end
      chance = 100
      if native.damagingMove?
        return 0 if user.hasActiveAbility?(:SHEERFORCE) && native.addlEffect > 0
        return 0 if target.hasActiveItem?(:COVERTCLOAK)
        return 0 if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
        chance = [native.addlEffect, 100].min
        return 0 if chance <= 0
        if user.hasActiveAbility?(:SERENEGRACE) || user.pbOwnSide.effects[PBEffects::Rainbow] > 0
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
          gain *= 2 if user.hasActiveAbility?(:SIMPLE) && !battle.moldBreaker
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

# Ability ranking
KaitoAbilitySupport.rate(:SUBJUGATE, 7)
Battle::AI::Handlers::AbilityRanking.add(:SUBJUGATE, proc { |ability, score, battler, ai|
  useful = battler.check_for_move do |move|
    SubjugateAI.stat_lowering_move?(move)
  end
  next 0 if !useful
  next(-3) if battler.has_active_ability?(:CONTRARY)
  next 9 if battler.has_active_ability?(:SIMPLE)
  next 7
})

# Essentials AI - augment existing stat-drop scoring.
module SubjugateNativeScoring
  def get_score_for_target_stat_drop(score, target, stat_changes, *args)
    result = super
    return result if result == Battle::AI::MOVE_USELESS_SCORE
    return result if !@user || !@move
    return result + SubjugateAI.bonus( @user, target, @move.move, stat_changes, @battle )
  end
end
Battle::AI.prepend(SubjugateNativeScoring)

# Advanced AI - standard target stat-lowering moves.
if defined?(AdvancedAI) && Battle::AI.method_defined?(:score_move_advanced)
  module SubjugateAdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= 0 || !user || !target
      native = move.respond_to?(:move) ? move.move : move
      return score if !SubjugateAI.stat_lowering_move?(native)
      return score + SubjugateAI.bonus( user, target, native, native.statDown, @battle )
    end
  end
  Battle::AI.prepend(SubjugateAdvancedScoring)
end

# Early Bird - +2 move priority on the waking turn
module EarlyBirdWake
  def self.ready?(value)
    battler = value.respond_to?(:battler) ? value.battler : value
    return false if !battler || battler.fainted?
    return false if !battler.hasActiveAbility?(:EARLYBIRD)

    # Priority is calculated before the sleep counter is reduced.
    # A counter of 1 means the Pokémon will wake when attempting its move.
    if battler.status == :SLEEP
      return battler.statusCount <= 1
    end

    # Already woke/cured earlier during this same round.
    record = battler.instance_variable_get(:@early_bird_wake_record)
    return record == [ battler.battle.turnCount, battler.pokemon.object_id ]
  end
end

# Remember when sleep is cured.
# Use an alias to remain compatible with the existing plugin alias chains.
class Battle::Battler
  alias_method :early_bird_original_cure_status, :pbCureStatus

  def pbCureStatus(showMessages = true)
    was_asleep = (@status == :SLEEP)
    result = early_bird_original_cure_status(showMessages)
    if was_asleep && @status != :SLEEP && @pokemon
      @early_bird_wake_record = [ @battle.turnCount, @pokemon.object_id ]
    end
    return result
  end
end

# Actual priority and Essentials AI prediction.
Battle::AbilityEffects::PriorityChange.add(:EARLYBIRD, proc { |ability, battler, move, priority|
  next priority if !EarlyBirdWake.ready?(battler)
  next priority + 2
})

# Ability ranking.
Battle::AI::Handlers::AbilityRanking.add(:EARLYBIRD, proc { |ability, score, battler, ai|
  next 8 if EarlyBirdWake.ready?(battler)
  has_rest = battler.check_for_move { |m| m.id == :REST }
  next has_rest ? 7 : 5
})

# Advanced AI has a separate priority utility.
# Its PriorityTiers helper already calls the engine's priority handlers.
if defined?(AdvancedAI::Utilities)
  module EarlyBirdAdvancedPriority
    def effective_priority(user, move, battle = nil)
      priority = super
      return priority if !move
      return priority + (EarlyBirdWake.ready?(user) ? 2 : 0)
    end
  end
  AdvancedAI::Utilities.singleton_class.prepend( EarlyBirdAdvancedPriority )
end

# Cat's Luck
module CatsLuck
  STATS = [ :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED, :ACCURACY, :EVASION ]

  def self.available_stats(battler); return STATS.select do |stat| battler.pbCanRaiseStatStage?(stat, battler) end; end

  def self.activate(user, battle)
    stats = available_stats(user)
    return if stats.empty?
    stat = stats[battle.pbRandom(stats.length)]
    old_name  = $aamName
    old_name2 = $aamName2
    begin
      name = GameData::Ability.get(:CATSLUCK).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(user)
      user.pbRaiseStatStageByAbility(stat, 1, user, false)
      battle.pbHideAbilitySplash(user)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end
end

Battle::AbilityEffects::OnDealingHit.add(:CATSLUCK, proc { |ability, user, target, move, battle|
  next if user.fainted?
  next if !move.damagingMove?
  next if !target.damageState.critical
  next if target.damageState.substitute
  next if target.damageState.disguise || target.damageState.iceFace
  CatsLuck.activate(user, battle)
})

# AI helpers - estimate critical-hit chance without rolling RNG.
module CatsLuckAI
  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

  def self.critical_chance(user, target, move, battle)
    return 0.0 if target.pbOwnSide.effects[PBEffects::LuckyChant] > 0
    ignored = battle.moldBreaker
    if defined?(AdvancedAI::Utilities)
      ignored = AdvancedAI::Utilities.ignores_ability?( user, move, target )
    end
    stage = 0
    if user.abilityActive?
      stage = Battle::AbilityEffects.triggerCriticalCalcFromUser( user.ability, user, target, stage )
    end
    return 0.0 if stage < 0
    if target.abilityActive? && !ignored
      stage = Battle::AbilityEffects.triggerCriticalCalcFromTarget( target.ability, user, target, stage )
    end
    return 0.0 if stage < 0
    if user.itemActive?
      stage = Battle::ItemEffects.triggerCriticalCalcFromUser( user.item, user, target, stage )
    end
    return 0.0 if stage < 0
    if target.itemActive?
      stage = Battle::ItemEffects.triggerCriticalCalcFromTarget( target.item, user, target, stage )
    end
    return 0.0 if stage < 0
    override = move.pbCritialOverride(user, target)
    return 0.0 if override == -1
    return 1.0 if override == 1 || stage > 50
    return 1.0 if user.effects[PBEffects::LaserFocus] > 0
    stage += 1 if move.highCriticalRate?
    stage += user.effects[PBEffects::FocusEnergy]
    stage += 1 if user.inHyperMode? && move.type == :SHADOW
    ratios = Battle::Move::CRITICAL_HIT_RATIOS
    stage = [[stage, 0].max, ratios.length - 1].min
    return 1.0 / ratios[stage]
  end

  def self.bonus(user, target, move, battle)
    user   = real_battler(user)
    target = real_battler(target)
    native = move.respond_to?(:move) ? move.move : move
    return 0 if !user || !target
    return 0 if !user.opposes?(target)
    return 0 if !user.hasActiveAbility?(:CATSLUCK)
    return 0 if !native.damagingMove?
    return 0 if native.is_a?(Battle::Move::FixedDamageMove)
    return 0 if CatsLuck.available_stats(user).empty?
    if target.effects[PBEffects::Substitute] > 0 && !native.ignoresSubstitute?(user)
      return 0
    end
    chance = critical_chance(user, target, native, battle)
    return 0 if chance <= 0
    hits = native.multiHitMove? ? 3.0 : 1.0
    if defined?(AdvancedAI::CombatUtilities)
      hits = AdvancedAI::CombatUtilities.expected_hit_multiplier( native, user )
    end
    value = [(10 * chance * hits).round, 20].min
    value *= 2 if user.hasActiveAbility?(:SIMPLE)
    value = -value if user.hasActiveAbility?(:CONTRARY)
    return value
  end
end

# Ability ranking
KaitoAbilitySupport.rate(:CATSLUCK, 7)
Battle::AI::Handlers::AbilityRanking.add(:CATSLUCK, proc { |ability, score, battler, ai|
  next 0 if CatsLuck.available_stats(battler.battler).empty?
  next 0 if !battler.check_for_move { |m| m.damagingMove? }
  next(-3) if battler.has_active_ability?(:CONTRARY)
  next 9 if battler.has_active_ability?(:SIMPLE)
  next 8 if battler.has_active_ability?(:SUPERLUCK)
  next 7
})

# Essentials AI
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:cats_luck, proc { |score, move, user, target, ai, battle|
  next score if !ai.trainer.medium_skill?
  next score + CatsLuckAI.bonus(user, target, move, battle)
})

# Advanced AI
# Use an alias rather than prepending the scoring method.
if defined?(AdvancedAI) && Battle::AI.method_defined?(:score_move_advanced)
  class Battle::AI
    alias_method :cats_luck_original_advanced_score, :score_move_advanced

    def score_move_advanced(move, user, target, skill)
      score = cats_luck_original_advanced_score( move, user, target, skill )
      return score if score <= 0
      return score + CatsLuckAI.bonus( user, target, move, @battle )
    end
  end
end

# Great Wisdom - doubles Special Attack
Battle::AbilityEffects::DamageCalcFromUser.add(:GREATWISDOM, proc { |ability, user, target, move, mults, power, type|
  next if !move.specialMove?
  mults[:attack_multiplier] *= 2.0
})

# Essentials AI
# Native damage prediction uses the same damage handler.
KaitoAbilitySupport.rate(:GREATWISDOM, 9)
Battle::AI::Handlers::AbilityRanking.add(:GREATWISDOM, proc { |ability, score, battler, ai|
  useful = battler.check_for_move do |move|
    move.damagingMove? && move.specialMove? && !move.is_a?(Battle::Move::FixedDamageMove)
  end
  next useful ? 9 : 0
})

# Advanced AI - shared damage estimator
if defined?(AdvancedAI::CombatUtilities)
  class << AdvancedAI::CombatUtilities
    alias_method :great_wisdom_original_ability_modifier, :ability_damage_modifier

    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      result = great_wisdom_original_ability_modifier( attacker, target, type, physical, effectiveness, move, physical_defense )
      user = attacker.respond_to?(:battler) ? attacker.battler : attacker
      return result if !user || physical
      return result if !user.respond_to?(:hasActiveAbility?)
      result *= 2.0 if user.hasActiveAbility?(:GREATWISDOM)
      return result
    end
  end
end

# Advanced AI - separate rough damage calculation
if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage)
  class Battle::AI
    alias_method :great_wisdom_original_rough_damage, :calculate_rough_damage

    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = great_wisdom_original_rough_damage( move, user, target, override_bp )
      return result if result <= 0
      attacker = user.respond_to?(:battler) ? user.battler : user
      native = move.respond_to?(:move) ? move.move : move
      return result if !attacker
      return result if !attacker.hasActiveAbility?(:GREATWISDOM)
      return result if !native.specialMove?
      return result if native.is_a?(Battle::Move::FixedDamageMove)
      return result if native.function_code.start_with?("OHKO")
      return (result * 2.0).to_i
    end
  end
end

# Perfectionist
module Perfectionist
  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

  def self.bonus(move)
    native = move.respond_to?(:move) ? move.move : move
    return 0 if !native || !native.damagingMove?
    return 0 if native.is_a?(Battle::Move::FixedDamageMove)
    return 0 if native.function_code.start_with?("OHKO")
    power = native.power
    # Power 0/1 is commonly used as a placeholder for special formulas.
    return 0 if power <= 1
    return 2 if power < 26
    return 1 if power < 51
    return 0
  end

  # Temporarily add critical stages while the engine performs its normal
  # critical-hit calculation. Always restore the original effect afterward.
  def self.with_bonus(value, move)
    user = real_battler(value)
    extra = user && user.hasActiveAbility?(:PERFECTIONIST) ? bonus(move) : 0
    return yield if extra == 0
    original = user.effects[PBEffects::FocusEnergy]
    begin
      user.effects[PBEffects::FocusEnergy] = original + extra
      return yield
    ensure
      user.effects[PBEffects::FocusEnergy] = original
    end
  end

  def self.ai_bonus(user, target, move)
    user   = real_battler(user)
    target = real_battler(target)
    native = move.respond_to?(:move) ? move.move : move
    return 0 if !user || !target || !user.opposes?(target)
    return 0 if !user.hasActiveAbility?(:PERFECTIONIST)
    extra = bonus(native)
    return 0 if extra == 0
    return 0 if target.pbOwnSide.effects[PBEffects::LuckyChant] > 0
    ignored = user.battle.moldBreaker
    if defined?(AdvancedAI::Utilities)
      ignored = AdvancedAI::Utilities.ignores_ability?( user, native, target )
    end
    return 0 if !ignored && target.hasActiveAbility?([:BATTLEARMOR, :SHELLARMOR])
    override = native.pbCritialOverride(user, target)
    return 0 if override != 0
    return 0 if user.effects[PBEffects::LaserFocus] > 0
    return extra * 3
  end
end

# Battle effect - preserve the existing critical-hit calculation.
class Battle::Move
  alias_method :perfectionist_original_is_critical, :pbIsCritical?

  def pbIsCritical?(user, target); return Perfectionist.with_bonus(user, self) do perfectionist_original_is_critical(user, target) end; end
end

# Essentials AI - predict the correct critical-hit stage.
class Battle::AI::AIMove
  alias_method :perfectionist_original_critical_stage, :rough_critical_hit_stage

  def rough_critical_hit_stage; return Perfectionist.with_bonus(@ai.user, @move) do perfectionist_original_critical_stage end; end
end
KaitoAbilitySupport.rate(:PERFECTIONIST, 7)
Battle::AI::Handlers::AbilityRanking.add(:PERFECTIONIST, proc { |ability, score, battler, ai|
  best = battler.moves.map { |m| Perfectionist.bonus(m) }.max || 0
  next 0 if best == 0
  next best == 2 ? 8 : 7
})
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:perfectionist, proc { |score, move, user, target, ai, battle|
  next score if !ai.trainer.medium_skill?
  next score + Perfectionist.ai_bonus(user, target, move)
})

# Advanced AI - additional move preference.
if defined?(AdvancedAI) && Battle::AI.method_defined?(:score_move_advanced)
  class Battle::AI
    alias_method :perfectionist_original_advanced_score, :score_move_advanced

    def score_move_advanced(move, user, target, skill)
      score = perfectionist_original_advanced_score( move, user, target, skill )
      return score if score <= 0
      return score + Perfectionist.ai_bonus(user, target, move)
    end
  end
end

# Keep Cat's Luck's custom critical-chance prediction compatible.
if defined?(CatsLuckAI) && CatsLuckAI.respond_to?(:critical_chance)
  class << CatsLuckAI
    alias_method :perfectionist_original_critical_chance, :critical_chance

    def critical_chance(user, target, move, battle)
      return Perfectionist.with_bonus(user, move) do perfectionist_original_critical_chance(user, target, move, battle) end
    end
  end
end

# Nine Lives
module NineLives
  CHANCE = 15

  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

  def self.priority_active?(value)
    b = real_battler(value)
    return false if !b || b.fainted?
    return b.hasActiveAbility?(:NINELIVES) && b.hp * 4 < b.totalhp
  end

  def self.roll?(battler, ignore_fainted = false)
    return false if !battler.hasActiveAbility?(:NINELIVES, ignore_fainted)
    return battler.battle.pbRandom(100) < CHANCE
  end

  def self.show_message(battler)
    battle = battler.battle
    old_name  = $aamName
    old_name2 = $aamName2
    begin
      name = GameData::Ability.get(:NINELIVES).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("{1} held on with {2}!", battler.pbThis, name))
      battle.pbHideAbilitySplash(battler)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end

  def self.ai_survival_adjustment(user, target, move, damage)
    target = real_battler(target)
    user   = real_battler(user)
    native = move.respond_to?(:move) ? move.move : move
    return 0 if !user || !target
    return 0 if !user.opposes?(target)
    return 0 if !native.damagingMove?
    return 0 if !target.hasActiveAbility?(:NINELIVES)
    return 0 if damage < target.hp
    if target.effects[PBEffects::Substitute] > 0 && !native.ignoresSubstitute?(user)
      return 0
    end
    return native.multiHitMove? ? -1 : -2
  end
end

# Survival against lethal HP loss.
class Battle::Battler
  alias_method :nine_lives_original_reduce_hp, :pbReduceHP

  def pbReduceHP(amt, anim = true, registerDamage = true, anyAnim = true)
    @nine_lives_lethal_checked = false
    amount = amt.round
    saved = false
    if hp > 0 && amount >= hp
      # Prevent a second roll in pbFaint after a failed survival attempt.
      @nine_lives_lethal_checked = true
      if NineLives.roll?(self)
        amount = hp - 1
        saved = true

        # Keep direct move-damage bookkeeping accurate.
        if @nine_lives_direct_hp_damage
          state = damageState
          difference = state.hpLost - amount
          state.hpLost = amount
          state.totalHPLost -= difference
        end
      end
    end

    # The engine normally forces a minimum loss of 1 HP.
    # Skip it when Nine Lives protects a Pokémon already at 1 HP.
    if saved && amount == 0
      NineLives.show_message(self)
      return 0
    end
    result = nine_lives_original_reduce_hp( amount, anim, registerDamage, anyAnim )
    NineLives.show_message(self) if saved && !fainted?
    return result
  end

  # Fallback for effects that directly set HP to 0 before calling pbFaint.
  alias_method :nine_lives_original_faint, :pbFaint

  def pbFaint(showMessage = true)
    already_checked = @nine_lives_lethal_checked
    @nine_lives_lethal_checked = false
    if fainted? && !@fainted && !already_checked
      if NineLives.roll?(self, true)
        self.hp = 1
        @battle.scene.pbHPChanged(self, 0, false)
        NineLives.show_message(self)
        return
      end
    end
    return nine_lives_original_faint(showMessage)
  end
end

# Identify the direct move-damage HP update.
class Battle::Move
  alias_method :nine_lives_original_inflict_hp_damage, :pbInflictHPDamage

  def pbInflictHPDamage(target)
    old_flag = target.instance_variable_get(:@nine_lives_direct_hp_damage)
    begin
      target.instance_variable_set(:@nine_lives_direct_hp_damage, true)
      return nine_lives_original_inflict_hp_damage(target)
    ensure
      target.instance_variable_set( :@nine_lives_direct_hp_damage, old_flag )
    end
  end
end

# +1 priority for damaging moves below 1/4 HP.
Battle::AbilityEffects::PriorityChange.add(:NINELIVES, proc { |ability, battler, move, priority|
  next priority if !move.damagingMove?
  next priority if !NineLives.priority_active?(battler)
  next priority + 1
})

# Essentials AI
KaitoAbilitySupport.rate(:NINELIVES, 8)
Battle::AI::Handlers::AbilityRanking.add(:NINELIVES, proc { |ability, score, battler, ai|
  damaging = battler.check_for_move { |m| m.damagingMove? }
  next 6 if !damaging
  next NineLives.priority_active?(battler) ? 9 : 8
})
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:nine_lives, proc { |score, move, user, target, ai, battle|
  next score if !ai.trainer.medium_skill?
  next score if !move.damagingMove?
  next score if !target.has_active_ability?(:NINELIVES)
  next score + NineLives.ai_survival_adjustment( user, target, move, move.rough_damage )
})

# Advanced AI
if defined?(AdvancedAI::Utilities)
  class << AdvancedAI::Utilities
    alias_method :nine_lives_original_effective_priority, :effective_priority

    def effective_priority(user, move, battle = nil)
      result = nine_lives_original_effective_priority(user, move, battle)
      return result if !move || !move.damagingMove?
      return result + (NineLives.priority_active?(user) ? 1 : 0)
    end
  end
end
if defined?(AdvancedAI::CombatUtilities) && Battle::AI.method_defined?(:score_move_advanced)
  class Battle::AI
    alias_method :nine_lives_original_advanced_score, :score_move_advanced

    def score_move_advanced(move, user, target, skill)
      score = nine_lives_original_advanced_score(move, user, target, skill)
      return score if score <= 0 || !user || !target
      attacker = NineLives.real_battler(user)
      defender = NineLives.real_battler(target)
      native = move.respond_to?(:move) ? move.move : move
      return score if !native.damagingMove?
      return score if !defender.hasActiveAbility?(:NINELIVES)
      damage = AdvancedAI::CombatUtilities.estimate_damage( attacker, native, defender )
      return score + NineLives.ai_survival_adjustment( attacker, defender, native, damage )
    end
  end
end

# Berserker Rage
module BerserkerRage
  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

  # Reaches 1.0 at 95% missing HP.
  def self.intensity(value)
    b = real_battler(value)
    return 0.0 if !b || b.totalhp <= 0
    missing = b.totalhp - b.hp
    return [[missing * 20.0 / (b.totalhp * 19), 0.0].max, 1.0].min
  end

  def self.speed_multiplier(value); return 1.0 + intensity(value); end

  def self.healing_rate(value); return 0.5 * intensity(value); end

  def self.heal_amount(value, damage)
    b = real_battler(value)
    return 0 if !b || damage <= 0 || !b.canHeal?
    rate = healing_rate(b)
    return 0 if rate <= 0
    amount = [(damage * rate).floor, 1].max
    return [amount, b.totalhp - b.hp].min
  end

  def self.recover(user, amount, battle)
    return if amount <= 0
    old_name  = $aamName
    old_name2 = $aamName2
    begin
      name = GameData::Ability.get(:BERSERKERRAGE).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(user)
      user.pbRecoverHP(amount)
      battle.pbDisplay(_INTL("{1}'s {2} restored its HP!", user.pbThis, name))
      battle.pbHideAbilitySplash(user)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end

  def self.ai_bonus(user, target, move, damage)
    user   = real_battler(user)
    target = real_battler(target)
    native = move.respond_to?(:move) ? move.move : move
    return 0 if !user || !target
    return 0 if !user.opposes?(target)
    return 0 if !user.hasActiveAbility?(:BERSERKERRAGE)
    return 0 if !native.damagingMove?
    if target.effects[PBEffects::Substitute] > 0 && !native.ignoresSubstitute?(user)
      return 0
    end
    actual_damage = [damage, target.hp].min
    heal = heal_amount(user, actual_damage)
    return 0 if heal <= 0

    # Prefer attacks that recover a meaningful portion of total HP.
    value = (40.0 * heal / user.totalhp).round
    return [value, 20].min
  end
end

# Speed
Battle::AbilityEffects::SpeedCalc.add(:BERSERKERRAGE, proc { |ability, battler, mult| next mult * BerserkerRage.speed_multiplier(battler) }
)

# Recover HP after each successful damaging hit.
Battle::AbilityEffects::OnDealingHit.add(:BERSERKERRAGE, proc { |ability, user, target, move, battle|
  next if user.fainted?
  next if user.index == target.index
  next if !move.damagingMove?
  next if target.damageState.substitute
  next if target.damageState.disguise || target.damageState.iceFace
  damage = target.damageState.hpLost
  amount = BerserkerRage.heal_amount(user, damage)
  next if amount <= 0
  BerserkerRage.recover(user, amount, battle)
})

# Essentials AI
# Speed prediction uses the SpeedCalc handler at high skill.
KaitoAbilitySupport.rate(:BERSERKERRAGE, 8)
Battle::AI::Handlers::AbilityRanking.add(:BERSERKERRAGE, proc { |ability, score, battler, ai|
  next 5 if !battler.check_for_move { |m| m.damagingMove? }
  next 10 if battler.hp * 4 <= battler.totalhp
  next 9 if battler.hp * 2 <= battler.totalhp
  next 8
})
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:berserker_rage, proc { |score, move, user, target, ai, battle|
  next score if !ai.trainer.medium_skill?
  next score if !move.damagingMove?
  next score if !user.has_active_ability?(:BERSERKERRAGE)
  next score + BerserkerRage.ai_bonus( user, target, move, move.rough_damage )
})

# Advanced AI
# Its existing pbSpeed calls include the SpeedCalc handler.
if defined?(AdvancedAI::CombatUtilities) && Battle::AI.method_defined?(:score_move_advanced)
  class Battle::AI
    alias_method :berserker_rage_original_advanced_score, :score_move_advanced

    def score_move_advanced(move, user, target, skill)
      score = berserker_rage_original_advanced_score( move, user, target, skill )
      return score if score <= 0 || !user || !target
      attacker = BerserkerRage.real_battler(user)
      defender = BerserkerRage.real_battler(target)
      native = move.respond_to?(:move) ? move.move : move
      return score if !native.damagingMove?
      return score if !attacker.hasActiveAbility?(:BERSERKERRAGE)
      damage = AdvancedAI::CombatUtilities.estimate_damage( attacker, native, defender )
      return score + BerserkerRage.ai_bonus( attacker, defender, native, damage )
    end
  end
end

# Ragnarok
module Ragnarok
  def self.real_battler(value); return value.respond_to?(:battler) ? value.battler : value; end

  def self.negative_stats(value)
    b = real_battler(value)
    return [] if !b
    return b.stages.keys.select { |stat| b.stages[stat] < 0 }
  end

  def self.activate(battler)
    return if battler.fainted?
    return if !battler.hasActiveAbility?(:RAGNAROK)
    return if battler.instance_variable_get(:@ragnarok_activating)
    negatives = negative_stats(battler)
    has_status = battler.status != :NONE
    return if !has_status && negatives.empty?
    battle = battler.battle
    old_name  = $aamName
    old_name2 = $aamName2
    begin
      battler.instance_variable_set(:@ragnarok_activating, true)
      name = GameData::Ability.get(:RAGNAROK).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(battler)
      battler.pbCureStatus if has_status
      if !negatives.empty?
        negatives.each { |stat| battler.stages[stat] = 0 }
        battle.pbDisplay(_INTL( "{1}'s lowered stats were restored!", battler.pbThis ))
      end
      battle.pbHideAbilitySplash(battler)
    ensure
      battler.instance_variable_set(:@ragnarok_activating, false)
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end

  def self.ai_adjustment(user, target, move, damage)
    user   = real_battler(user)
    target = real_battler(target)
    native = move.respond_to?(:move) ? move.move : move
    return 0 if !user || !target
    return 0 if !user.opposes?(target)
    return 0 if !native.damagingMove?
    return 0 if !target.hasActiveAbility?(:RAGNAROK)
    return 0 if target.hp * 2 < target.totalhp
    return 0 if damage <= 0 || damage >= target.hp
    return 0 if (target.hp - damage) * 2 >= target.totalhp
    if target.effects[PBEffects::Substitute] > 0 && !native.ignoresSubstitute?(user)
      return 0
    end
    benefit = target.status != :NONE ? 5 : 0
    negative_stats(target).each do |stat|
      benefit += [-target.stages[stat], 3].min * 2
    end
    return -[benefit, 15].min
  end
end

# Detect actual threshold crossings, including indirect damage and HP costs.
class Battle::Battler
  alias_method :ragnarok_original_reduce_hp, :pbReduceHP

  def pbReduceHP(amt, anim = true, registerDamage = true, anyAnim = true)
    old_hp = hp
    result = ragnarok_original_reduce_hp( amt, anim, registerDamage, anyAnim )
    if !fainted? && old_hp * 2 >= totalhp && hp * 2 < totalhp
      Ragnarok.activate(self)
    end
    return result
  end
end

# Essentials AI
KaitoAbilitySupport.rate(:RAGNAROK, 7)
Battle::AI::Handlers::AbilityRanking.add(:RAGNAROK, proc { |ability, score, battler, ai|
  impaired = battler.status != :NONE || !Ragnarok.negative_stats(battler).empty?
  next 9 if impaired && battler.hp * 2 >= battler.totalhp
  next battler.hp * 2 >= battler.totalhp ? 7 : 4
})
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:ragnarok, proc { |score, move, user, target, ai, battle|
  next score if !ai.trainer.medium_skill?
  next score if !move.damagingMove?
  next score if !target.has_active_ability?(:RAGNAROK)
  next score + Ragnarok.ai_adjustment( user, target, move, move.rough_damage )
})

# Advanced AI
if defined?(AdvancedAI::CombatUtilities) && Battle::AI.method_defined?(:score_move_advanced)
  class Battle::AI
    alias_method :ragnarok_original_advanced_score, :score_move_advanced

    def score_move_advanced(move, user, target, skill)
      score = ragnarok_original_advanced_score( move, user, target, skill )
      return score if score <= 0 || !user || !target
      attacker = Ragnarok.real_battler(user)
      defender = Ragnarok.real_battler(target)
      native = move.respond_to?(:move) ? move.move : move
      return score if !native.damagingMove?
      return score if !defender.hasActiveAbility?(:RAGNAROK)
      damage = AdvancedAI::CombatUtilities.estimate_damage( attacker, native, defender )
      return score + Ragnarok.ai_adjustment( attacker, defender, native, damage )
    end
  end
end

# X-Ray Vision
# Reveals all opposing held items on entry and disables them for 2 rounds.
# Only held items are disabled; items used from the Bag are unaffected.
module XRayVision
  DURATION = 2

  def self.real(value)
    return value.battler if value && value.respond_to?(:battler)
    return value
  end

  def self.turns(battler)
    battler = real(battler)
    return 0 if !battler
    return battler.instance_variable_get(:@xray_vision_turns).to_i
  end

  def self.locked?(battler); return turns(battler) > 0; end

  def self.apply(target)
    target.instance_variable_set(:@xray_vision_turns, DURATION)
    target.instance_variable_set(:@xray_vision_token, Object.new)
  end
  # Held item suppression and reset on switching, including Baton Pass.
  module BattlerHooks
    def itemActive?(ignoreFainted = false)
      return false if XRayVision.locked?(self)
      super
    end

    def hasWorkingItem(*args)
      return false if XRayVision.locked?(self)
      super
    end
  end
  # Count down after all end-of-round item effects.
  # Tokens prevent newly switched-in Pokemon from losing a turn immediately.
  module BattleHooks
    def pbEndOfRoundPhase
      pending = allBattlers.select { |b| XRayVision.locked?(b) }.map do |b|
        [b, b.instance_variable_get(:@xray_vision_token)]
      end
      result = super
      return result if @decision > 0
      pending.each do |battler, token|
        next if battler.fainted?
        next if !battler.instance_variable_get(:@xray_vision_token).equal?(token)
        remaining = XRayVision.turns(battler) - 1
        battler.instance_variable_set(:@xray_vision_turns, remaining)
        next if remaining > 0
        battler.instance_variable_set(:@xray_vision_token, nil)
        pbDisplay(_INTL("X-Ray Vision's effect on {1} wore off!", battler.pbThis(true)))

        # Check berries, herbs and seeds when held items become usable again.
        battler.pbHeldItemTriggerCheck
        battler.pbItemTerrainStatBoostCheck
      end
      return result
    end
  end
  # Install optional AdvancedAI hooks after all plugins have loaded.
  module AIBootHooks
    def initialize(*args, &block)
      XRayVision.install_advanced_ai!
      super
    end
  end

  module AdvancedUtilityHooks
    def has_resist_berry?(target, move_type)
      return false if XRayVision.locked?(target)
      super
    end
  end

  module AdvancedScorerHooks
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if !move || !user
      return score if !score.is_a?(Numeric) || score <= -999
      source = XRayVision.real(user)
      victim = XRayVision.real(target)

      # Fling and Natural Gift fail while the user's held item is disabled.
      if source && XRayVision.locked?(source) && ["ThrowUserItemAtTarget", "TypeAndPowerDependOnUserBerry"].include?(move.function_code)
        return -1000
      end

      # Embargo is less urgent while the target's item is already disabled.
      if victim && XRayVision.turns(victim) >= 2 && move.function_code == "StartTargetCannotUseItem"
        score -= 25
      end
      return score
    end
  end

  def self.install_advanced_ai!
    if defined?(AdvancedAI::Utilities) && AdvancedAI::Utilities.respond_to?(:has_resist_berry?) &&
       !AdvancedAI::Utilities.singleton_class.ancestors.include?(AdvancedUtilityHooks)
      AdvancedAI::Utilities.singleton_class.prepend(AdvancedUtilityHooks)
    end
    if Battle::AI.method_defined?(:score_move_advanced) && !Battle::AI.ancestors.include?(AdvancedScorerHooks)
      Battle::AI.prepend(AdvancedScorerHooks)
    end
  end
end

class Battle::Battler
  unless method_defined?(:xray_vision_original_pbInitEffects)
    alias_method :xray_vision_original_pbInitEffects, :pbInitEffects
  end

  def pbInitEffects(batonPass)
    @xray_vision_turns = 0
    @xray_vision_token = nil
    return xray_vision_original_pbInitEffects(batonPass)
  end
end
Battle::Battler.prepend(XRayVision::BattlerHooks)

# X-Ray Vision - end-of-round countdown compatible with M.A.G
class Battle
  unless method_defined?(:xray_vision_original_end_of_round)
    alias_method :xray_vision_original_end_of_round, :pbEndOfRoundPhase
  end

  def pbEndOfRoundPhase
    pending = allBattlers.select do |b|
      XRayVision.locked?(b)
    end.map do |b|
      [b, b.instance_variable_get(:@xray_vision_token)]
    end
    result = xray_vision_original_end_of_round
    return result if @decision > 0
    pending.each do |battler, token|
      next if battler.fainted?
      next if !battler.instance_variable_get( :@xray_vision_token ).equal?(token)
      remaining = XRayVision.turns(battler) - 1
      battler.instance_variable_set( :@xray_vision_turns, remaining )
      next if remaining > 0
      battler.instance_variable_set(:@xray_vision_token, nil)
      pbDisplay( _INTL("X-Ray Vision's effect on {1} wore off!", battler.pbThis(true)) )
      battler.pbHeldItemTriggerCheck
      battler.pbItemTerrainStatBoostCheck
    end
    return result
  end
end

class Battle::AI
  unless method_defined?(:xray_vision_original_initialize) || private_method_defined?(:xray_vision_original_initialize)
    alias_method :xray_vision_original_initialize, :initialize
  end

  def initialize(*args, &block)
    XRayVision.install_advanced_ai!
    xray_vision_original_initialize(*args, &block)
  end
  private :initialize
end

# X-Ray Vision - On entering battle
# Works for both player and opposing Pokemon.
Battle::AbilityEffects::OnSwitchIn.add(:XRAYVISION, proc { |ability, battler, battle, switch_in|
  foes = battle.allOtherSideBattlers(battler.index).select do |b|
    !b.fainted? && b.item
  end
  next if foes.empty?
  battle.pbShowAbilitySplash(battler)
  begin
    foes.each do |foe|
      battle.pbDisplay(_INTL("{1} frisked {2} and found its {3}!", battler.pbThis, foe.pbThis(true), foe.itemName))
      XRayVision.apply(foe)
      battle.pbDisplay(_INTL("{1}'s held item was disabled for {2} turns!", foe.pbThis, XRayVision::DURATION))
    end
  ensure
    battle.pbHideAbilitySplash(battler)
  end
})

# X-Ray Vision - Standard AI ability ranking
# Disabling useful items is beneficial; disabling harmful items can be harmful.
# Native AI item calculations also respect the patched itemActive? method.
Battle::AI::BASE_ABILITY_RATINGS[5] ||= []
Battle::AI::BASE_ABILITY_RATINGS[5] |= [:XRAYVISION]
Battle::AI::Handlers::AbilityRanking.add(:XRAYVISION, proc { |ability, score, battler, ai|
  utility = 0
  ai.each_foe_battler(battler.side) do |foe, index|
    next if !foe.item || !foe.item_active?
    utility += foe.wants_item?(foe.item_id) - foe.wants_item?(:NONE)
  end
  next [[(utility / 2.0).round, -5].max, 8].min
})

# Malignate
# Converts Normal-type moves into Dark-type moves.
# Moves converted by this ability gain 20% power.
Battle::AbilityEffects::ModifyMoveBaseType.add(:MALIGNATE, proc { |ability, user, move, type|
  next if type != :NORMAL || !GameData::Type.exists?(:DARK)
  move.powerBoost = true
  next :DARK
})

Battle::AbilityEffects::DamageCalcFromUser.add(:MALIGNATE, proc { |ability, user, target, move, mults, power, type| mults[:power_multiplier] *= 1.2 if move.powerBoost }
)

# Malignate - AI ability rating
# Native AI damage calculations use the ability handlers above.
Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
Battle::AI::BASE_ABILITY_RATINGS[8] |= [:MALIGNATE]

# PHANTOM IMAGE
# Load after Innate Abilities and Advanced AI.
module PhantomImage
  # Returns the evasion multiplier, without checking ability ownership.
  def self.multiplier(user, target)
    user_speed   = [user.pbSpeed, 1].max
    target_speed = [target.pbSpeed, 1].max
    return 2.0  if target_speed >= user_speed * 2
    return 1.5  if target_speed * 2 >= user_speed * 3
    return 1.25 if target_speed * 4 >= user_speed * 5
    return 1.0
  end

  # Preserve the Innate Abilities splash name.
  def self.show_splash(battler, battle)
    old_name  = $aamName
    old_name2 = $aamName2
    name = GameData::Ability.get(:PHANTOMIMAGE).name
    begin
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay( _INTL("{1} is moving in an elusive way!", battler.pbThis) )
      battle.pbHideAbilitySplash(battler)
    ensure
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end

  # Approximate additional accuracy penalty for Advanced AI.
  # This does not perform a hit check or consume the battle's RNG.
  def self.advanced_penalty(move, user, target)
    return 0 if !move || !user || !target
    user   = user.battler if user.respond_to?(:battler)
    target = target.battler if target.respond_to?(:battler)
    native = move.respond_to?(:move) ? move.move : move
    return 0 if user.fainted? || target.fainted?
    return 0 if !user.opposes?(target)
    return 0 if !target.hasActiveAbility?(:PHANTOMIMAGE)
    factor = multiplier(user, target)
    return 0 if factor <= 1.0

    # Mold Breaker and ability-ignoring moves.
    # The existing utility also checks Ability Shield.
    return 0 if AdvancedAI::Utilities.ignores_ability?( user, native, target )
    return 0 if user.hasActiveAbility?(:NOGUARD)
    return 0 if target.hasActiveAbility?(:NOGUARD)

    # OHKO moves have their own accuracy calculation.
    return 0 if native.is_a?(Battle::Move::OHKO)

    # Lock-On / Mind Reader.
    if user.effects[PBEffects::LockOn] > 0 && user.effects[PBEffects::LockOnPos] == target.index
      return 0
    end
    return 0 if target.effects[PBEffects::Telekinesis] > 0
    if Settings::MECHANICS_GENERATION >= 6 && target.effects[PBEffects::Minimize] && native.tramplesMinimize?
      return 0
    end

    # Includes weather-dependent accuracy, e.g. Thunder in rain.
    accuracy = native.pbBaseAccuracy(user, target)
    return 0 if accuracy <= 0

    # Heuristic score adjustment, not a replacement accuracy formula.
    return (40.0 * (1.0 - 1.0 / factor)).round
  end
end

# Actual battle effect.
# Native AI also reads this handler when estimating accuracy.
Battle::AbilityEffects::AccuracyCalcFromTarget.add(:PHANTOMIMAGE, proc { |ability, mods, user, target, move, type| mods[:evasion_multiplier] *= PhantomImage.multiplier(user, target) }
)

# Correct the old misspelled splash handler.
Battle::AbilityEffects::OnSwitchIn.remove(:PHANTOMPIMAGE)

Battle::AbilityEffects::OnSwitchIn.add(:PHANTOMIMAGE, proc { |ability, battler, battle, switch_in|
  next if battler.fainted?
  PhantomImage.show_splash(battler, battle)
})

# Native AI: ability rating.
# No extra accuracy penalty here, because rough_accuracy already uses the handler.
KaitoAbilitySupport.rate(:PHANTOMIMAGE, 6)
Battle::AI::Handlers::AbilityRanking.add(:PHANTOMIMAGE, proc { |ability, score, battler, ai|
  holder = battler.battler
  next 0 if holder.fainted?

  # No Guard on the holder makes ordinary accuracy checks always succeed.
  next 0 if holder.hasActiveAbility?(:NOGUARD)
  values = []
  ai.battle.battlers.each do |foe|
    next if !foe || foe.fainted?
    next if !holder.opposes?(foe)
    if foe.hasActiveAbility?(:NOGUARD)
      values << 0.0
    else
      factor = PhantomImage.multiplier(foe, holder)
      values << (factor - 1.0)
    end
  end
  next score if values.empty?
  average = values.inject(0.0) { |sum, value| sum + value }
  average /= values.length

  # Contextual rating: 3 to 9.
  next 3 + (average * 6).round
})

# Advanced AI: additional per-target move score adjustment.
class Battle::AI
  if method_defined?(:score_move_advanced)
    unless method_defined?(:phantom_image_original_advanced_score)
      alias_method :phantom_image_original_advanced_score, :score_move_advanced
    end

    def score_move_advanced(move, user, target, skill)
      score = phantom_image_original_advanced_score( move, user, target, skill )
      return score if !score.is_a?(Numeric) || score <= 0
      penalty = PhantomImage.advanced_penalty(move, user, target)
      return score if penalty <= 0
      return [score - penalty, 1].max
    end
  end
end

# STALK - complete replacement with knockout reactivation for Pokemon Essentials v21.1
if defined?(StealthAbility::ABILITY)
  raise "Remove the old Stealth block before loading Stalk_Complete.rb."
end

module StealthAbility
  ABILITY = :STALK

  def self.real(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  def self.native(move)
    return move.move if move.respond_to?(:move)
    return move
  end

  def self.used?(battle, pokemon)
    return true if !battle || !pokemon
    used = battle.instance_variable_get(:@stealth_ability_used)
    return used && used[pokemon.object_id] == true
  end

  def self.can_activate?(battler)
    return false if !battler || battler.fainted? || !battler.pokemon
    return false if used?(battler.battle, battler.pokemon)
    return battler.hasActiveAbility?(ABILITY)
  end

  def self.vanished?(battler)
    return false if !battler || battler.fainted?
    return battler.instance_variable_get(:@stealth_vanished) == true
  end

  def self.active?(battler); return vanished?(battler) && battler.hasActiveAbility?(ABILITY); end

  def self.splash(battler)
    old_name, old_name2 = $aamName, $aamName2
    begin
      name = GameData::Ability.get(ABILITY).name
      $aamName = $aamName2 = name
      battler.battle.pbShowAbilitySplash(battler)
      yield
      battler.battle.pbHideAbilitySplash(battler)
    ensure
      $aamName, $aamName2 = old_name, old_name2
    end
  end

  def self.activate(battler)
    return false if !can_activate?(battler)
    battle = battler.battle
    used = battle.instance_variable_get(:@stealth_ability_used) || {}
    used[battler.pokemon.object_id] = true
    battle.instance_variable_set(:@stealth_ability_used, used)
    battler.instance_variable_set(:@stealth_vanished, true)
    splash(battler) do
      battle.pbDisplay(_INTL("{1} vanished into the shadows!", battler.pbThis))
    end
    return true
  end

  # A knockout restores vanishing independently of the entry activation limit.
  def self.recloak_after_ko(user)
    return false if !user || user.fainted?
    return false if !user.hasActiveAbility?(ABILITY)
    return false if user.instance_variable_get(:@stalk_ko_pokemon).equal?(user.pokemon)
    user.instance_variable_set(:@stalk_ko_pokemon, user.pokemon)
    user.instance_variable_set(:@stealth_vanished, true)
    splash(user) do
      user.battle.pbDisplay(_INTL("{1} vanished into the shadows!", user.pbThis))
    end
    return true
  end

  def self.reappear(battler, show_message = true)
    earned_this_action =
      battler.instance_variable_get(:@stalk_move_depth).to_i > 0 &&
      battler.instance_variable_get(:@stalk_ko_pokemon).equal?(battler.pokemon)
    return if show_message && earned_this_action && !battler.fainted?
    battler.instance_variable_set(:@stalk_ko_pokemon, nil) if !show_message
    was_hidden = battler.instance_variable_get(:@stealth_vanished)
    battler.instance_variable_set(:@stealth_vanished, false)
    if was_hidden && show_message && !battler.fainted?
      battler.battle.pbDisplay(_INTL("{1} reappeared!", battler.pbThis))
    end
  end

  def self.instant_force?(move, user)
    return false if !active?(real(user))
    return [:PHANTOMFORCE, :SHADOWFORCE].include?(native(move).id)
  end

  def self.ignored?(user, target, move)
    if defined?(AdvancedAI::Utilities) && AdvancedAI::Utilities.respond_to?(:ignores_ability?)
      return AdvancedAI::Utilities.ignores_ability?(user, move, target)
    end
    return false if target.hasActiveItem?(:ABILITYSHIELD)
    return true if user.hasMoldBreaker?
    return true if ["IgnoreTargetAbility", "CategoryDependsOnHigherDamageIgnoreTargetAbility"].include?(move.function_code)
    return user.hasActiveAbility?(:MYCELIUMMIGHT) && move.statusMove?
  end

  # Compute priority using a copy so handlers cannot set Prankster or other
  # effects on the real battler during prediction.
  def self.priority(move, battler)
    move = native(move)
    copy = battler.clone
    copy.instance_variable_set(:@effects, battler.effects.dup)
    copy.instance_variable_set(:@stages, battler.stages.dup)
    value = move.pbPriority(copy)
    if copy.abilityActive?
      value = Battle::AbilityEffects.triggerPriorityChange( copy.ability, copy, move, value )
    end
    return value
  end

  # Probability that user acts before target, assuming target uses each of
  # its currently usable moves equally often. A speed tie is treated as 50/50.
  def self.before_chance(move, user, target)
    up = priority(move, user)
    moves = target.moves.each_with_index.select do |m, index|
      m && (m.pp > 0 || m.total_pp == 0) && target.battle.pbCanChooseMove?(target.index, index, false)
    end.map { |pair| pair[0] }
    priorities = moves.map { |m| priority(m, target) }
    priorities = [0] if priorities.empty?
    us, ts = user.pbSpeed, target.pbSpeed
    trick_room = user.battle.field.effects[PBEffects::TrickRoom] > 0
    total = priorities.inject(0.0) do |sum, tp|
      chance = if up != tp
                 up > tp ? 1.0 : 0.0
               elsif us == ts
                 0.5
               else
                 faster = us > ts
                 faster = !faster if trick_room
                 faster ? 1.0 : 0.0
               end
      sum + chance
    end
    return total / priorities.length
  end

  def self.block_chance(move, user, target)
    user, target, move = real(user), real(target), native(move)
    return 0.0 if !user || !target || !move || !user.opposes?(target)
    data = move.pbTarget(user)
    return 0.0 if !data.targets_foe && data.id != :None
    return 0.0 if !active?(target) || ignored?(user, target, move)
    return before_chance(move, user, target)
  end

  # Query availability on a cloned battlefield. Never consume the original
  # Pokemon's activation, and include active Innates and ability suppression.
  def self.entry_available?(battle, pokemon, index)
    return false if !pokemon || pokemon.fainted? || pokemon.egg?
    return false if used?(battle, pokemon)
    preview = battle.clone
    copies = battle.battlers.map do |b|
      next nil if !b
      copy = b.clone
      copy.instance_variable_set(:@battle, preview)
      copy.instance_variable_set(:@effects, b.effects.dup)
      copy.instance_variable_set(:@stages, b.stages.dup)
      copy
    end
    preview.instance_variable_set(:@battlers, copies)
    preview.moldBreaker = false
    probe = Battle::Battler.new(preview, index)
    probe.pbInitialize(pokemon.clone, -1)
    copies[index] = probe
    return probe.hasActiveAbility?(ABILITY)
  end

  def self.adjust_score(score, move, user, target)
    ai_move = move
    return score if !score.is_a?(Numeric) || score <= Battle::AI::MOVE_USELESS_SCORE
    user, target, move = real(user), real(target), native(move)
    return score if !user || !move
    if target && user.opposes?(target)
      chance = block_chance(move, user, target)
      score -= (60 * chance).round
    end
    # A safe turn has value, but do not revive a move already judged useless.
    if active?(user) && move.statusMove?
      chances = user.battle.battlers.map do |foe|
        next if !foe || foe.fainted? || !user.opposes?(foe)
        next if ignored?(foe, user, move)
        1.0 - before_chance(move, user, foe)
      end.compact
      safe = chances.empty? ? 0.0 : chances.inject(1.0) { |v, c| v * c }
      score += ((move.healingMove? ? 12 : 8) * safe).round
    end
    # Reward opposing knockouts that would restore the user's cloak.
    # Never reward deliberately knocking out allies.
    if user.hasActiveAbility?(ABILITY) && target && !target.fainted? && user.opposes?(target) && move.damagingMove? &&
       block_chance(move, user, target) < 1.0
      damage = nil
      if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:estimate_damage)
        damage = AdvancedAI::CombatUtilities.estimate_damage(user, move, target)
      elsif ai_move.respond_to?(:rough_damage)
        damage = ai_move.rough_damage
      end
      score += 12 if damage && damage >= target.hp
    end
    return [score, Battle::AI::MOVE_USELESS_SCORE + 1].max
  end
end

# Entry hazards: skip ONLY this Pokemon's hazard processing.
# OnSwitchIn is a fallback for alternate entry flows.
class Battle
  alias_method :stealth_v2_entry_hazards, :pbEntryHazards
  def pbEntryHazards(battler)
    StealthAbility.activate(battler) if StealthAbility.can_activate?(battler)
    return if StealthAbility.active?(battler)
    return stealth_v2_entry_hazards(battler)
  end
end

Battle::AbilityEffects::OnSwitchIn.add(:STALK, proc { |ability, battler, battle, switch_in| StealthAbility.activate(battler) })

Battle::AbilityEffects::MoveImmunity.add(:STALK, proc { |ability, user, target, move, type, battle, show_message|
  next false if !user || !user.opposes?(target)
  next false if !StealthAbility.active?(target)
  # The normal engine handles ability suppression/Mold Breaker before here.
  # During AI queries, reject only when Stealth is predicted to block for sure.
  if battle.instance_variable_get(:@stealth_ai_depth).to_i > 0
    next StealthAbility.block_chance(move, user, target) >= 1.0
  end
  if show_message
    StealthAbility.splash(target) do
      battle.pbDisplay(_INTL("{1} avoided the move while vanished!", target.pbThis))
    end
  end
  next true
})

Battle::AbilityEffects::OnDealingHit.add(:STALK, proc { |ability, user, target, move, battle|
  next if !user || !target || user.fainted? || user.equal?(target)
  next if !user.hasActiveAbility?(:STALK) || !target.fainted?
  next if target.damageState.unaffected || target.damageState.substitute
  next if target.damageState.hpLost <= 0
  StealthAbility.recloak_after_ko(user)
})

class Battle::Battler
  # Preserve a cloak earned during nested/called moves until the whole action
  # completes. The next attempted move may remove it normally.
  alias_method :stalk_ko_original_use_move, :pbUseMove
  def pbUseMove(*args)
    previous_depth = @stalk_move_depth.to_i
    @stalk_ko_pokemon = nil if previous_depth == 0
    @stalk_move_depth = previous_depth + 1
    begin
      return stalk_ko_original_use_move(*args)
    ensure
      @stalk_move_depth = previous_depth
      @stalk_ko_pokemon = nil if previous_depth == 0
    end
  end
  alias_method :stealth_v2_end_turn, :pbEndTurn
  def pbEndTurn(choice)
    original_pokemon = pokemon
    result = stealth_v2_end_turn(choice)
    if pokemon.equal?(original_pokemon) && choice && choice[0] == :UseMove
      StealthAbility.reappear(self)
    end
    return result
  end
  alias_method :stealth_v2_switch_out, :pbAbilitiesOnSwitchOut
  def pbAbilitiesOnSwitchOut(*args)
    StealthAbility.reappear(self, false)
    return stealth_v2_switch_out(*args)
  end
end

# A narrowly scoped, LAST-loaded move wrapper also works with the existing
# CursedTerrain prepend. No aliases are created on a prepended method.
module StealthInstantForce
  def pbIsChargingTurn?(user)
    if StealthAbility.instant_force?(self, user)
      @powerHerb = false
      @chargingTurn = false
      @damagingTurn = true
      return false
    end
    return super
  end
end
Battle::Move::TwoTurnAttackInvulnerableRemoveProtections.prepend(StealthInstantForce)

# Native and Advanced AI prediction context. Always restore it, even on errors.
class Battle::AI
  alias_method :stealth_v2_move_score, :pbGetMoveScore
  def pbGetMoveScore(*args)
    depth = @battle.instance_variable_get(:@stealth_ai_depth).to_i
    begin
      @battle.instance_variable_set(:@stealth_ai_depth, depth + 1)
      return stealth_v2_move_score(*args)
    ensure
      @battle.instance_variable_set(:@stealth_ai_depth, depth)
    end
  end
  alias_method :stealth_v2_predict_failure, :pbPredictMoveFailureAgainstTarget
  def pbPredictMoveFailureAgainstTarget
    depth = @battle.instance_variable_get(:@stealth_ai_depth).to_i
    begin
      @battle.instance_variable_set(:@stealth_ai_depth, depth + 1)
      return stealth_v2_predict_failure
    ensure
      @battle.instance_variable_set(:@stealth_ai_depth, depth)
    end
  end
  alias_method :stealth_v2_target_score, :pbGetMoveScoreAgainstTarget
  def pbGetMoveScoreAgainstTarget
    score = stealth_v2_target_score
    return score if @stealth_v2_advanced_scoring
    return StealthAbility.adjust_score(score, @move, @user, @target)
  end
  if method_defined?(:score_move_advanced)
    alias_method :stealth_v2_advanced_score, :score_move_advanced
    def score_move_advanced(move, user, target, skill)
      previous = @stealth_v2_advanced_scoring
      begin
        @stealth_v2_advanced_scoring = true
        score = stealth_v2_advanced_score(move, user, target, skill)
      ensure
        @stealth_v2_advanced_scoring = previous
      end
      return StealthAbility.adjust_score(score, move, user, target)
    end
  end

  # Advanced AI extends this signature with damage_only. Forward all args.
  alias_method :stealth_v2_hazard_damage, :calculate_entry_hazard_damage
  def calculate_entry_hazard_damage(pokemon, position, *args)
    index = respond_to?(:get_battler_index) ? get_battler_index(position) : position
    return 0 if StealthAbility.entry_available?(@battle, pokemon, index)
    return stealth_v2_hazard_damage(pokemon, position, *args)
  end
  if method_defined?(:switch_entry_hp_preview)
    alias_method :stealth_v2_entry_preview, :switch_entry_hp_preview
    def switch_entry_hp_preview(pokemon, index)
      if StealthAbility.entry_available?(@battle, pokemon, index)
        return switch_hazard_preview(pokemon, index)
      end
      return stealth_v2_entry_preview(pokemon, index)
    end
  end
end
KaitoAbilitySupport.rate(:STALK, 8)
Battle::AI::Handlers::AbilityRanking.add(:STALK, proc { |ability, score, battler, ai|
  holder = battler.battler
  next 9 if StealthAbility.vanished?(holder)
  next 8 if !StealthAbility.used?(ai.battle, holder.pokemon)
  next holder.moves.any? { |move| move && move.damagingMove? } ? 6 : 0
})

# Native AI: instant Phantom/Shadow Force is a damaging turn, not a charge turn.
class Battle::AI::AIMove
  alias_method :stealth_v2_function_score, :function_code
  def function_code
    if @ai && @ai.user && StealthAbility.instant_force?(@move, @ai.user)
      return "RemoveProtections"
    end
    return stealth_v2_function_score
  end
end
if defined?(AdvancedAI::HazardControl)
  class << AdvancedAI::HazardControl
    alias_method :stealth_v2_hazard_estimate, :calculate_hazard_damage
    def calculate_hazard_damage(battle, battler, side_effects)
      holder = StealthAbility.real(battler)
      if holder && holder.respond_to?(:pokemon) && StealthAbility.entry_available?(battle, holder.pokemon, holder.index)
        return 0
      end
      return stealth_v2_hazard_estimate(battle, battler, side_effects)
    end
  end
end

# TELEPATHY

module TelepathyDodge
  CHANCE = 10
  # Convert AI wrappers to actual battle objects.
  def self.real_battler(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  def self.real_move(object)
    return object.move if object.respond_to?(:move)
    return object
  end
  # Show Telepathy rather than the holder's primary ability when it is an Innate.
  def self.show_splash(battler, battle)
    previous_name  = $aamName
    previous_name2 = $aamName2
    begin
      name = GameData::Ability.get(:TELEPATHY).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(battler)
      yield
      battle.pbHideAbilitySplash(battler)
    ensure
      $aamName  = previous_name
      $aamName2 = previous_name2
    end
  end
  # Whether a move can be subject to Telepathy's independent dodge.
  #
  # This method never rolls RNG.
  def self.eligible?(user, target, move, battle, predicting = false)
    user   = real_battler(user)
    target = real_battler(target)
    move   = real_move(move)
    return false if !user || !target || !move || !battle
    return false if user.fainted? || target.fainted?
    return false if !user.opposes?(target)
    return false if !target.hasActiveAbility?(:TELEPATHY)

    # No Guard prevents Telepathy's independent dodge.
    return false if user.hasActiveAbility?(:NOGUARD)
    return false if target.hasActiveAbility?(:NOGUARD)

    # Lock-On / Mind Reader prevents dodging this user's move.
    if user.effects[PBEffects::LockOn] > 0 && user.effects[PBEffects::LockOnPos] == target.index
      return false
    end

    # Exclude self, side and field moves.
    target_data = move.pbTarget(user)
    return false if !target_data.targets_foe && target_data.id != :None
    if predicting && defined?(AdvancedAI::Utilities) && AdvancedAI::Utilities.respond_to?(:ignores_ability?)
      return false if AdvancedAI::Utilities.ignores_ability?( user, move, target )
    else
      if battle.moldBreaker && !target.hasActiveItem?(:ABILITYSHIELD)
        return false
      end
    end
    return true
  end
  # Actual battle roll.
  # Called only from the real move-success flow, never from AI scoring.
  def self.try_dodge(user, target, move, battle, show_message = true)
    return false if !eligible?(user, target, move, battle)
    return false if battle.pbRandom(100) >= CHANCE
    if show_message
      show_splash(target, battle) do
        battle.pbDisplay( _INTL("{1} foresaw the move and avoided it!", target.pbThis) )
      end
    end
    return true
  end
  # AI preference adjustment.
  # An estimate of the extra risk; it does not change accuracy or roll RNG.
  def self.adjust_ai_score(score, move, user, target, battle)
    return score if !score.is_a?(Numeric)
    return score if score <= Battle::AI::MOVE_USELESS_SCORE
    if eligible?(user, target, move, battle, true)
      score -= 5
    end
    return score
  end
end

# Remove the previously suggested accuracy modifier.
# Telepathy's dodge is handled independently below.

Battle::AbilityEffects::AccuracyCalcFromTarget.remove(:TELEPATHY)

# Original Telepathy effect:
# Avoid damaging moves used by allies.
#
# Opposing moves are NOT randomly processed by this handler.
# This keeps AI immunity queries deterministic.

Battle::AbilityEffects::MoveImmunity.add(:TELEPATHY, proc { |ability, user, target, move, type, battle, show_message|
  next false if !user || !target
  next false if move.statusMove?
  next false if user.index == target.index
  next false if user.opposes?(target)
  if show_message
    TelepathyDodge.show_splash(target, battle) do
      battle.pbDisplay( _INTL("{1} avoids attacks by its ally Pokémon!", target.pbThis) )
    end
  end
  next true
})

# Independent dodge:
# Run after the normal initial success checks, before per-hit accuracy checks.
#
# A failed roll simply allows the move to continue normally.
# A successful roll rejects the move against this target for all its hits.
#
# Uses an ordinary alias, not prepend.

class Battle::Battler
  unless method_defined?(:telepathy_complete_original_success_check)
    alias_method :telepathy_complete_original_success_check, :pbSuccessCheckAgainstTarget
  end

  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    success = telepathy_complete_original_success_check( move, user, target, targets )

    # Do not roll if Protect, immunity, Substitute, etc. already blocked it.
    return success if !success

    # The charging turn itself should not trigger a dodge.
    return success if user.effects[PBEffects::TwoTurnAttack]
    show_message = move.pbShowFailMessages?(targets)
    if TelepathyDodge.try_dodge( user, target, move, @battle, show_message )
      return false
    end
    return success
  end
end

# Native AI: ability value.
# Telepathy now has a benefit in singles as well as doubles.
KaitoAbilitySupport.rate(:TELEPATHY, 4)
Battle::AI::Handlers::AbilityRanking.add(:TELEPATHY, proc { |ability, score, battler, ai|
  holder = battler.battler
  next 0 if holder.fainted?
  has_ally = ai.battle.battlers.any? do |other|
    other && !other.fainted? && other.index != holder.index && !holder.opposes?(other)
  end
  next has_ally ? 6 : 4
})

# Native AI: extra risk when targeting Telepathy.
# Never mark the move as guaranteed to fail because of the 10% dodge.
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
  :telepathy_independent_dodge,
  proc { |score, move, user, target, ai, battle| next TelepathyDodge.adjust_ai_score( score, move, user, target, battle ) }
)

# Advanced AI: its scoring pipeline is separate from native AI's pipeline.
# There are deliberately no No Guard/Lock-On/always-hit exceptions.

class Battle::AI
  if method_defined?(:score_move_advanced)
    unless method_defined?(:telepathy_complete_original_advanced_score)
      alias_method :telepathy_complete_original_advanced_score, :score_move_advanced
    end

    def score_move_advanced(move, user, target, skill)
      score = telepathy_complete_original_advanced_score( move, user, target, skill )
      return TelepathyDodge.adjust_ai_score( score, move, user, target, @battle )
    end
  end
end

# Forewarn
# Announces an opposing Pokemon's strongest move and disables it for 3 rounds.

module ForewarnDisable
  DURATION = 3
  # Forewarn's estimated power for moves with unusual damage calculations.
  def self.move_power(move)
    code = move.function_code
    return 160 if code.start_with?("OHKO")
    return 150 if code == "PowerHigherWithUserHP"
    return 120 if [ "CounterPhysicalDamage", "CounterSpecialDamage", "CounterDamagePlusHalf" ].include?(code)
    return 80 if [
      "FixedDamage20",
      "FixedDamage40",
      "FixedDamageUserLevel",
      "LowerTargetHPToUserHP",
      "FixedDamageUserLevelRandom",
      "PowerHigherWithUserHappiness",
      "PowerLowerWithUserHappiness",
      "PowerHigherWithTargetFasterThanUser",
      "TypeAndPowerDependOnUserBerry",
      "PowerHigherWithLessPP",
      "PowerLowerWithUserHP",
      "PowerHigherWithTargetWeight"
    ].include?(code)
    if Settings::MECHANICS_GENERATION <= 5 && code == "TypeDependsOnUserIVs"
      return 80
    end
    return move.power
  end
  # Keep both the move and its owner instead of storing only the move name.
  def self.candidates(battler, battle)
    strongest = -1
    choices = []
    battle.allOtherSideBattlers(battler.index).each do |foe|
      next if foe.fainted?
      foe.eachMoveWithIndex do |move, index|
        if foe.respond_to?(:baseMoves) && foe.baseMoves && foe.baseMoves[index]
          move = foe.baseMoves[index]
        end
        next if !move
        power = move_power(move)
        next if power < strongest
        if power > strongest
          strongest = power
          choices.clear
        end
        choices << [foe, move.id]
      end
    end
    return choices
  end
  # Use the engine's existing Disable-protection check.
  # Forewarn is an ability effect, not a Mold Breaker attack.
  def self.blocked?(user, target, battle)
    checker = Battle::Move.from_pokemon_move( battle, Pokemon::Move.new(:DISABLE) )
    previous_mold_breaker = battle.moldBreaker
    begin
      battle.moldBreaker = false
      return checker.pbMoveFailedAromaVeil?(user, target, true)
    ensure
      battle.moldBreaker = previous_mold_breaker
    end
  end
end

# Effect

Battle::AbilityEffects::OnSwitchIn.add(:FOREWARN, proc { |ability, battler, battle, switch_in|
  next if battler.fainted?
  choices = ForewarnDisable.candidates(battler, battle)
  next if choices.empty?
  target, move_id = choices[battle.pbRandom(choices.length)]
  move_name = GameData::Move.get(move_id).name
  previous_name  = $aamName
  previous_name2 = $aamName2
  begin
    ability_name = GameData::Ability.get(:FOREWARN).name
    $aamName  = ability_name
    $aamName2 = ability_name
    battle.pbShowAbilitySplash(battler)
    battle.pbDisplay( _INTL("{1} was alerted to {2}'s {3}!", battler.pbThis, target.pbThis(true), move_name) )
    battle.pbHideAbilitySplash(battler)
    next if target.fainted?

    # Standard Disable only stores one disabled move per Pokemon.
    if target.effects[PBEffects::Disable] > 0
      battle.pbDisplay( _INTL("{1} already has a disabled move!", target.pbThis) )
      next
    end
    next if ForewarnDisable.blocked?(battler, target, battle)
    target.effects[PBEffects::Disable] = ForewarnDisable::DURATION
    target.effects[PBEffects::DisableMove] = move_id
    battle.pbDisplay( _INTL("{1}'s {2} was disabled for 3 turns!", target.pbThis, move_name) )

    # Allows Mental Herb and the engine's other cures to respond normally.
    target.pbItemStatusCureCheck
  ensure
    $aamName  = previous_name
    $aamName2 = previous_name2
  end
})

# AI ability value
# Native AI and Advanced AI already recognize the standard Disable effects.
KaitoAbilitySupport.rate(:FOREWARN, 6)
Battle::AI::Handlers::AbilityRanking.add(:FOREWARN, proc { |ability, score, battler, ai| next score })

# Steadfast - additional low-HP effect

module SteadfastResolve
  STATS = [:DEFENSE, :SPECIAL_DEFENSE].freeze
  # Store usage on the battle, keyed by the actual Pokemon.
  # Do not store it on the reusable battler slot.
  def self.used?(battler)
    return true if !battler || !battler.pokemon
    used = battler.battle.instance_variable_get(:@steadfast_resolve_used)
    return used && used[battler.pokemon.object_id] == true
  end

  def self.mark_used(battler)
    battle = battler.battle
    used = ( battle.instance_variable_get(:@steadfast_resolve_used) || {}).dup
    used[battler.pokemon.object_id] = true
    battle.instance_variable_set(:@steadfast_resolve_used, used)
  end
  # Eligibility
  def self.can_activate?(battler)
    return false if !battler || !battler.pokemon
    return false if battler.fainted?
    return false if battler.dummy
    return false if used?(battler)
    return false if battler.hp * 2 >= battler.totalhp
    return false if !battler.hasActiveAbility?(:STEADFAST)
    return true
  end
  # Activate immediately once the condition is met.
  # Standard stat-change rules, including Contrary/Simple, still apply.
  def self.activate(battler)
    return false if !can_activate?(battler)

    # Consume the activation before changing stats to prevent recursion.
    mark_used(battler)
    battle = battler.battle
    previous_name  = $aamName
    previous_name2 = $aamName2
    begin
      name = GameData::Ability.get(:STEADFAST).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(battler)
      STATS.each do |stat|
        battler.pbRaiseStatStageByAbility(stat, 1, battler, false)
      end
      battle.pbHideAbilitySplash(battler)
    ensure
      $aamName  = previous_name
      $aamName2 = previous_name2
    end
    return true
  end
end

# Check after HP loss.
# Ordinary aliases avoid the prepend/alias loops seen with other plugins.

class Battle::Battler
  unless method_defined?(:steadfast_resolve_original_reduce_hp)
    alias_method :steadfast_resolve_original_reduce_hp, :pbReduceHP
  end

  def pbReduceHP(*args)
    original_pokemon = pokemon
    previous_hp = hp
    result = steadfast_resolve_original_reduce_hp(*args)
	show_hp_change = (args.length < 4) ? true : args[3]
	if show_hp_change && pokemon.equal?(original_pokemon) && hp < previous_hp
	  SteadfastResolve.activate(self)
	end
    return result
  end
end

class Battle::Move
  unless method_defined?(:steadfast_original_animate_hit_and_hp_lost)
    alias_method :steadfast_original_animate_hit_and_hp_lost, :pbAnimateHitAndHPLost
  end

  def pbAnimateHitAndHPLost(user, targets)
    result = steadfast_original_animate_hit_and_hp_lost(user, targets)
    targets.each do |target|
      next if target.damageState.substitute
      next if target.damageState.hpLost <= 0
      SteadfastResolve.activate(target)
    end
    return result
  end
end

# Entering battle already below half HP.
# Does not interfere with the original OnFlinch handler.

Battle::AbilityEffects::OnSwitchIn.add(:STEADFAST, proc { |ability, battler, battle, switch_in| SteadfastResolve.activate(battler) })

# AI: ability value before and after the defensive activation is spent.
# Actual stat stages are handled by the existing damage estimators.
KaitoAbilitySupport.rate(:STEADFAST, 6)
Battle::AI::Handlers::AbilityRanking.add(:STEADFAST, proc { |ability, score, battler, ai|
  holder = battler.battler

  # The original flinch-triggered Speed boost still has value.
  next 2 if SteadfastResolve.used?(holder)
  next 6
})

# Fatal Precision

module FatalPrecision
  # Convert AI wrappers into actual battle objects.
  def self.real_battler(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  def self.real_move(object)
    return object.move if object.respond_to?(:move)
    return object
  end
  # Determine whether this damaging move is super effective against this target.
  def self.super_effective?(move, user, target, type = nil)
    move   = real_move(move)
    user   = real_battler(user)
    target = real_battler(target)
    return false if !move || !user || !target
    return false if !move.damagingMove?
    return false if move.is_a?(Battle::Move::OHKO)
    type = move.pbCalcType(user) if !type
    return false if !type
    effectiveness = move.pbCalcTypeMod(type, user, target)
    return Effectiveness.super_effective?(effectiveness)
  end
  # CriticalCalcFromUser does not receive the move.
  # Supply temporary move context without altering Focus Energy or stat stages.
  def self.with_move(user, move)
    previous_move = user.instance_variable_get(:@fatal_precision_move)
    begin
      user.instance_variable_set(:@fatal_precision_move, move)
      return yield
    ensure
      user.instance_variable_set(:@fatal_precision_move, previous_move)
    end
  end
end

# Accuracy: super-effective moves cannot miss through accuracy/evasion.
# Native AI also reads this handler.

Battle::AbilityEffects::AccuracyCalcFromUser.add(:FATALPRECISION, proc { |ability, mods, user, target, move, type|
  next if !FatalPrecision.super_effective?(move, user, target, type)
  mods[:base_accuracy] = 0
})

# Critical-hit stage: +1 for super-effective damaging moves.
# Target critical immunity and other restrictions are processed normally.

Battle::AbilityEffects::CriticalCalcFromUser.add(:FATALPRECISION, proc { |ability, user, target, stage|
  next stage if stage < 0 || stage > 50
  move = user.instance_variable_get(:@fatal_precision_move)
  next stage if !move
  next stage if !FatalPrecision.super_effective?(move, user, target)

  # AI prediction must not consume battle RNG.
  next stage if user.instance_variable_get(:@fatal_precision_ai_check)

  # Half-stage equivalent: 50% chance to gain one full crit stage.
  next stage + ((user.battle.pbRandom(100) < 50) ? 1 : 0)
})

# Actual critical calculation: provide the move to the ability handler.

class Battle::Move
  unless method_defined?(:fatal_precision_original_critical)
    alias_method :fatal_precision_original_critical, :pbIsCritical?
  end

  def pbIsCritical?(user, target); return FatalPrecision.with_move(user, self) do fatal_precision_original_critical(user, target) end; end
end

# Native AI: provide the same move context during critical-stage prediction.

class Battle::AI::AIMove
  unless method_defined?(:fatal_precision_original_rough_critical)
    alias_method :fatal_precision_original_rough_critical, :rough_critical_hit_stage
  end

  def rough_critical_hit_stage
    user = @ai.user.battler
    previous_check = user.instance_variable_get(:@fatal_precision_ai_check)
    begin
      user.instance_variable_set(:@fatal_precision_ai_check, true)
      return FatalPrecision.with_move(user, @move) do fatal_precision_original_rough_critical end
    ensure
      user.instance_variable_set( :@fatal_precision_ai_check, previous_check )
    end
  end
end

# Native AI: ability value based on available super-effective coverage.
KaitoAbilitySupport.rate(:FATALPRECISION, 6)
Battle::AI::Handlers::AbilityRanking.add(:FATALPRECISION, proc { |ability, score, battler, ai|
  holder = battler.battler
  next 0 if holder.fainted?
  foes = ai.battle.battlers.select do |other|
    other && !other.fainted? && holder.opposes?(other)
  end
  next score if foes.empty?
  useful = holder.moves.any? do |move|
    next false if !move || !move.damagingMove?
    foes.any? do |foe|
      FatalPrecision.super_effective?(move, holder, foe)
    end
  end
  next useful ? 8 : 3
})

# Advanced AI:
#   - Remove its ordinary low-accuracy penalty for eligible moves.
#   - Add a modest preference for the increased critical-hit chance.
#
# Native AI already uses the accuracy and critical handlers above.

class Battle::AI
  if method_defined?(:score_move_advanced)
    unless method_defined?(:fatal_precision_original_advanced_score)
      alias_method :fatal_precision_original_advanced_score, :score_move_advanced
    end

    def score_move_advanced(move, user, target, skill)
      score = fatal_precision_original_advanced_score( move, user, target, skill )
      return score if !score.is_a?(Numeric) || score <= 0
      return score if !move || !user || !target
      attacker = FatalPrecision.real_battler(user)
      defender = FatalPrecision.real_battler(target)
      attack   = FatalPrecision.real_move(move)
      return score if !attacker.hasActiveAbility?(:FATALPRECISION)
      return score if !FatalPrecision.super_effective?( attack, attacker, defender )

      # Undo the Advanced AI scorer's ordinary accuracy penalty.
      accuracy_score = score_accuracy(move, skill, user)
      score -= accuracy_score if accuracy_score < 0

      # Critical immunity still prevents the crit benefit.
      crit_blocked = defender.pbOwnSide.effects[PBEffects::LuckyChant] > 0
      if !AdvancedAI::Utilities.ignores_ability?( attacker, attack, defender )
        crit_blocked ||= defender.hasActiveAbility?(:BATTLEARMOR)
        crit_blocked ||= defender.hasActiveAbility?(:SHELLARMOR)
      end

      # Do not reward an extra crit stage when crits are impossible or
      # already guaranteed by these existing effects.
      crit_override = attack.pbCritialOverride(attacker, defender)
      already_guaranteed =
        crit_override == 1 || attacker.effects[PBEffects::LaserFocus] > 0 ||
        (
          attacker.hasActiveAbility?(:MERCILESS) && defender.poisoned?
        )
      if !crit_blocked && !already_guaranteed && crit_override != -1 && !attack.is_a?(Battle::Move::FixedDamageMove)
        score += 3
      end
      return score
    end
  end
end

# BLADEMASTER
#
# Parry:
#   20% against opposing damaging moves.
#   60% against opposing slicing moves.
#   One roll per move against each target; blocks all hits.
#
# Counter:
#   30% after a successful parry or a connected damaging hit.
#   One counter opportunity per incoming move.
#   Physical Normal-type damage, base power 25.
#   Does not consume the holder's normal action.
#
# LOAD LAST, after other battle ability patches.

module Blademaster
  PARRY_CHANCE         = 20
  SLICING_PARRY_CHANCE = 60
  COUNTER_CHANCE       = 30
  COUNTER_MOVE         = :BLADEMASTERCOUNTER
  # Helpers
  def self.real_battler(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  def self.real_move(object)
    return object.move if object.respond_to?(:move)
    return object
  end

  def self.context(battle); return battle.instance_variable_get(:@blademaster_context); end

  def self.parry_chance(move)
    move = real_move(move)
    if move.respond_to?(:slicingMove?) && move.slicingMove?
      return SLICING_PARRY_CHANCE
    end
    return PARRY_CHANCE
  end

  def self.key(move, user, target); return [ move.object_id, user.pokemon.object_id, target.pokemon.object_id ]; end
  # Eligibility; no RNG is used here.
  def self.eligible?(move, user, target, battle, predicting = false)
    move   = real_move(move)
    user   = real_battler(user)
    target = real_battler(target)
    return false if !move || !user || !target
    return false if !user.respond_to?(:effects)
    return false if !target.respond_to?(:hasActiveAbility?)
    return false if user.fainted? || target.fainted?
    return false if !user.opposes?(target)
    return false if !move.damagingMove?
    return false if !target.hasActiveAbility?(:BLADEMASTER)
    if !predicting
      return false if user.effects[PBEffects::TwoTurnAttack]
      if battle.moldBreaker && !target.hasActiveItem?(:ABILITYSHIELD)
        return false
      end
    elsif !target.hasActiveItem?(:ABILITYSHIELD)
      if defined?(AdvancedAI::Utilities) && AdvancedAI::Utilities.respond_to?(:ignores_ability?)
        return false if AdvancedAI::Utilities.ignores_ability?( user, move, target )
      elsif user.respond_to?(:hasMoldBreaker?)
        return false if user.hasMoldBreaker?
      end
    end
    return true
  end
  # Correct splash name when Blademaster is an Innate.
  def self.show_splash(battler, battle)
    previous_name  = $aamName
    previous_name2 = $aamName2
    begin
      name = GameData::Ability.get(:BLADEMASTER).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(battler)
      yield
    ensure
      battle.pbHideAbilitySplash(battler)
      $aamName  = previous_name
      $aamName2 = previous_name2
    end
  end
  # One independent parry roll per incoming move/target.
  # Only runs inside actual move execution.
  def self.try_parry(move, user, target, battle, show_message)
    ctx = context(battle)
    return false if !ctx
    return false if !eligible?(move, user, target, battle)
    event_key = key(move, user, target)
    if ctx[:parry].key?(event_key)
      return ctx[:parry][event_key]
    end
    parried = battle.pbRandom(100) < parry_chance(move)
    ctx[:parry][event_key] = parried
    return false if !parried
    if show_message
      show_splash(target, battle) do
        battle.pbDisplay( _INTL("{1} parried the attack!", target.pbThis) )
      end
    end
    register_counter(move, user, target, battle)
    return true
  end
  # Roll the independent counter chance once.
  # Queue the counter until the incoming move has finished.
  def self.register_counter(move, user, target, battle)
    ctx = context(battle)
    return if !ctx
    return if battle.instance_variable_get(:@blademaster_countering)
    return if !eligible?(move, user, target, battle)
    event_key = key(move, user, target)
    return if ctx[:counter_checked][event_key]
    ctx[:counter_checked][event_key] = true
    return if battle.pbRandom(100) >= COUNTER_CHANCE
    ctx[:queue] << [ target, user, target.pokemon, user.pokemon ]
  end
  # Resolve queued counters.
  # Do not attack a replacement Pokemon after either battler switches.
  def self.flush(battle, ctx)
    return if battle.instance_variable_get(:@blademaster_countering)
    ctx[:queue].each do |holder, attacker, holder_pokemon, attacker_pokemon|
      break if battle.decision > 0
      next if !holder.pokemon.equal?(holder_pokemon)
      next if !attacker.pokemon.equal?(attacker_pokemon)
      next if holder.fainted? || attacker.fainted?
      next if !holder.hasActiveAbility?(:BLADEMASTER)
      perform_counter(holder, attacker, battle)
    end
    ctx[:queue].clear
  end
  # Execute a single reactive strike through the engine's hit pipeline.
  #
  # Does not call pbUseMove/pbBeginTurn/pbEndTurn:
  #   - does not consume the holder's action;
  #   - does not replace its selected move;
  #   - does not alter lastRoundMoved.
  def self.perform_counter(holder, attacker, battle)
    return if !GameData::Move.exists?(COUNTER_MOVE)
    counter = Battle::Move.from_pokemon_move( battle, Pokemon::Move.new(COUNTER_MOVE) )
    old_countering = battle.instance_variable_get( :@blademaster_countering )
    old_mold_breaker = battle.moldBreaker
    original_pokemon = holder.pokemon
    old_current_move = holder.instance_variable_get(:@currentMove)

    # Preserve ongoing move sequences if a failed counter calls pbCancelMoves.
    saved_effects = {}
    [ :ParentalBond, :TwoTurnAttack, :Prankster, :FuryCutter, :Rollout, :Outrage, :Uproar, :Bide ].each do |name|
      effect = PBEffects.const_get(name)
      saved_effects[effect] = holder.effects[effect]
    end
    choice = battle.choices[holder.index]
    old_priority = choice[4] if choice
    begin
      battle.instance_variable_set(:@blademaster_countering, true)
      battle.moldBreaker = holder.hasMoldBreaker?
      holder.effects[PBEffects::ParentalBond] = 0
      holder.effects[PBEffects::TwoTurnAttack] = nil
      holder.effects[PBEffects::Prankster] = false

      # This reactive strike has ordinary priority.
      choice[4] = 0 if choice
      counter.calcType = counter.pbCalcType(holder)
      attacker.damageState.reset
      show_splash(holder, battle) do
        battle.pbDisplay( _INTL("{1} counterattacked with a swift slash!", holder.pbThis) )
      end
      targets = [attacker]
      if !holder.pbSuccessCheckAgainstTarget( counter, holder, attacker, targets )
        attacker.damageState.unaffected = true
        return
      end
      success = holder.pbProcessMoveHit( counter, holder, targets, 0, false )

      # Standard post-move effects: KO abilities, items, forced switches, etc.
      holder.pbEffectsAfterMove( holder, targets, counter, success ? 1 : 0 )
      battle.pbJudge
    ensure
      if holder.pokemon.equal?(original_pokemon)
        saved_effects.each do |effect, value|
          holder.effects[effect] = value
        end
        holder.instance_variable_set( :@currentMove, old_current_move )
      end
      choice[4] = old_priority if choice
      battle.moldBreaker = old_mold_breaker
      battle.instance_variable_set( :@blademaster_countering, old_countering )
    end
  end
  # Deterministic AI preference; never rolls battle RNG.
  def self.adjust_score(score, move, user, target, battle)
    return score if !score.is_a?(Numeric)
    return score if score <= 0
    return score if !eligible?( move, user, target, battle, true )

    # Modest heuristic for parry risk and potential retaliation.
    penalty = (parry_chance(move) == SLICING_PARRY_CHANCE) ? 18 : 6
    return [score - penalty - 3, 1].max
  end
end

# Dedicated counter move.
# Always Normal-type, single-hit, with Slash's animation.

class Battle::Move::BlademasterCounter < Battle::Move
  def pbBaseType(user); return :NORMAL; end

  def pbCalcType(user)
    @powerBoost = false
    return :NORMAL
  end

  def pbNumHits(user, targets); return 1; end

  def pbShowAnimation( id, user, targets, hitNum = 0, showAnimation = true )
    return if !showAnimation
    @battle.pbAnimation(:SLASH, user, targets, 0)
  end
end

# Real battle hooks.
# No aliases are created on previously prepended methods.

module BlademasterBattleHooks
  def pbUseMove(*args)
    previous_context = @battle.instance_variable_get( :@blademaster_context )
    ctx = { :parry           => {}, :counter_checked => {}, :queue           => [] }
    begin
      @battle.instance_variable_set(:@blademaster_context, ctx)
      result = super
      Blademaster.flush(@battle, ctx)
      return result
    ensure
      @battle.instance_variable_set( :@blademaster_context, previous_context )
    end
  end

  # A connected hit can trigger a counter even if no parry occurred.
  def pbProcessMoveHit(move, user, targets, hitNum, skipAccuracyCheck)
    result = super
    if result && move.damagingMove?
      targets.each do |target|
        next if target.damageState.unaffected
        next if target.damageState.calcDamage <= 0
        Blademaster.register_counter( move, user, target, @battle )
      end
    end
    return result
  end
end
unless Battle::Battler.ancestors.include?(BlademasterBattleHooks)
  Battle::Battler.prepend(BlademasterBattleHooks)
end

# Blademaster: hook compatible with MAG/Community alias chains.
# pbSuccessCheckAgainstTarget must NOT remain in BlademasterBattleHooks.
class Battle::Battler
  unless method_defined?(:blademaster_success_check_without_parry)
    alias_method :blademaster_success_check_without_parry, :pbSuccessCheckAgainstTarget

    def pbSuccessCheckAgainstTarget(move, user, target, targets)
      success = blademaster_success_check_without_parry( move, user, target, targets )
      return success if !success
      return success if !move.pbDamagingMove?
      if Blademaster.try_parry( move, user, target, @battle, move.pbShowFailMessages?(targets) )
        return false
      end
      return success
    end
  end
end

# Native AI.
Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[8].include?(:BLADEMASTER)
  Battle::AI::BASE_ABILITY_RATINGS[8] << :BLADEMASTER
end
Battle::AI::Handlers::AbilityRanking.add(:BLADEMASTER, proc { |ability, score, battler, ai| next score })
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
  :blademaster_parry_and_counter,
  proc { |score, move, user, target, ai, battle| next Blademaster.adjust_score( score, move, user, target, battle ) }
)

# Advanced AI's separate scoring pipeline.

module BlademasterAdvancedAI
  def score_move_advanced(move, user, target, skill)
    score = super
    return Blademaster.adjust_score( score, move, user, target, @battle )
  end
end
if Battle::AI.method_defined?(:score_move_advanced) && !Battle::AI.ancestors.include?(BlademasterAdvancedAI)
  Battle::AI.prepend(BlademasterAdvancedAI)
end

# ANTICIPATION - FIRST DANGER GUARD

module AnticipationGuard
  DAMAGE_MULTIPLIER = 0.5

  # true  = refresh protection whenever the Pokemon enters battle.
  # false = only one activation per Pokemon per battle.
  RESET_ON_SWITCH = true
  unless const_defined?(:ORIGINAL_SWITCH_IN, false)
    ORIGINAL_SWITCH_IN = Battle::AbilityEffects::OnSwitchIn[:ANTICIPATION]
  end
  # Helpers
  def self.real_battler(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  def self.real_move(object)
    return object.move if object.respond_to?(:move)
    return object
  end

  def self.storage(battle)
    data = battle.instance_variable_get(:@anticipation_guard_data)
    if !data
      data = {}
      battle.instance_variable_set(:@anticipation_guard_data, data)
    end
    return data
  end

  def self.state(target)
    target = real_battler(target)
    return nil if !target
    return nil if !target.respond_to?(:battle)
    return nil if !target.respond_to?(:pokemon)
    return nil if !target.pokemon
    data = target.battle.instance_variable_get( :@anticipation_guard_data )
    return nil if !data
    return data[target.pokemon.object_id]
  end
  # Match the original Anticipation warning criteria.
  # Record the exact move and its Pokemon owner.
  def self.scan_threats(battler, battle)
    threats = {}
    types = battler.pbTypes(true)
    battle.allOtherSideBattlers(battler.index).each do |foe|
      next if foe.fainted?
      foe.eachMove do |move|
        next if move.statusMove?
        ohko = [ "OHKO", "OHKOIce", "OHKOHitsUndergroundTarget" ].include?(move.function_code)
        if types.length > 0
          type = move.type
          if Settings::MECHANICS_GENERATION >= 6 && move.function_code == "TypeDependsOnUserIVs"
            type = pbHiddenPower(foe.pokemon)[0]
          end
          effectiveness = Effectiveness.calculate(type, *types)
          next if Effectiveness.ineffective?(effectiveness)
          next if !ohko && !Effectiveness.super_effective?(effectiveness)
        else
          next if !ohko
        end
        threats[[foe.pokemon.object_id, move.id]] = true
      end
    end
    return threats
  end

  def self.prepare(battler, battle)
    previous = state(battler)
    spent = false
    if !RESET_ON_SWITCH && previous
      spent = previous[:spent]
    end
    storage(battle)[battler.pokemon.object_id] = { :threats => scan_threats(battler, battle), :spent   => spent, :action  => nil }
  end
  # Ability bypass checks.
  def self.ignored?(move, user, target, predicting)
    return false if target.hasActiveItem?(:ABILITYSHIELD)
    if predicting
      if defined?(AdvancedAI::Utilities) && AdvancedAI::Utilities.respond_to?(:ignores_ability?)
        return AdvancedAI::Utilities.ignores_ability?( user, move, target )
      end
      return true if user.respond_to?(:hasMoldBreaker?) && user.hasMoldBreaker?
      return true if move.is_a?(Battle::Move::IgnoreTargetAbility)
      return false
    end
    return target.battle.moldBreaker
  end
  # True only for a recorded threatening move.
  # No RNG or stat changes.
  def self.eligible?(move, user, target, predicting = false)
    move   = real_move(move)
    user   = real_battler(user)
    target = real_battler(target)
    return false if !move || !user || !target
    return false if !user.respond_to?(:pokemon)
    return false if !target.respond_to?(:hasActiveAbility?)
    return false if !user.pokemon || !target.pokemon
    return false if user.fainted? || target.fainted?
    return false if !user.opposes?(target)
    return false if !move.damagingMove?
    return false if !target.hasActiveAbility?(:ANTICIPATION)
    data = state(target)
    return false if !data
    move_key = [user.pokemon.object_id, move.id]
    return false if !data[:threats][move_key]
    return false if ignored?(move, user, target, predicting)
    if predicting
      return !data[:spent]
    end
    token = target.battle.instance_variable_get( :@anticipation_guard_action )
    return false if !token
    action = [token, user.pokemon.object_id, move.id]
    return true if !data[:spent]
    return data[:action] == action
  end
  # Correct splash when Anticipation is an Innate.
  def self.show_activation(target)
    battle = target.battle
    previous_name  = $aamName
    previous_name2 = $aamName2
    begin
      name = GameData::Ability.get(:ANTICIPATION).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(target)
      battle.pbDisplay( _INTL("{1} anticipated the attack and braced itself!", target.pbThis) )
    ensure
      battle.pbHideAbilitySplash(target)
      $aamName  = previous_name
      $aamName2 = previous_name2
    end
  end
  # Called after accuracy checks and damage absorption checks.
  def self.reduce_damage(move, user, target)
    return if !eligible?(move, user, target)
    damage_state = target.damageState
    return if damage_state.unaffected
    return if damage_state.substitute
    return if damage_state.disguise || damage_state.iceFace
    return if damage_state.calcDamage <= 0
    data = state(target)
    if !data[:spent]
      token = target.battle.instance_variable_get( :@anticipation_guard_action )
      data[:spent] = true
      data[:action] = [ token, user.pokemon.object_id, move.id ]
      show_activation(target)
    end
    damage_state.calcDamage = [ (damage_state.calcDamage * DAMAGE_MULTIPLIER).round, 1 ].max
  end
end

# Preserve the existing warning, then prepare the additional protection.

Battle::AbilityEffects::OnSwitchIn.add(:ANTICIPATION, proc { |ability, battler, battle, switch_in|
  next if battler.fainted?
  original = AnticipationGuard::ORIGINAL_SWITCH_IN
  if original
    original.call(ability, battler, battle, switch_in)
  end
  AnticipationGuard.prepare(battler, battle)
})

# One action token per move usage.
# Nested/called moves receive separate tokens.

module AnticipationGuardAction
  def pbUseMove(*args)
    previous = @battle.instance_variable_get( :@anticipation_guard_action )
    begin
      @battle.instance_variable_set( :@anticipation_guard_action, Object.new )
      return super
    ensure
      @battle.instance_variable_set( :@anticipation_guard_action, previous )
    end
  end
end
unless Battle::Battler.ancestors.include?(AnticipationGuardAction)
  Battle::Battler.prepend(AnticipationGuardAction)
end

# Apply reduction before Endure, Focus Sash, Sturdy and final HP loss.
# Includes fixed-damage moves, because they also pass through pbReduceDamage.

module AnticipationGuardDamage
  def pbReduceDamage(user, target)
    AnticipationGuard.reduce_damage(self, user, target)
    return super
  end
end
unless Battle::Move.ancestors.include?(AnticipationGuardDamage)
  Battle::Move.prepend(AnticipationGuardDamage)
end

# Native AI: estimate the reduced damage without consuming protection.

module AnticipationGuardNativeAI
  def rough_damage
    damage = super
    if AnticipationGuard.eligible?( @move, @ai.user, @ai.target, true )
      return [ (damage * AnticipationGuard::DAMAGE_MULTIPLIER).round, 1 ].max
    end
    return damage
  end
end
unless Battle::AI::AIMove.ancestors.include?(AnticipationGuardNativeAI)
  Battle::AI::AIMove.prepend(AnticipationGuardNativeAI)
end

# AI ability value.
KaitoAbilitySupport.rate(:ANTICIPATION, 6)
Battle::AI::Handlers::AbilityRanking.add(:ANTICIPATION, proc { |ability, score, battler, ai|
  data = AnticipationGuard.state(battler)
  next 2 if data && data[:spent]
  next score
})

# Advanced AI's separate shared damage estimator.

module AnticipationGuardAdvancedAI
  def estimate_damage(attacker, move, defender, options = {})
    damage = super
    return damage if !damage.is_a?(Numeric) || damage <= 0
    if AnticipationGuard.eligible?( move, attacker, defender, true )
      damage *= AnticipationGuard::DAMAGE_MULTIPLIER
      return damage if options[:as_percent]
      return [damage.round, 1].max
    end
    return damage
  end
end
if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:estimate_damage)
  singleton = AdvancedAI::CombatUtilities.singleton_class
  unless singleton.ancestors.include?(AnticipationGuardAdvancedAI)
    singleton.prepend(AnticipationGuardAdvancedAI)
  end
end

# MIMICRY - Retain original-type STAB

module MimicryOriginalSTAB
  def self.real_battler(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end
  # Active ability for battle objects.
  # Also accepts Pokemon objects used by party/switch AI.
  def self.has_ability?(object, ability)
    object = real_battler(object)
    return false if !object
    if object.respond_to?(:hasActiveAbility?)
      return object.hasActiveAbility?(ability)
    end
    if object.respond_to?(:hasAbility?)
      return object.hasAbility?(ability)
    end
    return object.ability_id == ability if object.respond_to?(:ability_id)
    return false
  end
  # Original species/form types, not the battler's altered @types.
  # Terrain changes only alter the battle object's current typing.
  def self.original_types(object)
    object = real_battler(object)
    return [] if !object
    pokemon = if object.respond_to?(:pokemon) && object.pokemon
                object.pokemon
              else
                object
              end
    return [] if !pokemon.respond_to?(:types)
    return pokemon.types.compact.uniq
  end

  def self.retains_stab?(object, type)
    return false if !type
    return false if !has_ability?(object, :MIMICRY)
    return original_types(object).include?(type)
  end

  def self.stellar?(object)
    object = real_battler(object)
    return false if !object.respond_to?(:tera?)
    return false if !object.tera?
    return object.tera_type == :STELLAR
  end
  # STAB already granted by the engine/DBK Terastallization.
  def self.existing_stab(object, type)
    object = real_battler(object)
    return 1.0 if !object || !type
    adaptability = has_ability?(object, :ADAPTABILITY)
    if object.respond_to?(:tera?) && object.tera?
      adaptability = false if stellar?(object)
      if object.pbPreTeraTypes.include?(type)
        if object.typeTeraBoosted?(type)
          return adaptability ? 2.25 : 2.0
        end
        return adaptability ? 2.0 : 1.5
      end
      if object.typeTeraBoosted?(type)
        return 2.0 if adaptability
        return stellar?(object) ? 1.2 : 1.5
      end
      return 1.0
    end
    matches = if object.respond_to?(:pbHasType?)
                object.pbHasType?(type)
              elsif object.respond_to?(:types)
                object.types.include?(type)
              else
                false
              end
    return 1.0 if !matches
    return adaptability ? 2.0 : 1.5
  end

  def self.retained_stab(object)
    if has_ability?(object, :ADAPTABILITY) && !stellar?(object)
      return 2.0
    end
    return 1.5
  end
  # Add only the missing amount, preserving stronger existing Tera STAB.
  def self.extra_multiplier(object, type)
    return 1.0 if !retains_stab?(object, type)
    existing = existing_stab(object, type)
    desired  = [existing, retained_stab(object)].max
    return desired / existing
  end
end

# Actual battle damage.
# Does not modify pbHasType?, resistances, immunities or terrain eligibility.

module MimicryOriginalSTABBattle
  def pbCalcDamageMults_Type( user, target, numTargets, type, baseDmg, multipliers )
    result = super
    multipliers[:final_damage_multiplier] *= MimicryOriginalSTAB.extra_multiplier(user, type)
    return result
  end
end
unless Battle::Move.ancestors.include?(MimicryOriginalSTABBattle)
  Battle::Move.prepend(MimicryOriginalSTABBattle)
end

# Native AI damage estimation.

module MimicryOriginalSTABNativeAI
  def calc_type_mults( user, target, base_dmg, calc_type, is_critical, multipliers )
    result = super
    multipliers[:final_damage_multiplier] *= MimicryOriginalSTAB.extra_multiplier(user, calc_type)
    return result
  end
end
unless Battle::AI::AIMove.ancestors.include?(MimicryOriginalSTABNativeAI)
  Battle::AI::AIMove.prepend(MimicryOriginalSTABNativeAI)
end

# Advanced AI's shared estimator calculates ordinary STAB separately.
# Add the missing original-type STAB through its ability multiplier.

module MimicryOriginalSTABAdvancedAI
  def ability_damage_modifier(
    attacker, target, effective_type, is_physical, effectiveness,
    move = nil, uses_physical_defense = is_physical
  )
    result = super
    return result if !MimicryOriginalSTAB.retains_stab?( attacker, effective_type )
    existing = 1.0
    if AdvancedAI::Utilities.has_type?(attacker, effective_type)
      existing = 1.5
      if AdvancedAI::Utilities.ability_active?(attacker, :ADAPTABILITY)
        existing = 2.0
      end
    end
    desired = [ existing, MimicryOriginalSTAB.retained_stab(attacker) ].max
    return result * desired / existing
  end
end
if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
  singleton = AdvancedAI::CombatUtilities.singleton_class
  unless singleton.ancestors.include?(MimicryOriginalSTABAdvancedAI)
    singleton.prepend(MimicryOriginalSTABAdvancedAI)
  end
end

# Native AI ability value.
KaitoAbilitySupport.rate(:MIMICRY, 6)
Battle::AI::Handlers::AbilityRanking.add(:MIMICRY, proc { |ability, score, battler, ai| next score })

# HONEY GATHER + HONEY

module HoneyGatherPlus
  GATHER_CHANCE = 30

  def self.heal_amount(totalhp); return [totalhp / 8, 1].max; end
  # Correct ability splash when Honey Gather is an Innate.
  def self.show_splash(battler, battle)
    previous_name  = $aamName
    previous_name2 = $aamName2
    begin
      name = GameData::Ability.get(:HONEYGATHER).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(battler)
      yield
    ensure
      battle.pbHideAbilitySplash(battler)
      $aamName  = previous_name
      $aamName2 = previous_name2
    end
  end
  # Generate Honey once per round at most.
  # No initialization aliases are needed.
  def self.gather(battler, battle)
    return if battler.fainted?
    return if !battler.hasActiveAbility?(:HONEYGATHER)
    return if battler.item
    return if !GameData::Item.exists?(:HONEY)
    roll_key = [battler.pokemon.object_id, battle.turnCount]
    previous_roll = battler.instance_variable_get( :@honey_gather_last_roll )
    return if previous_roll == roll_key
    battler.instance_variable_set( :@honey_gather_last_roll, roll_key )
    return if battle.pbRandom(100) >= GATHER_CHANCE
    show_splash(battler, battle) do
      battler.item = :HONEY

      # Keep generated Honey after battle if it remains unconsumed.
      battler.setInitialItem(:HONEY) if !battler.initialItem
      battle.pbDisplay( _INTL("{1} gathered some Honey!", battler.pbThis) )
    end

    # Newly obtained Honey can activate immediately.
    battler.pbHeldItemTriggerCheck
  end
  # Eat the target's Honey, like Bug Bite/Pluck.
  # The attacker's own held item is not consumed or replaced.
  def self.eat_target_honey(user, target, move, battle)
    return if !user || !target
    return if user.fainted?
    return if !user.opposes?(target)
    return if !user.hasActiveAbility?(:HONEYGATHER)
    return if !move.damagingMove?
    return if target.damageState.unaffected
    return if target.damageState.substitute
    return if target.damageState.calcDamage <= 0
    return if !target.item || target.item.id != :HONEY
    return if target.unlosableItem?(target.item)
    if target.hasActiveAbility?(:STICKYHOLD) && !battle.moldBreaker
      return
    end
    show_splash(user, battle) do
      # Remove from the target; the attacker receives its effect directly.
      # Do not mark it as an item consumed by the target for Pickup/Recycle.
      target.pbRemoveItem
      battle.pbCommonAnimation("EatBerry", user)
      battle.pbDisplay( _INTL("{1} stole and ate {2}'s Honey!", user.pbThis, target.pbThis(true)) )

      # Explicit item argument forces consumption effects regardless of the
      # user's HP threshold or its own currently held item.
      user.pbHeldItemTriggerCheck(:HONEY, false)

      # Also allow Symbiosis to respond if Honey couldn't restore HP.
      user.pbSymbiosis
    end
  end
end

# HONEY: held-item healing.
#
# forced = true when consumed through an explicit item effect.
# Normal held activation requires HP strictly below 75%.
Battle::ItemEffects::HPHeal.add(:HONEY, proc { |item, battler, battle, forced|
  next false if battler.fainted?
  next false if !battler.canHeal?
  if !forced
    next false if battler.hp * 4 >= battler.totalhp * 3
    battle.pbCommonAnimation("EatBerry", battler)
  end
  recovered = battler.pbRecoverHP( HoneyGatherPlus.heal_amount(battler.totalhp) )
  next false if recovered <= 0
  battle.pbDisplay( _INTL("{1} restored its HP with Honey!", battler.pbThis) )
  next true
})

# HONEY: use from the Bag.
# Replace the original direct-use/Sweet Scent action.
ItemHandlers::UseFromBag.remove(:HONEY)
ItemHandlers::UseInField.remove(:HONEY)
ItemHandlers::UseOnPokemon.add(:HONEY, proc { |item, qty, pokemon, scene| next pbHPItem( pokemon, HoneyGatherPlus.heal_amount(pokemon.totalhp), scene ) }
)
ItemHandlers::CanUseInBattle.copy(:POTION, :HONEY)
ItemHandlers::BattleUseOnPokemon.add(:HONEY, proc { |item, pokemon, battler, choices, scene|
  next pbBattleHPItem( pokemon, battler, HoneyGatherPlus.heal_amount(pokemon.totalhp), scene )
})

# HONEY GATHER: additional in-battle effects.
# Does not alter def pbHoneyGather or its post-battle collection chance.

Battle::AbilityEffects::EndOfRoundGainItem.add(:HONEYGATHER, proc { |ability, battler, battle| HoneyGatherPlus.gather(battler, battle) })

Battle::AbilityEffects::OnDealingHit.add(:HONEYGATHER, proc { |ability, user, target, move, battle| HoneyGatherPlus.eat_target_honey( user, target, move, battle ) }
)

# AI ability/item values.
KaitoAbilitySupport.rate(:HONEYGATHER, 6)
Battle::AI::Handlers::AbilityRanking.add(:HONEYGATHER, proc { |ability, score, battler, ai| next score })
Battle::AI::Handlers::ItemRanking.add(:HONEY, proc { |item, score, battler, ai| next 5 })

# NOCTURNAL - Rework

module NocturnalRework
  WEATHER = :GloomMoonlight

  def self.real_battler(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  def self.has_ability?(object, ability)
    object = real_battler(object)
    return false if !object
    if object.respond_to?(:hasActiveAbility?)
      return object.hasActiveAbility?(ability)
    end
    if object.respond_to?(:hasAbility?)
      return object.hasAbility?(ability)
    end
    return object.ability_id == ability if object.respond_to?(:ability_id)
    return false
  end

  def self.stellar?(object)
    object = real_battler(object)
    return false if !object.respond_to?(:tera?)
    return false if !object.tera?
    return object.tera_type == :STELLAR
  end

  def self.granted_stab(object)
    if has_ability?(object, :ADAPTABILITY) && !stellar?(object)
      return 2.0
    end
    return 1.5
  end
  # Existing STAB from current typing and Terastallization.
  def self.existing_stab(object, type)
    object = real_battler(object)
    return 1.0 if !object || !type
    adaptability = has_ability?(object, :ADAPTABILITY)
    if object.respond_to?(:tera?) && object.tera?
      adaptability = false if stellar?(object)
      if object.pbPreTeraTypes.include?(type)
        if object.typeTeraBoosted?(type)
          return adaptability ? 2.25 : 2.0
        end
        return adaptability ? 2.0 : 1.5
      end
      if object.typeTeraBoosted?(type)
        return 2.0 if adaptability
        return stellar?(object) ? 1.2 : 1.5
      end
      return 1.0
    end
    matches = if object.respond_to?(:pbHasType?)
                object.pbHasType?(type)
              elsif object.respond_to?(:types)
                object.types.include?(type)
              else
                false
              end
    return 1.0 if !matches
    return adaptability ? 2.0 : 1.5
  end
  # Add only the missing STAB.
  # Account for the previously supplied Mimicry extension.
  def self.extra_multiplier(object, type)
    return 1.0 if type != :DARK
    return 1.0 if !has_ability?(object, :NOCTURNAL)
    existing = existing_stab(object, type)
    if defined?(MimicryOriginalSTAB) && MimicryOriginalSTAB.retains_stab?(object, type)
      existing = [ existing, MimicryOriginalSTAB.retained_stab(object) ].max
    end
    desired = [existing, granted_stab(object)].max
    return desired / existing
  end
end

# Remove Nocturnal's previous defensive effect.

Battle::AbilityEffects::DamageCalcFromTarget.remove(:NOCTURNAL)

# Double Speed during effective Gloom Moonlight.
# Air Lock/Cloud Nine suppress this through effectiveWeather.

Battle::AbilityEffects::SpeedCalc.add(:NOCTURNAL, proc { |ability, battler, mult|
  if battler.effectiveWeather == NocturnalRework::WEATHER
    next mult * 2
  end
  next mult
})

# Actual battle STAB.

module NocturnalReworkBattle
  def pbCalcDamageMults_Type( user, target, numTargets, type, baseDmg, multipliers )
    result = super
    multipliers[:final_damage_multiplier] *= NocturnalRework.extra_multiplier(user, type)
    return result
  end
end
unless Battle::Move.ancestors.include?(NocturnalReworkBattle)
  Battle::Move.prepend(NocturnalReworkBattle)
end

# Native AI STAB estimation.

module NocturnalReworkNativeAI
  def calc_type_mults( user, target, base_dmg, calc_type, is_critical, multipliers )
    result = super
    multipliers[:final_damage_multiplier] *= NocturnalRework.extra_multiplier(user, calc_type)
    return result
  end
end
unless Battle::AI::AIMove.ancestors.include?(NocturnalReworkNativeAI)
  Battle::AI::AIMove.prepend(NocturnalReworkNativeAI)
end

# Advanced AI's separate STAB estimation.

module NocturnalReworkAdvancedAI
  def ability_damage_modifier(
    attacker, target, effective_type, is_physical, effectiveness,
    move = nil, uses_physical_defense = is_physical
  )
    result = super
    return result if effective_type != :DARK
    return result if !NocturnalRework.has_ability?( attacker, :NOCTURNAL )
    existing = 1.0
    if AdvancedAI::Utilities.has_type?(attacker, effective_type)
      existing = 1.5
      if AdvancedAI::Utilities.ability_active?(attacker, :ADAPTABILITY)
        existing = 2.0
      end
    end
    if defined?(MimicryOriginalSTAB) && MimicryOriginalSTAB.retains_stab?(attacker, effective_type)
      existing = [ existing, MimicryOriginalSTAB.retained_stab(attacker) ].max
    end
    desired = [ existing, NocturnalRework.granted_stab(attacker) ].max
    return result * desired / existing
  end
end
if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
  singleton = AdvancedAI::CombatUtilities.singleton_class
  unless singleton.ancestors.include?(NocturnalReworkAdvancedAI)
    singleton.prepend(NocturnalReworkAdvancedAI)
  end
end

# AI ability value.
KaitoAbilitySupport.rate(:NOCTURNAL, 6)
Battle::AI::Handlers::AbilityRanking.add(:NOCTURNAL, proc { |ability, score, battler, ai|
  if battler.battler.effectiveWeather == NocturnalRework::WEATHER
    next 8
  end
  next score
})

# NOCTURNAL - Advanced AI compatibility patch
# Requires the existing NocturnalRework code.
module KaitoNocturnalAIPatch
  module Scorer
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0
      return value if !move.damagingMove?
      return value if !NocturnalRework.has_ability?(user, :NOCTURNAL)

      # Fixed damage and OHKO moves do not receive STAB.
      native = move.respond_to?(:move) ? move.move : move
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      function = move.function_code.to_s
      return value if function.start_with?( "FixedDamage", "OHKO", "Counter" )
      return value if [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(function)

      # These moves already use the shared estimator in Pollination.
      # Its existing Nocturnal hook supplies the bonus.
      if @battle && @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      return value if type != :DARK

      # STAB already included by Advanced AI's separate calculator.
      existing = user.pbHasType?(type) ? 1.5 : 1.0
      if user.hasActiveAbility?(:PROTEAN) || user.hasActiveAbility?(:LIBERO)
        existing = [existing, 1.5].max
      end
      if user.pbHasType?(type) && user.hasActiveAbility?(:ADAPTABILITY)
        existing = 2.0
      end

      # Match Nocturnal's intended STAB, including Terastallization.
      desired = [ existing, NocturnalRework.existing_stab(user, type), NocturnalRework.granted_stab(user) ].max
      return [(value * desired / existing).round, 1].max
    end
  end

  def self.install!
    return if !defined?(NocturnalRework)
    return if !defined?(AdvancedAI::CombatUtilities)
    return if !Battle::AI.method_defined?(:calculate_rough_damage)

    # Install the existing shared-estimator hook if its initial
    # installation was skipped because of plugin load order.
    if defined?(NocturnalReworkAdvancedAI) && AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(NocturnalReworkAdvancedAI)
        singleton.prepend(NocturnalReworkAdvancedAI)
      end
    end
    unless Battle::AI.ancestors.include?(KaitoNocturnalAIPatch::Scorer)
      Battle::AI.prepend(KaitoNocturnalAIPatch::Scorer)
    end
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoNocturnalAIPatch.install!
      super
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoNocturnalAIPatch::BattleConstruction )
  Battle.singleton_class.prepend( KaitoNocturnalAIPatch::BattleConstruction )
end

# SPARE SCALES

module SpareScales
  STATS = [:DEFENSE, :SPECIAL_DEFENSE].freeze

  def self.activate(user, move, battle)
    return if user.fainted?
    return if !user.hasActiveAbility?(:SPARESCALES)
    return if move.calcType != :BUG
    return if user.effects[PBEffects::TwoTurnAttack]
    return if !STATS.any? do |stat|
      user.pbCanRaiseStatStage?(stat, user)
    end
    previous_name  = $aamName
    previous_name2 = $aamName2
    begin
      name = GameData::Ability.get(:SPARESCALES).name
      $aamName  = name
      $aamName2 = name
      battle.pbShowAbilitySplash(user)
      STATS.each do |stat|
        user.pbRaiseStatStageByAbility(stat, 1, user, false)
      end
    ensure
      battle.pbHideAbilitySplash(user)
      $aamName  = previous_name
      $aamName2 = previous_name2
    end
  end
  # Deterministic AI preference. Does not activate the ability or change stages.
  def self.adjust_ai_score(score, move, user)
    return score if !score.is_a?(Numeric) || score <= 0
    return score if !move || !user
    holder = user.respond_to?(:battler) ? user.battler : user
    attack = move.respond_to?(:move) ? move.move : move
    return score if !holder.respond_to?(:hasActiveAbility?)
    return score if holder.fainted?
    return score if !holder.hasActiveAbility?(:SPARESCALES)
    type = if move.respond_to?(:rough_type)
             move.rough_type
           elsif defined?(AdvancedAI::CombatUtilities)
             AdvancedAI::CombatUtilities.resolve_move_type(holder, attack)
           else
             attack.pbCalcType(holder)
           end
    return score if type != :BUG
    if holder.hasActiveAbility?(:CONTRARY)
      STATS.each do |stat|
        score -= 8 if holder.pbCanLowerStatStage?(stat, holder)
      end
    else
      STATS.each do |stat|
        score += 8 if holder.pbCanRaiseStatStage?(stat, holder)
      end
    end
    return score
  end
end

# Actual effect: after the entire move finishes.

Battle::AbilityEffects::OnEndOfUsingMove.add(:SPARESCALES, proc { |ability, user, targets, move, battle| SpareScales.activate(user, move, battle) }
)

# Native AI ability value.
KaitoAbilitySupport.rate(:SPARESCALES, 8)
Battle::AI::Handlers::AbilityRanking.add(:SPARESCALES, proc { |ability, score, battler, ai|
  next 0 if !battler.check_for_move { |move| move.type == :BUG }
  next score
})

# Native AI move preference.
Battle::AI::Handlers::GeneralMoveScore.add(
  :spare_scales_defensive_boost,
  proc { |score, move, user, ai, battle| next SpareScales.adjust_ai_score(score, move, user) }
)

# Advanced AI's separate scoring pipeline.

module SpareScalesAdvancedAI
  def score_move_advanced(move, user, target, skill)
    score = super
    return SpareScales.adjust_ai_score(score, move, user)
  end
end
if Battle::AI.method_defined?(:score_move_advanced) && !Battle::AI.ancestors.include?(SpareScalesAdvancedAI)
  Battle::AI.prepend(SpareScalesAdvancedAI)
end

# INTIMIDATE / TERROR SOWER - Synchronization patch
#
# - Intimidate lowers Attack.
# - Terror Sower lowers Special Attack.
# - Each ability activates once per switch-in.
# - Supports both abilities being active together as Innates.
# - Substitute blocks before Contrary is checked.
# - Overwhelm blocks both abilities before any stat change.
# - Preserves Rattled, Run Away, Adrenaline Orb and stat-loss reactions.
# - Guard Dog raises ATTACK against either ability.
#
# LOAD LAST, after other ability and Advanced AI patches.

module IntimidationSync
  STATS = { :INTIMIDATE => :ATTACK, :TERRORSOWER => :SPECIAL_ATTACK }.freeze
  OVERWHELM = defined?(OVERWHELM_ABILITY) ? OVERWHELM_ABILITY : :OVERWHELM
  IMMUNITIES = [ :OBLIVIOUS, :OWNTEMPO, :INNERFOCUS, :SCRAPPY ].freeze
  # Correct splash name for primary abilities and Innates.
  def self.with_splash(holder, ability)
    battle = holder.battle
    old_name  = $aamName
    old_name2 = $aamName2
    begin
      $aamName = $aamName2 = GameData::Ability.get(ability).name
      battle.pbShowAbilitySplash(holder)
      yield
    ensure
      battle.pbHideAbilitySplash(holder)
      $aamName  = old_name
      $aamName2 = old_name2
    end
  end

  def self.blocked_message(target); target.battle.pbDisplay( _INTL("{1} is unaffected!", target.pbThis) ); end
  # Shared intimidation checks.
  #
  # Uses the ordinary stat-change flow after dedicated immunity checks.
  # Avoids older Guard Dog aliases on pbLowerStatStageByAbility that only
  # inspect the source's primary ability.
  def self.apply(source, target, stat)
    return false if target.fainted?
    battle = source.battle
    old_mold = battle.moldBreaker
    begin
      # These are ability effects, not Mold Breaker attacks.
      battle.moldBreaker = false

      # Substitute must block even if the target has Contrary.
      if target.effects[PBEffects::Substitute] > 0
        battle.pbDisplay( _INTL("{1} is protected by its substitute!", target.pbThis) )
        return false
      end
      immune = [OVERWHELM]
      immune += IMMUNITIES if Settings::MECHANICS_GENERATION >= 8
      blocker = immune.find do |id|
        target.hasActiveAbility?(id)
      end
      if blocker
        with_splash(target, blocker) do
          blocked_message(target)
        end
        return false
      end

      # Match Gen 9's dedicated Intimidate item-immunity check.
      if !target.hasActiveAbility?(:CONTRARY) && target.itemActive?
        if Battle::ItemEffects.triggerStatLossImmunity( target.item, target, stat, battle, true )
          return false
        end
      end

      # Guard Dog keeps its original Attack boost for BOTH effects.
      if target.hasActiveAbility?(:GUARDDOG)
        changed = false
        with_splash(target, :GUARDDOG) do
          changed = target.pbRaiseStatStageByAbility( :ATTACK, 1, target, false )
        end
        return changed
      end

      # Handles Mist, general ability immunity, Clear Amulet, Contrary,
      # Simple, Mirror Armor and normal stat-stage limits.
      return false if !target.pbCanLowerStatStage?( stat, source, nil, true )

      # Keeps Defiant, Competitive and other normal stat-loss reactions.
      return target.pbLowerStatStage(stat, 1, source)
    ensure
      battle.moldBreaker = old_mold
    end
  end
  # Adrenaline Orb eligibility follows Intimidate's stage-limit rules.
  def self.item_can_trigger?(target, stat)
    if target.hasActiveAbility?(:GUARDDOG)
      return !target.statStageAtMax?(:ATTACK)
    elsif target.hasActiveAbility?(:CONTRARY)
      return !target.statStageAtMax?(stat)
    end
    return !target.statStageAtMin?(stat)
  end
  # Entry activation.
  # Tracks Intimidate and Terror Sower separately.
  def self.activate(ability, source, battle)
    return if source.fainted?
    return if !source.hasActiveAbility?(ability)
    used = source.instance_variable_get(:@intimidation_sync_used)
    if !used || used[:pokemon] != source.pokemon.object_id
      used = { :pokemon => source.pokemon.object_id }
      source.instance_variable_set( :@intimidation_sync_used, used )
    end
    return if used[ability]
    used[ability] = true
    old_mold = battle.moldBreaker
    begin
      battle.moldBreaker = false
      with_splash(source, ability) do
        battle.allOtherSideBattlers(source.index).each do |target|
          break if source.fainted?
          next if target.fainted?
          next if !target.near?(source)
          check_item = item_can_trigger?( target, STATS[ability] )
          changed = apply(source, target, STATS[ability])

          # Includes Rattled and the existing Run Away +2 Speed handler.
          if changed && !target.fainted?
            target.pbAbilitiesOnIntimidated
          end

          # As with ordinary Intimidate, Adrenaline Orb can activate
          # even if the attempted stat drop is blocked.
          if check_item && !target.fainted?
            target.pbItemOnIntimidatedCheck
          end
        end
      end
    ensure
      battle.moldBreaker = old_mold
    end
  end
  # Read the unlocked abilities used by the Innate plugin.
  def self.party_has?(pokemon, ability)
    return true if pokemon.hasAbility?(ability)
    if pokemon.respond_to?(:set_innate_limits) && pokemon.respond_to?(:active_innates) && pokemon.active_innates
      return pokemon.set_innate_limits.include?(ability)
    end
    return false
  end
  # Deterministic AI switching heuristic.
  # Does not change stages, activate abilities or use battle RNG.
  def self.foe_score(foe, stat)
    return 0 if foe.fainted?
    return 0 if foe.effects[PBEffects::Substitute] > 0
    return 0 if foe.hasActiveAbility?(OVERWHELM)
    if Settings::MECHANICS_GENERATION >= 8
      return 0 if IMMUNITIES.any? do |id|
        foe.hasActiveAbility?(id)
      end
    end
    return 0 if foe.hasActiveItem?(:CLEARAMULET)
    if foe.hasActiveAbility?(:GUARDDOG)
      return foe.statStageAtMax?(:ATTACK) ? 0 : -12
    end
    if foe.hasActiveAbility?(:CONTRARY)
      return foe.statStageAtMax?(stat) ? 0 : -10
    end
    return 0 if foe.statStageAtMin?(stat)
    return 0 if foe.pbOwnSide.effects[PBEffects::Mist] > 0
    if [:CLEARBODY, :WHITESMOKE, :FULLMETALBODY].any? do |id|
      foe.hasActiveAbility?(id)
    end
      return 0
    end
    if stat == :ATTACK && foe.hasActiveAbility?(:HYPERCUTTER)
      return 0
    end
    if foe.pbHasType?(:GRASS)
      protectors = [foe] + foe.allAllies.to_a
      return 0 if protectors.any? do |b|
        b.hasActiveAbility?(:FLOWERVEIL)
      end
    end
    category = (stat == :ATTACK) ? 0 : 1
    relevant = foe.moves.any? do |move|
      move && move.damagingMove? && move.category == category
    end
    score = relevant ? 12 : 3
    score -= 14 if foe.hasActiveAbility?(:DEFIANT)
    score -= 14 if foe.hasActiveAbility?(:COMPETITIVE)
    score -= 12 if foe.hasActiveAbility?(:MIRRORARMOR)
    score -= 10 if foe.hasActiveAbility?(:RUNAWAY)
    if Settings::MECHANICS_GENERATION >= 8 && foe.hasActiveAbility?(:RATTLED)
      score -= 5
    end
    score -= 4 if foe.hasActiveItem?(:ADRENALINEORB)
    return score
  end

  def self.switch_bonus( battle, index, pokemon, abilities = STATS.keys )
    return 0 if battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS)
    score = 0
    abilities.each do |ability|
      next if !party_has?(pokemon, ability)
      battle.allOtherSideBattlers(index).each do |foe|
        holder = battle.battlers[index]
        next if holder && !foe.near?(holder)
        score += foe_score(foe, STATS[ability])
      end
    end
    return score
  end
end

# Reset activation only when initializing a new field appearance.
# No aliases are created on previously prepended methods.

module IntimidationSyncBattler
  def pbInitialize(*args)
    @intimidation_sync_used = nil
    return super
  end

  # Also supports existing callers such as Warrior Dancer.
  def pbLowerAttackStatStageIntimidate(source); return IntimidationSync.apply(source, self, :ATTACK); end

  def pbLowerSpecialAttackStatStageIntimidate(source); return IntimidationSync.apply(source, self, :SPECIAL_ATTACK); end
end
unless Battle::Battler.ancestors.include?(IntimidationSyncBattler)
  Battle::Battler.prepend(IntimidationSyncBattler)
end

# Replace the old entry handlers, including the old Run Away wrapper.
# Run Away now triggers through pbAbilitiesOnIntimidated instead.
IntimidationSync::STATS.each_key do |id|
  Battle::AbilityEffects::OnSwitchIn.add(id, proc { |ability, battler, battle, switch_in| IntimidationSync.activate(ability, battler, battle) }
  )
end

# Overwhelm now blocks BEFORE the drop.
# Remove its old after-drop notification handler.
Battle::AbilityEffects::OnIntimidated.remove( IntimidationSync::OVERWHELM )

# Native AI ability value.
IntimidationSync::STATS.each_key do |id|
  Battle::AI::BASE_ABILITY_RATINGS.each_value do |ids|
    ids.delete(id)
  end
  Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
  Battle::AI::BASE_ABILITY_RATINGS[7] << id
  Battle::AI::Handlers::AbilityRanking.add(id, proc { |ability, score, battler, ai|
      value = 0
      ai.battle.allOtherSideBattlers(battler.index).each do |foe|
        value += IntimidationSync.foe_score( foe, IntimidationSync::STATS[ability] )
      end
      next value < 0 ? 1 : score
    })
end

# Native AI replacement scoring.
# Existing hazard damage estimates remain unchanged.

module IntimidationSyncAI
  def rate_replacement_pokemon(index, pokemon, score)
    result = super
    return result if !result.is_a?(Numeric)
    return result + IntimidationSync.switch_bonus( @battle, index, pokemon )
  end
end
unless Battle::AI.ancestors.include?(IntimidationSyncAI)
  Battle::AI.prepend(IntimidationSyncAI)
end

# Advanced AI's separate detailed switching pipeline.
# Its existing Intimidate bonus is kept; add Terror Sower evaluation.

module IntimidationSyncAdvancedAI
  def evaluate_switch_candidate_detailed(pokemon, current_user, skill)
    result = super
    return result if !result.is_a?(Numeric)
    index = get_battler_index(current_user)
    return result + IntimidationSync.switch_bonus( @battle, index, pokemon, [:TERRORSOWER] )
  end
end
if Battle::AI.method_defined?(:evaluate_switch_candidate_detailed) && !Battle::AI.ancestors.include?(IntimidationSyncAdvancedAI)
  Battle::AI.prepend(IntimidationSyncAdvancedAI)
end

# AMPHIBIOUS
# Water/Poison/Ground moves gain STAB regardless of the user's typing.
# Swamp Terrain immunity is handled in ExtendedTerrains below.
module AmphibiousAbility
  TYPES = [:WATER, :POISON, :GROUND].freeze

  def self.real(object); return object.respond_to?(:battler) ? object.battler : object; end

  def self.active?(object); return MimicryOriginalSTAB.has_ability?(real(object), :AMPHIBIOUS); end

  def self.granted_stab(object); return MimicryOriginalSTAB.retained_stab(real(object)); end

  # Only grant the missing STAB.
  # Preserve stronger Tera STAB and avoid stacking with Mimicry.
  def self.native_factor(object, type)
    return 1.0 if !TYPES.include?(type) || !active?(object)
    existing = MimicryOriginalSTAB.existing_stab(object, type)
    if MimicryOriginalSTAB.retains_stab?(object, type)
      existing = [ existing, MimicryOriginalSTAB.retained_stab(object) ].max
    end
    return [existing, granted_stab(object)].max / existing
  end

  # Advanced AI has separate STAB calculations.
  def self.advanced_factor(object, type, separate = false)
    return 1.0 if !TYPES.include?(type) || !active?(object)
    battler = real(object)
    utilities = AdvancedAI::Utilities
    existing = utilities.has_type?(battler, type) ? 1.5 : 1.0
    if existing > 1.0 && utilities.ability_active?(battler, :ADAPTABILITY)
      existing = 2.0
    end
    if separate
      if utilities.ability_active?(battler, :PROTEAN) || utilities.ability_active?(battler, :LIBERO)
        existing = [existing, 1.5].max
      end
    elsif MimicryOriginalSTAB.retains_stab?(battler, type)
      existing = [ existing, MimicryOriginalSTAB.retained_stab(battler) ].max
    end
    return [existing, granted_stab(battler)].max / existing
  end

  module BattleMoveHooks
    def pbCalcDamageMults_Type(user, target, numTargets, type, baseDmg, mults)
      result = super
      mults[:final_damage_multiplier] *= AmphibiousAbility.native_factor(user, type)
      return result
    end
  end

  module NativeAIHooks
    def calc_type_mults(user, target, base_dmg, type, critical, mults)
      result = super
      mults[:final_damage_multiplier] *= AmphibiousAbility.native_factor(user, type)
      return result
    end
  end

  module AdvancedCombatHooks
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      result = super
      return result * AmphibiousAbility.advanced_factor(attacker, type)
    end
  end

  module AdvancedScorerHooks
    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = super
      return result if !move || !user || !target || result <= 0
      native = move.respond_to?(:move) ? move.move : move
      return result if native.is_a?(Battle::Move::FixedDamageMove)
      return result if native.function_code.start_with?("OHKO")
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      factor = AmphibiousAbility.advanced_factor(user, type, true)
      return result if factor == 1.0
      return [(result * factor).round, 1].max
    end

    def score_stab_bonus(move, user)
      score = super
      return score if !move.damagingMove?
      return score if !AmphibiousAbility.active?(user)
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      return AmphibiousAbility::TYPES.include?(type) ? [score, 20].max : score
    end
  end

  # Install after all plugins have finished loading to avoid alias recursion.
  def self.install!
    return if @installed
    unless Battle::Move.ancestors.include?(BattleMoveHooks)
      Battle::Move.prepend(BattleMoveHooks)
    end
    unless Battle::AI::AIMove.ancestors.include?(NativeAIHooks)
      Battle::AI::AIMove.prepend(NativeAIHooks)
    end
    if defined?(AdvancedAI::CombatUtilities)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(AdvancedCombatHooks)
        singleton.prepend(AdvancedCombatHooks)
      end
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage)
      unless Battle::AI.ancestors.include?(AdvancedScorerHooks)
        Battle::AI.prepend(AdvancedScorerHooks)
      end
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      AmphibiousAbility.install!
      super(*args, &block)
    end
  end
end
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:AMPHIBIOUS)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :AMPHIBIOUS
end
unless Battle.singleton_class.ancestors.include?( AmphibiousAbility::BattleConstruction )
  Battle.singleton_class.prepend(AmphibiousAbility::BattleConstruction)
end

# AIR BLOWER
# Sets Tailwind for 4 turns upon entering battle.
Battle::AbilityEffects::OnSwitchIn.add(:AIRBLOWER, proc { |ability, battler, battle, switch_in|
  next if battler.fainted?
  next if !battler.hasActiveAbility?(:AIRBLOWER)
  battle.pbShowAbilitySplash(battler)
  battler.pbOwnSide.effects[PBEffects::Tailwind] = 4
  battle.pbAnimation(:TAILWIND, battler, [battler])
  battle.pbDisplay( _INTL("The Tailwind blew from behind {1}!", battler.pbTeam(true)) )
  battle.pbHideAbilitySplash(battler)
})

# Native AI ability rating.
Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:AIRBLOWER)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :AIRBLOWER
end

# GIANT WINGS
module GiantWingsAbility
  WING_MOVES = [ :WINGATTACK, :STEELWING, :DUALWINGBEAT, :OBLIVIONWING, :ESPERWING, :BLAZINGWINGS ].freeze

  def self.active?(object)
    battler = object.respond_to?(:battler) ? object.battler : object
    return false if !battler
    if battler.respond_to?(:hasActiveAbility?)
      return battler.hasActiveAbility?(:GIANTWINGS)
    end
    return battler.ability_id == :GIANTWINGS if battler.respond_to?(:ability_id)
    return false
  end

  def self.boosted_move?(move)
    return false if !move
    data = GameData::Move.try_get(move.id)
    return false if !data || data.category == 2
    return WING_MOVES.include?(data.id) || data.has_flag?("Wind") || data.has_flag?("Wing")
  end

  # Preserve the existing Tailwind effects, including Gen 9 ability triggers.
  module TailwindHook
    def pbEffectGeneral(user)
      result = super
      if GiantWingsAbility.active?(user) && user.pbOwnSide.effects[PBEffects::Tailwind] > 0
        user.pbOwnSide.effects[PBEffects::Tailwind] = 6
      end
      return result
    end
  end

  # Advanced AI: shared damage estimator.
  module AdvancedCombatHook
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      result = super
      if GiantWingsAbility.active?(attacker) && GiantWingsAbility.boosted_move?(move)
        result *= 1.3
      end
      return result
    end
  end

  # Advanced AI: separate move damage estimator.
  module AdvancedScorerHook
    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = super
      return result if result <= 0 || !GiantWingsAbility.active?(user)
      return result if !GiantWingsAbility.boosted_move?(move)
      native = ExtendedTerrains::Advanced.native_move(move, user)
      return result if native.is_a?(Battle::Move::FixedDamageMove)
      return result if native.function_code.start_with?("OHKO")
      return [(result * 1.3).round, 1].max
    end
  end

  # Delay installation until all plugin aliases have finished loading.
  def self.install!
    return if @installed
    Battle::Move::StartUserSideDoubleSpeed.prepend(TailwindHook)
    if defined?(AdvancedAI::CombatUtilities)
      AdvancedAI::CombatUtilities.singleton_class.prepend( AdvancedCombatHook )
    end
    if defined?(ExtendedTerrains::Advanced) && Battle::AI.method_defined?(:calculate_rough_damage)
      Battle::AI.prepend(AdvancedScorerHook)
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      GiantWingsAbility.install!
      super(*args, &block)
    end
  end
end

# Actual battle damage and native AI ability damage calculation.
Battle::AbilityEffects::DamageCalcFromUser.add(:GIANTWINGS, proc { |ability, user, target, move, mults, power, type|
  next if !GiantWingsAbility.active?(user)
  next if !GiantWingsAbility.boosted_move?(move)
  mults[:power_multiplier] *= 1.3
})
Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:GIANTWINGS)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :GIANTWINGS
end
unless Battle.singleton_class.ancestors.include?( GiantWingsAbility::BattleConstruction )
  Battle.singleton_class.prepend(GiantWingsAbility::BattleConstruction)
end

# KEEN EYE
# Prevents Accuracy loss through its existing StatLossImmunity handler.
# Ignores positive Evasion stages and boosts move accuracy.
Battle::AbilityEffects::AccuracyCalcFromUser.add(:KEENEYE, proc { |ability, mods, user, target, move, type|
  next if !user.hasActiveAbility?(:KEENEYE)

  # Ignore the target's Evasion boosts.
  mods[:evasion_stage] = 0 if mods[:evasion_stage] > 0

  # Increase the user's move accuracy.
  mods[:accuracy_multiplier] *= 1.2
})

# TANGLED FEET - Rework

# Replace the original accuracy handler.
Battle::AbilityEffects::AccuracyCalcFromTarget.add(:TANGLEDFEET, proc { |ability, mods, user, target, move, type|
  next if !target.hasActiveAbility?(:TANGLEDFEET)
  next if target.effects[PBEffects::Confusion] <= 0
  mods[:accuracy_multiplier] *= 0.5
})

module TangledFeetRework
  module BattlerHook
    def pbConfusionDamage(msg)
      return super unless hasActiveAbility?(:TANGLEDFEET)
      @battle.pbShowAbilitySplash(self)
      @battle.pbDisplay( _INTL("{1} avoided hurting itself in confusion!", pbThis) )
      @battle.pbHideAbilitySplash(self)
      return
    end
  end

  # Install after all plugins, including MAG, have loaded.
  def self.install!
    return if @installed
    unless Battle::Battler.ancestors.include?(BattlerHook)
      Battle::Battler.prepend(BattlerHook)
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      TangledFeetRework.install!
      super(*args, &block)
    end
  end
end
unless Battle.singleton_class.ancestors.include?( TangledFeetRework::BattleConstruction )
  Battle.singleton_class.prepend(TangledFeetRework::BattleConstruction)
end

Battle::AbilityEffects::DamageCalcFromUser.add(:TANGLEDFEET, proc { |ability, user, target, move, mults, power, type|
  next if !user.hasActiveAbility?(:TANGLEDFEET)
  next if user.effects[PBEffects::Confusion] <= 0
  next if !move.damagingMove?
  mults[:final_damage_multiplier] *= 1.25
})

# BIG PECKS - Contact damage boost
Battle::AbilityEffects::DamageCalcFromUser.add(:BIGPECKS, proc { |ability, user, target, move, mults, power, type|
  next if !user.hasActiveAbility?(:BIGPECKS)
  next if !move.damagingMove?
  next if !move.contactMove?
  mults[:final_damage_multiplier] *= 1.15
})

# THICK FLOSS
# Reduces damage from supereffective moves by 25%.
Battle::AbilityEffects::DamageCalcFromTarget.copy(:FILTER, :THICKFLOSS)

# THICK FLOSS - Advanced AI integration
module ThickFlossAI
  def self.real(object); return object.respond_to?(:battler) ? object.battler : object; end

  def self.factor(user, target, move, effectiveness)
    return 1.0 if !user || !target
    return 1.0 if !Effectiveness.super_effective?(effectiveness)
    source   = real(user)
    defender = real(target)
    return 1.0 if !AdvancedAI::Utilities.ability_active?( defender, :THICKFLOSS )
    return 1.0 if AdvancedAI::Utilities.ignores_ability?( source, move, defender )
    return 0.75
  end

  # Shared damage estimator.
  module SharedDamageHook
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      result = super
      return result * ThickFlossAI.factor( attacker, target, move, effectiveness )
    end
  end

  # Separate damage estimator used when choosing moves.
  module MoveScorerHook
    def calculate_rough_damage(move, user, target, override_bp = nil)
      result = super
      return result if !move || !user || !target || result <= 0

      # These moves use the shared estimator in Pollination Terrain.
      # Avoid applying the same reduction twice.
      if defined?(ExtendedTerrains::AdvancedScorerHooks) && @battle.field.terrain == :Pollination &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return result
      end
      native = ExtendedTerrains::Advanced.native_move(move, user)
      return result if !native.damagingMove?
      return result if native.is_a?(Battle::Move::FixedDamageMove)
      return result if native.function_code.start_with?("OHKO")
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      effectiveness = AdvancedAI::CombatUtilities.move_type_effectiveness( move, user, target, type )
      factor = ThickFlossAI.factor( user, target, native, effectiveness )
      return result if factor == 1.0
      return [(result * factor).round, 1].max
    end
  end

  # Install after all plugins have finished loading.
  def self.install!
    return if @installed
    return if !defined?(AdvancedAI::CombatUtilities)
    singleton = AdvancedAI::CombatUtilities.singleton_class
    unless singleton.ancestors.include?(SharedDamageHook)
      singleton.prepend(SharedDamageHook)
    end
    if defined?(ExtendedTerrains::Advanced) && Battle::AI.method_defined?(:calculate_rough_damage)
      unless Battle::AI.ancestors.include?(MoveScorerHook)
        Battle::AI.prepend(MoveScorerHook)
      end
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      ThickFlossAI.install!
      super(*args, &block)
    end
  end
end

# Native AI ability rating.
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:THICKFLOSS)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :THICKFLOSS
end
unless Battle.singleton_class.ancestors.include?( ThickFlossAI::BattleConstruction )
  Battle.singleton_class.prepend(ThickFlossAI::BattleConstruction)
end

# GRAND MANE - Contact resistance and wind weakness
Battle::AbilityEffects::DamageCalcFromTarget.add(:GRANDMANE, proc { |ability, user, target, move, mults, power, type|
  next if !target.hasActiveAbility?(:GRANDMANE)
  next if !move.damagingMove?
  mults[:final_damage_multiplier] *= 0.5 if move.pbContactMove?(user)
  mults[:final_damage_multiplier] *= 2.0 if move.windMove?
})

# GRAND MANE - AI
# Extends the shared helper used by both Thick Floss AI prediction paths.
module GrandManeAIExtension
  def factor(user, target, move, effectiveness)
    result = super
    return result if !user || !target || !move
    source    = ThickFlossAI.real(user)
    defender  = ThickFlossAI.real(target)
    utilities = AdvancedAI::Utilities
    return result if !utilities.ability_active?(defender, :GRANDMANE)
    return result if utilities.ignores_ability?(source, move, defender)
    native = move.respond_to?(:move) ? move.move : move
    data = GameData::Move.try_get(native.id)
    return result if !data || data.category == 2
    contact = if native.respond_to?(:pbContactMove?) && source.respond_to?(:hasActiveAbility?)
                native.pbContactMove?(source)
              else
                data.has_flag?("Contact") && !utilities.ability_active?(source, :LONGREACH) &&
                  !(data.has_flag?("Punching") && utilities.item_active?(source, :PUNCHINGGLOVE))
              end
    result *= 0.5 if contact
    result *= 2.0 if data.has_flag?("Wind")
    return result
  end
end
unless ThickFlossAI.singleton_class.ancestors.include?( GrandManeAIExtension )
  ThickFlossAI.singleton_class.prepend(GrandManeAIExtension)
end
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:GRANDMANE)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :GRANDMANE
end

# DUST CLOUD
# Uses Sand Attack upon entry without consuming the regular action.
module DustCloudAbility
  MOVE = :SANDATTACK
  TURN_VARS = [
    :@lastRoundMoved, :@currentMove, :@lastRegularMoveUsed,
    :@lastRegularMoveTarget, :@lastMoveFailed, :@powerMoveIndex,
    :@lastMoveUsedIsZMove, :@turnCount
  ].freeze
  TURN_EFFECTS = [
    :TwoTurnAttack, :Outrage, :Rollout, :Uproar, :Bide,
    :FuryCutter, :ProtectRate, :Metronome, :ChoiceBand,
    :Truant, :ParentalBond, :Prankster
  ].freeze

  def self.targets(user, battle); return battle.allOtherSideBattlers(user.index).select do |b| !b.fainted? && b.near?(user) end; end

  # Only affects the temporary Sand Attack object.
  module MoveHook
    def pbChangeUsageCounters(user, specialUsage)
      # Don't reset regular-turn move chains or Fusion flags.
    end
  end

  module BattlerHook
    def dust_cloud_virtual?; return @dust_cloud_owner && @dust_cloud_owner.equal?(pokemon); end

    def pbBeginTurn(choice)
      return if dust_cloud_virtual?
      super
    end

    def pbEndTurn(choice)
      return if dust_cloud_virtual?
      super
    end

    def pbCancelMoves(*args)
      return if dust_cloud_virtual?
      super
    end

    def usingMultiTurnAttack?
      return false if dust_cloud_virtual?
      super
    end

    # This is an ability-triggered move, not a trainer command.
    def pbObedienceCheck?(choice)
      return true if dust_cloud_virtual?
      super
    end

    # Keep normal restrictions such as Taunt.
    def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
      if dust_cloud_virtual? && move.id == DustCloudAbility::MOVE
        specialUsage = false
      end
      super(move, commandPhase, showMessages, specialUsage)
    end

    def pbTryUseMove(choice, move, specialUsage, skipAccuracyCheck)
      unless dust_cloud_virtual? && move.id == DustCloudAbility::MOVE
        return super
      end
      original      = pokemon
      old_status    = status
      old_count     = statusCount
      old_confusion = effects[PBEffects::Confusion]
      old_truant    = effects[PBEffects::Truant]
      begin
        # Run normal status checks without advancing their turn counters.
        self.statusCount += 1 if old_status == :SLEEP
        effects[PBEffects::Confusion] += 1 if old_confusion > 0
        return super(choice, move, specialUsage, false)
      ensure
        if pokemon.equal?(original) && !fainted?
          if old_status == :SLEEP && status == :SLEEP
            self.statusCount = old_count
          end
          if old_confusion > 0 && effects[PBEffects::Confusion] > 0
            effects[PBEffects::Confusion] = old_confusion
          end
          effects[PBEffects::Truant] = old_truant
        end
      end
    end

    # Called moves normally skip accuracy; Dust Cloud must check normally.
    def pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
      if dust_cloud_virtual? && move.id == DustCloudAbility::MOVE
        skipAccuracyCheck = false
      end
      super(move, user, target, skipAccuracyCheck)
    end
  end

  def self.trigger(user, battle)
    return if user.fainted? || battle.decision != 0
    return if !user.hasActiveAbility?(:DUSTCLOUD)
    return if user.dust_cloud_virtual?
    foes = targets(user, battle)
    return if foes.empty?
    target = foes[battle.pbRandom(foes.length)]
    original   = user.pokemon
    old_owner  = user.instance_variable_get(:@dust_cloud_owner)
    old_choice = battle.choices[user.index].dup
    old_mold   = battle.moldBreaker
    old_names  = [$aamName, $aamName2]
    saved_vars = TURN_VARS.map do |name|
      [ name, user.instance_variable_defined?(name), user.instance_variable_get(name) ]
    end
    saved_effects = TURN_EFFECTS.filter_map do |name|
      next if !PBEffects.const_defined?(name)
      key = PBEffects.const_get(name)
      [key, user.effects[key]]
    end
    begin
      user.instance_variable_set(:@dust_cloud_owner, original)
      battle.pbShowAbilitySplash(user)
      battle.pbHideAbilitySplash(user)
      move = Battle::Move.from_pokemon_move( battle, Pokemon::Move.new(MOVE) )
      move.pp = -1
      move.singleton_class.prepend(MoveHook)

      # Calculate this move's priority for normal defensive interactions.
      user.effects[PBEffects::Prankster] = false
      priority = move.pbPriority(user)
      if user.abilityActive?
        priority = Battle::AbilityEffects.triggerPriorityChange( user.ability, user, move, priority )
      end
      choice = [:UseMove, -1, move, target.index, priority]
      battle.choices[user.index] = choice

      # Use the real move pipeline without consuming PP.
      user.pbUseMove(choice, true)
    ensure
      # Don't restore the previous occupant's action after a forced switch.
      if user.pokemon.equal?(original) && !user.fainted?
        saved_vars.each do |name, existed, value|
          if existed
            user.instance_variable_set(name, value)
          elsif user.instance_variable_defined?(name)
            user.remove_instance_variable(name)
          end
        end
        saved_effects.each do |key, value|
          user.effects[key] = value
        end
        battle.choices[user.index] = old_choice
      end
      user.instance_variable_set(:@dust_cloud_owner, old_owner)
      battle.moldBreaker = old_mold
      $aamName, $aamName2 = old_names
    end
  end

  # Install after all plugin aliases, including MAG, have loaded.
  def self.install!
    return if @installed
    Battle::Battler.prepend(BattlerHook)

    # Basic Advanced AI support-ability recognition.
    if defined?(AdvancedAI::CustomContent::SUPPORT_ABILITIES)
      AdvancedAI::CustomContent::SUPPORT_ABILITIES[:DUSTCLOUD] = 1.0
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      DustCloudAbility.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::OnSwitchIn.add(:DUSTCLOUD, proc { |ability, battler, battle, switch_in| DustCloudAbility.trigger(battler, battle) }
)

# Basic native AI ability rating.
Battle::AI::BASE_ABILITY_RATINGS[5] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[5].include?(:DUSTCLOUD)
  Battle::AI::BASE_ABILITY_RATINGS[5] << :DUSTCLOUD
end
unless Battle.singleton_class.ancestors.include?( DustCloudAbility::BattleConstruction )
  Battle.singleton_class.prepend(DustCloudAbility::BattleConstruction)
end

# PRETENTIOUS
# Raises critical-hit stage after knocking out a target.
Battle::AbilityEffects::OnEndOfUsingMove.add(:PRETENTIOUS, proc { |ability, user, targets, move, battle|
  next if user.fainted? || !user.hasActiveAbility?(:PRETENTIOUS)
  next if !move.damagingMove?
  next if battle.pbAllFainted?(user.idxOpposingSide)
  knocked_out = targets.compact.uniq.count do |target|
    target.damageState.fainted
  end
  next if knocked_out == 0
  maximum = Battle::Move::CRITICAL_HIT_RATIOS.length - 1
  previous = user.effects[PBEffects::FocusEnergy]
  updated = [previous + knocked_out, maximum].min
  next if updated <= previous
  battle.pbShowAbilitySplash(user)
  user.effects[PBEffects::FocusEnergy] = updated
  battle.pbDisplay( _INTL("{1}'s critical-hit ratio rose!", user.pbThis) )
  battle.pbHideAbilitySplash(user)
})

# Native AI
# Its critical-hit calculation already reads the FocusEnergy counter.
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:PRETENTIOUS)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :PRETENTIOUS
end
Battle::AI::Handlers::AbilityRanking.add(:PRETENTIOUS, proc { |ability, score, battler, ai|
  next 0 if !battler.check_for_move { |move| move.damagingMove? }
  maximum = Battle::Move::CRITICAL_HIT_RATIOS.length - 1
  next 1 if battler.battler.effects[PBEffects::FocusEnergy] >= maximum
  next 6
})

# Advanced AI - offensive ability recognition.
# Its existing critical-hit scoring also reads FocusEnergy.
module PretentiousAI
  def self.install!
    return if @installed
    if defined?(AdvancedAI::CustomContent::OFFENSIVE_ABILITIES)
      AdvancedAI::CustomContent::OFFENSIVE_ABILITIES[:PRETENTIOUS] = 1.5
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      PretentiousAI.install!
      super(*args, &block)
    end
  end
end
unless Battle.singleton_class.ancestors.include?( PretentiousAI::BattleConstruction )
  Battle.singleton_class.prepend(PretentiousAI::BattleConstruction)
end

# FLUID GUARD
# Damage multiplier = attacker Speed / defender Speed, limited to 0.5–1.0.
module FluidGuard
  def self.real(battler); return battler.respond_to?(:battler) ? battler.battler : battler; end

  def self.speed(battler)
    battler = real(battler)
    value = battler.respond_to?(:pbSpeed) ? battler.pbSpeed : battler.speed
    return [value, 1].max
  end

  def self.factor(user, target)
    ratio = speed(user).to_f / speed(target)
    return [[ratio, 0.5].max, 1.0].min
  end

  def self.ai_factor(user, target, move)
    return 1.0 if !user || !target
    return 1.0 if move && !move.damagingMove?
    return 1.0 unless AdvancedAI::Utilities.ability_active?( real(target), :FLUIDGUARD )
    return 1.0 if AdvancedAI::Utilities.ignores_ability?( user, move, target )
    return factor(user, target)
  end

  # Shared Advanced AI damage estimator.
  module SharedDamage
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      return super * FluidGuard.ai_factor(attacker, target, move)
    end
  end

  # Advanced AI's separate move damage estimator.
  module ScorerDamage
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !value.is_a?(Numeric) || value <= 0
      return value if !move || !user || !target

      # These terrain calculations already use the shared estimator.
      if defined?(ExtendedTerrains::Advanced) && @battle.field.terrain == :Pollination &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      native = move.respond_to?(:move) ? move.move : move
      unless native.is_a?(Battle::Move)
        native = Battle::Move.from_pokemon_move( @battle, Pokemon::Move.new(native.id) )
      end
      return value if !native.damagingMove?
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      return value if native.function_code.start_with?("OHKO")
      factor = FluidGuard.ai_factor(user, target, move)
      return value if factor == 1.0
      return [(value * factor).round, 1].max
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    return if @installed
    if defined?(AdvancedAI::CombatUtilities)
      AdvancedAI::CombatUtilities.singleton_class.prepend(SharedDamage)
      if Battle::AI.method_defined?(:calculate_rough_damage)
        Battle::AI.prepend(ScorerDamage)
      end
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      FluidGuard.install!
      super(*args, &block)
    end
  end
end

# Battle effect and native AI damage prediction.
Battle::AbilityEffects::DamageCalcFromTarget.add(:FLUIDGUARD, proc { |ability, user, target, move, mults, power, type|
  next if !target.hasActiveAbility?(:FLUIDGUARD)
  next if !move.damagingMove?
  mults[:final_damage_multiplier] *= FluidGuard.factor(user, target)
})

# Native AI ability rating.
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:FLUIDGUARD)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :FLUIDGUARD
end
unless Battle.singleton_class.ancestors.include?( FluidGuard::BattleConstruction )
  Battle.singleton_class.prepend(FluidGuard::BattleConstruction)
end

# SPEED FORCE - KAITO replacement
# Contact moves gain flat damage equal to 20% of effective Speed per hit.
module KaitoSpeedForce
  RATE = 0.20

  def self.real(user); return user.respond_to?(:battler) ? user.battler : user; end

  def self.bonus(user, move)
    user = real(user)
    move = move.respond_to?(:move) ? move.move : move
	return 0 if !user || !move
	return 0 if !move.damagingMove?
	return 0 if move.is_a?(Battle::Move::FixedDamageMove)
	data = GameData::Move.try_get(move.id)
	contact = if move.respond_to?(:contactMove?)
				move.contactMove?
			  else
				data && data.has_flag?("Contact")
			  end
	return 0 if !contact
	code = if move.respond_to?(:function_code)
			 move.function_code.to_s
		   else
			 data ? data.function_code.to_s : ""
		   end
    return 0 if code.start_with?("FixedDamage", "OHKO", "Counter")
    return 0 if [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(code)
    active = if user.respond_to?(:hasActiveAbility?)
               user.hasActiveAbility?(:SPEEDFORCE)
             else
               user.ability_id == :SPEEDFORCE
             end
    return 0 if !active
    speed = user.respond_to?(:pbSpeed) ? user.pbSpeed : user.speed
    return (speed * RATE).floor
  end

  # Expected hit count for AI predictions.
  def self.hits(user, move)
    return 1.0 unless defined?(AdvancedAI::CombatUtilities)

    # AAI weights these moves by power rather than hit count.
    count = if [:TRIPLEAXEL, :TRIPLEKICK].include?(move.id)
              3.0
            else
              AdvancedAI::CombatUtilities.expected_hit_multiplier( move, user )
            end
    if count == 1.0 && !move.multiHitMove? && AdvancedAI::Utilities.ability_active?(user, :PARENTALBOND)
      count = 2.0
    end
    return count
  end

  def self.add_prediction(value, user, target, move, count = 1.0)
    return value if !value.is_a?(Numeric) || value <= 0
    extra = bonus(user, move)
    return value if extra == 0
    result = value + (extra * count).round
    native = move.respond_to?(:move) ? move.move : move
    if native.respond_to?(:nonLethal?) && native.nonLethal?(real(user), real(target))
      result = [result, [target.hp - 1, 0].max].min
    end
    return result
  end

  # Actual damage, before Substitute and survival effects are resolved.
  module BattleDamage
    def pbCalcDamage(user, target, numTargets = 1)
      result = super
      state = target.damageState
      return result if state.disguise || state.iceFace
      return result if Effectiveness.ineffective?(state.typeMod)
      return result if state.calcDamage <= 0
      state.calcDamage += KaitoSpeedForce.bonus(user, self)
      return result
    end
  end

  # Native AI, including MAG's rough_damage implementation.
  module NativeAI
    def rough_damage
      value = super
      return KaitoSpeedForce.add_prediction( value, @ai.user, @ai.target, @move, KaitoSpeedForce.hits(@ai.user, @move) )
    end
  end

  # Advanced AI shared damage estimator.
  module SharedAI
    def estimate_damage(attacker, move, defender, options = {})
      value = super
      return value if !attacker || !move || !defender
      scale = options[:as_percent] ? [defender.totalhp, 1].max.to_f : 1.0
      damage = KaitoSpeedForce.add_prediction( value * scale, attacker, defender, move, KaitoSpeedForce.hits(attacker, move) )
      return damage / scale if options[:as_percent]
      return damage
    end
  end

  # Advanced AI's separate move damage estimator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target

      # Extended Terrains already used the shared estimator here.
      if defined?(ExtendedTerrains::Advanced) && @battle.field.terrain == :Pollination &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      count = override_bp ? 1.0 : KaitoSpeedForce.hits(user, move)
      return KaitoSpeedForce.add_prediction( value, user, target, move, count )
    end
  end

  def self.install!
    return if @installed

    # Disable the old Community Abilities handler and its messages.
    Battle::AbilityEffects::DamageCalcFromUser.add( :SPEEDFORCE, proc { |*args| })
    Battle::Move.prepend(BattleDamage)
    Battle::AI::AIMove.prepend(NativeAI)
    if defined?(AdvancedAI::CombatUtilities)
      AdvancedAI::CombatUtilities.singleton_class.prepend(SharedAI)
      if Battle::AI.method_defined?(:calculate_rough_damage)
        Battle::AI.prepend(ScorerAI)
      end
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      result = super(*args, &block)
      KaitoSpeedForce.install!
      return result
    end
  end
end
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:SPEEDFORCE)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :SPEEDFORCE
end
unless Battle.singleton_class.ancestors.include?( KaitoSpeedForce::BattleConstruction )
  Battle.singleton_class.prepend( KaitoSpeedForce::BattleConstruction )
end

# BRAVE HEART
# Gain one Attack stage per successful opposing stat increase.
module BraveHeart
  def self.real(battler); return battler.respond_to?(:battler) ? battler.battler : battler; end

  def self.active?(battler)
    battler = real(battler)
    return battler && !battler.fainted? && battler.hasActiveAbility?(:BRAVEHEART)
  end

  # Resolve reactions after the original stat-change messages.
  def self.with_change(battler)
    battle = battler.battle
    depth = battle.instance_variable_get(:@bh_depth).to_i
    battle.instance_variable_set(:@bh_depth, depth + 1)
    completed = false
    begin
      result = yield
      completed = true
      return result
    ensure
      battle.instance_variable_set(:@bh_depth, depth)
      if depth == 0
        events = battle.instance_variable_get(:@bh_events) || []
        battle.instance_variable_set(:@bh_events, [])
        resolve(battle, events) if completed && !events.empty?
      end
    end
  end

  def self.record(battler)
    battle = battler.battle
    return if battle.instance_variable_get(:@bh_resolving)
    events = battle.instance_variable_get(:@bh_events) || []
    events << battler
    battle.instance_variable_set(:@bh_events, events)
  end

  def self.resolve(battle, events)
    return if battle.instance_variable_get(:@bh_resolving)
    battle.instance_variable_set(:@bh_resolving, true)
    begin
      events.each do |gainer|
        next if gainer.fainted?
        battle.allOtherSideBattlers(gainer.index).each do |b|
          next if !active?(b)
          next if !b.pbCanRaiseStatStage?(:ATTACK, b)

          # This method handles its own ability splash.
          b.pbRaiseStatStageByAbility(:ATTACK, 1, b)
        end
      end
    ensure
      battle.instance_variable_set(:@bh_resolving, false)
    end
  end

  module StatChanges
    [:pbRaiseStatStage, :pbRaiseStatStageByCause, :pbLowerStatStage, :pbLowerStatStageByCause].each do |name|
      define_method(name) do |*args, &block|
        BraveHeart.with_change(self) { super(*args, &block) }
      end
    end

    def pbRaiseStatStageBasic(stat, increment, ignoreContrary = false)
      BraveHeart.with_change(self) do
        before = stages[stat]
        result = super
        BraveHeart.record(self) if stages[stat] > before
        result
      end
    end
  end

  # Positive cost means the opposing side gains an advantage.
  def self.ai_cost(gainer)
    gainer = real(gainer)
    return 0 if !gainer
    battle = gainer.battle
    return battle.allOtherSideBattlers(gainer.index).sum do |b|
      next 0 if !active?(b)
      next 0 if !b.pbCanRaiseStatStage?(:ATTACK, b)
      delta = 1
      unless battle.moldBreaker
        delta = -1 if b.hasActiveAbility?(:CONTRARY)
        delta *= 2 if b.hasActiveAbility?(:SIMPLE)
      end
      limit = Battle::Battler::STAT_STAGE_MAXIMUM
      old = b.stages[:ATTACK]
      delta = (old + delta).clamp(-limit, limit) - old
      physical = b.moves.any? do |m|
        m && m.damagingMove? && m.physicalMove? &&
          ![ "UseTargetAttackInsteadOfUserAttack", "UseUserDefenseInsteadOfUserAttack" ].include?(m.function_code)
      end
      next delta * (physical ? 12 : 4)
    end
  end

  # Native AI: account for each allied stat increase being evaluated.
  module NativeAI
    def get_target_stat_raise_score_one(score, target, stat, increment, desire_mult = 1)
      value = super
      return value if !value.is_a?(Numeric)
      return value if value <= Battle::AI::MOVE_USELESS_SCORE
      gainer = BraveHeart.real(target)
      return value if gainer.opposes?(BraveHeart.real(@user))
      chance = @move.damagingMove? ? @move.move.addlEffect.to_f / 100 : 1.0
      chance = chance.clamp(0.0, 1.0)
      return value - (BraveHeart.ai_cost(gainer) * chance).round
    end
  end

  # Advanced AI: penalize recognized self-setup moves.
  module AdvancedAIHook
    def score_setup_value(move, user, target, skill, status_multiplier = 1.0)
      value = super
      return value if skill < 55 || !move || !user
      source = BraveHeart.real(user)
      native = move.respond_to?(:move) ? move.move : move
      unless native.is_a?(Battle::Move)
        native = Battle::Move.from_pokemon_move( @battle, Pokemon::Move.new(native.id) )
      end
      return value unless AdvancedAI.setup_move?(move.id)
      return value unless native.respond_to?(:statUp)
      count = native.statUp.each_slice(2).count do |stat, amount|
        amount > 0 && source.pbCanRaiseStatStage?(stat, source) && !(!@battle.moldBreaker && source.hasActiveAbility?(:CONTRARY))
      end
      return value - BraveHeart.ai_cost(source) * count
    end
  end

  # Install after all plugins have finished defining aliases.
  def self.install!
    return if @installed
    Battle::Battler.prepend(StatChanges)
    Battle::AI.prepend(NativeAI)
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:score_setup_value)
      Battle::AI.prepend(AdvancedAIHook)
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      BraveHeart.install!
      super(*args, &block)
    end
  end
end
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:BRAVEHEART)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :BRAVEHEART
end
unless Battle.singleton_class.ancestors.include?( BraveHeart::BattleConstruction )
  Battle.singleton_class.prepend(BraveHeart::BattleConstruction)
end

# NIGHTSTALKER
# Dark-type moves gain +1 priority while above half HP.
module Nightstalker
  def self.boost?(user, move)
    user = user.battler if user.respond_to?(:battler)
    move = move.move if move.respond_to?(:move)
    return false if !user || !move || user.fainted?
    return false if user.hp * 2 <= user.totalhp
    return false if move.type != :DARK
    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(:NIGHTSTALKER)
    end
    return user.ability_id == :NIGHTSTALKER
  end

  # Advanced AI also has a separate priority utility.
  module AdvancedPriority
    def effective_priority(user, move, battle = nil)
      value = super
      return Nightstalker.boost?(user, move) ? value + 1 : value
    end
  end

  def self.install!
    return if @installed
    if defined?(AdvancedAI::Utilities)
      AdvancedAI::Utilities.singleton_class.prepend( AdvancedPriority )
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      Nightstalker.install!
      super(*args, &block)
    end
  end
end

# Actual battle, native AI and Advanced AI PriorityTiers.
Battle::AbilityEffects::PriorityChange.add(:NIGHTSTALKER, proc { |ability, battler, move, priority| next priority + ( Nightstalker.boost?(battler, move) ? 1 : 0 ) }
)

# Native AI ability evaluation.
Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:NIGHTSTALKER)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :NIGHTSTALKER
end
Battle::AI::Handlers::AbilityRanking.add(:NIGHTSTALKER, proc { |ability, score, battler, ai|
  next 0 if !battler.check_for_move { |move| move.type == :DARK }
  next battler.hp * 2 > battler.totalhp ? 8 : 4
})
unless Battle.singleton_class.ancestors.include?( Nightstalker::BattleConstruction )
  Battle.singleton_class.prepend( Nightstalker::BattleConstruction )
end

# CHEAP TACTICS
# Use a real Scratch upon entry without consuming the regular action.
module CheapTactics
  MOVE = :SCRATCH
  TURN_VARS = [
    :@lastRoundMoved, :@currentMove, :@lastRegularMoveUsed,
    :@lastRegularMoveTarget, :@lastMoveFailed, :@powerMoveIndex,
    :@lastMoveUsedIsZMove, :@turnCount
  ].freeze
  TURN_EFFECTS = [
    :TwoTurnAttack, :Outrage, :Rollout, :Uproar, :Bide,
    :FuryCutter, :ProtectRate, :Metronome, :ChoiceBand,
    :Truant, :ParentalBond, :Prankster
  ].freeze

  def self.targets(user, battle); return battle.allOtherSideBattlers(user.index).select do |b| !b.fainted? && b.near?(user) end; end

  # Only attached to the temporary Scratch object.
  module MoveHook
    def pbChangeUsageCounters(user, specialUsage)
      # Preserve regular move chains and Fusion flags.
    end
  end

  module BattlerHook
    def cheap_tactics_virtual?; return @cheap_tactics_owner && @cheap_tactics_owner.equal?(pokemon); end

    def pbBeginTurn(choice)
      return if @cheap_tactics_owner
      super
    end

    def pbEndTurn(choice)
      return if @cheap_tactics_owner
      super
    end

    def pbCancelMoves(*args)
      return if @cheap_tactics_owner
      super
    end

    def usingMultiTurnAttack?
      return false if cheap_tactics_virtual?
      super
    end

    def pbObedienceCheck?(choice)
      return true if cheap_tactics_virtual?
      super
    end

    # Apply normal move restrictions.
    def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
      if cheap_tactics_virtual? && [:SCRATCH, :ASTONISH].include?(move.id)
        specialUsage = false
      end
      super(move, commandPhase, showMessages, specialUsage)
    end

    def pbTryUseMove(choice, move, specialUsage, skipAccuracyCheck)
      unless cheap_tactics_virtual? && move.id == CheapTactics::MOVE
        return super
      end
      original      = pokemon
      old_status    = status
      old_count     = statusCount
      old_confusion = effects[PBEffects::Confusion]
      old_truant    = effects[PBEffects::Truant]
      begin
        # Run status checks without advancing turn-based counters.
        self.statusCount += 1 if old_status == :SLEEP
        effects[PBEffects::Confusion] += 1 if old_confusion > 0
        return super(choice, move, specialUsage, false)
      ensure
        if pokemon.equal?(original) && !fainted?
          if old_status == :SLEEP && status == :SLEEP
            self.statusCount = old_count
          end
          if old_confusion > 0 && effects[PBEffects::Confusion] > 0
            effects[PBEffects::Confusion] = old_confusion
          end
          effects[PBEffects::Truant] = old_truant
        end
      end
    end

    # Called moves normally skip accuracy; this Scratch must not.
    def pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
      if cheap_tactics_virtual? && move.id == CheapTactics::MOVE
        skipAccuracyCheck = false
      end
      super(move, user, target, skipAccuracyCheck)
    end
  end

  def self.trigger(user, battle, move_id = MOVE, ability_id = :CHEAPTACTICS)
    return if user.fainted? || battle.decision != 0
    return if !user.hasActiveAbility?(ability_id)
    return if user.cheap_tactics_virtual?
    foes = targets(user, battle)
    return if foes.empty?
    target = foes[battle.pbRandom(foes.length)]
    original   = user.pokemon
    old_owner  = user.instance_variable_get(:@cheap_tactics_owner)
    old_choice = battle.choices[user.index]&.dup
    old_mold   = battle.moldBreaker
    old_names  = [$aamName, $aamName2]
    saved_vars = TURN_VARS.map do |name|
      [ name, user.instance_variable_defined?(name), user.instance_variable_get(name) ]
    end
    saved_effects = TURN_EFFECTS.filter_map do |name|
      next if !PBEffects.const_defined?(name)
      key = PBEffects.const_get(name)
      [key, user.effects[key]]
    end
    begin
      user.instance_variable_set(:@cheap_tactics_owner, original)
		battle.pbShowAbilitySplash(user, true)
		battle.pbHideAbilitySplash(user)
      move = Battle::Move.from_pokemon_move( battle, Pokemon::Move.new(move_id) )
      move.pp = -1
      move.singleton_class.prepend(MoveHook)

      # Needed for Psychic Terrain and other priority protections.
      user.effects[PBEffects::Prankster] = false
      priority = move.pbPriority(user)
      if user.abilityActive?
        priority = Battle::AbilityEffects.triggerPriorityChange( user.ability, user, move, priority )
      end
      choice = [:UseMove, -1, move, target.index, priority]
      battle.choices[user.index] = choice
      user.pbUseMove(choice, true)
    ensure
      # Never restore the old occupant's action after a forced switch/KO.
      if user.pokemon.equal?(original) && !user.fainted?
        saved_vars.each do |name, existed, value|
          if existed
            user.instance_variable_set(name, value)
          elsif user.instance_variable_defined?(name)
            user.remove_instance_variable(name)
          end
        end
        saved_effects.each do |key, value|
          user.effects[key] = value
        end
        battle.choices[user.index] = old_choice
      end
      user.instance_variable_set(:@cheap_tactics_owner, old_owner)
      battle.moldBreaker = old_mold
      $aamName, $aamName2 = old_names
    end
  end

  # Advanced AI: value the entry attack when comparing switch candidates.
  module SwitchAI
    def evaluate_switch_candidate_detailed(pkmn, current_user, skill)
      value = super
      return value if !value.is_a?(Numeric) || !pkmn || skill < 55
      probe = switch_entry_hp_preview( pkmn, get_battler_index(current_user) )
      return value if probe.fainted?
      move_ids = []
      move_ids << :SCRATCH if probe.hasActiveAbility?(:CHEAPTACTICS)
      move_ids << :ASTONISH if probe.hasActiveAbility?(:JUMPSCARE)
      return value if move_ids.empty?
      return value if [:SLEEP, :FROZEN].include?(probe.status)
      preview = probe.battle
      foes = CheapTactics.targets(probe, preview)
      return value if foes.empty?
      expected = move_ids.sum do |move_id|
        move = Battle::Move.from_pokemon_move( preview, Pokemon::Move.new(move_id) )
        foes.sum do |foe|
          next 0.0 if AdvancedAI::Utilities.counter_priority_blocked?( preview, move, probe, foe )
          damage = AdvancedAI::CombatUtilities.estimate_damage( probe, move, foe )
          next 0.0 if damage <= 0
          gain = 30.0 * [ damage.to_f / [foe.hp, 1].max, 1.0 ].min
          gain += 10 if damage >= foe.hp
          if move.pbContactMove?(probe) && probe.takesIndirectDamage? && !probe.hasActiveItem?(:PROTECTIVEPADS)
            recoil = 0
            if foe.hasActiveItem?(:ROCKYHELMET)
              recoil += [probe.totalhp / 6, 1].max
            end
            if foe.hasActiveAbility?([:ROUGHSKIN, :IRONBARBS])
              recoil += [probe.totalhp / 8, 1].max
            end
            gain -= 30.0 * recoil / [probe.hp, 1].max
            gain -= 20 if recoil >= probe.hp
          end
          gain
        end / foes.length
      end
      expected *= 0.75 if probe.status == :PARALYSIS
      return value + expected.round
    end
  end

  # Install after all plugin aliases, including MAG, have loaded.
  def self.install!
    return if @installed
    Battle::Battler.prepend(BattlerHook)
    if defined?(AdvancedAI::CustomContent::OFFENSIVE_ABILITIES)
      AdvancedAI::CustomContent::OFFENSIVE_ABILITIES[:CHEAPTACTICS] = 1.0
    end
    if Battle::AI.method_defined?(:evaluate_switch_candidate_detailed) && Battle::AI.method_defined?(:switch_entry_hp_preview)
      Battle::AI.prepend(SwitchAI)
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      CheapTactics.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::OnSwitchIn.add(:CHEAPTACTICS, proc { |ability, battler, battle, switch_in| CheapTactics.trigger(battler, battle) })
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:CHEAPTACTICS)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :CHEAPTACTICS
end
unless Battle.singleton_class.ancestors.include?( CheapTactics::BattleConstruction )
  Battle.singleton_class.prepend(CheapTactics::BattleConstruction)
end

# JUMPSCARE
# Shares Cheap Tactics' virtual move pipeline.
Battle::AbilityEffects::OnSwitchIn.add(:JUMPSCARE, proc { |ability, battler, battle, switch_in| CheapTactics.trigger(battler, battle, :ASTONISH, :JUMPSCARE) }
)
Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:JUMPSCARE)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :JUMPSCARE
end

# ILLUMINATE
# Prevents Accuracy loss, ignores Evasion boosts,
# and lowers opposing Pokemon's Accuracy upon entry.
module KaitoIlluminate
  def self.install!
    return if @installed

    # Independent handler: no accuracy multiplier.
    Battle::AbilityEffects::AccuracyCalcFromUser.add(:ILLUMINATE, proc { |ability, mods, user, target, move, type|
        next if !user.hasActiveAbility?(:ILLUMINATE)
        mods[:evasion_stage] = 0 if mods[:evasion_stage] > 0
      })

    Battle::AbilityEffects::StatLossImmunity.add(:ILLUMINATE, proc { |ability, battler, stat, battle, showMessages|
        next false if stat != :ACCURACY
        next false if !battler.hasActiveAbility?(:ILLUMINATE)
        if showMessages
          battle.pbShowAbilitySplash(battler)
          battle.pbDisplay( _INTL("{1}'s accuracy cannot be lowered!", battler.pbThis) )
          battle.pbHideAbilitySplash(battler)
        end
        next true
      })

    Battle::AbilityEffects::OnSwitchIn.add(:ILLUMINATE, proc { |ability, user, battle, switch_in|
        next if user.fainted? || battle.decision != 0
        next if !user.hasActiveAbility?(:ILLUMINATE)
        battle.pbShowAbilitySplash(user)
        begin
          battle.allOtherSideBattlers(user.index).each do |target|
            next if target.fainted?
            next if target.effects[PBEffects::Substitute] > 0
            next if !target.pbCanLowerStatStage?( :ACCURACY, user, nil, true )
            target.pbLowerStatStage(:ACCURACY, 1, user)
          end
        ensure
          battle.pbHideAbilitySplash(user)
        end
      })
    if Battle::AI.method_defined?(:evaluate_switch_candidate_detailed) && Battle::AI.method_defined?(:switch_entry_hp_preview)
      Battle::AI.prepend(SwitchAI)
    end
    @installed = true
  end

  # Advanced AI: value the entry Accuracy drop when choosing a switch.
  module SwitchAI
    def evaluate_switch_candidate_detailed(pkmn, current_user, skill)
      value = super
      return value if !value.is_a?(Numeric) || !pkmn || skill < 55
      probe = switch_entry_hp_preview( pkmn, get_battler_index(current_user) )
      return value if probe.fainted?
      return value if !probe.hasActiveAbility?(:ILLUMINATE)
      return value if probe.hasActiveAbility?(:NOGUARD)
      old_names = [$aamName, $aamName2]
      begin
        bonus = probe.battle.allOtherSideBattlers(probe.index).sum do |foe|
          next 0 if foe.fainted?
          next 0 if foe.effects[PBEffects::Substitute] > 0
          next 0 if foe.hasActiveAbility?(:NOGUARD)
          next 0 if !foe.moves.any? { |m| m && m.accuracy > 0 }
          next 0 if !foe.pbCanLowerStatStage?(:ACCURACY, probe)
          contrary = foe.hasActiveAbility?(:CONTRARY)

          # Reflected Accuracy drops are blocked by Illuminate.
          next 0 if !contrary && foe.hasActiveAbility?(:MIRRORARMOR)
          delta = contrary ? 1 : -1
          delta *= 2 if foe.hasActiveAbility?(:SIMPLE)
          old = foe.stages[:ACCURACY]
          delta = (old + delta).clamp(-6, 6) - old
          next -8 * delta
        end
        return value + bonus
      ensure
        $aamName, $aamName2 = old_names
      end
    end
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoIlluminate.install!
      super(*args, &block)
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoIlluminate::BattleConstruction )
  Battle.singleton_class.prepend( KaitoIlluminate::BattleConstruction )
end

# REFRACTIVE
# Light moves add their type before use and gain 20% power.
module Refractive
  def self.real(user); return user.respond_to?(:battler) ? user.battler : user; end

  def self.native(move); return move.respond_to?(:move) ? move.move : move; end

  def self.light?(move)
    move = native(move)
    return false if !move
    data = GameData::Move.try_get(move.id)
    return data && data.flags.any? do |flag| flag.downcase == "light" end
  end

  def self.active?(user)
    user = real(user)
    return false if !user || user.fainted?
    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(:REFRACTIVE)
    end
    return user.ability_id == :REFRACTIVE
  end

  def self.extra_type(user, type); return user.pbTypes(false).include?(type) ? nil : type; end

  def self.activate(user, move)
    return if !active?(user) || !light?(move)
    return if !user.canChangeType?
    type = move.calcType || move.pbCalcType(user)
    return if !type || !GameData::Type.exists?(type)
    extra = extra_type(user, type)
    return if user.effects[PBEffects::ExtraType] == extra
    user.effects[PBEffects::ExtraType] = extra
    battle = user.battle
    battle.pbShowAbilitySplash(user)
    begin
      if extra
        battle.pbDisplay( _INTL("{1} gained the {2} type!", user.pbThis, GameData::Type.get(extra).name) )
      else
        battle.pbDisplay( _INTL("{1}'s added type faded!", user.pbThis) )
      end
    ensure
      battle.pbHideAbilitySplash(user)
    end
  end

  # Predict the new typing without messages or lasting changes.
  def self.predict(user, move)
    source = real(user)
    unless active?(source) && light?(move) && source.respond_to?(:effects) && source.canChangeType?
      return yield
    end
    type = if defined?(AdvancedAI::CombatUtilities)
             AdvancedAI::CombatUtilities.resolve_move_type(user, move)
           else
             native(move).pbCalcType(source)
           end
    return yield if !type || !GameData::Type.exists?(type)
    previous = source.effects[PBEffects::ExtraType]
    begin
      source.effects[PBEffects::ExtraType] = extra_type(source, type)
      return yield
    ensure
      source.effects[PBEffects::ExtraType] = previous
    end
  end

  # Runs after resolving the actual user, including Snatch,
  # and before the move's use message and animation.
  module BattlerHook
    def pbChangeUser(choice, move, user)
      actual_user = super
      Refractive.activate(actual_user, move)
      return actual_user
    end
  end

  module NativeAI
    def rough_damage; Refractive.predict(@ai.user, @move) { super }; end
  end

  module SharedPrediction
    def estimate_damage(attacker, move, defender, options = {}); Refractive.predict(attacker, move) { super }; end

    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      value = super
      if Refractive.active?(attacker) && Refractive.light?(move)
        return value * 1.3
      end
      return value
    end
  end

  module ScorerPrediction
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = Refractive.predict(user, move) { super }
      return value if !value.is_a?(Numeric) || value <= 0 || !move

      # These terrain calculations already use the shared estimator.
      if defined?(ExtendedTerrains::Advanced) && @battle.field.terrain == :Pollination &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      return value unless Refractive.active?(user) && Refractive.light?(move)
      native = Refractive.native(move)
      unless native.is_a?(Battle::Move)
        native = Battle::Move.from_pokemon_move( @battle, Pokemon::Move.new(native.id) )
      end
      return value if !native.damagingMove?
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      return value if native.function_code.start_with?("OHKO")
      return [(value * 1.3).round, 1].max
    end
  end

  def self.install!
    return if @installed
    Battle::Battler.prepend(BattlerHook)
    Battle::AI::AIMove.prepend(NativeAI)

    Battle::AbilityEffects::DamageCalcFromUser.add(:REFRACTIVE, proc { |ability, user, target, move, mults, power, type|
        next if !Refractive.active?(user)
        next if !Refractive.light?(move) || !move.damagingMove?
        mults[:power_multiplier] *= 1.3
      })
    if defined?(AdvancedAI::CombatUtilities)
      AdvancedAI::CombatUtilities.singleton_class.prepend( SharedPrediction )
      if Battle::AI.method_defined?(:calculate_rough_damage)
        Battle::AI.prepend(ScorerPrediction)
      end
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      Refractive.install!
      super(*args, &block)
    end
  end
end
Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:REFRACTIVE)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :REFRACTIVE
end
unless Battle.singleton_class.ancestors.include?( Refractive::BattleConstruction )
  Battle.singleton_class.prepend(Refractive::BattleConstruction)
end

# PARANOID
# Doubles Sp. Defense in damage calculations.
# Takes double damage from Psychic-type moves.
module Paranoid
  def self.real(battler); return battler.respond_to?(:battler) ? battler.battler : battler; end

  def self.uses_spdef?(move, user, target, type, physical = nil)
    native = move.respond_to?(:move) ? move.move : move
    special = physical.nil? ? native.specialMove?(type) : !physical
    if native.function_code == "UseTargetDefenseInsteadOfTargetSpDef"
      special = false
    end
    battle = real(target).battle
    special = !special if battle.field.effects[PBEffects::WonderRoom] > 0
    return special
  end

  def self.ai_factor(user, target, move, type, uses_spdef)
    return 1.0 if !user || !target
    return 1.0 unless AdvancedAI::Utilities.ability_active?( real(target), :PARANOID )
    return 1.0 if AdvancedAI::Utilities.ignores_ability?( user, move, target )
    factor = uses_spdef ? 0.5 : 1.0
    factor *= 2.0 if type == :PSYCHIC
    return factor
  end

  module SharedDamage
    def ability_damage_modifier(attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical)
      value = super
      return value * Paranoid.ai_factor( attacker, target, move, type, !physical_defense )
    end
  end

  module ScorerDamage
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !value.is_a?(Numeric) || value <= 0
      return value if !move || !user || !target

      # These terrain calculations already use the shared estimator.
      if defined?(ExtendedTerrains::Advanced) && @battle.field.terrain == :Pollination &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      native = move.respond_to?(:move) ? move.move : move
      unless native.is_a?(Battle::Move)
        native = Battle::Move.from_pokemon_move( @battle, Pokemon::Move.new(native.id) )
      end
      return value if !native.damagingMove?
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      return value if native.function_code.start_with?("OHKO")
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      physical = native.physicalMove?(type)
      if [:PHOTONGEYSER, :LIGHTTHATBURNSTHESKY].include?(move.id) || (move.id == :TERABLAST && tera_type)
        combat = AdvancedAI::CombatUtilities
        atk = user.attack * combat.stage_multiplier(user.stages[:ATTACK])
        spa = user.spatk * combat.stage_multiplier(user.stages[:SPECIAL_ATTACK])
        physical = atk > spa
      end
      spdef = Paranoid.uses_spdef?( native, user, target, type, physical )
      factor = Paranoid.ai_factor(user, target, move, type, spdef)
      return value if factor == 1.0
      return [(value * factor).round, 1].max
    end
  end

  def self.install!
    return if @installed
    if defined?(AdvancedAI::CombatUtilities)
      AdvancedAI::CombatUtilities.singleton_class.prepend( SharedDamage )
      if Battle::AI.method_defined?(:calculate_rough_damage)
        Battle::AI.prepend(ScorerDamage)
      end
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      Paranoid.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::DamageCalcFromTarget.add(:PARANOID, proc { |ability, user, target, move, mults, power, type|
  next if !target.hasActiveAbility?(:PARANOID)
  next if !move.damagingMove?
  if Paranoid.uses_spdef?(move, user, target, type)
    mults[:defense_multiplier] *= 2.0
  end
  mults[:final_damage_multiplier] *= 2.0 if type == :PSYCHIC
})
Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:PARANOID)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :PARANOID
end
unless Battle.singleton_class.ancestors.include?( Paranoid::BattleConstruction )
  Battle.singleton_class.prepend( Paranoid::BattleConstruction )
end

# Sand Rush - Sandstorm or Sandy Terrain
Battle::AbilityEffects::SpeedCalc.add(:SANDRUSH, proc { |ability, battler, mult|
  battle = battler.instance_variable_get(:@battle)
  sandy = battle && battle.field.terrain == :Sandy
  if battler.effectiveWeather == :Sandstorm || sandy
    next mult * 2.0
  end
  next mult
})

# Sand Force - Sandstorm or Sandy Terrain
module KaitoSandForce
  TYPES = [:GROUND, :ROCK, :STEEL].freeze

	def self.active?(user, type, battle = nil)
	  user = user.battler if user.respond_to?(:battler)
	  return false if !user || !TYPES.include?(type)
	  battle ||= user.instance_variable_get(:@battle)
	  if user.respond_to?(:hasActiveAbility?)
		return false if !user.hasActiveAbility?(:SANDFORCE)
	  else
		# AI may evaluate a Pokemon that is not currently on the field.
		abilities = []
		abilities << user.ability_id if user.respond_to?(:ability_id)
		if user.respond_to?(:active_innates)
		  abilities.concat(Array(user.active_innates))
		end
		return false if !abilities.include?(:SANDFORCE)
		return false if battle && battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS)
	  end
	  weather = if user.respond_to?(:effectiveWeather)
				  user.effectiveWeather
				elsif battle
				  battle.pbWeather
				end
	  return weather == :Sandstorm || !!(battle && battle.field.terrain == :Sandy)
	end

  # Advanced AI's shared damage estimator.
  module CombatAI
    def ability_damage_modifier( attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical )
	value = super
	source = attacker.respond_to?(:battler) ? attacker.battler : attacker
	victim = target.respond_to?(:battler) ? target.battler : target
	battle = source && source.instance_variable_get(:@battle)
	battle ||= victim && victim.instance_variable_get(:@battle)
	value *= 1.3 if KaitoSandForce.active?(source, type, battle)
	return value
    end
  end

  # Advanced AI's separate move-scoring damage calculator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?

      # Pollination delegates these moves to the shared estimator.
      if @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      native = move.respond_to?(:move) ? move.move : move
      if defined?(ExtendedTerrains::Advanced)
        native = ExtendedTerrains::Advanced.native_move(move, user)
      end
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      function = move.function_code.to_s
      return value if function.start_with?("FixedDamage", "OHKO", "Counter")
      return value if [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(function)
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      return value if !KaitoSandForce::TYPES.include?(type)

      # The original calculator already adds Sand Force in Sandstorm.
      existing = if user.hasActiveAbility?(:SANDFORCE) && @battle.pbWeather == :Sandstorm
                   1.3
                 else
                   1.0
                 end
      desired = KaitoSandForce.active?(user, type) ? 1.3 : 1.0
      return [(value * desired / existing).round, 1].max
    end
  end

  def self.install!
    Battle::AbilityEffects::DamageCalcFromUser.add(:SANDFORCE, proc { |ability, user, target, move, mults, power, type|
        if KaitoSandForce.active?(user, type)
          mults[:power_multiplier] *= 1.3
        end
      })
    if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(KaitoSandForce::CombatAI)
        singleton.prepend(KaitoSandForce::CombatAI)
      end
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(KaitoSandForce::ScorerAI)
      Battle::AI.prepend(KaitoSandForce::ScorerAI)
    end
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoSandForce.install!
      super
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoSandForce::BattleConstruction )
  Battle.singleton_class.prepend(KaitoSandForce::BattleConstruction)
end

# Sand Veil - Sandstorm or Sandy Terrain
Battle::AbilityEffects::AccuracyCalcFromTarget.add(:SANDVEIL, proc { |ability, mods, user, target, move, type|
  battle = target.instance_variable_get(:@battle)
  sandy = battle && battle.field.terrain == :Sandy
  if target.effectiveWeather == :Sandstorm || sandy
    mods[:evasion_multiplier] *= 1.25
  end
})

# Shatter Mark
# Damaging hits have a 30% chance to inflict MAG's Splinter status.
Battle::AbilityEffects::OnDealingHit.add(:SHATTERMARK, proc { |ability, user, target, move, battle|
  next if !user.hasActiveAbility?(:SHATTERMARK)
  next if !move.damagingMove?
next if !move.contactMove? && move.calcType != :ROCK
  next if target.fainted?
  next if target.damageState.substitute
  next if target.damageState.calcDamage <= 0

  # Like Poison Touch, Shield Dust blocks this ability's status effect.
  next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
  next if !target.pbCanSplinter?(user, false)
  next if battle.pbRandom(100) >= 100
  battle.pbShowAbilitySplash(user)
  begin
    message = nil
    if !Battle::Scene::USE_ABILITY_SPLASH
      message = _INTL( "{1}'s {2} left {3} with splinters!", user.pbThis, GameData::Ability.get(ability).name, target.pbThis(true) )
    end
    target.pbSplinter(user, message)
  ensure
    battle.pbHideAbilitySplash(user)
  end
})

# MAG Splinter - Halves Defense while afflicted
module KaitoSplinterFix
  module BattlerStats
    def defense
      value = super
      return value if status != :SPLINTER

      # In Wonder Room, this getter returns Special Defense.
      return value if @battle.field.effects[PBEffects::WonderRoom] > 0
      return [value / 2, 1].max
    end

    def spdef
      value = super
      return value if status != :SPLINTER

      # In Wonder Room, this getter returns Defense.
      return value if @battle.field.effects[PBEffects::WonderRoom] <= 0
      return [value / 2, 1].max
    end
  end

  def self.install!
    unless Battle::Battler.ancestors.include?( KaitoSplinterFix::BattlerStats )
      Battle::Battler.prepend(KaitoSplinterFix::BattlerStats)
    end
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoSplinterFix.install!
      super
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoSplinterFix::BattleConstruction )
  Battle.singleton_class.prepend( KaitoSplinterFix::BattleConstruction )
end

# Boulder Barrier
# Blocking a move stores a boost for the next damaging Rock-type move.
module KaitoBoulderBarrier
  TOKEN = :@kaito_boulder_move_token
  STACK = :@kaito_boulder_move_frames

  def self.real(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  def self.charged?(object)
    battler = real(object)
    return false if !battler || battler.fainted?
    return battler.hasActiveAbility?(:BOULDERBARRIER) && battler.effects[PBEffects::BoulderBarrier]
  end

  # During an actual move, the token preserves the bonus across all hits.
  # Outside move execution, AI reads the stored charge without consuming it.
  def self.boosted?(object, move)
    user = real(object)
    return false if !user || user.fainted?
    return false if !user.hasActiveAbility?(:BOULDERBARRIER)
    native = move.respond_to?(:move) ? move.move : move
    token = native.instance_variable_get(TOKEN)
    return charged?(user) if token.nil?
    return token.is_a?(Array) && token[0].equal?(user) && token[1].equal?(user.pokemon)
  end

  def self.fixed?(move, user)
    native = move.respond_to?(:move) ? move.move : move
    if defined?(ExtendedTerrains::Advanced)
      native = ExtendedTerrains::Advanced.native_move(move, user)
    end
    return true if native.is_a?(Battle::Move::FixedDamageMove)
    function = move.function_code.to_s
    return true if function.start_with?("FixedDamage", "OHKO", "Counter")
    return [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(function)
  end

  def self.protect_bonus(move, object)
    user = real(object)
    return 0 if !user || user.fainted?
    return 0 if !user.hasActiveAbility?(:BOULDERBARRIER)
    return 0 if charged?(user)
    function = move.function_code.to_s
    return 0 if !function.start_with?("ProtectUser")
    return 0 if function.start_with?("ProtectUserSide")
    usable_rock = user.moves.any? do |m|
      m && (m.pp > 0 || m.total_pp == 0) && m.damagingMove? && !fixed?(m, user) && m.pbCalcType(user) == :ROCK
    end
    return 0 if !usable_rock
    battle = user.instance_variable_get(:@battle)
    threat = battle.allBattlers.any? do |foe|
      next false if foe.fainted? || !foe.opposes?(user)
      next false if !foe.near?(user)
      foe.moves.any? do |m|
        m && (m.pp > 0 || m.total_pp == 0) && m.damagingMove? && m.canProtectAgainst? &&
          !(foe.hasActiveAbility?(:UNSEENFIST) && m.contactMove?)
      end
    end
    return 0 if !threat
    rate = [user.effects[PBEffects::ProtectRate].to_i, 1].max
    return rate >= 3 ? 0 : 10
  end

  module BattlerHook
    def pbInitEffects(batonPass)
      super
      @effects[PBEffects::BoulderBarrier] = false
    end

    def pbSuccessCheckAgainstTarget(move, user, target, targets)
      result = super

      # Track protection of this target, not the attacker's global result.
      # Unblocked attacks do not remove a stored charge.
      if target.hasActiveAbility?(:BOULDERBARRIER) && target.damageState.protected
        target.effects[PBEffects::BoulderBarrier] = true
      end
      return result
    end

    def pbUseMove(choice, specialUsage = false)
      stack = @battle.instance_variable_get(KaitoBoulderBarrier::STACK)
      if !stack
        stack = []
        @battle.instance_variable_set(KaitoBoulderBarrier::STACK, stack)
      end
      frame = []
      stack.push(frame)
      begin
        super
      ensure
        # Restore tokens even if the move fails, switches a battler or errors.
        frame.reverse_each do |move, previous|
          move.instance_variable_set(KaitoBoulderBarrier::TOKEN, previous)
        end
        stack.pop
      end
    end

    def pbChangeUser(choice, move, user)
      actual_user = super
      stack = @battle.instance_variable_get(KaitoBoulderBarrier::STACK)
      frame = stack && stack.last
      return actual_user if !frame
      previous = move.instance_variable_get(KaitoBoulderBarrier::TOKEN)
      frame.push([move, previous])

      # Shadow any token belonging to an outer/nested use of this move.
      move.instance_variable_set(KaitoBoulderBarrier::TOKEN, false)
      return actual_user if !KaitoBoulderBarrier.charged?(actual_user)
      return actual_user if !move.damagingMove?
      return actual_user if move.calcType != :ROCK

      # Keep the charge during the charging-only turn of a two-turn move.
      if move.chargingTurnMove? && move.instance_variable_get(:@damagingTurn) == false
        return actual_user
      end

      # Consume now, but preserve this use's bonus in its own token.
      # A new charge earned during this move remains available afterwards.
      actual_user.effects[PBEffects::BoulderBarrier] = false
      move.instance_variable_set( KaitoBoulderBarrier::TOKEN, [actual_user, actual_user.pokemon] )
      return actual_user
    end
  end

  # Advanced AI: shared damage estimator.
  module CombatAI
    def ability_damage_modifier( attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical )
      value = super
      if type == :ROCK && KaitoBoulderBarrier.charged?(attacker)
        value *= 1.5
      end
      return value
    end
  end

  # Advanced AI: separate damage calculator and Protect scoring.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      return value if !KaitoBoulderBarrier.charged?(user)
      return value if KaitoBoulderBarrier.fixed?(move, user)

      # Avoid applying the bonus twice through terrain delegation.
      if @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      return value if type != :ROCK
      return [(value * 1.5).round, 1].max
    end

    def score_protect_utility(move, user, target)
      value = super
      return value if value < 0
      return value + KaitoBoulderBarrier.protect_bonus(move, user)
    end
  end

  # Native AI already estimates damage through the actual ability handler.
  module NativeScoring
    def apply_move_effect_score(function, score, move, user, ai, battle)
      value = super
      return value if value <= Battle::AI::MOVE_USELESS_SCORE
      return value + KaitoBoulderBarrier.protect_bonus(move, user)
    end
  end

  def self.install!
    Battle::AbilityEffects::DamageCalcFromUser.add(:BOULDERBARRIER, proc { |ability, user, target, move, mults, power, type|
        if type == :ROCK && KaitoBoulderBarrier.boosted?(user, move)
          mults[:attack_multiplier] *= 1.5
        end
      })
    unless Battle::Battler.ancestors.include?(BattlerHook)
      Battle::Battler.prepend(BattlerHook)
    end
    handlers = Battle::AI::Handlers.singleton_class
    unless handlers.ancestors.include?(NativeScoring)
      handlers.prepend(NativeScoring)
    end
    if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(CombatAI)
        singleton.prepend(CombatAI)
      end
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage) && !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
    if defined?(Battle::AI::CAL_BASE_ABILITY_RATINGS)
      Battle::AI::CAL_BASE_ABILITY_RATINGS.each_value do |abilities|
        abilities.delete(:BOULDERBARRIER)
      end
    end
    KaitoAbilitySupport.rate(:BOULDERBARRIER, 5)
  end

  # Install after plugin aliases have finished loading.
  module BattleConstruction
    def new(*args, &block)
      KaitoBoulderBarrier.install!
      super
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoBoulderBarrier::BattleConstruction )
  Battle.singleton_class.prepend( KaitoBoulderBarrier::BattleConstruction )
end

# Boulder Barrier - Reliable damage application
# Requires the existing KaitoBoulderBarrier implementation.
module KaitoBoulderBarrier
  # Reserve Pokemon cannot carry a charge from the current battlefield.
  def self.charged?(object)
    battler = real(object)
    return false if !battler
    return false if !battler.respond_to?(:effects)
    return false if !battler.respond_to?(:hasActiveAbility?)
    return false if battler.fainted?
    return battler.hasActiveAbility?(:BOULDERBARRIER) && !!battler.effects[PBEffects::BoulderBarrier]
  end

  module ReliableState
    def pbSuccessCheckAgainstTarget(move, user, target, targets)
      had_charge = !!target.effects[PBEffects::BoulderBarrier]
      result = super
      if target.hasActiveAbility?(:BOULDERBARRIER)
        protected = !!target.damageState.protected

        # Preserve a charge even if an older handler cleared its flag.
        target.effects[PBEffects::BoulderBarrier] = had_charge || protected
        if protected && !had_charge
          @battle.pbShowAbilitySplash(target)
          begin
            @battle.pbDisplay(_INTL( "{1} stored power for its next Rock-type attack!", target.pbThis ))
          ensure
            @battle.pbHideAbilitySplash(target)
          end
        end
      end
      return result
    end

    def pbChangeUser(choice, move, user)
      move.instance_variable_set(:@kaito_bb_damage_announced, false)
      return super
    end
  end

  module ReliableDamage
    def pbCalcDamageMultipliers( user, target, numTargets, type, baseDmg, multipliers )
      # Prevent the ability handler from applying a second multiplier.
      previous = @kaito_bb_calculating_damage
      @kaito_bb_calculating_damage = true
      begin
        result = super
      ensure
        @kaito_bb_calculating_damage = previous
      end
      return result if type != :ROCK
      return result if !damagingMove?
      return result if is_a?(Battle::Move::FixedDamageMove)
      return result if !KaitoBoulderBarrier.boosted?(user, self)
      multipliers[:attack_multiplier] *= 1.5

      # Announce once per actual move, not once per hit or target.
      token = instance_variable_get(KaitoBoulderBarrier::TOKEN)
      if token.is_a?(Array) && !@kaito_bb_damage_announced
        @kaito_bb_damage_announced = true
        @battle.pbDisplay(_INTL( "{1}'s {2} strengthened {3}!", user.pbThis, GameData::Ability.get(:BOULDERBARRIER).name, name ))
      end
      return result
    end
  end

  module ReliableInstaller
    def install!
      super
      unless Battle::Battler.ancestors.include?( KaitoBoulderBarrier::ReliableState )
        Battle::Battler.prepend(KaitoBoulderBarrier::ReliableState)
      end
      unless Battle::Move.ancestors.include?( KaitoBoulderBarrier::ReliableDamage )
        Battle::Move.prepend(KaitoBoulderBarrier::ReliableDamage)
      end

      # Native AI still uses this handler directly.
      # Actual battle damage receives its bonus through ReliableDamage.
      Battle::AbilityEffects::DamageCalcFromUser.add(:BOULDERBARRIER, proc { |ability, user, target, move, mults, power, type|
          next if move.instance_variable_get( :@kaito_bb_calculating_damage )
          next if type != :ROCK
          next if !KaitoBoulderBarrier.boosted?(user, move)
          mults[:attack_multiplier] *= 1.5
        })
    end
  end
end
unless KaitoBoulderBarrier.singleton_class.ancestors.include?( KaitoBoulderBarrier::ReliableInstaller )
  KaitoBoulderBarrier.singleton_class.prepend( KaitoBoulderBarrier::ReliableInstaller )
end

# Umbral Grit
# Takes 1/3 less damage from non-Steel moves in Gloom Moonlight.
module KaitoUmbralGrit
  WEATHER = :GloomMoonlight
  MULTIPLIER = 2.0 / 3.0

  def self.active?(object, type)
    target = object.respond_to?(:battler) ? object.battler : object
    return false if !target || target.fainted?
    return false if type == :STEEL
    return false if !target.hasActiveAbility?(:UMBRALGRIT)
    return target.effectiveWeather == WEATHER
  end

  def self.ai_factor(user, target, move, type)
    return 1.0 if !active?(target, type)
    return 1.0 if AdvancedAI::Utilities.ignores_ability?( user, move, target )
    return MULTIPLIER
  end

  def self.fixed?(move, user)
    native = move.respond_to?(:move) ? move.move : move
    if defined?(ExtendedTerrains::Advanced)
      native = ExtendedTerrains::Advanced.native_move(move, user)
    end
    return true if native.is_a?(Battle::Move::FixedDamageMove)
    function = move.function_code.to_s
    return true if function.start_with?("FixedDamage", "OHKO", "Counter")
    return [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(function)
  end

  # Advanced AI's shared damage estimator.
  module CombatAI
    def ability_damage_modifier( attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical )
      value = super
      return value * KaitoUmbralGrit.ai_factor( attacker, target, move, type )
    end
  end

  # Advanced AI's separate damage calculator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      return value if KaitoUmbralGrit.fixed?(move, user)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      factor = KaitoUmbralGrit.ai_factor(user, target, move, type)
      return value if factor == 1.0
      return [(value * factor).round, 1].max
    end
  end

  def self.install!
    Battle::AbilityEffects::DamageCalcFromTarget.add(:UMBRALGRIT, proc { |ability, user, target, move, mults, power, type|
        if move.damagingMove? && KaitoUmbralGrit.active?(target, type)
          mults[:final_damage_multiplier] *= KaitoUmbralGrit::MULTIPLIER
        end
      })
    if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(CombatAI)
        singleton.prepend(CombatAI)
      end
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage) && !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
    KaitoAbilitySupport.rate(:UMBRALGRIT, 6)
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoUmbralGrit.install!
      super
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoUmbralGrit::BattleConstruction )
  Battle.singleton_class.prepend( KaitoUmbralGrit::BattleConstruction )
end

# Umbral Grit - Handle battlers and reserve Pokemon in AI predictions
module KaitoUmbralGrit
  def self.real(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  def self.battle_of(object)
    object = real(object)
    return nil if !object
    battle = object.battle if object.respond_to?(:battle)
    return battle if battle
    return object.instance_variable_get(:@battle)
  end

  def self.active?(object, type, battle = nil)
    target = real(object)
    return false if !target || type == :STEEL
    return false if target.fainted?
    has_ability = if target.respond_to?(:hasActiveAbility?)
                    # Active battlers: respect ability suppression.
                    target.hasActiveAbility?(:UMBRALGRIT)
                  elsif target.respond_to?(:set_innate_limits)
                    # Reserve Pokemon: include unlocked innates.
                    Array(target.set_innate_limits).include?(:UMBRALGRIT)
                  else
                    target.respond_to?(:ability_id) && target.ability_id == :UMBRALGRIT
                  end
    return false if !has_ability
    weather = if target.respond_to?(:effectiveWeather)
                target.effectiveWeather
              else
                battle ||= battle_of(target)
                battle ? battle.pbWeather : nil
              end
    return weather == KaitoUmbralGrit::WEATHER
  end

  def self.ai_factor(user, target, move, type)
    native = move.respond_to?(:move) ? move.move : move
    battle = battle_of(target) || battle_of(user) || battle_of(native)
    return 1.0 if !active?(target, type, battle)
    return 1.0 if AdvancedAI::Utilities.ignores_ability?( user, move, target )
    return KaitoUmbralGrit::MULTIPLIER
  end
end

# Kinetic
# Uses effective Speed as the attacking stat.
# Successful damaging moves cost 20% maximum HP once per use.
module KaitoKinetic
  def self.real(object)
    return object.battler if object.respond_to?(:battler)
    object
  end

  def self.has?(object, ability)
    object = real(object)
    return false if !object
    if object.respond_to?(:hasActiveAbility?)
      return object.hasActiveAbility?(ability)
    end
    if object.respond_to?(:set_innate_limits)
      return Array(object.set_innate_limits).include?(ability)
    end
    object.respond_to?(:ability_id) && object.ability_id == ability
  end

  def self.active?(object)
    object = real(object)
    object && !object.fainted? && has?(object, :KINETIC)
  end

  # Resolve PBS data even for an AI MoveProxy.
  def self.data(move)
    return nil if !move
    id = move.respond_to?(:id) ? move.id : nil
    id ? GameData::Move.try_get(id) : nil
  end

  def self.speed(object)
    object = real(object)
    value = object.respond_to?(:pbSpeed) ? object.pbSpeed : object.speed
    [value.to_i, 1].max
  end

  def self.stage(object, stat)
    object = real(object)
    object.respond_to?(:stages) ? object.stages[stat].to_i : 0
  end

  def self.staged(value, stage)
    factor = stage >= 0 ? (2.0 + stage) / 2 : 2.0 / (2 - stage)
    [(value * factor).floor, 1].max
  end

  def self.fixed?(move)
    info = data(move)
    return true if !info
    code = info.function_code
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return true if [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(code)
    if Battle::Move.const_defined?(code, false)
      klass = Battle::Move.const_get(code, false)
    end
    !!(klass.is_a?(Class) && klass <= Battle::Move::FixedDamageMove)
  end

  def self.physical?(user, move, tera = false)
    info = data(move)
    return false if !info
    source = real(user)
    dynamic = [:PHOTONGEYSER, :LIGHTTHATBURNSTHESKY].include?(info.id)
    dynamic ||= info.id == :TERABLAST && (tera || (source.respond_to?(:tera?) && source.tera?))
    if dynamic
      return staged(source.attack, stage(source, :ATTACK)) > staged(source.spatk, stage(source, :SPECIAL_ATTACK))
    end
    info.category == 0
  end

  # Advanced AI correction relative to its original attacking stat.
  def self.ai_ratio(user, target, move, physical)
    return 1.0 if !active?(user) || fixed?(move)
    info = data(move)
    return 1.0 if info.category == 2
    source = real(user)
    stat = physical ? :ATTACK : :SPECIAL_ATTACK
    value = physical ? source.attack : source.spatk
    if info.function_code == "UseTargetAttackInsteadOfUserAttack"
      source = real(target)
      stat, value = :ATTACK, source.attack
    elsif info.function_code == "UseUserDefenseInsteadOfUserAttack"
      stat, value = :DEFENSE, source.defense
    end
    increment = stage(source, stat)
    if info.function_code != "UseTargetAttackInsteadOfUserAttack" && has?(target, :UNAWARE) &&
       !AdvancedAI::Utilities.ignores_ability?(user, move, target)
      increment = 0
    end
    speed(user).to_f / staged(value, increment)
  end

  def self.recoil(object)
    user = real(object)
    return 0 if !active?(user)
    return 0 if has?(user, :MAGICGUARD) || has?(user, :ROCKHEAD)
    if user.respond_to?(:takesIndirectDamage?)
      return 0 if !user.takesIndirectDamage?
    end
    [user.totalhp / 5, 1].max
  end

  def self.risk(move, user)
    info = data(move)
    return 0 if !info || info.category == 2
    cost = recoil(user)
    return 0 if cost <= 0
    hp = [real(user).hp, 1].max
    (40.0 * cost / hp).round + (cost >= hp ? 30 : 0)
  end

  module AttackStats
    def pbGetAttackStats(user, target)
      if damagingMove? && KaitoKinetic.active?(user)
        # pbSpeed already includes Speed stages and other Speed modifiers.
        # Return a neutral attack stage to avoid applying stages twice.
        return KaitoKinetic.speed(user), Battle::Battler::STAT_STAGE_MAXIMUM
      end
      super
    end
  end

  # Deduplicate recoil within one use, while allowing Instruct/called moves
  # to create their own independent uses.
  module UseFrame
    def pbUseMove(*args, &block)
      frames = @battle.instance_variable_get(:@kaito_kinetic_frames)
      if !frames
        frames = []
        @battle.instance_variable_set(:@kaito_kinetic_frames, frames)
      end
      frames.push({})
      begin
        super(*args, &block)
      ensure
        frames.pop
      end
    end
  end

  module CombatAI
    def ability_damage_modifier( user, target, type, physical, effectiveness, move = nil, physical_defense = physical )
      value = super
      value * KaitoKinetic.ai_ratio(user, target, move, physical)
    end
  end

  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target || !value || value <= 0
      return value if !KaitoKinetic.active?(user)
      return value if KaitoKinetic.fixed?(move)

      # Avoid multiplying twice through terrain delegation.
      if @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      tera = move.id == :TERABLAST && !!get_tera_type_for_move(user)
      physical = KaitoKinetic.physical?(user, move, tera)
      ratio = KaitoKinetic.ai_ratio(user, target, move, physical)
      [(value * ratio).round, 1].max
    end

    def score_recoil_risk(move, user); super - KaitoKinetic.risk(move, user); end
  end

  def self.install!
    # Include moves overriding pbGetAttackStats, such as Body Press/Foul Play.
    @patched_classes ||= []
    ObjectSpace.each_object(Class) do |klass|
      next if !(klass <= Battle::Move)
      next if !klass.instance_methods(false).include?(:pbGetAttackStats)
      next if @patched_classes.include?(klass)
      klass.prepend(AttackStats)
      @patched_classes.push(klass)
    end
    unless Battle::Battler.ancestors.include?(UseFrame)
      Battle::Battler.prepend(UseFrame)
    end

    Battle::AbilityEffects::OnEndOfUsingMove.add(:KINETIC, proc { |ability, user, targets, move, battle|
        next if !move.damagingMove?
        next if !targets.any? { |t| t.damageState.totalHPLost > 0 }
        amount = KaitoKinetic.recoil(user)
        next if amount <= 0
        frames = battle.instance_variable_get(:@kaito_kinetic_frames)
        paid = frames && frames.last
        key = user.pokemon.object_id
        next if paid && paid[key]
        paid[key] = true if paid
        user.pbReduceHP(amount, false)
        battle.pbDisplay(_INTL( "{1} is damaged by Kinetic's recoil!", user.pbThis ))
        user.pbItemHPHealCheck
        user.pbFaint if user.fainted?
      })
    Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:kaito_kinetic, proc { |score, move, user, target, ai, battle|
        next score if score <= Battle::AI::MOVE_USELESS_SCORE
        next score - KaitoKinetic.risk(move, user)
      })
    if defined?(AdvancedAI::CombatUtilities)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(CombatAI)
        singleton.prepend(CombatAI)
      end
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage)
      Battle::AI.prepend(ScorerAI) unless Battle::AI.ancestors.include?(ScorerAI)
    end
    KaitoAbilitySupport.rate(:KINETIC, 7)
  end

  # Delay installation until plugin aliases finish loading.
  module BattleConstruction
    def new(*args, &block)
      KaitoKinetic.install!
      super(*args, &block)
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoKinetic::BattleConstruction )
  Battle.singleton_class.prepend(KaitoKinetic::BattleConstruction)
end

# Vigor Dash
# Doubles Speed while HP is strictly above 75%.
Battle::AbilityEffects::SpeedCalc.add(:VIGORDASH, proc { |ability, battler, multiplier|
  if battler.hp * 4 > battler.totalhp * 3
    multiplier *= 2
  end
  next multiplier
})

# Dancing Panic - Extension for this project's existing Dance reversal system
module KaitoDancingPanic
  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.native_move(move); move.respond_to?(:move) ? move.move : move; end

  # Find an opposing, active Dancing Panic holder.
  # Multiple holders do not stack or reverse the effect twice.
  def self.holder(battle, object)
    user = real(object)
    return nil if !user || user.fainted?
    battle.allBattlers.each do |b|
      next if b.fainted?
      next if !b.opposes?(user)
      next if !b.hasActiveAbility?(:DANCINGPANIC)
      return b
    end
    return nil
  end

  def self.affected?(battle, user, move)
    move = native_move(move)
    return false if !move || !move.respond_to?(:danceMove?)
    return false if !move.danceMove?
    return !!holder(battle, user)
  end

  # AI penalty for the confusion inflicted after using the move.
  def self.confusion_penalty(battle, object)
    user = real(object)
    source = holder(battle, user)
    return 0 if !source
    return 0 if !user.pbCanConfuse?(source, false)
    return 15
  end

  # Status Dance moves using the project's existing reversal branches.
  def self.self_setup?(move)
    move = native_move(move)
    return false if !move || !move.statusMove?
    return move.is_a?(Battle::Move::StatUpMove) || move.is_a?(Battle::Move::MultiStatUpMove)
  end

  def self.target_drop?(move)
    move = native_move(move)
    return false if !move || !move.statusMove?
    return move.is_a?(Battle::Move::TargetStatDownMove) || move.is_a?(Battle::Move::TargetMultiStatDownMove)
  end

  # Shared heuristic for Native AI and Advanced AI.
  def self.adjust_score(score, battle, user, target, move, floor)
    return score if !affected?(battle, user, move)
    user = real(user)
    target = real(target) if target

    # Self-boosting Dance moves become self-debuffs.
    # Contrary reverses the debuffs again through the normal engine.
    if self_setup?(move) && !user.hasActiveAbility?(:CONTRARY)
      return [score, floor].min
    end

    # A stat-lowering Dance now boosts its recipient.
    # Do not reject this when boosting an ally, or when Contrary
    # converts the boost back into a drop on an opposing target.
    if target && target_drop?(move) && target.opposes?(user) && !target.hasActiveAbility?(:CONTRARY)
      return [score, floor].min
    end
    return score - confusion_penalty(battle, user)
  end

  module MoveHook
    def pbReverseDanceEffect?(user)
      # Preserve ALL existing reversal branches, including Feather Dance.
      return KaitoDancingPanic.affected?(@battle, user, self)
    end
  end

  module BattlerHook
    def pbEffectsAfterMove(user, targets, move, numHits)
      # This hook runs after the move's hits and direct effects.
      # Apply before post-move switching and other general effects.
      if move.danceMove? && numHits > 0 && !user.lastMoveFailed && !user.fainted?
        source = KaitoDancingPanic.holder(@battle, user)
        if source && user.pbCanConfuse?(source, false)
          @battle.pbShowAbilitySplash(source, true)
          begin
            user.pbConfuse(_INTL( "{1} became confused from the frantic rhythm!", user.pbThis ))
          ensure
            @battle.pbHideAbilitySplash(source)
          end
        end
      end
      return super
    end
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return KaitoDancingPanic.adjust_score( score, @battle, user, target, move, -100 )
    end
  end

  def self.install_ai!
    return if !defined?(AdvancedAI)
    return if !Battle::AI.method_defined?(:score_move_advanced)
    return if Battle::AI.ancestors.include?(AdvancedScoring)
    Battle::AI.prepend(AdvancedScoring)
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoDancingPanic.install_ai!
      super(*args, &block)
    end
  end
end
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
  :kaito_dancing_panic,
  proc { |score, move, user, target, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next KaitoDancingPanic.adjust_score( score, battle, user, target, move, Battle::AI::MOVE_USELESS_SCORE )
  })
unless Battle.singleton_class.ancestors.include?( KaitoDancingPanic::BattleConstruction )
  Battle.singleton_class.prepend(KaitoDancingPanic::BattleConstruction)
end

# Hydroponic
# Grass moves deal 30% more damage in rain OR Swamp Terrain.
module KaitoHydroponic
  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.battle_of(object)
    object = real(object)
    return nil if !object
    return object.instance_variable_get(:@battle)
  end

  def self.has?(object)
    user = real(object)
    return false if !user || user.fainted?
    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(:HYDROPONIC)
    end

    # Reserve Pokemon: ordinary ability plus unlocked innates.
    return true if user.respond_to?(:ability_id) && user.ability_id == :HYDROPONIC
    return user.respond_to?(:set_innate_limits) && Array(user.set_innate_limits).include?(:HYDROPONIC)
  end

  def self.active?(object, type, battle = nil)
    return false if type != :GRASS || !has?(object)
    user = real(object)
    battle ||= battle_of(user)

    # OR condition: never apply two multipliers.
    return true if battle && battle.field.terrain == :Swamp
    weather = if user.respond_to?(:effectiveWeather)
                user.effectiveWeather
              elsif battle
                battle.pbWeather
              end
    return [:Rain, :HeavyRain].include?(weather)
  end

  module CombatAI
    def ability_damage_modifier( attacker, target, type, physical, effectiveness, move = nil, physical_defense = physical )
      value = super
      battle = KaitoHydroponic.battle_of(attacker) || KaitoHydroponic.battle_of(target) || KaitoHydroponic.battle_of(move)
      if KaitoHydroponic.active?(attacker, type, battle)
        value *= 1.3
      end
      return value
    end
  end

  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      native = move.respond_to?(:move) ? move.move : move
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      code = move.function_code.to_s
      return value if code.start_with?("FixedDamage", "OHKO", "Counter")
      return value if [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(code)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      return value if !KaitoHydroponic.active?(user, type, @battle)
      return [(value * 1.3).round, 1].max
    end
  end

  def self.install_ai!
    if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(KaitoHydroponic::CombatAI)
        singleton.prepend(KaitoHydroponic::CombatAI)
      end
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage)
      unless Battle::AI.ancestors.include?(KaitoHydroponic::ScorerAI)
        Battle::AI.prepend(KaitoHydroponic::ScorerAI)
      end
    end
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoHydroponic.install_ai!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::DamageCalcFromUser.add(:HYDROPONIC, proc { |ability, user, target, move, mults, power, type|
  if KaitoHydroponic.active?(user, type)
    mults[:power_multiplier] *= 1.3
  end
})
unless Battle.singleton_class.ancestors.include?( KaitoHydroponic::BattleConstruction )
  Battle.singleton_class.prepend(KaitoHydroponic::BattleConstruction)
end

# Dancing Panic - No announcement on switch-in.
Battle::AbilityEffects::OnSwitchIn.add(:DANCINGPANIC, proc { |ability, battler, battle, switch_in|
  # No switch-in announcement.
})

# Seaweed
# Halves incoming Fire damage.
# Grass is super effective against the target's Fire typing.
module KaitoSeaweed
  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.has?(object)
    object = real(object)
    return false if !object || object.fainted?
    if object.respond_to?(:hasActiveAbility?)
      return object.hasActiveAbility?(:SEAWEED)
    end
    return true if object.respond_to?(:ability_id) && object.ability_id == :SEAWEED
    return object.respond_to?(:set_innate_limits) && Array(object.set_innate_limits).include?(:SEAWEED)
  end

  def self.fire_resistance(user, target, move, type)
    return 1.0 if type != :FIRE || !has?(target)
    return 1.0 if AdvancedAI::Utilities.ignores_ability?( user, move, target )
    return 0.5
  end

  # Actual battle and Native AI type effectiveness.
  module TypeEffect
    def pbCalcTypeModSingle(moveType, defType, user, target)
      if moveType == :GRASS && defType == :FIRE && KaitoSeaweed.has?(user)
        return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
      end
      return super
    end
  end

  module CombatAI
    # Both Advanced AI damage paths use this type-effectiveness helper.
    def move_type_effectiveness(move, user, defender, effective_type = nil)
      value = super
      type = effective_type || resolve_move_type(user, move)
      return value if type != :GRASS || !KaitoSeaweed.has?(user)
      target = KaitoSeaweed.real(defender)
      types = target.respond_to?(:pbTypes) ? target.pbTypes(true) : target.types

      # Grass vs Fire changes from 0.5 to 2: ratio = 4.
      return types.include?(:FIRE) ? value * 4 : value
    end

    def ability_damage_modifier( user, target, type, physical, effectiveness, move = nil, physical_defense = physical )
      value = super
      return value * KaitoSeaweed.fire_resistance( user, target, move, type )
    end
  end

  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      native = move.respond_to?(:move) ? move.move : move
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      code = move.function_code.to_s
      return value if code.start_with?("FixedDamage", "OHKO", "Counter")
      return value if [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(code)

      # Terrain delegation already uses the shared damage estimator.
      if @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      factor = KaitoSeaweed.fire_resistance(user, target, move, type)
      return value if factor == 1.0
      return [(value * factor).round, 1].max
    end
  end

  def self.install!
    # Patch classes that define their own per-type calculation as well.
    @patched_classes ||= []
    ObjectSpace.each_object(Class) do |klass|
      next if !(klass <= Battle::Move)
      next if !klass.instance_methods(false).include?(:pbCalcTypeModSingle)
      next if @patched_classes.include?(klass)
      klass.prepend(TypeEffect)
      @patched_classes.push(klass)
    end
    if defined?(AdvancedAI::CombatUtilities)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage)
      Battle::AI.prepend(ScorerAI) unless Battle::AI.ancestors.include?(ScorerAI)
    end
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoSeaweed.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::DamageCalcFromTarget.add(:SEAWEED, proc { |ability, user, target, move, mults, power, type| mults[:final_damage_multiplier] *= 0.5 if type == :FIRE }
)
unless Battle.singleton_class.ancestors.include?( KaitoSeaweed::BattleConstruction )
  Battle.singleton_class.prepend(KaitoSeaweed::BattleConstruction)
end

# Hushed Soar
# Actual battle priority + Native AI / Advanced AI scoring.
module KaitoHushedSoar
  ABILITY = :HUSHEDSOAR

  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.native(move); move.respond_to?(:move) ? move.move : move; end

  def self.active?(object)
    battler = real(object)
    return false if !battler || battler.fainted?
    return false if !battler.respond_to?(:hasActiveAbility?)
    return battler.hasActiveAbility?(ABILITY)
  end

  def self.move_choice?(battle, battler)
    choice = battle.choices[battler.index]
    return choice && choice[0] == :UseMove && choice[2]
  end

  def self.boosted_priority(original, opposing_priority)
    return original if opposing_priority.nil? || opposing_priority <= 0
    return [original, opposing_priority + 1].max
  end
  # Actual battle: use the completed engine priority table.
  module BattleHook
    def pbCalculatePriority(fullCalc = false, indexArray = nil)
      # Remove our old contribution before any full/partial recalculation.
      if @priority
        @priority.each do |entry|
          saved = entry.instance_variable_get(:@kaito_hushed_original)
          next if saved.nil?
          entry[5] = saved
          choice = @choices[entry[0].index]
          choice[4] = saved if choice && choice[0] == :UseMove
          entry.remove_instance_variable(:@kaito_hushed_original)
        end
      end
      result = super
      return result if !@priority || @priority.empty?

      # Snapshot before applying ANY Hushed Soar.
      snapshot = @priority.map { |entry| [entry, entry[5], entry[4]] }
      snapshot.each do |entry, original, subpriority|
        user = entry[0]
        next if !KaitoHushedSoar.active?(user)
        next if !KaitoHushedSoar.move_choice?(self, user)
        highest = nil
        snapshot.each do |foe_entry, foe_priority, foe_subpriority|
          foe = foe_entry[0]
          next if foe.fainted? || !foe.opposes?(user)
          next if !KaitoHushedSoar.move_choice?(self, foe)

          # Positive sub-priority is an additional virtual point.
          value = foe_priority + (foe_subpriority > 0 ? 1 : 0)
          next if value <= 0
          highest = value if highest.nil? || value > highest
        end
        boosted = KaitoHushedSoar.boosted_priority(original, highest)
        next if boosted == original
        entry.instance_variable_set(:@kaito_hushed_original, original)
        entry[5] = boosted
        @choices[user.index][4] = boosted
      end

      # Match the engine's ordering, including Trick Room and tie-breakers.
      @priority.sort! do |a, b|
        if a[5] != b[5]
          b[5] <=> a[5]
        elsif a[4] != b[4]
          b[4] <=> a[4]
        elsif a[1] == b[1]
          b[6] <=> a[6]
        elsif @priorityTrickRoom
          a[1] <=> b[1]
        else
          b[1] <=> a[1]
        end
      end
      return result
    end
  end
  # AI: evaluate base priority without modifying the actual battler.
  # Do not inspect battle.choices or reroll priority items.
  def self.base_priority(object, move)
    battler = real(object)
    move = native(move)
    return 0 if !battler || !move
    return move.priority.to_i if !move.respond_to?(:pbPriority)
    probe = battler.dup
    probe.instance_variable_set(:@effects, battler.effects.dup)
    probe.instance_variable_set(:@stages, battler.stages.dup)
    previous_name = $aamName
    begin
      priority = move.pbPriority(probe)
      if probe.abilityActive?
        priority = Battle::AbilityEffects.triggerPriorityChange( probe.ability, probe, move, priority )
      end
      return priority
    ensure
      $aamName = previous_name
    end
  end

  # Known probability of positive sub-priority.
  # Actual battle still uses the engine's real result for every item/ability.
  def self.quick_chance(battler)
    ability_chance = battler.hasActiveAbility?(:QUICKDRAW) ? 0.30 : 0.0
    item_chance = 0.0
    if battler.hasActiveItem?(:QUICKCLAW)
      item_chance = 0.20
    elsif battler.hasActiveItem?(:CUSTAPBERRY) && battler.canConsumePinchBerry?
      item_chance = 1.0
    end
    return 1.0 - (1.0 - ability_chance) * (1.0 - item_chance)
  end

  # Distribution of a foe's possible priority, using usable moves.
  # Equal move weights are a heuristic, not knowledge of their chosen move.
  def self.foe_distribution(battle, foe)
    options = []
    foe.moves.each_with_index do |move, index|
      next if !move
      next if !battle.pbCanChooseMove?(foe.index, index, false)
      next if move.id == :FAKEOUT && foe.turnCount > 0
      options.push(base_priority(foe, move))
    end
    return { 0 => 1.0 } if options.empty?
    quick = quick_chance(foe)
    result = Hash.new(0.0)
    weight = 1.0 / options.length
    options.each do |priority|
      result[priority] += weight * (1.0 - quick)
      result[priority + 1] += weight * quick
    end
    return result
  end

  # Combine all opponents: use their maximum, never sum their priorities.
  def self.opposing_distribution(battle, user)
    result = { 0 => 1.0 }
    battle.allBattlers.each do |foe|
      next if foe.fainted? || !foe.opposes?(user)
      combined = Hash.new(0.0)
      options = foe_distribution(battle, foe)
      result.each do |current, probability|
        options.each do |priority, chance|
          combined[[current, priority].max] += probability * chance
        end
      end
      result = combined
    end
    return result
  end

  def self.priority_blocked?(battle, user, target, move)
    return false if !target || !target.opposes?(user)
    if battle.field.terrain == :Psychic && target.affectedByTerrain?
      return true
    end
    ignores = if defined?(AdvancedAI::Utilities)
                AdvancedAI::Utilities.ignores_ability?(user, move, target)
              else
                user.hasMoldBreaker?
              end
    return false if ignores
    blockers = [:DAZZLING, :QUEENLYMAJESTY, :ARMORTAIL]
    return battle.allBattlers.any? do |b| !b.fainted? && !b.opposes?(target) && blockers.any? { |ability| b.hasActiveAbility?(ability) } end
  end

  def self.score_adjustment(battle, object, target_object, move)
    user = real(object)
    target = real(target_object)
    move = native(move)
    return 0 if !user || !target || !move
    return 0 if user.fainted? || target.fainted?
    original = base_priority(user, move)
    adjustment = 0.0
    if active?(user)
      probability = 0.0
      opposing_distribution(battle, user).each do |priority, chance|
        boosted = boosted_priority(original, priority)
        probability += chance if boosted > original
      end
      if probability > 0
        if original <= 0 && priority_blocked?(battle, user, target, move)
          # Becoming positive-priority can make the move fail.
          adjustment -= 100 * probability
        else
          # Prefer useful damage/healing when priority is likely to improve.
          value = move.damagingMove? ? 20 : 8
          value += 10 if user.hp * 3 <= user.totalhp
          adjustment += value * probability
        end
      end
    end

    # Also recognise the danger of feeding priority to an opposing holder.
    # A positive-priority move cannot rely on outspeeding that holder.
    if target.opposes?(user) && active?(target)
      virtual = original + quick_chance(user)
      if virtual > 0
        adjustment -= move.damagingMove? ? 25 : 10
      end
    end
    return adjustment.round
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= -100
      return score + KaitoHushedSoar.score_adjustment( @battle, user, target, move )
    end
  end

  def self.install_ai!
    return if !defined?(AdvancedAI)
    return if !Battle::AI.method_defined?(:score_move_advanced)
    return if Battle::AI.ancestors.include?(AdvancedScoring)
    Battle::AI.prepend(AdvancedScoring)
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoHushedSoar.install_ai!
      super(*args, &block)
    end
  end
end
unless Battle.ancestors.include?(KaitoHushedSoar::BattleHook)
  Battle.prepend(KaitoHushedSoar::BattleHook)
end
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
  :kaito_hushed_soar,
  proc { |score, move, user, target, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE

    # Advanced AI receives its adjustment through AdvancedScoring.
    # Avoid a second adjustment if it delegates to Native scoring.
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:score_move_advanced)
      next score
    end
    next score + KaitoHushedSoar.score_adjustment( battle, user, target, move )
  })
unless Battle.singleton_class.ancestors.include?( KaitoHushedSoar::ConstructionHook )
  Battle.singleton_class.prepend(KaitoHushedSoar::ConstructionHook)
end

# Mind Insight
# Normal attacks gain Psychic's super-effective matchups and can hit Ghost.
# Includes Native AI and Advanced AI type-effectiveness support.
module KaitoMindInsight
  ABILITY = :MINDINSIGHT

  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.active?(object)
    user = real(object)
    return false if !user || user.fainted?
    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ABILITY)
    end

    # Reserve Pokemon: ordinary ability and unlocked innates.
    return true if user.respond_to?(:ability_id) && user.ability_id == ABILITY
    return user.respond_to?(:set_innate_limits) && Array(user.set_innate_limits).include?(ABILITY)
  end

  # nil means this ability does not override this defensive type.
  def self.override(defending_type)
    if Effectiveness.super_effective_type?(:PSYCHIC, defending_type)
      return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
    end
    if defending_type == :GHOST
      return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    end
    return nil
  end

  module MoveHook
    def pbCalcTypeModSingle(moveType, defType, user, target)
      if moveType == :NORMAL && damagingMove? && KaitoMindInsight.active?(user)
        replacement = KaitoMindInsight.override(defType)
        return replacement unless replacement.nil?
      end
      return super
    end
  end

  module AdvancedTypes
    def move_type_effectiveness(move, user, defender, effective_type = nil)
      type = effective_type || resolve_move_type(user, move)
      unless type == :NORMAL && KaitoMindInsight.active?(user)
        return super
      end
      native = move.respond_to?(:move) ? move.move : move
      info = GameData::Move.try_get(move.id)
      return super if !info || info.category == 2
      attacker = KaitoMindInsight.real(user)
      target = KaitoMindInsight.real(defender)

      # Live battlers: use the actual engine calculation, preserving
      # move-specific rules and the project's other type-effectiveness hooks.
      if native.is_a?(Battle::Move) && attacker.is_a?(Battle::Battler) && target.is_a?(Battle::Battler)
        return native.pbCalcTypeMod(type, attacker, target)
      end

      # Reserve Pokemon / MoveProxy prediction.
      types = target.respond_to?(:pbTypes) ? target.pbTypes(true) : target.types
      value = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      types.each do |def_type|
        multiplier = KaitoMindInsight.override(def_type)
        if multiplier.nil?
          multiplier = Effectiveness.calculate(type, def_type)
        end
        value = value * multiplier / Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
      return value
    end
  end

  def self.install!
    # Include move subclasses defining their own per-type calculation.
    @patched_classes ||= []
    ObjectSpace.each_object(Class) do |klass|
      next if !(klass <= Battle::Move)
      next if !klass.instance_methods(false).include?(:pbCalcTypeModSingle)
      next if @patched_classes.include?(klass)
      klass.prepend(MoveHook)
      @patched_classes.push(klass)
    end
    if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:move_type_effectiveness)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(AdvancedTypes)
        singleton.prepend(AdvancedTypes)
      end
    end
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoMindInsight.install!
      super(*args, &block)
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoMindInsight::BattleConstruction )
  Battle.singleton_class.prepend(KaitoMindInsight::BattleConstruction)
end

# Mind Insight - Additional Psychic STAB
# Requires the existing KaitoMindInsight implementation.
module KaitoMindInsight
  def self.has_ability?(object, ability)
    user = real(object)
    return false if !user
    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ability)
    end
    return true if user.respond_to?(:ability_id) && user.ability_id == ability
    return user.respond_to?(:set_innate_limits) && Array(user.set_innate_limits).include?(ability)
  end

  def self.psychic_stab; :PSYCHIC; end

  def self.desired_stab(object)
    user = real(object)
    stellar = user.respond_to?(:tera?) && user.tera? && user.tera_type == :STELLAR
    return 2.0 if !stellar && has_ability?(user, :ADAPTABILITY)
    return 1.5
  end

  # STAB already granted by the actual engine, including Terastallization.
  def self.engine_stab(object)
    user = real(object)
    type = psychic_stab
    adaptability = has_ability?(user, :ADAPTABILITY)
    existing = 1.0
    if user.respond_to?(:tera?) && user.tera?
      stellar = user.tera_type == :STELLAR
      adaptability = false if stellar
      if user.pbPreTeraTypes.include?(type)
        existing = if user.typeTeraBoosted?(type)
                     adaptability ? 2.25 : 2.0
                   else
                     adaptability ? 2.0 : 1.5
                   end
      elsif user.typeTeraBoosted?(type)
        existing = adaptability ? 2.0 : (stellar ? 1.2 : 1.5)
      end
    else
      matches = user.respond_to?(:pbHasType?) ? user.pbHasType?(type) : user.types.include?(type)
      existing = adaptability ? 2.0 : 1.5 if matches
    end

    # Respect the existing Mimicry original-type STAB extension.
    if defined?(MimicryOriginalSTAB) && MimicryOriginalSTAB.retains_stab?(user, type)
      existing = [ existing, MimicryOriginalSTAB.retained_stab(user) ].max
    end
    return existing
  end

  def self.extra_stab(object, type)
    return 1.0 if type != psychic_stab || !active?(object)
    existing = engine_stab(object)
    return [existing, desired_stab(object)].max / existing
  end

  # Advanced AI currently calculates ordinary STAB separately.
  def self.ai_extra_stab(object, type)
    return 1.0 if type != psychic_stab || !active?(object)
    user = real(object)
    matches = user.respond_to?(:pbHasType?) ? user.pbHasType?(type) : user.types.include?(type)
    existing = matches ? 1.5 : 1.0
    existing = 2.0 if matches && has_ability?(user, :ADAPTABILITY)
    if has_ability?(user, :PROTEAN) || has_ability?(user, :LIBERO)
      existing = [existing, 1.5].max
    end
    if defined?(MimicryOriginalSTAB) && MimicryOriginalSTAB.retains_stab?(user, type)
      existing = [ existing, MimicryOriginalSTAB.retained_stab(user) ].max
    end
    return [existing, desired_stab(user)].max / existing
  end

  module PsychicCombatAI
    def ability_damage_modifier( user, target, type, physical, effectiveness, move = nil, physical_defense = physical )
      value = super
      return value * KaitoMindInsight.ai_extra_stab(user, type)
    end
  end

  module PsychicScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      native = move.respond_to?(:move) ? move.move : move
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      code = move.function_code.to_s
      return value if code.start_with?("FixedDamage", "OHKO", "Counter")
      return value if [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(code)

      # Avoid applying STAB twice through shared-estimator delegation.
      if @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      factor = KaitoMindInsight.ai_extra_stab(user, type)
      return value if factor == 1.0
      return [(value * factor).round, 1].max
    end
  end

  module PsychicInstaller
    def install!
      super
      if defined?(AdvancedAI::CombatUtilities)
        singleton = AdvancedAI::CombatUtilities.singleton_class
        unless singleton.ancestors.include?(PsychicCombatAI)
          singleton.prepend(PsychicCombatAI)
        end
      end
      if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage) && !Battle::AI.ancestors.include?(PsychicScorerAI)
        Battle::AI.prepend(PsychicScorerAI)
      end
    end
  end
end

Battle::AbilityEffects::DamageCalcFromUser.add(:MINDINSIGHT, proc { |ability, user, target, move, mults, power, type|
  mults[:final_damage_multiplier] *= KaitoMindInsight.extra_stab(user, type)
})
unless KaitoMindInsight.singleton_class.ancestors.include?( KaitoMindInsight::PsychicInstaller )
  KaitoMindInsight.singleton_class.prepend( KaitoMindInsight::PsychicInstaller )
end

# Oleum Burst
# An opposing hit removing more than 1/3 max HP lowers the attacker's Speed.
Battle::AbilityEffects::OnBeingHit.add(:OLEUMBURST, proc { |ability, user, target, move, battle|
  next if !user || !target || !move
  next if user.fainted? || !user.opposes?(target)
  next if target.damageState.substitute
  next if target.damageState.hpLost * 3 <= target.totalhp

  # Standard stat-drop handling: Contrary, Simple, immunities,
  # Mirror Armor, stat limits, ability splash and messages.
  user.pbLowerStatStageByAbility(:SPEED, 1, target)
})

# Native AI + Advanced AI scoring
module KaitoOleumBurst
  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.applicable?(user, target, move)
    user = real(user)
    target = real(target)
    native = move.respond_to?(:move) ? move.move : move
    return false if !user || !target || !native
    return false if user.fainted? || target.fainted?
    return false if !user.opposes?(target)
    return false if !target.hasActiveAbility?(:OLEUMBURST)
    return false if !native.damagingMove?
    if target.effects[PBEffects::Substitute] > 0 && !native.ignoresSubstitute?(user)
      return false
    end
    return true
  end

  # Positive values are bonuses; negative values are penalties.
  def self.adjustment(user, target, estimated_damage)
    user = real(user)
    target = real(target)
    return 0 if !estimated_damage || estimated_damage <= 0

    # Compare actual predicted HP loss, not overkill damage.
    lost = [estimated_damage, target.hp].min
    return 0 if lost * 3 <= target.totalhp
    return 0 if !user.pbCanLowerStatStage?(:SPEED, target, nil, false)

    # Contrary turns the Speed drop into a benefit.
    return 12 if user.hasActiveAbility?(:CONTRARY)

    # Mirror Armor can reflect the drop back to the defender.
    if user.hasActiveAbility?(:MIRRORARMOR)
      return target.hp > lost ? 8 : 0
    end
    penalty = 12
    penalty += 8 if user.hasActiveAbility?(:SIMPLE)

    # Losing a speed advantage is particularly costly.
    if user.pbSpeed > target.pbSpeed
      stage = user.stages[:SPEED]
      before = stage >= 0 ? (2.0 + stage) / 2 : 2.0 / (2 - stage)
      after_stage = [stage - 1, -6].max
      after = after_stage >= 0 ? (2.0 + after_stage) / 2 : 2.0 / (2 - after_stage)
      predicted_speed = user.pbSpeed * after / before
      penalty += 10 if predicted_speed < target.pbSpeed
    end

    # Stat-drop-triggered offensive boosts can offset the drawback.
    penalty -= 20 if user.hasActiveAbility?(:DEFIANT) || user.hasActiveAbility?(:COMPETITIVE)
    return -penalty
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      # Prevent duplicate scoring if Advanced AI delegates to Native handlers.
      @kaito_oleum_scoring_depth = @kaito_oleum_scoring_depth.to_i + 1
      begin
        score = super
        return score if score <= -100
        return score if !KaitoOleumBurst.applicable?(user, target, move)
        damage = calculate_rough_damage(move, user, target)
        return score + KaitoOleumBurst.adjustment( user, target, damage )
      ensure
        @kaito_oleum_scoring_depth -= 1
      end
    end
  end

  def self.install_ai!
    return if !defined?(AdvancedAI)
    return if !Battle::AI.method_defined?(:score_move_advanced)
    return if Battle::AI.ancestors.include?(AdvancedScoring)
    Battle::AI.prepend(AdvancedScoring)
  end

  module BattleConstruction
    def new(*args, &block)
      KaitoOleumBurst.install_ai!
      super(*args, &block)
    end
  end
end
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
  :kaito_oleum_burst,
  proc { |score, move, user, target, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next score if ai.instance_variable_get( :@kaito_oleum_scoring_depth ).to_i > 0
    next score if !KaitoOleumBurst.applicable?(user, target, move)
    next score + KaitoOleumBurst.adjustment( user, target, move.rough_damage )
  })
unless Battle.singleton_class.ancestors.include?( KaitoOleumBurst::BattleConstruction )
  Battle.singleton_class.prepend(KaitoOleumBurst::BattleConstruction)
end

# Tengu Reprisal
# Once per entry:
# - Cures a newly received opposing major status/confusion/flinch/attraction.
# - Uses Leaf Tornado without consuming the normal action.
# - Supports Early Bird waking-turn priority and AI scoring.
module KaitoTenguReprisal
  ABILITY = :TENGUREPRISAL
  MOVE    = :LEAFTORNADO

  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.ready?(object)
    b = real(object)
    return false if !b || b.fainted?
    return false if !b.respond_to?(:hasActiveAbility?)
    return false if b.instance_variable_get(:@kaito_tr_used)
    return b.hasActiveAbility?(ABILITY)
  end
  # Track the actual source of an effect.
  def self.with_origin(battle, source)
    old = battle.instance_variable_get(:@kaito_tr_origin)
    battle.instance_variable_set(:@kaito_tr_origin, source)
    begin
      return yield
    ensure
      battle.instance_variable_set(:@kaito_tr_origin, old)
    end
  end

  def self.state(b, kind)
    case kind
    when :pbInflictStatus
      return [b.status, b.statusCount]
    when :pbConfuse
      return b.effects[PBEffects::Confusion]
    when :pbAttract
      return b.effects[PBEffects::Attract]
    when :pbFlinch
      return b.effects[PBEffects::Flinch]
    end
  end
  # Cure only the newly received effect, then queue the retaliation.
  def self.try_trigger(b)
    return if !ready?(b)
    stack = b.instance_variable_get(:@kaito_tr_receiving)
    frame = stack && stack.last
    return if !frame
    kind, before, source = frame
    source = real(source)
    return if !source || !source.respond_to?(:opposes?)
    return if source.equal?(b) || !source.opposes?(b)
    current = state(b, kind)
    return if current == before
    valid = case kind
            when :pbInflictStatus then b.status != :NONE
            when :pbConfuse       then current.to_i > 0
            when :pbAttract       then current.to_i >= 0
            when :pbFlinch        then current == true
            end
    return if !valid

    # Consume first to prevent recursive activation during cure callbacks.
    b.instance_variable_set(:@kaito_tr_used, true)
    battle = b.instance_variable_get(:@battle)
    queue = battle.instance_variable_get(:@kaito_tr_queue)
    if !queue
      queue = []
      battle.instance_variable_set(:@kaito_tr_queue, queue)
    end
    queue.push([ b, b.pokemon, b.instance_variable_get(:@kaito_tr_generation) ])
    was_asleep = kind == :pbInflictStatus && b.status == :SLEEP
    battle.pbShowAbilitySplash(b, true)
    begin
      case kind
      when :pbInflictStatus
        # Calls the existing Early Bird wake-record hook.
        b.pbCureStatus(false)
      when :pbConfuse
        b.pbCureConfusion
      when :pbAttract
        b.pbCureAttract
      when :pbFlinch
        b.effects[PBEffects::Flinch] = false
      end
      battle.pbDisplay(_INTL( "{1} broke free with its fighting spirit!", b.pbThis ))
    ensure
      battle.pbHideAbilitySplash(b)
    end
    if was_asleep && b.status != :SLEEP && b.hasActiveAbility?(:EARLYBIRD)
      battle.instance_variable_set(:@kaito_tr_refresh_priority, true)
    end
  end

  def self.same_entry?(b, pokemon, generation)
    return b.pokemon.equal?(pokemon) && b.instance_variable_get(:@kaito_tr_generation) == generation
  end
  # Resolve queued moves outside the current move/action/switching operation.
  def self.flush(battle)
    return if battle.instance_variable_get(:@kaito_tr_busy).to_i > 0
    return if battle.instance_variable_get(:@kaito_tr_draining)
    battle.instance_variable_set(:@kaito_tr_draining, true)
    begin
      queue = battle.instance_variable_get(:@kaito_tr_queue) || []
      until queue.empty?
        b, pokemon, generation = queue.shift
        next if !same_entry?(b, pokemon, generation) || b.fainted?
        next if battle.decision != 0
        foes = battle.allBattlers.select do |foe|
          !foe.fainted? && foe.opposes?(b) && foe.near?(b)
        end
        next if foes.empty?
        target = foes[battle.pbRandom(foes.length)]
        saved = [ b.lastRoundMoved, b.currentMove, b.lastMoveFailed, b.effects[PBEffects::Dancer], b.effects[PBEffects::Outrage] ]
        begin
          # Dancer-style called move: preserve the normal action.
          b.effects[PBEffects::Dancer] = true
          if saved[4] > 0
            b.effects[PBEffects::Outrage] = saved[4] + 1
          end
          b.pbUseMoveSimple(MOVE, target.index)
        ensure
          # Never restore old state onto a replacement Pokemon.
          if same_entry?(b, pokemon, generation)
            b.lastRoundMoved = saved[0]
            b.currentMove = saved[1]
            b.lastMoveFailed = saved[2]
            b.effects[PBEffects::Dancer] = saved[3]
            b.effects[PBEffects::Outrage] = saved[4]
          end
        end
      end
    ensure
      battle.instance_variable_set(:@kaito_tr_draining, false)
    end

    # Refresh after all reactions, preserving the engine's item rolls.
    if battle.instance_variable_get(:@kaito_tr_refresh_priority)
      battle.instance_variable_set(:@kaito_tr_refresh_priority, false)
      priority = battle.instance_variable_get(:@priority)
      if battle.decision == 0 && priority && !priority.empty?
        battle.pbCalculatePriority(false)
      end
    end
  end

  def self.boundary(battle)
    old = battle.instance_variable_get(:@kaito_tr_busy).to_i
    battle.instance_variable_set(:@kaito_tr_busy, old + 1)
    begin
      result = yield
    ensure
      battle.instance_variable_set(:@kaito_tr_busy, old)
    end
    flush(battle)
    return result
  end
  # Battler hooks.
  module BattlerHook
    def pbInitEffects(batonPass)
      result = super
      @kaito_tr_generation = @kaito_tr_generation.to_i + 1
      @kaito_tr_used = false
      @kaito_tr_receiving = []
      return result
    end
    [:pbInflictStatus, :pbConfuse, :pbAttract, :pbFlinch].each do |kind|
      define_method(kind) do |*args, &block|
        source = case kind
                 when :pbInflictStatus
                   args[3]
                 when :pbAttract, :pbFlinch
                   args[0]
                 end
        source ||= @battle.instance_variable_get(:@kaito_tr_origin)
        @kaito_tr_receiving ||= []
        @kaito_tr_receiving.push([ kind, KaitoTenguReprisal.state(self, kind), source ])
        begin
          result = super(*args, &block)
          KaitoTenguReprisal.try_trigger(self)
        ensure
          @kaito_tr_receiving.pop
        end
        KaitoTenguReprisal.flush(@battle)
        return result
      end
    end

    # Give the ability the opportunity to cure before status berries.
    def pbItemStatusCureCheck(*args, &block)
      KaitoTenguReprisal.try_trigger(self)
      return super(*args, &block)
    end
    [:pbUseMove, :pbProcessTurn].each do |name|
      define_method(name) do |*args, &block|
        KaitoTenguReprisal.boundary(@battle) do
          super(*args, &block)
        end
      end
    end
  end

  module BattleHook
    [:pbRecallAndReplace, :pbOnAllBattlersEnteringBattle, :pbEndOfRoundPhase].each do |name|
      define_method(name) do |*args, &block|
        KaitoTenguReprisal.boundary(self) do
          super(*args, &block)
        end
      end
    end
  end

  module MoveOrigin
    [:pbEffectGeneral, :pbEffectAgainstTarget, :pbAdditionalEffect, :pbEffectAfterAllHits].each do |name|
      define_method(name) do |*args, &block|
        KaitoTenguReprisal.with_origin(@battle, args[0]) do
          super(*args, &block)
        end
      end
    end
  end

  module AbilityOrigin
    def triggerOnBeingHit(ability, user, target, move, battle)
      KaitoTenguReprisal.with_origin(battle, target) do
        super
      end
    end

    def triggerOnDealingHit(ability, user, target, move, battle)
      KaitoTenguReprisal.with_origin(battle, user) do
        super
      end
    end
  end
  # AI: heuristic penalty for triggering an unused Tengu Reprisal.
  def self.ai_adjustment(user, target, move)
    user = real(user)
    target = real(target)
    move = move.move if move.respond_to?(:move)
    return 0 if !user || !target || !move
    return 0 if !user.opposes?(target) || !ready?(target)
    info = GameData::Move.try_get(move.id)
    return 0 if !info
    code = info.function_code.to_s
    return 0 if code !~ /(Sleep|Poison|Burn|Paraly[sz]e|Freeze|Frostbite|Confuse|Flinch|Attract)Target/
    if target.effects[PBEffects::Substitute] > 0 && !move.ignoresSubstitute?(user)
      return 0
    end
    chance = 1.0
    if move.damagingMove?
      return 0 if user.hasActiveAbility?(:SHEERFORCE)
      return 0 if target.hasActiveItem?(:COVERTCLOAK)
      ignores = defined?(AdvancedAI::Utilities) && AdvancedAI::Utilities.ignores_ability?(user, move, target)
      return 0 if target.hasActiveAbility?(:SHIELDDUST) && !ignores
      chance = [info.effect_chance / 100.0, 1.0].min
      if user.hasActiveAbility?(:SERENEGRACE)
        chance = [chance * 2, 1.0].min
      end
    end
    penalty = move.damagingMove? ? 30 : 60
    if code.include?("SleepTarget") && target.hasActiveAbility?(:EARLYBIRD)
      penalty += 15
    end
    return -(penalty * chance).round
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      @kaito_tr_ai_depth = @kaito_tr_ai_depth.to_i + 1
      begin
        score = super
        return score if score <= -100
        return score + KaitoTenguReprisal.ai_adjustment( user, target, move )
      ensure
        @kaito_tr_ai_depth -= 1
      end
    end
  end

  def self.install!
    # Install only when a Battle is constructed, after plugin loading.
    unless Battle::Battler.ancestors.include?(BattlerHook)
      Battle::Battler.prepend(BattlerHook)
    end
    unless Battle.ancestors.include?(BattleHook)
      Battle.prepend(BattleHook)
    end
    singleton = Battle::AbilityEffects.singleton_class
    unless singleton.ancestors.include?(AbilityOrigin)
      singleton.prepend(AbilityOrigin)
    end
    @source_patches ||= []
    relevant = [ :pbEffectGeneral, :pbEffectAgainstTarget, :pbAdditionalEffect, :pbEffectAfterAllHits ]
    ObjectSpace.each_object(Class) do |klass|
      next if !(klass <= Battle::Move)
      next if @source_patches.include?(klass)
      next if (klass.instance_methods(false) & relevant).empty?
      klass.prepend(MoveOrigin)
      @source_patches.push(klass)
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:score_move_advanced) && !Battle::AI.ancestors.include?(AdvancedScoring)
      Battle::AI.prepend(AdvancedScoring)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoTenguReprisal.install!
      super(*args, &block)
    end
  end
end
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
  :kaito_tengu_reprisal,
  proc { |score, move, user, target, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next score if ai.instance_variable_get(:@kaito_tr_ai_depth).to_i > 0
    next score + KaitoTenguReprisal.ai_adjustment(user, target, move)
  })
unless Battle.singleton_class.ancestors.include?( KaitoTenguReprisal::ConstructionHook )
  Battle.singleton_class.prepend( KaitoTenguReprisal::ConstructionHook )
end

# Tengu Reprisal - Fix MAG applying major status twice in one call chain.
# Wait until the outer pbInflictStatus finishes before curing major status.
module KaitoTenguReprisal
  def self.defer_major_cure?(b)
    return false if !ready?(b)
    stack = b.instance_variable_get(:@kaito_tr_receiving)
    frame = stack && stack.last
    return false if !frame || frame[0] != :pbInflictStatus
    source = real(frame[2])
    return false if !source || !source.respond_to?(:opposes?)
    return false if source.equal?(b) || !source.opposes?(b)

    # Only defer for a newly applied, opposing major status.
    return b.status != :NONE && state(b, :pbInflictStatus) != frame[1]
  end

  module BattlerHook
    def pbItemStatusCureCheck(*args, &block)
      # The outer pbInflictStatus wrapper will trigger the cure after
      # MAG and all delegated status methods finish assigning the status.
      return if KaitoTenguReprisal.defer_major_cure?(self)
      KaitoTenguReprisal.try_trigger(self)
      return super(*args, &block)
    end

    def pbAbilityStatusCureCheck(*args, &block)
      return if KaitoTenguReprisal.defer_major_cure?(self)
      KaitoTenguReprisal.try_trigger(self)
      return super(*args, &block)
    end
  end
end

# Maleficent
# Gloom Moonlight: highest offensive stat x1.5, loses 1/16 max HP per turn.
module KaitoMaleficent
  ABILITY = :MALEFICENT
  WEATHER = :GloomMoonlight

  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.battle_of(object)
    object = real(object)
    object ? object.instance_variable_get(:@battle) : nil
  end

  def self.has?(object)
    user = real(object)
    return false if !user || user.fainted?
    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ABILITY)
    end
    return true if user.respond_to?(:ability_id) && user.ability_id == ABILITY
    return user.respond_to?(:set_innate_limits) && Array(user.set_innate_limits).include?(ABILITY)
  end

  def self.active?(object, battle = nil)
    user = real(object)
    return false if !has?(user)
    battle ||= battle_of(user)
    weather = if user.respond_to?(:effectiveWeather)
                user.effectiveWeather
              elsif battle
                battle.pbWeather
              end
    return weather == WEATHER
  end

  def self.staged(object, stat)
    user = real(object)
    value = stat == :ATTACK ? user.attack : user.spatk
    stage = user.respond_to?(:stages) ? user.stages[stat].to_i : 0
    stage = [[stage, -6].max, 6].min
    factor = stage >= 0 ? (2.0 + stage) / 2 : 2.0 / (2 - stage)
    return [(value * factor).floor, 1].max
  end

  def self.highest(object); return staged(object, :ATTACK) >= staged(object, :SPECIAL_ATTACK) ? :ATTACK : :SPECIAL_ATTACK; end

  # Only boost moves actually using the user's offensive stats.
  def self.factor(user, physical, move, battle = nil)
    return 1.0 if !active?(user, battle)
    if move
      info = GameData::Move.try_get(move.id)
      if info
        code = info.function_code.to_s
        return 1.0 if code.start_with?("FixedDamage", "OHKO", "Counter")
        return 1.0 if [
          "UseTargetAttackInsteadOfUserAttack",
          "UseUserDefenseInsteadOfUserAttack",
          "LowerTargetHPToUserHP",
          "UserFaintsFixedDamageUserHP",
          "MultiTurnAttackBideThenReturnDoubleDamage"
        ].include?(code)
      end
    end

    # Kinetic replaces offensive stats with Speed.
    if defined?(KaitoKinetic) && KaitoKinetic.active?(user)
      return 1.0
    end
    stat = physical ? :ATTACK : :SPECIAL_ATTACK
    return highest(user) == stat ? 1.5 : 1.0
  end

  def self.cost(object)
    user = real(object)
    return 0 if !user || !active?(user)
    return 0 if !user.respond_to?(:takesIndirectDamage?)
    return 0 if !user.takesIndirectDamage?
    return [user.totalhp / 16, 1].max
  end

  # Expected cost after weather expiration at the start of end-of-round effects.
  def self.predicted_cost(object)
    user = real(object)
    amount = cost(user)
    return 0 if amount <= 0
    battle = battle_of(user)
    if battle && battle.field.weatherDuration == 1 && battle.field.defaultWeather != WEATHER
      return 0
    end
    return amount
  end

  def self.fixed?(move)
    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)
    info = GameData::Move.try_get(move.id)
    return false if !info
    code = info.function_code.to_s
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(code)
  end

  def self.physical?(user, move, tera = false)
    info = GameData::Move.try_get(move.id)
    return false if !info
    dynamic = [:PHOTONGEYSER, :LIGHTTHATBURNSTHESKY].include?(info.id)
    source = real(user)
    dynamic ||= info.id == :TERABLAST && (tera || (source.respond_to?(:tera?) && source.tera?))
    if dynamic
      return staged(user, :ATTACK) > staged(user, :SPECIAL_ATTACK)
    end
    return info.category == 0
  end

  # Shared Advanced AI damage estimator.
  module CombatAI
    def ability_damage_modifier( user, target, type, physical, effectiveness, move = nil, physical_defense = physical )
      value = super
      battle = KaitoMaleficent.battle_of(user) || KaitoMaleficent.battle_of(target) || KaitoMaleficent.battle_of(move)
      return value * KaitoMaleficent.factor( user, physical, move, battle )
    end
  end

  # Advanced AI's separate damage calculator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      return value if KaitoMaleficent.fixed?(move)

      # These calculations already delegate to the shared estimator.
      if @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      tera = move.id == :TERABLAST && !!get_tera_type_for_move(user)
      physical = KaitoMaleficent.physical?(user, move, tera)
      factor = KaitoMaleficent.factor(user, physical, move, @battle)
      return value if factor == 1.0
      return [(value * factor).round, 1].max
    end

    # Discourage waiting out the turn when Maleficent's HP loss is dangerous.
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= -100 || !move || !user
      amount = KaitoMaleficent.predicted_cost(user)
      return score if amount <= 0 || !move.statusMove?
      native = move.respond_to?(:move) ? move.move : move
      return score if native.respond_to?(:healingMove?) && native.healingMove?
      hp = KaitoMaleficent.real(user).hp
      return score - (amount >= hp ? 35 : 5)
    end
  end

  # Native AI already obtains the offensive bonus through the damage handler.
  module NativeResidual
    def rough_end_of_round_damage; return super + KaitoMaleficent.predicted_cost(battler); end
  end

  def self.install!
    unless Battle::AI::AIBattler.ancestors.include?(NativeResidual)
      Battle::AI::AIBattler.prepend(NativeResidual)
    end
    if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage) && !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoMaleficent.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::DamageCalcFromUser.add(:MALEFICENT, proc { |ability, user, target, move, mults, power, type|
  mults[:attack_multiplier] *= KaitoMaleficent.factor( user, move.physicalMove?, move )
})

Battle::AbilityEffects::EndOfRoundWeather.add(:MALEFICENT, proc { |ability, weather, battler, battle|
  next if weather != KaitoMaleficent::WEATHER
  amount = KaitoMaleficent.cost(battler)
  next if amount <= 0
  battle.pbShowAbilitySplash(battler)
  begin
    battle.scene.pbDamageAnimation(battler)
    battler.pbReduceHP(amount, false)
    battle.pbDisplay(_INTL( "{1} was drained by its {2}!", battler.pbThis, GameData::Ability.get(:MALEFICENT).name ))
  ensure
    battle.pbHideAbilitySplash(battler)
  end
  battler.pbItemHPHealCheck
})
unless Battle.singleton_class.ancestors.include?( KaitoMaleficent::ConstructionHook )
  Battle.singleton_class.prepend(KaitoMaleficent::ConstructionHook)
end

# Capacitor
# Raises Special Defense by 1 stage after using a status move.
Battle::AbilityEffects::OnEndOfUsingMove.add(:CAPACITOR, proc { |ability, user, targets, move, battle|
  next if !user || user.fainted? || !move
  next if !move.statusMove?
  next if !user.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user)
  user.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, user)
})

# Native AI + Advanced AI
module KaitoCapacitor
  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.bonus(object, move, battle)
    user = real(object)
    native = move.respond_to?(:move) ? move.move : move
    return 0 if !user || user.fainted? || !native
    return 0 if !user.respond_to?(:hasActiveAbility?)
    return 0 if !user.hasActiveAbility?(:CAPACITOR)
    return 0 if !native.statusMove?
    return 0 if !user.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user)

    # Contrary turns Capacitor into a Special Defense drop.
    return -12 if user.hasActiveAbility?(:CONTRARY)
    special_threat = battle.allBattlers.any? do |foe|
      next false if foe.fainted? || !foe.opposes?(user)
      foe.moves.any? do |m|
        info = m && GameData::Move.try_get(m.id)
        info && info.category == 1
      end
    end
    value = special_threat ? 10 : 5
    if user.hasActiveAbility?(:SIMPLE) && user.stages[:SPECIAL_DEFENSE] <= 4
      value += 4
    end
    return value
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      @kaito_capacitor_ai_depth = @kaito_capacitor_ai_depth.to_i + 1
      begin
        score = super
        return score if score <= -100
        return score + KaitoCapacitor.bonus(user, move, @battle)
      ensure
        @kaito_capacitor_ai_depth -= 1
      end
    end
  end

  def self.install_ai!
    return if !defined?(AdvancedAI)
    return if !Battle::AI.method_defined?(:score_move_advanced)
    return if Battle::AI.ancestors.include?(AdvancedScoring)
    Battle::AI.prepend(AdvancedScoring)
  end

  # Install after all plugin aliases have loaded.
  module ConstructionHook
    def new(*args, &block)
      KaitoCapacitor.install_ai!
      super(*args, &block)
    end
  end
end
Battle::AI::Handlers::GeneralMoveScore.add(
  :kaito_capacitor,
  proc { |score, move, user, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next score if ai.instance_variable_get( :@kaito_capacitor_ai_depth ).to_i > 0
    next score + KaitoCapacitor.bonus(user, move, battle)
  })
unless Battle.singleton_class.ancestors.include?( KaitoCapacitor::ConstructionHook )
  Battle.singleton_class.prepend(KaitoCapacitor::ConstructionHook)
end

# Overcharge
# Electric attacks are super effective against Electric typing.
# Bypasses selected absorption immunities but preserves their other effects.
module KaitoOvercharge
  ABILITY = :OVERCHARGE
  ABSORBERS = [:VOLTABSORB, :MOTORDRIVE, :LIGHTNINGROD]

  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.active?(object)
    user = real(object)
    return false if !user || user.fainted?
    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ABILITY)
    end
    return true if user.respond_to?(:ability_id) && user.ability_id == ABILITY
    return user.respond_to?(:set_innate_limits) && Array(user.set_innate_limits).include?(ABILITY)
  end

  # PBS lookup also supports Advanced AI MoveProxy objects.
  def self.applies?(user, move, type)
    return false if type != :ELECTRIC || !active?(user)
    return false if !move
    info = GameData::Move.try_get(move.id)
    return info && info.category != 2
  end

  def self.absorber?(ability)
    ability = ability.id if ability.respond_to?(:id)
    return ABSORBERS.include?(ability)
  end
  # Actual type effectiveness + Native AI.
  module MoveType
    def pbCalcTypeModSingle(moveType, defType, user, target)
      if defType == :ELECTRIC && KaitoOvercharge.applies?(user, self, moveType)
        return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
      end
      return super
    end
  end
  # Wrap each individual immunity handler, not the aggregate innate result.
  # The original handler still performs healing/stat boosts.
  # Other immunity abilities remain able to block the attack.
  module ImmunityHandler
    def trigger(ability, user, target, move, type, battle, show_message)
      bypass = KaitoOvercharge.absorber?(ability) && KaitoOvercharge.applies?(user, move, type)
      if bypass && show_message
        # Avoid the original "doesn't affect" message when no benefit is possible.
        benefit = case ability
                  when :VOLTABSORB
                    target.canHeal?
                  when :MOTORDRIVE
                    target.pbCanRaiseStatStage?(:SPEED, target)
                  when :LIGHTNINGROD
                    target.pbCanRaiseStatStage?(:SPECIAL_ATTACK, target)
                  else
                    true
                  end
        show_message = false if !benefit
      end
      result = super( ability, user, target, move, type, battle, show_message )

      # Preserve everything the handler did, remove only its immunity result.
      return false if bypass
      return result
    end
  end
  # Advanced AI: shared type calculation used by both damage paths.
  module AdvancedTypes
    def move_type_effectiveness(move, user, defender, effective_type = nil)
      value = super
      type = effective_type || resolve_move_type(user, move)
      return value if !KaitoOvercharge.applies?(user, move, type)
      target = KaitoOvercharge.real(defender)
      types = target.respond_to?(:pbTypes) ? target.pbTypes(true) : target.types
      return value if !types.include?(:ELECTRIC)
      original = Effectiveness.calculate(:ELECTRIC, :ELECTRIC)
      replacement = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER

      # Modify only the Electric component. Ground immunity remains zero.
      return value * replacement / original
    end
  end

  module AdvancedAbsorption
    def type_absorbing_immunity?(user, target, move_type, move = nil)
      result = super
      return result if !result
      return result if !KaitoOvercharge.applies?(user, move, move_type)
      return result if !KaitoOvercharge.absorber?(result[:ability])
      return nil
    end
  end
  # Install after all plugin aliases and handler registrations have loaded.
  def self.install!
    @type_patches ||= []
    ObjectSpace.each_object(Class) do |klass|
      next if !(klass <= Battle::Move)
      next if @type_patches.include?(klass)
      next if !klass.instance_methods(false).include?(:pbCalcTypeModSingle)
      klass.prepend(MoveType)
      @type_patches.push(klass)
    end
    singleton = Battle::AbilityEffects::MoveImmunity.singleton_class
    unless singleton.ancestors.include?(ImmunityHandler)
      singleton.prepend(ImmunityHandler)
    end
    if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:move_type_effectiveness)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(AdvancedTypes)
        singleton.prepend(AdvancedTypes)
      end
    end
    if defined?(AdvancedAI::Utilities) && AdvancedAI::Utilities.respond_to?(:type_absorbing_immunity?)
      singleton = AdvancedAI::Utilities.singleton_class
      unless singleton.ancestors.include?(AdvancedAbsorption)
        singleton.prepend(AdvancedAbsorption)
      end
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoOvercharge.install!
      super(*args, &block)
    end
  end
end
unless Battle.singleton_class.ancestors.include?( KaitoOvercharge::ConstructionHook )
  Battle.singleton_class.prepend(KaitoOvercharge::ConstructionHook)
end

# Plus / Minus - Complete party-based rework
# Plus:  +10% Electric power per party Pokemon with Minus; 15% Burn.
# Minus: +10% Electric power per party Pokemon with Plus; 15% Frostbite.
module KaitoPlusMinusParty
  COUNT_FAINTED = true

  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.has?(object, ability)
    object = real(object)
    return false if !object
    if object.respond_to?(:hasActiveAbility?)
      return object.hasActiveAbility?(ability)
    end
    abilities = []
    abilities.concat(Array(object.ability_id)) if object.respond_to?(:ability_id)
    if object.respond_to?(:set_innate_limits)
      abilities.concat(Array(object.set_innate_limits))
    end
    return abilities.flatten.include?(ability)
  end

  def self.party_member?(pokemon, wanted)
    return false if !pokemon || pokemon.egg?
    return false if !COUNT_FAINTED && pokemon.fainted?
    abilities = Array(pokemon.ability_id)
    if pokemon.respond_to?(:set_innate_limits)
      abilities.concat(Array(pokemon.set_innate_limits))
    end
    return abilities.flatten.include?(wanted)
  end

  def self.battle_of(object)
    object = real(object)
    return object ? object.instance_variable_get(:@battle) : nil
  end

  # Return the party side and trainer owner.
  # Supports both active battlers and reserve Pokemon in AI predictions.
  def self.owner_context(battle, object)
    user = real(object)
    return nil if !battle || !user
    if user.is_a?(Battle::Battler)
      return [ user.index, battle.pbGetOwnerIndexFromBattlerIndex(user.index) ]
    end
    [0, 1].each do |side|
      index = battle.pbParty(side).index { |p| p.equal?(user) }
      next if index.nil?
      return [ side, battle.pbGetOwnerIndexFromPartyIndex(side, index) ]
    end
    return nil
  end

  def self.count(battle, object, wanted)
    context = owner_context(battle, object)
    return 0 if !context
    side, owner = context
    total = 0
    battle.pbParty(side).each_with_index do |pokemon, index|
      next if battle.pbGetOwnerIndexFromPartyIndex(side, index) != owner
      total += 1 if party_member?(pokemon, wanted)
    end
    return total
  end

  def self.factor(object, type, battle = nil)
    return 1.0 if type != :ELECTRIC
    battle ||= battle_of(object)
    return 1.0 if !battle
    counts = []
    if has?(object, :PLUS)
      counts.push(count(battle, object, :MINUS))
    end
    if has?(object, :MINUS)
      counts.push(count(battle, object, :PLUS))
    end
    return 1.0 if counts.empty?
    return 1.0 + counts.max * 0.10
  end
  # Retained secondary effects.
  def self.inflict(ability, user, target, move, battle)
    return if !user || !target || !move
    return if user.fainted? || target.fainted?
    return if !move.damagingMove? || move.calcType != :ELECTRIC
    return if target.damageState.substitute
    return if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
    can_inflict = if ability == :PLUS
                    target.pbCanBurn?(user, false)
                  else
                    target.pbCanFrostbite?(user, false)
                  end
    return if !can_inflict
    return if battle.pbRandom(100) >= 20
    battle.pbShowAbilitySplash(user)
    begin
      if ability == :PLUS
        target.pbBurn(user)
      else
        target.pbFrostbite(user)
      end
    ensure
      battle.pbHideAbilitySplash(user)
    end
  end
  # Advanced AI: shared damage estimator.
  module CombatAI
    def ability_damage_modifier( user, target, type, physical, effectiveness, move = nil, physical_defense = physical )
      value = super
      battle = KaitoPlusMinusParty.battle_of(user) || KaitoPlusMinusParty.battle_of(target) || KaitoPlusMinusParty.battle_of(move)
      return value * KaitoPlusMinusParty.factor(user, type, battle)
    end
  end
  # Advanced AI: separate damage calculator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      native = move.respond_to?(:move) ? move.move : move
      return value if native.is_a?(Battle::Move::FixedDamageMove)
      code = move.function_code.to_s
      return value if code.start_with?("FixedDamage", "OHKO", "Counter")
      return value if [ "LowerTargetHPToUserHP", "UserFaintsFixedDamageUserHP", "MultiTurnAttackBideThenReturnDoubleDamage" ].include?(code)

      # Avoid a second multiplier when terrain delegates to the shared estimator.
      if @battle.field.terrain == :Pollination && defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?( ExtendedTerrains::AdvancedScorerHooks ) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end
      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end
      factor = KaitoPlusMinusParty.factor(user, type, @battle)
      return value if factor == 1.0
      return [(value * factor).round, 1].max
    end
  end

  def self.install_ai!
    if defined?(AdvancedAI::CombatUtilities) && AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      unless singleton.ancestors.include?(CombatAI)
        singleton.prepend(CombatAI)
      end
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:calculate_rough_damage) && !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  # Delay installation until plugin loading has finished.
  module ConstructionHook
    def new(*args, &block)
      KaitoPlusMinusParty.install_ai!
      super(*args, &block)
    end
  end
end

# Replace the original Sp. Atk bonus.
Battle::AbilityEffects::DamageCalcFromUser.add(:PLUS, proc { |ability, user, target, move, mults, power, type|
  mults[:power_multiplier] *= KaitoPlusMinusParty.factor(user, type)
})

Battle::AbilityEffects::DamageCalcFromUser.add(:MINUS, proc { |ability, user, target, move, mults, power, type|
  # If both abilities are active, PLUS supplies the shared bonus once.
  next if user.hasActiveAbility?(:PLUS)
  mults[:power_multiplier] *= KaitoPlusMinusParty.factor(user, type)
})

# Replace the original status handlers, preserving their 15% effects.
Battle::AbilityEffects::OnDealingHit.add(:PLUS, proc { |ability, user, target, move, battle| KaitoPlusMinusParty.inflict(:PLUS, user, target, move, battle) }
)

Battle::AbilityEffects::OnDealingHit.add(:MINUS, proc { |ability, user, target, move, battle| KaitoPlusMinusParty.inflict(:MINUS, user, target, move, battle) }
)
unless Battle.singleton_class.ancestors.include?( KaitoPlusMinusParty::ConstructionHook )
  Battle.singleton_class.prepend( KaitoPlusMinusParty::ConstructionHook )
end

# Excavator
# After dealing damage with a Ground move:
# raises Defense by 1 stage and clears the user's side's entry hazards.
module KaitoExcavator
  SIDE_HAZARDS = {
    :StealthRock     => false,
    :Spikes          => 0,
    :ToxicSpikes     => 0,
    :StickyWeb       => false,
    :Steelsurge      => false,
    :TerrainSmash    => false,
    :RestictiveWinds => false,
    :HauntedOrbs     => false,
    :SharpSteel      => false,
    :CopperJacks     => false,
    :BurningDebris   => false,
    :WaterChannel    => false,
    :RoseField       => false,
    :ProtonOverload  => false,
    :MindField       => false,
    :IceRing         => false,
    :DraconicRift    => false,
    :DarkMist        => false,
    :ManaFlux        => false,
    :Miasma          => false
  }.freeze

  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.side_hazards(user)
    effects = user.pbOwnSide.effects
    result = []
    SIDE_HAZARDS.each do |name, empty|
      next if !PBEffects.const_defined?(name)
      key = PBEffects.const_get(name)
      value = effects[key]
      active = if empty == false
                 value == true
               else
                 value.is_a?(Numeric) && value > 0
               end
      result.push([key, empty]) if active
    end
    return result
  end

  def self.hazard_count(user, battle); return side_hazards(user).length; end

  def self.clear_hazards(user, battle)
    hazards = side_hazards(user)
    hazards.each do |key, empty|
      user.pbOwnSide.effects[key] = empty
    end
    return !hazards.empty?
  end
  # AI: value Defense gain and clearing existing hazards.
  def self.ai_bonus(object, move, battle, type, damage)
    user = real(object)
    return 0 if !user || user.fainted? || !move
    return 0 if !user.respond_to?(:hasActiveAbility?)
    return 0 if !user.hasActiveAbility?(:EXCAVATOR)
    return 0 if type != :GROUND || !damage || damage <= 0
    score = 0
    if user.pbCanRaiseStatStage?(:DEFENSE, user)
      if user.hasActiveAbility?(:CONTRARY)
        score -= 12
      else
        score += 10
        if user.hasActiveAbility?(:SIMPLE) && user.stages[:DEFENSE] <= 4
          score += 4
        end
      end
    end
    hazards = hazard_count(user, battle)
    score += [15 + hazards * 5, 40].min if hazards > 0
    return score
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      @kaito_excavator_ai_depth = @kaito_excavator_ai_depth.to_i + 1
      begin
        score = super
        return score if score <= -100 || !move || !user || !target
        return score if !move.damagingMove?
        return score if !KaitoExcavator.real(user).
          hasActiveAbility?(:EXCAVATOR)
        type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
        if move.id == :TERABLAST
          tera_type = get_tera_type_for_move(user)
          type = tera_type if tera_type
        end
        return score if type != :GROUND
        damage = calculate_rough_damage(move, user, target)
        return score + KaitoExcavator.ai_bonus( user, move, @battle, type, damage )
      ensure
        @kaito_excavator_ai_depth -= 1
      end
    end
  end

  def self.install_ai!
    return if !defined?(AdvancedAI)
    return if !Battle::AI.method_defined?(:score_move_advanced)
    return if Battle::AI.ancestors.include?(AdvancedScoring)
    Battle::AI.prepend(AdvancedScoring)
  end

  # Install after plugin aliases have finished loading.
  module ConstructionHook
    def new(*args, &block)
      KaitoExcavator.install_ai!
      super(*args, &block)
    end
  end
end

# Actual effect: existing end-of-move ability handler.
Battle::AbilityEffects::OnEndOfUsingMove.add(:EXCAVATOR, proc { |ability, user, targets, move, battle|
  next if !user || user.fainted? || !move
  next if !move.damagingMove? || move.calcType != :GROUND
  dealt_damage = targets.any? do |target|
    target && target.damageState.totalHPLost.to_i > 0
  end
  next if !dealt_damage
  can_raise = user.pbCanRaiseStatStage?(:DEFENSE, user)
  has_hazards = KaitoExcavator.hazard_count(user, battle) > 0
  next if !can_raise && !has_hazards
  battle.pbShowAbilitySplash(user, true)
  begin
    # Clear independently of whether Defense can change.
    if KaitoExcavator.clear_hazards(user, battle)
      battle.pbDisplay(_INTL( "{1} cleared away all entry hazards on its side!", user.pbThis ))
    end
    if can_raise
      user.pbRaiseStatStageByAbility(:DEFENSE, 1, user, false)
    end
  ensure
    battle.pbHideAbilitySplash(user)
  end
})
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(
  :kaito_excavator,
  proc { |score, move, user, target, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next score if ai.instance_variable_get( :@kaito_excavator_ai_depth ).to_i > 0
    battler = KaitoExcavator.real(user)
    next score if !battler.hasActiveAbility?(:EXCAVATOR)
    next score if !move.damagingMove?
    type = move.rough_type
    next score if type != :GROUND
    next score + KaitoExcavator.ai_bonus( user, move, battle, type, move.rough_damage )
  })
unless Battle.singleton_class.ancestors.include?( KaitoExcavator::ConstructionHook )
  Battle.singleton_class.prepend( KaitoExcavator::ConstructionHook )
end

# Burrow In
# Automatically uses Dig upon entering battle.
# Preserves its charging state and schedules the attacking turn correctly.
module KaitoBurrowIn
  ABILITY = :BURROWIN
  MOVE    = :DIG

  def self.real(object); object.respond_to?(:battler) ? object.battler : object; end

  def self.charging?(b)
    return false if !b || b.fainted?
    return b.effects[PBEffects::TwoTurnAttack] == MOVE && b.currentMove == MOVE
  end

  def self.trigger(b, battle)
    return if b.fainted?
    return if !b.hasActiveAbility?(ABILITY)
    return if b.instance_variable_get(:@kaito_burrow_used)
    return if b.usingMultiTurnAttack?
    foes = battle.allBattlers.select do |foe|
      !foe.fainted? && foe.opposes?(b) && foe.near?(b)
    end
    return if foes.empty?
    dig = Battle::Move.from_pokemon_move( battle, Pokemon::Move.new(MOVE) )
    return if !b.pbCanChooseMove?(dig, false, false, true)
    b.instance_variable_set(:@kaito_burrow_used, true)
    target = foes[battle.pbRandom(foes.length)]
    pokemon = b.pokemon
    old_round   = b.lastRoundMoved
    old_current = b.currentMove
    old_failed  = b.lastMoveFailed
    old_dancer  = b.effects[PBEffects::Dancer]
    old_outrage = b.effects[PBEffects::Outrage]
    old_lock    = b.effects[PBEffects::ChoiceBand]
    old_mold    = battle.moldBreaker
    begin
      battle.pbShowAbilitySplash(b, true)
      battle.pbHideAbilitySplash(b)
      b.effects[PBEffects::Dancer] = true
      if old_outrage > 0
        b.effects[PBEffects::Outrage] = old_outrage + 1
      end

      # Use the engine's real Dig, including animation and Power Herb.
      b.pbUseMoveSimple(MOVE, target.index)
    ensure
      battle.moldBreaker = old_mold
      if b.pokemon.equal?(pokemon)
        b.lastRoundMoved = old_round
        b.lastMoveFailed = old_failed
        b.effects[PBEffects::Dancer] = old_dancer
        b.effects[PBEffects::Outrage] = old_outrage
        b.effects[PBEffects::ChoiceBand] = old_lock
        if charging?(b)
          # Keep currentMove = DIG; restoring it would break the second turn.
          b.instance_variable_set( :@kaito_burrow_pending, [pokemon, target.index] )
        else
          b.currentMove = old_current
          b.instance_variable_set(:@kaito_burrow_pending, nil)
        end
      end
    end
  end

  # Register the attacking turn at the NEXT command phase.
  # Do not change the current switch action into an immediate extra attack.
  def self.prepare_commands(battle)
    battle.allBattlers.each do |b|
      pending = b.instance_variable_get(:@kaito_burrow_pending)
      next if !pending || !b.pokemon.equal?(pending[0])
      next if !charging?(b)
      dig = Battle::Move.from_pokemon_move( battle, Pokemon::Move.new(MOVE) )
      dig.pp = -1
      battle.choices[b.index] = [ :UseMove, -1, dig, pending[1], 0 ]
      b.instance_variable_set( :@kaito_burrow_action_round, battle.turnCount )
    end
  end

  module BattlerHook
    def pbInitEffects(batonPass)
      result = super
      @kaito_burrow_used = false
      @kaito_burrow_pending = nil
      @kaito_burrow_action_round = nil
      return result
    end
  end

  module CommandHook
    def pbCommandPhase(*args, &block)
      KaitoBurrowIn.prepare_commands(self)
      return super(*args, &block)
    end
  end
  # Advanced AI: estimate whether the target will still be underground
  # when the proposed move is executed.
  def self.priority(battler, move)
    probe = battler.dup
    probe.instance_variable_set(:@effects, battler.effects.dup)
    probe.instance_variable_set(:@stages, battler.stages.dup)
    old_name = $aamName
    begin
      value = move.pbPriority(probe)
      if probe.abilityActive?
        value = Battle::AbilityEffects.triggerPriorityChange( probe.ability, probe, move, value )
      end
      return value
    ensure
      $aamName = old_name
    end
  end

  def self.ai_penalty(user, target, move, battle)
    user = real(user)
    target = real(target)
    native = move.respond_to?(:move) ? move.move : move
    return 0 if !user || !target || !native
    return 0 if !target.is_a?(Battle::Battler)
    return 0 if !target.opposes?(user) || !charging?(target)
    pending = target.instance_variable_get(:@kaito_burrow_pending)
    return 0 if !pending || !target.pokemon.equal?(pending[0])
    return 0 if !native.respond_to?(:hitsDiggingTargets?)
    return 0 if native.hitsDiggingTargets?
    return 0 if native.targetsPosition?
    return 0 if native.pbTarget(user).num_targets <= 0
    return 0 if user.hasActiveAbility?(:NOGUARD) || target.hasActiveAbility?(:NOGUARD)

    # If the attacking turn has not been scheduled this round,
    # the target remains underground for the rest of this round.
    action_round = target.instance_variable_get( :@kaito_burrow_action_round )
    return -120 if action_round != battle.turnCount
    return 0 if target.movedThisRound?
    dig = Battle::Move.from_pokemon_move( battle, Pokemon::Move.new(MOVE) )
    user_priority = priority(user, native)
    dig_priority = priority(target, dig)

    # Attacker moves before Dig resolves: target is still underground.
    return -120 if user_priority > dig_priority
    return 0 if user_priority < dig_priority
    user_speed = user.pbSpeed
    target_speed = target.pbSpeed
    return -60 if user_speed == target_speed
    trick_room = battle.field.effects[PBEffects::TrickRoom] > 0
    moves_first = trick_room ? user_speed < target_speed : user_speed > target_speed
    return moves_first ? -120 : 0
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= -100 || !move || !user || !target
      return score + KaitoBurrowIn.ai_penalty( user, target, move, @battle )
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    unless Battle::Battler.ancestors.include?(BattlerHook)
      Battle::Battler.prepend(BattlerHook)
    end
    unless Battle.ancestors.include?(CommandHook)
      Battle.prepend(CommandHook)
    end
    if defined?(AdvancedAI) && Battle::AI.method_defined?(:score_move_advanced) && !Battle::AI.ancestors.include?(AdvancedScoring)
      Battle::AI.prepend(AdvancedScoring)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoBurrowIn.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::OnSwitchIn.add(:BURROWIN, proc { |ability, battler, battle, switch_in|
  next if !switch_in
  KaitoBurrowIn.trigger(battler, battle)
})
KaitoAbilitySupport.rate(:BURROWIN, 6)
unless Battle.singleton_class.ancestors.include?( KaitoBurrowIn::ConstructionHook )
  Battle.singleton_class.prepend( KaitoBurrowIn::ConstructionHook )
end

# --- Battle_Move.rb ---
# Pyromancy
# Increases the chance of burning from attack additional effects by 5 times.
class Battle::Move
  alias pyromancy_pbAdditionalEffectChance pbAdditionalEffectChance
  def pbAdditionalEffectChance(user, target, effectChance = 0)
    ret = pyromancy_pbAdditionalEffectChance(user, target, effectChance)
    if user.hasActiveAbility?(:PYROMANCY) &&
       damagingMove? &&
       function_code.include?("Burn") &&
       ret > 0
      ret *= 3
      ret = 100 if ret > 100
    end
    return ret
  end
end

# Precise Fist
# Punching moves gain +1 critical hit chance and double secondary effects.
# Đánh dấu move hiện tại có phải punching move không.
Battle::AbilityEffects::AccuracyCalcFromUser.add(:PRECISEFIST, proc { |ability, mods, user, target, move, type|
    user.instance_variable_set(:@precise_fist_punching_move, move && move.punchingMove?)
  })

# Nếu move hiện tại là punching move thì +1 crit stage.
Battle::AbilityEffects::CriticalCalcFromUser.add(:PRECISEFIST, proc { |ability, user, target, crit_stage|
    if user.instance_variable_get(:@precise_fist_punching_move)
      next crit_stage + 1
    end
    next crit_stage
  })

# Xóa dấu sau khi dùng move xong.
Battle::AbilityEffects::OnEndOfUsingMove.add(:PRECISEFIST, proc { |ability, user, targets, move, battle|
    user.instance_variable_set(:@precise_fist_punching_move, false)
  })

# Nhân đôi secondary effect chance của punching move.
class Battle::Move
  if method_defined?(:pbAdditionalEffectChance)
    alias precise_fist_pbAdditionalEffectChance pbAdditionalEffectChance
    def pbAdditionalEffectChance(user, target, effectChance = 0)
      ret = precise_fist_pbAdditionalEffectChance(user, target, effectChance)
      if user.hasActiveAbility?(:PRECISEFIST) && punchingMove? && ret > 0
        ret *= 2
        ret = 100 if ret > 100
      end
      return ret
    end
  end
end

# --- Sleet.rb ---
# Ability: Sleet
#
# Effect:
# During hail, this Pokémon damages opposing Pokémon by 1/8 max HP
# at the end of each turn.
#
# Thick Fat: takes half damage from Sleet.
# Magic Guard: immune to Sleet damage.
#
# Compatible safer handler for projects using M.A.G / AAM / Innate Abilities.
module SleetAbility
  HAIL_WEATHERS = [:Hail, :Snow].freeze
  def self.hail_active?(battle, weather = nil)
    return true if weather && HAIL_WEATHERS.include?(weather)
    return false if !battle
    return HAIL_WEATHERS.include?(battle.pbWeather)
  end
  def self.sleet_damage(target)
    damage = [target.totalhp / 8, 1].max
    if target.hasActiveAbility?(:THICKFAT)
      damage = [damage / 2, 1].max
    end
    return damage
  end
end

# Battle effect
Battle::AbilityEffects::EndOfRoundWeather.add(:SLEET, proc { |ability, *args|
    weather = nil
    battler = nil
    battle  = nil
    # Some plugins call:
    #   ability, weather, battler, battle
    #
    # Essentials-style handlers may call:
    #   ability, battler, battle
    #
    # This block safely supports both.
    if args.length >= 3 && args[0].is_a?(Symbol)
      weather = args[0]
      battler = args[1]
      battle  = args[2]
    else
      battler = args[0]
      battle  = args[1]
      weather = battle.pbWeather if battle
    end
    next if !battler
    next if !battle
    next if !battler.respond_to?(:fainted?)
    next if battler.fainted?
    next if !battler.hasActiveAbility?(:SLEET)
    next if !SleetAbility.hail_active?(battle, weather)
    showed_splash = false
    battle.allOtherSideBattlers(battler.index).each do |target|
      next if !target
      next if target.fainted?
      if !showed_splash
        battle.pbShowAbilitySplash(battler)
        showed_splash = true
      end
      # Magic Guard completely blocks Sleet damage.
      if target.hasActiveAbility?(:MAGICGUARD)
        battle.pbDisplay(_INTL("{1} was protected from {2}'s Sleet by Magic Guard!", target.pbThis, battler.pbThis(true)))
        next
      end
      damage = SleetAbility.sleet_damage(target)
      if target.hasActiveAbility?(:THICKFAT)
        battle.pbDisplay(_INTL("{1}'s Thick Fat weakened {2}'s Sleet!", target.pbThis, battler.pbThis(true)))
      end
      battle.pbDisplay(_INTL("{1}'s Sleet battered {2}!", battler.pbThis, target.pbThis(true)))
      target.pbTakeEffectDamage(damage)
      break if battle.decision > 0
    end
    battle.pbHideAbilitySplash(battler) if showed_splash
  })

# Sleet AI Support
#
# Ability:
# Sleet - During hail/snow, damages opposing Pokémon at the end of each turn.
module SleetAI
  HAIL_WEATHERS = [:Hail, :Snow].freeze
  def self.hail_active?(battle)
    return false if !battle
    return HAIL_WEATHERS.include?(battle.pbWeather)
  end
  def self.battler_has_sleet?(battler)
    return false if !battler
    return false if !battler.respond_to?(:hasActiveAbility?)
    return battler.hasActiveAbility?(:SLEET)
  end
  def self.ai_battler_has_sleet?(battler)
    return false if !battler
    if battler.respond_to?(:has_active_ability?)
      return battler.has_active_ability?(:SLEET)
    end
    if battler.respond_to?(:hasActiveAbility?)
      return battler.hasActiveAbility?(:SLEET)
    end
    return false
  end
  def self.has_sleet_on_same_side?(ai, user)
    return false if !ai
    return false if !user
    found = false
    if ai.respond_to?(:each_same_side_battler)
      ai.each_same_side_battler(user.side) do |b, i|
        next if !b
        if self.ai_battler_has_sleet?(b)
          found = true
          break
        end
      end
    end
    return found
  end
  def self.count_foes_alive(ai, user)
    return 0 if !ai
    return 0 if !user
    count = 0
    if ai.respond_to?(:each_foe_battler)
      ai.each_foe_battler(user.side) do |b, i|
        next if !b
        if b.respond_to?(:can_attack?)
          count += 1 if b.can_attack?
        elsif b.respond_to?(:fainted?)
          count += 1 if !b.fainted?
        else
          count += 1
        end
      end
    end
    return count
  end
end

# AI: Use Hail/Snow better if same side has Sleet
if defined?(Battle::AI::Handlers) &&
   defined?(Battle::AI::Handlers::MoveEffectScore)
  # Essentials thường dùng function code này cho move Hail.
  Battle::AI::Handlers::MoveEffectScore.add("StartHailWeather", proc { |score, move, user, ai, battle|
      next score if !battle
      next Battle::AI::MOVE_USELESS_SCORE if SleetAI.hail_active?(battle)
      if SleetAI.has_sleet_on_same_side?(ai, user)
        score += 20
        foe_count = SleetAI.count_foes_alive(ai, user)
        score += foe_count * 5
      end
      next score
    })
  # Một số plugin Gen 9 / M.A.G có thể dùng Snow hoặc Snowscape.
  # Nếu function code này không tồn tại trong project thì cũng không sao,
  # handler chỉ nằm chờ, không gây lỗi cú pháp.
  Battle::AI::Handlers::MoveEffectScore.add("StartSnowWeather", proc { |score, move, user, ai, battle|
      next score if !battle
      next Battle::AI::MOVE_USELESS_SCORE if SleetAI.hail_active?(battle)
      if SleetAI.has_sleet_on_same_side?(ai, user)
        score += 20
        foe_count = SleetAI.count_foes_alive(ai, user)
        score += foe_count * 5
      end
      next score
    })
end

# Optional AI: Ability ranking for Sleet
# Only runs if your AI plugin supports AbilityRanking.
if defined?(Battle::AI::Handlers) &&
   defined?(Battle::AI::Handlers::AbilityRanking)
  Battle::AI::Handlers::AbilityRanking.add(:SLEET, proc { |ability, score, battler, ai|
      # Giá trị cơ bản: Sleet là ability gây chip damage nên có ích.
      score += 3
      # Nếu đang có Hail/Snow, Sleet mạnh hơn nhiều.
      if ai && ai.respond_to?(:battle) && ai.battle
        score += 7 if SleetAI.hail_active?(ai.battle)
      end
      # Nếu Pokémon có move tạo Hail/Snow, tăng giá trị.
      if battler && battler.respond_to?(:moves)
        battler.moves.each do |m|
          next if !m
          next if !m.respond_to?(:id)
          if [:HAIL, :SNOWSCAPE].include?(m.id)
            score += 5
            break
          end
        end
      end
      next score
    })
end

#===============================================================================
# FLOODING
# Swamp Terrain: Special Attack x1.5; loses 1/16 maximum HP each turn.
#===============================================================================
module KaitoFlooding
  ABILITY = :FLOODING
  TERRAIN = :Swamp

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.battle_of(object)
    object = real(object)
    object ? object.instance_variable_get(:@battle) : nil
  end

  def self.has?(object)
    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ABILITY)
    end

    return true if user.respond_to?(:ability_id) &&
                   user.ability_id == ABILITY

    return user.respond_to?(:set_innate_limits) &&
           Array(user.set_innate_limits).include?(ABILITY)
  end

  def self.active?(object, battle = nil)
    return false if !has?(object)

    battle ||= battle_of(object)
    return battle && battle.field.terrain == TERRAIN
  end

  def self.move_data(move)
    return nil if !move || !move.respond_to?(:id)
    GameData::Move.try_get(move.id)
  end

  def self.fixed?(move)
    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)

    info = move_data(move)
    return false if !info

    code = info.function_code.to_s
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")

    return [
      "LowerTargetHPToUserHP",
      "UserFaintsFixedDamageUserHP",
      "MultiTurnAttackBideThenReturnDoubleDamage"
    ].include?(code)
  end

  def self.factor(user, physical, move, battle = nil)
    return 1.0 if physical || !active?(user, battle)

    info = move_data(move)
    if info
      return 1.0 if info.category == 2 || fixed?(move)
      return 1.0 if [
        "UseTargetAttackInsteadOfUserAttack",
        "UseUserDefenseInsteadOfUserAttack"
      ].include?(info.function_code)
    end

    # Kinetic uses Speed instead of the user's offensive stat.
    if defined?(KaitoKinetic) && KaitoKinetic.active?(user)
      return 1.0
    end

    return 1.5
  end

  def self.staged(object, stat)
    user = real(object)
    value = stat == :ATTACK ? user.attack : user.spatk
    stage = user.respond_to?(:stages) ? user.stages[stat].to_i : 0
    stage = [[stage, -6].max, 6].min
    factor = stage >= 0 ? (2.0 + stage) / 2 : 2.0 / (2 - stage)

    return [(value * factor).floor, 1].max
  end

  def self.physical?(user, move, tera = false)
    info = move_data(move)
    return false if !info

    dynamic = [:PHOTONGEYSER, :LIGHTTHATBURNSTHESKY].include?(info.id)
    source = real(user)
    dynamic ||= info.id == :TERABLAST &&
      (tera || (source.respond_to?(:tera?) && source.tera?))

    if dynamic
      return staged(user, :ATTACK) > staged(user, :SPECIAL_ATTACK)
    end

    return info.category == 0
  end

  def self.cost(object)
    user = real(object)
    return 0 if !active?(user)
    return 0 if !user.respond_to?(:takesIndirectDamage?)
    return 0 if !user.takesIndirectDamage?

    return [user.totalhp / 16, 1].max
  end

  def self.predicted_cost(object)
    amount = cost(object)
    return 0 if amount <= 0

    battle = battle_of(object)

    # Terrain expires before EndOfRoundEffect handlers run.
    if battle && battle.field.terrainDuration == 1 &&
       battle.field.defaultTerrain != TERRAIN
      return 0
    end

    return amount
  end

  #---------------------------------------------------------------------------
  # Advanced AI: shared damage estimator.
  #---------------------------------------------------------------------------
  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      battle = KaitoFlooding.battle_of(user) ||
               KaitoFlooding.battle_of(target) ||
               KaitoFlooding.battle_of(move)

      return value * KaitoFlooding.factor(
        user, physical, move, battle
      )
    end
  end

  #---------------------------------------------------------------------------
  # Advanced AI: separate move damage estimator.
  #---------------------------------------------------------------------------
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      return value if KaitoFlooding.fixed?(move)

      tera = move.id == :TERABLAST && !!get_tera_type_for_move(user)
      physical = KaitoFlooding.physical?(user, move, tera)
      factor = KaitoFlooding.factor(user, physical, move, @battle)

      return value if factor == 1.0
      return [(value * factor).round, 1].max
    end

    # A small penalty for spending a turn when HP loss is dangerous.
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= -100 || !move || !user

      amount = KaitoFlooding.predicted_cost(user)
      return score if amount <= 0 || !move.statusMove?

      native = move.respond_to?(:move) ? move.move : move
      return score if native.respond_to?(:healingMove?) &&
                      native.healingMove?

      hp = KaitoFlooding.real(user).hp
      return score - (amount >= hp ? 35 : 5)
    end
  end

  # Native AI gets the offensive bonus through DamageCalcFromUser.
  module NativeResidual
    def rough_end_of_round_damage
      return super + KaitoFlooding.predicted_cost(battler)
    end
  end

  # Install after plugin aliases have loaded.
  def self.install!
    unless Battle::AI::AIBattler.ancestors.include?(NativeResidual)
      Battle::AI::AIBattler.prepend(NativeResidual)
    end

    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoFlooding.install!
      super(*args, &block)
    end
  end
end

#===============================================================================
# Actual battle + native AI: Special Attack multiplier.
#===============================================================================
Battle::AbilityEffects::DamageCalcFromUser.add(:FLOODING,
  proc { |ability, user, target, move, mults, power, type|
    mults[:attack_multiplier] *= KaitoFlooding.factor(
      user, move.physicalMove?, move
    )
  }
)

#===============================================================================
# Actual battle: end-of-turn HP loss.
#===============================================================================
Battle::AbilityEffects::EndOfRoundEffect.add(:FLOODING,
  proc { |ability, battler, battle|
    amount = KaitoFlooding.cost(battler)
    next if amount <= 0

    battle.pbShowAbilitySplash(battler)
    begin
      battle.scene.pbDamageAnimation(battler)
      battler.pbReduceHP(amount, false)
      battle.pbDisplay(_INTL(
        "{1} was drained by its {2}!",
        battler.pbThis,
        GameData::Ability.get(:FLOODING).name
      ))
    ensure
      battle.pbHideAbilitySplash(battler)
    end

    battler.pbItemHPHealCheck
  }
)

unless Battle.singleton_class.ancestors.include?(
  KaitoFlooding::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoFlooding::ConstructionHook)
end

#===============================================================================
# SHORT CIRCUIT
# Electric attacks: x1.1 normally, x1.2 at half HP, x1.5 at one-third HP.
#===============================================================================
module KaitoShortCircuit
  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.has?(object)
    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(:SHORTCIRCUIT)
    end

    return true if user.respond_to?(:ability_id) &&
                   user.ability_id == :SHORTCIRCUIT

    return user.respond_to?(:set_innate_limits) &&
           Array(user.set_innate_limits).include?(:SHORTCIRCUIT)
  end

  def self.factor(object, type)
    return 1.0 if type != :ELECTRIC || !has?(object)

    user = real(object)
    return 1.5 if user.hp <= user.totalhp / 3
    return 1.2 if user.hp <= user.totalhp / 2
    return 1.1
  end

  def self.fixed?(move)
    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)

    info = GameData::Move.try_get(move.id)
    return false if !info

    code = info.function_code.to_s
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return [
      "LowerTargetHPToUserHP",
      "UserFaintsFixedDamageUserHP",
      "MultiTurnAttackBideThenReturnDoubleDamage"
    ].include?(code)
  end

  # Advanced AI: shared damage estimator, including reserve Pokemon.
  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      return value if move && KaitoShortCircuit.fixed?(move)

      return value * KaitoShortCircuit.factor(user, type)
    end
  end

  # Advanced AI: separate move damage estimator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      return value if KaitoShortCircuit.fixed?(move)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination &&
         defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?(ExtendedTerrains::AdvancedScorerHooks) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end

      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end

      factor = KaitoShortCircuit.factor(user, type)
      return value if factor == 1.0

      return [(value * factor).round, 1].max
    end
  end

  # Delay prepend until all plugin aliases have finished loading.
  def self.install!
    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoShortCircuit.install!
      super(*args, &block)
    end
  end
end

# Actual battle + native AI, matching the existing starter abilities.
Battle::AbilityEffects::DamageCalcFromUser.add(:SHORTCIRCUIT,
  proc { |ability, user, target, move, mults, power, type|
    mults[:attack_multiplier] *= KaitoShortCircuit.factor(user, type)
  }
)

# Native AI ability valuation.
Battle::AI::BASE_ABILITY_RATINGS[5] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[5].include?(:SHORTCIRCUIT)
  Battle::AI::BASE_ABILITY_RATINGS[5] << :SHORTCIRCUIT
end

Battle::AI::Handlers::AbilityRanking.add(:SHORTCIRCUIT,
  proc { |ability, score, battler, ai|
    next battler.has_damaging_move_of_type?(:ELECTRIC) ? score : 0
  }
)

unless Battle.singleton_class.ancestors.include?(
  KaitoShortCircuit::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoShortCircuit::ConstructionHook)
end

#===============================================================================
# PARTING QUILLS
# Adds one layer of opposing Spikes when switching out alive.
#===============================================================================
module KaitoPartingQuills
  ABILITY = :PARTINGQUILLS

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.ready?(object)
    user = real(object)
    return false if !user || user.fainted?
    return false if !user.respond_to?(:hasActiveAbility?)
    return false if !user.hasActiveAbility?(ABILITY)
    return user.pbOpposingSide.effects[PBEffects::Spikes] < 3
  end

  def self.trigger(user, end_of_battle)
    return if end_of_battle || !ready?(user)
    return if user.instance_variable_get(:@kaito_parting_quills_used)

    battle = user.instance_variable_get(:@battle)
    return if !battle || battle.decision != 0

    # Prevent duplicate activation if the same ability appears in innates too.
    user.instance_variable_set(:@kaito_parting_quills_used, true)

    battle.pbShowAbilitySplash(user)
    begin
      user.pbOpposingSide.effects[PBEffects::Spikes] += 1
      battle.pbAnimation(:SPIKES, user, user.pbDirectOpposing)
      battle.pbDisplay(_INTL(
        "Spikes were scattered on the ground all around {1}!",
        user.pbOpposingTeam(true)
      ))
    ensure
      battle.pbHideAbilitySplash(user)
    end
  end

  # AI: extra value for switching moves while another layer can be placed.
  def self.pivot_bonus(object, move, battle)
    user = real(object)
    return 0 if !ready?(user) || !move
    return 0 if !battle.pbCanChooseNonActive?(user.index)

    info = GameData::Move.try_get(move.id)
    return 0 if !info
    return 0 if !info.function_code.to_s.include?("SwitchOutUser")

    # Spikes has no immediate strategic value if no opposing reserves remain.
    reserves = battle.pbParty(user.index ^ 1).any? do |pkmn|
      next false if !pkmn || pkmn.egg? || pkmn.fainted?
      !battle.allBattlers.any? { |b| b.pokemon.equal?(pkmn) }
    end
    return 0 if !reserves

    layers = user.pbOpposingSide.effects[PBEffects::Spikes]
    return [12, 8, 10][layers] || 0
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      @kaito_parting_quills_depth = @kaito_parting_quills_depth.to_i + 1
      begin
        score = super
        return score if score <= -100
        return score if @kaito_parting_quills_depth > 1

        return score + KaitoPartingQuills.pivot_bonus(user, move, @battle)
      ensure
        @kaito_parting_quills_depth -= 1
      end
    end
  end

  def self.install!
    return if !defined?(AdvancedAI)
    return if !Battle::AI.method_defined?(:score_move_advanced)
    return if Battle::AI.ancestors.include?(AdvancedScoring)

    Battle::AI.prepend(AdvancedScoring)
  end

  # Install after all plugin aliases have loaded.
  module ConstructionHook
    def new(*args, &block)
      KaitoPartingQuills.install!
      super(*args, &block)
    end
  end
end

# Reset on entry without displaying an ability splash.
Battle::AbilityEffects::OnSwitchIn.add(:PARTINGQUILLS,
  proc { |ability, battler, battle, switch_in|
    battler.instance_variable_set(:@kaito_parting_quills_used, false)
  }
)

Battle::AbilityEffects::OnSwitchOut.add(:PARTINGQUILLS,
  proc { |ability, battler, end_of_battle|
    KaitoPartingQuills.trigger(battler, end_of_battle)
  }
)

# Native AI: switching-move bonus.
Battle::AI::Handlers::GeneralMoveScore.add(:kaito_parting_quills,
  proc { |score, move, user, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next score if ai.instance_variable_get(:@kaito_parting_quills_depth).to_i > 0

    next score + KaitoPartingQuills.pivot_bonus(user, move, battle)
  }
)

Battle::AI::BASE_ABILITY_RATINGS[6] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[6].include?(:PARTINGQUILLS)
  Battle::AI::BASE_ABILITY_RATINGS[6] << :PARTINGQUILLS
end

unless Battle.singleton_class.ancestors.include?(
  KaitoPartingQuills::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoPartingQuills::ConstructionHook)
end

#===============================================================================
# IGNITION CYCLE
# End of turn: Speed +2, loses 1/8 max HP.
# At +6 Speed: resets Speed stages and refunds this cycle's actual HP loss.
#===============================================================================
module KaitoIgnitionCycle
  ABILITY = :IGNITIONCYCLE

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.active?(object)
    user = real(object)
    return false if !user || user.fainted?
    return user.respond_to?(:hasActiveAbility?) &&
           user.hasActiveAbility?(ABILITY)
  end

  def self.debt(user)
    user.instance_variable_get(:@kaito_ignition_hp).to_i
  end

  def self.cost(user)
    return 0 if !user.takesIndirectDamage?
    return [user.totalhp / 8, 1].max
  end

  def self.trigger(user, battle)
    return if !active?(user)
    return if user.instance_variable_get(:@kaito_ignition_round) ==
              battle.turnCount

    user.instance_variable_set(:@kaito_ignition_round, battle.turnCount)

    battle.pbShowAbilitySplash(user)
    begin
      if user.pbCanRaiseStatStage?(:SPEED, user)
        user.pbRaiseStatStageByAbility(:SPEED, 2, user, false)
      end

      amount = cost(user)
      if amount > 0
        battle.scene.pbDamageAnimation(user)
        lost = user.pbReduceHP(amount, false)
        user.instance_variable_set(:@kaito_ignition_hp, debt(user) + lost)

        battle.pbDisplay(_INTL(
          "{1} lost HP from its {2}!",
          user.pbThis, GameData::Ability.get(ABILITY).name
        ))
      end

      # HP loss can cause fainting; this ability does not revive the user.
      if !user.fainted? && user.stages[:SPEED] >= 6
        refund = debt(user)
        user.stages[:SPEED] = 0
        user.instance_variable_set(:@kaito_ignition_hp, 0)

        battle.pbDisplay(_INTL(
          "{1}'s Speed returned to normal!", user.pbThis
        ))

        if refund > 0 && user.canHeal?
          recovered = user.pbRecoverHP(refund)
          if recovered > 0
            battle.pbDisplay(_INTL(
              "{1} recovered the HP spent during its ignition cycle!",
              user.pbThis
            ))
          end
        end
      end
    ensure
      battle.pbHideAbilitySplash(user)
    end

    user.pbItemHPHealCheck
    user.pbAbilitiesOnDamageTaken if amount > 0 && !user.fainted?
    user.pbFaint if user.fainted?
  end

  #---------------------------------------------------------------------------
  # AI prediction: expected net HP loss at the end of this turn.
  #---------------------------------------------------------------------------
  def self.predicted_loss(object)
    user = real(object)
    return 0 if !active?(user)

    amount = [cost(user), user.hp].min
    return amount if amount >= user.hp

    stage = user.stages[:SPEED]
    if user.pbCanRaiseStatStage?(:SPEED, user)
      gain = user.hasActiveAbility?(:SIMPLE) ? 4 : 2
      gain *= -1 if user.hasActiveAbility?(:CONTRARY)
      stage = [[stage + gain, -6].max, 6].min
    end
    return amount if stage < 6

    # Account for the game's healing restrictions.
    return amount if user.effects[PBEffects::HealBlock] > 0
    return amount if user.respond_to?(:pbBleeding?) && user.pbBleeding?

    missing_after_cost = user.totalhp - user.hp + amount
    refund = [debt(user) + amount, missing_after_cost].min
    return amount - refund
  end

  module NativeResidual
    def rough_end_of_round_damage
      return super + KaitoIgnitionCycle.predicted_loss(battler)
    end
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      score = super
      return score if score <= -100 || !move || !user
      return score if !KaitoIgnitionCycle.active?(user)

      loss = KaitoIgnitionCycle.predicted_loss(user)
      source = KaitoIgnitionCycle.real(user)
      native = move.respond_to?(:move) ? move.move : move

      # Avoid passive turns when the HP cost would be fatal.
      if loss >= source.hp && move.statusMove?
        healing = native.respond_to?(:healingMove?) && native.healingMove?
        score -= 35 if !healing
      end

      return score
    end
  end

  # Reset on initialization, including switches and fainting.
  module BattlerHook
    def pbInitEffects(batonPass)
      result = super
      @kaito_ignition_hp = 0
      @kaito_ignition_round = nil
      return result
    end
  end

  # Delay installation until all plugin aliases have loaded.
  def self.install!
    unless Battle::Battler.ancestors.include?(BattlerHook)
      Battle::Battler.prepend(BattlerHook)
    end

    unless Battle::AI::AIBattler.ancestors.include?(NativeResidual)
      Battle::AI::AIBattler.prepend(NativeResidual)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:score_move_advanced) &&
       !Battle::AI.ancestors.include?(AdvancedScoring)
      Battle::AI.prepend(AdvancedScoring)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoIgnitionCycle.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::EndOfRoundEffect.add(:IGNITIONCYCLE,
  proc { |ability, battler, battle|
    KaitoIgnitionCycle.trigger(battler, battle)
  }
)

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[8].include?(:IGNITIONCYCLE)
  Battle::AI::BASE_ABILITY_RATINGS[8] << :IGNITIONCYCLE
end

unless Battle.singleton_class.ancestors.include?(
  KaitoIgnitionCycle::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoIgnitionCycle::ConstructionHook)
end

#===============================================================================
# HEAT VEIL
# Doubles Special Defense in Sun/Harsh Sun.
#===============================================================================
module KaitoHeatVeil
  ABILITY = :HEATVEIL

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.battle_of(object)
    object = real(object)
    object ? object.instance_variable_get(:@battle) : nil
  end

  def self.active?(object, battle = nil)
    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return false if !user.hasActiveAbility?(ABILITY)
    else
      ordinary = user.respond_to?(:ability_id) && user.ability_id == ABILITY
      innate = user.respond_to?(:set_innate_limits) &&
               Array(user.set_innate_limits).include?(ABILITY)
      return false if !ordinary && !innate
    end

    battle ||= battle_of(user)
    weather = user.respond_to?(:effectiveWeather) ?
                user.effectiveWeather : (battle && battle.pbWeather)

    return [:Sun, :HarshSun].include?(weather)
  end

  def self.fixed?(move)
    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)

    info = GameData::Move.try_get(move.id)
    return false if !info

    code = info.function_code.to_s
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return [
      "LowerTargetHPToUserHP",
      "UserFaintsFixedDamageUserHP",
      "MultiTurnAttackBideThenReturnDoubleDamage"
    ].include?(code)
  end

  def self.ai_factor(user, target, move, physical_defense, battle = nil)
    return 1.0 if physical_defense || !active?(target, battle)
    return 1.0 if move && fixed?(move)
    return 1.0 if AdvancedAI::Utilities.ignores_ability?(user, move, target)

    return 0.5
  end

  def self.staged(object, stat)
    user = real(object)
    value = stat == :ATTACK ? user.attack : user.spatk
    stage = user.respond_to?(:stages) ? user.stages[stat].to_i : 0
    stage = [[stage, -6].max, 6].min
    factor = stage >= 0 ? (2.0 + stage) / 2 : 2.0 / (2 - stage)

    return [(value * factor).floor, 1].max
  end

  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      battle = KaitoHeatVeil.battle_of(target) ||
               KaitoHeatVeil.battle_of(user)

      return value * KaitoHeatVeil.ai_factor(
        user, target, move, physical_defense, battle
      )
    end
  end

  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      value = super
      return value if !move || !user || !target
      return value if !value || value <= 0 || !move.damagingMove?
      return value if KaitoHeatVeil.fixed?(move)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination &&
         defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?(ExtendedTerrains::AdvancedScorerHooks) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return value
      end

      info = GameData::Move.try_get(move.id)
      return value if !info

      physical = info.category == 0
      dynamic = [:PHOTONGEYSER, :LIGHTTHATBURNSTHESKY].include?(move.id)
      dynamic ||= move.id == :TERABLAST && !!get_tera_type_for_move(user)

      if dynamic
        physical = KaitoHeatVeil.staged(user, :ATTACK) >
                   KaitoHeatVeil.staged(user, :SPECIAL_ATTACK)
      end

      physical_defense = physical
      if info.function_code == "UseTargetDefenseInsteadOfTargetSpDef"
        physical_defense = true
      end

      if @battle.field.effects[PBEffects::WonderRoom] > 0
        physical_defense = !physical_defense
      end

      factor = KaitoHeatVeil.ai_factor(
        user, target, move, physical_defense, @battle
      )
      return value if factor == 1.0

      return [(value * factor).round, 1].max
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoHeatVeil.install!
      super(*args, &block)
    end
  end
end

# Actual battle + native AI.
Battle::AbilityEffects::DamageCalcFromTarget.add(:HEATVEIL,
  proc { |ability, user, target, move, mults, power, type|
    next if !KaitoHeatVeil.active?(target)
    next if !move.specialMove?
    next if move.function_code == "UseTargetDefenseInsteadOfTargetSpDef"

    mults[:defense_multiplier] *= 2.0
  }
)

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:HEATVEIL)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :HEATVEIL
end

unless Battle.singleton_class.ancestors.include?(
  KaitoHeatVeil::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoHeatVeil::ConstructionHook)
end

#===============================================================================
# EVEBOOST SYNC
# Each distinct Eeveelution in the owner's party grants entry stat boosts.
#===============================================================================
module KaitoEveboostSync
  ABILITY = :EVEBOOSTSYNC
  COUNT_FAINTED = true

  SPECIES_STATS = {
    :FLAREON  => :ATTACK,
    :VAPOREON => :SPECIAL_ATTACK,
    :JOLTEON  => :SPEED,
    :ESPEON   => :SPECIAL_ATTACK,
    :UMBREON  => :SPECIAL_DEFENSE,
    :LEAFEON  => :DEFENSE,
    :GLACEON  => :SPECIAL_ATTACK,
    :SYLVEON  => :SPECIAL_DEFENSE
  }.freeze

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.boosts(object, battle)
    user = real(object)
    result = Hash.new(0)
    return result if !user || !user.respond_to?(:index)

    owner = battle.pbGetOwnerIndexFromBattlerIndex(user.index)
    seen = {}

    battle.pbParty(user.index).each_with_index do |pkmn, i|
      next if !pkmn || pkmn.egg?
      next if !COUNT_FAINTED && pkmn.fainted?
      next if battle.pbGetOwnerIndexFromPartyIndex(user.index, i) != owner

      species = pkmn.species
      stat = SPECIES_STATS[species]
      next if !stat || seen[species]

      seen[species] = true
      result[stat] += 1
    end

    return result
  end

  def self.trigger(user, battle)
    return if user.fainted? || !user.hasActiveAbility?(ABILITY)
    return if user.instance_variable_get(:@kaito_eveboost_used)

    # One activation per entry, including ability/innate duplicates.
    user.instance_variable_set(:@kaito_eveboost_used, true)

    changes = boosts(user, battle).select do |stat, amount|
      amount > 0 && user.pbCanRaiseStatStage?(stat, user)
    end
    return if changes.empty?

    battle.pbShowAbilitySplash(user)
    begin
      show_anim = true
      changes.each do |stat, amount|
        changed = user.pbRaiseStatStage(stat, amount, user, show_anim)
        show_anim = false if changed
      end
    ensure
      battle.pbHideAbilitySplash(user)
    end
  end

  module BattlerHook
    def pbInitEffects(batonPass)
      result = super
      @kaito_eveboost_used = false
      return result
    end
  end

  # Install after plugin aliases have finished loading.
  def self.install!
    unless Battle::Battler.ancestors.include?(BattlerHook)
      Battle::Battler.prepend(BattlerHook)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoEveboostSync.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::OnSwitchIn.add(:EVEBOOSTSYNC,
  proc { |ability, battler, battle, switch_in|
    next if !switch_in
    KaitoEveboostSync.trigger(battler, battle)
  }
)

# Native AI: value the ability according to the owner's party.
Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[8].include?(:EVEBOOSTSYNC)
  Battle::AI::BASE_ABILITY_RATINGS[8] << :EVEBOOSTSYNC
end

Battle::AI::Handlers::AbilityRanking.add(:EVEBOOSTSYNC,
  proc { |ability, score, battler, ai|
    user = KaitoEveboostSync.real(battler)
    battle = user.instance_variable_get(:@battle)
    next score if !battle

    total = KaitoEveboostSync.boosts(user, battle).values.inject(0, :+)
    next 0 if total == 0
    next 0 if user.hasActiveAbility?(:CONTRARY)

    next [5 + total, 10].min
  }
)

unless Battle.singleton_class.ancestors.include?(
  KaitoEveboostSync::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoEveboostSync::ConstructionHook)
end

#===============================================================================
# PREMONITION
# Halves the first attack hit that actually damages HP during each entry.
#===============================================================================
module KaitoPremonition
  ABILITY = :PREMONITION

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.ready?(object)
    user = real(object)
    return false if !user || user.fainted?
    return false if user.instance_variable_get(:@kaito_premonition_used)

    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ABILITY)
    end

    return true if user.respond_to?(:ability_id) &&
                   user.ability_id == ABILITY

    return user.respond_to?(:set_innate_limits) &&
           Array(user.set_innate_limits).include?(ABILITY)
  end

  # Approximate total-move damage: only the first hit is reduced.
  def self.ai_damage(damage, user, target, move)
    return damage if !damage || damage <= 0 || !move
    return damage if !ready?(target)

    source = real(user)
    defender = real(target)

    if defined?(AdvancedAI::Utilities)
      return damage if AdvancedAI::Utilities.ignores_ability?(
        user, move, target
      )
    elsif source.respond_to?(:hasMoldBreaker?)
      return damage if source.hasMoldBreaker?
    end

    info = GameData::Move.try_get(move.id)
    return damage if !info || info.category == 2

    hits = case info.function_code
           when "HitTwoTimes", "HitTwoTimesFlinchTarget"
             2.0
           when "HitThreeTimes", "HitThreeTimesPowersUpWithEachHit"
             3.0
           when "HitTwoToFiveTimes"
             if source.respond_to?(:hasActiveAbility?) &&
                source.hasActiveAbility?(:SKILLLINK)
               5.0
             else
               3.0
             end
           else
             1.0
           end

    return [(damage * (1.0 - 0.5 / hits)).round, 1].max
  end

  module BattlerHook
    def pbInitEffects(batonPass)
      result = super
      @kaito_premonition_used = false
      @kaito_premonition_pending = false
      return result
    end
  end

  module MoveHook
    # Apply before HP clipping, Focus Sash, Sturdy and Endure.
    def pbReduceDamage(user, target)
      target.instance_variable_set(:@kaito_premonition_pending, false)
      state = target.damageState

      return super if !KaitoPremonition.ready?(target)
      return super if @battle.moldBreaker || state.calcDamage <= 0
      return super if state.substitute || state.disguise || state.iceFace

      original = state.calcDamage

      # Shield absorbs its normal amount; halve only the HP overflow.
      shield = target.respond_to?(:pbShieldHP) ? target.pbShieldHP : 0
      absorbed = [shield, original].min
      overflow = original - absorbed
      return super if overflow <= 0

      target.instance_variable_set(:@kaito_premonition_pending, true)

      begin
        state.calcDamage = absorbed + [(overflow / 2.0).round, 1].max
        return super
      ensure
        state.calcDamage = original
      end
    end

    # Consume only after real HP has actually decreased.
    def pbInflictHPDamage(target)
      pending = target.instance_variable_get(:@kaito_premonition_pending)
      target.instance_variable_set(:@kaito_premonition_pending, false)

      old_hp = target.hp
      result = super

      if pending && target.hp < old_hp &&
         !target.instance_variable_get(:@kaito_premonition_used)
        target.instance_variable_set(:@kaito_premonition_used, true)

        @battle.pbShowAbilitySplash(target)
        begin
          @battle.pbDisplay(_INTL(
            "{1} foresaw the attack and softened the blow!",
            target.pbThis
          ))
        ensure
          @battle.pbHideAbilitySplash(target)
        end
      end

      return result
    end
  end

  module NativeAI
    def rough_damage
      damage = super
      return KaitoPremonition.ai_damage(
        damage, @ai.user, @ai.target, @move
      )
    end
  end

  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      return value if !move

      # Use a large reference value to retain multiplier precision.
      adjusted = KaitoPremonition.ai_damage(
        100000.0, user, target, move
      )
      return value * adjusted / 100000.0
    end
  end

  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      damage = super
      return damage if !move || !user || !target

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination &&
         defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?(ExtendedTerrains::AdvancedScorerHooks) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return damage
      end

      return KaitoPremonition.ai_damage(damage, user, target, move)
    end
  end

  # Install after plugin aliases have finished loading.
  def self.install!
    {
      Battle::Battler => BattlerHook,
      Battle::Move => MoveHook,
      Battle::AI::AIMove => NativeAI
    }.each do |klass, hook|
      klass.prepend(hook) unless klass.ancestors.include?(hook)
    end

    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoPremonition.install!
      super(*args, &block)
    end
  end
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[8].include?(:PREMONITION)
  Battle::AI::BASE_ABILITY_RATINGS[8] << :PREMONITION
end

unless Battle.singleton_class.ancestors.include?(
  KaitoPremonition::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoPremonition::ConstructionHook)
end

#===============================================================================
# MINDWARD
# Doubles Special Defense while Psychic Terrain is active.
#===============================================================================
module KaitoMindward
  ABILITY = :MINDWARD

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.battle_of(object)
    object = real(object)
    object ? object.instance_variable_get(:@battle) : nil
  end

  def self.active?(object, battle = nil)
    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return false if !user.hasActiveAbility?(ABILITY)
    else
      ordinary = user.respond_to?(:ability_id) &&
                 user.ability_id == ABILITY
      innate = user.respond_to?(:set_innate_limits) &&
               Array(user.set_innate_limits).include?(ABILITY)
      return false if !ordinary && !innate
    end

    battle ||= battle_of(user)
    return battle && battle.field.terrain == :Psychic
  end

  def self.fixed?(move)
    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)

    info = GameData::Move.try_get(move.id)
    return false if !info

    code = info.function_code.to_s
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return [
      "LowerTargetHPToUserHP",
      "UserFaintsFixedDamageUserHP",
      "MultiTurnAttackBideThenReturnDoubleDamage"
    ].include?(code)
  end

  def self.ai_factor(user, target, move, physical_defense, battle = nil)
    return 1.0 if physical_defense || !active?(target, battle)
    return 1.0 if move && fixed?(move)
    return 1.0 if AdvancedAI::Utilities.ignores_ability?(user, move, target)

    return 0.5
  end

  def self.staged(object, stat)
    user = real(object)
    value = stat == :ATTACK ? user.attack : user.spatk
    stage = user.respond_to?(:stages) ? user.stages[stat].to_i : 0
    stage = [[stage, -6].max, 6].min
    factor = stage >= 0 ? (2.0 + stage) / 2 : 2.0 / (2 - stage)

    return [(value * factor).floor, 1].max
  end

  # Advanced AI: shared damage estimator.
  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      battle = KaitoMindward.battle_of(target) ||
               KaitoMindward.battle_of(user)

      return value * KaitoMindward.ai_factor(
        user, target, move, physical_defense, battle
      )
    end
  end

  # Advanced AI: separate move damage estimator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      damage = super
      return damage if !move || !user || !target
      return damage if !damage || damage <= 0 || !move.damagingMove?
      return damage if KaitoMindward.fixed?(move)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination &&
         defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?(ExtendedTerrains::AdvancedScorerHooks) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return damage
      end

      info = GameData::Move.try_get(move.id)
      return damage if !info

      physical = info.category == 0
      dynamic = [:PHOTONGEYSER, :LIGHTTHATBURNSTHESKY].include?(move.id)
      dynamic ||= move.id == :TERABLAST && !!get_tera_type_for_move(user)

      if dynamic
        physical = KaitoMindward.staged(user, :ATTACK) >
                   KaitoMindward.staged(user, :SPECIAL_ATTACK)
      end

      physical_defense = physical
      if info.function_code == "UseTargetDefenseInsteadOfTargetSpDef"
        physical_defense = true
      end

      if @battle.field.effects[PBEffects::WonderRoom] > 0
        physical_defense = !physical_defense
      end

      factor = KaitoMindward.ai_factor(
        user, target, move, physical_defense, @battle
      )
      return damage if factor == 1.0

      return [(damage * factor).round, 1].max
    end
  end

  # Delay installation until all plugin aliases have loaded.
  def self.install!
    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoMindward.install!
      super(*args, &block)
    end
  end
end

# Actual battle + native AI.
Battle::AbilityEffects::DamageCalcFromTarget.add(:MINDWARD,
  proc { |ability, user, target, move, mults, power, type|
    next if !KaitoMindward.active?(target)
    next if !move.specialMove?
    next if move.function_code == "UseTargetDefenseInsteadOfTargetSpDef"

    mults[:defense_multiplier] *= 1.5
  }
)

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:MINDWARD)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :MINDWARD
end

unless Battle.singleton_class.ancestors.include?(
  KaitoMindward::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoMindward::ConstructionHook)
end

#===============================================================================
# BAD LUCK
# Opposing aura:
# - Blocks random critical hits, preserves guaranteed critical hits.
# - 2-5-hit moves hit twice; Skill Link/Loaded Dice guarantee five hits.
# - Accuracy x0.95; uncertain move secondary effects become 1%.
# - Confusion self-hit: 66%; full paralysis: 50%.
#===============================================================================
module KaitoBadLuck
  ABILITY = :BADLUCK

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.battle_of(object)
    object = real(object)
    return nil if !object
    return object.battle if object.respond_to?(:battle)

    object.instance_variable_get(:@battle)
  end

  def self.afflicted?(object, battle = nil)
    user = real(object)
    return false if !user || user.fainted?
    return false if !user.respond_to?(:index)

    battle ||= battle_of(user)
    return false if !battle

    return battle.allBattlers.any? do |holder|
      !holder.fainted? && holder.opposes?(user.index) &&
        holder.hasActiveAbility?(ABILITY)
    end
  end

  def self.two_to_five?(move, object)
    return false if !move

    info = GameData::Move.try_get(move.id)
    return false if !info
    return false if !info.function_code.start_with?("HitTwoToFiveTimes")

    # Fixed-hit Water Shuriken variants retain their original hit count.
    user = real(object)
    if info.function_code == "HitTwoToFiveTimesOrThreeForAshGreninja" &&
       user.respond_to?(:isSpecies?) && user.isSpecies?(:GRENINJA) &&
       [2, 3].include?(user.form)
      return false
    end

    return true
  end

  def self.hit_count(object)
    user = real(object)
    return 5 if user.hasActiveAbility?(:SKILLLINK)
    return 5 if user.hasActiveItem?(:LOADEDDICE)
    return 2
  end

  # Match the engine's guaranteed-critical checks without rolling RNG.
  def self.guaranteed_critical?(move, user, target, battle)
    return false if target.pbOwnSide.effects[PBEffects::LuckyChant] > 0

    old_name = $aamName
    begin
      stage = 0

      if stage >= 0 && user.abilityActive?
        stage = Battle::AbilityEffects.triggerCriticalCalcFromUser(
          user.ability, user, target, stage
        )
      end

      if stage >= 0 && target.abilityActive? && !battle.moldBreaker
        stage = Battle::AbilityEffects.triggerCriticalCalcFromTarget(
          target.ability, user, target, stage
        )
      end

      if stage >= 0 && user.itemActive?
        stage = Battle::ItemEffects.triggerCriticalCalcFromUser(
          user.item, user, target, stage
        )
      end

      if stage >= 0 && target.itemActive?
        stage = Battle::ItemEffects.triggerCriticalCalcFromTarget(
          target.item, user, target, stage
        )
      end

      return false if stage < 0

      case move.pbCritialOverride(user, target)
      when 1  then return true
      when -1 then return false
      end

      return true if stage > 50
      return true if user.effects[PBEffects::LaserFocus] > 0

      stage += 1 if move.highCriticalRate?
      stage += user.effects[PBEffects::FocusEnergy]
      stage += 1 if user.inHyperMode? && move.type == :SHADOW

      ratios = Battle::Move::CRITICAL_HIT_RATIOS
      stage = [stage, ratios.length - 1].min
      return ratios[stage] == 1
    ensure
      $aamName = old_name
    end
  end

  # Stack scoped strictly to move-use success checks.
  def self.checks(battle)
    stack = battle.instance_variable_get(:@kaito_bad_luck_checks)
    if !stack
      stack = []
      battle.instance_variable_set(:@kaito_bad_luck_checks, stack)
    end
    return stack
  end

  # Original secondary probability, before Bad Luck's final reduction.
  # Used only for AI evaluation.
  def self.secondary_chance(move, object, target, battle)
    return 0 if !move || !@secondary_original

    user = real(object)
    defender = real(target)
    return 0 if !user || !defender

    native = move.respond_to?(:move) ? move.move : move
    if !native.is_a?(Battle::Move)
      native = Battle::Move.from_pokemon_move(
        battle, Pokemon::Move.new(move.id)
      )
    end

    return @secondary_original.bind(native).call(user, defender)
  end

  # A neutral move copy for separating move effects from ability effects.
  def self.neutral_secondary(move)
    native = move.respond_to?(:move) ? move.move : move
    native = native.dup
    native.instance_variable_set(:@addlEffect, 0)
    native.define_singleton_method(:addlEffect) { 0 }
    native.define_singleton_method(:function_code) { "None" }
    native.define_singleton_method(:flinchingMove?) { false }

    return native if !move.respond_to?(:move)

    wrapper = move.dup
    wrapper.instance_variable_set(:@move, native)
    wrapper.define_singleton_method(:move) { native }
    wrapper.define_singleton_method(:addlEffect) { 0 }
    wrapper.define_singleton_method(:function_code) { "None" }
    wrapper.define_singleton_method(:flinchingMove?) { false }
    return wrapper
  end

  # AI: value inflicting confusion/paralysis on an afflicted opponent.
  def self.status_bonus(move, user, target, battle)
    return 0 if !move || !user || !target

    source = real(user)
    defender = real(target)
    return 0 if !source.respond_to?(:opposes?)
    return 0 if !source.opposes?(defender)
    return 0 if !afflicted?(defender, battle)

    info = GameData::Move.try_get(move.id)
    return 0 if !info

    chance = if info.category == 2
               1.0
             else
               value = secondary_chance(move, user, target, battle)
               value >= 100 ? 1.0 : (value > 0 ? 0.01 : 0.0)
             end

    bonus = 0
    code = info.function_code

    if code.include?("ConfuseTarget") &&
       defender.effects[PBEffects::Confusion] <= 0
      bonus += 20
    end

    if code.include?("ParalyzeTarget") && defender.status == :NONE
      bonus += 15
    end

    return (bonus * chance).round
  end

  #---------------------------------------------------------------------------
  # Actual battle: critical hits, accuracy, secondary effects.
  #---------------------------------------------------------------------------
  module MoveHook
    def pbIsCritical?(user, target)
      if KaitoBadLuck.afflicted?(user, @battle)
        return false if !KaitoBadLuck.guaranteed_critical?(
          self, user, target, @battle
        )
      end

      return super
    end

    def pbCalcAccuracyModifiers(user, target, modifiers)
      result = super

      if modifiers[:base_accuracy] > 0 &&
         KaitoBadLuck.afflicted?(user, @battle)
        modifiers[:accuracy_multiplier] *= 0.95
      end

      return result
    end

    def pbAdditionalEffectChance(user, target, effectChance = 0)
      chance = super
      return chance if chance <= 0 || chance >= 100
      return KaitoBadLuck.afflicted?(user, @battle) ? 1 : chance
    end
  end

  module HitCountHook
    def pbNumHits(user, targets)
      if KaitoBadLuck.afflicted?(user, @battle) &&
         KaitoBadLuck.two_to_five?(self, user)
        return KaitoBadLuck.hit_count(user)
      end

      return super
    end
  end

  #---------------------------------------------------------------------------
  # Actual battle: preserve the engine's status-check order.
  #---------------------------------------------------------------------------
  module BattlerHook
    def pbTryUseMove(*args, &block)
      stack = KaitoBadLuck.checks(@battle)
      frame = {
        :user => self,
        :enabled => !args[3],
        :confusion_roll => false,
        :paralysis_checked => false
      }

      stack.push(frame)
      begin
        return super(*args, &block)
      ensure
        stack.pop
      end
    end
  end

  module BattleHook
    def pbCommonAnimation(name, user = nil, target = nil)
      frame = KaitoBadLuck.checks(self).last

      if frame && frame[:enabled] && name == "Confusion" &&
         user.equal?(frame[:user])
        frame[:confusion_roll] = true
      end

      return super
    end

    def pbRandom(*args)
      roll = super
      return roll if args.length != 1 || args[0] != 100

      frame = KaitoBadLuck.checks(self).last
      return roll if !frame || !frame[:enabled]

      # Ignore animation RNG, obedience RNG and every other nested check.
      location = caller_locations(1, 1)[0]
      return roll if !location ||
                     !location.base_label.include?("pbTryUseMove")

      user = frame[:user]

      if frame[:confusion_roll]
        frame[:confusion_roll] = false
        return roll if !KaitoBadLuck.afflicted?(user, self)

        # Works with either the engine's 33% or 50% confusion threshold.
        return roll < 66 ? 0 : 99
      end

      if user.status == :PARALYSIS && !frame[:paralysis_checked]
        frame[:paralysis_checked] = true
        return roll if !KaitoBadLuck.afflicted?(user, self)

        # Works with both standard and Champions paralysis thresholds.
        return roll < 50 ? 0 : 99
      end

      return roll
    end
  end

  #---------------------------------------------------------------------------
  # Native AI.
  #---------------------------------------------------------------------------
  module NativeAI
    def rough_critical_hit_stage
      stage = super
      return stage if !KaitoBadLuck.afflicted?(@ai.user, @ai.battle)
      return stage if stage < 0

      ratios = Battle::Move::CRITICAL_HIT_RATIOS
      return stage if stage >= ratios.length || ratios[stage] == 1

      return -1
    end

    def apply_rough_accuracy_modifiers(user, target, type, modifiers)
      result = super

      if modifiers[:base_accuracy] > 0 &&
         KaitoBadLuck.afflicted?(user, @ai.battle)
        modifiers[:accuracy_multiplier] *= 0.95
      end

      return result
    end

    def base_power
      if KaitoBadLuck.afflicted?(@ai.user, @ai.battle) &&
         KaitoBadLuck.two_to_five?(@move, @ai.user)
        power = @move.pbBaseDamage(
          @move.power, @ai.user.battler, @ai.target.battler
        )
        return power * KaitoBadLuck.hit_count(@ai.user)
      end

      return super
    end

    def get_score_change_for_additional_effect(user, target = nil)
      score = super
      return score if score == -999 || !target
      return score if !KaitoBadLuck.afflicted?(user, @ai.battle)

      chance = KaitoBadLuck.secondary_chance(
        @move, user, target, @ai.battle
      )
      return score if chance <= 0 || chance >= 100

      return -8
    end
  end

  #---------------------------------------------------------------------------
  # Advanced AI.
  #---------------------------------------------------------------------------
  module CombatAI
    def expected_hit_multiplier(move, user)
      if KaitoBadLuck.afflicted?(user) &&
         KaitoBadLuck.two_to_five?(move, user)
        return KaitoBadLuck.hit_count(user).to_f
      end

      return super
    end
  end

  module ScorerAI
    def score_crit_potential(move, user, target)
      if KaitoBadLuck.afflicted?(user, @battle)
        guaranteed = AdvancedAI::CombatUtilities.move_guaranteed_critical?(
          move, user, target
        )
        return 0 if !guaranteed
      end

      return super
    end

    def score_accuracy(move, skill, user = nil)
      score = super
      return score if !user || !KaitoBadLuck.afflicted?(user, @battle)

      info = GameData::Move.try_get(move.id)
      return score if !info || info.accuracy == 0
      return score if KaitoBadLuck.real(user).hasActiveAbility?(:NOGUARD)

      return score - 5
    end

    def score_secondary_effects(move, user, target)
      score = super
      return score if !move || !target
      return score if !KaitoBadLuck.afflicted?(user, @battle)

      chance = KaitoBadLuck.secondary_chance(
        move, user, target, @battle
      )
      return score if chance <= 0 || chance >= 100

      neutral = KaitoBadLuck.neutral_secondary(move)
      unrelated = super(neutral, user, target)

      return unrelated + ((score - unrelated) / chance.to_f).round
    end

    def score_move_advanced(move, user, target, skill)
      @kaito_bad_luck_score_depth = @kaito_bad_luck_score_depth.to_i + 1
      begin
        score = super
        return score if score <= -100
        return score if @kaito_bad_luck_score_depth > 1

        return score + KaitoBadLuck.status_bonus(
          move, user, target, @battle
        )
      ensure
        @kaito_bad_luck_score_depth -= 1
      end
    end
  end

  #---------------------------------------------------------------------------
  # Install once, after all plugin aliases have loaded.
  #---------------------------------------------------------------------------
  def self.install!
    return if @installed

    @secondary_original =
      Battle::Move.instance_method(:pbAdditionalEffectChance)

    Battle::Move.prepend(MoveHook)
    Battle::Battler.prepend(BattlerHook)
    Battle.prepend(BattleHook)
    Battle::AI::AIMove.prepend(NativeAI)

    # Hook each class that owns a 2-5-hit count implementation.
    ObjectSpace.each_object(Class) do |klass|
      next if !(klass < Battle::Move::HitTwoToFiveTimes) &&
              klass != Battle::Move::HitTwoToFiveTimes
      next if !klass.instance_methods(false).include?(:pbNumHits)

      hook = Module.new
      hook.include(HitCountHook)
      klass.prepend(hook)
    end

    if defined?(AdvancedAI::CombatUtilities)
      AdvancedAI::CombatUtilities.singleton_class.prepend(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:score_move_advanced)
      Battle::AI.prepend(ScorerAI)
    end

    @installed = true
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoBadLuck.install!
      super(*args, &block)
    end
  end
end

Battle::AI::Handlers::GeneralMoveScore.add(:kaito_bad_luck_status,
  proc { |score, move, user, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next score if ai.instance_variable_get(
      :@kaito_bad_luck_score_depth
    ).to_i > 0

    next score + KaitoBadLuck.status_bonus(
      move, user, ai.target, battle
    )
  }
)

Battle::AI::BASE_ABILITY_RATINGS[9] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[9].include?(:BADLUCK)
  Battle::AI::BASE_ABILITY_RATINGS[9] << :BADLUCK
end

unless Battle.singleton_class.ancestors.include?(
  KaitoBadLuck::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoBadLuck::ConstructionHook)
end

#===============================================================================
# SOLAR PSYCHE
# Psychic attacks deal double damage in Sun/Harsh Sun.
#===============================================================================
module KaitoSolarPsyche
  ABILITY = :SOLARPSYCHE

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.battle_of(object)
    object = real(object)
    object ? object.instance_variable_get(:@battle) : nil
  end

  def self.active?(object, type, battle = nil)
    return false if type != :PSYCHIC

    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return false if !user.hasActiveAbility?(ABILITY)
    else
      ordinary = user.respond_to?(:ability_id) &&
                 user.ability_id == ABILITY
      innate = user.respond_to?(:set_innate_limits) &&
               Array(user.set_innate_limits).include?(ABILITY)
      return false if !ordinary && !innate
    end

    battle ||= battle_of(user)
    weather = user.respond_to?(:effectiveWeather) ?
                user.effectiveWeather : (battle && battle.pbWeather)

    return [:Sun, :HarshSun].include?(weather)
  end

  def self.fixed?(move)
    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)

    info = GameData::Move.try_get(move.id)
    return false if !info

    code = info.function_code.to_s
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return [
      "LowerTargetHPToUserHP",
      "UserFaintsFixedDamageUserHP",
      "MultiTurnAttackBideThenReturnDoubleDamage"
    ].include?(code)
  end

  # Advanced AI: shared damage estimator.
  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      return value if move && KaitoSolarPsyche.fixed?(move)

      battle = KaitoSolarPsyche.battle_of(user) ||
               KaitoSolarPsyche.battle_of(target)

      if KaitoSolarPsyche.active?(user, type, battle)
        value *= 2.0
      end

      return value
    end
  end

  # Advanced AI: separate move damage estimator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      damage = super
      return damage if !move || !user || !target
      return damage if !damage || damage <= 0 || !move.damagingMove?
      return damage if KaitoSolarPsyche.fixed?(move)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination &&
         defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?(ExtendedTerrains::AdvancedScorerHooks) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return damage
      end

      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end

      return damage if !KaitoSolarPsyche.active?(user, type, @battle)
      return [(damage * 2.0).round, 1].max
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoSolarPsyche.install!
      super(*args, &block)
    end
  end
end

# Actual battle + native AI.
Battle::AbilityEffects::DamageCalcFromUser.add(:SOLARPSYCHE,
  proc { |ability, user, target, move, mults, power, type|
    next if !KaitoSolarPsyche.active?(user, type)
    next if KaitoSolarPsyche.fixed?(move)

    mults[:final_damage_multiplier] *= 2.0
  }
)

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[8].include?(:SOLARPSYCHE)
  Battle::AI::BASE_ABILITY_RATINGS[8] << :SOLARPSYCHE
end

Battle::AI::Handlers::AbilityRanking.add(:SOLARPSYCHE,
  proc { |ability, score, battler, ai|
    next battler.has_damaging_move_of_type?(:PSYCHIC) ? score : 0
  }
)

unless Battle.singleton_class.ancestors.include?(
  KaitoSolarPsyche::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoSolarPsyche::ConstructionHook)
end

#===============================================================================
# BALEFUL GLOW
# Uses the target's Attack/Sp. Atk and corresponding stat stages.
#===============================================================================
module KaitoBalefulGlow
  ABILITY = :BALEFULGLOW

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.active?(object)
    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ABILITY)
    end

    return true if user.respond_to?(:ability_id) &&
                   user.ability_id == ABILITY

    return user.respond_to?(:set_innate_limits) &&
           Array(user.set_innate_limits).include?(ABILITY)
  end

  def self.data(move)
    return nil if !move || !move.respond_to?(:id)
    GameData::Move.try_get(move.id)
  end

  def self.fixed?(move)
    info = data(move)
    return true if !info

    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)

    code = info.function_code
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return true if [
      "LowerTargetHPToUserHP",
      "UserFaintsFixedDamageUserHP",
      "MultiTurnAttackBideThenReturnDoubleDamage"
    ].include?(code)

    if Battle::Move.const_defined?(code, false)
      klass = Battle::Move.const_get(code, false)
      return true if klass.is_a?(Class) &&
                     klass <= Battle::Move::FixedDamageMove
    end

    return false
  end

  def self.applies?(user, target, move)
    return false if !active?(user) || !target
    info = data(move)
    return info && info.category != 2 && !fixed?(move)
  end

  def self.stage(object, stat)
    object = real(object)
    return 0 if !object.respond_to?(:stages)
    return [[object.stages[stat].to_i, -6].max, 6].min
  end

  def self.staged(value, increment)
    factor = increment >= 0 ?
               (2.0 + increment) / 2 : 2.0 / (2 - increment)
    return [(value * factor).floor, 1].max
  end

  def self.has?(object, ability)
    object = real(object)
    return false if !object

    if object.respond_to?(:hasActiveAbility?)
      return object.hasActiveAbility?(ability)
    end

    return true if object.respond_to?(:ability_id) &&
                   object.ability_id == ability

    return object.respond_to?(:set_innate_limits) &&
           Array(object.set_innate_limits).include?(ability)
  end

  # Category-changing moves retain their usual category-selection rule.
  def self.physical?(user, move, tera = false)
    info = data(move)
    return false if !info

    source = real(user)
    dynamic = [:PHOTONGEYSER, :LIGHTTHATBURNSTHESKY].include?(info.id)
    dynamic ||= info.id == :TERABLAST &&
      (tera || (source.respond_to?(:tera?) && source.tera?))

    if dynamic
      attack = staged(source.attack, stage(source, :ATTACK))
      spatk = staged(source.spatk, stage(source, :SPECIAL_ATTACK))
      return attack > spatk
    end

    return info.category == 0
  end

  # Advanced AI correction relative to its original attacking-stat source.
  def self.ai_ratio(user, target, move, physical, shared = false)
    return 1.0 if !applies?(user, target, move)

    source = real(user)
    defender = real(target)
    info = data(move)
    stat = physical ? :ATTACK : :SPECIAL_ATTACK

    new_value = physical ? defender.attack : defender.spatk
    new_stage = stage(defender, stat)

    old_value = physical ? source.attack : source.spatk
    old_stage = stage(source, stat)

    # Existing AI implementations use these special stat sources.
    if info.function_code == "UseTargetAttackInsteadOfUserAttack"
      old_value = defender.attack
      old_stage = stage(defender, :ATTACK)
    elsif info.function_code == "UseUserDefenseInsteadOfUserAttack"
      old_value = source.defense
      old_stage = stage(source, :DEFENSE)
    elsif info.function_code == "UseUserSpeedInsteadOfUserAttack"
      old_value = source.speed
      old_stage = stage(source, :SPEED)
    end

    unaware = has?(defender, :UNAWARE) &&
      !AdvancedAI::Utilities.ignores_ability?(user, move, target)

    new_stage = 0 if unaware
    if unaware &&
       !(shared && info.function_code == "UseTargetAttackInsteadOfUserAttack")
      old_stage = 0
    end

    critical = AdvancedAI::CombatUtilities.move_guaranteed_critical?(
      move, user, target
    )
    new_stage = 0 if critical && new_stage < 0
    old_stage = 0 if critical && old_stage < 0

    numerator = staged(new_value, new_stage)
    denominator = staged(old_value, old_stage)

    # Baleful Glow takes precedence over Kinetic.
    # Its existing AI correction has already replaced the original source.
    if defined?(KaitoKinetic) && KaitoKinetic.active?(user)
      denominator = KaitoKinetic.speed(user)
    end

    return numerator.to_f / [denominator, 1].max
  end

  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      return value if !move

      return value * KaitoBalefulGlow.ai_ratio(
        user, target, move, physical, true
      )
    end
  end

  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      damage = super
      return damage if !move || !user || !target
      return damage if !damage || damage <= 0
      return damage if !KaitoBalefulGlow.applies?(user, target, move)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination &&
         defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?(ExtendedTerrains::AdvancedScorerHooks) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return damage
      end

      tera = move.id == :TERABLAST && !!get_tera_type_for_move(user)
      physical = KaitoBalefulGlow.physical?(user, move, tera)
      ratio = KaitoBalefulGlow.ai_ratio(user, target, move, physical)

      return [(damage * ratio).round, 1].max
    end
  end

  # Install after all plugins have finished defining aliases.
  def self.install!
    return if @installed

    # Establish priority before installing our stat-source hooks.
    if defined?(KaitoKinetic) && KaitoKinetic.respond_to?(:install!)
      KaitoKinetic.install!
    end

    # Include moves with their own stat-source methods, e.g. Body Press.
    classes = []
    ObjectSpace.each_object(Class) do |klass|
      next if !(klass <= Battle::Move)
      next if !klass.instance_methods(false).include?(:pbGetAttackStats)
      classes << klass
    end

    classes.each do |klass|
      hook = Module.new do
        def pbGetAttackStats(user, target)
          if KaitoBalefulGlow.applies?(user, target, self)
            maximum = Battle::Battler::STAT_STAGE_MAXIMUM

            if specialMove?
              return target.spatk,
                     target.stages[:SPECIAL_ATTACK] + maximum
            end

            return target.attack, target.stages[:ATTACK] + maximum
          end

          return super
        end
      end

      klass.prepend(hook)
    end

    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      AdvancedAI::CombatUtilities.singleton_class.prepend(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage)
      Battle::AI.prepend(ScorerAI)
    end

    @installed = true
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoBalefulGlow.install!
      super(*args, &block)
    end
  end
end

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[8].include?(:BALEFULGLOW)
  Battle::AI::BASE_ABILITY_RATINGS[8] << :BALEFULGLOW
end

unless Battle.singleton_class.ancestors.include?(
  KaitoBalefulGlow::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoBalefulGlow::ConstructionHook)
end

#===============================================================================
# FREEZE ALL
# Each damaging hit has a 20% chance to freeze the opposing target.
#===============================================================================
module KaitoFreezeAll
  ABILITY = :FREEZEALL
  CHANCE = 25

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.active?(object)
    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ABILITY)
    end

    return true if user.respond_to?(:ability_id) &&
                   user.ability_id == ABILITY

    return user.respond_to?(:set_innate_limits) &&
           Array(user.set_innate_limits).include?(ABILITY)
  end

  def self.native_move(move, battle)
    return nil if !move

    native = move.respond_to?(:move) ? move.move : move
    return native if native.is_a?(Battle::Move)
    return nil if !GameData::Move.exists?(move.id)

    return Battle::Move.from_pokemon_move(
      battle, Pokemon::Move.new(move.id)
    )
  end

  def self.eligible?(user, target, move, battle)
    user = real(user)
    target = real(target)

    return false if !active?(user) || !target || target.fainted?
    return false if !user.is_a?(Battle::Battler)
    return false if !target.is_a?(Battle::Battler)
    return false if !target.opposes?(user)

    native = native_move(move, battle)
    return false if !native || !native.damagingMove?
    return false if target.hasActiveItem?(:COVERTCLOAK)
    return false if target.hasActiveAbility?(:SHIELDDUST) &&
                    !battle.moldBreaker

    return target.pbCanFreeze?(user, false, native)
  end

  def self.trigger(user, target, move, battle)
    return if !target || !move
    return if target.damageState.substitute
    return if target.damageState.hpLost <= 0
    return if !eligible?(user, target, move, battle)
    return if battle.pbRandom(100) >= CHANCE

    battle.pbShowAbilitySplash(user)
    begin
      duration = 0
      if defined?(Settings::CHAMPIONS_MECHANICS) &&
         Settings::CHAMPIONS_MECHANICS
        duration = 3
      end

      # Supply the source so status-response abilities can identify the attacker.
      target.pbInflictStatus(:FROZEN, duration, nil, user)
    ensure
      battle.pbHideAbilitySplash(user)
    end
  end

  # AI scoring only; no real status is applied during prediction.
  def self.bonus(move, user, target, battle)
    return 0 if !eligible?(user, target, move, battle)

    native = native_move(move, battle)
    hits = 1.0

    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:expected_hit_multiplier)
      hits = AdvancedAI::CombatUtilities.expected_hit_multiplier(
        native, real(user)
      )
    elsif native.multiHitMove?
      code = native.function_code
      hits = if code.start_with?("HitTwoToFiveTimes")
               real(user).hasActiveAbility?(:SKILLLINK) ? 5.0 : 3.1
             elsif code.start_with?("HitTwoTimes")
               2.0
             elsif code.start_with?("HitThreeTimes")
               3.0
             else
               2.0
             end
    end

    hits = [[hits.to_f, 1.0].max, 10.0].min
    probability = 1.0 - ((1.0 - CHANCE / 100.0) ** hits)

    return (75 * probability).round
  end

  module AdvancedScoring
    def score_secondary_effects(move, user, target)
      @kaito_freeze_all_ai_depth = @kaito_freeze_all_ai_depth.to_i + 1
      begin
        score = super
        return score if @kaito_freeze_all_ai_depth > 1

        return score + KaitoFreezeAll.bonus(
          move, user, target, @battle
        )
      ensure
        @kaito_freeze_all_ai_depth -= 1
      end
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    return if !defined?(AdvancedAI)
    return if !Battle::AI.method_defined?(:score_secondary_effects)
    return if Battle::AI.ancestors.include?(AdvancedScoring)

    Battle::AI.prepend(AdvancedScoring)
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoFreezeAll.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::OnDealingHit.add(:FREEZEALL,
  proc { |ability, user, target, move, battle|
    KaitoFreezeAll.trigger(user, target, move, battle)
  }
)

# Native AI.
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:kaito_freeze_all,
  proc { |score, move, user, target, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next score if ai.instance_variable_get(
      :@kaito_freeze_all_ai_depth
    ).to_i > 0

    next score + KaitoFreezeAll.bonus(move, user, target, battle)
  }
)

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[8].include?(:FREEZEALL)
  Battle::AI::BASE_ABILITY_RATINGS[8] << :FREEZEALL
end

unless Battle.singleton_class.ancestors.include?(
  KaitoFreezeAll::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoFreezeAll::ConstructionHook)
end

#===============================================================================
# RIME LAYER
# After using an Ice move, randomly raises Defense or Special Defense by 1.
#===============================================================================
module KaitoRimeLayer
  ABILITY = :RIMELAYER
  STATS = [:DEFENSE, :SPECIAL_DEFENSE].freeze

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.active?(object)
    user = real(object)
    return false if !user || user.fainted?
    return user.respond_to?(:hasActiveAbility?) &&
           user.hasActiveAbility?(ABILITY)
  end

  def self.available_stats(object)
    user = real(object)
    return [] if !active?(user)

    return STATS.select do |stat|
      user.pbCanRaiseStatStage?(stat, user)
    end
  end

  def self.trigger(user, move, battle)
    return if !move || !active?(user)
    return if move.calcType != :ICE

    # A two-turn move must finish charging first.
    return if user.effects[PBEffects::TwoTurnAttack] == move.id

    stats = available_stats(user)
    return if stats.empty?

    stat = stats.length == 1 ? stats[0] : stats[battle.pbRandom(stats.length)]
    user.pbRaiseStatStageByAbility(stat, 1, user)
  end

  def self.predicted_type(move, user)
    return nil if !move

    # Native AI already resolves type-changing moves.
    return move.rough_type if move.respond_to?(:rough_type)

    if defined?(AdvancedAI::CombatUtilities)
      return AdvancedAI::CombatUtilities.resolve_move_type(user, move)
    end

    info = GameData::Move.try_get(move.id)
    return info ? info.type : nil
  end

  # Expected benefit of the random defensive increase.
  def self.bonus(object, move, battle, type = nil)
    user = real(object)
    return 0 if !active?(user) || !move
    return 0 if (type || predicted_type(move, user)) != :ICE

    stats = available_stats(user)
    return 0 if stats.empty?

    # The actual stat-change methods also handle Contrary and Simple.
    if user.hasActiveAbility?(:CONTRARY) && !battle.moldBreaker
      return user.hasActiveAbility?(:SIMPLE) ? -20 : -12
    end

    increment = user.hasActiveAbility?(:SIMPLE) ? 2 : 1
    scores = stats.map do |stat|
      gain = [increment, 6 - user.stages[stat]].min
      gain * 8
    end

    return (scores.inject(0.0, :+) / scores.length).round
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      @kaito_rime_layer_ai_depth = @kaito_rime_layer_ai_depth.to_i + 1

      begin
        score = super
        return score if score <= -100 || !move || !user
        return score if @kaito_rime_layer_ai_depth > 1

        type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
        if move.id == :TERABLAST
          tera_type = get_tera_type_for_move(user)
          type = tera_type if tera_type
        end

        return score + KaitoRimeLayer.bonus(user, move, @battle, type)
      ensure
        @kaito_rime_layer_ai_depth -= 1
      end
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    return if !defined?(AdvancedAI)
    return if !Battle::AI.method_defined?(:score_move_advanced)
    return if Battle::AI.ancestors.include?(AdvancedScoring)

    Battle::AI.prepend(AdvancedScoring)
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoRimeLayer.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::OnEndOfUsingMove.add(:RIMELAYER,
  proc { |ability, user, targets, move, battle|
    KaitoRimeLayer.trigger(user, move, battle)
  }
)

# Native AI.
Battle::AI::Handlers::GeneralMoveScore.add(:kaito_rime_layer,
  proc { |score, move, user, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next score if ai.instance_variable_get(
      :@kaito_rime_layer_ai_depth
    ).to_i > 0

    next score + KaitoRimeLayer.bonus(user, move, battle)
  }
)

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:RIMELAYER)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :RIMELAYER
end

Battle::AI::Handlers::AbilityRanking.add(:RIMELAYER,
  proc { |ability, score, battler, ai|
    user = KaitoRimeLayer.real(battler)
    has_ice_move = user.moves.any? do |move|
      info = move && GameData::Move.try_get(move.id)
      info && info.type == :ICE
    end
    next has_ice_move ? score : 0
  }
)

unless Battle.singleton_class.ancestors.include?(
  KaitoRimeLayer::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoRimeLayer::ConstructionHook)
end

#===============================================================================
# SIPHON LEAVES
# Contact attackers lose 1/10 max HP.
# If HP was actually lost, the holder heals 1/10 of its own max HP.
#===============================================================================
module KaitoSiphonLeaves
  ABILITY = :SIPHONLEAVES

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.native_move(move, battle)
    return nil if !move

    native = move.respond_to?(:move) ? move.move : move
    return native if native.is_a?(Battle::Move)
    return nil if !GameData::Move.exists?(move.id)

    return Battle::Move.from_pokemon_move(
      battle, Pokemon::Move.new(move.id)
    )
  end

  def self.trigger(user, target, move, battle)
    return if !user || !target || !move || user.fainted?
    return if !move.pbContactMove?(user)
    return if target.damageState.substitute
    return if !user.affectedByContactEffect?
    return if !user.takesIndirectDamage?

    battle.pbShowAbilitySplash(target)
    begin
      old_hp = user.hp
      battle.scene.pbDamageAnimation(user)
      user.pbReduceHP([user.totalhp / 10, 1].max, false)
      lost = [old_hp - user.hp, 0].max

      if lost > 0
        battle.pbDisplay(_INTL(
          "{1} was hurt by {2}'s sharp leaves!",
          user.pbThis, target.pbThis(true)
        ))

        # Fixed healing based on the holder's maximum HP.
        # A fainted holder cannot be revived.
        if target.canHeal?
          recovered = target.pbRecoverHP([target.totalhp / 10, 1].max)
          if recovered > 0
            battle.pbDisplay(_INTL(
              "{1} restored its HP!", target.pbThis
            ))
          end
        end
      end
    ensure
      battle.pbHideAbilitySplash(target)
    end

    # The engine handles the attacker's HP/item checks after OnBeingHit.
  end

  def self.predicted_hits(move, user)
    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:expected_hit_multiplier)
      hits = AdvancedAI::CombatUtilities.expected_hit_multiplier(move, user)
      return [[hits.to_f, 1.0].max, 10.0].min
    end

    return 1.0 if !move.multiHitMove?

    code = move.function_code
    return 2.0 if code.start_with?("HitTwoTimes")
    return 3.0 if code.start_with?("HitThreeTimes")
    if code.start_with?("HitTwoToFiveTimes")
      return 5.0 if user.hasActiveAbility?(:SKILLLINK)
      return 4.5 if user.hasActiveItem?(:LOADEDDICE)
      return 3.1
    end

    return 2.0
  end

  # AI scoring only; never applies damage or healing.
  def self.penalty(move, object, defender, battle, incoming = nil)
    user = real(object)
    target = real(defender)

    return 0 if !user.is_a?(Battle::Battler)
    return 0 if !target.is_a?(Battle::Battler)
    return 0 if user.fainted? || target.fainted?
    return 0 if !target.hasActiveAbility?(ABILITY)

    native = native_move(move, battle)
    return 0 if !native || !native.damagingMove?
    return 0 if !native.pbContactMove?(user)
    return 0 if !user.affectedByContactEffect?
    return 0 if !user.takesIndirectDamage?

    if target.effects[PBEffects::Substitute] > 0 &&
       !native.ignoresSubstitute?(user)
      return 0
    end

    hits = predicted_hits(native, user)
    recoil = [[user.totalhp / 10, 1].max * hits, user.hp].min

    healing = 0
    survives = !incoming || incoming < target.hp
    healing_blocked = target.effects[PBEffects::HealBlock] > 0
    healing_blocked ||= target.respond_to?(:pbBleeding?) && target.pbBleeding?

    if survives && !healing_blocked
      missing = target.totalhp - target.hp + [incoming.to_f, 0].max
      healing = [[target.totalhp / 10, 1].max * hits, missing].min
    end

    score = 55.0 * recoil / [user.totalhp, 1].max
    score += 55.0 * healing / [target.totalhp, 1].max
    score += 80 if recoil >= user.hp

    return score.round
  end

  module AdvancedScoring
    def score_move_advanced(move, user, target, skill)
      @kaito_siphon_leaves_ai_depth =
        @kaito_siphon_leaves_ai_depth.to_i + 1

      begin
        score = super
        return score if score <= -100 || !move || !user || !target
        return score if @kaito_siphon_leaves_ai_depth > 1

        defender = KaitoSiphonLeaves.real(target)
        return score if !defender.respond_to?(:hasActiveAbility?)
        return score if !defender.hasActiveAbility?(:SIPHONLEAVES)

        incoming = move.damagingMove? ?
                     calculate_rough_damage(move, user, target) : 0

        return score - KaitoSiphonLeaves.penalty(
          move, user, target, @battle, incoming
        )
      ensure
        @kaito_siphon_leaves_ai_depth -= 1
      end
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    return if !defined?(AdvancedAI)
    return if !Battle::AI.method_defined?(:score_move_advanced)
    return if Battle::AI.ancestors.include?(AdvancedScoring)

    Battle::AI.prepend(AdvancedScoring)
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoSiphonLeaves.install!
      super(*args, &block)
    end
  end
end

Battle::AbilityEffects::OnBeingHit.add(:SIPHONLEAVES,
  proc { |ability, user, target, move, battle|
    KaitoSiphonLeaves.trigger(user, target, move, battle)
  }
)

# Native AI.
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:kaito_siphon_leaves,
  proc { |score, move, user, target, ai, battle|
    next score if score <= Battle::AI::MOVE_USELESS_SCORE
    next score if ai.instance_variable_get(
      :@kaito_siphon_leaves_ai_depth
    ).to_i > 0

    defender = KaitoSiphonLeaves.real(target)
    next score if !defender.hasActiveAbility?(:SIPHONLEAVES)

    incoming = move.damagingMove? ? move.rough_damage : 0
    next score - KaitoSiphonLeaves.penalty(
      move, user, target, battle, incoming
    )
  }
)

Battle::AI::BASE_ABILITY_RATINGS[8] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[8].include?(:SIPHONLEAVES)
  Battle::AI::BASE_ABILITY_RATINGS[8] << :SIPHONLEAVES
end

unless Battle.singleton_class.ancestors.include?(
  KaitoSiphonLeaves::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoSiphonLeaves::ConstructionHook)
end

#===============================================================================
# PLAYFUL AGGRO
# Status condition: Special Attack x1.5.
# Ignores Frostbite's special damage penalty, but retains its residual damage.
#===============================================================================
module KaitoPlayfulAggro
  ABILITY = :PLAYFULAGGRO

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.has?(object)
    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ABILITY)
    end

    return true if user.respond_to?(:ability_id) &&
                   user.ability_id == ABILITY

    return user.respond_to?(:set_innate_limits) &&
           Array(user.set_innate_limits).include?(ABILITY)
  end

  def self.active?(object)
    user = real(object)
    return false if !has?(user)
    return user.status && user.status != :NONE
  end

  def self.frostbite_immune?(object)
    user = real(object)
    return has?(user) && user.status == :FROSTBITE
  end

  def self.data(move)
    return nil if !move || !move.respond_to?(:id)
    GameData::Move.try_get(move.id)
  end

  def self.fixed?(move)
    info = data(move)
    return true if !info

    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)

    code = info.function_code
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return true if [
      "LowerTargetHPToUserHP",
      "UserFaintsFixedDamageUserHP",
      "MultiTurnAttackBideThenReturnDoubleDamage"
    ].include?(code)

    if Battle::Move.const_defined?(code, false)
      klass = Battle::Move.const_get(code, false)
      return true if klass.is_a?(Class) &&
                     klass <= Battle::Move::FixedDamageMove
    end

    return false
  end

  def self.factor(user, physical, move = nil)
    return 1.0 if physical || !active?(user)

    if move
      info = data(move)
      return 1.0 if !info || info.category == 2 || fixed?(move)

      # These moves do not use the user's Special Attack.
      return 1.0 if [
        "UseTargetAttackInsteadOfUserAttack",
        "UseUserDefenseInsteadOfUserAttack",
        "UseUserSpeedInsteadOfUserAttack"
      ].include?(info.function_code)
    end

    if defined?(KaitoKinetic) && KaitoKinetic.active?(user)
      return 1.0
    end

    if defined?(KaitoBalefulGlow) && KaitoBalefulGlow.active?(user)
      return 1.0
    end

    return 1.5
  end

  def self.staged(object, stat)
    user = real(object)
    value = stat == :ATTACK ? user.attack : user.spatk
    stage = user.respond_to?(:stages) ? user.stages[stat].to_i : 0
    stage = [[stage, -6].max, 6].min
    factor = stage >= 0 ? (2.0 + stage) / 2 : 2.0 / (2 - stage)

    return [(value * factor).floor, 1].max
  end

  def self.physical?(user, move, tera = false)
    info = data(move)
    return false if !info

    source = real(user)
    dynamic = [:PHOTONGEYSER, :LIGHTTHATBURNSTHESKY].include?(info.id)
    dynamic ||= info.id == :TERABLAST &&
      (tera || (source.respond_to?(:tera?) && source.tera?))

    if dynamic
      return staged(user, :ATTACK) > staged(user, :SPECIAL_ATTACK)
    end

    return info.category == 0
  end

  # Used only inside the status-damage multiplier calculation.
  # The real battler's status is never changed.
  def self.without_frostbite(object)
    copy = object.dup
    copy.define_singleton_method(:status) { :NONE }
    return copy
  end

  #---------------------------------------------------------------------------
  # Actual battle: omit only the Frostbite damage penalty.
  #---------------------------------------------------------------------------
  module StatusHook
    def pbCalcDamageMults_Status(
      user, target, numTargets, type, baseDmg, multipliers
    )
      if KaitoPlayfulAggro.frostbite_immune?(user)
        user = KaitoPlayfulAggro.without_frostbite(user)
      end

      return super(user, target, numTargets, type, baseDmg, multipliers)
    end
  end

  # Native AI: omit the same penalty in its status multiplier calculation.
  module NativeStatus
    def calc_status_condition_mults(
      user, target, base_dmg, calc_type, is_critical, multipliers
    )
      if KaitoPlayfulAggro.frostbite_immune?(user)
        user = KaitoPlayfulAggro.without_frostbite(user)
      end

      return super(
        user, target, base_dmg, calc_type, is_critical, multipliers
      )
    end
  end

  # Advanced AI currently has no Frostbite damage penalty to cancel.
  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      return value * KaitoPlayfulAggro.factor(user, physical, move)
    end
  end

  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      damage = super
      return damage if !move || !user || !target
      return damage if !damage || damage <= 0 || !move.damagingMove?
      return damage if KaitoPlayfulAggro.fixed?(move)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination &&
         defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?(ExtendedTerrains::AdvancedScorerHooks) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return damage
      end

      tera = move.id == :TERABLAST && !!get_tera_type_for_move(user)
      physical = KaitoPlayfulAggro.physical?(user, move, tera)
      factor = KaitoPlayfulAggro.factor(user, physical, move)

      return damage if factor == 1.0
      return [(damage * factor).round, 1].max
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    unless Battle::Move.ancestors.include?(StatusHook)
      Battle::Move.prepend(StatusHook)
    end

    unless Battle::AI::AIMove.ancestors.include?(NativeStatus)
      Battle::AI::AIMove.prepend(NativeStatus)
    end

    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoPlayfulAggro.install!
      super(*args, &block)
    end
  end
end

# Actual battle + native AI: Special Attack bonus.
Battle::AbilityEffects::DamageCalcFromUser.add(:PLAYFULAGGRO,
  proc { |ability, user, target, move, mults, power, type|
    mults[:attack_multiplier] *= KaitoPlayfulAggro.factor(
      user, move.physicalMove?, move
    )
  }
)

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:PLAYFULAGGRO)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :PLAYFULAGGRO
end

unless Battle.singleton_class.ancestors.include?(
  KaitoPlayfulAggro::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoPlayfulAggro::ConstructionHook)
end

#===============================================================================
# FAIRY TALES
# Reduces incoming move damage by 25% while Misty Terrain is active.
#===============================================================================
module KaitoFairyTales
  ABILITY = :FAIRYTALES

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.battle_of(object)
    object = real(object)
    object ? object.instance_variable_get(:@battle) : nil
  end

  def self.active?(object, battle = nil)
    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return false if !user.hasActiveAbility?(ABILITY)
    else
      ordinary = user.respond_to?(:ability_id) &&
                 user.ability_id == ABILITY
      innate = user.respond_to?(:set_innate_limits) &&
               Array(user.set_innate_limits).include?(ABILITY)
      return false if !ordinary && !innate
    end

    battle ||= battle_of(user)
    return battle && battle.field.terrain == :Misty
  end

  def self.fixed?(move)
    return false if !move

    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)

    info = GameData::Move.try_get(move.id)
    return false if !info

    code = info.function_code
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return true if [
      "LowerTargetHPToUserHP",
      "UserFaintsFixedDamageUserHP",
      "MultiTurnAttackBideThenReturnDoubleDamage"
    ].include?(code)

    if Battle::Move.const_defined?(code, false)
      klass = Battle::Move.const_get(code, false)
      return true if klass.is_a?(Class) &&
                     klass <= Battle::Move::FixedDamageMove
    end

    return false
  end

  def self.ai_factor(user, target, move, battle = nil)
    return 1.0 if !active?(target, battle) || fixed?(move)
    return 1.0 if AdvancedAI::Utilities.ignores_ability?(
      user, move, target
    )

    return 0.75
  end

  # Advanced AI: shared damage estimator.
  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      battle = KaitoFairyTales.battle_of(target) ||
               KaitoFairyTales.battle_of(user)

      return value * KaitoFairyTales.ai_factor(
        user, target, move, battle
      )
    end
  end

  # Advanced AI: separate move damage estimator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      damage = super
      return damage if !move || !user || !target
      return damage if !damage || damage <= 0 || !move.damagingMove?
      return damage if KaitoFairyTales.fixed?(move)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination &&
         defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?(ExtendedTerrains::AdvancedScorerHooks) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return damage
      end

      factor = KaitoFairyTales.ai_factor(user, target, move, @battle)
      return damage if factor == 1.0

      return [(damage * factor).round, 1].max
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoFairyTales.install!
      super(*args, &block)
    end
  end
end

# Actual battle + native AI.
Battle::AbilityEffects::DamageCalcFromTarget.add(:FAIRYTALES,
  proc { |ability, user, target, move, mults, power, type|
    next if !KaitoFairyTales.active?(target)
    next if KaitoFairyTales.fixed?(move)

    mults[:final_damage_multiplier] *= 0.75
  }
)

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:FAIRYTALES)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :FAIRYTALES
end

unless Battle.singleton_class.ancestors.include?(
  KaitoFairyTales::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoFairyTales::ConstructionHook)
end

#===============================================================================
# DRAGON SLAYER
# Damage against Dragon-type targets x1.5.
# Incoming Dragon-type move damage x0.5.
#===============================================================================
module KaitoDragonSlayer
  ABILITY = :DRAGONSLAYER

  def self.real(object)
    object.respond_to?(:battler) ? object.battler : object
  end

  def self.active?(object)
    user = real(object)
    return false if !user || user.fainted?

    if user.respond_to?(:hasActiveAbility?)
      return user.hasActiveAbility?(ABILITY)
    end

    return true if user.respond_to?(:ability_id) &&
                   user.ability_id == ABILITY

    return user.respond_to?(:set_innate_limits) &&
           Array(user.set_innate_limits).include?(ABILITY)
  end

  def self.dragon?(object)
    target = real(object)
    return false if !target

    if target.respond_to?(:pbHasType?)
      return target.pbHasType?(:DRAGON)
    end

    return target.respond_to?(:types) && target.types.include?(:DRAGON)
  end

  def self.fixed?(move)
    return false if !move

    native = move.respond_to?(:move) ? move.move : move
    return true if native.is_a?(Battle::Move::FixedDamageMove)

    info = GameData::Move.try_get(move.id)
    return false if !info

    code = info.function_code
    return true if code.start_with?("FixedDamage", "OHKO", "Counter")
    return true if [
      "LowerTargetHPToUserHP",
      "UserFaintsFixedDamageUserHP",
      "MultiTurnAttackBideThenReturnDoubleDamage"
    ].include?(code)

    if Battle::Move.const_defined?(code, false)
      klass = Battle::Move.const_get(code, false)
      return true if klass.is_a?(Class) &&
                     klass <= Battle::Move::FixedDamageMove
    end

    return false
  end

  def self.offensive_factor(user, target)
    return active?(user) && dragon?(target) ? 1.5 : 1.0
  end

  def self.ai_factor(user, target, move, type)
    return 1.0 if fixed?(move)

    factor = offensive_factor(user, target)

    if type == :DRAGON && active?(target) &&
       !AdvancedAI::Utilities.ignores_ability?(user, move, target)
      factor *= 0.5
    end

    return factor
  end

  # Advanced AI: shared damage estimator.
  module CombatAI
    def ability_damage_modifier(
      user, target, type, physical, effectiveness,
      move = nil, physical_defense = physical
    )
      value = super
      return value * KaitoDragonSlayer.ai_factor(
        user, target, move, type
      )
    end
  end

  # Advanced AI: separate move damage estimator.
  module ScorerAI
    def calculate_rough_damage(move, user, target, override_bp = nil)
      damage = super
      return damage if !move || !user || !target
      return damage if !damage || damage <= 0 || !move.damagingMove?
      return damage if KaitoDragonSlayer.fixed?(move)

      # These terrain calculations already use the shared estimator.
      if @battle.field.terrain == :Pollination &&
         defined?(ExtendedTerrains::AdvancedScorerHooks) &&
         Battle::AI.ancestors.include?(ExtendedTerrains::AdvancedScorerHooks) &&
         [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
        return damage
      end

      type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
      if move.id == :TERABLAST
        tera_type = get_tera_type_for_move(user)
        type = tera_type if tera_type
      end

      factor = KaitoDragonSlayer.ai_factor(user, target, move, type)
      return damage if factor == 1.0

      return [(damage * factor).round, 1].max
    end
  end

  # Install after all plugin aliases have loaded.
  def self.install!
    if defined?(AdvancedAI::CombatUtilities) &&
       AdvancedAI::CombatUtilities.respond_to?(:ability_damage_modifier)
      singleton = AdvancedAI::CombatUtilities.singleton_class
      singleton.prepend(CombatAI) unless singleton.ancestors.include?(CombatAI)
    end

    if defined?(AdvancedAI) &&
       Battle::AI.method_defined?(:calculate_rough_damage) &&
       !Battle::AI.ancestors.include?(ScorerAI)
      Battle::AI.prepend(ScorerAI)
    end
  end

  module ConstructionHook
    def new(*args, &block)
      KaitoDragonSlayer.install!
      super(*args, &block)
    end
  end
end

# Actual battle + native AI: offensive effect.
Battle::AbilityEffects::DamageCalcFromUser.add(:DRAGONSLAYER,
  proc { |ability, user, target, move, mults, power, type|
    next if KaitoDragonSlayer.fixed?(move)

    mults[:final_damage_multiplier] *=
      KaitoDragonSlayer.offensive_factor(user, target)
  }
)

# Actual battle + native AI: defensive effect.
Battle::AbilityEffects::DamageCalcFromTarget.add(:DRAGONSLAYER,
  proc { |ability, user, target, move, mults, power, type|
    next if type != :DRAGON
    next if !KaitoDragonSlayer.active?(target)
    next if KaitoDragonSlayer.fixed?(move)

    mults[:final_damage_multiplier] *= 0.5
  }
)

Battle::AI::BASE_ABILITY_RATINGS[7] ||= []
unless Battle::AI::BASE_ABILITY_RATINGS[7].include?(:DRAGONSLAYER)
  Battle::AI::BASE_ABILITY_RATINGS[7] << :DRAGONSLAYER
end

unless Battle.singleton_class.ancestors.include?(
  KaitoDragonSlayer::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoDragonSlayer::ConstructionHook)
end

#===============================================================================
# DEEP WOUND
# Slicing hits have a 50% chance to inflict the existing Bleed condition.
#===============================================================================
module KaitoDeepWound
  ABILITY = :DEEPWOUND
  CHANCE  = 50

  def self.real(object)
    return object.battler if object.respond_to?(:battler)
    return object
  end

  def self.move_data(move)
    move = move.move if move.respond_to?(:move)
    return nil if !move || !move.respond_to?(:id)
    return GameData::Move.try_get(move.id)
  end

  def self.slicing?(move)
    data = move_data(move)
    return false if !data || data.category == 2
    return data.flags.any? { |flag| flag.to_s.downcase == "slicing" }
  end

  # Shared by actual effects and AI; never inflicts Bleed during scoring.
  def self.eligible?(user, target, move, battle)
    user   = real(user)
    target = real(target)
    return false if !user.is_a?(Battle::Battler)
    return false if !target.is_a?(Battle::Battler)
    return false if user.fainted? || target.fainted?
    return false if !user.hasActiveAbility?(ABILITY)
    return false if !target.opposes?(user.index)
    return false if !slicing?(move)
    return false if !target.respond_to?(:pbCanBleed?)
    return false if !target.respond_to?(:pbInflictBleed)
    return false if target.hasActiveItem?(:COVERTCLOAK)

    if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      return false
    end

    if defined?(KaitoShield) &&
       KaitoShield.respond_to?(:blocks_secondary?) &&
       KaitoShield.blocks_secondary?(target)
      return false
    end

    return target.pbCanBleed?(false)
  end

  def self.trigger(user, target, move, battle)
    return if !eligible?(user, target, move, battle)
    return if target.damageState.substitute
    return if target.damageState.calcDamage <= 0
    return if battle.pbRandom(100) >= CHANCE

    battle.pbShowAbilitySplash(user)
    begin
      target.pbInflictBleed
    ensure
      battle.pbHideAbilitySplash(user)
    end
  end

  # Expected hit count for AI only. Does not roll the battle's RNG.
  def self.expected_hits(move, user)
    data = move_data(move)
    return 1.0 if !data
    code = data.function_code

    if code.start_with?("HitTwoToFiveTimes")
      return 5.0 if user.hasActiveAbility?(:SKILLLINK)
      return 4.5 if user.hasActiveItem?(:LOADEDDICE)
      return 3.1
    end

    return 2.0 if code.start_with?("HitTwoTimes")
    return 3.0 if code.start_with?("HitThreeTimes")
    return 1.0
  end

  def self.ai_bonus(user, target, move, battle)
    user   = real(user)
    target = real(target)
    return 0 if !eligible?(user, target, move, battle)

    # Conservative scoring while a Substitute or Shield remains.
    return 0 if target.effects[PBEffects::Substitute] > 0

    if target.respond_to?(:pbHasShield?) && target.pbHasShield?
      return 0
    end

    hits = expected_hits(move, user)
    chance = 1.0 - ((1.0 - CHANCE / 100.0) ** hits)

    # Bleed blocks healing even when indirect damage is prevented.
    value = target.takesIndirectDamage? ? 40 : 20
    return (value * chance).round
  end

  # Advanced AI may call the native scoring path internally.
  # The depth guard prevents adding the same bonus twice.
  module AdvancedScoreHook
    def score_move_advanced(move, user, target, skill)
      previous_depth = @kaito_deep_wound_depth || 0
      @kaito_deep_wound_depth = previous_depth + 1

      begin
        score = super
        if previous_depth == 0 && score.is_a?(Numeric) && score > 0
          score += KaitoDeepWound.ai_bonus(
            user, target, move, @battle
          )
        end
        return score
      ensure
        @kaito_deep_wound_depth = previous_depth
      end
    end
  end

  def self.install_ai!
    return if !defined?(Battle::AI)
    return if !Battle::AI.method_defined?(:score_move_advanced)
    return if Battle::AI.ancestors.include?(AdvancedScoreHook)
    Battle::AI.prepend(AdvancedScoreHook)
  end

  # Install after plugin loading to avoid alias/prepend recursion.
  module ConstructionHook
    def new(*args, &block)
      KaitoDeepWound.install_ai!
      return super
    end
  end
end

#===============================================================================
# Actual effect: once per damaging hit, independently for each opposing target.
#===============================================================================
Battle::AbilityEffects::OnDealingHit.add(:DEEPWOUND,
  proc { |ability, user, target, move, battle|
    KaitoDeepWound.trigger(user, target, move, battle)
  }
)

#===============================================================================
# Native AI
#===============================================================================
Battle::AI::Handlers::GeneralMoveAgainstTargetScore.add(:deep_wound,
  proc { |score, move, user, target, ai, battle|
    depth = ai.instance_variable_get(:@kaito_deep_wound_depth).to_i
    next score if depth > 0
    next score if !move.damagingMove?

    score += KaitoDeepWound.ai_bonus(user, target, move, battle)
    next score
  }
)

Battle::AI::Handlers::AbilityRanking.add(:DEEPWOUND,
  proc { |ability, score, battler, ai|
    useful = battler.check_for_move do |move|
      KaitoDeepWound.slicing?(move)
    end
    next useful ? 7 : 0
  }
)

unless Battle.singleton_class.ancestors.include?(
  KaitoDeepWound::ConstructionHook
)
  Battle.singleton_class.prepend(KaitoDeepWound::ConstructionHook)
end