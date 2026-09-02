class Battle::AI

  KAITO_BASE_ABILITY_RATINGS = {
    6 => [:HYPERCHARGE, :AGILE],
    7 => [:HALFDRAKE, :FIERYSPIRIT, :BUGBOUND, :TERRORSOWER],
    8 => [:TRAUMATICFIST, :KINTSUGI, :PRECISEFIST],
    9 => [:DISTORTION]
  }

end

if defined?(Battle::AI::Handlers) &&
   defined?(Battle::AI::Handlers::AbilityRanking)

  Battle::AI::Handlers::AbilityRanking.add(:HYPERCHARGE,
    proc { |ability, score, battler, ai|
      next score if battler.check_for_move { |m| m.type == :ELECTRIC }
      next 0
    }
  )

end

