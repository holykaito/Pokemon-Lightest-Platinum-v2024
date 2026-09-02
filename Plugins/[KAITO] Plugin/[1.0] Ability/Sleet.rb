#===============================================================================
# Ability: Sleet
# Pokémon Essentials v21.1
#
# Effect:
# During hail, this Pokémon damages opposing Pokémon by 1/8 max HP
# at the end of each turn.
#
# Thick Fat: takes half damage from Sleet.
# Magic Guard: immune to Sleet damage.
#
# Compatible safer handler for projects using M.A.G / AAM / Innate Abilities.
#===============================================================================

module SleetAbility
  HAIL_WEATHERS = [:Hail, :Snow].freeze

  def self.hail_active?(battle, weather = nil)
    return true if weather && HAIL_WEATHERS.include?(weather)
    return false if !battle
    return HAIL_WEATHERS.include?(battle.pbWeather)
  end

  def self.sleet_damage(target)
    damage = [target.totalhp / 8, 1].max

    if target.hasActiveAbility?(:THICKFAT)
      damage = [damage / 2, 1].max
    end

    return damage
  end
end

#===============================================================================
# Battle effect
#===============================================================================

Battle::AbilityEffects::EndOfRoundWeather.add(:SLEET,
  proc { |ability, *args|
    weather = nil
    battler = nil
    battle  = nil

    #---------------------------------------------------------------------------
    # Some plugins call:
    #   ability, weather, battler, battle
    #
    # Essentials-style handlers may call:
    #   ability, battler, battle
    #
    # This block safely supports both.
    #---------------------------------------------------------------------------
    if args.length >= 3 && args[0].is_a?(Symbol)
      weather = args[0]
      battler = args[1]
      battle  = args[2]
    else
      battler = args[0]
      battle  = args[1]
      weather = battle.pbWeather if battle
    end

    next if !battler
    next if !battle
    next if !battler.respond_to?(:fainted?)
    next if battler.fainted?
    next if !battler.hasActiveAbility?(:SLEET)
    next if !SleetAbility.hail_active?(battle, weather)

    showed_splash = false

    battle.allOtherSideBattlers(battler.index).each do |target|
      next if !target
      next if target.fainted?

      if !showed_splash
        battle.pbShowAbilitySplash(battler)
        showed_splash = true
      end

      # Magic Guard completely blocks Sleet damage.
      if target.hasActiveAbility?(:MAGICGUARD)
        battle.pbDisplay(_INTL("{1} was protected from {2}'s Sleet by Magic Guard!",
          target.pbThis, battler.pbThis(true)))
        next
      end

      damage = SleetAbility.sleet_damage(target)

      if target.hasActiveAbility?(:THICKFAT)
        battle.pbDisplay(_INTL("{1}'s Thick Fat weakened {2}'s Sleet!",
          target.pbThis, battler.pbThis(true)))
      end

      battle.pbDisplay(_INTL("{1}'s Sleet battered {2}!",
        battler.pbThis, target.pbThis(true)))

      target.pbTakeEffectDamage(damage)
      break if battle.decision > 0
    end

    battle.pbHideAbilitySplash(battler) if showed_splash
  }
)

#===============================================================================
# Sleet AI Support
# Pokémon Essentials v21.1 + safer compatibility for Kaito/AAM/M.A.G projects
#
# Ability:
# Sleet - During hail/snow, damages opposing Pokémon at the end of each turn.
#===============================================================================

module SleetAI
  HAIL_WEATHERS = [:Hail, :Snow].freeze

  def self.hail_active?(battle)
    return false if !battle
    return HAIL_WEATHERS.include?(battle.pbWeather)
  end

  def self.battler_has_sleet?(battler)
    return false if !battler
    return false if !battler.respond_to?(:hasActiveAbility?)
    return battler.hasActiveAbility?(:SLEET)
  end

  def self.ai_battler_has_sleet?(battler)
    return false if !battler

    if battler.respond_to?(:has_active_ability?)
      return battler.has_active_ability?(:SLEET)
    end

    if battler.respond_to?(:hasActiveAbility?)
      return battler.hasActiveAbility?(:SLEET)
    end

    return false
  end

  def self.has_sleet_on_same_side?(ai, user)
    return false if !ai
    return false if !user

    found = false

    if ai.respond_to?(:each_same_side_battler)
      ai.each_same_side_battler(user.side) do |b, i|
        next if !b
        if self.ai_battler_has_sleet?(b)
          found = true
          break
        end
      end
    end

    return found
  end

  def self.count_foes_alive(ai, user)
    return 0 if !ai
    return 0 if !user

    count = 0

    if ai.respond_to?(:each_foe_battler)
      ai.each_foe_battler(user.side) do |b, i|
        next if !b

        if b.respond_to?(:can_attack?)
          count += 1 if b.can_attack?
        elsif b.respond_to?(:fainted?)
          count += 1 if !b.fainted?
        else
          count += 1
        end
      end
    end

    return count
  end
end

#===============================================================================
# AI: Use Hail/Snow better if same side has Sleet
#===============================================================================

if defined?(Battle::AI::Handlers) &&
   defined?(Battle::AI::Handlers::MoveEffectScore)

  #---------------------------------------------------------------------------
  # Essentials thường dùng function code này cho move Hail.
  #---------------------------------------------------------------------------
  Battle::AI::Handlers::MoveEffectScore.add("StartHailWeather",
    proc { |score, move, user, ai, battle|
      next score if !battle
      next Battle::AI::MOVE_USELESS_SCORE if SleetAI.hail_active?(battle)

      if SleetAI.has_sleet_on_same_side?(ai, user)
        score += 20

        foe_count = SleetAI.count_foes_alive(ai, user)
        score += foe_count * 5
      end

      next score
    }
  )

  #---------------------------------------------------------------------------
  # Một số plugin Gen 9 / M.A.G có thể dùng Snow hoặc Snowscape.
  # Nếu function code này không tồn tại trong project thì cũng không sao,
  # handler chỉ nằm chờ, không gây lỗi cú pháp.
  #---------------------------------------------------------------------------
  Battle::AI::Handlers::MoveEffectScore.add("StartSnowWeather",
    proc { |score, move, user, ai, battle|
      next score if !battle
      next Battle::AI::MOVE_USELESS_SCORE if SleetAI.hail_active?(battle)

      if SleetAI.has_sleet_on_same_side?(ai, user)
        score += 20

        foe_count = SleetAI.count_foes_alive(ai, user)
        score += foe_count * 5
      end

      next score
    }
  )

end

#===============================================================================
# Optional AI: Ability ranking for Sleet
# Only runs if your AI plugin supports AbilityRanking.
#===============================================================================

if defined?(Battle::AI::Handlers) &&
   defined?(Battle::AI::Handlers::AbilityRanking)

  Battle::AI::Handlers::AbilityRanking.add(:SLEET,
    proc { |ability, score, battler, ai|
      # Giá trị cơ bản: Sleet là ability gây chip damage nên có ích.
      score += 3

      # Nếu đang có Hail/Snow, Sleet mạnh hơn nhiều.
      if ai && ai.respond_to?(:battle) && ai.battle
        score += 7 if SleetAI.hail_active?(ai.battle)
      end

      # Nếu Pokémon có move tạo Hail/Snow, tăng giá trị.
      if battler && battler.respond_to?(:moves)
        battler.moves.each do |m|
          next if !m
          next if !m.respond_to?(:id)

          if [:HAIL, :SNOWSCAPE].include?(m.id)
            score += 5
            break
          end
        end
      end

      next score
    }
  )

end


