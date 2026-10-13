#===============================================================================
# [019] Setup Recognition - 5 Evaluation Systems
#===============================================================================
# Recognizes Setup Moves and evaluates Counter Strategies
#
# Systems:
# 1. Setup Detection (Swords Dance, Nasty Plot, etc.)
# 2. Setup Threat Assessment (how dangerous is Setup?)
# 3. Counter Priority (Haze, Roar, Encore, etc.)
# 4. Optimal Counter Timing (when to counter?)
# 5. Setup Chain Detection (Baton Pass chains)
#===============================================================================

module AdvancedAI
  module SetupRecognition
    
    #===========================================================================
    # Setup Counter Moves
    #===========================================================================
    SETUP_COUNTERS = {
      # Phazing (forced switch)
      :ROAR         => { type: :phaze, priority: -6, bypasses_sub: true },
      :WHIRLWIND    => { type: :phaze, priority: -6, bypasses_sub: true },
      :DRAGONTAIL   => { type: :phaze, priority: -6, damage: true },
      :CIRCLETHROW  => { type: :phaze, priority: -6, damage: true },
      
      # Stat Reset
      :HAZE         => { type: :reset, affects: :all },
      :CLEARSMOG    => { type: :reset, affects: :target, damage: true },
      
      # Disruption
      :ENCORE       => { type: :lock, duration: 3 },
      :TAUNT        => { type: :block, duration: 3, status_only: true },
      :DISABLE      => { type: :block, duration: 4, last_move: true },
      :TORMENT      => { type: :lock, no_repeat: true },
      
      # Stat Copying
      :PSYCHUP      => { type: :copy, positive_only: true },
      :SPECTRALTHIEF => { type: :steal, damage: true },
      
      # Punishment (stronger vs boosted)
      :PUNISHMENT   => { type: :punish, max_power: 200 },
      :STOREDPOWER  => { type: :reward, max_power: 860 },
    }
    
    #===========================================================================
    # Setup Detection
    #===========================================================================
    
    # Detects if Battler has setup (stat boosts)
    def self.has_setup?(battler)
      return false if !battler
      
      # Check for positive stat stages
      [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, 
       :SPEED, :ACCURACY, :EVASION].each do |stat|
        return true if battler.stages[stat] > 0
      end
      
      return false
    end
    
    # Counts Setup Stages
    def self.count_setup_stages(battler)
      return 0 if !battler
      
      total = 0
      [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, 
       :SPEED, :ACCURACY, :EVASION].each do |stat|
        total += battler.stages[stat] if battler.stages[stat] > 0
      end
      
      return total
    end
    
    # Checks if Pokemon recently used setup move
    def self.recently_setup?(battle, battler)
      return false if !battle || !battler
      return false if !AdvancedAI.feature_enabled?(:setup, 100)
      
      # Check Move Memory
      memory = AdvancedAI.get_memory(battle, battler)
      return false if !memory
      
      last_move = memory[:last_move]
      return false if !last_move
      
      return AdvancedAI.setup_move?(last_move)
    end
    
    #===========================================================================
    # Setup Threat Assessment
    #===========================================================================
    
    # Evaluates Setup Threat (0-10 Scale)
    def self.assess_setup_threat(battle, attacker, defender)
      return 0.0 if !battle || !attacker || !defender
      
      threat = 0.0
      
      # 1. Number of Setup Stages (+0.5 per Stage)
      stages = count_setup_stages(attacker)
      threat += stages * 0.5
      
      # 2. Type of Boosts
      if attacker.stages[:ATTACK] >= 2 || attacker.stages[:SPECIAL_ATTACK] >= 2
        threat += 2.0  # Offensive threat
      end
      
      if attacker.stages[:SPEED] >= 2
        threat += 1.5  # Speed threat (hard to stop)
      end
      
      if attacker.stages[:EVASION] >= 1
        threat += 2.0  # Evasion = very annoying
      end
      
      # 3. Pokemon Quality
      # High Base Stat = more dangerous with Boosts
      if attacker.attack >= 120 || attacker.spatk >= 120
        threat += 1.0
      end
      
      if attacker.speed >= 100
        threat += 1.0
      end
      
      # 4. Coverage Moves
      known_moves = AdvancedAI.get_memory(battle, attacker)
      if known_moves && known_moves[:moves]
        coverage_count = 0
        known_moves[:moves].each do |move_id|
          move = GameData::Move.try_get(move_id)
          next if !move || move.power == 0  # skip status moves (GameData::Move has no .statusMove?)
          coverage_count += 1
        end
        
        threat += coverage_count * 0.3  # More Coverage = more dangerous
      end
      
      # 5. Sweep Potential
      if defender.hp < defender.totalhp * 0.5
        threat += 1.5  # Defender weak = higher danger
      end
      
      # Team has no counters left? Use side index (defender.index & 1 gives 0 or 1)
      remaining_pokemon = battle.pbAbleNonActiveCount(defender.index & 1)
      if remaining_pokemon <= 1
        threat += 2.0  # Last Pokemon = critical
      end
      
      # Cap at 10.0
      threat = [threat, 10.0].min
      
      return threat
    end
    
    #===========================================================================
    # Counter Priority System
    #===========================================================================
    
    # Finds best Setup Counter Move
    def self.find_best_counter(battle, user, target)
      return nil if !battle || !user || !target
      
      best_move = nil
      best_score = 0
      
      user.moves.each_with_index do |move, index|
        next if !move || move.pp <= 0
        next unless battle.pbCanChooseMove?(user.index, index, false)
        next if AdvancedAI::Utilities.counter_shield_blocked?(battle, move, user, target)
        move_id = move.id
        
        # Phazing Moves (Roar, Whirlwind)
        if [:ROAR, :WHIRLWIND, :DRAGONTAIL, :CIRCLETHROW].include?(move_id)
          next unless AdvancedAI::Utilities.phazing_possible?(battle, move, user, target)
          score = 100

          # More points if many boosts
          score += count_setup_stages(target) * 10
          
          if score > best_score
            best_score = score
            best_move = move_id
          end
        end
        
        # Haze (reset all stats)
        if move_id == :HAZE
          next if count_setup_stages(target) <= 0
          next unless AdvancedAI::Utilities.stat_reset_hits_target?(battle, move, user, target)
          score = 90
          score += count_setup_stages(target) * 10
          
          if score > best_score
            best_score = score
            best_move = move_id
          end
        end
        
        # Clear Smog (reset + damage)
        if move_id == :CLEARSMOG
          next if count_setup_stages(target) <= 0
          next unless AdvancedAI::Utilities.stat_reset_hits_target?(battle, move, user, target)
          score = 85
          score += count_setup_stages(target) * 10
          
          # Type effectiveness (handle both Battler and Pokemon)
          resolved_type = AdvancedAI::CombatUtilities.resolve_move_type(user, move)
          effectiveness = AdvancedAI::Utilities.type_mod(resolved_type, target)
          score += 20 if Effectiveness.super_effective?(effectiveness)
          score -= 20 if Effectiveness.not_very_effective?(effectiveness)
          
          if score > best_score
            best_score = score
            best_move = move_id
          end
        end
        
        # Encore (lock into last move)
        if move_id == :ENCORE
          next unless AdvancedAI::Utilities.setup_disruption_hits?(battle, move, user, target)
          score = 80
          
          # Very good if target used setup move
          if recently_setup?(battle, target)
            score += 40
          end
          
          if score > best_score
            best_score = score
            best_move = move_id
          end
        end
        
        # Taunt (prevent status moves)
        if move_id == :TAUNT
          next unless AdvancedAI::Utilities.setup_disruption_hits?(battle, move, user, target)
          score = 70
          
          # Good against Support Pokemon
          roles = AdvancedAI.detect_roles(target)
          score += 30 if roles.include?(:support)
          
          if score > best_score
            best_score = score
            best_move = move_id
          end
        end
      end
      
      return best_move
    end
    
    #===========================================================================
    # Optimal Counter Timing
    #===========================================================================
    
    # Determines if we should counter NOW
    def self.should_counter_now?(battle, user, target, skill_level)
      return false if !battle || !user || !target
      
      # Setup threat
      threat = assess_setup_threat(battle, target, user)
      
      # Thresholds based on skill
      threshold = case skill_level
      when 100 then 4.0   # Master: Counter early
      when 90  then 5.0   # Expert
      when 80  then 6.0   # Advanced
      when 70  then 7.0   # Skilled
      else 8.0            # Core: Only if extreme danger
      end
      
      # Counter if threat > threshold
      return threat >= threshold
    end
    
    #===========================================================================
    # Baton Pass Chain Detection
    #===========================================================================
    
    # Checks if Team uses Baton Pass chain
    def self.baton_pass_chain?(battle, side_index)
      return false if !battle
      
      baton_pass_count = 0
      setup_move_count = 0
      
      battle.eachInTeamFromBattlerIndex(side_index) do |pokemon, _index|
        next if !pokemon || pokemon.egg? || pokemon.fainted?
        
        ids = pokemon.moves.map(&:id).uniq
        baton_pass_count += 1 if ids.include?(:BATONPASS)
        setup_move_count += ids.count { |id| AdvancedAI.setup_move?(id) }
      end
      
      # Chain if at least 2 Pokemon have Baton Pass
      # AND at least 3 Setup Moves in Team
      return baton_pass_count >= 2 && setup_move_count >= 3
    end
    
    # Priority against Baton Pass chains
    def self.baton_chain_priority(battle, user, move = nil, target = nil, skill = 100)
      return 0 unless battle && user && AdvancedAI.get_setting(:setup_chains, 0) > 0
      return 0 unless AdvancedAI.feature_enabled?(:setup, skill) && AdvancedAI.tier_feature(skill, :setup_detection)
      user = user.battler if user.respond_to?(:battler)
      target = target.battler if target.respond_to?(:battler)
      targets = target ? [target] : battle.allOtherSideBattlers(user).to_a
      bonuses = targets.map do |opponent|
        next 0 unless opponent.opposes?(user) && baton_pass_chain?(battle, opponent.index)
        counter = find_best_counter(battle, user, opponent)
        next 0 unless counter && (!move || move.id == counter)
        [:TAUNT, :ENCORE].include?(counter) ? 20 : 30
      end
      bonuses.max || 0
    end
    
  end
