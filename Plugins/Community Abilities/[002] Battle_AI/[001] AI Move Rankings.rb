#===============================================================================
# PoisonTarget
#===============================================================================
# GREYGOO Stuff tbh
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("PoisonTarget",
  proc { |score, move, user, target, ai, battle|
    PBDebug.log_ai("HELLO!")
	useless_score = (move.statusMove?) ? Battle::AI::MOVE_USELESS_SCORE : score
    next useless_score if target.has_active_ability?(:POISONHEAL)
	next useless_score if target.has_active_ability?(:GREYGOO)
    # No score modifier if the poisoning will be removed immediately
    next useless_score if target.has_active_item?([:PECHABERRY, :LUMBERRY])
    next useless_score if target.faster_than?(user) &&
                          target.has_active_ability?(:HYDRATION) &&
                          [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanPoison?(user.battler, false, move.move)
      add_effect = move.get_score_change_for_additional_effect(user, target)
      next useless_score if add_effect == -999   # Additional effect will be negated
      score += add_effect
      # Inherent preference
      score += 15
      # Prefer if the target is at high HP
      if ai.trainer.has_skill_flag?("HPAware")
        score += 15 * target.hp / target.totalhp
      end
      # Prefer if the user or an ally has a move/ability that is better if the target is poisoned
      ai.each_same_side_battler(user.side) do |b, i|
        score += 5 if b.has_move_with_function?("DoublePowerIfTargetPoisoned",
                                                "DoublePowerIfTargetStatusProblem")
        score += 10 if b.has_active_ability?(:MERCILESS)
      end
      # Don't prefer if target benefits from having the poison status problem
      score -= 8 if target.has_active_ability?([:GUTS, :MARVELSCALE, :QUICKFEET, :TOXICBOOST])
      score -= 25 if target.has_active_ability?(:POISONHEAL)
	  score -= 25 if target.has_active_ability?(:GREYGOO)
      score -= 20 if target.has_active_ability?(:SYNCHRONIZE) &&
                     user.battler.pbCanPoisonSynchronize?(target.battler)
      score -= 5 if target.has_move_with_function?("DoublePowerIfUserPoisonedBurnedParalyzed",
                                                   "CureUserBurnPoisonParalysis")
      score -= 15 if target.check_for_move { |m|
        m.function_code == "GiveUserStatusToTarget" && user.battler.pbCanPoison?(target.battler, false, m)
      }
      # Don't prefer if the target won't take damage from the poison
      score -= 20 if !target.battler.takesIndirectDamage?
      # Don't prefer if the target can heal itself (or be healed by an ally)
      if target.has_active_ability?(:SHEDSKIN)
        score -= 8
      elsif target.has_active_ability?(:HYDRATION) &&
            [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
        score -= 15
      end
      ai.each_same_side_battler(target.side) do |b, i|
        score -= 8 if i != target.index && b.has_active_ability?(:HEALER)
      end
    end
    next score
  }
)

Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("PoisonTarget","BadPoisonTarget")

Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("TargetMovesBecomeElectric",
  proc { |score, move, user, target, ai, battle|
    # Get Electric's effectiveness against the user
    electric_eff = user.effectiveness_of_type_against_battler(:ELECTRIC, target)
    electric_eff *= 1.5 if target.has_type?(:ELECTRIC)   # STAB
    electric_eff = 0 if user.has_active_ability?([:LIGHTNINGROD, :MOTORDRIVE, :VOLTABSORB])
    # For each of target's moves, get its effectiveness against the user and
    # decide whether it is better or worse than Electric's effectiveness
    old_type_better = 0
    electric_type_better = 0
    target.battler.eachMove do |m|
      next if !m.damagingMove?
      m_type = m.pbCalcType(target.battler)
      next if m_type == :ELECTRIC
      eff = user.effectiveness_of_type_against_battler(m_type, target, m)
      eff *= 1.5 if target.has_type?(m_type)   # STAB
      case m_type
      when :FIRE
        eff = 0 if user.has_active_ability?(:FLASHFIRE)
      when :GRASS
        eff = 0 if user.has_active_ability?(:SAPSIPPER)
      when :WATER
        eff = 0 if user.has_active_ability?([:STORMDRAIN, :WATERABSORB])
	  when :POISON
		eff = 0 if user.has_active_ability?([:GREYGOO])
      end
      if eff > electric_eff
        electric_type_better += 1
      elsif eff < electric_eff
        old_type_better += 1
      end
    end
    next Battle::AI::MOVE_USELESS_SCORE if electric_type_better == 0
    next Battle::AI::MOVE_USELESS_SCORE if electric_type_better < old_type_better
    score += 10 * (electric_type_better - old_type_better)
    next score
  }
)



