#===============================================================================
# Advanced AI System - Special Sacrifice & Utility Moves
# Handles Pain Split, Healing Wish, Final Gambit, Memento, etc.
#===============================================================================

class Battle::AI
  # ============================================================================
  # SPECIAL MOVE EVALUATION
  # ============================================================================
  
  alias_method :special_moves_pbRegisterMove, :pbRegisterMove unless method_defined?(:special_moves_pbRegisterMove) || private_method_defined?(:special_moves_pbRegisterMove)
  def pbRegisterMove(user, move)
    score = special_moves_pbRegisterMove(user, move)
    
    return score unless user && move
    
    case move.id
    when :PAINSPLIT
      score += evaluate_pain_split(user, move, @_resolved_target)
    when :HEALINGWISH, :LUNARDANCE
      score += evaluate_healing_wish(user, move)
    when :FINALGAMBIT
      score += evaluate_final_gambit(user, move, @_resolved_target)
    when :MEMENTO, :MISTYEXPLOSION
      score += evaluate_sacrifice_moves(user, move, @_resolved_target)
    when :RAPIDSPIN, :DEFOG
      score += evaluate_hazard_removal(user, move)
    when :ENDEAVOR
      score += evaluate_endeavor(user, move, @_resolved_target)
    end
    
    return score
  end
  
  # ============================================================================
  # PAIN SPLIT EVALUATION
  # ============================================================================
  
  def evaluate_pain_split(user, move, resolved_target = nil)
    score = 0
    
    targets = resolved_target ? [resolved_target] : @battle.allOtherSideBattlers(user.index)
    targets = targets.select { |t| t && !t.fainted? && t.opposes?(user) }
    return 0 if targets.empty?
    
    best = targets.map { |target|
      next -90 if target.effects[PBEffects::Substitute] > 0 && !move.ignoresSubstitute?(user)
      tscore = 0
      
      # Pain Split averages RAW HP values (not percentages!)
      average_hp = (user.hp + target.hp) / 2
      user_gain = [average_hp, user.totalhp].min - user.hp
      user_gain_pct = user_gain / user.totalhp.to_f
      user_hp_percent = user.hp.to_f / user.totalhp
      
      # Value scales with recovered HP.
      if user_gain_pct > 0.30 && user_hp_percent < 0.35
        tscore += 80
        AdvancedAI.log("  Pain Split (#{user.hp}/#{user.totalhp} vs #{target.hp}/#{target.totalhp}): +80 (huge heal)", "Special")
        
        if user_hp_percent < 0.2
          tscore += 40
          AdvancedAI.log("  Emergency heal: +40", "Special")
        end
      elsif user_gain_pct > 0.15
        # MEDIUM VALUE
        tscore += 50
        AdvancedAI.log("  Pain Split: +50 (good heal, +#{(user_gain_pct * 100).to_i}% HP)", "Special")
      elsif user_gain_pct <= 0
        # BAD: We lose HP or gain nothing
        tscore -= 40
        AdvancedAI.log("  Pain Split: -40 (we lose HP)", "Special")
      else
        # Minimal benefit
        tscore += 10
        AdvancedAI.log("  Pain Split: +10 (slight benefit)", "Special")
      end
      
      # BONUS: High max HP target (more raw HP to average from)
      if target.totalhp > user.totalhp * 1.3
        tscore += 20
        AdvancedAI.log("  High HP target: +20", "Special")
      end
      
      tscore
    }.max || 0
    
    return best
  end
  
  # ============================================================================
  # HEALING WISH / LUNAR DANCE EVALUATION
  # ============================================================================
  
  def evaluate_healing_wish(user, move)
    score = 0
    
    # User faints to fully heal next Pokemon
    # Only use if:
    # 1. We're about to die anyway
    # 2. We have a valuable teammate to heal
    
    user_hp_percent = user.hp.to_f / user.totalhp
    
    # Don't sacrifice if healthy
    if user_hp_percent > 0.4
      AdvancedAI.log("  #{move.name}: -70 (too healthy to sacrifice)", "Special")
      return -70
    end
    
    party = []
    @battle.eachInTeamFromBattlerIndex(user.index) { |pkmn, i| party << pkmn }
    active = @battle.allSameSideBattlers(user.index).map { |b| b.pokemon }
    reserves = party.reject { |p| !p || p.fainted? || p.egg? || active.include?(p) }
    valuable_teammates = 0
    injured_sweepers = 0
    depleted_pp = false
    
    reserves.each do |pkmn|
      
      depleted_pp ||= pkmn.moves.any? { |m| m.pp < m.total_pp }
      hp_percent = pkmn.hp.to_f / pkmn.totalhp
      
      # Valuable if injured and has high stats
      if hp_percent < 0.6 && (pkmn.attack > 100 || pkmn.spatk > 100)
        injured_sweepers += 1
      end
      
      # Valuable if status'd â€” both Healing Wish (Gen 5+) and Lunar Dance cure status
      if pkmn.status != :NONE
        valuable_teammates += 1
      end
    end
    
    if injured_sweepers > 0
      score += injured_sweepers * 50
      AdvancedAI.log("  #{move.name}: +#{injured_sweepers * 50} (heal sweeper)", "Special")
      
      # Last Pokemon standing
      alive_count = party.count { |p| p && !p.egg? && !p.fainted? }
      if alive_count == 2 && user_hp_percent < 0.25
        score += 60
        AdvancedAI.log("  Last hope sacrifice: +60", "Special")
      end
    elsif valuable_teammates == 0 && !(move.id == :LUNARDANCE && depleted_pp)
      # No good targets
      score -= 50
      AdvancedAI.log("  #{move.name}: -50 (no valuable teammates)", "Special")
    end
    
    # Both Healing Wish and Lunar Dance cure status (Gen 5+)
    if valuable_teammates > 0
      score += 30
      AdvancedAI.log("  #{move.name} cures status: +30", "Special")
    end
    
    # Lunar Dance extra: also fully restores PP
    if move.id == :LUNARDANCE && depleted_pp
      score += 10
      AdvancedAI.log("  Lunar Dance restores PP: +10", "Special")
    end
    
    return score
  end
  
  # ============================================================================
  # FINAL GAMBIT EVALUATION
  # ============================================================================
  
  def evaluate_final_gambit(user, move, resolved_target = nil)
    score = 0
    
    targets = resolved_target ? [resolved_target] : @battle.allOtherSideBattlers(user.index)
    targets = targets.select { |t| t && !t.fainted? && t.opposes?(user) }
    return 0 if targets.empty?
    
    best = targets.map { |target|
      tscore = 0
      
      # Final Gambit: Deals damage equal to user's current HP, user faints
      next -90 if AdvancedAI::CombatUtilities.estimate_damage(user, move, target) <= 0
      next -90 if target.effects[PBEffects::Substitute] > 0 && !move.ignoresSubstitute?(user)
      damage = user.hp
      target_hp = target.hp
      
      # BEST CASE: KO high-value target
      bypass = AdvancedAI::Utilities.ignores_ability?(user, move, target)
      survives = target.effects[PBEffects::Endure] ||
                 (target.hp == target.totalhp && (target.hasActiveItem?(:FOCUSSASH) ||
                  (target.hasActiveAbility?(:STURDY) && !bypass)))
      if damage >= target_hp && !survives
        tscore += 100
        AdvancedAI.log("  Final Gambit: +100 (KOs target)", "Special")
        
        # BONUS: Target is a sweeper
        if target.stages.values.sum >= 2
          tscore += 50
          AdvancedAI.log("  KOs boosted sweeper: +50", "Special")
        end
        
        # BONUS: Target is last Pokemon
        enemy_count = @battle.pbParty(target.index).count { |p| p && !p.egg? && !p.fainted? }
        if enemy_count == 1
          tscore += 80
          AdvancedAI.log("  KOs last Pokemon: +80 (wins game!)", "Special")
        end
      else
        # Doesn't KO - check if worth it
        damage_percent = damage.to_f / target.totalhp
        
        if damage_percent > 0.6
          tscore += 40
          AdvancedAI.log("  Final Gambit: +40 (big damage)", "Special")
        elsif damage_percent > 0.4
          tscore += 20
          AdvancedAI.log("  Final Gambit: +20 (decent damage)", "Special")
        else
          tscore -= 60
          AdvancedAI.log("  Final Gambit: -60 (waste)", "Special")
        end
      end
      
      # PENALTY: We're valuable
      user_hp_percent = user.hp.to_f / user.totalhp
      if user_hp_percent > 0.5
        tscore -= 50
        AdvancedAI.log("  Too healthy: -50", "Special")
      end
      
      tscore
    }.max || 0
    
    return best
  end
  
  # ============================================================================
  # SACRIFICE MOVES (Memento, Misty Explosion, etc.)
  # ============================================================================
  
  def evaluate_sacrifice_moves(user, move, resolved_target = nil)
    score = 0
    user_hp_percent = user.hp.to_f / user.totalhp
    
    # Memento: -2 Atk/SpAtk to target, user faints
    # Misty Explosion: user faints after dealing damage.
    
    if move.id == :MEMENTO
      targets = resolved_target ? [resolved_target] : @battle.allOtherSideBattlers(user.index)
      targets = targets.select { |t| t && !t.fainted? && t.opposes?(user) }
      
      best = targets.map { |target|
        tscore = 0
        
        preview = @battle.clone
        preview.moldBreaker = AdvancedAI::Utilities.ignores_ability?(user, move, target)
        probe = target.clone
        probe.instance_variable_set(:@battle, preview)
        if target.hasActiveAbility?([:DEFIANT, :COMPETITIVE]) ||
           (!preview.moldBreaker && target.hasActiveAbility?([:CONTRARY, :MIRRORARMOR]))
          next -90
        end
        next -90 unless [:ATTACK, :SPECIAL_ATTACK].any? { |stat| probe.pbCanLowerStatStage?(stat, user, move) }

        # Cripple a setup sweeper.
        if target.stages[:ATTACK] >= 1 || target.stages[:SPECIAL_ATTACK] >= 1
          tscore += 70
          AdvancedAI.log("  Memento vs boosted: +70 (cripple)", "Special")
        elsif target.attack > 120 || target.spatk > 120
          tscore += 50
          AdvancedAI.log("  Memento vs strong: +50", "Special")
        else
          tscore += 20
          AdvancedAI.log("  Memento: +20", "Special")
        end
        
        tscore
      }.max || 0
      
      score += best
      
      # Only if we're dying anyway
      if user_hp_percent > 0.3
        score -= 60
        AdvancedAI.log("  Too healthy to Memento: -60", "Special")
      end
    end
    
    if move.id == :MISTYEXPLOSION
      return -90 if @battle.pbCheckGlobalAbility(:DAMP) && !AdvancedAI::Utilities.ignores_ability?(user, move)
      # Native Misty Terrain bonus: 1.5x.
      if @battle.field.terrain == :Misty
        score += 40
        AdvancedAI.log("  Misty Explosion (terrain): +40", "Special")
      end
    end
    
    return score
  end
  
  # ============================================================================
  # HAZARD REMOVAL (Rapid Spin, Defog)
  # ============================================================================
  
  def aai_revival_candidates(index, party = nil)
    party ||= @battle.pbParty(index)
    first, last = @battle.pbTeamIndexRangeFromBattlerIndex(index)
    (first...last).select { |i| party[i] && !party[i].egg? && party[i].fainted? }
  end

  def aai_secondary_poison_useful?(user, move, target)
    user = user.battler if user.respond_to?(:battler)
    move = move.move if move.respond_to?(:move)
    target = target.battler if target.respond_to?(:battler)
    return false if user.hasActiveAbility?(:SHEERFORCE)
    return false if target.effects[PBEffects::Substitute] > 0 && !move.ignoresSubstitute?(user)
    return false unless AdvancedAI::WinConditions.poison_damage_useful?(@battle, target)
    preview = @battle.clone
    battlers = @battle.battlers.map do |b|
      next nil unless b
      copy = b.clone
      copy.instance_variable_set(:@battle, preview)
      copy.instance_variable_set(:@effects, b.effects.dup)
      copy.instance_variable_set(:@stages, b.stages.dup)
      copy
    end
    preview.instance_variable_set(:@battlers, battlers)
    user = battlers[user.index]
    target = battlers[target.index]
    native = Battle::Move.from_pokemon_move(preview, Pokemon::Move.new(move.id))
    preview.moldBreaker = user.hasMoldBreaker? && !target.hasActiveItem?(:ABILITYSHIELD)
    native.pbAdditionalEffectChance(user, target) > 0 && target.pbCanPoison?(user, false, native)
  end

  def aai_self_stage_delta(user, move, stat)
    user = user.battler if user.respond_to?(:battler)
    move = move.move if move.respond_to?(:move)
    preview = @battle.clone
    preview.moldBreaker = false
    copy = user.clone
    copy.instance_variable_set(:@battle, preview)
    copy.instance_variable_set(:@stages, user.stages.dup)
    copy.instance_variable_set(:@effects, user.effects.dup)
    return 0 unless copy.pbCanRaiseStatStage?(stat, copy, move)
    before = copy.stages[stat]
    copy.pbRaiseStatStageBasic(stat, 1)
    copy.stages[stat] - before
  end

  def aai_known_retaliation_ko?(user, move, target)
    user = user.battler if user.respond_to?(:battler)
    target = target.battler if target.respond_to?(:battler)
    move = move.move if move.respond_to?(:move)
    return false unless user.takesIndirectDamage?
    contact = move.pbContactMove?(user) && user.affectedByContactEffect?
    return false if target.effects[PBEffects::Substitute] > 0 && !move.ignoresSubstitute?(user)
    hits = []
    hits << [user.totalhp / 8, 1].max if contact && target.hasActiveAbility?([:ROUGHSKIN, :IRONBARBS])
    if target.hasActiveAbility?([:AFTERMATH, :INNARDSOUT]) && AdvancedAI::EndgameScenarios.can_ko?(user, target, move)
      if target.hasActiveAbility?(:INNARDSOUT)
        hits << target.hp unless user.dummy
      elsif contact
        mold_breaker = user.hasMoldBreaker? && !target.hasActiveItem?(:ABILITYSHIELD)
        hits << [user.totalhp / 4, 1].max if mold_breaker || !@battle.pbCheckGlobalAbility(:DAMP)
      end
    end
    hits << [user.totalhp / 6, 1].max if contact && target.hasActiveItem?(:ROCKYHELMET)
    return false if hits.empty?
    preview = @battle.clone
    copies = @battle.battlers.map do |b|
      next nil unless b
      copy = b.clone
      copy.instance_variable_set(:@pokemon, b.pokemon.clone) if b.pokemon
      copy.instance_variable_set(:@battle, preview)
      copy.instance_variable_set(:@effects, b.effects.dup)
      copy.instance_variable_set(:@stages, b.stages.dup)
      copy
    end
    preview.instance_variable_set(:@battlers, copies)
    probe = copies[user.index]
    hits.each do |damage|
      probe.hp = [probe.hp - damage, 0].max
      return true if probe.fainted?
      heal_switch_entry_item(probe)
    end
    false
  end

  def aai_removal_target_state(user, move, target)
    user = user.battler if user.respond_to?(:battler)
    move = move.move if move.respond_to?(:move)
    target = target.battler if target.respond_to?(:battler)
    return :blocked unless target && !target.fainted? && !user.fainted?
    index = user.moves.index { |m| m.id == move.id }
    return :blocked if index && !@battle.pbCanChooseMove?(user.index, index, false)
    return :blocked if AdvancedAI::Utilities.counter_priority_blocked?(@battle, move, user, target)
    return :blocked if AdvancedAI::Utilities.counter_shield_blocked?(@battle, move, user, target)
    if move.damagingMove?
      return :blocked if move.id == :RAPIDSPIN && aai_known_retaliation_ko?(user, move, target)
      return AdvancedAI::CombatUtilities.estimate_damage(user, move, target) > 0 ? :hit : :blocked
    end
    preview = @battle.clone
    native = Battle::Move.from_pokemon_move(preview, Pokemon::Move.new(move.id))
    preview.moldBreaker = (user.hasMoldBreaker? || user.hasActiveAbility?(:MYCELIUMMIGHT)) && !target.hasActiveItem?(:ABILITYSHIELD)
    return :blocked if native.pbImmunityByAbility(user, target, false)
    return :reflected if native.canMagicCoat? && !target.semiInvulnerable? &&
      (target.effects[PBEffects::MagicCoat] ||
       (target.hasActiveAbility?(:MAGICBOUNCE) && !preview.moldBreaker && !target.effects[PBEffects::MagicBounce]))
    return :blocked if native.pbFailsAgainstTarget?(user, target, false)
    :hit
  end

  def evaluate_hazard_removal(user, move, resolved_target = nil)
    user = user.battler if user.respond_to?(:battler)
    move = move.move if move.respond_to?(:move)
    resolved_target ||= @_resolved_target
    targets = resolved_target ? [resolved_target] : @battle.allOtherSideBattlers(user.index)
    scores = targets.map do |target|
      state = aai_removal_target_state(user, move, target)
      next 0 if state == :blocked
      score = 0
      our_side = user.pbOwnSide
      opp_side = user.pbOpposingSide
      clears_ours = move.id == :RAPIDSPIN || Settings::MECHANICS_GENERATION >= 6 || state == :reflected
      if clears_ours
        hazards = (our_side.effects[PBEffects::StealthRock] ? 1 : 0) +
                  our_side.effects[PBEffects::Spikes] + our_side.effects[PBEffects::ToxicSpikes] +
                  (our_side.effects[PBEffects::StickyWeb] ? 1 : 0)
        score += hazards * 30
        if our_side.effects[PBEffects::StealthRock]
          score += 25
          weak = @battle.pbParty(user.index & 1).count do |p|
            p && !p.egg? && !p.fainted? && Effectiveness.super_effective?(Effectiveness.calculate(:ROCK, *p.types))
          end
          score += weak * 15
        end
      end
      if move.id == :RAPIDSPIN
        score += 30 if user.effects[PBEffects::LeechSeed] >= 0
        score += 30 if user.effects[PBEffects::Trapping] > 0
      elsif move.id == :DEFOG
        cleared_side = state == :reflected ? our_side : target.pbOwnSide
        if [:Reflect, :LightScreen, :AuroraVeil].any? { |effect| cleared_side.effects[PBEffects.const_get(effect)] > 0 }
          score += state == :reflected ? -40 : 40
        end
        if Settings::MECHANICS_GENERATION >= 6 || state != :reflected
          hazards = (opp_side.effects[PBEffects::StealthRock] ? 1 : 0) +
                    opp_side.effects[PBEffects::Spikes] + opp_side.effects[PBEffects::ToxicSpikes] +
                    (opp_side.effects[PBEffects::StickyWeb] ? 1 : 0)
          score -= hazards * 15
        end
      end
      score
    end
    scores.max || 0
  end

  # ============================================================================
  # ENDEAVOR EVALUATION
  # ============================================================================
  
  def evaluate_endeavor(user, move, resolved_target = nil)
    score = 0
    
    targets = resolved_target ? [resolved_target] : @battle.allOtherSideBattlers(user.index)
    targets = targets.select { |t| t && !t.fainted? && t.opposes?(user) }
    return 0 if targets.empty?
    
    # Endeavor: Set target HP to user's current HP
    # Only good if we're low HP
    user_hp_percent = user.hp.to_f / user.totalhp
    
    if user_hp_percent > 0.5
      AdvancedAI.log("  Endeavor: -60 (too healthy)", "Special")
      return -60
    end
    
    best = targets.map { |target|
      next -90 if AdvancedAI::CombatUtilities.estimate_damage(user, move, target) <= 0
      next -90 if target.effects[PBEffects::Substitute] > 0 && !move.ignoresSubstitute?(user)
      tscore = 0
      user_hp = user.hp
      target_hp = target.hp
      
      # Favor high-HP targets while the user is low.
      if target_hp > user_hp * 2
        damage = target_hp - user_hp
        damage_percent = damage.to_f / target.totalhp
        
        tscore += 60
        AdvancedAI.log("  Endeavor: +60 (#{(damage_percent * 100).to_i}% damage)", "Special")
        
        # COMBO: Follow up with priority move
        priority_moves = user.moves.each_with_index.select do |m, i|
          m && m.damagingMove? && @battle.pbCanChooseMove?(user.index, i, false) &&
            AdvancedAI::PriorityTiers.get_priority_tier(m, user) > 0 &&
            !(@battle.field.terrain == :Psychic && target.affectedByTerrain?) &&
            (AdvancedAI::Utilities.ignores_ability?(user, m, target) ||
             @battle.allSameSideBattlers(target.index).none? { |b| b.hasActiveAbility?([:DAZZLING, :QUEENLYMAJESTY, :ARMORTAIL]) }) &&
            AdvancedAI::CombatUtilities.estimate_damage(user, m, target) > 0
        end
        if priority_moves.any?
          tscore += 40
          AdvancedAI.log("  Have priority follow-up: +40", "Special")
        end
      else
        tscore -= 40
        AdvancedAI.log("  Endeavor: -40 (target too low)", "Special")
      end
      
      tscore
    }.max || 0
    
    return best
  end
end

module AdvancedAI::RevivalOwnerSelection
  def choose_best_revive_pokemon(index, party)
    aai_revival_candidates(index, party).max_by { |i| rate_replacement_pokemon(index, party[i], 100) } || -1
  end
end
Battle::AI.prepend(AdvancedAI::RevivalOwnerSelection) unless Battle::AI.ancestors.include?(AdvancedAI::RevivalOwnerSelection)

AdvancedAI.log("Special Sacrifice & Utility Moves loaded", "Core")
AdvancedAI.log("  - Pain Split (HP averaging)", "Special")
AdvancedAI.log("  - Healing Wish/Lunar Dance (sacrifice heal)", "Special")
AdvancedAI.log("  - Final Gambit (sacrifice damage)", "Special")
AdvancedAI.log("  - Memento/Misty Explosion", "Special")
AdvancedAI.log("  - Rapid Spin/Defog (hazard removal)", "Special")
AdvancedAI.log("  - Endeavor (HP matching)", "Special")
