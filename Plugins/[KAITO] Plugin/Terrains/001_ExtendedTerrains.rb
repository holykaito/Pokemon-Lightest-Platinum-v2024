#===============================================================================
# Extended Terrains - Pokemon Essentials v21.1
# Sandy / Swamp / Toxic / Draconic / Colosseum / Pollination
#===============================================================================
module ExtendedTerrains
  # Set a common animation name here when you have created its animation.
  DATA = {
    :Sandy       => ["Sandy Terrain",       "SandyTerrain"],
    :Swamp       => ["Swamp Terrain",       "SwampTerrain"],
    :Toxic       => ["Toxic Terrain",       "ToxicTerrain"],
    :Draconic    => ["Draconic Terrain",    "DraconicTerrain"],
    :Colosseum   => ["Colosseum Terrain",   "ColosseumTerrain"],
    :Pollination => ["Pollination Terrain", "PollinationTerrain"],
	:Ravine 	 => ["Ravine Terrain",      "RavineTerrain"]
  }

  # Add custom mud move IDs here, or give them the PBS flag "Mud".
  MUD_MOVES = [:MUDBOMB, :MUDSHOT, :MUDSLAP, :MUDDYWATER, :MUDSPORT]

  # The request grounds the power boosts, but not these two secondary effects.
  # Set true to restrict the corresponding secondary effect to grounded Pokemon.
  SANDY_EVASION_GROUNDED_ONLY = false
  POLLINATION_STAGES_GROUNDED_ONLY = false

  def self.battle_of(battler)
    return battler.instance_variable_get(:@battle)
  end

  def self.grounded?(battler)
    return battler && !battler.fainted? && battler.affectedByTerrain?
  end

  def self.in_air?(battler)
    return battler && !battler.fainted? && battler.airborne? &&
           !battler.semiInvulnerable?
  end

  def self.mud_move?(move)
    return true if MUD_MOVES.include?(move.id)
    return move.flags.any? { |flag| flag.to_s.downcase == "mud" }
  end

  def self.berry_locked?(battler)
    return false if !grounded?(battler)
    return battle_of(battler).field.terrain == :Toxic &&
           !battler.pbHasType?(:POISON)
  end

  def self.berry?(item)
    data = GameData::Item.try_get(item)
    return data && data.is_berry?
  end

  # Pollination does not remove actual stat stages.
  def self.effective_stage(battler, stage)
    return stage if !battler || battler.fainted?
    return stage if battle_of(battler).field.terrain != :Pollination
    return stage if POLLINATION_STAGES_GROUNDED_ONLY && !grounded?(battler)
    bug = battler.pbHasType?(:BUG)
    return 0 if stage < 0 && bug
    return 0 if stage > 0 && !bug && !battler.pbHasType?(:GRASS)
    return stage
  end

  # Use a temporary stage snapshot only around read-only calculation methods.
  # Always restore the exact original Hash, including after an exception.
  def self.with_effective_stages(battlers)
    saved = []
    begin
      battlers.compact.uniq.each do |battler|
        original = battler.instance_variable_get(:@stages)
        next if !original
        adjusted = original.dup
        original.each { |stat, stage| adjusted[stat] = effective_stage(battler, stage) }
        next if adjusted == original
        saved << [battler, original]
        battler.instance_variable_set(:@stages, adjusted)
      end
      return yield
    ensure
      saved.reverse_each do |battler, original|
        battler.instance_variable_set(:@stages, original)
      end
    end
  end

  #=============================================================================
  # Restrictions imposed by terrain.
  #=============================================================================
  def self.move_block_reason(battler, move)
    case battle_of(battler).field.terrain
    when :Colosseum
      if move.statusMove?
        return _INTL("Colosseum Terrain prevents status moves!")
      end

    when :Ravine
      if move.powderMove?
        return _INTL("Ravine Terrain blows away spores and powder!")
      end
    end

    return nil
  end

  #=============================================================================
  # Terrain damage modifiers.
  #=============================================================================
  def self.apply_damage(move, user, target, type, multipliers)
    battle = battle_of(user)
    boost = false

    case battle.field.terrain
    when :Sandy
      boost = grounded?(user) && type == :GROUND

    when :Swamp
      boost = grounded?(user) &&
              (type == :WATER || mud_move?(move))

    when :Toxic
      boost = grounded?(user) &&
              (type == :POISON || mud_move?(move))

    when :Colosseum
      boost = grounded?(user) && type == :FIGHTING

    when :Pollination
      boost = grounded?(user) && type == :BUG

    when :Draconic
      if type == :FAIRY && grounded?(target)
        multipliers[:final_damage_multiplier] *= 0.5
      end

    when :Ravine
      boost = in_air?(user) && type == :FLYING

      if in_air?(target) && target.pbHasType?(:FLYING)
        effectiveness = move.pbCalcTypeMod(type, user, target)

        if Effectiveness.super_effective?(effectiveness)
          multipliers[:final_damage_multiplier] *= 0.75
        end
      end
    end # Closes case battle.field.terrain

    # Apply the power boost once.
    multipliers[:power_multiplier] *= 1.3 if boost
  end # Closes def self.apply_damage

  #=============================================================================
  # Battle: terrain registration, messages, expiration and Toxic poisoning.
  #=============================================================================
  module BattleHooks
    def pbStartTerrain(user, newTerrain, fixedDuration = true)
      return super if !ExtendedTerrains::DATA.key?(newTerrain)
      return if @field.terrain == newTerrain
      # M.A.G has an extra terrain-blocking entry hazard. Check nil users safely.
      if user && PBEffects.const_defined?(:TerrainSmash) &&
         user.pbOwnSide.effects[PBEffects.const_get(:TerrainSmash)]
        pbDisplay(_INTL("The terrain is too smashed to set up the terrain!"))
        pbHideAbilitySplash(user)
        return
      end
      @field.terrain = newTerrain
      duration = fixedDuration ? 5 : -1
      if duration > 0 && user && user.itemActive?
        duration = Battle::ItemEffects.triggerTerrainExtender(
          user.item, newTerrain, duration, user, self
        )
      end
      @field.terrainDuration = duration
      data = GameData::BattleTerrain.get(newTerrain)
      pbCommonAnimation(data.animation) if data.animation
      pbHideAbilitySplash(user) if user
      pbDisplay(_INTL("{1} spread across the battlefield!", data.name))
      allBattlers.each { |b| b.pbAbilityOnTerrainChange }
      allBattlers.each { |b| b.pbItemTerrainStatBoostCheck }
    end

    def pbTerrainStartMessage
      if ExtendedTerrains::DATA.key?(@field.terrain)
        data = GameData::BattleTerrain.get(@field.terrain)
        pbDisplay(_INTL("{1} covers the battlefield!", data.name))
        return
      end
      super if defined?(super)
    end

    def pbEOREndTerrain
      old_terrain = @field.terrain
      # Inflict ordinary poison before the terrain's final turn expires.
      # Residual poison damage has already happened in the normal EOR sequence.
      if old_terrain == :Toxic
        pbPriority(true).each do |battler|
          next if !ExtendedTerrains.berry_locked?(battler)
          # Self-source validates environmental poison without Substitute blocking
          # it; pbPoison receives nil so Synchronize has no opposing source.
          next if battler.pbHasType?(:STEEL)
          next if !battler.pbCanPoison?(battler, false)
          battler.pbPoison(nil, _INTL("{1} was poisoned by Toxic Terrain!", battler.pbThis))
        end
      end
      if ExtendedTerrains::DATA.key?(old_terrain)
        if @field.terrainDuration == 1
          pbDisplay(_INTL("{1} faded.", GameData::BattleTerrain.get(old_terrain).name))
        elsif @field.terrainDuration != 0
          pbDisplay(_INTL("{1} covers the battlefield.", GameData::BattleTerrain.get(old_terrain).name))
        end
      end
      # Preserve the original duration/default-terrain/DBK end triggers.
      super
    end
  end

  #=============================================================================
  # Battler: speed, item consumption and move restrictions.
  #=============================================================================
  module BattlerHooks
    def pbSpeed
      value = ExtendedTerrains.with_effective_stages([self]) { super }
      if @battle.field.terrain == :Swamp && ExtendedTerrains.grounded?(self) &&
         !pbHasType?(:WATER)
        value = [(value * 0.75).round, 1].max
      end
      return value
    end

    def canConsumeBerry?
      return false if ExtendedTerrains.berry_locked?(self)
      super
    end

    def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
      reason = ExtendedTerrains.move_block_reason(self, move)
      if reason
        if showMessages
          commandPhase ? @battle.pbDisplayPaused(reason) : @battle.pbDisplay(reason)
        end
        return false
      end
      super
    end

    # Also catch called moves and a terrain that changed after move selection.
    def pbTryUseMove(choice, move, specialUsage, skipAccuracyCheck)
      reason = ExtendedTerrains.move_block_reason(self, move)
      if reason
        @battle.pbDisplay(reason)
        @lastMoveFailed = true
        return false
      end
      super
    end
	
	#---------------------------------------------------------------------------
	# Ravine Terrain - protects against powder and spore moves.
	#---------------------------------------------------------------------------
	def affectedByPowder?(showMsg = false)
	  if @battle.field.terrain == :Ravine
		if showMsg
		  @battle.pbDisplay(
			_INTL("Ravine Terrain blows away spores and powder!")
		  )
		end
		return false
	  end

	  super
	end
  end

  #=============================================================================
  # Move: power, damage reduction, accuracy and Dragon/Fairy type interaction.
  #=============================================================================
  module MoveHooks
    def pbOnStartUse(user, targets)
      # These moves choose physical/special category by comparing staged stats.
      codes = ["CategoryDependsOnHigherDamagePoisonTarget",
               "CategoryDependsOnHigherDamageIgnoreTargetAbility",
               "CategoryDependsOnHigherDamageTera",
               "TerapagosCategoryDependsOnHigherDamage"]
      if codes.include?(@function_code)
        return ExtendedTerrains.with_effective_stages([user]) { super }
      end
      super
    end

    def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
      result = super
      ExtendedTerrains.apply_damage(self, user, target, type, multipliers)
      return result
    end

    def pbCalcAccuracyModifiers(user, target, modifiers)
      result = super
      modifiers[:accuracy_stage] = ExtendedTerrains.effective_stage(user, modifiers[:accuracy_stage])
      modifiers[:evasion_stage] = ExtendedTerrains.effective_stage(target, modifiers[:evasion_stage])
      if @battle.field.terrain == :Sandy &&
         (!ExtendedTerrains::SANDY_EVASION_GROUNDED_ONLY || ExtendedTerrains.grounded?(target)) &&
         !target.pbHasType?(:GROUND) && !target.pbHasType?(:ROCK)
        modifiers[:evasion_multiplier] *= 0.6
      end
      return result
    end

    def pbCalcTypeModSingle(moveType, defType, user, target)
      result = super
      if @battle.field.terrain == :Draconic && moveType == :DRAGON &&
         defType == :FAIRY && ExtendedTerrains.grounded?(user) &&
         result == Effectiveness::INEFFECTIVE_MULTIPLIER
        return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
      return result
    end
  end

  # Catch forced Berry effects too (Pluck, Bug Bite, Fling and Teatime).
  # Do not suppress the held item itself: Natural Gift, Trick and Knock Off
  # should still see that the Pokemon is holding a Berry.
  module BerryItemHooks
    [:triggerHPHeal, :triggerStatusCure, :triggerOnEndOfUsingMove,
     :triggerOnEndOfUsingMoveStatRestore, :triggerOnBeingHitPositiveBerry].each do |method_name|
      define_method(method_name) do |item, battler, *args|
        if ExtendedTerrains.berry_locked?(battler) && ExtendedTerrains.berry?(item)
          return false
        end
        super(item, battler, *args)
      end
    end
  end

  #=============================================================================
  # Standard Essentials/DBK AI damage estimate; no full Advanced AI strategy.
  #=============================================================================
  module AIMoveHooks
    def rough_damage
      damage = super
      return damage if @move.is_a?(Battle::Move::FixedDamageMove) || !@move.damagingMove?
      user = @ai.user.battler
      target = @ai.target.battler
      mults = { :power_multiplier => 1.0, :final_damage_multiplier => 1.0 }
      ExtendedTerrains.apply_damage(@move, user, target, rough_type, mults)
      return (damage * mults[:power_multiplier] * mults[:final_damage_multiplier]).round
    end
  end

  module AIBattlerHooks
    def rough_stat(stat)
      return battler.pbSpeed if stat == :SPEED
      return ExtendedTerrains.with_effective_stages([battler]) { super }
    end

    def effectiveness_of_type_against_single_battler_type(type, defend_type, user = nil)
      value = super
      source = user.respond_to?(:battler) ? user.battler : user
      if @ai.battle.field.terrain == :Draconic && type == :DRAGON &&
         defend_type == :FAIRY && ExtendedTerrains.grounded?(source) &&
         value == Effectiveness::INEFFECTIVE_MULTIPLIER
        return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
      return value
    end
  end
