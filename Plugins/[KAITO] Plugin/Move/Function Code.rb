#===============================================================================
# Hydro Pump: Always hits in rain
#===============================================================================
class Battle::Move::AlwaysHitsInRain < Battle::Move
  def pbBaseAccuracy(user, target)
    # Accuracy = 0 means the move bypasses the accuracy check.
    return 0 if [:Rain, :HeavyRain].include?(user.effectiveWeather)
    return super
  end
end