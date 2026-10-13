#===============================================================================
# [020] Endgame Scenarios - 1v1/2v2 Logic
#===============================================================================
# Special Strategies for Endgame Situations
#
# Features:
# - 1v1 Optimize (only 1 Pokemon per side left)
# - 2v2 Optimize (2v2 Situation)
# - Winning Move Detection (guaranteed KO)
# - Stall Detection (Play for time)
# - Desperation Moves (Last attempt)
#===============================================================================

module AdvancedAI
  module EndgameScenarios
    
    #===========================================================================
    # Endgame Detection
    #===========================================================================
    
    # Checks if Endgame (≤2 Pokemon per side)
    def self.is_endgame?(battle)
      return false if !battle
      
      # Count remaining Pokemon (active + bench)
      side0_count = battle.pbAbleCount(0)
      side1_count = battle.pbAbleCount(1)
      
      return side0_count <= 2 || side1_count <= 2
    end
    
    # Checks if 1v1 (only 1 Pokemon per side active)
    def self.is_1v1?(battle)
      return false if !battle
      
      side0_count = battle.pbAbleCount(0)
      side1_count = battle.pbAbleCount(1)
      
      return side0_count == 1 && side1_count == 1
    end
    
    # Checks if 2v2 (2 Pokemon per side)
    def self.is_2v2?(battle)
      return false if !battle
      
      side0_count = battle.pbAbleCount(0)
      side1_count = battle.pbAbleCount(1)
      
      return side0_count == 2 && side1_count == 2
    end
    
    #===========================================================================
    # 1v1 Optimization
    #===========================================================================
    
    # Evaluates Move for 1v1
    def self.score_1v1_move(battle, user, target, move, base_score)
      return base_score if !battle || !user || !target || !move
      return base_score if !is_1v1?(battle)
      
      score = base_score
      
      # 1. KO Priority (Winning Move = +100)
      if AdvancedAI.get_setting(:ko_prediction, 0) > 0 && can_ko?(user, target, move)
        AdvancedAI.log("1v1: Move can KO! +100", :endgame)
        score += 100
      # 2. 2HKO Priority (+50)
      elsif AdvancedAI.get_setting(:ko_prediction, 0) > 0 && can_2hko?(user, target, move)
        AdvancedAI.log("1v1: Move can 2HKO! +50", :endgame)
        score += 50
      end
      
      # 3. Speed Control
      trick_room = battle.field.effects[PBEffects::TrickRoom] > 0
      slower = trick_room ? user.pbSpeed > target.pbSpeed : user.pbSpeed < target.pbSpeed
      faster = trick_room ? user.pbSpeed < target.pbSpeed : user.pbSpeed > target.pbSpeed
      if slower
        # Slower = Priority Moves very valuable (attacks only - Protect has
        # priority +4 but never strikes first, score_protect_utility owns it)
        if move.damagingMove? && AdvancedAI::PriorityTiers.get_priority_tier(move, user) > 0 &&
           ko_damage(user, target, move) > 0
          AdvancedAI.log("1v1: Priority move (slower) +60", :endgame)
          score += 60
        end
        
        # Slower = Setup risky
        if AdvancedAI.setup_move?(move.id)
          AdvancedAI.log("1v1: Setup risky (slower) -40", :endgame)
          score -= 40
        end
      elsif faster
        # Faster = Setup safer
        if AdvancedAI.setup_move?(move.id)
          AdvancedAI.log("1v1: Setup safe (faster) +20", :endgame)
          score += 20
        end
      end
      
      # 4. Survival Moves
      if user.hp < user.totalhp * 0.3
        # Protect valuable if weak
        if AdvancedAI.protect_move?(move.id)
          score += 40
        end
        
        # Healing critical
        if AdvancedAI.healing_move?(move.id)
          score += 60
        end
      end
      
      # 5. Status Moves in 1v1
      if move.statusMove?
        # Will-O-Wisp/Thunder Wave very strong
        if [:WILLOWISP, :THUNDERWAVE, :TOXIC].include?(move.id)
          # But only if target doesn't have status yet
          if target.status == :NONE
            score += 40
          end
        end
        
        # Setup = risky but can win
        if AdvancedAI.setup_move?(move.id)
          # +20 if user can survive
          if user.hp > user.totalhp * 0.7
            score += 20
          end
        end
      end
      
      # 6. OHKO Moves (desperate)
      if AdvancedAI.ohko_move?(move.id)
        # Check known immunities before awarding bonus
        immune = false
        immune = true if target.hasActiveAbility?(:STURDY)  # Sturdy = unconditional OHKO immunity
        immune = true if target.level > user.level
        immune = true if move.id == :FISSURE && (target.pbHasType?(:FLYING) || target.hasActiveAbility?(:LEVITATE))
        immune = true if move.id == :SHEERCOLD && target.pbHasType?(:ICE)
        # Focus Sash: target survives OHKO at full HP → attack wastes the turn
        if target.hp == target.totalhp && target.item_id == :FOCUSSASH
          immune = true
        end
        # 30% Chance = better than losing
        score += 80 unless immune
      end
      
      return score
    end
    
    #===========================================================================
    # 2v2 Optimization
    #===========================================================================
    
    # Evaluates Move for 2v2
    def self.score_2v2_move(battle, user, target, move, base_score)
      return base_score if !battle || !user || !target || !move
      return base_score if !is_2v2?(battle)
      
      score = base_score
      
      # 1. Focus Fire (both on weakest target)
      weakest = find_weakest_opponent(battle, user)
      if weakest && target.index == weakest.index
        AdvancedAI.log("2v2: Targeting weakest +40", :endgame)
        score += 40
      end
      
      # 2. Protect Stalling (wait for Partner KO)
      if AdvancedAI.protect_move?(move.id)
        partner = get_partner(battle, user)
        if partner
          # Check if Partner can KO
          partner.moves.each do |partner_move|
            next if !partner_move
            if AdvancedAI.get_setting(:ko_prediction, 0) > 0 && can_ko?(partner, target, partner_move)
              AdvancedAI.log("2v2: Protect for partner KO +50", :endgame)
              score += 50
              break
            end
          end
        end
      end
      
      # 3. Spread Moves less valuable (only 2 targets)
      if AdvancedAI.spread_move?(move.id)
        AdvancedAI.log("2v2: Spread move limited -20", :endgame)
        score -= 20
      end
      
      # 4. Priority for secure KOs
      if AdvancedAI.get_setting(:ko_prediction, 0) > 0 && can_ko?(user, target, move)
        AdvancedAI.log("2v2: Secure KO +80", :endgame)
        score += 80
      end
      
      return score
    end
    
    #===========================================================================
    # Winning Move Detection
    #===========================================================================
    
    # Whether the estimated hit could remove every remaining opposing Pokemon.
    def self.winning_move?(battle, user, move)
      user = user.battler if user.respond_to?(:battler)
      move = move.move if move.respond_to?(:move)
      return false unless battle && user && move && !user.fainted? && move.damagingMove?
      index = user.moves.index { |candidate| candidate.id == move.id }
      return false unless index && battle.pbCanChooseMove?(user.index, index, false)
      opponents = battle.allOtherSideBattlers(user.index).reject(&:fainted?)
      return false if opponents.empty?
      return false if battle.pbAbleCount(1 - (user.index & 1)) > opponents.length
      target_data = move.pbTarget(user)
      return false if opponents.length > 1 && target_data.num_targets <= 1
      opponents.all? do |opponent|
        battle.pbMoveCanTarget?(user.index, opponent.index, target_data) && can_ko?(user, opponent, move)
      end
    end

    # Finds Winning Move (if exists)
    def self.find_winning_move(battle, user)
      return nil if !battle || !user
      
      user.moves.each do |move|
        next if !move || move.pp <= 0
        return move.id if winning_move?(battle, user, move)
      end
      
      return nil
    end
    
    #===========================================================================
    # Stall Detection
    #===========================================================================
    
    # Checks if Stalling makes sense
    def self.should_stall?(battle, user)
      return false if !battle || !user
      
      # Stalling only useful in Endgame
      return false if !is_endgame?(battle)
      
      # Requirements for Stalling:
      # 1. User has Recovery
      # 2. User has defensive Stats
      # 3. Opponent cannot OHKO
      
      has_recovery = false
      user.moves.each do |move|
        next if !move
        has_recovery = true if AdvancedAI.healing_move?(move.id)
      end
      
      return false if !has_recovery
      
      # Check defensive stats
      roles = AdvancedAI.detect_roles(user)
      return false if !roles.include?(:wall) && !roles.include?(:tank)
      
      # Check if opponent can OHKO
      opponents = battle.allOtherSideBattlers(user.index)
      opponents.each do |opp|
        next if !opp || opp.fainted?
        
        # If opponent very strong = no Stalling
        if opp.attack >= 140 || opp.spatk >= 140
          return false
        end
      end
      
      return true
    end
    
    #===========================================================================
    # Desperation Moves
    #===========================================================================
    
    # Bonus for desperate Moves
    def self.desperation_bonus(battle, user, move)
      return 0 if !battle || !user || !move
      
      # Only if close to losing
      remaining = battle.pbAbleCount(user.index & 1)
      return 0 if remaining > 1
      
      # Only if user weak
      return 0 if user.hp > user.totalhp * 0.3
      
      bonus = 0
      
      # OHKO Moves (+80)
      bonus += 80 if AdvancedAI.ohko_move?(move.id)
      
      # Explosion/Self-Destruct (+60)
      bonus += 60 if [:EXPLOSION, :SELFDESTRUCT].include?(move.id)
      
      # Final Gambit (+50)
      bonus += 50 if move.id == :FINALGAMBIT
      
      # Reversal / Flail (strong at low HP) (+40)
      bonus += 40 if [:REVERSAL, :FLAIL].include?(move.id)
      
      return bonus
    end
    
    #===========================================================================
    # Helper Methods
    #===========================================================================
    
    # Checks if Move can KO
    def self.can_ko?(user, target, move)
      user = user.battler if user.respond_to?(:battler)
      target = target.battler if target.respond_to?(:battler)
      return false unless user && target && move && !target.fainted?
      return false if target.effects[PBEffects::Endure]
      if target.hp == target.totalhp
        return false if target.hasActiveItem?(:FOCUSSASH)
        return false if target.hasActiveAbility?(:STURDY) && !AdvancedAI::Utilities.ignores_ability?(user, move, target)
      end
      ko_damage(user, target, move) >= target.hp
    end

    def self.can_2hko?(user, target, move)
      user = user.battler if user.respond_to?(:battler)
      target = target.battler if target.respond_to?(:battler)
      return false unless user && target && move && !target.fainted?
      ko_damage(user, target, move) * 2 >= target.hp
    end

    def self.ko_damage(user, target, move)
      user = user.battler if user.respond_to?(:battler)
      target = target.battler if target.respond_to?(:battler)
      return 0 unless user && target && move
      return 0 if user.fainted? || move.statusMove?
      battle = user.instance_variable_get(:@battle)
      index = user.moves.index { |candidate| candidate && candidate.id == move.id }
      return 0 if index && !battle.pbCanChooseMove?(user.index, index, false)
      native = move.respond_to?(:move) ? move.move : move
      return 0 if target.effects[PBEffects::Substitute] > 0 && !native.ignoresSubstitute?(user)
      return 0 if AdvancedAI::Utilities.counter_priority_blocked?(battle, native, user, target)
      return 0 if AdvancedAI::Utilities.counter_shield_blocked?(battle, native, user, target)
      calculate_rough_damage(native, user, target)
    end

    # Rough Damage Calculation
    # NOTE: Signature matches Move_Scorer: (move, attacker, defender)
    def self.calculate_rough_damage(move, user, target)
      return 0 if !user || !target || !move
      return 0 if move.statusMove?

      AdvancedAI::CombatUtilities.estimate_damage(user, move, target)
    end
    
    # Finds weakest Opponent
    def self.find_weakest_opponent(battle, user)
      return nil if !battle || !user
      
      opponents = battle.allOtherSideBattlers(user.index)
      return nil if opponents.empty?
      
      weakest = nil
      lowest_hp_percent = 999
      
      opponents.each do |opp|
        next if !opp || opp.fainted?
        
        hp_percent = (opp.hp * 100.0 / opp.totalhp)
        if hp_percent < lowest_hp_percent
          lowest_hp_percent = hp_percent
          weakest = opp
        end
      end
      
      return weakest
    end
    
    # Returns Partner (Doubles)
    def self.get_partner(battle, user)
      return nil if !battle || !user
      return nil unless battle.pbSideSize(0) > 1  # Not doubles
      
      # PE v21.1 interleaved indexing: 0=player1, 1=opp1, 2=player2, 3=opp2
      # Partner is on same side: index XOR 2 (0↔2, 1↔3)
      partner = battle.allSameSideBattlers(user.index).find { |b| b && b.index != user.index && !b.fainted? }
      return partner
    end
    
  end
