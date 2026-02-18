class Battle::Battler
  #For Effects on Battlers	
  alias CAL_pbInitEffects pbInitEffects
  def pbInitEffects(batonPass)
	CAL_pbInitEffects(batonPass)
	@effects[PBEffects::VictoryStarEvo]        		= 0
    @effects[PBEffects::RageBaited]                	= false
	@effects[PBEffects::BeastMode]        			= 0
	@effects[PBEffects::BoulderBarrier] 			= false
  end
  
  #GREYGOO
  alias CAL_takesIndirectDamage? takesIndirectDamage?
  def takesIndirectDamage?(showMsg = false)
	ret = CAL_takesIndirectDamage?(showMsg)
	
	if hasActiveAbility?(:GREYGOO) && @status == :POISON
		ret = false;
	end
	
	return ret
  end
  #PHANTOMTHIEF #RAGEBAITING
  alias CAL_pbLowerStatStage pbLowerStatStage
  def pbLowerStatStage(stat, increment, user, showAnim = true, ignoreContrary = false, mirrorArmorSplash = 0, ignoreMirrorArmor = false)
	ret = CAL_pbLowerStatStage(stat, increment, user, showAnim, ignoreContrary, mirrorArmorSplash, ignoreMirrorArmor)
	if (ret)
		Battle::AbilityEffects.triggerOnStatLossWithIncrement(self.ability, self, stat, user, increment)
		
		if user.hasActiveAbility?(:PHANTOMTHIEF) || user.hasActiveAbility?(:RAGEBAITING)
			Battle::AbilityEffects.triggerOnAnyStatLoss(user.ability, user, stat, self, increment, @battle)
		end
	end
	
	return ret
  end
  #PHANTOMTHIEF #RAGEBAITING  
  alias CAL_pbLowerStatStageByCause pbLowerStatStageByCause
  def pbLowerStatStageByCause(stat, increment, user, cause, showAnim = true, ignoreContrary = false, ignoreMirrorArmor = false)
	ret = CAL_pbLowerStatStage(stat, increment, user, cause, showAnim,ignoreContrary, ignoreMirrorArmor)
	
	if (ret)
		Battle::AbilityEffects.triggerOnStatLossWithIncrement(self.ability, self, stat, user, increment)
	
		if user.hasActiveAbility?(:PHANTOMTHIEF) || user.hasActiveAbility?(:RAGEBAITING)
			Battle::AbilityEffects.triggerOnAnyStatLoss(user.ability, user, stat, self, increment, @battle)
		end
	end
	
	return ret
  end
  #PARALYTICPOISON & ACIDICPOISON
  alias CAL_pbInflictStatus pbInflictStatus
  def pbInflictStatus(newStatus, newStatusCount = 0, msg = nil, user = nil)
	if user && newStatus == :POISON
		if user.hasActiveAbility?(:PARALYTICPOISON)
			newStatus = :PARALYSIS
			newStatusCount = 0
		elsif user.hasActiveAbility?(:ACIDICPOISON)
			newStatus = :BURN
			newStatusCount = 0
		end
	end
  
	CAL_pbInflictStatus(newStatus, newStatusCount, msg, user)
  end
  #PARALYTICPOISON & ACIDICPOISON 
  alias CAL_pbCanInflictStatus? pbCanInflictStatus?
  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
  	if user && newStatus == :POISON
		if user.hasActiveAbility?(:PARALYTICPOISON)
			newStatus = :PARALYSIS
		elsif user.hasActiveAbility?(:ACIDICPOISON)
			newStatus = :BURN
		end
	end
  
	CAL_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
  end
  #CHEMICALREACTION
  alias CAL_pbConsumeItem pbConsumeItem
  def pbConsumeItem(recoverable = true, symbiosis = true, belch = true)
	if self.item.is_berry? && self.hasActiveAbility?(:CHEMICALREACTION)
		typeOut = :NORMAL
		item = self.item
		item.flags.each do |flag|
			next if !flag[/^NaturalGift_(\w+)_(?:\d+)$/i]
			typ = $~[1].to_sym
			typeOut = typ if GameData::Type.exists?(typ)
			break
		end
		
		@battle.pbShowAbilitySplash(self)
		self.pbChangeTypes(typeOut)
		pbRecoverHP(@totalhp / 4)
		@battle.pbDisplay(_INTL("{1}'s type changed to {2} and healed from a {3}!",self.pbThis, GameData::Type.get(typeOut).name, self.abilityName))
		@battle.pbHideAbilitySplash(self)
	end
  
	CAL_pbConsumeItem(recoverable, symbiosis, belch)
  end
  #POWERSHIELD & #BEASTMODE
  alias CAL_unstoppableAbility? unstoppableAbility?
  def unstoppableAbility?(abil = nil)
    abil = @ability_id if !abil
    abil = GameData::Ability.try_get(abil)
    return false if !abil
	
	ret = CAL_unstoppableAbility?(abil)
	
	if !ret
		ability_blacklist = [
			:POWERSHIELD,
			:BEASTMODE,
			:IGNITION,
			:EXTINGUISH
		]
		return ability_blacklist.include?(abil.id)
	end
	
	return ret	
  end
  #POWERSHIELD & #BEASTMODE
  alias CAL_ungainableAbility? ungainableAbility?
  def ungainableAbility?(abil = nil)
    abil = @ability_id if !abil
    abil = GameData::Ability.try_get(abil)
    return false if !abil
	
	ret = CAL_ungainableAbility?(abil)
	
	if !ret
		ability_blacklist = [
			:POWERSHIELD,
			:BEASTMODE,
			:IGNITION,
			:EXTINGUISH
		]
		return ability_blacklist.include?(abil.id)
	end
	
	return ret	
  end 
  #BEASTMODE
  alias CAL_pbCheckForm pbCheckForm
  def pbCheckForm(endOfRound = false)
    return if fainted? || @effects[PBEffects::Transform]
	CAL_pbCheckForm(endOfRound)
	
	# BEASTMODE
    if self.ability == :BEASTMODE
      if self.effects[PBEffects::BeastMode] < 5 && @form != 1
		  @battle.pbShowAbilitySplash(self, true)
		  @battle.pbHideAbilitySplash(self)
		  pbChangeForm(@form + 1, _INTL("{1} triggered!", abilityName))
      elsif self.effects[PBEffects::BeastMode] >= 5 && @form != 0
        @battle.pbShowAbilitySplash(self, true)
        @battle.pbHideAbilitySplash(self)
        pbChangeForm(@form - 1, _INTL("{1} triggered!", abilityName))
      end
    end
  end
  #BOULDERBARRIER #ARCANEMAGE
  alias CAL_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget
  def pbSuccessCheckAgainstTarget(move, user, target, targets)
	ret = CAL_pbSuccessCheckAgainstTarget(move, user, target, targets)
	
	return ret if @battle.moldBreaker
	
	if @battle.successStates[user.index].protected && target.hasActiveAbility?(:BOULDERBARRIER)
		target.effects[PBEffects::BoulderBarrier] = true
	elsif target.hasActiveAbility?(:BOULDERBARRIER)
		target.effects[PBEffects::BoulderBarrier] = false
	end
	
	if user.hasActiveAbility?(:ARCANEMAGE) && [:FIRE, :ICE, :ELECTRIC].include?(move.type) && target.pbHasType?(:DARK) 
		@battle.pbShowAbilitySplash(user)
		@battle.pbDisplay(_INTL("{1} is immune to Arcane Magic!", target.pbThis))
		ret = false
		@battle.pbHideAbilitySplash(user)
	end
	
	return ret
  end
  #SOUPFILLER
  alias CAL_pbEffectsAfterMove pbEffectsAfterMove
  def pbEffectsAfterMove(user, targets, move, numHits)
	if move.healingMove?
		@battle.battlers.each do |b|
			if b.opposes?(user) && b.hasActiveAbility?(:SOUPFILLER)
				@battle.pbShowAbilitySplash(b)
				b.pbRecoverHP(b.totalhp/8)
				@battle.pbHideAbilitySplash(b)
			end
		end
	end
  
	CAL_pbEffectsAfterMove(user, targets, move, numHits)
  end
end














