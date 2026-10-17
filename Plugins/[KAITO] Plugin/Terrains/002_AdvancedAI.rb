#===============================================================================
# Extended Terrains - Advanced AI System 2.7.2 integration
# Loaded after Advanced AI by the optional dependency in meta.txt.
# All predictions are heuristic; the battle engine remains authoritative.
#===============================================================================
  module ExtendedTerrains
    module Advanced
      SETTERS = ExtendedTerrains::DATA.keys.each_with_object({}) do |terrain, map|
        map["Start#{terrain}Terrain"] = terrain
      end

      def self.real(battler)
        return battler.respond_to?(:battler) ? battler.battler : battler
      end

      def self.native_move(move, user)
        native = move.respond_to?(:move) ? move.move : move
        return native if native.is_a?(Battle::Move)
        battler = real(user)
        existing = battler.moves.find { |candidate| candidate && candidate.id == native.id }
        return existing if existing
        battle = ExtendedTerrains.battle_of(battler)
        return Battle::Move.from_pokemon_move(battle, Pokemon::Move.new(native.id))
      end

      def self.fixed_damage?(move, user)
        return native_move(move, user).is_a?(Battle::Move::FixedDamageMove)
      end

      # Reuse the engine-side terrain rules; one multiplier per prediction path.
      def self.damage_multiplier(move, user, target, type = nil)
        user = real(user)
        target = real(target)
        return 1.0 if !user || !target
        return 1.0 if !ExtendedTerrains::DATA.key?(ExtendedTerrains.battle_of(user).field.terrain)
        native = native_move(move, user)
        return 1.0 if native.is_a?(Battle::Move::FixedDamageMove)
        type ||= AdvancedAI::CombatUtilities.resolve_move_type(user, native)
        mults = { :power_multiplier => 1.0, :final_damage_multiplier => 1.0 }
        ExtendedTerrains.apply_damage(native, user, target, type, mults)
        return mults[:power_multiplier] * mults[:final_damage_multiplier]
      end

      # Keep access to raw stages for Stored Power/Power Trip/Punishment.
      def self.with_stages(battlers)
        saved = []
        begin
          battlers.compact.map { |b| real(b) }.uniq.each do |b|
            defined_before = b.instance_variable_defined?(:@et_ai_raw_stages)
            previous = b.instance_variable_get(:@et_ai_raw_stages)
            saved << [b, defined_before, previous]
            b.instance_variable_set(:@et_ai_raw_stages, b.stages) if !defined_before
          end
          return ExtendedTerrains.with_effective_stages(battlers.compact.map { |b| real(b) }) { yield }
        ensure
          saved.reverse_each do |b, defined_before, previous|
            if defined_before
              b.instance_variable_set(:@et_ai_raw_stages, previous)
            else
              b.remove_instance_variable(:@et_ai_raw_stages)
            end
          end
        end
      end

      def self.raw_stages(battler)
        b = real(battler)
        return b.instance_variable_get(:@et_ai_raw_stages) || b.stages
      end

      # Query a proposed terrain without starting it, triggering abilities/items,
      # decrementing duration or displaying animations. Always restore the field.
      def self.with_terrain(battle, terrain)
        previous = battle.field.terrain
        begin
          battle.field.terrain = terrain
          return yield
        ensure
          battle.field.terrain = previous
        end
      end

      def self.usable_moves(battler)
        return battler.moves.compact.select { |m| m.pp > 0 || m.total_pp == 0 }
      end

      def self.power_opportunity(battler, type, mud = false, airborne = false)
        eligible = airborne ? ExtendedTerrains.in_air?(battler) : ExtendedTerrains.grounded?(battler)
        return 0 if !eligible
        moves = usable_moves(battler).select { |m| m.damagingMove? && !fixed_damage?(m, battler) }
        matching = moves.count do |m|
          AdvancedAI::CombatUtilities.resolve_move_type(battler, m) == type ||
            (mud && ExtendedTerrains.mud_move?(m))
        end
        return matching > 0 ? 16 + [matching - 1, 2].min * 3 : 0
      end

      def self.poison_value(battler)
        return 0 if battler.pbHasType?(:STEEL) || battler.status != :NONE
        return 0 if !battler.pbCanPoison?(battler, false)
        return 24 if battler.hasActiveAbility?(:POISONHEAL)
        return 0 if battler.hasActiveAbility?(:MAGICGUARD)
        if battler.hasActiveAbility?(:GUTS) || battler.hasActiveAbility?(:QUICKFEET) ||
           battler.hasActiveAbility?(:TOXICBOOST)
          return -3
        end
        return -22
      end

      # Value for this one Pokemon. Positive is good for that Pokemon's side.
      def self.battler_value(battle, battler, terrain)
        value = 0
        ground = ExtendedTerrains.grounded?(battler)
        case terrain
        when :Sandy
          value += power_opportunity(battler, :GROUND)
          eligible = !ExtendedTerrains::SANDY_EVASION_GROUNDED_ONLY || ground
          value -= 12 if eligible && !battler.pbHasType?(:GROUND) && !battler.pbHasType?(:ROCK)
        when :Swamp
          value += power_opportunity(battler, :WATER, true)
          if ground && !battler.pbHasType?(:WATER)
            value += battle.field.effects[PBEffects::TrickRoom] > 0 ? 14 : -14
          end
        when :Toxic
          value += power_opportunity(battler, :POISON, true)
          if ground && !battler.pbHasType?(:POISON)
            value += poison_value(battler)
            value -= 14 if battler.itemActive? && battler.item && battler.item.is_berry?
          end
        when :Draconic
          if ground
            opponents = battle.allBattlers.select { |b| !b.fainted? && b.opposes?(battler) }
            value += 14 if opponents.any? { |b| usable_moves(b).any? { |m| m.damagingMove? && AdvancedAI::CombatUtilities.resolve_move_type(b, m) == :FAIRY } }
            if opponents.any? { |b| b.pbHasType?(:FAIRY) }
              value += power_opportunity(battler, :DRAGON)
            end
          end
        when :Colosseum
          value += power_opportunity(battler, :FIGHTING)
          moves = usable_moves(battler)
          status_count = moves.count { |m| m.statusMove? }
          value -= [status_count * 12, 36].min
          value -= 25 if !moves.empty? && moves.all? { |m| m.statusMove? }
        when :Pollination
          value += power_opportunity(battler, :BUG)
          eligible = !ExtendedTerrains::POLLINATION_STAGES_GROUNDED_ONLY || ground
          if eligible
            stages = raw_stages(battler)
            if battler.pbHasType?(:BUG)
              value += [stages.values.select { |s| s < 0 }.sum.abs * 6, 36].min
            elsif !battler.pbHasType?(:GRASS)
              value -= [stages.values.select { |s| s > 0 }.sum * 6, 36].min
            end
          end
        when :Ravine
          value += power_opportunity(battler, :FLYING, false, true)
          if ExtendedTerrains.in_air?(battler) &&
             battler.pbHasType?(:FLYING)
            value += 14
          end
          powder_count = usable_moves(battler).count { |m| m.powderMove? }
          value -= [powder_count * 18, 36].min
        end # case terrain

        return value
      end # def self.battler_value

      # Score both teams, including the partner in double/triple battles.
      def self.terrain_value(battle, perspective, terrain)
        return 0 if !ExtendedTerrains::DATA.key?(terrain)
        user = real(perspective)
        return with_terrain(battle, terrain) do
          battle.allBattlers.inject(0) do |score, b|
            next score if b.fainted?
            value = battler_value(battle, b, terrain)
            score + (b.opposes?(user) ? -value : value)
          end
        end
      end

      def self.accuracy_penalty(chance)
        return -40 if chance < 70
        return -20 if chance < 85
        return -10 if chance < 95
        return 0
      end

      def self.acc_stage_multiplier(stage)
        stage = [[stage, -6].max, 6].min
        return stage >= 0 ? (3.0 + stage) / 3 : 3.0 / (3 - stage)
      end
    end

    #===========================================================================
    # Shared utility path: incoming damage, switch evaluation, survival checks.
    #===========================================================================
    module AdvancedCombatHooks
      def move_type_effectiveness(move, user, defender, effective_type = nil)
        source = Advanced.real(user)
        target = Advanced.real(defender)
        type = effective_type || resolve_move_type(user, move)
        if source && target && type == :DRAGON &&
           ExtendedTerrains.battle_of(source).field.terrain == :Draconic &&
           ExtendedTerrains.grounded?(source)
          return Advanced.native_move(move, source).pbCalcTypeMod(type, source, target)
        end
        super
      end

      def field_modifier(battle, attacker, effective_type, move, is_physical, target = nil)
        value = super
        return value if !target
        return value * Advanced.damage_multiplier(move, attacker, target, effective_type)
      end

      def estimate_damage(attacker, move, defender, options = {})
        return super if !attacker || !move || !defender
        native = Advanced.native_move(move, attacker)
        return 0 if ExtendedTerrains.move_block_reason(Advanced.real(attacker), native)
        return Advanced.with_stages([attacker, defender]) { super }
      end

      def resolve_move_power(move, attacker = nil, defender = nil)
        source = Advanced.real(attacker || defender)
        return super if !source || ExtendedTerrains.battle_of(source).field.terrain != :Pollination
        if attacker && [:STOREDPOWER, :POWERTRIP].include?(move.id)
          boosts = Advanced.raw_stages(attacker).values.select { |s| s > 0 }.sum
          return 20 + 20 * boosts
        end
        if defender && move.id == :PUNISHMENT
          boosts = Advanced.raw_stages(defender).values.select { |s| s > 0 }.sum
          return [60 + 20 * boosts, 200].min
        end
        super
      end
    end

    module AdvancedUtilityHooks
      def has_resist_berry?(target, move_type)
        return false if target && ExtendedTerrains.berry_locked?(Advanced.real(target))
        super
      end
    end

    #===========================================================================
    # Main Advanced AI move scorer and its separate rough-damage calculator.
    #===========================================================================
    module AdvancedScorerHooks
      def calculate_rough_damage(move, user, target, override_bp = nil)
        return super if !move || !user || !target
        native = Advanced.native_move(move, user)
        return 0 if ExtendedTerrains.move_block_reason(Advanced.real(user), native)
        # The original calculator overwrites Stored Power's BP by reading stages
        # itself. Use the shared estimator, which preserves its raw-stage BP.
        if @battle.field.terrain == :Pollination && [:STOREDPOWER, :POWERTRIP, :PUNISHMENT].include?(move.id)
          return AdvancedAI::CombatUtilities.estimate_damage(user, move, target)
        end
        value = Advanced.with_stages([user, target]) { super }
        return value if Advanced.fixed_damage?(move, user)
        return (value * Advanced.damage_multiplier(move, user, target)).round
      end

      def score_move_advanced(move, user, target, skill)
        previous_target = @et_score_target
        @et_score_target = target
        begin
          return super if !move || !user
          source = Advanced.real(user)
          native = Advanced.native_move(move, source)
          return -1000 if ExtendedTerrains.move_block_reason(source, native)
          terrain = Advanced::SETTERS[move.function_code]
          if terrain
            return -1000 if @battle.field.terrain == terrain
            if PBEffects.const_defined?(:TerrainSmash) &&
               source.pbOwnSide.effects[PBEffects.const_get(:TerrainSmash)]
              return -1000
            end
          end
          score = super
          return score if !score.is_a?(Numeric) || score <= -999
          current = @battle.field.terrain
          current_value = Advanced.terrain_value(@battle, source, current)
          if terrain
            # Existing terrains use the original standard terrain evaluator.
            if !ExtendedTerrains::DATA.key?(current) && current != :None
              ai_user = @battlers && @battlers[source.index]
              current_value = get_score_for_terrain(current, ai_user) if ai_user
            end
            gain = Advanced.terrain_value(@battle, source, terrain) - current_value
            # Spending a turn has a cost; discourage neutral/redundant setup.
            adjustment = gain * 1.5 - 25
            adjustment -= 15 if source.hp * 3 < source.totalhp
            score += [[adjustment, -120].max, 100].min
          elsif ExtendedTerrains::DATA.key?(current)
            if ["RemoveTerrain", "RemoveTerrainIceSpinner"].include?(move.function_code) ||
               [:DEFOG, :ICESPINNER, :STEELROLLER].include?(move.id)
              score += [[-current_value, -60].max, 60].min
            end
            victim = Advanced.real(target)
            if current == :Toxic && native.statusMove? && victim &&
               native.function_code.start_with?("PoisonTarget") &&
               ExtendedTerrains.berry_locked?(victim) && Advanced.poison_value(victim) < 0
              score -= native.function_code.include?("Badly") ? 5 : 25
            end
          end
          return score.round
        ensure
          @et_score_target = previous_target
        end
      end

      def score_accuracy(move, skill, user = nil)
        original = super
        target = Advanced.real(@et_score_target)
        source = Advanced.real(user)
        return original if !source || !target || ![:Sandy, :Pollination].include?(@battle.field.terrain)
        native = Advanced.native_move(move, source)
        return original if native.accuracy == 0 || native.function_code.start_with?("OHKO")
        return original if source.hasActiveAbility?(:NOGUARD) || target.hasActiveAbility?(:NOGUARD)
        acc = native.accuracy.to_f
        acc *= 1.3 if source.hasActiveAbility?(:COMPOUNDEYES)
        acc *= 1.1 if source.hasActiveAbility?(:VICTORYSTAR)
        acc *= 0.8 if source.hasActiveAbility?(:HUSTLE) && native.physicalMove?
        old_acc = source.stages[:ACCURACY]
        old_eva = target.stages[:EVASION]
        new_acc = ExtendedTerrains.effective_stage(source, old_acc)
        new_eva = ExtendedTerrains.effective_stage(target, old_eva)
        before = acc * Advanced.acc_stage_multiplier(old_acc) / Advanced.acc_stage_multiplier(old_eva)
        after = acc * Advanced.acc_stage_multiplier(new_acc) / Advanced.acc_stage_multiplier(new_eva)
        if @battle.field.terrain == :Sandy &&
           (!ExtendedTerrains::SANDY_EVASION_GROUNDED_ONLY || ExtendedTerrains.grounded?(target)) &&
           !target.pbHasType?(:GROUND) && !target.pbHasType?(:ROCK)
          after /= 0.6
        end
        return original + Advanced.accuracy_penalty(after) - Advanced.accuracy_penalty(before)
      end

      def score_setup_value(move, user, target, skill, status_multiplier = 1.0)
        value = super
        source = Advanced.real(user)
        native = Advanced.native_move(move, source)
        if @battle.field.terrain == :Pollination &&
           ExtendedTerrains.effective_stage(source, 1) == 0 && native.statusMove? &&
           native.function_code.include?("RaiseUser") && native.respond_to?(:statUp)
          # These boosts remain recorded, but do not improve the current stats.
          if Advanced.usable_moves(source).any? { |m| [:STOREDPOWER, :POWERTRIP].include?(m.id) }
            return [value, 15].min
          end
          return [value, -30].min
        end
        return value
      end

      def score_status_utility(move, user, target, skill, status_multiplier = 1.0)
        value = super
        victim = Advanced.real(target)
        native = Advanced.native_move(move, user)
        if victim && @battle.field.terrain == :Pollination &&
           ExtendedTerrains.effective_stage(victim, -1) == 0 && native.statusMove? &&
           native.function_code.start_with?("LowerTarget") && native.respond_to?(:statDown)
          return [value, -25].min
        end
        return value
      end
    end
  end

# Installed by ExtendedTerrains.install! after all plugin scripts have loaded.
def ExtendedTerrains.install_advanced_ai!
  return if @advanced_installed
  return if !defined?(AdvancedAI::CombatUtilities) || !defined?(AdvancedAI::Utilities)
  AdvancedAI::CombatUtilities.singleton_class.prepend(ExtendedTerrains::AdvancedCombatHooks)
  AdvancedAI::Utilities.singleton_class.prepend(ExtendedTerrains::AdvancedUtilityHooks)
  Battle::AI.prepend(ExtendedTerrains::AdvancedScorerHooks)
  @advanced_installed = true
end
