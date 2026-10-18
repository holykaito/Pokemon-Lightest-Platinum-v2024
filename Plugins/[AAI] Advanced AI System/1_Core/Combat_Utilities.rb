#===============================================================================
# Advanced AI System - Combat Utilities (Shared Functions)
# Centralized damage calculation and common combat utilities
#===============================================================================

module AdvancedAI
  module CombatUtilities
    
    #===========================================================================
    # HP Percentage Calculations (DRY - Don't Repeat Yourself)
    #===========================================================================
    
    def self.hp_percent(battler)
      return 0 unless battler && battler.totalhp > 0
      battler.hp.to_f / battler.totalhp
    end
    
    def self.hp_threshold_score(hp_percent, thresholds)
      # Generic HP-based scoring
      # thresholds: Hash like { 0.33 => 80, 0.50 => 50, 0.70 => 30 }
      thresholds.each do |threshold, score|
        return score if hp_percent < threshold
      end
      return 0
    end
    
    #===========================================================================
    # Move Type & Power Resolution (Shared Helpers)
    #===========================================================================
    
    # Resolve the effective type of a move considering -ate abilities, Tera Blast,
    # Weather Ball, and Terrain Pulse.
    # Works with both Battler objects (hasActiveAbility?) and Pokemon objects (ability_id).
    def self.resolve_move_type(user, move)
      effective_type = move.type
      # Handle -ate abilities: Normal moves → typed
      if effective_type == :NORMAL
        ate_map = { PIXILATE: :FAIRY, AERILATE: :FLYING, REFRIGERATE: :ICE, GALVANIZE: :ELECTRIC }
        if user.respond_to?(:hasActiveAbility?)
          ate_ability = ate_map.keys.find { |a| user.hasActiveAbility?(a) }
        elsif user.respond_to?(:ability_id)
          ate_ability = ate_map.keys.find { |a| user.ability_id == a }
        end
        effective_type = ate_map[ate_ability] if ate_ability
      end
      # Normalize: all moves become Normal type
      if user.respond_to?(:hasActiveAbility?)
        effective_type = :NORMAL if user.hasActiveAbility?(:NORMALIZE) && effective_type != :NORMAL
      elsif user.respond_to?(:ability_id)
        effective_type = :NORMAL if user.ability_id == :NORMALIZE && effective_type != :NORMAL
      end
      # Liquid Voice: sound moves become Water type
      if move.respond_to?(:soundMove?) && move.soundMove?
        if user.respond_to?(:hasActiveAbility?)
          effective_type = :WATER if user.hasActiveAbility?(:LIQUIDVOICE)
        elsif user.respond_to?(:ability_id)
          effective_type = :WATER if user.ability_id == :LIQUIDVOICE
        end
      end
      # Handle Tera Blast: becomes user's Tera type when Terastallized
      if move.respond_to?(:id) && move.id == :TERABLAST
        battler = user.respond_to?(:battler) ? user.battler : user
        if battler.respond_to?(:tera?) && battler.tera?
          tera_type = battler.respond_to?(:tera_type) ? battler.tera_type : nil
          if !tera_type && battler.respond_to?(:pokemon) && battler.pokemon.respond_to?(:tera_type)
            tera_type = battler.pokemon.tera_type
          end
          effective_type = tera_type if tera_type
        end
      end
      # Handle Weather Ball: type changes based on active weather
      if move.respond_to?(:id) && move.id == :WEATHERBALL
        battle = user.respond_to?(:battle) ? user.battle : nil
        if battle
          weather = battle.pbWeather rescue :None
          case weather
          when :Sun, :HarshSun   then effective_type = :FIRE
          when :Rain, :HeavyRain then effective_type = :WATER
          when :Sandstorm        then effective_type = :ROCK
          when :Hail, :Snow      then effective_type = :ICE
          end
        end
      end
      # Handle Terrain Pulse: type changes based on active terrain (grounded user)
      if move.respond_to?(:id) && move.id == :TERRAINPULSE
        battle = user.respond_to?(:battle) ? user.battle : nil
        if battle
          terrain = battle.field.terrain rescue nil
          if terrain && user.respond_to?(:affectedByTerrain?) && user.affectedByTerrain?
            case terrain
            when :Electric then effective_type = :ELECTRIC
            when :Grassy   then effective_type = :GRASS
            when :Psychic  then effective_type = :PSYCHIC
            when :Misty    then effective_type = :FAIRY
            end
          end
        end
      end
      if move.respond_to?(:function_code) && move.function_code == "TypeAndPowerDependOnUserBerry"
        real_move = move.respond_to?(:move) ? move.move : move
        real_user = user.respond_to?(:battler) ? user.battler : user
        effective_type = real_move.pbBaseType(real_user) rescue effective_type
      end
      effective_type
    end
    
    # Calculate type effectiveness accounting for Scrappy / Mind's Eye.
    # Scrappy/Mind's Eye allow Normal and Fighting moves to hit Ghost types.
    # Works with both Battler objects (hasActiveAbility?) and Pokemon objects (ability_id).
    def self.scrappy_effectiveness(effective_type, user, defender_types)
      type_mod = Effectiveness.calculate(effective_type, *defender_types)
      if Effectiveness.ineffective?(type_mod) && [:NORMAL, :FIGHTING].include?(effective_type)
        has_scrappy = if user.respond_to?(:hasActiveAbility?)
                        user.hasActiveAbility?(:SCRAPPY) || user.hasActiveAbility?(:MINDSEYE)
                      elsif user.respond_to?(:ability_id)
                        ([:SCRAPPY, :MINDSEYE].include?(user.ability_id) rescue false)
                      else
                        false
                      end
        if has_scrappy
          non_ghost = defender_types.reject { |t| t == :GHOST }
          type_mod = non_ghost.empty? ? Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER :
                     Effectiveness.calculate(effective_type, *non_ghost)
        end
      end
      type_mod
    end

    def self.move_type_effectiveness(move, user, defender, effective_type = nil)
      effective_type ||= resolve_move_type(user, move)
      defender_types = if defender.respond_to?(:pbTypes)
                         defender.pbTypes(true)
                       else
                         (defender.types rescue [:NORMAL])
                       end
      freeze_dry = (move.respond_to?(:function_code) &&
                    move.function_code == "FreezeTargetSuperEffectiveAgainstWater") ||
                   (move.respond_to?(:id) && move.id == :FREEZEDRY)
      if freeze_dry
        type_mod = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
        defender_types.each do |defender_type|
          multiplier = if defender_type == :WATER
                         Effectiveness::SUPER_EFFECTIVE_MULTIPLIER
                       else
                         Effectiveness.calculate(effective_type, defender_type)
                       end
          type_mod = type_mod * multiplier / Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
        end
        return type_mod
      end
      grounds_target = move.respond_to?(:function_code) &&
                       move.function_code == "HitsTargetInSkyGroundsTarget" &&
                       effective_type == :GROUND
      battle = (user.battle rescue nil) || (defender.battle rescue nil)
      grounds_target ||= effective_type == :GROUND && AdvancedAI::Utilities.grounded?(defender, battle)
      if grounds_target && defender_types.include?(:FLYING)
        grounded_types = defender_types.reject { |type| type == :FLYING }
        return grounded_types.empty? ? Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER :
               scrappy_effectiveness(effective_type, user, grounded_types)
      end
      scrappy_effectiveness(effective_type, user, defender_types)
    end

    # Resolve effective base power for variable-power moves.
    # The engine uses power=1 in PBS for variable-power moves; convert to 60 (engine default).
    def self.resolve_move_power(move, attacker = nil, defender = nil)
      power = move.power
      return 0 if power == 0
      native = move.respond_to?(:move) ? move.move : move
      user = attacker.respond_to?(:battler) ? attacker.battler : attacker
      target = defender.respond_to?(:battler) ? defender.battler : defender
      if user && target && user.respond_to?(:effects) && target.respond_to?(:effects) && native.respond_to?(:pbBaseDamage)
        case native.function_code
        when "PowerHigherWithUserHP", "PowerLowerWithUserHP", "PowerHigherWithTargetHP",
             "DoublePowerIfTargetHPLessThanHalf", "DoublePowerIfUserPoisonedBurnedParalyzed",
             "DoublePowerIfTargetPoisoned", "DoublePowerIfTargetStatusProblem",
             "DoublePowerIfTargetAsleepCureTarget", "DoublePowerIfTargetParalyzedCureTarget"
          return native.pbBaseDamage(power, user, target)
        when "DoublePowerIfUserHasNoItem"
          return power * native.pbBaseDamageMultiplier(1.0, user, target)
        end
      end
      return power if power != 1

      ai = nil
      ai = attacker.instance_variable_get(:@ai) if attacker && attacker.instance_variable_defined?(:@ai)
      ai ||= defender.instance_variable_get(:@ai) if defender && defender.instance_variable_defined?(:@ai)
      ai_move = defined?(Battle::AI::AIMove) && move.is_a?(Battle::AI::AIMove)
      if ai && ai_move && defined?(Battle::AI::Handlers) &&
         Battle::AI::Handlers.respond_to?(:get_base_power) && move.respond_to?(:function_code)
        ai_battlers = ai.instance_variable_get(:@battlers) rescue nil
        ai_user = attacker.is_a?(Battle::AI::AIBattler) ? attacker :
                  (ai_battlers && attacker.respond_to?(:index) ? ai_battlers[attacker.index] : nil)
        ai_target = defender.is_a?(Battle::AI::AIBattler) ? defender :
                    (ai_battlers && defender.respond_to?(:index) ? ai_battlers[defender.index] : nil)
        if ai_user && ai_target
          resolved = Battle::AI::Handlers.get_base_power(
            move.function_code, power, move, ai_user, ai_target, ai,
            ai.instance_variable_get(:@battle)
          )
          return resolved if resolved.is_a?(Numeric) && resolved > 1
        end
      end

      if attacker && defender
        case move.id
        when :GYROBALL
          attacker_speed = attacker.respond_to?(:pbSpeed) ? attacker.pbSpeed : attacker.speed
          defender_speed = defender.respond_to?(:pbSpeed) ? defender.pbSpeed : defender.speed
          return [[25 * [defender_speed, 1].max / [attacker_speed, 1].max, 1].max, 150].min
        when :ELECTROBALL
          attacker_speed = attacker.respond_to?(:pbSpeed) ? attacker.pbSpeed : attacker.speed
          defender_speed = defender.respond_to?(:pbSpeed) ? defender.pbSpeed : defender.speed
          ratio = attacker_speed.to_f / [defender_speed, 1].max
          return 150 if ratio >= 4
          return 120 if ratio >= 3
          return 80 if ratio >= 2
          return 60 if ratio >= 1
          return 40
        when :LOWKICK, :GRASSKNOT
          weight = defender.respond_to?(:weight) ? defender.weight : 0
          return 120 if weight >= 2_000
          return 100 if weight >= 1_000
          return 80 if weight >= 500
          return 60 if weight >= 250
          return 40 if weight >= 100
          return 20
        when :HEAVYSLAM, :HEATCRASH
          ratio = attacker.weight.to_f / [defender.weight, 1].max
          return 120 if ratio >= 5
          return 100 if ratio >= 4
          return 80 if ratio >= 3
          return 60 if ratio >= 2
          return 40
        end
      end
      60
    end

    def self.battle_move_for(attacker, move)
      if move.respond_to?(:physicalMove?) && move.respond_to?(:multiHitMove?)
        return move
      end
      move_id = move.respond_to?(:id) ? move.id : move
      candidates = attacker.respond_to?(:moves) ? attacker.moves : nil
      if !candidates && attacker.respond_to?(:battler)
        candidates = attacker.battler.moves rescue nil
      end
      candidates&.find { |candidate| candidate && candidate.id == move_id }
    end
    
    #===========================================================================
    # Field & Context Modifier (weather, terrain, items, burn)
    # Shared helper for all simplified damage calcs to avoid duplication.
    #===========================================================================
    
    def self.field_modifier(battle, attacker, effective_type, move, is_physical, target = nil)
      mod = 1.0
      battle ||= attacker.battle if attacker.respond_to?(:battle)
      return mod unless battle
      
      # Weather modifiers (Sun/Rain boost/nerf Fire/Water by 1.5x/0.5x)
      # Utility Umbrella holders are unaffected by weather
      weather = battle.pbWeather rescue nil
      attacker_umbrella = AdvancedAI::Utilities.item_active?(attacker, :UTILITYUMBRELLA, battle)
      target_umbrella = target && AdvancedAI::Utilities.item_active?(target, :UTILITYUMBRELLA, battle)
      if weather && !attacker_umbrella
        if weather == :Sun || weather == :HarshSun
          mod *= 1.5 if effective_type == :FIRE && !target_umbrella
          mod *= 0.5 if effective_type == :WATER && !target_umbrella
        elsif weather == :Rain || weather == :HeavyRain
          mod *= 1.5 if effective_type == :WATER && !target_umbrella
          mod *= 0.5 if effective_type == :FIRE && !target_umbrella
        end
      end
      
      # Terrain modifiers
      terrain = battle.field.terrain rescue nil
      if terrain
        attacker_grounded = attacker.respond_to?(:affectedByTerrain?) && attacker.affectedByTerrain?
        if attacker_grounded
          mod *= 1.3 if terrain == :Electric && effective_type == :ELECTRIC
          mod *= 1.3 if terrain == :Grassy && effective_type == :GRASS
          mod *= 1.3 if terrain == :Psychic && effective_type == :PSYCHIC
        end
        # Misty Terrain: Dragon halved against grounded target
        if terrain == :Misty && effective_type == :DRAGON
          target_grounded = target && target.respond_to?(:affectedByTerrain?) && target.affectedByTerrain?
          mod *= 0.5 if target_grounded
        end
        # Grassy Terrain: Earthquake/Bulldoze/Magnitude halved against grounded target
        move_id = move.respond_to?(:id) ? move.id : nil
        if terrain == :Grassy && [:EARTHQUAKE, :BULLDOZE, :MAGNITUDE].include?(move_id)
          target_grounded = target && target.respond_to?(:affectedByTerrain?) && target.affectedByTerrain?
          mod *= 0.5 if target_grounded
        end
      end
      
      # Item modifiers (attacker)
      mod *= 1.5 if is_physical && AdvancedAI::Utilities.item_active?(attacker, :CHOICEBAND, battle)
      mod *= 1.5 if !is_physical && AdvancedAI::Utilities.item_active?(attacker, :CHOICESPECS, battle)
      mod *= 1.3 if AdvancedAI::Utilities.item_active?(attacker, :LIFEORB, battle)
      if AdvancedAI::Utilities.item_active?(attacker, :PUNCHINGGLOVE, battle)
        is_punching = (move.respond_to?(:punchingMove?) && move.punchingMove?) rescue false
        mod *= 1.1 if is_punching
      end
      
      # Burn halves physical damage (unless Guts)
      if is_physical
        attacker_burned = (attacker.status == :BURN rescue false)
        has_guts = attacker.respond_to?(:hasActiveAbility?) ? attacker.hasActiveAbility?(:GUTS) : false
        native = move.respond_to?(:move) ? move.move : move
        reduced = !native.respond_to?(:damageReducedByBurn?) || native.damageReducedByBurn?
        mod *= 0.5 if attacker_burned && !has_guts && reduced
      end
      
      mod
    end
    
    #===========================================================================
    # Defender Modifier (Assault Vest, Eviolite, weather defense boosts)
    # Shared helper so every simplified calc accounts for target-side factors.
    #===========================================================================
    
    def self.defender_modifier(battle, target, is_physical, uses_physical_defense = is_physical)
      mod = 1.0
      battle ||= target.battle if target.respond_to?(:battle)
      
      # Assault Vest: 1.5x SpDef on special moves → damage * 0.67
      if !uses_physical_defense && AdvancedAI::Utilities.item_active?(target, :ASSAULTVEST, battle)
        mod *= 0.67
      end
      # Eviolite: 1.5x Def/SpDef for NFE → damage * 0.67
      if AdvancedAI::Utilities.item_active?(target, :EVIOLITE, battle)
        has_evos = (target.species_data.get_evolutions(true).length > 0 rescue false)
        mod *= 0.67 if has_evos
      end
      
      # Weather defense boosts (not included in stat getters)
      if battle
        weather = battle.pbWeather rescue nil
        if weather
          # Sandstorm: Rock-types get 1.5x SpDef → special damage * 0.67
          if weather == :Sandstorm && !uses_physical_defense
            has_rock = target.respond_to?(:pbHasType?) ? target.pbHasType?(:ROCK) : (target.types.include?(:ROCK) rescue false)
            mod *= 0.67 if has_rock
          end
          # Snow (Gen 9): Ice-types get 1.5x Def → physical damage * 0.67
          if weather == :Snow && uses_physical_defense
            has_ice = target.respond_to?(:pbHasType?) ? target.pbHasType?(:ICE) : (target.types.include?(:ICE) rescue false)
            mod *= 0.67 if has_ice
          end
        end
      end
      
      mod
    end
    
    #===========================================================================
    # Screen Modifier (Reflect / Light Screen / Aurora Veil)
    # Shared helper so every simplified calc accounts for active screens.
    #===========================================================================
    
    def self.screen_modifier(battle, attacker, target, is_physical)
      # Get target's side — Battler has pbOwnSide; party Pokemon does not
      target_side = nil
      if target.respond_to?(:pbOwnSide)
        target_side = target.pbOwnSide rescue nil
      elsif attacker.respond_to?(:pbOpposingSide)
        # Switch_Intelligence: target is party Pokemon, screens are on attacker's opposing side
        target_side = attacker.pbOpposingSide rescue nil
      end
      return 1.0 unless target_side
      
      # Infiltrator bypasses screens
      if attacker.respond_to?(:hasActiveAbility?) && attacker.hasActiveAbility?(:INFILTRATOR)
        return 1.0
      end
      
      # Singles: 0.5x, Doubles: ~0.67x
      battle ||= (target.battle rescue nil) || (attacker.battle rescue nil)
      is_doubles = battle && (battle.pbSideSize(0) > 1 rescue false)
      mult = is_doubles ? 0.67 : 0.5
      
      # Aurora Veil covers both physical and special
      if (target_side.effects[PBEffects::AuroraVeil] > 0 rescue false)
        return mult
      end
      
      if is_physical && (target_side.effects[PBEffects::Reflect] > 0 rescue false)
        return mult
      end
      if !is_physical && (target_side.effects[PBEffects::LightScreen] > 0 rescue false)
        return mult
      end
      
      1.0
    end
    
    #===========================================================================
    # Ability Damage Modifier (target & attacker abilities that affect damage)
    # Shared helper for defensive abilities like Fur Coat, Ice Scales, etc.
    # and offensive abilities like Tinted Lens.
    #===========================================================================
    
    def self.ability_damage_modifier(attacker, target, effective_type, is_physical, effectiveness, move = nil,
                                     uses_physical_defense = is_physical)
      mod = 1.0
      real_attacker = attacker.respond_to?(:battler) ? attacker.battler : attacker
      real_move = move.respond_to?(:move) ? move.move : move
      ignored = AdvancedAI::Utilities.ignores_ability?(attacker, move, target) rescue false
      is_contact = if real_move && real_move.respond_to?(:pbContactMove?) && real_attacker
                     real_move.pbContactMove?(real_attacker) rescue false
                   else
                     (move.respond_to?(:contactMove?) && move.contactMove?) rescue false
                   end
      is_sound = (move.respond_to?(:soundMove?) && move.soundMove?) rescue false

      if target.respond_to?(:hasActiveAbility?)
        unless ignored
          mod *= 0.5 if uses_physical_defense && target.hasActiveAbility?(:FURCOAT)
          if target.hasActiveAbility?(:FLUFFY)
            mod *= 0.5 if is_contact
            mod *= 2.0 if effective_type == :FIRE
          end
          mod *= 0.5 if !is_physical && target.hasActiveAbility?(:ICESCALES)
          mod *= 0.5 if is_sound && target.hasActiveAbility?(:PUNKROCK)
          mod *= 0.5 if target.hasActiveAbility?(:THICKFAT) && [:FIRE, :ICE].include?(effective_type)
          mod *= 0.5 if target.hasActiveAbility?(:HEATPROOF) && effective_type == :FIRE
          mod *= 0.5 if target.hasActiveAbility?(:WATERBUBBLE) && effective_type == :FIRE
          if Effectiveness.super_effective?(effectiveness) &&
             (target.hasActiveAbility?(:FILTER) || target.hasActiveAbility?(:SOLIDROCK))
            mod *= 0.75
          end
          if target.hp == target.totalhp && target.hasActiveAbility?(:MULTISCALE)
            mod *= 0.5
          end
        end
        if Effectiveness.super_effective?(effectiveness) && target.hasActiveAbility?(:PRISMARMOR)
          mod *= 0.75
        end
        if target.hp == target.totalhp && target.hasActiveAbility?(:SHADOWSHIELD)
          mod *= 0.5
        end
      else
        target_ability = target.ability_id rescue nil
        if target_ability
          full_hp = (target.hp == target.totalhp rescue true)
          unless ignored
            mod *= 0.5 if uses_physical_defense && target_ability == :FURCOAT
            if target_ability == :FLUFFY
              mod *= 0.5 if is_contact
              mod *= 2.0 if effective_type == :FIRE
            end
            mod *= 0.5 if !is_physical && target_ability == :ICESCALES
            mod *= 0.5 if target_ability == :PUNKROCK && is_sound
            mod *= 0.5 if target_ability == :THICKFAT && [:FIRE, :ICE].include?(effective_type)
            mod *= 0.5 if target_ability == :HEATPROOF && effective_type == :FIRE
            mod *= 0.5 if target_ability == :WATERBUBBLE && effective_type == :FIRE
            mod *= 0.75 if Effectiveness.super_effective?(effectiveness) && [:FILTER, :SOLIDROCK].include?(target_ability)
            mod *= 0.5 if full_hp && target_ability == :MULTISCALE
          end
          mod *= 0.75 if Effectiveness.super_effective?(effectiveness) && target_ability == :PRISMARMOR
          mod *= 0.5 if full_hp && target_ability == :SHADOWSHIELD
        end
      end
      
      # --- Attacker offensive abilities ---
      if attacker.respond_to?(:hasActiveAbility?)
        # Spellcaster: +25% for Electric/Fire/Ice, except against Dark.
        spellcaster_target = target.respond_to?(:battler) ? target.battler : target

        if attacker.hasActiveAbility?(:SPELLCASTER) &&
           [:ELECTRIC, :FIRE, :ICE].include?(effective_type) &&
           spellcaster_target &&
           !spellcaster_target.pbHasType?(:DARK)
          mod *= 1.25
        end
        # Tinted Lens: NVE damage doubled
        if attacker.hasActiveAbility?(:TINTEDLENS) && Effectiveness.not_very_effective?(effectiveness)
          mod *= 2.0
        end
        # Sharpness: slicing moves 1.5x
        is_slicing = (move.respond_to?(:slicingMove?) && move.slicingMove?) rescue false
        mod *= 1.5 if is_slicing && attacker.hasActiveAbility?(:SHARPNESS)
        # Strong Jaw: biting moves 1.5x
        is_biting = (move.respond_to?(:bitingMove?) && move.bitingMove?) rescue false
        mod *= 1.5 if is_biting && attacker.hasActiveAbility?(:STRONGJAW)
        # Iron Fist: punching moves 1.2x
        is_punching = (move.respond_to?(:punchingMove?) && move.punchingMove?) rescue false
        mod *= 1.2 if is_punching && attacker.hasActiveAbility?(:IRONFIST)
        # Mega Launcher: pulse moves 1.5x
        is_pulse = (move.respond_to?(:pulseMove?) && move.pulseMove?) rescue false
        mod *= 1.5 if is_pulse && attacker.hasActiveAbility?(:MEGALAUNCHER)
        # Punk Rock (attacker): sound moves 1.3x
        mod *= 1.3 if is_sound && attacker.hasActiveAbility?(:PUNKROCK)
        # Water Bubble (attacker): Water moves 2x
        mod *= 2.0 if effective_type == :WATER && attacker.hasActiveAbility?(:WATERBUBBLE)
        mod *= 1.5 if is_physical && attacker.status != :NONE && attacker.hasActiveAbility?(:GUTS)
        # Steelworker: Steel moves 1.5x
        mod *= 1.5 if effective_type == :STEEL && attacker.hasActiveAbility?(:STEELWORKER)
        # Supreme Overlord: +10% per fainted ally (max +50%)
        if attacker.hasActiveAbility?(:SUPREMEOVERLORD)
          fainted = if defined?(PBEffects::SupremeOverlord)
                      (attacker.effects[PBEffects::SupremeOverlord] rescue 0) || 0
                    else
                      0
                    end
          mod *= (1.0 + fainted * 0.1) if fainted > 0
        end
      else
        atk_ability = attacker.ability_id rescue nil
        if atk_ability == :TINTEDLENS && Effectiveness.not_very_effective?(effectiveness)
          mod *= 2.0
        end
      end
      
      mod
    end

    def self.ruin_damage_modifier(battle, attacker, target, is_physical)
      return 1.0 unless battle && battle.respond_to?(:pbCheckGlobalAbility)
      mod = 1.0
      wonder_room = (battle.field.effects[PBEffects::WonderRoom] > 0 rescue false)
      attacker_ability = attacker.ability_id rescue nil
      target_ability = target.ability_id rescue nil
      if battle.pbCheckGlobalAbility(:TABLETSOFRUIN) && attacker_ability != :TABLETSOFRUIN
        mod *= 0.75 if is_physical
      end
      if battle.pbCheckGlobalAbility(:VESSELOFRUIN) && attacker_ability != :VESSELOFRUIN
        mod *= 0.75 unless is_physical
      end
      if battle.pbCheckGlobalAbility(:SWORDOFRUIN) && target_ability != :SWORDOFRUIN
        mod /= 0.75 if is_physical != wonder_room
      end
      if battle.pbCheckGlobalAbility(:BEADSOFRUIN) && target_ability != :BEADSOFRUIN
        mod /= 0.75 if is_physical == wonder_room
      end
      mod
    end

    def self.spread_damage_modifier(battle, attacker, move)
      return 1.0 unless move && move.damagingMove?
      real_attacker = attacker.respond_to?(:battler) ? attacker.battler : attacker
      battle ||= real_attacker.battle rescue nil
      return 1.0 unless battle && real_attacker
      target_data = move.pbTarget(real_attacker) rescue nil
      return 1.0 unless target_data && target_data.num_targets > 1
      targets = battle.allBattlers.count do |battler|
        battler && !battler.fainted? &&
          battle.pbMoveCanTarget?(real_attacker.index, battler.index, target_data)
      end
      targets > 1 ? 0.75 : 1.0
    rescue
      1.0
    end
    
    #===========================================================================
    # Simplified Damage Calculation (For Quick Estimates)
    #===========================================================================
    
    # Stat stage multiplier: converts a stage (-6..+6) to a multiplier.
    # Positive stages: (2+stage)/2; Negative stages: 2/(2+stage.abs)
    STAGE_MULTIPLIERS = {
      -6 => 2.0/8, -5 => 2.0/7, -4 => 2.0/6, -3 => 2.0/5,
      -2 => 2.0/4, -1 => 2.0/3,  0 => 1.0,
       1 => 3.0/2,  2 => 4.0/2,  3 => 5.0/2,
       4 => 6.0/2,  5 => 7.0/2,  6 => 8.0/2
    }

    def self.stage_multiplier(stage)
      stage = stage.clamp(-6, 6)
      STAGE_MULTIPLIERS[stage] || 1.0
    end

    def self.wonder_room_active?(attacker, defender)
      battle = (attacker.battle rescue nil) || (defender.battle rescue nil)
      return false unless battle && defined?(PBEffects::WonderRoom)
      (battle.field.effects[PBEffects::WonderRoom] rescue 0).to_i > 0
    end

    def self.move_guaranteed_critical?(move, user, target = nil)
      guaranteed = (move.function_code rescue "").include?("AlwaysCriticalHit")
      if !guaranteed && target && AdvancedAI::Utilities.ability_active?(user, :MERCILESS)
        target_status = target.status rescue nil
        guaranteed = [:POISON, :TOXIC].include?(target_status)
      end
      if !guaranteed && defined?(PBEffects::LaserFocus) && user.respond_to?(:effects)
        guaranteed = (user.effects[PBEffects::LaserFocus] rescue 0).to_i > 0
      end
      if guaranteed && target
        if target.respond_to?(:pbOwnSide) && defined?(PBEffects::LuckyChant)
          guaranteed = false if (target.pbOwnSide.effects[PBEffects::LuckyChant] rescue 0).to_i > 0
        end
        blocked = AdvancedAI::Utilities.ability_active?(target, :BATTLEARMOR) ||
                  AdvancedAI::Utilities.ability_active?(target, :SHELLARMOR)
        guaranteed = false if blocked && !AdvancedAI::Utilities.ignores_ability?(user, move, target)
      end
      guaranteed
    end

    def self.expected_hit_multiplier(move, user)
      code = (move.function_code rescue "")
      return 1.0 unless (move.multiHitMove? rescue false) || code.include?("HitTwoTimes")
      skill_link = AdvancedAI::Utilities.ability_active?(user, :SKILLLINK)
      loaded_dice = AdvancedAI::Utilities.item_active?(user, :LOADEDDICE)
      return 10.0 if move.id == :POPULATIONBOMB && skill_link
      return 7.0 if move.id == :POPULATIONBOMB && loaded_dice
      return 4.0 if move.id == :POPULATIONBOMB
      if [:TRIPLEAXEL, :TRIPLEKICK].include?(move.id)
        return (skill_link || loaded_dice) ? 6.0 : 3.5
      end
      return 2.0 if code.include?("HitTwoTimes")
      return 3.0 if code.include?("HitThreeTimes")
      return 10.0 if code.include?("HitTenTimes") && skill_link
      return 4.0 if code.include?("HitTenTimes")
      return 5.0 if skill_link
      return 4.5 if loaded_dice
      code.include?("HitThreeToSevenTimes") ? 5.0 : 3.1
    rescue
      1.0
    end

    def self.estimate_damage(attacker, move, defender, options = {})
      return 0 unless attacker && move && defender
      return 0 unless move.damagingMove?

      battle = (attacker.battle rescue nil) || (defender.battle rescue nil)

      effective_type = resolve_move_type(attacker, move)
      if battle
        weather = battle.pbWeather
        return 0 if weather == :HarshSun && effective_type == :WATER
        return 0 if weather == :HeavyRain && effective_type == :FIRE
      end
      function_code = (move.function_code rescue "")
      grounds_target = function_code == "HitsTargetInSkyGroundsTarget"
      if effective_type == :GROUND && !grounds_target && !AdvancedAI::Utilities.grounded?(defender, battle)
        return 0 if AdvancedAI::Utilities.item_active?(defender, :AIRBALLOON, battle)
        if defender.respond_to?(:effects)
          return 0 if defender.effects[PBEffects::MagnetRise] > 0 || defender.effects[PBEffects::Telekinesis] > 0
        end
      end
      effectiveness = move_type_effectiveness(move, attacker, defender, effective_type)
      return 0 if Effectiveness.ineffective?(effectiveness)
      if AdvancedAI::Utilities.type_absorbing_immunity?(attacker, defender, effective_type, move)
        return 0
      end
      return 0 if AdvancedAI::Utilities.bulletproof_immune?(attacker, defender, move)
      return 0 if AdvancedAI::Utilities.soundproof_immune?(attacker, defender, move)
      if AdvancedAI::Utilities.ability_active?(defender, :WONDERGUARD) &&
         !AdvancedAI::Utilities.ignores_ability?(attacker, move, defender) &&
         !Effectiveness.super_effective?(effectiveness)
        return 0
      end

      fixed_damage = case function_code
                     when "FixedDamage20" then 20
                     when "FixedDamage40" then 40
                     when "FixedDamageHalfTargetHP" then [(defender.hp / 2.0).round, 1].max
                     when "FixedDamageUserLevel" then attacker.level
                     when "FixedDamageUserLevelRandom"
                       ((attacker.level / 2 + attacker.level * 3 / 2) / 2.0).round
                     when "LowerTargetHPToUserHP" then [defender.hp - attacker.hp, 0].max
                     when "UserFaintsFixedDamageUserHP" then attacker.hp
                     when /^OHKO/
                       return 0 if defender.level > attacker.level
                       return 0 if effective_type == :ICE && AdvancedAI::Utilities.has_type?(defender, :ICE)
                       if AdvancedAI::Utilities.ability_active?(defender, :STURDY) &&
                          !AdvancedAI::Utilities.ignores_ability?(attacker, move, defender)
                         return 0
                       end
                       defender.hp
                     end
      unless fixed_damage.nil?
        return options[:as_percent] ? fixed_damage.to_f / [defender.totalhp, 1].max : fixed_damage
      end

      power = resolve_move_power(move, attacker, defender)
      return 0 if power <= 0
      power *= expected_hit_multiplier(move, attacker)

      is_physical = move.physicalMove?
      real_attacker = attacker.respond_to?(:battler) ? attacker.battler : attacker
      tera_active = real_attacker.respond_to?(:tera?) && real_attacker.tera?
      attacker_stages = attacker.respond_to?(:stages) ? attacker.stages : nil
      physical_attack = attacker.attack * stage_multiplier(attacker_stages ? attacker_stages[:ATTACK].to_i : 0)
      special_attack = attacker.spatk * stage_multiplier(attacker_stages ? attacker_stages[:SPECIAL_ATTACK].to_i : 0)
      if function_code == "CategoryDependsOnHigherDamage" ||
         function_code == "CategoryDependsOnHigherDamageIgnoreTargetAbility" ||
         function_code == "CategoryDependsOnHigherAttackIgnoreTargetAbility" ||
         (function_code == "TypeAndPowerDependOnUserTeraType" && tera_active)
        is_physical = physical_attack > special_attack
      end

      uses_physical_defense = is_physical
      uses_physical_defense = true if function_code == "UseTargetDefenseInsteadOfTargetSpDef"
      uses_physical_defense = !uses_physical_defense if wonder_room_active?(attacker, defender)

      atk = is_physical ? attacker.attack : attacker.spatk
      defense = uses_physical_defense ? defender.defense : defender.spdef
      atk_stage_key = is_physical ? :ATTACK : :SPECIAL_ATTACK
      def_stage_key = uses_physical_defense ? :DEFENSE : :SPECIAL_DEFENSE
      if function_code == "UseTargetAttackInsteadOfUserAttack"
        atk = defender.attack
        atk_stage_key = :ATTACK
      elsif function_code == "UseUserDefenseInsteadOfUserAttack"
        atk = attacker.defense
        atk_stage_key = :DEFENSE
      end
      critical = move_guaranteed_critical?(move, attacker, defender)
      stages = if function_code == "UseTargetAttackInsteadOfUserAttack"
                 defender.respond_to?(:stages) ? defender.stages : nil
               else
                 attacker_stages
               end
      atk_stage = stages ? stages[atk_stage_key].to_i : 0
      if AdvancedAI::Utilities.ability_active?(defender, :UNAWARE) &&
         !AdvancedAI::Utilities.ignores_ability?(attacker, move, defender) &&
         function_code != "UseTargetAttackInsteadOfUserAttack"
        atk_stage = 0
      end
      atk_stage = 0 if critical && atk_stage < 0
      atk = (atk * stage_multiplier(atk_stage)).to_i

      stages = defender.respond_to?(:stages) ? defender.stages : nil
      def_stage = stages ? stages[def_stage_key].to_i : 0
      def_stage = 0 if AdvancedAI::Utilities.ability_active?(attacker, :UNAWARE)
      def_stage = 0 if critical && def_stage > 0
      defense = (defense * stage_multiplier(def_stage)).to_i

      level = attacker.level
      base_damage = ((2.0 * level / 5 + 2) * power * atk / [defense, 1].max / 50 + 2)

      stab = AdvancedAI::Utilities.has_type?(attacker, effective_type) ? 1.5 : 1.0
      if stab == 1.5 && AdvancedAI::Utilities.ability_active?(attacker, :ADAPTABILITY)
        stab = 2.0
      end

      if is_physical && (AdvancedAI::Utilities.ability_active?(attacker, :HUGEPOWER) ||
                         AdvancedAI::Utilities.ability_active?(attacker, :PUREPOWER))
        base_damage *= 2
      end
      effectiveness_mult = effectiveness.to_f / Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      field_mod = field_modifier(battle, attacker, effective_type, move, is_physical, defender)
      def_mod = defender_modifier(battle, defender, is_physical, uses_physical_defense)
      scr_mod = critical ? 1.0 : screen_modifier(battle, attacker, defender, is_physical)

      pb_mod = 1.0
      if !move.multiHitMove? && AdvancedAI::Utilities.ability_active?(attacker, :PARENTALBOND)
        pb_mod = 1.25
      end

      abil_mod = ability_damage_modifier(attacker, defender, effective_type, is_physical,
                                         effectiveness, move, uses_physical_defense)
      ruin_mod = ruin_damage_modifier(battle, attacker, defender, is_physical)
      spread_mod = spread_damage_modifier(battle, attacker, move)

      crit_mod = critical ? 1.5 : 1.0
      crit_mod *= 1.5 if critical && AdvancedAI::Utilities.ability_active?(attacker, :SNIPER)
      estimated_damage = (base_damage * stab * effectiveness_mult * field_mod * def_mod *
                          scr_mod * pb_mod * abil_mod * ruin_mod * spread_mod * crit_mod * 0.925).to_i

      estimated_damage = [estimated_damage, 1].max
      if options[:as_percent]
        return estimated_damage.to_f / [defender.totalhp, 1].max
      end

      estimated_damage
    end
    
    #===========================================================================
    # Speed Comparison Utilities
    #===========================================================================
    
    def self.speed_tier_difference(user, target)
      return 0 unless user && target
      
      user_speed = user.pbSpeed
      target_speed = target.pbSpeed
      
      return 0 if user_speed == target_speed
      
      # Return ratio (how much faster/slower)
      if target_speed > user_speed
        target_speed.to_f / [user_speed, 1].max  # Positive = opponent faster
      else
        -(user_speed.to_f / [target_speed, 1].max)  # Negative = we're faster
      end
    end
    
    def self.is_faster?(user, target)
      return false unless user && target
      user.pbSpeed > target.pbSpeed
    end
    
    def self.is_much_slower?(user, target, threshold = 1.5)
      speed_diff = speed_tier_difference(user, target)
      speed_diff >= threshold
    end
    
    #===========================================================================
    # Team Size Utilities (For Trade Calculations)
    #===========================================================================
    
    def self.count_alive_pokemon(battle, battler_index)
      return 0 unless battle
      
      party = battle.pbParty(battler_index & 1)  # battler_index may be slot 0-3; & 1 gives side 0/1
      return 0 unless party
      
      party.count { |p| p && !p.fainted? }
    end
    
    def self.team_advantage(battle, user_index, opponent_index)
      user_count = count_alive_pokemon(battle, user_index)
      opponent_count = count_alive_pokemon(battle, opponent_index)
      
      return -1 if user_count == 0
      return 1 if opponent_count == 0
      
      # Return: 1 = ahead, 0 = even, -1 = behind
      if user_count > opponent_count
        return 1
      elsif user_count == opponent_count
        return 0
      else
        return -1
      end
    end
    
    #===========================================================================
    # Doubles Battle Utilities
    #===========================================================================
    
    def self.is_doubles?(battle)
      return false unless battle
      battle.pbSideSize(0) > 1
    end
    
    def self.get_partner(battler)
      return nil unless battler
      
      partners = battler.allAllies
      return nil if partners.empty?
      
      partners.first
    end
    
    def self.partner_alive?(battler)
      partner = get_partner(battler)
      partner && !partner.fainted?
    end
    
    #===========================================================================
    # Setup Detection
    #===========================================================================
    
    def self.is_boosted?(battler, threshold = 1)
      return false unless battler
      
      # Check offensive stat boosts
      atk_boost = battler.stages[:ATTACK] || 0
      spatk_boost = battler.stages[:SPECIAL_ATTACK] || 0
      
      (atk_boost + spatk_boost) >= threshold
    end
    
    def self.total_stat_boosts(battler)
      return 0 unless battler
      battler.stages.values.select { |v| v > 0 }.sum
    end
    
    #===========================================================================
    # Common Scoring Patterns
    #===========================================================================
    
    # Generic low HP bonus (desperation / cleanup)
    LOW_HP_THRESHOLDS = {
      0.25 => 60,
      0.33 => 50,
      0.50 => 30,
      0.70 => 15
    }
    
    # Generic partner HP concern
    PARTNER_HP_CONCERN = {
      0.33 => 80,
      0.50 => 50,
      0.70 => 30
    }
    
  end
end