end

ExtendedTerrains::DATA.each do |id, data|
  GameData::BattleTerrain.register({ :id => id, :name => _INTL(data[0]), :animation => data[1] })
end

#===============================================================================
# Install only when Battle.new is first called, after plugin loading is complete.
# An alias made AFTER a prepend can capture that prepended method and make its
# super call cycle back through the alias. Delaying installation avoids this.
#===============================================================================
module ExtendedTerrains
  def self.install!
    return if @installed
    Battle.prepend(ExtendedTerrains::BattleHooks)
    Battle::Battler.prepend(ExtendedTerrains::BattlerHooks)
    Battle::Move.prepend(ExtendedTerrains::MoveHooks)
    Battle::ItemEffects.singleton_class.prepend(ExtendedTerrains::BerryItemHooks)
    Battle::AI::AIMove.prepend(ExtendedTerrains::AIMoveHooks)
    Battle::AI::AIBattler.prepend(ExtendedTerrains::AIBattlerHooks)

    #===============================================================================
    # Pollination: wrap each existing override of stat getter methods, including
    # Body Press, Foul Play, Psyshock and custom moves that use another stat.
    # Each class receives its own module. No aliasing of prepended methods.
    #===============================================================================
    ObjectSpace.each_object(Class) do |klass|
      next if !(klass == Battle::Move || klass < Battle::Move)
      own = klass.instance_methods(false)
      methods = [:pbGetAttackStats, :pbGetDefenseStats].select { |name| own.include?(name) }
      next if methods.empty?
      hook = Module.new
      methods.each do |name|
        hook.send(:define_method, name) do |user, target|
          ExtendedTerrains.with_effective_stages([user, target]) { super(user, target) }
        end
      end
      klass.prepend(hook)
    end

    # Read-only dynamic-category comparisons also need Pollination's effective
    # stages. These classes override pbOnStartUse without calling the base method.
    [:CategoryDependsOnHigherDamagePoisonTarget,
     :CategoryDependsOnHigherDamageIgnoreTargetAbility,
     :CategoryDependsOnHigherDamageTera,
     :TerapagosCategoryDependsOnHigherDamage].each do |name|
      next if !Battle::Move.const_defined?(name, false)
      klass = Battle::Move.const_get(name)
      hook = Module.new do
        def pbOnStartUse(user, targets)
          ExtendedTerrains.with_effective_stages([user]) { super }
        end
      end
      klass.prepend(hook)
    end

    install_advanced_ai! if respond_to?(:install_advanced_ai!)
    @installed = true
  end

  module BattleConstruction
    def new(*args, &block)
      ExtendedTerrains.install!
      super(*args, &block)
    end
  end
