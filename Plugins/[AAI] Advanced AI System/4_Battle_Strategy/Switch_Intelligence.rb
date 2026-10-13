#===============================================================================
# Advanced AI System - Switch Intelligence
# Intelligent Switching Decisions with Type Matchup and Momentum Control
#===============================================================================

class Battle::AI
  #=============================================================================
  # SWITCH ANALYZER - Evaluates switch opportunities
  #=============================================================================
  
  # Helper method to safely get battler index from either Battler or Integer
  def get_battler_index(battler_or_index)
    return battler_or_index.to_i if battler_or_index.is_a?(Integer)
    return battler_or_index.index if battler_or_index.respond_to?(:index)
    battler_or_index.to_i
  end
  
  def aai_reserved_party_index(user)
    return -1 unless AdvancedAI::RESPECT_RESERVE_LAST_POKEMON
    index = get_battler_index(user)
    side = index & 1
    owner = @battle.pbGetOwnerIndexFromBattlerIndex(index)
    trainer = @trainers && @trainers[side] && @trainers[side][owner]
    unless trainer
      native_trainer = @battle.pbGetOwnerFromBattlerIndex(index)
      return -1 unless native_trainer
      trainer = Battle::AI::AITrainer.new(self, side, owner, native_trainer)
    end
    return -1 unless trainer.has_skill_flag?("ReserveLastPokemon")
    starts = @battle.pbPartyStarts(index)
    (starts[owner + 1] || @battle.pbParty(index).length) - 1
  end

  def aai_filter_reserved_switches(candidates, user, forced_switch = false)
    reserved = aai_reserved_party_index(user)
    ace = candidates.find { |entry| entry[2] == reserved } if reserved >= 0
    return candidates unless ace
    others = candidates.reject { |entry| entry[2] == reserved }
    if others.empty?
      return (forced_switch || user.fainted?) ? candidates : []
    end
    return others if AdvancedAI::RESERVE_LAST_POKEMON_STRICT
    candidates.each { |entry| entry[1] ||= evaluate_switch_matchup_detailed(entry[0], user) }
    return candidates if ace[1] > others.map { |entry| entry[1] }.max + 50
    others
  end

  def aai_switch_candidate_legal?(user, index, forced_switch = false)
    return @battle.pbCanSwitchIn?(user.index, index) if forced_switch || user.fainted?
    @battle.pbCanSwitch?(user.index, index)
  end

  def aai_switch_move_available?(battler, index)
    move = battler.moves[index]
    move && move.damagingMove? && @battle.pbCanChooseMove?(battler.index, index, false)
  end

  def aai_switch_ability_immunity?(pkmn, current_user, attacker, move, move_type)
    absorbers = AdvancedAI::Utilities::TYPE_ABSORBING_ABILITIES[move_type]
    return false unless absorbers && absorbers.any? { |ability, _| Array(ability).include?(pkmn.ability_id) }
    probe = switch_hazard_preview(pkmn, get_battler_index(current_user))
    projected_attacker = probe.battle.battlers[attacker.index]
    projected_move = move.clone
    projected_move.instance_variable_set(:@battle, probe.battle)
    !!AdvancedAI::Utilities.type_absorbing_immunity?(projected_attacker, probe, move_type, projected_move)
  end

  # Initialize caches
  def initialize_switch_caches
    @type_effectiveness_cache ||= {}
    @setup_move_cache ||= {}
  end
  
  # Analyzes if AI should switch (advanced version)
  def should_switch_advanced?(user, skill = 100)
    return false unless user && !user.fainted?
    return false unless @battle.pbParty(user.index).each_index.any? { |i| @battle.pbCanSwitch?(user.index, i) }
    return false unless AdvancedAI.feature_enabled?(:core, skill)
    
    # Initialize caches
    initialize_switch_caches
    
    # Initialize switch analysis cache
    @switch_analyzer[user.index] ||= {}
    cache = @switch_analyzer[user.index]
    
    # Calculate Switch Score
    switch_score = calculate_switch_score(user, skill)
    
    # Cache result
    cache[:last_score] = switch_score
    cache[:last_turn] = @battle.turnCount
    
    AdvancedAI.log("Switch score for #{user.pbThis}: #{switch_score}", "Switch")
    
    # Thresholds based on skill
    tier = AdvancedAI.get_ai_tier(skill)
    threshold = AdvancedAI::SWITCH_THRESHOLDS[tier] || 50
    personality = AdvancedAI.get_personality(@battle, user.index)
    neutral_threshold = AdvancedAI.get_personality_switch_threshold(:balanced)
    personality_threshold = AdvancedAI.get_personality_switch_threshold(personality)
    threshold = (threshold + personality_threshold - neutral_threshold).clamp(0, 100)
    would_switch = switch_score >= threshold

    # Sacrifice-switch veto: even when the score says "switch", never give up a
    # voluntary switch if every legal replacement would faint on the switch-in.
    # Staying in (and acting) always beats feeding a teammate to a free OHKO.
    # This is the Garganacl -> Aerodactyl-into-Meteor-Mash scenario.
    if would_switch && no_safe_switch_in?(user, skill)
      AdvancedAI.log("Switch vetoed for #{user.pbThis}: no safe switch-in (every replacement faints on entry)", "Switch")
      return false
    end

    return would_switch
  end
  
  private # All methods below are private helper methods
  
  # Calculates Switch Score (0-100+)
  def calculate_switch_score(user, skill)
    dbg = AdvancedAI::DEBUG_SWITCH_INTELLIGENCE
    if dbg
      echoln "  ┌─────────────────────────────────────┐"
      echoln "  │ SWITCH SCORE CALCULATION            │"
      echoln "  └─────────────────────────────────────┘"
    end
    score = 0
    
    # 1. TYPE MATCHUP ANALYSIS (0-40 Points)
    type_score = evaluate_type_disadvantage(user, skill)
    score += type_score
    echoln("  [1/8] Type Disadvantage: +#{type_score}") if dbg && type_score > 0
    
    # 2. HP & STATUS ANALYSIS (0-30 Points)
    survival_score = evaluate_survival_concerns(user, skill)
    score += survival_score
    echoln("  [2/8] Survival Concerns: +#{survival_score}") if dbg && survival_score > 0
    
    # 3. STAT STAGE ANALYSIS (0-25 Points)
    stat_score = evaluate_stat_stages(user, skill)
    score += stat_score
    echoln("  [3/8] Stat Stage Loss: +#{stat_score}") if dbg && stat_score > 0
    
    # 4. BETTER OPTION AVAILABLE (0-35 Points)
    better_score = evaluate_better_options(user, skill)
    score += better_score
    echoln("  [4/8] Better Options: +#{better_score}") if dbg && better_score > 0
    
    # 5. MOMENTUM CONTROL (0-20 Points)
    if AdvancedAI.get_setting(:momentum_control) > 0
      momentum_score = evaluate_momentum(user, skill)
      score += momentum_score
      echoln("  [5/8] Momentum Control: +#{momentum_score}") if dbg && momentum_score > 0
    end
    
    # 6. PREDICTION BONUS (0-15 Points)
    if skill >= 85 && AdvancedAI.tier_feature(skill, :switch_prediction) && AdvancedAI.get_setting(:switch_prediction) > 0
      prediction_score = evaluate_prediction_advantage(user, skill)
      score += prediction_score
      echoln("  [6/8] Prediction: +#{prediction_score}") if dbg && prediction_score > 0
    end
    
    # 7. PENALTY: Losing Momentum (-20 Points)
    if user_has_advantage?(user)
      score -= 20
      echoln("  [7/12] Has Advantage (malus): -20") if dbg
    end
    
    # 8. BONUS: Pivot Move Available (+25 Points)
    # Prefer using pivot moves (U-turn, Volt Switch, etc.) over hard switches
    pivot_bonus = AdvancedAI.tier_feature(skill, :pivot_preference) ? evaluate_pivot_move_option(user, skill) : 0
    if pivot_bonus > 0
      score -= pivot_bonus  # REDUCE switch score if pivot available (prefer pivot over switch!)
      echoln("  [8/12] Pivot Move Available (reduces hard switch need): -#{pivot_bonus}") if dbg
    end
    
    # 9. PENALTY: Wasting Setup (-30 Points)
    if user.stages.values.any? { |stage| stage > 0 }
      positive_boosts = user.stages.values.select { |s| s > 0 }.sum
      malus = [positive_boosts * 10, 30].min
      score -= malus
      echoln("  [9/12] Wasting Setup +#{positive_boosts} (malus): -#{malus}") if dbg
    end
    
    # 10. PENALTY: Switching too soon (-40 Points)
    if user.turnCount < 2
      score -= 40
      echoln("  [10/12] Just Switched In (malus): -40") if dbg
    end
    
    # 11. PENALTY: No better option (-30, or more when the matchup is inescapable)
    # If better_score is 0, it means either no switches exist OR the best switch isn't significantly better.
    # When the best reachable switch is ITSELF a losing matchup (@best_switch_matchup < 0),
    # the type-disadvantage / survival pressure inflating this score can't actually
    # be escaped — every benched mon is disadvantaged too, so switching only feeds
    # the incoming mon a free hit (the revolving-door bug). Scale the penalty up to
    # also cancel the unescapable type-disadvantage points so the AI stays in and
    # acts instead of sacrificing its team one Pokemon at a time.
    if better_score <= 0
      if @best_switch_matchup && @best_switch_matchup < 0
        penalty = 30 + [type_score, 0].max
        score -= penalty
        echoln("  [11/12] No Better Option — inescapable matchup (malus): -#{penalty}") if dbg
      else
        score -= 30
        echoln("  [11/12] No Better Option (malus): -30") if dbg
      end
    end
    
    # 12. PENALTY: Can KO Opponent (-60 Points)
    if can_ko_opponent?(user)
      score -= 60
      echoln("  [12/12] Can Secure KO (malus): -60") if dbg
    end
    
    # 13. PENALTY: Stall Gameplan Active (-25 to -50 Points)
    # Stall mons should NOT switch when their passive damage is ticking
    if AdvancedAI.has_stall_moveset?(user)
      stall_penalty = 0
      @battle.allOtherSideBattlers(user.index).each do |target|
        next unless target && !target.fainted?
        leech_seed_val = (target.effects[PBEffects::LeechSeed] rescue -1)
        if target.status == :POISON && target.statusCount > 0  # Toxic
          stall_penalty += 20
        elsif target.poisoned?
          stall_penalty += 15
        end
        stall_penalty += 10 if target.burned?
        stall_penalty += 15 if leech_seed_val.is_a?(Numeric) && leech_seed_val >= 0
      end
      if stall_penalty > 0
        stall_penalty = [stall_penalty, 50].min
        score -= stall_penalty
        echoln("  [13/13] Stall Gameplan Active (malus): -#{stall_penalty}") if dbg
      end
      
      # Additional: stall mons with recovery at decent HP should stay
      hp_percent = user.hp.to_f / user.totalhp
      has_recovery = user.moves.any? do |m|
        next false unless m
        AdvancedAI.healing_move?(m.id)
      end
      if has_recovery && hp_percent > 0.35
        score -= 20
        echoln("  [13/13] Stall Mon w/Recovery (malus): -20") if dbg
      end
    end
    
    if dbg
      echoln "  ─────────────────────────────────────"
      echoln "  TOTAL SWITCH SCORE: #{score}"
      
      # Show Threshold
      tier = AdvancedAI.get_ai_tier(skill)
      threshold = AdvancedAI::SWITCH_THRESHOLDS[tier] || 50
      echoln "  Threshold (#{tier}): #{threshold}"
      echoln "  Decision: #{score >= threshold ? 'SWITCH' : 'STAY'}"
      
      # === USER-FRIENDLY SWITCH SUMMARY ===
      # Produces the [Switch] lines matching the showcase debug output
      if type_score > 0
        # Find which opponent type is threatening
        my_types = get_real_types(user)
        @battle.allOtherSideBattlers(user.index).each do |target|
          next unless target && !target.fainted?
          target.moves.each_with_index do |m, index|
            next unless aai_switch_move_available?(target, index) && m.type
            resolved_m_type = AdvancedAI::CombatUtilities.resolve_move_type(target, m)
            type_mod = Effectiveness.calculate(resolved_m_type, *my_types)
            if Effectiveness.super_effective?(type_mod)
              echoln "[Switch] Type disadvantage detected: #{resolved_m_type} vs #{user.name}"
              break
            end
          end
        end
      end
      if survival_score > 0
        # Show estimated incoming damage
        @battle.allOtherSideBattlers(user.index).each do |target|
          next unless target && !target.fainted?
          max_dmg_pct = 0
          best_move_name = nil
          target.moves.each_with_index do |m, index|
            next unless aai_switch_move_available?(target, index)
            dmg = estimate_incoming_damage_percent(user, m, target) rescue 0
            if dmg > max_dmg_pct
              max_dmg_pct = dmg
              best_move_name = m.name
            end
          end
          if max_dmg_pct > 0 && best_move_name
            echoln "[Switch] Survival concern: incoming #{best_move_name} ~#{max_dmg_pct.to_i}% estimated damage"
          end
        end
      end
    end
    
    return score
  end

  # Sacrifice-switch guard: returns true when EVERY legal replacement would
  # faint on the switch-in (entry-hazard chip + the opponent's strongest hit).
  # In that case a voluntary switch only feeds a teammate to a free OHKO, so
  # should_switch_advanced? stays in instead. The Ace is excluded the same way
  # find_best_switch_advanced excludes it for voluntary switches, so this stays
  # consistent with the replacement that would actually be chosen.
  # NOTE: only the VOLUNTARY path calls this. Forced replacements (faint,
  # U-turn / Volt Switch, phazing, Eject Button, etc.) never reach here, so a
  # fainted Pokemon is still always replaced.
  def no_safe_switch_in?(user, skill)
    party = @battle.pbParty(user.index & 1)
    side  = user.index & 1

    available = []
    party.each_with_index do |pkmn, i|
      next unless pkmn && !pkmn.fainted? && !pkmn.egg?
      next if @battle.pbFindBattler(i, user.index)      # already on the field
      next unless aai_switch_candidate_legal?(user, i)
      available << [pkmn, i]
    end

    available = aai_filter_reserved_switches(available.map { |pkmn, i| [pkmn, nil, i] }, user)

    return false if available.empty?  # nothing to switch to -> don't veto here

    opponents = @battle.allOtherSideBattlers(user.index).select { |t| t && !t.fainted? }
    return false if opponents.empty?

    # Veto only if EVERY candidate faints on entry.
    available.all? do |(pkmn, _score, _idx)|
      hp_frac     = pkmn.hp.to_f / [pkmn.totalhp, 1].max
      hazard_frac = (calculate_entry_hazard_damage(pkmn, user.index, true) rescue 0.0)

      worst_hit = 0.0
      opponents.each do |target|
        target.moves.each_with_index do |move, index|
          next unless aai_switch_move_available?(target, index)
          dmg = (calculate_incoming_damage(pkmn, move, target, user) rescue 0.0)
          worst_hit = dmg if dmg > worst_hit
        end
      end

      faints_on_entry = (hazard_frac + worst_hit) >= hp_frac
      if AdvancedAI::DEBUG_SWITCH_INTELLIGENCE
        echoln("    [SAC-CHECK] #{pkmn.name}: hazard #{(hazard_frac * 100).to_i}% + hit #{(worst_hit * 100).to_i}% vs #{(hp_frac * 100).to_i}% HP -> #{faints_on_entry ? 'FAINTS' : 'survives'}")
      end
      faints_on_entry
    end
  end

  #=============================================================================
  # EVALUATION METHODS
  #=============================================================================

  # 1. Type Disadvantage Evaluation
  def evaluate_type_disadvantage(user, skill)
    score = 0
    
    my_types = get_real_types(user)
    
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      echoln("    → Analyzing vs #{target.name} [#{target.pbTypes(true).join('/')}]")
      
      # Offensive Threat (Opponent can hit User super effectively)
      target.moves.each_with_index do |move, index|
        next unless aai_switch_move_available?(target, index)
        next unless move.type # Fix ArgumentError
        resolved_type = AdvancedAI::CombatUtilities.resolve_move_type(target, move)
        type_mod = Effectiveness.calculate(resolved_type, *my_types)
        if Effectiveness.super_effective?(type_mod)
          score += 20  # Super effective move!
          echoln("      • #{move.name} [#{resolved_type}] → SUPER EFFECTIVE! (+20)")
        end
      end
      
      # Defensive Weakness (User cannot hit Opponent effectively)
      user_offensive = user.moves.map do |move|
        next 0 unless move
        next 0 unless move.type # Fix ArgumentError
        resolved_type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
        type_mod = Effectiveness.calculate(resolved_type, *target.pbTypes(true))
        Effectiveness.not_very_effective?(type_mod) ? 1.0 : 0.0
      end.count { |x| x > 0 }
      
      score += 10 if user_offensive >= 3  # Most moves not very effective
      
      # STAB Disadvantage
      target.moves.each_with_index do |move, index|
        next unless aai_switch_move_available?(target, index)
        next unless move.type # Fix ArgumentError
        resolved_type = AdvancedAI::CombatUtilities.resolve_move_type(target, move)
        if target.pbHasType?(resolved_type)  # STAB
          type_mod = Effectiveness.calculate(resolved_type, *my_types)
          score += 15 if Effectiveness.super_effective?(type_mod)
        end
      end
    end
    
    return [score, 40].min  # Cap at 40
  end
  
  # 2. Survival Concerns
  def evaluate_survival_concerns(user, skill)
    score = 0
    hp_percent = user.hp.to_f / user.totalhp
    
    # Low HP
    if hp_percent < 0.25
      score += 30
    elsif hp_percent < 0.40
      score += 20
    elsif hp_percent < 0.55
      score += 10
    end
    
    # No Recovery Options
    has_recovery = user.moves.any? do |m|
      next false unless m
      move_data = GameData::Move.try_get(m.id)
      next false unless move_data
      move_data.function_code.start_with?("HealUser") || 
        ["Roost", "Synthesis", "MorningSun", "Moonlight", "Recover", "Softboiled", "Wish", "Rest"].include?(move_data.real_name)
    end
    score += 10 if !has_recovery && hp_percent < 0.5
    
    # Bad Status
    if user.status != :NONE
      case user.status
      when :POISON
        score += (user.statusCount > 0) ? 20 : 15  # Badly poisoned (toxic) vs regular
      when :BURN
        score += 15
      when :SLEEP, :FROZEN
        score += 10
      when :PARALYSIS
        score += 5
      end
    end
    
    # OHKO Danger
    my_types = get_real_types(user)
    
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      # Faster Opponent with high Attack (accounting for Trick Room)
      tr_active = (@battle.field.effects[PBEffects::TrickRoom] > 0 rescue false)
      if tr_active ? (target.pbSpeed < user.pbSpeed) : (target.pbSpeed > user.pbSpeed)
        target.moves.each_with_index do |move, index|
          next unless aai_switch_move_available?(target, index)
          next unless move.type
          
          resolved_type = AdvancedAI::CombatUtilities.resolve_move_type(target, move)
          type_mod = Effectiveness.calculate(resolved_type, *my_types)
          
          # Rough Damage Estimate
          if Effectiveness.super_effective?(type_mod)
            # Use safer base damage retrieval for v21.1 compatibility
            base_dmg = AdvancedAI::CombatUtilities.resolve_move_power(move)
            if move.physicalMove?
              atk = target.attack
              dfn = [user.defense, 1].max
            else
              atk = target.spatk
              dfn = [user.spdef, 1].max
            end
            estimated_damage = (atk * base_dmg * 2.0) / dfn
            score += 15 if estimated_damage >= user.hp
          end
        end
      end
    end
    
    return [score, 30].min
  end
  
  # 3. Stat Stage Analysis
  def evaluate_stat_stages(user, skill)
    score = 0
    
    # Negative Stat Stages
    negative_stages = user.stages.values.count { |stage| stage < 0 }
    score += negative_stages * 8
    
    # Critical Drops
    score += 10 if user.stages[:ATTACK] <= -2 && user.attack > user.spatk
    score += 10 if user.stages[:SPECIAL_ATTACK] <= -2 && user.spatk > user.attack
    score += 12 if user.stages[:SPEED] <= -2
    
    # Opponent with many Boosts
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      positive_stages = target.stages.values.count { |stage| stage > 0 }
      score += 5 if positive_stages >= 2
      score += 10 if positive_stages >= 4
    end
    
    return [score, 25].min
  end
  
  # 4. Better Available Options
  def evaluate_better_options(user, skill)
    score = 0
    # Best matchup reachable by a voluntary switch (after reserve filtering), so
    # calculate_switch_score can tell whether the current type disadvantage is
    # actually escapable. nil = no legal switch target at all.
    @best_switch_matchup = nil

    party = @battle.pbParty(user.index & 1)
    available_switches = []
    party.each_with_index do |pkmn, i|
      next unless pkmn && !pkmn.fainted? && !pkmn.egg?
      next if @battle.pbFindBattler(i, user.index)
      next unless aai_switch_candidate_legal?(user, i)
      available_switches << [pkmn, nil, i]
    end
    available_switches = aai_filter_reserved_switches(available_switches, user).map(&:first)

    return 0 if available_switches.empty?
    
    # Find best alternative
    best_matchup_score = -Float::INFINITY
    best_switch = nil
    
    available_switches.each do |switch_mon|
      matchup = evaluate_switch_matchup(switch_mon, user)
      if matchup > best_matchup_score
        best_matchup_score = matchup
        best_switch = switch_mon
      end
    end
    
    return 0 unless best_switch
    @best_switch_matchup = best_matchup_score

    # Calculate current pokemon's matchup for comparison
    current_matchup_score = evaluate_switch_matchup(user.pokemon, user)
    
    # Calculate improvement
    improvement = best_matchup_score - current_matchup_score
    
    echoln("[AAI Switch] Current: #{current_matchup_score} vs Best: #{best_matchup_score} (Diff: #{improvement})")

    # Revolving-door guard: a positive "improvement" is only worth a free switch-in
    # turn if the destination is actually a viable matchup. When every benched
    # Pokemon is still type-disadvantaged against the opponent (best_matchup_score
    # < 0), switching just trades one losing matchup for another and feeds the
    # incoming mon a free hit. Granting the switch bonus here produced the
    # reported revolving-door: a team of Bug-types vs a Combusken spamming Flame
    # Charge, where the AI pivoted into fresh OHKO fodder every single turn until
    # its whole party was gone. In that case grant NO switch incentive so the AI
    # stays in and acts (chip / status / pray for a miss) instead of sacrificing
    # teammates one at a time. A still-negative "best" never escapes the
    # disadvantage, so improvement alone must not justify the switch.
    if best_matchup_score < 0
      echoln("[AAI Switch] No favorable switch — best option #{best_switch.name} still unfavorable (#{best_matchup_score}); staying in")
    # Bonus only if SIGNIFICANT improvement INTO a viable (>= neutral) matchup
    elsif improvement > 25
      score += 35
      echoln("[AAI Switch] Best Option: #{best_switch.name} (Matchup +#{best_matchup_score}, Improvement +#{improvement})")
    elsif improvement > 15
      score += 25
      echoln("[AAI Switch] Good Option: #{best_switch.name} (Matchup +#{best_matchup_score}, Improvement +#{improvement})")
    elsif improvement > 5 && best_matchup_score > 40
      # Require a score above 40 for small matchup improvements.
      score += 15
      echoln("[AAI Switch] Solid Option: #{best_switch.name} (Matchup +#{best_matchup_score}, Improvement +#{improvement})")
    end

    return score
  end
  
  # 5. Momentum Control
  def evaluate_momentum(user, skill)
    score = 0
    
    # Force Momentum Shift if behind
    alive_user = @battle.pbParty(user.index & 1).count { |p| p && !p.fainted? }
    alive_enemy = 0
    @battle.allOtherSideBattlers(user.index).each do |b|
      next unless b && !b.fainted?
      alive_enemy = @battle.pbParty(b.index & 1).count { |p| p && !p.fainted? }
      break  # In singles, one opponent's party is enough
    end
    
    if alive_user < alive_enemy
      score += 10  # Attempt Momentum Shift
    end
    
    # Predict Switch if opponent wants to setup
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      # Opponent has Setup Moves (check function codes)
      has_setup = target.moves.any? do |m|
        next false unless m && m.is_a?(Battle::Move) && m.statusMove?
        move_data = GameData::Move.try_get(m.id)
        next false unless move_data
        # Setup moves have function codes like RaiseUserAttack2, RaiseMultipleStats, etc.
        move_data.function_code.to_s.include?("RaiseUser") || move_data.function_code.to_s.include?("RaiseMulti")
      end
      score += 15 if has_setup && user_has_type_disadvantage?(user, target)
    end
    
    return [score, 20].min
  end
  
  # 6. Prediction Advantage (Skill 85+)
  def evaluate_prediction_advantage(user, skill)
    return 0 unless skill >= 85 && AdvancedAI.prediction_depth(skill) > 0
    score = 0
    
    # If opponent likely switches, stay in
    # If opponent likely setups, switch out
    
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      memory = AdvancedAI.get_memory(@battle, target)
      if AdvancedAI.tier_feature(skill, :learn_patterns)
        usable_ids = target.moves.each_with_index.filter_map do |move, i|
          move.id if move && @battle.pbCanChooseMove?(target.index, i, false)
        end
        setup_count = (memory[:move_counts] || {}).sum do |id, count|
          next 0 unless usable_ids.include?(id)
          data = GameData::Move.try_get(id)
          next 0 unless data && data.function_code.start_with?("RaiseUser", "RaiseMulti")
          count
        end
        score += 10 if setup_count >= 2
      end
      if target.hp < target.totalhp * 0.35 &&
         @battle.pbParty(target.index).each_index.any? { |i| @battle.pbCanSwitch?(target.index, i) }
        score -= 15
      end
    end
    
    return [score, 15].min
  end
  
  #=============================================================================
  # FIND BEST SWITCH OPTION
  #=============================================================================
  
  # Detailed Switch Candidate Evaluation
  def evaluate_switch_candidate_detailed(pkmn, current_user, skill)
    score = 50  # Base score
    
    # 1. TYPE MATCHUP (0-50 Points)
    score += evaluate_switch_matchup(pkmn, current_user)
    
    # 2. HP & STATUS (0-20 Points)
    hp_percent = pkmn.hp.to_f / pkmn.totalhp
    score += (hp_percent * 20).to_i
    score -= 20 if pkmn.status != :NONE
    
    # 3. SPEED (0-15 Points)
    # Note: pkmn is Pokemon (not Battler), need to calculate speed properly
    @battle.allOtherSideBattlers(get_battler_index(current_user)).each do |target|
      next unless target && !target.fainted?
      # Use base speed stat for Pokemon comparison (pkmn doesn't have pbSpeed)
      pkmn_speed = pkmn.speed
      target_speed = target.speed  # Use base speed for fair comparison
      score += 15 if pkmn_speed > target_speed
    end
    
    # 4. ROLE ANALYSIS (0-25 Points)
    role_bonus = evaluate_switch_role(pkmn, current_user, skill)
    score += role_bonus
    
    # 4b. ROLE COUNTER-PICK (0-25 Points)
    counter_bonus = role_counter_pick_bonus(pkmn, current_user, skill)
    score += counter_bonus
    
    if AdvancedAI.get_setting(:hazard_calc, 0) > 0
      probe = switch_hazard_preview(pkmn, get_battler_index(current_user))
      side = probe.pbOwnSide.effects
      immune = probe.hasActiveItem?(:HEAVYDUTYBOOTS) || !probe.takesIndirectDamage?
      if side[PBEffects::StealthRock]
        effectiveness = Effectiveness.calculate(:ROCK, *probe.pbTypes(true))
        if immune || Effectiveness.ineffective?(effectiveness)
          score += 15
        elsif Effectiveness.not_very_effective?(effectiveness)
          score += 10
        elsif Effectiveness.super_effective?(effectiveness)
          score -= 15
        end
      end
      score += 10 if side[PBEffects::Spikes] > 0 && (immune || probe.airborne?)
    end

    # 6. ABILITY SYNERGY (0-20 Points)
    # Use ability_id instead of ability to avoid Gen9 Pack recursion
    ability_id = nil
    begin
      ability_id = pkmn.ability_id if pkmn.respond_to?(:ability_id)
    rescue StandardError => e
      AdvancedAI.log("Error getting ability_id: #{e.message}", "Switch")
    end
    
    if ability_id
      # Intimidate on Switch-In
      score += 20 if ability_id == :INTIMIDATE
      
      # Weather/Terrain abilities
      score += 15 if [:DRIZZLE, :DROUGHT, :SANDSTREAM, :SNOWWARNING].include?(ability_id)
      
      # Defensive abilities
      score += 10 if [:REGENERATOR, :NATURALCURE, :IMMUNITY].include?(ability_id)
    end
    
    return score
  end
  
  # Matchup Evaluation for Switch
  def evaluate_switch_matchup(switch_mon, current_user)
    score = 0
    
    # Validate types
    # Validate types - normalize input to types array
    switch_types = []
    
    if switch_mon.is_a?(Battle::Battler)
       switch_types = get_real_types(switch_mon)
    elsif switch_mon.respond_to?(:types)
       # Pokemon object
       switch_types = switch_mon.types.compact
    end
    
    return 0 if switch_types.empty?
    
    @battle.allOtherSideBattlers(get_battler_index(current_user)).each do |target|
      next unless target && !target.fainted?
      
      # Offensive Type Advantage
      switch_mon_types = switch_types.uniq
      return 0 if switch_mon_types.empty?
      
      target_types = target.pbTypes(true).compact
      next if target_types.empty?
      
      switch_mon_types.each do |type|
        next unless type  # Skip nil
        effectiveness = Effectiveness.calculate(type, *target_types)
        if Effectiveness.super_effective?(effectiveness)
          score += 20
        elsif Effectiveness.not_very_effective?(effectiveness)
          score -= 10
        elsif Effectiveness.ineffective?(effectiveness)
          score -= 40  # STAB ineffective (Immunity)
        end
      end
      
      # Defensive Type Advantage
      target.moves.each_with_index do |move, index|
        next unless aai_switch_move_available?(target, index)
        next unless move.type  # Skip nil types
        # Use duck-typing for switch_mon (could be Battler or Pokemon)
        switch_types = switch_mon.is_a?(Battle::Battler) ? 
          switch_mon.pbTypes(true).compact :
          switch_mon.types.compact
        next if switch_types.empty?
        resolved_type = AdvancedAI::CombatUtilities.resolve_move_type(target, move)
        effectiveness = Effectiveness.calculate(resolved_type, *switch_types)
        if Effectiveness.ineffective?(effectiveness) ||
           aai_switch_ability_immunity?(switch_mon, current_user, target, move, resolved_type)
          score += 40  # IMMUNITY is extremely valuable!
        elsif Effectiveness.not_very_effective?(effectiveness)
          score += 15  # Resistance is good
        elsif Effectiveness.super_effective?(effectiveness)
          score -= 25  # Weakness is bad
        end
      end
    end
    
    return score
  end
  
  # Role-based Switch Evaluation
  def evaluate_switch_role(pkmn, current_user, skill)
    return 0 unless skill >= 55
    score = 0
    
    # Determine roles using the full 9-role detection system
    current_role = determine_pokemon_role(current_user)
    switch_role = determine_pokemon_role_from_stats(pkmn)
    
    # Also check the opponent's role for smart counter-switching
    opponent = @battle.allOtherSideBattlers(get_battler_index(current_user)).find { |b| b && !b.fainted? }
    opponent_role = opponent ? determine_pokemon_role(opponent) : :balanced
    
    # === Complementary Role Preferences ===
    # Switch to something that covers the current mon's weaknesses
    case current_role
    when :sweeper
      score += 15 if [:wall, :stall, :tank].include?(switch_role)
    when :wall, :stall
      score += 15 if [:sweeper, :wallbreaker].include?(switch_role)
    when :tank
      score += 15 if [:wallbreaker, :sweeper].include?(switch_role)
    when :support
      score += 20 if [:sweeper, :wallbreaker].include?(switch_role)  # Support done → bring attacker
    when :wallbreaker
      score += 15 if [:wall, :stall, :tank].include?(switch_role)
    when :pivot
      score += 10 if [:sweeper, :wallbreaker, :tank].include?(switch_role)
    when :lead
      score += 15 if [:sweeper, :wallbreaker, :pivot].include?(switch_role)  # Lead done → bring offense
    end
    
    # === Counter-Pick the Opponent ===
    # Bring in something that beats what the opponent is doing
    case opponent_role
    when :sweeper
      score += 20 if [:wall, :stall].include?(switch_role)  # Wall the sweeper
    when :wall, :stall
      score += 20 if switch_role == :wallbreaker  # Break the wall
    when :wallbreaker
      score += 15 if switch_role == :sweeper  # Outspeed the breaker
    when :support
      score += 15 if [:sweeper, :lead].include?(switch_role)  # Pressure before setup completes
    when :tank
      score += 15 if switch_role == :wallbreaker  # Break bulky offense
    end
    
    return score
  end
  
  # Find best switch Pokemon (public for Core.rb integration)
  # forced_switch: true when terrible_moves triggered the switch (not voluntary)
  # Includes entry hazards when checking for a near-certain switch-in KO.
  def ohkod_on_switch_in?(switch_pkmn, user)
    return false unless switch_pkmn && user
    # Effective HP fraction on entry, after Stealth Rock / Spikes / etc.
    hazard = (calculate_entry_hazard_damage(switch_pkmn, get_battler_index(user), true) rescue 0.0) || 0.0
    hp_fraction = switch_pkmn.hp.to_f / [switch_pkmn.totalhp, 1].max
    survivable = hp_fraction - hazard
    return true if survivable <= 0.0   # hazards alone already KO
    worst = 0.0
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      target.moves.each_with_index do |move, index|
        next unless aai_switch_move_available?(target, index)
        dmg = (calculate_incoming_damage(switch_pkmn, move, target, user) rescue 0.0) || 0.0
        worst = dmg if dmg > worst
      end
    end
    # Treat >=95% of the post-hazard HP as an effective OHKO (damage estimate
    # uses the average roll, so a 95% average is a near-certain kill).
    worst >= survivable * 0.95
  end

  def find_best_switch_advanced(user, skill, forced_switch = false)
    dbg = AdvancedAI::DEBUG_SWITCH_INTELLIGENCE
    if dbg
      echoln "  ┌─────────────────────────────────────┐"
      echoln "  │ FINDING BEST REPLACEMENT            │"
      echoln "  └─────────────────────────────────────┘"
    end
    
    party = @battle.pbParty(user.index & 1)
    available_switches = []
    
    party.each_with_index do |pkmn, i|
      next unless pkmn && !pkmn.fainted? && !pkmn.egg?
      next if @battle.pbFindBattler(i, user.index) # Already in battle
      next unless aai_switch_candidate_legal?(user, i, forced_switch)
      
      matchup_score = evaluate_switch_matchup_detailed(pkmn, user)
      available_switches.push([pkmn, matchup_score, i])
      
      echoln "  • #{pkmn.name}: Matchup = #{matchup_score}"
    end
    
    is_voluntary_switch = user && !user.fainted? && !forced_switch
    available_switches = aai_filter_reserved_switches(available_switches, user, forced_switch)

    if available_switches.empty?
      echoln "  >>> No valid switches available!"
      return nil
    end
    
    # Sort by matchup score (highest first)
    available_switches.sort_by! { |_, score, _| -score }
    best_pkmn, best_score, best_idx = available_switches.first

    # A voluntary switch prefers the first scored candidate that survives entry.
    # If every candidate is lost, keep the highest score.
    if is_voluntary_switch && best_pkmn && ohkod_on_switch_in?(best_pkmn, user)
      safer = available_switches.find { |pk, _s, _i| pk && !ohkod_on_switch_in?(pk, user) }
      if safer
        best_pkmn, best_score, best_idx = safer
        echoln "  [AAI] Switch-in safety: top pick is OHKO'd on entry — choosing safer #{best_pkmn.name} instead"
      end
    end

    echoln "  ─────────────────────────────────────"
    echoln "  ✅ BEST OPTION: #{best_pkmn.name}"
    echoln "  Matchup Score: #{best_score}"
    
    # === [Switch] BEST SWITCH SUMMARY ===
    echoln "[Switch] Best switch: #{best_pkmn.name} (Score: #{best_score})"
    
    # Sub-bullet: Type advantage vs opponents
    switch_types = best_pkmn.types.compact
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      target_types = target.pbTypes(true).compact rescue []
      next if target_types.empty?
      
      # Check for immunities and resistances
      switch_types.each do |st|
        next unless st
        eff = Effectiveness.calculate(st, *target_types) rescue nil
        next unless eff
        if Effectiveness.ineffective?(eff)
          echoln "  - Type advantage: #{target_types.first} immune (#{st})"
        end
      end
    end
    
    # Sub-bullet: Role synergy
    switch_roles = AdvancedAI.detect_roles(best_pkmn) rescue [:balanced]
    user_roles = AdvancedAI.detect_roles(user) rescue [:balanced]
    if switch_roles.any? && user_roles.any?
      echoln "  - Role synergy: #{user_roles.first} → #{switch_roles.first}"
    end
    
    # Sub-bullet: Entry hazard cost
    hazard_dmg = calculate_entry_hazard_damage(best_pkmn, get_battler_index(user)) rescue 0
    if hazard_dmg > 0
      hazard_source = []
      side = @battle.sides[user.index & 1]  # own side (& 1 is safe in doubles)
      hazard_source << "Stealth Rock" if side.effects[PBEffects::StealthRock]
      hazard_source << "Spikes" if side.effects[PBEffects::Spikes] > 0
      hazard_source << "Toxic Spikes" if side.effects[PBEffects::ToxicSpikes] > 0
      hazard_source << "Sticky Web" if side.effects[PBEffects::StickyWeb]
      source_str = hazard_source.empty? ? "hazards" : hazard_source.join(", ")
      echoln "  - Entry hazard cost: #{(hazard_dmg * 100).round(0)}% (#{source_str})"
    end
    
    # Return party index directly (Core.rb expects integer)
    return best_idx
  end
  
  private
  
  # Constants for damage calculation
  DAMAGE_RANDOM_MULTIPLIER = 0.925  # Average of random damage roll (85-100%)
  STAB_MULTIPLIER = 1.5
  BURN_PHYSICAL_MODIFIER = 0.5
  WEATHER_BOOST = 1.5
  WEATHER_NERF = 0.5
  
  # Calculate estimated incoming damage from a move
  # Returns damage as a percentage of switch_pkmn's total HP (0.0 to 1.0+)
  def calculate_incoming_damage(switch_pkmn, move, attacker, current_user = nil)
    return 0.0 unless switch_pkmn && move && attacker && move.damagingMove?
    index = current_user ? get_battler_index(current_user) : (attacker.index ^ 1)
    defender = switch_entry_hp_preview(switch_pkmn, index)
    return 0.0 if defender.fainted?
    projected_attacker = defender.battle.battlers[attacker.index]
    projected_move = move.clone
    projected_move.instance_variable_set(:@battle, defender.battle)
    AdvancedAI::CombatUtilities.estimate_damage(projected_attacker, projected_move, defender, as_percent: true)
  end

  # Detailed Matchup Evaluation for Switch Selection
  def evaluate_switch_matchup_detailed(switch_pkmn, current_user)
    score = 0
    
    # Validate switch_pkmn has types
    return 0 unless switch_pkmn
    switch_types = switch_pkmn.types.compact
    return 0 if switch_types.empty? || switch_types.any?(&:nil?)
    
    # === ENTRY HAZARD DAMAGE PENALTY ===
    score_hazards = AdvancedAI.get_setting(:hazard_calc, 0) > 0
    hazard_damage = score_hazards ? calculate_entry_hazard_damage(switch_pkmn, get_battler_index(current_user)) : 0.0
    entry_damage = calculate_entry_hazard_damage(switch_pkmn, get_battler_index(current_user), true)
    if hazard_damage != 0 || entry_damage > 0
      hazard_penalty = (hazard_damage * 100).to_i  # Scale: 50% hazard damage = -50 points
      score -= hazard_penalty
      echoln "[HAZARD] #{(hazard_damage * 100).round(1)}% HP on switch-in [-#{hazard_penalty}]"
      
      # Extra penalty if hazards would faint us immediately
      remaining_hp_fraction = switch_pkmn.hp.to_f / [switch_pkmn.totalhp, 1].max
      if entry_damage >= remaining_hp_fraction
        score -= 100  # FATAL - would faint on switch-in!
        echoln "FATAL] Hazards would KO on switch-in! [-100]"
      elsif score_hazards && entry_damage >= 0.50
        score -= 30
        echoln "[CRITICAL] 50%+ hazard damage! [-30]"
      end
    end
    
    # Check if current user is "already doomed" (will faint next turn)
    # If so, we should minimize damage on switch-in rather than avoid all OHKOs
    current_is_doomed = false
    if current_user && current_user.respond_to?(:fainted?) && !current_user.fainted?
      @battle.allOtherSideBattlers(get_battler_index(current_user)).each do |target|
        next unless target && !target.fainted?
        # Doomed if: Low HP AND opponent moves before us
        hp_percent = current_user.hp.to_f / current_user.totalhp
        tr_active = (@battle.field.effects[PBEffects::TrickRoom] > 0 rescue false)
        target_moves_first = tr_active ? (target.pbSpeed < current_user.pbSpeed) : (target.pbSpeed > current_user.pbSpeed)
        if hp_percent < 0.30 && target_moves_first
          current_is_doomed = true
          break
        end
      end
    end
    
    # Analyze against all opponents
    @battle.allOtherSideBattlers(get_battler_index(current_user)).each do |target|
      next unless target && !target.fainted?
      
      target_types = target.pbTypes(true).compact
      next if target_types.empty? || target_types.any?(&:nil?)
      
      # Defensive Matchup (Incoming Moves)
      target.moves.each_with_index do |move, index|
        next unless aai_switch_move_available?(target, index)
        next unless move.type  # Skip if move has no type
        
        move_type = move.pbCalcType(target)  # target is already a Battle::Battler
        next unless move_type  # Skip if calculated type is nil
        
        # Additional safety: ensure all switch types are valid
        next if switch_types.any? { |t| t.nil? }
        
        eff = Effectiveness.calculate(move_type, *switch_types)
        
        # Calculate actual damage to properly assess safety
        damage_percent = calculate_incoming_damage(switch_pkmn, move, target, current_user)
        
        # Type effectiveness scoring (base scoring)
        if Effectiveness.ineffective?(eff) ||
           aai_switch_ability_immunity?(switch_pkmn, current_user, target, move, move_type)
          score += 40
        elsif Effectiveness.not_very_effective?(eff)
          score += 15
        elsif Effectiveness.super_effective?(eff)
          score -= 25
        end
        
        # Damage-based penalties (critical for survival)
        # If current user is already doomed, we want to MINIMIZE damage, not avoid all OHKOs
        if current_is_doomed
          # In "doomed" scenario: Pick the switch that takes LEAST damage
          # Convert damage to a penalty (higher damage = worse score)
          damage_penalty = (damage_percent * 50).to_i  # Scale: 100% damage = -50 points
          score -= damage_penalty
          echoln "    [DAMAGE] #{move.name} (~#{(damage_percent * 100).to_i}% HP) [-#{damage_penalty}]"
        else
          # Normal scenario: Penalize based on OHKO/2HKO thresholds
          if damage_percent >= 0.85
            # Likely OHKO on entry
            score -= 60
            echoln "    [OHKO RISK] #{move.name} (~#{(damage_percent * 100).to_i}% HP) [-60]"
          elsif damage_percent >= 0.45
            # Likely 2HKO - risky switch
            score -= 30
            echoln "    [2HKO RISK] #{move.name} (~#{(damage_percent * 100).to_i}% HP) [-30]"
          elsif damage_percent >= 0.30
            # Moderate damage - somewhat risky
            score -= 10
          end
        end
      end
      
      # Offensive Matchup (Outgoing Moves)
      switch_pkmn.moves.each do |move|
        next unless move && move.id
        next if move.pp == 0 && move.total_pp > 0
        move_data = GameData::Move.try_get(move.id)
        next unless move_data
        next if move_data.category == 2  # Skip status moves (0=Physical, 1=Special, 2=Status)
        next unless move_data.type  # Skip if move has no type
        
        # Additional safety: ensure all target types are valid
        next if target_types.any? { |t| t.nil? }
        
        resolved_type = AdvancedAI::CombatUtilities.resolve_move_type(switch_pkmn, move_data)
        eff = Effectiveness.calculate(resolved_type, *target_types)
        
        if Effectiveness.super_effective?(eff)
          score += 20
        elsif Effectiveness.ineffective?(eff)
          score -= 40  # Useless move
        end
      end
    end
    
    # === Gen 9 switch-in ability bonuses (Zero to Hero, Booster Energy paradox, Intimidate, etc.) ===
    begin
      score += gen9_switchin_bonus(switch_pkmn) if respond_to?(:gen9_switchin_bonus)
    rescue
    end
    
    return score
  end

  #=============================================================================
  # HELPER METHODS
  #=============================================================================
  
  def user_has_advantage?(user)
    my_types = get_real_types(user)
    
    @battle.allOtherSideBattlers(user.index).all? do |target|
      next true unless target && !target.fainted?
      
      # Type advantage
      user.moves.each_index.any? do |index|
        next false unless aai_switch_move_available?(user, index)
        move = user.moves[index]
        next false unless move.type
        resolved_type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
        type_mod = Effectiveness.calculate(resolved_type, *target.pbTypes(true))
        Effectiveness.super_effective?(type_mod)
      end
    end
  end
  
  def user_has_type_disadvantage?(user, target)
    my_types = get_real_types(user)
    
    target.moves.each_index.any? do |index|
      next false unless aai_switch_move_available?(target, index)
      move = target.moves[index]
      next false unless move.type
      resolved_type = AdvancedAI::CombatUtilities.resolve_move_type(target, move)
      type_mod = Effectiveness.calculate(resolved_type, *my_types)
      Effectiveness.super_effective?(type_mod)
    end
  end
  
  def determine_pokemon_role(battler)
    # Use the full 9-role detection system from RoleDetection
    primary, _secondary = AdvancedAI.detect_roles(battler)
    return primary || :balanced
  end
  
  # Returns the types this battler should be evaluated against.
  # When called on the AI's own side, returns real types (perception layer is
  # a no-op for non-opposing battlers). When called on an opposing battler with
  # an active Illusion, the perception layer in 1_Core/Illusion_Perception.rb
  # transparently returns the disguised Pokemon's types instead.
  def get_real_types(battler)
    return battler.pbTypes(true)
  end
  
  def determine_pokemon_role_from_stats(pkmn)
    # Use the full 9-role detection system from RoleDetection
    primary, _secondary = AdvancedAI.detect_roles(pkmn)
    return primary || :balanced
  end
  
  # Check if current Pokemon can KO any opponent
  # Enhanced: Also considers if user can strike FIRST (speed/priority)
  def can_ko_opponent?(user)
    return false unless user && !user.fainted?
    
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      user.moves.each_with_index do |move, index|
        next unless aai_switch_move_available?(user, index)
        next unless move.type
        
        # Resolve effective type and power via shared helpers
        effective_type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
        power = AdvancedAI::CombatUtilities.resolve_move_power(move)
        next if power == 0
        
        # Check type effectiveness
        type_mod = Effectiveness.calculate(effective_type, *target.pbTypes(true))
        next if Effectiveness.ineffective?(type_mod)  # Can't KO with immune move

        # Use the shared, level-accurate damage estimator — the SAME one the move
        # scorer uses. The old inline formula dropped the (2*Level/5+2)/50 term and
        # divided by 100, underestimating real damage ~40-80x, so this method
        # almost never detected a KO and the -60 switch malus never fired.
        # calculate_rough_damage already accounts for STAB, type, Huge/Pure Power,
        # weather, terrain, items, screens and abilities.
        estimated_damage = calculate_rough_damage(move, user, target)

        # Can KO? (small buffer for low damage rolls)
        if estimated_damage >= target.hp * 0.85
          # This is critical when both Pokemon are in KO range
          move_priority = move.priority || 0
          
          # If we have priority advantage, we can KO first
          return true if move_priority > 0
          
          # If equal priority, check speed (accounting for Trick Room)
          if move_priority == 0
            # We can KO first if we move before them
            tr_active = (@battle.field.effects[PBEffects::TrickRoom] > 0 rescue false)
            user_moves_first = tr_active ? (user.pbSpeed < target.pbSpeed) : (user.pbSpeed > target.pbSpeed)
            return true if user_moves_first
            
            # Even if slower, if opponent CAN'T KO us back, still worth staying
            # (This handles the "I can 2HKO them but they can't touch me" scenario)
            opponent_can_ko_us = target.moves.each_index.any? do |opponent_index|
              next false unless aai_switch_move_available?(target, opponent_index)
              opp_move = target.moves[opponent_index]
              # Same fix: use the level-accurate estimator instead of the old
              # ~40-80x-too-low inline formula.
              calculate_rough_damage(opp_move, target, user) >= user.hp * 0.85
            end
            
            return true unless opponent_can_ko_us
          end
        end
      end
    end
    
    return false
  end
  
  #=============================================================================
  # SACRIFICE PLAY LOGIC - Intentional sacs for momentum
  #=============================================================================
  
  def evaluate_sacrifice_value(user, skill)
    return 0 unless skill >= 80
    score = 0
    
    # Is current mon "doomed"? (Will die this turn regardless)
    hp_percent = user.hp.to_f / user.totalhp
    is_doomed = false
    
    @battle.allOtherSideBattlers(user.index).each do |target|
      next unless target && !target.fainted?
      
      # Check if opponent can OHKO us with priority or moves before us
      tr_active = (@battle.field.effects[PBEffects::TrickRoom] > 0 rescue false)
      target.moves.each_with_index do |move, index|
        next unless aai_switch_move_available?(target, index)
        
        # Rough damage estimate
        rough_damage = estimate_sac_damage_percent(user, move, target)
        
        if rough_damage >= hp_percent * 100
          target_moves_first = tr_active ? (target.pbSpeed < user.pbSpeed) : (target.pbSpeed > user.pbSpeed)
          if move.priority > 0 || target_moves_first
            is_doomed = true
            break
          end
        end
      end
      break if is_doomed
    end
    
    return 0 unless is_doomed
    
    sac_value = 0
    
    party = @battle.pbParty(user.index & 1)
    sweepers = party.select do |pkmn|
      next false unless pkmn && !pkmn.fainted? && !pkmn.egg?
      next false if @battle.pbFindBattler(party.index(pkmn), user.index)
      pkmn.moves.any? { |m| m && AdvancedAI.setup_move?(m.id) }
    end
    
    sac_value += 20 if sweepers.any?
    
    @battle.allOtherSideBattlers(user.index).each do |target|
      if target.respond_to?(:dynamax?) && target.dynamax?
        sac_value += 30  # They waste Dynamax damage on fodder
      end
      if target.respond_to?(:tera?) && target.tera?
        sac_value += 15  # Less valuable but still good
      end
    end
    
    trade_moves = user.moves.select { |m| m && [:EXPLOSION, :SELFDESTRUCT, :FINALGAMBIT, :MISTYEXPLOSION].include?(m.id) }
    if trade_moves.any?
      sac_value += 25  # Can at least trade
    end
    
    # 4. Entry hazards - dying sets up rocks
    if user.moves.any? { |m| m && [:STEALTHROCK, :SPIKES, :TOXICSPIKES].include?(m.id) }
      opp_side = @battle.sides[1 - (user.index & 1)]  # opponent side (safe in doubles)
      unless opp_side.effects[PBEffects::StealthRock]
        sac_value += 15  # Can set rocks before dying
      end
    end
    
    sac_value
  end
  
  def estimate_sac_damage_percent(defender, move, attacker)
    return 0 unless move && attacker && defender
    ratio = AdvancedAI::CombatUtilities.estimate_damage(
      attacker, move, defender, as_percent: true
    )
    (ratio * 100).to_i
  end
  
  #=============================================================================
  # ENTRY HAZARD DAMAGE CALCULATION
  #=============================================================================
  
  # Calculate total damage from entry hazards on switch-in
  # Returns damage as percentage of total HP (0.0 to 1.0+)
  def switch_hazard_preview(pkmn, index)
    preview = @battle.clone
    copies = @battle.battlers.map do |b|
      next unless b
      copy = b.clone
      copy.instance_variable_set(:@battle, preview)
      copy.instance_variable_set(:@effects, b.effects.clone)
      copy.instance_variable_set(:@stages, b.stages.clone)
      copy
    end
    preview.instance_variable_set(:@battlers, copies)
    preview.moldBreaker = false
    probe = Battle::Battler.new(preview, index)
    probe.pbInitialize(pkmn.clone, -1)
    copies[index] = probe
    probe
  end

  def switch_entry_hp_preview(pkmn, index)
    probe = switch_hazard_preview(pkmn, index)
    return probe if probe.fainted? || probe.hasActiveItem?(:HEAVYDUTYBOOTS) || !probe.takesIndirectDamage?
    side = probe.pbOwnSide
    hits = []
    if side.effects[PBEffects::StealthRock]
      effectiveness = Effectiveness.calculate(:ROCK, *probe.pbTypes(true))
      hits << [(probe.totalhp * effectiveness / 8).round, 1].max unless Effectiveness.ineffective?(effectiveness)
    end
    layers = side.effects[PBEffects::Spikes]
    hits << [probe.totalhp / [8, 6, 4][layers - 1], 1].max if layers > 0 && !probe.airborne?
    hits.each do |damage|
      probe.hp = [probe.hp - damage, 0].max
      break if probe.fainted?
      heal_switch_entry_item(probe)
    end
    probe
  end

  def heal_switch_entry_item(probe)
    return unless probe.itemActive? && probe.canHeal?
    item = probe.item_id
    berry = item != :BERRYJUICE
    return if berry && !probe.canConsumeBerry?
    case item
    when :ORANBERRY, :SITRUSBERRY, :BERRYJUICE
      return if probe.hp > probe.totalhp / 2
      amount = { ORANBERRY: 10, SITRUSBERRY: probe.totalhp / 4, BERRYJUICE: 20 }[item]
    when :FIGYBERRY, :WIKIBERRY, :MAGOBERRY, :AGUAVBERRY, :IAPAPABERRY
      return unless probe.canConsumePinchBerry?(Settings::MECHANICS_GENERATION >= 7)
      divisor = Settings::MECHANICS_GENERATION >= 8 ? 3 : (Settings::MECHANICS_GENERATION == 7 ? 2 : 8)
      amount = probe.totalhp / divisor
    else
      return
    end
    amount *= 2 if berry && probe.hasActiveAbility?(:RIPEN)
    probe.hp = [probe.hp + [amount, 1].max, probe.totalhp].min
    if berry && probe.hasActiveAbility?(:CHEEKPOUCH) && probe.canHeal?
      probe.hp = [probe.hp + [probe.totalhp / 3, 1].max, probe.totalhp].min
    end
    probe.effects[PBEffects::Unburden] = true if probe.hasActiveAbility?(:UNBURDEN)
    probe.item = nil
  end

  def calculate_entry_hazard_damage(switch_pkmn, current_user, damage_only = false)
    return 0.0 unless switch_pkmn && current_user
    return 0.0 if switch_pkmn.fainted? || switch_pkmn.egg?
    index = get_battler_index(current_user)
    probe = switch_entry_hp_preview(switch_pkmn, index)
    return 0.0 if probe.hasActiveItem?(:HEAVYDUTYBOOTS)
    side = probe.pbOwnSide
    cost = (switch_pkmn.hp - probe.hp).to_f / [probe.totalhp, 1].max
    return cost if damage_only || probe.airborne? || probe.fainted?
    if side.effects[PBEffects::ToxicSpikes] > 0 && !probe.pbHasType?(:POISON) && probe.pbCanPoison?(nil, false)
      cost += 0.10
    end
    if side.effects[PBEffects::StickyWeb] && probe.pbCanLowerStatStage?(:SPEED)
      web_cost = [0.05 * probe.speed / 130.0, 0.15].min
      if probe.hasActiveAbility?(:CONTRARY)
        cost -= web_cost
      elsif !probe.hasActiveItem?(:WHITEHERB)
        cost += web_cost
      end
    end
    cost
  end

  #=============================================================================
  # SETUP MOVE DETECTION
  #=============================================================================
  
  # Detect if opponent is setting up (stat boosts)
  def opponent_is_setting_up?(opponent)
    return false unless opponent
    
    # Check if opponent has positive stat stages
    positive_stages = opponent.stages.values.count { |stage| stage > 0 }
    return true if positive_stages >= 2  # +2 or more boosts = setup threat
    
    # Check if opponent used setup move last turn
    last_move = opponent.lastMoveUsed rescue nil  # opponent is Battle::Battler, has no .battler
    return true if last_move && AdvancedAI.setup_move?(last_move)
    
    false
  end
  
  # Setup move check - delegated to AdvancedAI.setup_move? (Move_Categories.rb)
  # Uses the comprehensive SETUP_MOVES hash instead of a local hardcoded list
  
  # Evaluate setup threat level
  def evaluate_setup_threat(opponent)
    return 0 unless opponent
    
    threat = 0
    
    # Count positive stat stages
    offensive_boosts = [opponent.stages[:ATTACK], opponent.stages[:SPECIAL_ATTACK]].max
    speed_boosts = opponent.stages[:SPEED]
    
    # High offensive boosts = big threat
    threat += offensive_boosts * 20 if offensive_boosts > 0
    threat += speed_boosts * 15 if speed_boosts > 0
    
    # Check if opponent has setup moves in their moveset
    opponent.moves.each do |move|
      next unless move
      if AdvancedAI.setup_move?(move.id)
        threat += 10  # Has setup potential
      end
    end
    
    threat
  end
  
  #=============================================================================
  # SPEED TIER AWARENESS
  #=============================================================================
  
  # Check if switch-in can outspeed opponent
  def can_outspeed?(switch_pkmn, opponent, current_user = nil)
    return false unless switch_pkmn && opponent && !switch_pkmn.fainted?
    index = current_user || (opponent.index ^ 1)
    speed = calculate_party_speed(switch_pkmn, index)
    if @battle.field.effects[PBEffects::TrickRoom] > 0
      return speed < opponent.pbSpeed
    end
    speed > opponent.pbSpeed
  end

  def calculate_party_speed(pkmn, current_user = nil)
    return 0 unless pkmn && !pkmn.fainted? && !pkmn.egg?
    index = get_battler_index(current_user || @user || 1)
    probe = switch_entry_hp_preview(pkmn, index)
    return 0 if probe.fainted?
    if probe.pbOwnSide.effects[PBEffects::StickyWeb] && !probe.airborne? &&
       !probe.hasActiveItem?(:HEAVYDUTYBOOTS) && probe.pbCanLowerStatStage?(:SPEED)
      change = probe.hasActiveAbility?(:CONTRARY) ? 1 : -1
      change *= 2 if probe.hasActiveAbility?(:SIMPLE)
      probe.stages[:SPEED] = change
      if change < 0 && probe.hasActiveItem?(:WHITEHERB)
        probe.stages[:SPEED] = 0
        probe.item = nil
        probe.effects[PBEffects::Unburden] = true
      end
    end
    probe.pbSpeed
  end

  # Evaluate speed advantage for switch decision
  def evaluate_speed_advantage(switch_pkmn, current_user)
    score = 0
    
    @battle.allOtherSideBattlers(get_battler_index(current_user)).each do |opponent|
      next unless opponent && !opponent.fainted?
      
      if can_outspeed?(switch_pkmn, opponent, current_user)
        score += 15  # Outspeeding is valuable
        
        # Extra value if we can OHKO while outspeeding
        switch_pkmn.moves.each do |move|
          next unless move
          move_data = GameData::Move.try_get(move.id)
          next unless move_data && move_data.power > 0
          
          # Reward super-effective coverage while faster.
          move_type = AdvancedAI::CombatUtilities.resolve_move_type(switch_pkmn, move_data)
          opp_types = opponent.pbTypes(true)
          effectiveness = Effectiveness.calculate(move_type, *opp_types)
          
          if Effectiveness.super_effective?(effectiveness)
            score += 10  # Can hit hard while faster
            break
          end
        end
      else
        # Slower = need to tank a hit
        score -= 5
      end
    end
    
    score
  end
  
  #=============================================================================
  # PIVOT MOVE EVALUATION
  #=============================================================================
  
  # Evaluate if pivot move is available and better than hard switch
  # Returns bonus to REDUCE switch score (prefer pivot over switch)
  def evaluate_pivot_move_option(user, skill)
    return 0 unless user && skill >= 50 && @battle.pbCanChooseNonActive?(user.index)
    pivot_moves = [:UTURN, :VOLTSWITCH, :FLIPTURN, :PARTINGSHOT, :TELEPORT,
                   :BATONPASS, :SHEDTAIL, :CHILLYRECEPTION]
    opponents = @battle.allOtherSideBattlers(user.index).select { |t| t && !t.fainted? }
    bonus = 0
    user.moves.each_with_index do |move, index|
      next unless move && pivot_moves.include?(move.id)
      next unless @battle.pbCanChooseMove?(user.index, index, false)
      if move.id == :SHEDTAIL
        preview = @battle.clone
        preview.define_singleton_method(:pbDisplay) { |*args| }
        preview_move = move.clone
        preview_move.instance_variable_set(:@battle, preview)
        next if preview_move.pbMoveFailed?(user, [])
      end
      targets = opponents
      if move.damagingMove?
        targets = opponents.select { |t| AdvancedAI::CombatUtilities.estimate_damage(user, move, t) > 0 }
        next if targets.empty?
      elsif move.id == :PARTINGSHOT
        targets = opponents.reject do |target|
          reflected = target.effects[PBEffects::MagicCoat] ||
                      (target.hasActiveAbility?(:MAGICBOUNCE) && !AdvancedAI::Utilities.ignores_ability?(user, move, target))
          reflected || AdvancedAI::Utilities.soundproof_immune?(user, target, move) ||
            aai_disruption_fails?(:PARTINGSHOT, user, target)
        end
        next if targets.empty?
      end
      value = 25
      if move.damagingMove? && targets.any? { |t| Effectiveness.super_effective?(AdvancedAI::CombatUtilities.move_type_effectiveness(move, user, t)) }
        value += 10
      end
      value += 15 if move.id == :PARTINGSHOT
      bonus = [bonus, value].max
    end
    bonus
  end

  #=============================================================================
  # RECOVERY MOVE TIMING
  #=============================================================================
  
  # Determine if recovery move should be used instead of attacking/switching
  # Called from Move_Scorer when evaluating recovery moves
  def should_use_recovery_move?(user, recovery_move, skill)
    return false unless user && recovery_move
    return false if skill < 50  # Low skill AI doesn't optimize recovery
    
    hp_percent = user.hp.to_f / user.totalhp
    
    # Don't heal if healthy (>75% HP)
    return false if hp_percent > 0.75
    
    # Always heal if critical (<25% HP) and not slower than opponent
    if hp_percent < 0.25
      @battle.allOtherSideBattlers(user.index).each do |opponent|
        next unless opponent && !opponent.fainted?
        
        # If opponent outspeeds us and can OHKO, don't waste turn healing
        if opponent.pbSpeed > user.pbSpeed
          opponent.moves.each do |move|
            next unless move && move.damagingMove?
            
            # Rough damage estimate
            damage_percent = estimate_incoming_damage_percent(user, move, opponent)
            return false if damage_percent >= hp_percent * 100  # Would die anyway
          end
        end
      end
      
      # Safe to heal - no immediate OHKO threat or we're faster
      return true
    end
    
    # Moderate HP (25-50%) - heal if opponent can 2HKO
    if hp_percent < 0.50
      can_2hko = false
      
      @battle.allOtherSideBattlers(user.index).each do |opponent|
        next unless opponent && !opponent.fainted?
        
        opponent.moves.each do |move|
          next unless move && move.damagingMove?
          
          damage_percent = estimate_incoming_damage_percent(user, move, opponent)
          if damage_percent >= 45  # Would be 2HKO'd
            can_2hko = true
            break
          end
        end
        break if can_2hko
      end
      
      return true if can_2hko  # Heal to avoid 2HKO range
    end
    
    # Moderate HP (50-75%) - heal if we're stalling (status damage, weather, etc.)
    if hp_percent < 0.75
      # Check if we're benefiting from stall tactics
      stall_benefits = 0
      
      # Toxic/Burn on opponent
      @battle.allOtherSideBattlers(user.index).each do |opponent|
        next unless opponent && !opponent.fainted?
        stall_benefits += 1 if [:BURN, :POISON].include?(opponent.status)
      end
      
      # Leech Seed (check if any OPPONENT is seeded — that benefits us)
      @battle.allOtherSideBattlers(user.index).each do |opponent|
        next unless opponent && !opponent.fainted?
        stall_benefits += 1 if opponent.effects[PBEffects::LeechSeed] >= 0
      end
      
      # Leftovers
      stall_benefits += 1 if user.item_id == :LEFTOVERS
      
      # Weather damage to opponent
      weather = @battle.pbWeather
      hail_chips = !defined?(Settings::HAIL_WEATHER_TYPE) || Settings::HAIL_WEATHER_TYPE == 0
      if weather == :Sandstorm || (weather == :Hail && hail_chips)
        @battle.allOtherSideBattlers(user.index).each do |opponent|
          next unless opponent && !opponent.fainted?
          # Check type immunities for weather chip damage
          weather_hurts = case weather
                          when :Sandstorm
                            !opponent.pbHasType?(:ROCK) && !opponent.pbHasType?(:GROUND) && !opponent.pbHasType?(:STEEL)
                          when :Hail
                            !opponent.pbHasType?(:ICE)
                          else false
                          end
          stall_benefits += 1 if weather_hurts
        end
      end
      
      return true if stall_benefits >= 2  # Multiple stall advantages
    end
    
    false  # Don't heal by default
  end
  
  # Quick damage estimate for recovery timing (simpler than full calc)
  def estimate_incoming_damage_percent(defender, move, attacker)
    return 0 unless move && attacker && defender
    ratio = AdvancedAI::CombatUtilities.estimate_damage(
      attacker, move, defender, as_percent: true
    )
    (ratio * 100).round
  end
  
end

AdvancedAI.log("Switch Intelligence loaded", "Switch")
AdvancedAI.log("  - Sacrifice play logic", "Switch")
AdvancedAI.log("  - Setup move detection", "Switch")
AdvancedAI.log("  - Speed tier awareness", "Switch")
AdvancedAI.log("  - Ability/Item-aware damage calc", "Switch")
