#===============================================================================
# Advanced AI System - Core Battle AI Integration
# Hooks into Pokemon Essentials v21.1 AI system
#===============================================================================

# RGSS/mkxp does not provide Ruby's pp library.
module Kernel
  def pp(*args)
    return nil if args.empty?
    args.each { |a| p a }
    return args.length == 1 ? args[0] : args
  end
  module_function :pp
end

#===============================================================================
# AIMove Delegate Patches - Add missing method delegates from Battle::Move
# so that Advanced AI scorers can call move.pp, move.power, etc. on AIMove
#===============================================================================
class Battle::AI::AIMove
  def pp;            return @move.respond_to?(:pp) ? @move.pp : 0;                   end
  def total_pp;      return @move.respond_to?(:total_pp) ? @move.total_pp : 0;       end
  def power;         return @move.respond_to?(:power) ? @move.power : 0;             end
  def priority;      return @move.respond_to?(:priority) ? @move.priority : 0;       end
  def addlEffect;    return @move.respond_to?(:addlEffect) ? @move.addlEffect : 0;   end
  def accuracy;      return @move.respond_to?(:accuracy) ? @move.accuracy : 100;     end
  def category;      return @move.respond_to?(:category) ? @move.category : 0;       end
  def flags;         return @move.respond_to?(:flags) ? @move.flags : [];             end
  def contactMove?;  return @move.respond_to?(:contactMove?) ? @move.contactMove? : false;    end
  def soundMove?;    return @move.respond_to?(:soundMove?) ? @move.soundMove? : false;        end
  def flinchingMove?; return @move.respond_to?(:flinchingMove?) ? @move.flinchingMove? : false; end
  def multiHitMove?; return @move.respond_to?(:multiHitMove?) ? @move.multiHitMove? : false;  end
  def recoilMove?;   return @move.respond_to?(:recoilMove?) ? @move.recoilMove? : false;      end
  def bitingMove?;   return @move.respond_to?(:bitingMove?) ? @move.bitingMove? : false;      end
  def punchingMove?; return @move.respond_to?(:punchingMove?) ? @move.punchingMove? : false;  end
  def slicingMove?;  return @move.respond_to?(:slicingMove?) ? @move.slicingMove? : false;    end
  def pulseMove?;    return @move.respond_to?(:pulseMove?) ? @move.pulseMove? : false;        end
  def pbNumHits(*args); return @move.respond_to?(:pbNumHits) ? @move.pbNumHits(*args) : 1;    end
end

