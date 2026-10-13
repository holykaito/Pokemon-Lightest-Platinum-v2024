#===============================================================================
# Advanced AI System - Priority Move Tier System
# Distinguishes between priority levels for optimal move selection
#===============================================================================

module AdvancedAI
  module PriorityTiers
    
    #===========================================================================
    # Priority Move Categories
    #===========================================================================
    
    # Priority +5 (Gen 9)
    PRIORITY_PLUS_5 = [:HELPINGHAND]
    
    # Priority +4
    PRIORITY_PLUS_4 = [:MAGICCOAT, :SNATCH, :BANEFULBUNKER, :OBSTRUCT,
                       :KINGSSHIELD, :SPIKYSHIELD,
                       :PROTECT, :DETECT, :SILKTRAP, :BURNINGBULWARK]
    
    # Priority +3
    PRIORITY_PLUS_3 = [:FAKEOUT, :QUICKGUARD, :WIDEGUARD, :CRAFTYSHIELD, :UPPERHAND]
    
    # Priority +2
    PRIORITY_PLUS_2 = [:EXTREMESPEED, :FEINT, :FOLLOWME, :RAGEPOWDER,
                       :FIRSTIMPRESSION]
    
    # Priority +1 (Most common)
    PRIORITY_PLUS_1 = [
      :ACCELEROCK, :AQUAJET, :BULLETPUNCH, :ICESHARD, :MACHPUNCH,
      :QUICKATTACK, :SHADOWSNEAK, :SUCKERPUNCH, :VACUUMWAVE,
      :WATERSHURIKEN, :JETPUNCH, :ZIPZAP, :GRASSYGLIDE, :THUNDERCLAP
    ]
    
    # Priority +0 (Normal moves)
    # ... all other moves
    
    # Priority -1 to -7 (Negative priority)
    NEGATIVE_PRIORITY = {
      :VITALTHROW => -1,
      :BEAKBLAST => -3,
      :FOCUSPUNCH => -3,
      :AVALANCHE => -4,
      :REVENGE => -4,
      :COUNTER => -5,
      :MIRRORCOAT => -5,
      :ROAR => -6,
      :WHIRLWIND => -6,
      :TRICKROOM => -7
    }
    
    #===========================================================================
    # Get Priority Level
    #===========================================================================
    
    def self.get_priority_tier(move, user = nil)
      return 0 unless move
      move = move.move if move.respond_to?(:move)
      return move.priority || 0 unless user && move.respond_to?(:pbPriority)
      battler = user.respond_to?(:battler) ? user.battler : user
      return move.priority || 0 unless battler
      # Priority handlers can set effects such as Prankster; isolate prediction.
      probe = battler.dup
      probe.instance_variable_set(:@effects, battler.effects.dup)
      priority = move.pbPriority(probe)
      if probe.abilityActive?
        priority = Battle::AbilityEffects.triggerPriorityChange(probe.ability, probe, move, priority)
      end
      return priority
    end

    #===========================================================================
    # Priority Move Scoring
    #===========================================================================
    
    def self.score_priority_advantage(user, move, target, battle, skill_level = 100)
      return 0 if move && move.statusMove?
      return 0 unless skill_level >= 60
      return 0 unless move
      # Protect resolves before attacks but does not provide speed-control
      # value. Its dedicated scorer handles its actual situational utility.
      return 0 if AdvancedAI.protect_move?(move.id)
      
      move_priority = get_priority_tier(move, user)
      return 0 if move_priority == 0  # Not a priority move
      
      score = 0
      
      # === PRIORITY BLOCKERS (Dazzling, Queenly Majesty, Armor Tail) ===
      # These abilities block priority moves targeting ANY Pokémon on that side
      if move_priority > 0 && move.damagingMove? && target.opposes?(user)
        return -100 if battle.field.terrain == :Psychic && target.affectedByTerrain?
        blocking_abilities = [:DAZZLING, :QUEENLYMAJESTY, :ARMORTAIL]
        unless user.respond_to?(:hasMoldBreaker?) && user.hasMoldBreaker?
          # Check target
          if blocking_abilities.any? { |a| target.hasActiveAbility?(a) }
            return -100
          end
          # Check target's allies (protects the whole side)
          if battle.pbSideSize(target.index) > 1
            battle.allSameSideBattlers(target.index).each do |ally|
              next if ally == target || ally.fainted?
              if blocking_abilities.any? { |a| ally.hasActiveAbility?(a) }
                return -100
              end
            end
          end
        end
      end
      
      # Pre-compute speeds (used in positive, negative, and ability sections)
      user_speed = user.pbSpeed
      target_speed = target.pbSpeed
      trick_room = battle.field.effects[PBEffects::TrickRoom] > 0
      user_is_later = trick_room ? user_speed > target_speed : user_speed < target_speed

      # === POSITIVE PRIORITY ===
      if move_priority > 0
        # Striking first only helps a move that actually hits
        speed_matters = move.damagingMove?
        if speed_matters && user_is_later
          score += 40 * move_priority  # Higher priority = more valuable
          
          # Extra bonus if we're MUCH slower
          speed_ratio = [user_speed, target_speed].max.to_f / [[user_speed, target_speed].min, 1].max
          if speed_ratio >= 2.0
            score += 30  # Completely outclassed in speed
          elsif speed_ratio >= 1.5
            score += 20
          end
          
          # Bonus if user is low HP (desperation)
          user_hp_percent = AdvancedAI::CombatUtilities.hp_percent(user)
          score += AdvancedAI::CombatUtilities.hp_threshold_score(
            user_hp_percent,
            { 0.33 => 50, 0.50 => 30 }
          )
          
          # Bonus if target is low HP (secure KO)
          target_hp_percent = AdvancedAI::CombatUtilities.hp_percent(target)
          if target_hp_percent < 0.33 && move.damagingMove?
            score += 60  # Guaranteed KO before they move
          elsif target_hp_percent < 0.50 && move.damagingMove?
            score += 40
          end
          
        elsif speed_matters
          # We're already faster - priority is less valuable
          score += 10 * move_priority  # Small bonus
        end
        
        # === PRIORITY TIER BONUSES ===
        case move_priority
        when 4
          # Helping Hand: +50% damage to partner (doubles only)
          score += 40 if battle.pbSideSize(0) > 1
          
        when 3
          # Protection moves (King's Shield, Baneful Bunker, etc.)
          # High value if opponent is boosted or we're low HP
          if AdvancedAI::CombatUtilities.total_stat_boosts(target) > 2
            score += 50  # Protect vs boosted opponent
          end
          
          user_hp_percent = AdvancedAI::CombatUtilities.hp_percent(user)
          score += 60 if user_hp_percent < 0.33
          
          # Upper Hand: Counters priority moves — hits before the priority move
          # Only useful if the target has a priority move and is likely to use it
          if move.id == :UPPERHAND
            target_has_priority = target.moves.any? do |m|
              m && m.priority > 0 && m.power > 0
            end
            if target_has_priority
              score += 60  # Great - neutralize their priority move before it fires
            else
              score -= 60  # Upper Hand FAILS if target doesn't use a priority move
            end
          end
          
        when 2
          # Extreme Speed, Feint, Follow Me
          if move.id == :EXTREMESPEED
            score += 30  # Very reliable priority damage
          elsif move.id == :FEINT
            # Bonus vs Protect users
            if target.effects[PBEffects::Protect]
              score += 80  # Bypass Protect!
            end
          elsif [:FOLLOWME, :RAGEPOWDER].include?(move.id)
            # Redirection in doubles
            score += 50 if battle.pbSideSize(0) > 1
          end
          
        when 1
          # Standard priority (Aqua Jet, Mach Punch, etc.)
          # Already scored above, but add type-specific bonuses
          
          # Thunderclap: Only works if opponent is using a damaging move this turn
          # Similar to Sucker Punch - penalize if target is likely using status
          if move.id == :THUNDERCLAP
            if target.lastMoveUsed
              last_move_data = GameData::Move.try_get(target.lastMoveUsed)
              if last_move_data && last_move_data.power == 0  # status move
                score -= 80  # Likely to fail!
              end
            end
            # Also penalize if target is already fainted or protected
            score += 20 if target.attack > target.spatk  # Physical attacker → less likely to Thunderclap fake
          end
          
          # Sucker Punch: Only works if opponent attacks
          if move.id == :SUCKERPUNCH
            # Penalty if opponent is likely to use status move
            if target.lastMoveUsed
              last_move_data = GameData::Move.try_get(target.lastMoveUsed)
              if last_move_data && last_move_data.power == 0  # status move (GameData::Move has no .statusMove?)
                score -= 100  # Likely to fail!
              end
            end
          end
          
          # Grassy Glide: Priority only in Grassy Terrain
          if move.id == :GRASSYGLIDE
            terrain = battle.field.terrain rescue nil
            if terrain != :Grassy
              score -= 40  # No priority boost
            end
          end
        end
      end
      
      # === NEGATIVE PRIORITY ===
      if move_priority < 0
        # Negative priority is usually BAD (move last)
        score -= 20 * move_priority.abs
        
        # EXCEPTIONS:
        
        # Trick Room: Intentionally move last to activate field
        if move.id == :TRICKROOM
          # Check if already active (toggle off)
          tr_active = battle.field.effects[PBEffects::TrickRoom] &&
                      battle.field.effects[PBEffects::TrickRoom] > 0
          
          if user_speed < 50
            if tr_active
              score -= 100  # DO NOT cancel our own beneficial Trick Room
            else
              score += 100  # Slow Pokemon loves setting Trick Room
            end
          elsif tr_active
            score += 50  # Fast mon might want to cancel opponent's TR
          end
        end
        
        # Counter / Mirror Coat: Need to take hit first
        if [:COUNTER, :MIRRORCOAT].include?(move.id)
          # Bonus if we can survive and OHKO back
          user_hp_percent = AdvancedAI::CombatUtilities.hp_percent(user)
          if user_hp_percent > 0.70
            score += 60  # Healthy - can survive to counter
          else
            score -= 40  # Too risky if low HP
          end
        end
        
        # Avalanche / Revenge: Double power if hit first
        if [:AVALANCHE, :REVENGE].include?(move.id)
          # Bonus if we're bulky enough to survive
          if user.defense + user.spdef > 200
            score += 40  # Tanky - can take hit for 2x power
          end
        end
      end
      
      return score
    end
    
    #===========================================================================
    # Check for Priority Move Availability
    #===========================================================================
    
    def self.has_priority_move?(user)
      return false unless user
      
      user.moves.each do |move|
        return true if move && get_priority_tier(move, user) > 0
      end
      
      return false
    end
    
    def self.get_best_priority_move(user, target, battle)
      return nil unless user
      
      best_move = nil
      best_score = -999999
      
      user.moves.each do |move|
        next unless move
        next if get_priority_tier(move, user) <= 0  # Not a priority move
        
        score = score_priority_advantage(user, move, target, battle)
        if score > best_score
          best_score = score
          best_move = move
        end
      end
      
      return best_move
    end
    
  end
end


#===============================================================================
# Integration: Hook into pbRegisterMove
#===============================================================================

class Battle::AI
  alias_method :priority_tiers_pbRegisterMove, :pbRegisterMove unless method_defined?(:priority_tiers_pbRegisterMove) || private_method_defined?(:priority_tiers_pbRegisterMove)
  
  def pbRegisterMove(user, move)
    score = priority_tiers_pbRegisterMove(user, move)
    
    return score unless user && move
    
    skill_level = @_resolved_skill || 100
    target = @_resolved_target || @battle.allOtherSideBattlers(user.index).find { |b| b && !b.fainted? }
    
    # Apply priority tier bonus/penalty
    if target
      priority_score = AdvancedAI::PriorityTiers.score_priority_advantage(user, move, target, @battle, skill_level)
      score += priority_score
      if @_score_factors && priority_score != 0
        @_score_factors["Priority Advantage"] = priority_score
      end
    end
    
    return score
  end
end