end

Battle.singleton_class.prepend(ExtendedTerrains::BattleConstruction)

#===============================================================================
# Sandy Terrain - summon Sandy Terrain for five turns.
#===============================================================================
class Battle::Move::StartSandyTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if @battle.field.terrain != :Sandy
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end
  def pbEffectGeneral(user); @battle.pbStartTerrain(user, :Sandy); end
end

#===============================================================================
# Swamp Terrain - summon Swamp Terrain for five turns.
#===============================================================================
class Battle::Move::StartSwampTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if @battle.field.terrain != :Swamp
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end
  def pbEffectGeneral(user); @battle.pbStartTerrain(user, :Swamp); end
end

#===============================================================================
# Toxic Terrain - summon Toxic Terrain for five turns.
#===============================================================================
class Battle::Move::StartToxicTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if @battle.field.terrain != :Toxic
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end
  def pbEffectGeneral(user); @battle.pbStartTerrain(user, :Toxic); end
end

#===============================================================================
# Draconic Terrain - summon Draconic Terrain for five turns.
#===============================================================================
class Battle::Move::StartDraconicTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if @battle.field.terrain != :Draconic
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end
  def pbEffectGeneral(user); @battle.pbStartTerrain(user, :Draconic); end
end

#===============================================================================
# Colosseum Terrain - summon Colosseum Terrain for five turns.
#===============================================================================
class Battle::Move::StartColosseumTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if @battle.field.terrain != :Colosseum
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end
  def pbEffectGeneral(user); @battle.pbStartTerrain(user, :Colosseum); end
end

#===============================================================================
# Pollination Terrain - summon Pollination Terrain for five turns.
#===============================================================================
class Battle::Move::StartPollinationTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    return false if @battle.field.terrain != :Pollination
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end
  def pbEffectGeneral(user); @battle.pbStartTerrain(user, :Pollination); end
end

#===============================================================================
# Ravine Terrain
# Creates Ravine Terrain for five turns.
#===============================================================================
class Battle::Move::StartRavineTerrain < Battle::Move
  def pbMoveFailed?(user, targets)
    if @battle.field.terrain == :Ravine
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end

    return false
  end

  def pbEffectGeneral(user)
    @battle.pbStartTerrain(user, :Ravine)
  end
end

#===============================================================================
# Basic AI failure checks for the seven terrain-setting moves.
#===============================================================================
ExtendedTerrains::DATA.each_key do |terrain|
  Battle::AI::Handlers::MoveFailureCheck.add("Start#{terrain}Terrain",
    proc { |move, user, ai, battle| next battle.field.terrain == terrain }
  )
end