class Battle::AI
  attr_accessor :move_memory
  attr_accessor :threat_cache
  attr_accessor :switch_analyzer
  
  alias_method :aai_initialize, :initialize unless method_defined?(:aai_initialize) || private_method_defined?(:aai_initialize)
  def initialize(battle)
    aai_initialize(battle)
    @move_memory = {}      # Track opponent move usage
    @threat_cache = {}     # Cache threat assessments
    @switch_analyzer = {}  # Analyze switch opportunities
    @type_effectiveness_cache = {}  # Cache type effectiveness calculations for performance
  end
  
  # Clear caches when battle ends (memory management)
  def clear_caches
    @type_effectiveness_cache&.clear
    @threat_cache&.clear
  end
  
  # Enhanced move scoring with Advanced AI integration
  # Note: This hooks into the DBK AI scoring system which calls pbGetMoveScore
  # with different signatures depending on context
  alias_method :aai_pbGetMoveScore, :pbGetMoveScore unless method_defined?(:aai_pbGetMoveScore) || private_method_defined?(:aai_pbGetMoveScore)
  def pbGetMoveScore(*args)
    explicit_targets = args[0].is_a?(Array)
    targets = explicit_targets ? args[0].compact : []
    target = targets.first
    if !explicit_targets && @user
      target = @battle.allOtherSideBattlers(@user.index).find { |b| b && !b.fainted? }
    end
    
    # Get skill from trainer OR wild Pokemon setting
    if @trainer && !@battle.wildBattle?
      # Check for debug menu skill override
      skill = (@trainer.instance_variable_get(:@aai_skill_override) rescue nil) || @trainer.skill
    else
      # Wild Pokemon - check if AI is enabled
      return aai_pbGetMoveScore(*args) unless AdvancedAI::ENABLE_WILD_POKEMON_AI
      skill = AdvancedAI::WILD_POKEMON_SKILL_LEVEL
      # If skill is 0, use vanilla random behavior
      return aai_pbGetMoveScore(*args) if skill == 0
    end
    
    unless AdvancedAI.qualifies_for_advanced_ai?(skill)
      return aai_pbGetMoveScore(*args)
    end

    return aai_pbGetMoveScore(*args) unless @move
    return aai_pbGetMoveScore(*args) if explicit_targets && targets.empty?

    scoring_targets = explicit_targets ? targets : [target]
    if scoring_targets.all? { |t| aai_sleep_clause_blocks?(t) }
      return MOVE_USELESS_SCORE
    end
    mirror_move = @move.move if @move.function_code == "UseLastMoveUsedByTarget"
    mirror_target = @target
    scores = []
    target_data = @move.pbTarget(@user.battler) rescue nil
    @_resolved_skill = skill
    begin
      scoring_targets.each do |current_target|
        if mirror_move
          set_up_move_check(mirror_move)
          set_up_move_check_target(current_target)
        end
        next if aai_sleep_clause_blocks?(current_target)
        next if current_target && aai_move_fails_against_target?(current_target)
        @_resolved_target = current_target
        @_resolved_targets = current_target ? [current_target] : []
        current_score = pbRegisterMove(@user, @move)
        current_score = apply_advanced_modifiers(current_score, @move, @user, current_target, skill)
        if current_target && target_data && target_data.targets_foe &&
           !current_target.opposes?(@user) && current_target.index != @user.index
          current_score = ((1.85 * MOVE_BASE_SCORE) - current_score).to_i
        end
        scores << current_score
      end
    ensure
      @move.set_up(mirror_move) if mirror_move
      @target = mirror_target if mirror_move
      @_resolved_target = nil
      @_resolved_targets = nil
      @_resolved_skill = nil
    end
    if scores.empty?
      begin
        return aai_pbGetMoveScore(*args)
      ensure
        @move.set_up(mirror_move) if mirror_move
        @target = mirror_target if mirror_move
      end
    end

    score = scores.inject(0) { |sum, value| sum + value } / scores.length
    if scores.length > 1 && @trainer && @trainer.has_skill_flag?("PreferMultiTargetMoves")
      score += (scores.length - 1) * 10
    end
    
    # === DEBUG: Per-factor move score breakdown ===
    if AdvancedAI::DEBUG_MODE && @_score_factors && !@_score_factors.empty?
      move_name = @move.name rescue @move.id.to_s
      target_name = target.name rescue "???"
      user_name = @user.name rescue "???"
      actual_base = @_actual_base_score || 100
      echoln "  ┌─ MOVE SCORE: #{move_name} (#{user_name} vs #{target_name}) ─┐"
      echoln "    Base Score:                  #{actual_base}"
      @_score_factors.each do |name, value|
        next if value == 0
        sign = value >= 0 ? "+" : "-"
        padded_name = "#{sign} #{name}:".ljust(33)
        formatted_val = value >= 0 ? "+#{value}" : "#{value}"
        echoln "    #{padded_name}#{formatted_val}"
      end
      echoln "    ─────────────────────────────────"
      echoln "    = Final Score:               #{score}"
      echoln "  └───────────────────────────────────┘"
    end
    @_score_factors = nil
    
    return score
  end
  
  private

  def aai_sleep_clause_blocks?(target)
    return false unless AdvancedAI::ENFORCE_SLEEP_CLAUSE && @move && @user && target
    return false unless target.opposes?(@user) && @move.statusMove?
    return false unless @move.function_code.start_with?("SleepTarget")
    @battle.pbParty(target.index).any? { |p| p && !p.egg? && !p.fainted? && p.status == :SLEEP }
  end

  def aai_move_fails_against_target?(target)
    ai_target = @battlers[target.index]
    return false unless ai_target
    saved_target = @target
    begin
      @target = ai_target
      @target.refresh_battler
      return pbPredictMoveFailureAgainstTarget
    ensure
      @target = saved_target
    end
  rescue => e
    AdvancedAI.log("Failure-against-target check errored: #{e.class}: #{e.message}", "Core")
    return false
  end

  def apply_advanced_modifiers(score, move, user, target, skill)
    factors = @_score_factors  # May be nil if not debugging
    
    # Core Systems (50+)
    if AdvancedAI.feature_enabled?(:core, skill)
      if target
        pre = score; score = apply_move_memory(score, move, user, target)
        factors["Move Memory"] = score - pre if factors && score != pre
        
        pre = score; score = apply_threat_assessment(score, move, user, target)
        factors["Threat Assessment"] = score - pre if factors && score != pre
        
        pre = score; score = apply_field_effects(score, move, user, target)
        factors["Field Effects"] = score - pre if factors && score != pre
      end
      if @battle.pbSideSize(0) > 1 && target
        pre = score; score = apply_doubles_coordination(score, move, user, target, skill)
        factors["Doubles Coordination"] = score - pre if factors && score != pre
      end
    end
    
    # Setup Recognition (55+)
    if AdvancedAI.feature_enabled?(:setup, skill) && AdvancedAI.tier_feature(skill, :setup_detection) && target
      pre = score; score = apply_setup_evaluation(score, move, user, target)
      factors["Setup Recognition"] = score - pre if factors && score != pre
    end
    
    # Endgame Scenarios (60+)
    if AdvancedAI.feature_enabled?(:endgame, skill) && target
      pre = score; score = apply_endgame_logic(score, move, user, target)
      factors["Endgame Logic"] = score - pre if factors && score != pre
    end
    
    # Battle Personalities (65+)
    if AdvancedAI.feature_enabled?(:personalities, skill) && target
      pre = score; score = apply_personality_modifiers(score, move, user, target)
      factors["Personality"] = score - pre if factors && score != pre
    end
    
    # Strategic Awareness (70+) — archetype counters, win condition shifts,
    # coverage gaps, sacking, collective health, threat persistence, cores
    if skill >= 70 && target
      pre = score; score = apply_strategic_awareness(score, move, user, target, skill)
      factors["Strategic Awareness"] = score - pre if factors && score != pre
    end
    
    # Tactical Enhancements (50+) — ability/item/move awareness, multi-turn planning
    if skill >= 50 && target
      pre = score; score = apply_tactical_enhancements(score, move, user, target, skill)
      factors["Tactical Enhancements"] = score - pre if factors && score != pre
    end
    
    # Item Intelligence (85+)
    if AdvancedAI.feature_enabled?(:items, skill) && target
      pre = score; score = apply_item_intelligence(score, move, user, target)
      factors["Item Intelligence"] = score - pre if factors && score != pre
    end
    
    # Prediction System (85+)
    if AdvancedAI.feature_enabled?(:prediction, skill)
      if target
        pre = score; score = apply_prediction_logic(score, move, user, target)
        factors["Prediction"] = score - pre if factors && score != pre
      end
    end
    
    return score
  end
  
  # Placeholder methods — overridden by their respective module files
  # These stubs ensure the pipeline works even if a module isn't loaded
  def apply_move_memory(score, move, user, target)
    return score  # Overridden in Move_Memory.rb
  end
  
  def apply_threat_assessment(score, move, user, target)
    return score  # Overridden in Threat_Assessment.rb
  end
  
  def apply_field_effects(score, move, user, target)
    return score  # Overridden in Field_Effects.rb
  end
  
  def apply_doubles_coordination(score, move, user, target, skill = 100)
    return score  # Overridden in Doubles_Coordination.rb
  end
  
  def apply_setup_evaluation(score, move, user, target)
    return score  # Overridden in Setup_Recognition.rb
  end
  
  def apply_endgame_logic(score, move, user, target)
    return score  # Overridden in Endgame_Scenarios.rb
  end
  
  def apply_personality_modifiers(score, move, user, target)
    return score  # Overridden in Battle_Personalities.rb
  end
  
  def apply_strategic_awareness(score, move, user, target, skill = 100)
    return score  # Overridden in Strategic_Awareness.rb
  end
  
  def apply_tactical_enhancements(score, move, user, target, skill = 100)
    return score  # Overridden in Tactical_Enhancements.rb
  end
  
  def apply_item_intelligence(score, move, user, target)
    return score  # Overridden in Item_Intelligence.rb
  end
  
  def apply_prediction_logic(score, move, user, target)
    return score  # Overridden in Prediction_System.rb
  end
