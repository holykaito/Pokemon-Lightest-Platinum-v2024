class Battle::AI
  CAL_BASE_ABILITY_RATINGS = {
	10 	=> [:EXPEDITIOUS,:NEUTRALIZE],
	9   => [:GREYGOO],
	7 	=> [:CORRUPTEDCODE, :MADSCIENTIST, :WINDSWEPT],
	6	=> [:MUTATION, :PRACTICAL, :QUICKCHARGE, :SCARECROW],
	5	=> [:AQUATICBLOOD, :QUEENSPOTENTIAL, :MAGICJAW, :KINGSWRATH, :ARCANEMAGE],
	3	=> [:GOODLUCK, :UNCONCERNED, :SOLARFIELD, :HESSAFE],
	2   => [:COMPACTEDICE, :CHEMICALREACTION],
	1 	=> [:TOXICWATERS, :BURNINGSTEAM, :PHANTOMTHIEF, :BACKSWING, :PARALYTICPOISON, :ACIDICPOISON, :ECHOLOCATION, :RAGEBAITING, :SOUPFILLER],
	-1	=> [:SWEETDREAMS, :BEASTMODE, :CONCUSSION, :BOULDERBARRIER, :QUICKSTRIKE, :EXTINGUISH, :IGNITION],
	-2 	=> [:RUSTEDFEATHERS]
  }
  
#-------------------------------------------------------------------------------
# GREYGOO Posion no damage AI check!
#-------------------------------------------------------------------------------
	Battle::AI::Handlers::ShouldSwitch.add(:significant_eor_damage,
	  proc { |battler, reserves, ai, battle|
		eor_damage = battler.rough_end_of_round_damage
		# Switch to remove certain effects that cause the battler EOR damage
		if ai.trainer.high_skill? && eor_damage > 0
			if battler.status == :POISON && battler.statusCount > 0 && !battler.has_active_ability?(:GREYGOO)
				poison_damage = battler.totalhp / 8
				next_toxic_damage = battler.totalhp * (battler.effects[PBEffects::Toxic] + 1) / 16
				if (battler.hp <= next_toxic_damage && battler.hp > poison_damage) ||
				   next_toxic_damage > poison_damage * 2
				  PBDebug.log_ai("#{battler.name} wants to switch to reduce toxic to regular poisoning")
				  next true
				end
			end
		end
		next false
	  }
	)

#-------------------------------------------------------------------------------
# GREYGOO AbsorbPosion AI check!
#-------------------------------------------------------------------------------
	alias CAL_pokemon_can_absorb_move? pokemon_can_absorb_move?
	def pokemon_can_absorb_move?(pkmn, move, move_type)
		return false if pkmn.is_a?(Battle::AI::AIBattler) && !pkmn.ability_active?
		ret = CAL_pokemon_can_absorb_move?(pkmn, move, move_type)
		
		case pkmn.ability_id
		when :GREYGOO
			return move_type == :POISON
		end
		
		return ret
	end

#-------------------------------------------------------------------------------
# PHANTOMTHIEF stat change perfering & #RAGEBAITING
#-------------------------------------------------------------------------------
	
	alias CAL_get_score_for_target_stat_drop get_score_for_target_stat_drop
	def get_score_for_target_stat_drop(score, target, stat_changes, whole_effect = true, fixed_change = false, ignore_contrary = false)
		ret = CAL_get_score_for_target_stat_drop(score, target, stat_changes, whole_effect, fixed_change, ignore_contrary)
		
		if @user.has_active_ability?(:PHANTOMTHIEF)
			PBDebug.log_score_change(40, "perfer lowering stats as it will raise its own.")
			ret += 40
		end
		
		if @user.has_active_ability?(:RAGEBAITING)
			PBDebug.log_score_change(10, "perfer lowering stats as it will trap.")
			ret += 10
		end
		
		return ret
	end
	
#-------------------------------------------------------------------------------
# PRACTICAL stat change disinsentivising
#-------------------------------------------------------------------------------
	
	alias CAL_get_target_stat_drop_score_generic get_target_stat_drop_score_generic
	def get_target_stat_drop_score_generic(score, target, stat_changes, desire_mult = 1)
		score = CAL_get_target_stat_drop_score_generic(score, target, stat_changes, desire_mult)
		#(PRACTICAL)
		if target.opposes?(@user) && Battle::AbilityEffects::OnStatLossWithIncrement[target.ability]
			score -= 10
		end
		
		return score
	end

#-------------------------------------------------------------------------------
# SOLARFIELD sun prefering
#-------------------------------------------------------------------------------
	alias CAL_get_score_for_weather get_score_for_weather
	def get_score_for_weather(weather, move_user, starting = false)
		ret = CAL_get_score_for_weather(weather, move_user, starting)
	
		if weather == :Sun
			each_battler do |b, i|
				if b.has_active_ability?(:SOLARFIELD)
					ret += (b.opposes?(move_user)) ? -5 : 5
				end
			end
		end
		
		return ret
	end

#-------------------------------------------------------------------------------
# WINDSWEPT prefering flying moves if no tailwind
#-------------------------------------------------------------------------------
	alias CAL_pbGetMoveScore pbGetMoveScore
	def pbGetMoveScore(targets = nil)
		score = CAL_pbGetMoveScore(targets)
		
		score += 20 if @user.has_active_ability?(:WINDSWEPT) && @move.type == :FLYING && @user.pbOwnSide.effects[PBEffects::Tailwind] == 0
		
		return score
	end

#-------------------------------------------------------------------------------
# Acknowledge ARCANE MAGE dark Immunity
#-------------------------------------------------------------------------------
	alias CAL_pbPredictMoveFailureAgainstTarget pbPredictMoveFailureAgainstTarget
	def pbPredictMoveFailureAgainstTarget()
		ret = CAL_pbPredictMoveFailureAgainstTarget()
		
		ret = true if @user.has_active_ability?(:ARCANEMAGE) && [:FIRE, :ICE, :ELECTRIC].include?(@move.rough_type) && @target.has_type?(:DARK) && !@battle.moldBreaker
		
		return ret 
	end
end
  
class Battle::AI::AIBattler
  alias CAL_wants_ability? wants_ability?
  def wants_ability?(ability = :NONE)
    Battle::AI::CAL_BASE_ABILITY_RATINGS.each_pair do |val, abilities|
      next if Battle::AI::BASE_ABILITY_RATINGS[val] && Battle::AI::BASE_ABILITY_RATINGS[val].include?(ability)
      Battle::AI::BASE_ABILITY_RATINGS[val] = [] if !Battle::AI::BASE_ABILITY_RATINGS[val]
      abilities.each{|ab|
        Battle::AI::BASE_ABILITY_RATINGS[val].push(ab)
      }
    end
    return CAL_wants_ability?(ability)
  end
  
  #GREYGOO
  alias CAL_wants_status_problem? wants_status_problem?
  def wants_status_problem?(new_status)
	return true if new_status == :NONE
	ret = CAL_wants_status_problem?(new_status)
	
    if ability_active?
		case ability_id
		when :GREYGOO
			return true if new_status == :POISON
		end
	end
	
	return ret
  end
end