end

#===============================================================================
# API Wrapper
#===============================================================================
module AdvancedAI
  def self.has_setup?(battler)
    SetupRecognition.has_setup?(battler)
  end
  
  def self.count_setup_stages(battler)
    SetupRecognition.count_setup_stages(battler)
  end
  
  def self.assess_setup_threat(battle, attacker, defender)
    SetupRecognition.assess_setup_threat(battle, attacker, defender)
  end
  
  def self.find_best_setup_counter(battle, user, target)
    SetupRecognition.find_best_counter(battle, user, target)
  end
  
  def self.should_counter_setup_now?(battle, user, target, skill_level)
    SetupRecognition.should_counter_now?(battle, user, target, skill_level)
  end
  
  def self.baton_pass_chain?(battle, side_index)
    SetupRecognition.baton_pass_chain?(battle, side_index)
  end
end

#===============================================================================
# Integration in Battle::AI - Wires setup evaluation into scoring pipeline
#===============================================================================
class Battle::AI
  def apply_setup_evaluation(score, move, user, target)
    return score unless move
    skill = @_resolved_skill || @trainer&.skill || 100
    
    real_user = user.respond_to?(:battler) ? user.battler : user
    
    # If opponent has setup boosts, prioritize counter-measures
    if target
      real_target = target.respond_to?(:battler) ? target.battler : target
      if [:ROAR, :WHIRLWIND, :DRAGONTAIL, :CIRCLETHROW, :HAZE, :CLEARSMOG, :ENCORE, :TAUNT].include?(move.id)
        return score if AdvancedAI::Utilities.counter_shield_blocked?(@battle, move, real_user, real_target)
      end
      if [:HAZE, :CLEARSMOG].include?(move.id)
        index = real_user.moves.index { |m| m.id == move.id }
        return score if index && !@battle.pbCanChooseMove?(real_user.index, index, false)
        return score unless real_target.stages.values.any? { |stage| stage > 0 }
        return score unless AdvancedAI::Utilities.stat_reset_hits_target?(@battle, move, real_user, real_target)
      end
      if [:ROAR, :WHIRLWIND, :DRAGONTAIL, :CIRCLETHROW].include?(move.id)
        index = real_user.moves.index { |m| m.id == move.id }
        return score if index && !@battle.pbCanChooseMove?(real_user.index, index, false)
        return score unless AdvancedAI::Utilities.phazing_possible?(@battle, move, real_user, real_target)
      end
      score += AdvancedAI::SetupRecognition.baton_chain_priority(@battle, real_user, move, real_target, skill)
      threat = AdvancedAI.assess_setup_threat(@battle, real_target, real_user)
      
      if threat >= 5.0
        # High threat: boost phaze moves (Roar, Whirlwind, Dragon Tail)
        phaze_moves = [:ROAR, :WHIRLWIND, :DRAGONTAIL, :CIRCLETHROW, :HAZE, :CLEARSMOG]
        if phaze_moves.include?(move.id)
          score += (threat * 5).to_i  # Up to +50 for Haze/phaze vs boosted foe
        end
        
        # Priority moves are great against boosted sweepers
        if move.priority > 0 && move.damagingMove?
          score += (threat * 3).to_i  # Up to +30
        end
      end
      
      if AdvancedAI.should_counter_setup_now?(@battle, real_user, real_target, skill)
        counter_move = AdvancedAI.find_best_setup_counter(@battle, real_user, real_target)
        if counter_move && move.id == counter_move
          score += 25  # Boost the recommended counter move
        end
      end
    end
    
    # Our own setup: boost setup moves if safe
    if AdvancedAI.setup_move?(move.id) && target
      real_target = target.respond_to?(:battler) ? target.battler : target
      # Don't set up if opponent is already boosted and threatening
      opponent_threat = AdvancedAI.assess_setup_threat(@battle, real_target, real_user)
      if opponent_threat >= 6.0
        score -= 20  # Don't set up when opponent is already boosted
      end
    end
    
    return score
  end
end