end

#===============================================================================
# Enhanced Switch Intelligence Integration
#===============================================================================
# Registers Advanced AI switch handler with Essentials AI system
# This gets checked FIRST before vanilla switch handlers
#===============================================================================

Battle::AI::Handlers::ShouldSwitch.add(:advanced_ai_switch_intelligence,
  proc { |battler, reserves, ai, battle|
    skill = if ai.trainer
              ai.trainer.skill
            elsif battle.wildBattle?
              AdvancedAI::WILD_POKEMON_SKILL_LEVEL
            else
              100
            end
    dbg = AdvancedAI::DEBUG_SWITCH_INTELLIGENCE
    
    # Wild Pokemon: respect ENABLE_WILD_POKEMON_AI setting
    if battle.wildBattle? && !AdvancedAI::ENABLE_WILD_POKEMON_AI
      next false
    end
    
    # Respect UsePokemonInOrder — skip advanced switch analysis
    if ai.trainer && ai.trainer.has_skill_flag?("UsePokemonInOrder")
      next false
    end
    
    if dbg
      echoln "========================================"
      echoln "=== ADVANCED AI SWITCH ANALYSIS ==="
      echoln "  Pokemon: #{battler.name}"
      echoln "  Trainer Skill: #{skill}"
      echoln "  Reserves Available: #{reserves.length}"
      
      # DEBUG: Show which Pokemon are in reserves and which are filtered
      party = battle.pbParty(battler.index & 1)
      echoln "  --- PARTY COMPOSITION DEBUG ---"
      party.each_with_index do |pkmn, i|
        next if !pkmn
        is_active = battle.pbFindBattler(i, battler.index)
        in_reserves = reserves.any? { |reserve_pkmn| reserve_pkmn == pkmn }
        can_switch = battle.pbCanSwitchIn?(battler.index, i)
        
        status = []
        status << "ACTIVE" if is_active
        status << "IN_RESERVES" if in_reserves
        status << "CANNOT_SWITCH (pbCanSwitchIn? = false)" if !can_switch
        status << "FAINTED" if pkmn.fainted?
        status << "EGG" if pkmn.egg?
        
        echoln "    [#{i}] #{pkmn.name}: #{status.join(', ')}"
      end
      
      # Check if Challenge Modes is filtering
      if defined?(ChallengeModes) && ChallengeModes.respond_to?(:on?)
        echoln "  --- CHALLENGE MODES STATUS ---"
        echoln "    Monotype Mode: #{ChallengeModes.on?(:MONOTYPE_MODE)}"
        echoln "    Randomizer Mode: #{ChallengeModes.on?(:RANDOMIZER_MODE)}"
      end
      echoln "  --- END DEBUG ---"
    end
    
    qualifies = AdvancedAI.qualifies_for_advanced_ai?(skill)
    if dbg
      echoln "  Qualifies for Advanced AI? #{qualifies}"
    end
    
    if !qualifies
      if dbg
        echoln "  >>> NOT qualified (need skill 50+)"
        echoln "=============================="
      end
      next false
    end
    
    feature_enabled = AdvancedAI.feature_enabled?(:switch_intelligence, skill)
    if dbg
      echoln "  Switch Intelligence enabled? #{feature_enabled}"
    end
    
    if !feature_enabled
      if dbg
        echoln "  >>> Feature not enabled for this skill level"
        echoln "=============================="
      end
      next false
    end
    
    echoln "  >>> Checking switch logic..." if dbg
    
    result = false
    begin
      # should_switch_advanced? expects the real battler, not its AI wrapper.
      if ai.respond_to?(:should_switch_advanced?)
        real_battler = battler.respond_to?(:battler) ? battler.battler : battler
        result = ai.should_switch_advanced?(real_battler, skill)
        
        if dbg
          if result
            echoln ""
            echoln "  ✅ RESULT: SHOULD SWITCH!"
            echoln "=============================="
          else
            echoln ""
            echoln "  ❌ RESULT: Stay in battle"
            echoln "=============================="
          end
        end
      else
        if dbg
          echoln "  ⚠️ ERROR: should_switch_advanced? not found"
          echoln "=============================="
        end
      end
    rescue => e
      AdvancedAI.log("Core error: #{e.class}: #{e.message}", "Switch")
      AdvancedAI.log(e.backtrace.first(3).join("\n"), "Switch")
      result = false
    end
    
    next result
  }
)

