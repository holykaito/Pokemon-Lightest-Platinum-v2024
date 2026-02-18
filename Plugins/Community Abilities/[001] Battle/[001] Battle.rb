class Battle
  #-----------------------------------------------------------------------------
  # Money From GOODLUCK
  #-----------------------------------------------------------------------------
  alias CAL_pbGainMoney pbGainMoney
  def pbGainMoney
    CAL_pbGainMoney()
	
	return if !@internalBattle || !@moneyGain
	return if !@field.effects[PBEffects::GoodLuck]
    # Money rewarded from opposing trainers
    if trainerBattle?
      tMoney = 0
      @opponent.each_with_index do |t, i|
        tMoney += pbMaxLevelInTeam(1, i) * t.base_money
      end
      oldMoney = pbPlayer.money
      pbPlayer.money += tMoney
      moneyGained = pbPlayer.money - oldMoney
      if moneyGained > 0
        $stats.battle_money_gained += moneyGained
        pbDisplayPaused(_INTL("You got ${1} because of Good Luck!", moneyGained.to_s_formatted))
      end
    end
    # Pick up money scattered by Pay Day
    if @field.effects[PBEffects::PayDay] > 0
      oldMoney = pbPlayer.money
      pbPlayer.money += @field.effects[PBEffects::PayDay]
      moneyGained = pbPlayer.money - oldMoney
      if moneyGained > 0
        $stats.battle_money_gained += moneyGained
        pbDisplayPaused(_INTL("With some Good Luck you also got ${1}!", moneyGained.to_s_formatted))
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Sets GOODLUCK on switch in
  #-----------------------------------------------------------------------------
  alias CAL_pbRecordBattlerAsParticipated pbRecordBattlerAsParticipated
  def pbRecordBattlerAsParticipated(battler)
	CAL_pbRecordBattlerAsParticipated(battler)
	
	if !battler.opposes? && battler.hasActiveAbility?(:GOODLUCK)
      @field.effects[PBEffects::GoodLuck] = true
    end
  end 
  
  #-----------------------------------------------------------------------------
  # GREYGOO Healing
  #-----------------------------------------------------------------------------
  alias CAL_pbEORStatusProblemDamage pbEORStatusProblemDamage
  def pbEORStatusProblemDamage(priority)
	CAL_pbEORStatusProblemDamage(priority)
	
	priority.each do |battler|
		next if battler.fainted?
		next if battler.status != :POISON
		
		if battler.hasActiveAbility?(:GREYGOO)
			if battler.canHeal?
			  anim_name = GameData::Status.get(:POISON).animation
			  pbCommonAnimation(anim_name, battler) if anim_name
			  pbShowAbilitySplash(battler)
			  battler.pbRecoverHP(battler.totalhp / 8)
			  if Scene::USE_ABILITY_SPLASH
				pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
			  else
				pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
			  end
			  pbHideAbilitySplash(battler)
			end
        end
	end
  end
 
  #-----------------------------------------------------------------------------
  # Victory Star Mega Evo Enabling
  #-----------------------------------------------------------------------------
  alias CAL_pbCanMegaEvolve? pbCanMegaEvolve?
  def pbCanMegaEvolve?(idxBattler)
	return false if $game_switches[Settings::NO_MEGA_EVOLUTION]
    return false if !@battlers[idxBattler].hasMega?
    return false if @battlers[idxBattler].wild?
    return true if $DEBUG && Input.press?(Input::CTRL)
    return false if @battlers[idxBattler].effects[PBEffects::SkyDrop] >= 0
    return false if !pbHasMegaRing?(idxBattler)
  
	ret = CAL_pbCanMegaEvolve?(idxBattler)
	
	side  = @battlers[idxBattler].idxOwnSide
	owner = pbGetOwnerIndexFromBattlerIndex(idxBattler)
	megaCounter = @megaEvolution[side][owner] 
	
	if !ret	&& megaCounter == -2
		myBattlers = allSameSideBattlers(idxBattler)
	
		myBattlers.each do |b|
			if b.hasActiveAbility?(:VICTORYSTAR)
				b.effects[PBEffects::VictoryStarEvo] = 1
				ret = true
			end
		end
	end
	
	return ret
  end
  
  #-----------------------------------------------------------------------------
  # Victory Star Mega Evo minus stat enabling
  #-----------------------------------------------------------------------------
  alias CAL_pbMegaEvolve pbMegaEvolve
  def pbMegaEvolve(idxBattler)
	ret = CAL_pbMegaEvolve(idxBattler)
	return false if ret == false

	myBattlers = allSameSideBattlers(idxBattler)
	
	myBattlers.each do |b|
		if b.hasActiveAbility?(:VICTORYSTAR)
			Battle::AbilityEffects.triggerOnVictoryStarEvolution(b.ability, b, self)
		end
	end
  end
  
  #-----------------------------------------------------------------------------
  # RAGEBAITING avoiding dealing damage.
  #-----------------------------------------------------------------------------
  alias CAL_pbEORTrappingDamage pbEORTrappingDamage
  def pbEORTrappingDamage(battler)
	return if battler.fainted? || battler.effects[PBEffects::Trapping] == 0
		
	if battler.effects[PBEffects::TrappingMove] == "RAGEBAITING"
		battler.effects[PBEffects::Trapping] -= 1
			
		if battler.effects[PBEffects::Trapping] == 0
			pbDisplay(_INTL("{1} was freed from the rage bait!", battler.pbThis, ))
		end
	else 
		
		CAL_pbEORTrappingDamage(battler)
	end
  end
