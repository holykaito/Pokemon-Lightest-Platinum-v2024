###########################################################################
###########################################################################
###########################################################################
Battle::AbilityEffects::OnBeingHit.add(:CORRUPTEDCODE,
  proc { |ability, user, target, move, battle|
    next if user.fainted?
    next if user.effects[PBEffects::Disable] > 0
    regularMove = nil
    user.eachMove do |m|
      next if m.id != user.lastRegularMoveUsed
      regularMove = m
      break
    end
    next if !regularMove || (regularMove.pp == 0 && regularMove.total_pp > 0)
    next if battle.pbRandom(100) >= 30
    battle.pbShowAbilitySplash(target)
    if !move.pbMoveFailedAromaVeil?(target, user, Battle::Scene::USE_ABILITY_SPLASH)
      user.effects[PBEffects::Disable]     = 3
      user.effects[PBEffects::DisableMove] = regularMove.id
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1}'s {2} was disabled!", user.pbThis, regularMove.name))
      else
        battle.pbDisplay(_INTL("{1}'s {2} was disabled by {3}'s {4}!",
           user.pbThis, regularMove.name, target.pbThis(true), target.abilityName))
      end
      battle.pbHideAbilitySplash(target)
      user.pbItemStatusCureCheck
    end
    battle.pbHideAbilitySplash(target)
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:CORRUPTEDCODE,
  proc { |ability, user, target, move, mults, power, type|
    mults[:attack_multiplier] *= 1.5 if type == :POISON
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::DamageCalcFromUser.add(:AQUATICBLOOD,
  proc { |ability, user, target, move, mults, power, type|
    mults[:attack_multiplier] *= 1.5 if type == :WATER
  }
)

Battle::AbilityEffects::DamageCalcFromTarget.add(:AQUATICBLOOD,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] /= 2 if [:FIRE, :ICE, :STEEL, :WATER].include?(type)
	mults[:power_multiplier] *= 2 if [:ELECTRIC, :GRASS].include?(type)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::PriorityChange.add(:EXPEDITIOUS,
  proc { |ability, battler, move, pri|
    next pri + 1 if (!move.statusMove?)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::CriticalCalcFromUser.add(:GOODLUCK,
  proc { |ability, user, target, c|
    next c + 1
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnDealingHit.add(:TOXICWATERS,
  proc { |ability, user, target, move, battle|
    next if move.type != :WATER
    next if battle.pbRandom(100) >= 20
    battle.pbShowAbilitySplash(user)
    if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      battle.pbShowAbilitySplash(target)
      if !Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
      end
      battle.pbHideAbilitySplash(target)
    elsif target.pbCanPoison?(user, Battle::Scene::USE_ABILITY_SPLASH)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} poisoned {3}!", user.pbThis, user.abilityName, target.pbThis(true))
      end
      target.pbPoison(user, msg)
    end
    battle.pbHideAbilitySplash(user)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnDealingHit.add(:BURNINGSTEAM,
  proc { |ability, user, target, move, battle|
    next if move.type != :WATER
    next if battle.pbRandom(100) >= 20
    battle.pbShowAbilitySplash(user)
    if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      battle.pbShowAbilitySplash(target)
      if !Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
      end
      battle.pbHideAbilitySplash(target)
    elsif target.pbCanBurn?(user, Battle::Scene::USE_ABILITY_SPLASH)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} burned {3}!", user.pbThis, user.abilityName, target.pbThis(true))
      end
      target.pbBurn(user, msg)
    end
    battle.pbHideAbilitySplash(user)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::SpeedCalc.add(:RUSTEDFEATHERS,
  proc { |ability, battler, mult|
    next mult / 2
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:RUSTEDFEATHERS,
  proc { |ability, user, target, move, mults, power, type|
    mults[:attack_multiplier] /= 2
  }
)

Battle::AbilityEffects::DamageCalcFromTarget.add(:RUSTEDFEATHERS,
  proc { |ability, user, target, move, mults, power, type|
	mults[:power_multiplier] *= 2 if [:WATER].include?(type)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::MoveImmunity.add(:GREYGOO,
  proc { |ability, user, target, move, type, battle, show_message|
    next target.pbMoveImmunityHealingAbility(user, move, type, :POISON, show_message)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::DamageCalcFromUser.add(:MADSCIENTIST,
  proc { |ability, user, target, move, mults, power, type|
    mults[:attack_multiplier] *= 1.5 if type == :FIRE || type == :POISON || type == :FAIRY
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnEndOfUsingMove.add(:QUEENSPOTENTIAL,
  proc { |ability, user, targets, move, battle|
    next if battle.pbAllFainted?(user.idxOpposingSide)
    numFainted = 0
    targets.each { |b| numFainted += 1 if b.damageState.fainted }
    next if numFainted == 0 
	user.effects[PBEffects::FocusEnergy] += 1
	
	battle.pbShowAbilitySplash(user)
	battle.pbDisplay(_INTL("{1} is focusing!", user.name))
	battle.pbHideAbilitySplash(user)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnBeingHit.add(:MUTATION,
  proc { |ability, user, target, move, battle|
	next if !user.pbCanRaiseStatStage?(:ATTACK, user) && !user.pbCanLowerStatStage?(:SPEED, user)
  
    target.pbRaiseStatStageByAbility(:ATTACK, 1, target)
	target.pbLowerStatStageByAbility(:SPEED, 1, target)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnAnyStatLoss.add(:PHANTOMTHIEF,
  proc { |ability, battler, stat, user, increment,battle|
	next if battler && !battler.opposes?(user)
	next if !battler.pbCanRaiseStatStage?(stat, battler)
	battler.pbRaiseStatStageByAbility(stat, increment, battler)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnEndOfUsingMove.add(:BACKSWING,
  proc { |ability, user, targets, move, battle|
    next if battle.pbAllFainted?(user.idxOpposingSide)
	next if !user.lastMoveFailed
	next if !user.pbCanRaiseStatStage?(:ATTACK, user) && !user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user)
	
	user.pbRaiseStatStageByAbility(:ATTACK, 1, user)
	user.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, user)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::DamageCalcFromUser.add(:UNCONCERNED,
  proc { |ability, user, target, move, mults, power, type|
	next if type != :NORMAL
    mults[:attack_multiplier] *= 2 if target.pbHasType?(:ROCK)
	mults[:attack_multiplier] *= 2 if target.pbHasType?(:STEEL)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnDealingHit.add(:MAGICJAW,
  proc { |ability, user, target, move, battle|
    next if !move.bitingMove?
    next if battle.pbRandom(100) >= 30
	
	CALStatuses = [:SLEEP,:POISON,:BURN,:PARALYSIS,:FROZEN]
	CALStatus = CALStatuses.sample

	battle.pbShowAbilitySplash(user)
		if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
			battle.pbShowAbilitySplash(target)
		if !Battle::Scene::USE_ABILITY_SPLASH
			battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
		end
			battle.pbHideAbilitySplash(target)
	elsif target.pbCanInflictStatus?(CALStatus,user,Battle::Scene::USE_ABILITY_SPLASH) 
		msg = nil
		if CALStatus == :SLEEP
			target.pbInflictStatus(CALStatus,target.pbSleepDuration,msg,user)
		elsif CALStatus == :FROZEN
			target.pbInflictStatus(CALStatus,0,msg)
		else
			target.pbInflictStatus(CALStatus,0,msg,user)
		end
	end
	battle.pbHideAbilitySplash(user)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::EndOfRoundEffect.add(:SWEETDREAMS,
  proc { |ability, battler, battle|
    battle.allBattlers.each do |b|
      next if !b.asleep?
	  next if !b.canHeal?
	  
      battle.pbShowAbilitySplash(battler)
      b.pbRecoverHP(b.totalhp / 16)
	  
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} is relaxed!", b.pbThis))
      else
        battle.pbDisplay(_INTL("{1} is relaxed by {2}'s {3}!",b.pbThis, battler.pbThis(true), battler.abilityName))
      end
	  
      battle.pbHideAbilitySplash(battler)
    end
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnStatLossWithIncrement.add(:PRACTICAL,
  proc { |ability, battler, stat, user, increment|
    next if user && !user.opposes?(battler)
	#next if !battler.hasActiveAbility?(:PRACTICAL)
	
	case stat
	when :ATTACK
		battler.pbRaiseStatStageByAbility(:DEFENSE, increment, battler)
	when :DEFENSE
		battler.pbRaiseStatStageByAbility(:ATTACK, increment, battler)
	when :SPECIAL_ATTACK
		battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, increment, battler)
	when :SPECIAL_DEFENSE
		battler.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, increment, battler)
	end
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::DamageCalcFromTarget.add(:SOLARFIELD,
  proc { |ability, user, target, move, mults, power, type|
    if move.specialMove? && [:Sun, :HarshSun].include?(target.effectiveWeather)
      mults[:defense_multiplier] *= 1.5
    end
  }
)

Battle::AbilityEffects::EndOfRoundWeather.add(:SOLARFIELD,
  proc { |ability, weather, battler, battle|
    next if ![:Sun, :HarshSun].include?(weather)
	
	battle.allSameSideBattlers(battler.index).each do |b|
		next if !b
		next if !b.canHeal?
		next if !b.pbHasType?(:GRASS)
		
		
		battle.pbShowAbilitySplash(battler)
		b.pbRecoverHP(b.totalhp / 16, b)
		battle.pbDisplay(_INTL("{1} was healed by Solar Field!", b.pbThis))
		battle.pbHideAbilitySplash(battler)
	end
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::DamageCalcFromTarget.add(:COMPACTEDICE,
  proc { |ability, user, target, move, mults, power, type|
	next if type != :ROCK && type != :STEEL	
	targetTypes = target.pbTypes
	
	targetTypes.each do |monType|
		case type
		when :ROCK
			if Effectiveness.super_effective_type?(:ROCK,monType)
				mults[:power_multiplier] /= 2
			elsif Effectiveness.resistant_type?(:ROCK,monType)
				mults[:power_multiplier] *= 2
			end
		when :STEEL
			if Effectiveness.super_effective_type?(:STEEL,monType)
				mults[:power_multiplier] /= 2
			elsif Effectiveness.resistant_type?(:STEEL,monType)
				mults[:power_multiplier] *= 2
			end
		end
	end
  }
)

Battle::AbilityEffects::OnBeingHit.add(:COMPACTEDICE,
  proc { |ability, user, target, move, battle|
	next if move.type != :ROCK && move.type != :STEEL	
    target.pbRaiseStatStageByAbility(:DEFENSE, 1, target)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::ModifyMoveBaseType.add(:NEUTRALIZE,
  proc { |ability, user, move, type|
    next if !GameData::Type.exists?(:QMARKS)
    next :QMARKS
  }
)

Battle::AbilityEffects::DamageCalcFromUser.add(:NEUTRALIZE,
  proc { |ability, user, target, move, mults, power, type|
	next if type != :QMARKS
	mults[:attack_multiplier] *= 1.8
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnEndOfUsingMove.add(:WINDSWEPT,
  proc { |ability, user, targets, move, battle|
    next if battle.pbAllFainted?(user.idxOpposingSide)
	next if move.type != :FLYING
	next if user.pbOwnSide.effects[PBEffects::Tailwind] > 0
	
	battle.pbShowAbilitySplash(user)
	user.pbOwnSide.effects[PBEffects::Tailwind] = 4
	battle.pbAnimation(:TAILWIND, user, targets)
	battle.pbDisplay(_INTL("The Tailwind blew from behind {1}!", user.pbTeam(true)))
	battle.pbHideAbilitySplash(user)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnHPDroppedBelowHalf.add(:SCARECROW,
  proc { |ability, battler, move_user, battle|
    next false if battler.effects[PBEffects::SkyDrop] >= 0 || battler.inTwoTurnAttack?("TwoTurnAttackInvulnerableInSkyTargetCannotAct")   # Sky Drop
    next false if battle.pbAllFainted?(battler.idxOpposingSide)
	next false if battler.effects[PBEffects::Substitute] > 0
	
	@subLife = [battler.totalhp / 4, 1].max
    next false if battler.hp <= @subLife
	
	battle.pbShowAbilitySplash(battler, true)
    battle.pbHideAbilitySplash(battler)
	
	battle.pbAnimation(:SUBSTITUTE, battler, battler)
	battler.pbReduceHP(@subLife, false, false)
	battler.pbItemHPHealCheck
	
	battler.effects[PBEffects::Trapping]     = 0
    battler.effects[PBEffects::TrappingMove] = nil
    battler.effects[PBEffects::Substitute]   = @subLife
    battle.pbDisplay(_INTL("{1} created a scarecrow!", battler.pbThis))
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::DamageCalcFromUser.add(:KINGSWRATH,
  proc { |ability, user, target, move, mults, power, type|
	next if !move.drillMove? && !move.hornMove?
	
	mults[:attack_multiplier] *= 1.3
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::StatLossImmunity.add(:ECHOLOCATION,
  proc { |ability, battler, stat, battle, showMessages|
    next false if stat != :ACCURACY
    if showMessages
      battle.pbShowAbilitySplash(battler)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1}'s {2} cannot be lowered!", battler.pbThis, GameData::Stat.get(stat).name))
      else
        battle.pbDisplay(_INTL("{1}'s {2} prevents {3} loss!", battler.pbThis,
           battler.abilityName, GameData::Stat.get(stat).name))
      end
      battle.pbHideAbilitySplash(battler)
    end
    next true
  }
)

Battle::AbilityEffects::DamageCalcFromTarget.add(:ECHOLOCATION,
  proc { |ability, user, target, move, mults, power, type|
    mults[:final_damage_multiplier] *= 1.5 if move.soundMove?
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnVictoryStarEvolution.add(:VICTORYSTAR,
  proc { |ability, user, battle|
    next if user.effects[PBEffects::VictoryStarEvo] != 1
	
	battle.pbShowAbilitySplash(user)
	user.pbLowerStatStage(:ATTACK, 3, user)
	user.pbLowerStatStage(:SPECIAL_ATTACK, 3, user)
	user.pbLowerStatStage(:SPEED, 3, user)
	battle.pbHideAbilitySplash(user)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::StatusImmunityNonIgnorable.add(:POWERSHIELD,
  proc { |ability, battler, status|
	next true if status != :SLEEP
  }
)

Battle::AbilityEffects::DamageCalcFromTarget.add(:POWERSHIELD,
  proc { |ability, user, target, move, mults, power, type|
	targetTypes = target.pbTypes
	
	targetTypes.each do |monType|
		if Effectiveness.super_effective_type?(type,monType)
			mults[:power_multiplier] /= 2
		elsif Effectiveness.resistant_type?(type,monType)
			mults[:power_multiplier] *= 2
		end
	end
	
	mults[:power_multiplier] /= 2
  }
)

Battle::AbilityEffects::ModifyMoveBaseType.add(:POWERSHIELD,
  proc { |ability, user, move, type|
    next if !GameData::Type.exists?(:QMARKS)
    next :QMARKS
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::OnAnyStatLoss.add(:RAGEBAITING,
  proc { |ability, battler, stat, user, increment,battle|
	next if battler && !battler.opposes?(user)
	next if user.effects[PBEffects::RageBaited] == true

	battle.pbShowAbilitySplash(battler)
	user.effects[PBEffects::Trapping] = 2 
	user.effects[PBEffects::TrappingMove] = "RAGEBAITING"
	user.effects[PBEffects::RageBaited] = true
	user.pbReduceHP(user.totalhp / 8, false)
	
	msg = _INTL("{1} is baited into a rage!", user.pbThis)
	battle.pbDisplay(msg)
	battle.pbHideAbilitySplash(battler)
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::EndOfRoundEffect.add(:BEASTMODE,
  proc { |ability, battler, battle|
	battler.effects[PBEffects::BeastMode] += 1 if battler.effects[PBEffects::BeastMode] < 10
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::DamageCalcFromUser.add(:BOULDERBARRIER,
  proc { |ability, user, target, move, mults, power, type|
	mults[:attack_multiplier] *= 1.5 if user.effects[PBEffects::BoulderBarrier] && type == :ROCK
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::DamageCalcFromUser.add(:ARCANEMAGE,
  proc { |ability, user, target, move, mults, power, type|
	mults[:attack_multiplier] *= 1.5 if [:FIRE, :ICE, :ELECTRIC].include?(type) 
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::AccuracyCalcFromUser.add(:QUICKSTRIKE,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if user.effects[PBEffects::FirstMove] == true
  }
)

Battle::AbilityEffects::PriorityBracketChange.add(:QUICKSTRIKE,
  proc { |ability, battler, battle|
    next 1 if battler.effects[PBEffects::FirstMove] == true
  }
)

Battle::AbilityEffects::EndOfRoundEffect.add(:QUICKSTRIKE,
  proc { |ability, battler, battle|
    next if !battle.field.effects[PBEffects::QuickStrike]
    next if battle.pbAllFainted?(battler.idxOpposingSide)
	battler.effects[PBEffects::FirstMove] = false
	battle.field.effects[PBEffects::QuickStrike].push(battler.displayPokemon.personalID)
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:QUICKSTRIKE,
  proc { |ability, battler, battle, switch_in|
    battle.field.effects[PBEffects::QuickStrike] = [] if !battle.field.effects[PBEffects::QuickStrike]
	if battle.field.effects[PBEffects::QuickStrike].include?(battler.displayPokemon.personalID)
		battler.effects[PBEffects::FirstMove] = false
	else
		battler.effects[PBEffects::FirstMove] = true
	end
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AbilityEffects::DamageCalcFromTarget.add(:IGNITION,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] /= 2 if type == :FIRE
  }
)

Battle::AbilityEffects::OnBeingHit.add(:IGNITION,
  proc { |ability, user, target, move, battle|
	next if move.type != :FIRE	
    battle.pbShowAbilitySplash(target, true)
	battle.pbHideAbilitySplash(target)
	target.pbChangeForm(target.form + 1, _INTL("{1} was ignited!", target.pbThis))
  }
)

Battle::AbilityEffects::DamageCalcFromTarget.add(:EXTINGUISH,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] /= 2 if type == :WATER
  }
)

Battle::AbilityEffects::OnBeingHit.add(:EXTINGUISH,
  proc { |ability, user, target, move, battle|
	next if move.type != :WATER	
    battle.pbShowAbilitySplash(target, true)
	battle.pbHideAbilitySplash(target)
	target.pbChangeForm(target.form - 1, _INTL("{1} was extinguished!", target.pbThis))
  }
)





