#===============================================================================
# Override replacement Pokemon selection to use Advanced AI logic
#===============================================================================
class Battle::AI
  # Mark engine-requested replacements so stay-in heuristics cannot cancel them.
  alias_method :aai_pbDefaultChooseNewEnemy, :pbDefaultChooseNewEnemy unless method_defined?(:aai_pbDefaultChooseNewEnemy) || private_method_defined?(:aai_pbDefaultChooseNewEnemy)
  def pbDefaultChooseNewEnemy(idxBattler)
    @aai_forced_replacement = true
    begin
      return aai_pbDefaultChooseNewEnemy(idxBattler)
    ensure
      @aai_forced_replacement = false
    end
  end

  # True when every move the user could pick is predicted to do nothing at all.
  def aai_all_moves_dead?(user)
    battler = user.battler
    return false unless battler
    foes = @battle.allOtherSideBattlers(user.index).select { |b| b && !b.fainted? }
    return false if foes.empty?
    saved_target = @target
    begin
      battler.eachMoveWithIndex do |m, i|
        next if !@battle.pbCanChooseMove?(user.index, i, false)
        set_up_move_check(m)
        next if pbPredictMoveFailure
        works_somewhere = foes.any? do |f|
          ai_f = @battlers[f.index]
          next false unless ai_f
          @target = ai_f
          !pbPredictMoveFailureAgainstTarget
        end
        return false if works_somewhere
      end
      return true
    rescue
      return false
    ensure
      @target = saved_target
    end
  end

  alias_method :aai_choose_best_replacement_pokemon, :choose_best_replacement_pokemon unless method_defined?(:aai_choose_best_replacement_pokemon) || private_method_defined?(:aai_choose_best_replacement_pokemon)
  def choose_best_replacement_pokemon(idxBattler, terrible_moves = false)
    begin
      # Inspect the last move for forced paths that bypass pbDefaultChooseNewEnemy.
      mandatory_switch = (@aai_forced_replacement == true)
      begin
        if !mandatory_switch && @user
          if @user.respond_to?(:fainted?) && @user.fainted?
            mandatory_switch = true
          elsif @user.battler
            last_move = @user.battler.lastMoveUsed
            if last_move
              move_data = GameData::Move.try_get(last_move)
              if move_data
                fc = move_data.function_code
                pivot_ids = (defined?(AdvancedAI::PivotMoves::ALL_PIVOTS) ? AdvancedAI::PivotMoves::ALL_PIVOTS : [])
                if pivot_ids.include?(move_data.id) ||
                   ["SwitchOutUserDamagingMove",       # U-turn/Volt Switch/Flip Turn
                    "SwitchOutUserPassOnEffects",      # Baton Pass
                    "SwitchOutUserStatDownTarget",     # Parting Shot
                    "SwitchOutUserHealReplacement",    # Teleport (Gen 8+)
                    "SwitchOutUserAndChangeWeather",   # Chilly Reception
                    "SwitchOutUserPassOnSubstitute"    # Shed Tail
                   ].include?(fc)
                  mandatory_switch = true
                end
              end
            end
          end
        end
      rescue
        # Never downgrade a committed forced replacement to "optional".
        mandatory_switch ||= (@aai_forced_replacement == true)
      end
      
      # Wild Pokemon: respect ENABLE_WILD_POKEMON_AI setting
      if @battle.wildBattle? && !AdvancedAI::ENABLE_WILD_POKEMON_AI
        return aai_choose_best_replacement_pokemon(idxBattler, terrible_moves)
      end
      
      # Respect UsePokemonInOrder flag — vanilla already handles party-order selection
      if @trainer && @trainer.has_skill_flag?("UsePokemonInOrder")
        return aai_choose_best_replacement_pokemon(idxBattler, terrible_moves)
      end
      
      skill = if @trainer
                (@trainer.instance_variable_get(:@aai_skill_override) rescue nil) || @trainer.skill
              elsif @battle.wildBattle?
                AdvancedAI::WILD_POKEMON_SKILL_LEVEL
              else
                100
              end
      dbg = AdvancedAI::DEBUG_SWITCH_INTELLIGENCE
      
      if dbg
        echoln "========================================"
        echoln "=== CHOOSING REPLACEMENT POKEMON ==="
        echoln "  Current: #{@user.name}"
        echoln "  Trainer Skill: #{skill}"
        echoln "  Forced Switch: #{terrible_moves}"
      end
      
      # Avoid immediate switch-backs caused by low-scoring stall moves.
      # Mandatory switches and movesets that cannot affect a foe are exempt.
      if !mandatory_switch && terrible_moves && @user.turnCount < 2 && !@user.fainted? &&
         !aai_all_moves_dead?(@user)
        if dbg
          echoln "  >>> Anti-ping-pong: #{@user.name} just switched in (turn #{@user.turnCount})"
          echoln "  >>> Staying to use available moves instead of switching"
          echoln "========================================"
        end
        return -1
      end
      
      # Keep stall sets in while their passive-damage plan is active.
      if !mandatory_switch && terrible_moves && !@user.fainted? && AdvancedAI.has_stall_moveset?(@user)
        stall_working = false
        @battle.allOtherSideBattlers(@user.index).each do |target|
          next unless target && !target.fainted?
          leech_seed_val = (target.effects[PBEffects::LeechSeed] rescue -1)
          if target.poisoned? || target.burned? ||
             (leech_seed_val.is_a?(Numeric) && leech_seed_val >= 0)
            stall_working = true
            break
          end
        end
        
        if stall_working
          if dbg
            echoln "  >>> Stall Archetype: #{@user.name} has active stall gameplan"
            echoln "  >>> Staying to continue stalling (passive damage ticking)"
            echoln "========================================"
          end
          return -1
        end
        
        # Even without active status, stall mons with recovery should stay
        has_recovery = @user.battler.moves.any? do |m|
          m && AdvancedAI.healing_move?(m.id)
        end
        has_useful_status = @user.battler.moves.any? do |m|
          next false unless m
          [:TOXIC, :WILLOWISP, :THUNDERWAVE, :LEECHSEED, :SCALD].include?(m.id)
        end
        if has_recovery && has_useful_status
          if dbg
            echoln "  >>> Stall Archetype: #{@user.name} has recovery + status moves"
            echoln "  >>> Staying to execute stall strategy"
            echoln "========================================"
          end
          return -1
        end
      end
      
      qualifies = AdvancedAI.qualifies_for_advanced_ai?(skill)
      feature_enabled = AdvancedAI.feature_enabled?(:switch_intelligence, skill)
      
      if dbg
        echoln "  Qualifies for Advanced AI? #{qualifies}"
        echoln "  Switch Intelligence enabled? #{feature_enabled}"
      end
      
      # Use Advanced AI switch logic if qualified
      if qualifies && feature_enabled
        echoln "  >>> Using Advanced AI selection..." if dbg
        
        # Call our advanced switch finder from [012] Switch_Intelligence.rb
        # send bypasses the helper's visibility.
        best_idx = send(:find_best_switch_advanced, @user, skill, terrible_moves)
        if best_idx && @battle.pbCanSwitchIn?(idxBattler, best_idx)
          party = @battle.pbParty(idxBattler)
          best_pkmn = party[best_idx]
          if dbg
            echoln ""
            echoln "  ✅ SELECTED: #{best_pkmn.name} (Party Index: #{best_idx})"
            echoln "=============================="
          end
          return best_idx
        end
        AdvancedAI.log("No suitable advanced switch found, falling back to vanilla", "Switch")
      end
    rescue => e
      AdvancedAI.log("Error: #{e.class}: #{e.message}", "Switch")
      AdvancedAI.log(e.backtrace.first(3).join("\n"), "Switch")
    end
    
    # Fall back to vanilla logic
    return aai_choose_best_replacement_pokemon(idxBattler, terrible_moves)
  end
