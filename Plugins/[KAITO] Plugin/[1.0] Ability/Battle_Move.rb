#===============================================================================
# Pyromancy
# Increases the chance of burning from attack additional effects by 5 times.
#===============================================================================

class Battle::Move
  alias pyromancy_pbAdditionalEffectChance pbAdditionalEffectChance

  def pbAdditionalEffectChance(user, target, effectChance = 0)
    ret = pyromancy_pbAdditionalEffectChance(user, target, effectChance)

    if user.hasActiveAbility?(:PYROMANCY) &&
       damagingMove? &&
       function_code.include?("Burn") &&
       ret > 0
      ret *= 3
      ret = 100 if ret > 100
    end

    return ret
  end
end

#===============================================================================
# Precise Fist
# Punching moves gain +1 critical hit chance and double secondary effects.
#===============================================================================

# Đánh dấu move hiện tại có phải punching move không.
Battle::AbilityEffects::AccuracyCalcFromUser.add(:PRECISEFIST,
  proc { |ability, mods, user, target, move, type|
    user.instance_variable_set(:@precise_fist_punching_move, move && move.punchingMove?)
  }
)

# Nếu move hiện tại là punching move thì +1 crit stage.
Battle::AbilityEffects::CriticalCalcFromUser.add(:PRECISEFIST,
  proc { |ability, user, target, crit_stage|
    if user.instance_variable_get(:@precise_fist_punching_move)
      next crit_stage + 1
    end
    next crit_stage
  }
)

# Xóa dấu sau khi dùng move xong.
Battle::AbilityEffects::OnEndOfUsingMove.add(:PRECISEFIST,
  proc { |ability, user, targets, move, battle|
    user.instance_variable_set(:@precise_fist_punching_move, false)
  }
)

# Nhân đôi secondary effect chance của punching move.
class Battle::Move
  if method_defined?(:pbAdditionalEffectChance)
    alias precise_fist_pbAdditionalEffectChance pbAdditionalEffectChance

    def pbAdditionalEffectChance(user, target, effectChance = 0)
      ret = precise_fist_pbAdditionalEffectChance(user, target, effectChance)

      if user.hasActiveAbility?(:PRECISEFIST) && punchingMove? && ret > 0
        ret *= 2
        ret = 100 if ret > 100
      end

      return ret
    end
  end
end