end

class Battle::Move
	#KINGSWRATH
	def hornMove?;         	return @flags.any? { |f| f[/^Horn$/i] };         	end
	def drillMove?;         return @flags.any? { |f| f[/^Drill$/i] };   		end

	#MAGICJAW
	alias CAL_pbGetAttackStats pbGetAttackStats
	def pbGetAttackStats(user, target)
		return user.spatk, user.stages[:SPECIAL_ATTACK] + Battle::Battler::STAT_STAGE_MAXIMUM if user.hasActiveAbility?(:MAGICJAW) && bitingMove?
		return CAL_pbGetAttackStats(user, target)
	end
	
	#MAGICJAW
	alias CAL_pbGetDefenseStats pbGetDefenseStats
	def pbGetDefenseStats(user, target)
		return target.spdef, target.stages[:SPECIAL_DEFENSE] + Battle::Battler::STAT_STAGE_MAXIMUM if user.hasActiveAbility?(:MAGICJAW) && bitingMove?
		return CAL_pbGetDefenseStats(user, target)
	end
	
	#KINGSWRATH
	alias CAL_pbFlinchChance pbFlinchChance
	def pbFlinchChance(user, target)
		return 0 if flinchingMove?
		return 0 if target.hasActiveAbility?(:SHIELDDUST) && !@battle.moldBreaker
		ret = CAL_pbFlinchChance(user, target) 
		
		if ret == 0
			if user.hasActiveAbility?(:KINGSWRATH) && (hornMove? || drillMove?)
			  ret = 10
			end
			ret *= 2 if user.hasActiveAbility?(:SERENEGRACE) || user.pbOwnSide.effects[PBEffects::Rainbow] > 0
			return ret
		end
		
		return ret
	end
	
	
end

class Battle::Move::TwoTurnMove < Battle::Move	
	#QUICKCHARGE
	alias CAL_pbIsChargingTurn? pbIsChargingTurn?
	def pbIsChargingTurn?(user)
		ret = CAL_pbIsChargingTurn?(user)
	
		if !user.effects[PBEffects::TwoTurnAttack] && user.hasActiveAbility?(:QUICKCHARGE)
			@powerHerb = false
			@chargingTurn = true
			@damagingTurn = true
			return !@damagingTurn 
		end
		
		return ret
	end
end

class Battle::Move::UserFaintsExplosive < Battle::Move
  #CONCUSSION
  alias CAL_pbSelfKO pbSelfKO
  def pbSelfKO(user)
    return if user.fainted?
	if user.hasActiveAbility?(:CONCUSSION) && (user.hp == user.totalhp)
		user.pbReduceHP(user.hp*3/4.0, false)
		user.pbItemHPHealCheck
		
		user.pbConfuse(_INTL("{1} became confused due to its concussion!", user.pbThis))
	else
		CAL_pbSelfKO(user)
	end    
  end
end

class Battle::Move::RecoilMove < Battle::Move
  #HESSAFE
  alias CAL_pbEffectAfterAllHits pbEffectAfterAllHits
  def pbEffectAfterAllHits(user, target)
	return if target.damageState.unaffected
	return if !user.takesIndirectDamage?
	return if user.hasActiveAbility?(:ROCKHEAD)
	amt = pbRecoilDamage(user, target)
	amt = 1 if amt < 1
	
	@battle.field.effects[PBEffects::HesSafe] = [] if !@battle.field.effects[PBEffects::HesSafe]
	
	if user.hasActiveAbility?(:HESSAFE) && amt >= user.hp && !@battle.field.effects[PBEffects::HesSafe].include?(user.displayPokemon.personalID)
		user.pbReduceHP(user.hp-1, false)
		@battle.pbShowAbilitySplash(user)
		user.pbRecoverHP(user.totalhp / 2, user)
		@battle.pbDisplay(_INTL("{1} was called safe!", user.pbThis))
		@battle.pbHideAbilitySplash(user)
		@battle.field.effects[PBEffects::HesSafe].push(user.displayPokemon.personalID)
	else
		CAL_pbEffectAfterAllHits(user, target)
	end
  end
end


class Battle::Peer
  alias CAL_pbOnLeavingBattle pbOnLeavingBattle
  def pbOnLeavingBattle(battle, pkmn, usedInBattle, endBattle = false)
    return if !pkmn
	CAL_pbOnLeavingBattle(battle, pkmn, usedInBattle, endBattle)

	if pkmn.ability == :BEASTMODE
		pkmn.form = 0
	end
	
	if pkmn.ability == :EXTINGUISH
		pkmn.form = 0
	end
  end
end


module Battle::AbilityEffects
	OnAnyStatLoss                       = AbilityHandlerHash.new
	OnStatLossWithIncrement             = AbilityHandlerHash.new
	OnVictoryStarEvolution				= AbilityHandlerHash.new

	def self.triggerOnAnyStatLoss(ability, battler, stat, user, increment, battle)
		OnAnyStatLoss.trigger(ability, battler, stat, user, increment,battle)
	end
	
	def self.triggerOnStatLossWithIncrement(ability, battler, stat, user, increment)
		OnStatLossWithIncrement.trigger(ability, battler, stat, user, increment)
	end
	
	def self.triggerOnVictoryStarEvolution(ability, user, battle)
		OnVictoryStarEvolution.trigger(ability, user, battle)
	end
end