end

EventHandlers.add(:on_game_map_setup, :aai_core_loaded,
  proc {
    if defined?(AdvancedAI) && AdvancedAI.respond_to?(:log)
      AdvancedAI.log("Core AI integration loaded with switch intelligence handler", "Core")
    end
  }
)

AdvancedAI.log("Switch intelligence and replacement selector ready", "Core")



#===============================================================================
# Deterministic move selection (opt-in: AdvancedAI::DETERMINISTIC_MOVE_CHOICE)
# Picks the highest score; ties resolve by move index, then target index.
# The terrible-move switch gate also runs without its random roll.
#===============================================================================
class Battle::AI
  alias_method :aai_det_pbChooseMove, :pbChooseMove unless method_defined?(:aai_det_pbChooseMove) || private_method_defined?(:aai_det_pbChooseMove)

  def pbChooseMove(choices)
    return aai_det_pbChooseMove(choices) unless AdvancedAI::ENABLED
    unless (defined?(AdvancedAI::DETERMINISTIC_MOVE_CHOICE) && AdvancedAI::DETERMINISTIC_MOVE_CHOICE)
      return aai_det_pbChooseMove(choices)
    end
    user_battler = @user.battler
    if choices.length == 0
      @battle.pbAutoChooseMove(user_battler.index)
      PBDebug.log_ai("#{@user.name} will auto-use a move or Struggle")
      return
    end
    max_score = 0
    choices.each { |c| max_score = c[1] if max_score < c[1] }
    # Sleeping or frozen battlers do not switch merely because every move is unusable.
    if @trainer.high_skill? && @user.can_switch_lax?
      bad_moves = false
      if max_score <= MOVE_USELESS_SCORE
        bad_moves = @user.can_attack?
      elsif max_score < MOVE_BASE_SCORE * move_score_threshold && user_battler.turnCount > 2
        bad_moves = true
      end
      if bad_moves
        PBDebug.log_ai("#{@user.name} wants to switch due to terrible moves")
        if pbChooseToSwitchOut(true)
          @battle.pbUnregisterMegaEvolution(@user.index)
          return
        end
        PBDebug.log_ai("#{@user.name} won't switch after all")
      end
    end
    # Deterministic pick: highest score, ties -> lowest move index, then target.
    # (DBK's choices carry a 5th element and may have a nil target index.)
    best = choices.min_by { |c| [-c[1], c[0], c[2] || -1] }
    unless best
      @battle.pbAutoChooseMove(user_battler.index)
      PBDebug.log_ai("#{@user.name} deterministic fallback: auto-choosing a move or Struggle")
      return
    end
    # DBK registers a move's gimmick action before registering the move itself.
    if best.length > 4 && best[4] && respond_to?(:pbRegisterEnemySpecialActionFromMove)
      pbRegisterEnemySpecialActionFromMove(user_battler, best[4])
    end
    unless @battle.pbRegisterMove(user_battler.index, best[0], false)
      @battle.pbAutoChooseMove(user_battler.index)
      PBDebug.log_ai("#{@user.name} deterministic fallback: auto-choosing a move or Struggle")
      return
    end
    @battle.pbRegisterTarget(user_battler.index, best[2]) if best[2] && best[2] >= 0
    if $INTERNAL
      mv  = @battle.choices[user_battler.index][2]
      tgt = @battle.choices[user_battler.index][3]
      PBDebug.log("   => will use #{mv.name}" + ((tgt && tgt >= 0) ? " (target #{tgt})" : "") + " [deterministic]") if mv
    end
  end
end

class Battle::AI::AITrainer
  alias_method :aai_settings_set_up_skill, :set_up_skill unless method_defined?(:aai_settings_set_up_skill)
  def set_up_skill
    aai_settings_set_up_skill
    return if @trainer || !@ai.battle.wildBattle?
    return unless AdvancedAI::ENABLED && AdvancedAI::ENABLE_WILD_POKEMON_AI
    skill = AdvancedAI::WILD_POKEMON_SKILL_LEVEL
    @skill = skill if AdvancedAI.active?(skill) || skill == 0
  end
end
