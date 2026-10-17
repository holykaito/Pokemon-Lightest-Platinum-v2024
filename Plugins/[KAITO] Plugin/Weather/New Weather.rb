#===============================================================================
# Gloom Moonlight - Pokemon Essentials v21.1
# Weather ID: :GloomMoonlight
#===============================================================================

GameData::BattleWeather.register({
  :id        => :GloomMoonlight,
  :name      => _INTL("Gloom Moonlight"),
  :animation => "gloommoon"
})

module GloomMoonlight
  WEATHER = :GloomMoonlight

  #=============================================================================
  # Weather messages.
  # Keep the engine's existing duration, callbacks and weather effects.
  #=============================================================================
  module BattleHooks
    def pbStartWeather(user, newWeather, fixedDuration = false, showAnim = true)
      old_weather = @field.weather
      result = super

      if old_weather != @field.weather &&
         @field.weather == GloomMoonlight::WEATHER
        pbDisplay(_INTL("Gloomy moonlight shrouded the battlefield!"))
      end

      return result
    end

    def pbWeatherStartMessage
      if @field.weather == GloomMoonlight::WEATHER
        pbDisplay(_INTL("Gloomy moonlight shrouds the battlefield!"))
        return
      end
      super
    end

    def pbEOREndWeather(priority)
      if @field.weather == GloomMoonlight::WEATHER
        if @field.weatherDuration == 1
          pbDisplay(_INTL("The gloomy moonlight faded."))
        elsif @field.weatherDuration != 0
          pbDisplay(_INTL("Gloomy moonlight bathes the battlefield."))
        end
      end

      super
    end
  end

  #=============================================================================
  # Dark damage x1.5.
  # effectiveWeather respects Air Lock and Cloud Nine.
  # Using the resolved type also supports moves whose type changes.
  #=============================================================================
  module DamageHooks
    def pbCalcDamageMultipliers(user, target, numTargets, type,
                                baseDmg, multipliers)
      result = super

      if type == :DARK &&
         user.effectiveWeather == GloomMoonlight::WEATHER
        multipliers[:final_damage_multiplier] *= 1.5
      end

      return result
    end
  end

  #=============================================================================
  # Weather-dependent healing.
  # Outside Gloom Moonlight, preserve existing plugin behavior.
  #=============================================================================
  module HealingHooks
    def pbHealAmount(user)
      if user.effectiveWeather == GloomMoonlight::WEATHER
        case @id
        when :MOONLIGHT
          return (user.totalhp * 3 / 4.0).round
        when :SYNTHESIS, :MORNINGSUN
          return (user.totalhp / 4.0).round
        end
      end

      super
    end
  end
end

Battle.prepend(GloomMoonlight::BattleHooks)

#===============================================================================
# Gloom Moonlight damage boost - compatible with M.A.G alias hooks
#===============================================================================
class Battle::Move
  unless method_defined?(:gloom_moonlight_original_damage_multipliers)
    alias_method :gloom_moonlight_original_damage_multipliers,
                 :pbCalcDamageMultipliers
  end

  def pbCalcDamageMultipliers(user, target, numTargets, type,
                             baseDmg, multipliers)
    result = gloom_moonlight_original_damage_multipliers(
      user, target, numTargets, type, baseDmg, multipliers
    )

    if type == :DARK &&
       user.effectiveWeather == GloomMoonlight::WEATHER
      multipliers[:final_damage_multiplier] *= 1.5
    end

    return result
  end
end

Battle::Move::HealUserDependingOnWeather.prepend(
  GloomMoonlight::HealingHooks
)

#===============================================================================
# Optional move function: starts Gloom Moonlight for 5 turns.
# Inherits standard weather move failure checks, including primordial weather.
#===============================================================================
class Battle::Move::StartGloomMoonlightWeather < Battle::Move::WeatherMove
  def initialize(battle, move)
    super
    @weatherType = GloomMoonlight::WEATHER
  end
end