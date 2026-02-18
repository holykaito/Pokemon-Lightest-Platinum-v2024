###########################################################################
###########################################################################
###########################################################################
Battle::AI::Handlers::AbilityRanking.add(:CORRUPTEDCODE,
  proc { |ability, score, battler, ai|
    next score if battler.has_damaging_move_of_type?(:POISON)
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:AQUATICBLOOD,
  proc { |ability, score, battler, ai|
    next score if battler.has_damaging_move_of_type?(:WATER)
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:EXPEDITIOUS,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| !m.statusMove?}
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:RUSTEDFEATHERS,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| !m.statusMove? }
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:MADSCIENTIST,
  proc { |ability, score, battler, ai|
    next score if battler.has_damaging_move_of_type?(:FIRE)
	next score if battler.has_damaging_move_of_type?(:FAIRY)
	next score if battler.has_damaging_move_of_type?(:POISON)
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:UNCONCERNED,
  proc { |ability, score, battler, ai|
    next score if battler.has_damaging_move_of_type?(:NORMAL)
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:MAGICJAW,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| m.bitingMove? }
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:WINDSWEPT,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| m.type == :FLYING }
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:QUICKCHARGE,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| m.chargingTurnMove? }
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:KINGSWRATH,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| m.drillMove? }
	next score if battler.check_for_move { |m| m.hornMove? }
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:HESSAFE,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| m.recoilMove? && !m.is_a?(Battle::Move::CrashDamageIfFailsUnusableInGravity) }
    next 0
  }
)

###########################################################################
###########################################################################
###########################################################################

Battle::AI::Handlers::AbilityRanking.add(:ARCANEMAGE,
  proc { |ability, score, battler, ai|
    next score if battler.has_damaging_move_of_type?(:FIRE)
	next score if battler.has_damaging_move_of_type?(:ELECTRIC)
	next score if battler.has_damaging_move_of_type?(:ICE)
    next 0
  }
)





















