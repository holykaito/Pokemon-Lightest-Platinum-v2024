#===============================================================================
# Advanced AI System - Win Condition Identification
# Tracks and identifies how the AI can win the battle
#===============================================================================

module AdvancedAI
  module WinConditions
    #===========================================================================
    # Win Condition Types
    #===========================================================================
    WIN_CONDITIONS = {
      sweep: {
        description: "A single Pokemon can KO all remaining opponents",
        priority: 10
      },
      attrition: {
        description: "Chip damage + hazards will secure victory",
        priority: 7
      },
      stall: {
        description: "PP stall or Toxic stall will win",
        priority: 5
      },
      trade: {
        description: "Trading 1-for-1 leads to numerical advantage",
        priority: 6
      },
      setup: {
        description: "One safe setup turn wins the game",
        priority: 9
      },
      revenge: {
        description: "Revenge killing with priority/faster mon wins",
        priority: 8
      },
      speed_control: {
        description: "Speed advantage + faster attackers win",
        priority: 7
      }
    }
    
    #===========================================================================
    # Main Win Condition Analyzer
    #===========================================================================
    def self.identify_win_condition(battle, user, skill_level = 100)
      return nil unless skill_level >= 70
      
      user = user.battler if user.respond_to?(:battler)
      conditions = []
      
      # Gather battle state info
      our_side = get_side_pokemon(battle, user, own_side: true)
      opp_side = get_side_pokemon(battle, user, own_side: false)
      
      return nil if our_side.empty? || opp_side.empty?
      
      # Check each win condition type
      conditions << check_sweep_condition(battle, our_side, opp_side, skill_level)
      conditions << check_attrition_condition(battle, user, our_side, opp_side, skill_level)
      conditions << check_stall_condition(battle, our_side, opp_side, skill_level)
      conditions << check_trade_condition(battle, our_side, opp_side, skill_level)
      conditions << check_setup_condition(battle, our_side, opp_side, skill_level)
      conditions << check_revenge_condition(battle, our_side, opp_side, skill_level)
      conditions << check_speed_control_condition(battle, user, our_side, opp_side, skill_level)
      
      # Return highest priority valid condition
      conditions.compact.max_by { |c| c[:score] }
    end
    
    #===========================================================================
    # Individual Win Condition Checks
    #===========================================================================
    
    # Sweep: One Pokemon can OHKO or 2HKO all remaining opponents
    def self.check_sweep_condition(battle, our_side, opp_side, skill_level)
      our_side.each do |mon|
        next unless mon && !mon.fainted?
        
        can_sweep = true
        sweep_score = 0
        
        opp_side.each do |opp|
          next unless opp && !opp.fainted?
          
          # Check if we can KO this opponent
          best_move = find_best_attacking_move(mon, opp)
          if best_move
            damage_percent = estimate_damage_percent(mon, opp, best_move)
            if damage_percent >= 100
              sweep_score += 30  # OHKO
            elsif damage_percent >= 50
              sweep_score += 15  # 2HKO
            else
              can_sweep = false
              break
            end
          else
            can_sweep = false
            break
          end
          
          # Check if we outspeed or have priority
          unless outspeeds?(mon, opp, battle) || has_priority_ko?(mon, opp)
            opp_damage = estimate_max_damage_from(opp, mon)
            if opp_damage >= mon.hp
              can_sweep = false
              break
            end
          end
        end
        
        if can_sweep && sweep_score > 0
          return {
            type: :sweep,
            pokemon: mon,
            score: sweep_score + 50,
            description: "#{mon.name} can sweep remaining opponents"
          }
        end
      end
      
      nil
    end
    
    # Attrition: Hazards + Chip will win over time
    def self.check_attrition_condition(battle, user, our_side, opp_side, skill_level)
      return nil unless skill_level >= 75
      
      score = 0
      
      # Check hazards on opponent's side
      # Derive side index dynamically from user
      opp_side_index = 1 - (user.index & 1)
      opp_effects = battle.sides[opp_side_index].effects
      
      if opp_effects[PBEffects::StealthRock]
        opp_side.each do |opp|
          next unless opp
          opp_types = opp.respond_to?(:pbTypes) ? opp.pbTypes(true) : opp.types
          effectiveness = Effectiveness.calculate(:ROCK, *opp_types)
          if Effectiveness.super_effective?(effectiveness)
            score += 20  # SR hurts them
          end
        end
      end
      
      spikes = opp_effects[PBEffects::Spikes] || 0
      score += spikes * 10
      
      toxic_spikes = opp_effects[PBEffects::ToxicSpikes] || 0
      score += toxic_spikes * 8
      
      # Check if we have hazard setters
      our_side.each do |mon|
        next unless mon && !mon.fainted?
        if mon.moves.any? { |m| hazard_can_set?(battle, mon, m, opp_side_index) }
          score += 15
        end
      end
      
      # Check if we have recovery
      our_side.each do |mon|
        next unless mon && !mon.fainted?
        if mon.moves.any? { |m| move_available?(mon, m) && [:RECOVER, :ROOST, :SOFTBOILED, :SLACKOFF, :MOONLIGHT, :MORNINGSUN,
                                           :SYNTHESIS, :SHOREUP, :STRENGTHSAP, :WISH, :REST, :MILKDRINK,
                                           :HEALORDER, :LIFEDEW, :JUNGLEHEALING, :LUNARBLESSING].include?(m.id) }
          score += 20
        end
      end
      
      return nil if score < 30
      
      {
        type: :attrition,
        pokemon: nil,
        score: score,
        description: "Hazard chip damage will win over time"
      }
    end
    
    # Stall: PP stall or Toxic stall
    def self.check_stall_condition(battle, our_side, opp_side, skill_level)
      return nil unless skill_level >= 80
      
      score = 0
      stall_mon = nil
      
      our_side.each do |mon|
        next unless mon && !mon.fainted?
        
        mon_score = 0
        
        # High defenses
        if mon.defense >= 120 || mon.spdef >= 120
          mon_score += 20
        end
        
        # Recovery moves
        if mon.moves.any? { |m| move_available?(mon, m) && [:RECOVER, :ROOST, :SOFTBOILED, :SLACKOFF, :MOONLIGHT, :MORNINGSUN,
                                           :SYNTHESIS, :SHOREUP, :STRENGTHSAP, :WISH, :REST, :MILKDRINK,
                                           :HEALORDER, :LIFEDEW, :JUNGLEHEALING, :LUNARBLESSING].include?(m.id) }
          mon_score += 30
        end
        
        # Toxic for stall
        if mon.moves.any? { |m| m && m.id == :TOXIC && move_available?(mon, m) &&
                            opp_side.any? { |opp| toxic_plan_target?(battle, mon, opp, m) } }
          mon_score += 25
        end
        
        # Protect for Toxic stall
        if mon.moves.any? { |m| move_available?(mon, m) && [:PROTECT, :DETECT, :KINGSSHIELD, :SPIKYSHIELD,
                                           :BANEFULBUNKER, :OBSTRUCT, :SILKTRAP, :BURNINGBULWARK].include?(m.id) }
          mon_score += 15
        end
        
        # Wish + Protect
        if mon.moves.any? { |m| move_available?(mon, m) && m.id == :WISH }
          mon_score += 20
        end
        
        if mon_score > score
          score = mon_score
          stall_mon = mon
        end
      end
      
      return nil if score < 40
      
      {
        type: :stall,
        pokemon: stall_mon,
        score: score,
        description: "#{stall_mon&.name || 'Team'} can stall out opponents"
      }
    end
    
    # Trade: Numerical advantage from 1-for-1 trades
    def self.check_trade_condition(battle, our_side, opp_side, skill_level)
      our_count = our_side.count { |p| p && !p.fainted? }
      opp_count = opp_side.count { |p| p && !p.fainted? }
      
      if our_count > opp_count
        advantage = our_count - opp_count
        {
          type: :trade,
          pokemon: nil,
          score: advantage * 25 + 20,
          description: "#{advantage} Pokemon advantage - trading wins"
        }
      else
        nil
      end
    end
    
    # Setup: One setup turn wins
    def self.check_setup_condition(battle, our_side, opp_side, skill_level)
      return nil unless skill_level >= 70
      
      our_side.each do |mon|
        next unless mon && !mon.fainted?
        
        # Check for setup moves
        setup_moves = mon.moves.select do |m|
          m && [:SWORDSDANCE, :NASTYPLOT, :DRAGONDANCE, :QUIVERDANCE, :CALMMIND,
                :BULKUP, :IRONDEFENSE, :SHELLSMASH, :SHIFTGEAR, :COIL,
                :VICTORYDANCE, :FILLETAWAY, :BELLYDRUM, :AGILITY].include?(m.id)
        end
        
        next if setup_moves.empty?
        
        # Check if setup would enable sweep
        # Look up active battler for this party mon to get stat stages
        active_battler = mon.respond_to?(:stages) ? mon : nil
        mon_stages = (active_battler && active_battler.respond_to?(:stages)) ? active_battler.stages : {}
        current_stages = (mon_stages[:ATTACK] || 0) + (mon_stages[:SPECIAL_ATTACK] || 0)
        
        if current_stages >= 2
          can_clean = opp_side.all? do |opp|
            next true unless opp && !opp.fainted?
            best = find_best_attacking_move(mon, opp)
            best && estimate_damage_percent(mon, opp, best) >= 50
          end
          
          if can_clean
            return {
              type: :setup,
              pokemon: mon,
              score: 70 + (current_stages * 10),
              description: "#{mon.name} is set up and can clean"
            }
          end
        else
          next unless setup_moves.any? { |m| move_available?(mon, m) }
          return {
            type: :setup,
            pokemon: mon,
            score: 50,
            description: "#{mon.name} needs setup opportunity"
          }
        end
      end
      
      nil
    end
    
    # Revenge: Priority or faster revenge kills
    def self.check_revenge_condition(battle, our_side, opp_side, skill_level)
      return nil unless skill_level >= 65
      
      score = 0
      revenge_mons = []
      
      our_side.each do |mon|
        next unless mon && !mon.fainted?
        
        # Check if priority can KO weakened opponents
        opp_side.each do |opp|
          next unless opp && !opp.fainted?
          next unless opp.hp < opp.totalhp * 0.5  # Weakened
          
          if has_priority_ko?(mon, opp)
            score += 20
            revenge_mons << mon unless revenge_mons.include?(mon)
          end
        end
      end
      
      return nil if score < 20
      
      {
        type: :revenge,
        pokemon: revenge_mons.first,
        score: score + 30,
        description: "Priority moves can secure KOs"
      }
    end
    
    # Speed Control: Win via speed advantage
    def self.check_speed_control_condition(battle, user, our_side, opp_side, skill_level)
      return nil unless skill_level >= 70
      
      # Check speed control active — derive side from user
      our_side_index = user.index & 1
      our_effects = battle.sides[our_side_index].effects
      
      score = 0
      
      if our_effects[PBEffects::Tailwind] && our_effects[PBEffects::Tailwind] > 0
        score += 40
      end
      
      # Helper: base SPEED with fallback for unknown/removed species (default 100 = neutral)
      base_speed = ->(m) { GameData::Species.try_get(m.species)&.base_stats&.[](:SPEED) || 100 }

      if battle.field.effects[PBEffects::TrickRoom] && battle.field.effects[PBEffects::TrickRoom] > 0
        # Check if we benefit from TR (use base stats for reliable thresholds)
        our_slow = our_side.count { |m| m && !m.fainted? && base_speed.call(m) < 80 }
        opp_slow = opp_side.count { |m| m && !m.fainted? && base_speed.call(m) < 80 }

        if our_slow > opp_slow
          score += 35
        else
          score -= 20
        end
      end

      # Natural speed advantage (use base stats for reliable thresholds)
      our_fast = our_side.count { |m| m && !m.fainted? && base_speed.call(m) >= 100 }
      opp_fast = opp_side.count { |m| m && !m.fainted? && base_speed.call(m) >= 100 }
      
      if our_fast > opp_fast
        score += (our_fast - opp_fast) * 15
      end
      
      return nil if score < 25
      
      {
        type: :speed_control,
        pokemon: nil,
        score: score,
        description: "Speed advantage enables favorable trades"
      }
    end
    
    #===========================================================================
    # Score Modification Based on Win Condition
    #===========================================================================
    def self.apply_win_condition_bonus(battle, user, move, target, skill_level = 100)
      return 0 unless skill_level >= 70
      
      user = user.battler if user.respond_to?(:battler)
      target = target.battler if target.respond_to?(:battler)
      move = move.move if move.respond_to?(:move)
      win_con = identify_win_condition(battle, user, skill_level)
      return 0 unless win_con
      
      score = 0
      
      case win_con[:type]
      when :sweep
        # Protect the sweeper, boost its moves
        if win_con[:pokemon] == user
          score += 30 if move.damagingMove?  # Attack with sweeper
        elsif win_con[:pokemon]
          # Support the sweeper
          if move.id == :HELPINGHAND
            score += 25
          end
          # Redirect attacks away from sweeper
          if [:FOLLOWME, :RAGEPOWDER].include?(move.id)
            score += 20
          end
        end
        
      when :attrition
        # Prioritize hazards
        if [:STEALTHROCK, :SPIKES, :TOXICSPIKES, :STICKYWEB].include?(move.id)
          score += 25 if hazard_can_set?(battle, user, move, 1 - (user.index & 1))
        end
        # Value recovery
        if [:RECOVER, :ROOST, :SOFTBOILED, :SLACKOFF, :MOONLIGHT, :MORNINGSUN,
            :SYNTHESIS, :SHOREUP, :STRENGTHSAP, :WISH, :REST, :MILKDRINK,
            :HEALORDER, :LIFEDEW, :JUNGLEHEALING, :LUNARBLESSING].include?(move.id)
          score += 20 if user.hp < user.totalhp * 0.6 && user.canHeal? && move_available?(user, move)
        end
        
      when :stall
        # Prioritize status
        if move.id == :TOXIC
          score += 30 if poison_damage_useful?(battle, target) && toxic_can_hit?(battle, user, target, move)
        end
        # Protect for stall
        if [:PROTECT, :DETECT, :KINGSSHIELD, :SPIKYSHIELD, :BANEFULBUNKER,
            :OBSTRUCT, :SILKTRAP, :BURNINGBULWARK].include?(move.id)
          score += 15 if target && target.effects[PBEffects::Toxic] && target.effects[PBEffects::Toxic] > 0
        end
        # Recovery high priority
        if [:RECOVER, :ROOST, :SOFTBOILED, :SLACKOFF, :MOONLIGHT, :MORNINGSUN,
            :SYNTHESIS, :SHOREUP, :STRENGTHSAP, :WISH, :REST, :MILKDRINK,
            :HEALORDER, :LIFEDEW, :JUNGLEHEALING, :LUNARBLESSING].include?(move.id)
          score += 25 if user.hp < user.totalhp * 0.7 && user.canHeal? && move_available?(user, move)
        end
        
      when :trade
        # Aggressive plays
        if move.damagingMove?
          score += 15
        end
        # Don't overvalue setup when ahead
        if [:SWORDSDANCE, :NASTYPLOT, :CALMMIND].include?(move.id)
          score -= 10
        end
        
      when :setup
        # Boost setup moves for the setup mon
        if win_con[:pokemon] == user
          if [:SWORDSDANCE, :NASTYPLOT, :DRAGONDANCE, :QUIVERDANCE, :CALMMIND,
              :SHELLSMASH, :AGILITY].include?(move.id)
            user_stg = user.respond_to?(:stages) ? user.stages : {}
            score += 35 if (user_stg[:ATTACK] || 0) < 2 && (user_stg[:SPECIAL_ATTACK] || 0) < 2
          end
        end
        
      when :revenge
        # Priority moves valuable
        if target && priority_ko_move?(user, target, move)
          if target && target.hp < target.totalhp * 0.5
            score += 25
          end
        end
        
      when :speed_control
        # Maintain speed advantage
        if [:TAILWIND, :TRICKROOM].include?(move.id)
          score += 20
        end
        # Speed control attacks
        if [:ICYWIND, :ELECTROWEB, :BULLDOZE, :ROCKTOMB].include?(move.id)
          score += 15
        end
      end
      
      score
    end
    
    #===========================================================================
    # Helper Methods
    #===========================================================================
    private
    
    def self.get_side_pokemon(battle, user, own_side: true)
      # battler.index is slot (0-3 in doubles); pbParty takes side index (0 or 1)
      own_side_index = user.index & 1
      side_index = own_side ? own_side_index : (1 - own_side_index)
      active = battle.allSameSideBattlers(side_index)
      battle.pbParty(side_index).select { |p| p && !p.egg? && !p.fainted? }.map do |pokemon|
        active.find { |b| b.pokemon.equal?(pokemon) } || pokemon
      end
    end
    
    def self.find_best_attacking_move(user, target)
      return nil unless user.moves
      
      best_move = nil
      best_damage = 0
      
      user.moves.each do |move|
        next unless move_available?(user, move)
        resolved = resolve_move(move)
        next unless resolved && resolved.damagingMove?
        
        damage = estimate_damage_percent(user, target, resolved)
        if damage > best_damage
          best_damage = damage
          best_move = resolved
        end
      end
      
      best_move
    end
    
    def self.estimate_damage_percent(user, target, move)
      move = resolve_move(move) unless move.respond_to?(:damagingMove?)
      return 0 unless move && move.damagingMove?

      AdvancedAI::CombatUtilities.estimate_damage(
        user, move, target, :as_percent => true
      ) * 100
    end
    
    def self.estimate_max_damage_from(attacker, defender)
      max_damage = 0
      
      return 0 unless attacker.moves
      
      attacker.moves.each do |move|
        next unless move_available?(attacker, move)
        resolved = resolve_move(move)
        next unless resolved && resolved.damagingMove?
        damage = estimate_damage_percent(attacker, defender, resolved)
        damage_hp = (damage / 100.0) * defender.totalhp
        max_damage = damage_hp if damage_hp > max_damage
      end
      
      max_damage
    end
    
    def self.outspeeds?(user, target, battle = nil)
      if battle
        user_speed   = AdvancedAI::SpeedTiers.calculate_effective_speed(battle, user)
        target_speed = AdvancedAI::SpeedTiers.calculate_effective_speed(battle, target)
      else
        user_stage  = (user.respond_to?(:stages)   ? (user.stages[:SPEED]   || 0) : 0)
        target_stage = (target.respond_to?(:stages) ? (target.stages[:SPEED] || 0) : 0)
        user_speed   = user.speed * stage_multiplier(user_stage)
        target_speed = target.speed * stage_multiplier(target_stage)
      end
      
      return user_speed < target_speed if battle && battle.field.effects[PBEffects::TrickRoom] > 0
      user_speed > target_speed
    end
    
    def self.hazard_can_set?(battle, user, move, opposing_side)
      return false unless move_available?(user, move)
      return false unless hazard_has_room?(battle.sides[opposing_side].effects, move.id)
      return true unless user.is_a?(Battle::Battler)
      battle.allOtherSideBattlers(user.index).none? do |foe|
        next false if foe.fainted? || foe.semiInvulnerable?
        foe.effects[PBEffects::MagicCoat] ||
          (foe.hasActiveAbility?(:MAGICBOUNCE) && !user.hasMoldBreaker? && !foe.effects[PBEffects::MagicBounce])
      end
    end

    def self.hazard_has_room?(effects, id)
      case id
      when :STEALTHROCK then !effects[PBEffects::StealthRock]
      when :SPIKES then effects[PBEffects::Spikes] < 3
      when :TOXICSPIKES then effects[PBEffects::ToxicSpikes] < 2
      when :STICKYWEB then !effects[PBEffects::StickyWeb]
      else false
      end
    end

    def self.poison_damage_useful?(battle, target)
      return false unless target && !target.fainted?
      return false if [:POISONHEAL, :MAGICGUARD].any? { |id| AdvancedAI::Utilities.ability_active?(target, id) }
      berry = [:LUMBERRY, :PECHABERRY].any? { |id| AdvancedAI::Utilities.item_active?(target, id, battle) }
      return false if berry && (!target.respond_to?(:canConsumeBerry?) || target.canConsumeBerry?)
      true
    end

    def self.toxic_plan_target?(battle, user, target, move)
      return false unless poison_damage_useful?(battle, target)
      return true if target.status == :POISON
      return false unless target.status == :NONE
      if user.is_a?(Battle::Battler) && target.is_a?(Battle::Battler)
        return toxic_can_hit?(battle, user, target, move)
      end
      # Reserves have no live field state; check their known types and abilities.
      unless AdvancedAI::Utilities.ability_active?(user, :CORROSION)
        return false if [:STEEL, :POISON].any? { |type| AdvancedAI::Utilities.has_type?(target, type) }
      end
      return false if AdvancedAI::Utilities.ability_active?(target, :COMATOSE)
      unless AdvancedAI::Utilities.ignores_ability?(user, resolve_move(move), target)
        return false if [:IMMUNITY, :PASTELVEIL, :PURIFYINGSALT, :MAGICBOUNCE, :GOODASGOLD].any? { |id| AdvancedAI::Utilities.ability_active?(target, id) }
      end
      true
    end

    def self.toxic_can_hit?(battle, user, target, move)
      return false unless target && !target.fainted? && move_available?(user, move)
      return false if AdvancedAI::Utilities.counter_priority_blocked?(battle, move, user, target)
      return false if AdvancedAI::Utilities.counter_shield_blocked?(battle, move, user, target)
      preview = battle.clone
      battlers = battle.battlers.map do |b|
        next nil unless b
        copy = b.clone
        copy.instance_variable_set(:@pokemon, b.pokemon.clone) if b.pokemon
        copy.instance_variable_set(:@battle, preview)
        copy.instance_variable_set(:@effects, b.effects.dup)
        copy.instance_variable_set(:@stages, b.stages.dup)
        copy
      end
      preview.instance_variable_set(:@battlers, battlers)
      user = battlers[user.index]
      target = battlers[target.index]
      native = Battle::Move.from_pokemon_move(preview, Pokemon::Move.new(move.id))
      preview.moldBreaker = AdvancedAI::Utilities.ignores_ability?(user, native, target)
      return false if target.effects[PBEffects::MagicCoat]
      return false if target.hasActiveAbility?(:MAGICBOUNCE) && !preview.moldBreaker
      return false if native.pbImmunityByAbility(user, target, false)
      target.pbCanPoison?(user, false, native)
    end

    def self.move_available?(user, move)
      user = user.battler if user.respond_to?(:battler)
      move = move.move if move.respond_to?(:move)
      return false unless move && user && !user.fainted?
      index = user.moves.index { |candidate| candidate && candidate.id == move.id }
      return false unless index && user.moves[index].pp > 0
      battle = user.instance_variable_get(:@battle)
      return battle.pbCanChooseMove?(user.index, index, false) if battle && user.is_a?(Battle::Battler)
      true
    end

    def self.priority_ko_move?(user, target, move)
      return false unless target && !target.fainted? && move_available?(user, move)
      resolved = resolve_move(move)
      return false unless resolved && resolved.damagingMove?
      if user.is_a?(Battle::Battler) && target.is_a?(Battle::Battler)
        return false unless AdvancedAI::PriorityTiers.get_priority_tier(resolved, user) > 0
        return AdvancedAI::EndgameScenarios.can_ko?(user, target, resolved)
      end
      resolved.priority > 0 && estimate_damage_percent(user, target, resolved) >= (target.hp.to_f / target.totalhp * 100)
    end

    def self.has_priority_ko?(user, target)
      user.moves.any? { |move| priority_ko_move?(user, target, move) }
    end

    def self.stage_multiplier(stage)
      stage = stage.clamp(-6, 6)
      if stage >= 0
        (2 + stage) / 2.0
      else
        2.0 / (2 - stage)
      end
    end

    #=========================================================================
    # Move Data Resolver
    # Pokemon::Move only stores :id / :pp / :ppup — it does NOT have
    # damagingMove?, physicalMove?, type, power, or priority.
    # Battle::Move DOES, but party mons hold Pokemon::Move objects.
    # This struct bridges the gap for any code that needs those fields.
    #=========================================================================
    MoveProxy = Struct.new(:id, :type, :power, :priority, :category, keyword_init: true) do
      def damagingMove?;  category == 0 || category == 1; end
      def physicalMove?;  category == 0; end
      def specialMove?;   category == 1; end
      def statusMove?;    category == 2; end
      def multiHitMove?;  false; end
    end

    # Wraps a Pokemon::Move (or Battle::Move) so callers always get the full
    # set of query methods.  Returns nil if the move data can't be resolved.
    def self.resolve_move(move)
      return nil unless move
      return move if move.respond_to?(:damagingMove?)  # Already a Battle::Move

      data = GameData::Move.try_get(move.id)
      return nil unless data

      MoveProxy.new(
        id:       data.id,
        type:     data.type,
        power:    data.power || 0,
        priority: data.priority || 0,
        category: data.category  # 0 = Physical, 1 = Special, 2 = Status
      )
    end
  end
end

# API Methods
module AdvancedAI
  def self.identify_win_condition(battle, user, skill_level = 100)
    WinConditions.identify_win_condition(battle, user, skill_level)
  end
  
  def self.apply_win_condition_bonus(battle, user, move, target, skill_level = 100)
    WinConditions.apply_win_condition_bonus(battle, user, move, target, skill_level)
  end
end

AdvancedAI.log("Win Condition Identification System loaded", "WinCon")
AdvancedAI.log("  - Sweep detection", "WinCon")
AdvancedAI.log("  - Attrition/Hazard win paths", "WinCon")
AdvancedAI.log("  - Stall condition tracking", "WinCon")
AdvancedAI.log("  - Trade advantage awareness", "WinCon")
AdvancedAI.log("  - Setup sweeper protection", "WinCon")
AdvancedAI.log("  - Revenge kill opportunities", "WinCon")
AdvancedAI.log("  - Speed control advantage", "WinCon")