end

#===============================================================================
# API Wrapper
#===============================================================================
module AdvancedAI
  def self.is_endgame?(battle)
    EndgameScenarios.is_endgame?(battle)
  end
  
  def self.is_1v1?(battle)
    EndgameScenarios.is_1v1?(battle)
  end
  
  def self.is_2v2?(battle)
    EndgameScenarios.is_2v2?(battle)
  end
  
  def self.score_endgame_move(battle, user, target, move, base_score)
    score = base_score
    score = EndgameScenarios.score_1v1_move(battle, user, target, move, score) if EndgameScenarios.is_1v1?(battle)
    score = EndgameScenarios.score_2v2_move(battle, user, target, move, score) if EndgameScenarios.is_2v2?(battle)
    return score
  end
  
  def self.find_winning_move(battle, user)
    EndgameScenarios.find_winning_move(battle, user)
  end
  
  def self.should_stall?(battle, user)
    EndgameScenarios.should_stall?(battle, user)
  end
  
  def self.desperation_bonus(battle, user, move)
    EndgameScenarios.desperation_bonus(battle, user, move)
  end
end

#===============================================================================
# Integration in Battle::AI - Wires endgame logic into scoring pipeline
#===============================================================================
class Battle::AI
  def apply_endgame_logic(score, move, user, target)
    return score unless move
    skill = @trainer&.skill || 100
    
    # Apply endgame scenario scoring (1v1, 2v2 adjustments)
    if AdvancedAI.is_endgame?(@battle)
      score = AdvancedAI.score_endgame_move(@battle, user, target, move, score)
      
      # Add desperation bonus when losing badly
      desp = AdvancedAI.desperation_bonus(@battle, user, move)
      score += desp if desp && desp > 0
    end
    
    # Apply win condition bonus (works at any point, not just endgame)
    if skill >= 70
      win_bonus = AdvancedAI.apply_win_condition_bonus(@battle, user, move, target, skill)
      score += win_bonus if win_bonus && win_bonus > 0
    end
    
    return score
  end
end
