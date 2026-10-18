#===============================================================================
# Kaito Shield - Pokemon Essentials v21.1 / Hotfixes 1.0.9
# Separate battle-only shield pool, capped at the battler's maximum HP.
# No graphics assets or PBS changes are required for the core mechanic.
#
# INSTALL:
# Plugins/[KAITO] Shield/001_KaitoShield.rb
# Add meta.txt beside it:
#   Name       = Kaito Shield
#   Version    = 1.0.2
#   Essentials = 21.1
# Close the game and recompile plugins in Debug (hold Ctrl on startup).
#
# RULES:
# - Direct move damage and standard move recoil are absorbed first.
# - Life Orb recoil is included by default (ABSORB_LIFE_ORB below).
# - Poison/weather/hazards/Leech Seed/contact retaliation/confusion self-damage
#   and HP costs such as Belly Drum/Substitute/Explosion bypass the shield.
# - Shield stacks up to current maximum HP; switching/Baton Pass clears it.
# - Surviving shield blocks move secondary effects and move-related abilities.
# - The hit that breaks the shield can apply its secondary effects immediately.
# - Multi-hit moves re-check the remaining shield after each hit.
# - Stat stage changes are not status conditions and remain allowed.
# - Thunder Wave/Toxic/Attract and other direct STATUS moves remain effective.
# - Existing statuses are not cured. Healing real HP never repairs the shield.
# - Drain, Shell Bell and HP-damage-based abilities see only real HP damage.
# - Recoil based on damage dealt counts shield + real HP damage, then can itself
#   be absorbed by the attacker's shield. Rock Head/Magic Guard still apply.
# - Substitute, Disguise and Ice Face keep the engine's existing precedence.
# - Survival abilities/items check the HP overflow after shield absorption.
#
# PUBLIC API (inside any move/ability/item handler):
#   battler.pbGainShield(40)            # Add 40 shield points.
#   battler.pbGainShieldPercent(25)     # Add 25% of maximum HP.
#   battler.pbShieldHP                 # Current shield points.
#   battler.pbHasShield?               # True if shield remains.
#   battler.pbClearShield              # Remove it without HP damage.
#   battler.pbShieldRecoil(30)         # Custom recoil, shield-aware.
# Optional second argument false suppresses pbGainShield/Percent's message.
# For a future custom status setter, check KaitoShield.blocks_secondary?(target)
# before applying it. Standard statuses, MAG statuses, Bleed, Confusion,
# Attract, Flinch and the volatile effect list in install! are already guarded.
#
# OPTIONAL MOVE PBS (copy into a moves_*.txt file):
# [MINTWARD]
# Name = Mint Ward
# Type = NORMAL
# Category = Status
# Accuracy = 0
# TotalPP = 10
# Target = User
# FunctionCode = GiveUserShield
# Flags = CanSnatch,ShieldPercent_25
# Description = Creates a shield worth a quarter of the user's maximum HP.
#
# OPTIONAL ABILITY example (add separately, with matching abilities PBS):
# Battle::AbilityEffects::OnSwitchIn.add(:MINTGUARD,
#   proc { |ability, battler, battle, switch_in|
#     battle.pbShowAbilitySplash(battler)
#     battler.pbGainShieldPercent(25)
#     battle.pbHideAbilitySplash(battler)
#   }
# )
#
# OPTIONAL BAG ITEM example (matching items PBS: BattleUse = OnBattler):
# ItemHandlers::CanUseInBattle.add(:SHIELDCAPSULE,
#   proc { |item, pokemon, battler, move, first_action, battle, scene, show_messages|
#     allowed = battler && battler.pbCanGainShield?
#     scene.pbDisplay(_INTL("It won't have any effect.")) if !allowed && show_messages
#     next !!allowed
#   }
# )
# ItemHandlers::BattleUseOnBattler.add(:SHIELDCAPSULE,
#   proc { |item, battler, scene|
#     next battler.pbGainShieldPercent(25) > 0
#   }
# )
#
# VALIDATION LIMIT:
# Source inspected against the user's repository. No Ruby runtime/in-game UI
# test was available in the authoring environment. Advanced AI's separate
# battle strategy/damage predictions are not extended by this core plugin.
#===============================================================================
module KaitoShield
  VERSION = "1.0.2"
  MINT_RGB = [113, 238, 195]
  BAR_ANIMATION_SECONDS = Battle::Scene::PokemonDataBox::HP_BAR_CHANGE_TIME
  ABSORB_LIFE_ORB = true

  Attack = Struct.new(:battle, :user, :choice) do
    # Encore and ongoing two-turn moves can replace choice[2] during execution.
    def move
      return choice && choice[2]
    end
  end
  @attacks = []
  @secondary = []
  @recoil = []
  @volatile_rules = {}

  # Catch harmful volatile effects assigned directly with target.effects[id] = x.
  # An Array subclass is used instead of singleton patches, to remain cloneable
  # and serializable by battle-preview code. No global Array behavior is changed.
  class EffectArray < Array
    attr_accessor :shield_owner

    def []=(*args)
      if args.length == 2 && args[0].is_a?(Integer) && shield_owner &&
         KaitoShield.blocks_volatile?(shield_owner, args[0], args[1])
        return args[1]
      end
      super
    end
  end

  def self.bind_effects(battler, effects)
    return effects if !effects.is_a?(Array)
    if !effects.is_a?(EffectArray)
      wrapped = EffectArray.new
      wrapped.replace(effects)
      effects = wrapped
    end
    effects.shield_owner = battler
    return effects
  end

  def self.blocks_volatile?(battler, index, value)
    rule = @volatile_rules[index]
    return false if !rule || !blocks_secondary?(battler)
    case rule
    when :boolean then return value == true
    when :timer   then return value.is_a?(Numeric) && value > 0
    when :index   then return value.is_a?(Numeric) && value >= 0
    end
    return false
  end

  #---------------------------------------------------------------------------
  # Scoped contexts. They never leak after an exception or a nested called move.
  #---------------------------------------------------------------------------
  def self.with_attack(battle, user, choice)
    @attacks << Attack.new(battle, user, choice)
    begin
      return yield
    ensure
      @attacks.pop
    end
  end

  def self.attack_for(battle)
    return @attacks.reverse.find { |entry| entry.battle.equal?(battle) }
  end

  def self.with_secondary(battle)
    @secondary << battle
    begin
      return yield
    ensure
      @secondary.pop
    end
  end

  def self.with_recoil(battler)
    @recoil << battler
    begin
      return yield
    ensure
      @recoil.pop
    end
  end

  def self.recoil_for?(battler)
    return @recoil.any? { |entry| entry.equal?(battler) }
  end

  def self.split_damage(damage, shield)
    damage = [damage.round, 0].max
    shield = [shield.to_i, 0].max
    absorbed = [damage, shield].min
    return [absorbed, damage - absorbed]
  end

  def self.blocks_secondary?(battler)
    return false if battler.pbShieldHP <= 0
    battle = battler.battle
    return true if @secondary.any? { |entry| entry.equal?(battle) }
    attack = attack_for(battle)
    # Direct status moves still work. Self-imposed primary effects, such as
    # Outrage confusion, are not automatically removed by the user's shield.
    return attack && attack.move && attack.move.damagingMove? &&
           !attack.user.equal?(battler)
  end

  def self.refresh_bar(battler)
    scene = battler.battle.scene
    return if !scene || !scene.respond_to?(:pbRefreshOne)
    scene.pbRefreshOne(battler.index)
  end

  #---------------------------------------------------------------------------
  # Damage accounting: hpLost/totalHPLost remain REAL HP damage only.
  #---------------------------------------------------------------------------
  module DamageStateHooks
    attr_accessor :shieldLost, :totalShieldLost, :shieldPending, :shieldBroke

    def reset
      super
      @totalShieldLost = 0
    end

    def resetPerHit
      super
      @shieldLost = 0
      @shieldPending = 0
      @shieldBroke = false
    end
  end

  module BattlerHooks
    def pbInitEffects(batonPass)
      @kaito_shield_hp = 0
      result = super
      @effects = KaitoShield.bind_effects(self, @effects)
      return result
    end

    def effects
      @effects = KaitoShield.bind_effects(self, super)
      return @effects
    end

    # Public API: never changes Pokemon#hp or the displayed HP fraction.
    def pbShieldHP
      cap = [totalhp.to_i, 0].max
      @kaito_shield_hp = [[@kaito_shield_hp.to_i, 0].max, cap].min
      @kaito_shield_hp = 0 if fainted?
      return @kaito_shield_hp
    end

    def pbHasShield?
      return pbShieldHP > 0
    end

    def pbCanGainShield?
      return !fainted? && pbShieldHP < totalhp
    end

    # Adds a flat amount, stacks, returns the amount actually gained.
    def pbGainShield(amount, show_message = true)
      return 0 if !pbCanGainShield?
      amount = [amount.round, 0].max
      old = pbShieldHP
      @kaito_shield_hp = [old + amount, totalhp].min
      gained = @kaito_shield_hp - old
      return 0 if gained <= 0
      KaitoShield.refresh_bar(self)
      if show_message
        @battle.pbDisplay(_INTL("{1} gained a shield of {2}!", pbThis, gained))
      end
      return gained
    end

    # Example: pbGainShieldPercent(25) adds 25% maximum HP as shield.
    def pbGainShieldPercent(percent, show_message = true)
      amount = [(totalhp * percent / 100.0).round, 0].max
      return pbGainShield(amount, show_message)
    end

    def pbClearShield(show_message = false)
      old = pbShieldHP
      @kaito_shield_hp = 0
      KaitoShield.refresh_bar(self) if old > 0
      @battle.pbDisplay(_INTL("{1}'s shield disappeared!", pbThis)) if show_message && old > 0
      return old
    end

    # Internal/public utility: remove shield points without touching HP.
    def pbSpendShield(amount)
      lost = [[amount.round, 0].max, pbShieldHP].min
      @kaito_shield_hp = pbShieldHP - lost
      KaitoShield.refresh_bar(self) if lost > 0
      return lost
    end

    # Explicit API for a custom recoil implementation.
    def pbShieldRecoil(amount, anim = false)
      return KaitoShield.with_recoil(self) { pbReduceHP(amount, anim) }
    end

    def pbReduceHP(amt, anim = true, registerDamage = true, anyAnim = true)
      if KaitoShield.recoil_for?(self) && pbShieldHP > 0
        absorbed, remaining = KaitoShield.split_damage(amt, pbShieldHP)
        lost = pbSpendShield(absorbed)
        broke = lost > 0 && pbShieldHP == 0
        # Essentials would otherwise force pbReduceHP(0) to lose 1 real HP.
        result = remaining > 0 ? super(remaining, anim, registerDamage, anyAnim) : 0
        if broke
          @battle.pbDisplay(_INTL("{1}'s shield broke!", pbThis))
        end
        return result
      end
      # Poison, weather, hazards, HP costs and contact retaliation take this path.
      super
    end

    def pbUseMove(choice, specialUsage = false)
      move = choice && choice[2]
      return super if !move || !move.respond_to?(:damagingMove?)
      return KaitoShield.with_attack(@battle, self, choice) { super }
    end
  end

  module MoveHooks
    def pbReduceDamage(user, target)
      state = target.damageState
      state.shieldPending = 0
      return super if target.pbShieldHP <= 0 || state.calcDamage <= 0
      return super if state.substitute || state.disguise || state.iceFace
      # Split BEFORE the engine clips damage at current HP or runs survival
      # checks. Substitute/Disguise/Ice Face retain their original priority.
      original_damage = state.calcDamage
      absorbed, overflow = KaitoShield.split_damage(original_damage, target.pbShieldHP)
      state.shieldPending = absorbed
      begin
        state.calcDamage = overflow
        return super
      ensure
        state.calcDamage = original_damage
      end
    end

    def pbInflictHPDamage(target)
      state = target.damageState
      pending = state.shieldPending.to_i
      if pending > 0 && !state.substitute && !state.disguise && !state.iceFace
        state.shieldLost = target.pbSpendShield(pending)
        state.totalShieldLost = state.totalShieldLost.to_i + state.shieldLost
        state.shieldBroke = state.shieldLost > 0 && target.pbShieldHP == 0
      end
      state.shieldPending = 0
      return super if state.substitute
      old_hp = target.hp
      previous_total = state.totalHPLost - state.hpLost
      result = super
      # Account for Nine Lives, boss HP scaling and any other real-HP limiter.
      state.hpLost = [old_hp - target.hp, 0].max
      state.totalHPLost = previous_total + state.hpLost
      return result
    end

    def pbAnimateHitAndHPLost(user, targets)
      result = super
      # The normal method skips hits that caused no real HP damage.
      shield_only = targets.select do |b|
        !b.damageState.unaffected && b.damageState.shieldLost.to_i > 0 &&
          b.damageState.hpLost == 0
      end
      if !shield_only.empty?
        entries = shield_only.map do |b|
          effectiveness = 0
          effectiveness = 1 if Effectiveness.resistant?(b.damageState.typeMod)
          effectiveness = 2 if Effectiveness.super_effective?(b.damageState.typeMod)
          [b, b.hp, effectiveness]
        end
        @battle.scene.pbHitAndHPLossAnimation(entries)
      end
      return result
    end

    def pbHitEffectivenessMessages(user, target, numTargets = 1)
      result = super
      if target.damageState.shieldBroke
        @battle.pbDisplay(_INTL("{1}'s shield broke!", target.pbThis))
        target.damageState.shieldBroke = false
      end
      return result
    end
  end

  # Every ability/innate handler invoked during a move gets a secondary context.
  # This covers Poison Touch, Static, Cute Charm, Synchronize, etc., while
  # leaving abilities triggered by weather/end-of-round outside this context.
  module AbilityHandlerHooks
    def trigger(*args)
      attack = KaitoShield.instance_variable_get(:@attacks).last
      return super if !attack
      return KaitoShield.with_secondary(attack.battle) { super }
    end
  end

  module ItemEffectHooks
    def triggerAfterMoveUseFromUser(item, user, targets, move, num_hits, battle)
      id = item.respond_to?(:id) ? item.id : item
      if KaitoShield::ABSORB_LIFE_ORB && id == :LIFEORB
        return KaitoShield.with_recoil(user) { super }
      end
      super
    end
  end

  #---------------------------------------------------------------------------
  # Draw mint shield across the full height of the existing HP bar.
  # HP numbers are kept above the shield sprite.
  # Uses @hpBar's actual dimensions/coordinates for standard/DBK databoxes.
  #---------------------------------------------------------------------------
  module DataBoxHooks
    def kaito_shield_overlay_update
      return if !@battler || !@battler.respond_to?(:pbShieldHP)
      return if !@hpBar || @hpBar.disposed? || !@hpBar.bitmap || @hpBar.bitmap.disposed?
      width = @hpBarBitmap ? @hpBarBitmap.width : @hpBar.bitmap.width
      height = @hpBar.src_rect.height
      return if width <= 0 || height <= 0
      value = @battler.pbShieldHP
      now = System.uptime
      @kaito_shield_display ||= 0.0
      if @kaito_shield_battler != @battler.pokemon
        @kaito_shield_battler = @battler.pokemon
        @kaito_shield_display = value.to_f
        @kaito_shield_target = value
        @kaito_shield_timer = nil
      end
      if @kaito_shield_target != value
        @kaito_shield_start = @kaito_shield_display
        @kaito_shield_target = value
        @kaito_shield_timer = now
      end
      if @kaito_shield_timer
        fraction = [[(now - @kaito_shield_timer) /
                     KaitoShield::BAR_ANIMATION_SECONDS, 0.0].max, 1.0].min
        @kaito_shield_display = @kaito_shield_start +
          (@kaito_shield_target - @kaito_shield_start) * fraction
        @kaito_shield_timer = nil if fraction >= 1.0
      end
      return if !@kaito_shield_overlay && @kaito_shield_display <= 0
      if !@kaito_shield_overlay || @kaito_shield_overlay.disposed?
        @kaito_shield_overlay = Sprite.new(@hpBar.viewport)
        # Parent databox propagates fade color/opacity/visibility immediately.
        @sprites["kaitoShield"] = @kaito_shield_overlay
      end
      overlay = @kaito_shield_overlay
      if !overlay.bitmap || overlay.bitmap.width != width || overlay.bitmap.height != height
        overlay.bitmap.dispose if overlay.bitmap && !overlay.bitmap.disposed?
        overlay.bitmap = Bitmap.new(width, height)
      end
      pixels = (width * @kaito_shield_display / [@battler.totalhp, 1].max).round
      pixels = [[pixels, 0].max, width].min
      strip = height
      signature = [pixels, width, height]
      if @kaito_shield_draw_signature != signature
        overlay.bitmap.clear
        if pixels > 0
          edge = Color.new(28, 112, 92)
          overlay.bitmap.fill_rect(0, 0, pixels, strip, edge)
          # Vertical mint gradient, bounded by a one-pixel dark outline.
          if pixels > 2 && strip > 2
            top = [187, 255, 229]
            bottom = [62, 188, 153]
            (1...(strip - 1)).each do |row|
              t = (row - 1).to_f / [strip - 3, 1].max
              rgb = 3.times.map { |i| (top[i] + (bottom[i] - top[i]) * t).round }
              overlay.bitmap.fill_rect(1, row, pixels - 2, 1, Color.new(*rgb))
            end
          end
        end
        @kaito_shield_draw_signature = signature
      end
      overlay.x = @hpBar.x
      overlay.y = @hpBar.y
      overlay.z = @hpBar.z + 1
      if @hpNumbers && !@hpNumbers.disposed?
        @hpNumbers.z = overlay.z + 1 if @hpNumbers.z <= overlay.z
      end
      overlay.ox = @hpBar.ox
      overlay.oy = @hpBar.oy
      overlay.zoom_x = @hpBar.zoom_x
      overlay.zoom_y = @hpBar.zoom_y
      overlay.angle = @hpBar.angle
      overlay.mirror = @hpBar.mirror
      overlay.opacity = @hpBar.opacity
      overlay.color = @hpBar.color
      overlay.visible = visible && @hpBar.visible && !@battler.fainted? && pixels > 0
    end

    def hp
      if @kaito_shield_timer && !@anim_hp_timer_start
        return @battler.hp
      end
      super
    end

    # The scene waits for shield-only hits just as it waits for HP animation.
    def animating_hp?
      return super || !@kaito_shield_timer.nil?
    end

    def update_hp_animation
      # Core code uses animating_hp? as its guard. During a shield-only
      # animation it has no real HP endpoints, so do not invoke that code.
      return if !@anim_hp_timer_start
      super
    end

    def update
      result = super
      kaito_shield_overlay_update
      return result
    end

    def refresh_hp
      result = super
      kaito_shield_overlay_update
      return result
    end

    def dispose
      @sprites.delete("kaitoShield") if @sprites
      if @kaito_shield_overlay && !@kaito_shield_overlay.disposed?
        bitmap = @kaito_shield_overlay.bitmap
        @kaito_shield_overlay.dispose
        bitmap.dispose if bitmap && !bitmap.disposed?
      end
      super
    end
  end

  #---------------------------------------------------------------------------
  # Late install: avoid the alias/prepend recursion seen in earlier plugins.
  #---------------------------------------------------------------------------
  def self.install!
    return if @installed
    {
      :boolean => [:Flinch, :Torment, :Curse, :Nightmare, :GastroAcid,
                   :Powder, :TarShot, :SmackDown, :SaltCure],
      :timer => [:Confusion, :Yawn, :Taunt, :Encore, :Disable, :HealBlock,
                 :Embargo, :ThroatChop, :Trapping, :PerishSong, :Syrupy],
      :index => [:Attract, :LeechSeed, :Octolock]
    }.each do |rule, names|
      names.each do |name|
        @volatile_rules[PBEffects.const_get(name)] = rule if PBEffects.const_defined?(name)
      end
    end
    Battle::DamageState.prepend(DamageStateHooks)
    Battle::Battler.prepend(BattlerHooks)
    Battle::Move.prepend(MoveHooks)
    AbilityHandlerHash.prepend(AbilityHandlerHooks)
    Battle::ItemEffects.singleton_class.prepend(ItemEffectHooks)
    Battle::Scene::PokemonDataBox.prepend(DataBoxHooks)

    # Guard both validation and application. MAG statuses all route through
    # pbCanInflictStatus?/pbInflictStatus; Bleed uses its own entry points.
    guards = Module.new
    [:pbCanInflictStatus?, :pbInflictStatus, :pbCanConfuse?, :pbConfuse,
     :pbCanAttract?, :pbAttract, :pbFlinch, :pbCanBleed?, :pbInflictBleed].each do |name|
      next if !Battle::Battler.method_defined?(name)
      guards.send(:define_method, name) do |*args, &block|
        return false if KaitoShield.blocks_secondary?(self)
        super(*args, &block)
      end
    end
    Battle::Battler.prepend(guards)

    # pbAdditionalEffect is overridden in move subclasses. Wrap each owner
    # rather than relying on a base method which may never be called.
    classes = ObjectSpace.each_object(Class).select do |klass|
      klass == Battle::Move || klass < Battle::Move
    end
    classes.each do |klass|
      own = klass.instance_methods(false)
      hook = Module.new
      used = false
      if own.include?(:pbAdditionalEffect)
        hook.send(:define_method, :pbAdditionalEffect) do |user, target|
          KaitoShield.with_secondary(@battle) { super(user, target) }
        end
        used = true
      end
      if own.include?(:pbRecoilDamage)
        hook.send(:define_method, :pbRecoilDamage) do |user, target|
          state = target.damageState
          return super(user, target) if state.instance_variable_get(:@kaito_shield_recoil_calc)
          original = state.totalHPLost
          begin
            state.instance_variable_set(:@kaito_shield_recoil_calc, true)
            # Recoil is based on damage to the target's shield + real HP.
            # Drain healing continues to use real hpLost/totalHPLost only.
            state.totalHPLost = original + state.totalShieldLost.to_i
            super(user, target)
          ensure
            state.totalHPLost = original
            state.instance_variable_set(:@kaito_shield_recoil_calc, false)
          end
        end
        used = true
      end
      if own.include?(:pbEffectAfterAllHits)
        hook.send(:define_method, :pbEffectAfterAllHits) do |user, target|
          if is_a?(Battle::Move::RecoilMove) || id == :STRUGGLE || recoilMove?
            KaitoShield.with_recoil(user) { super(user, target) }
          else
            super(user, target)
          end
        end
        used = true
      end
      klass.prepend(hook) if used
    end
    @installed = true
  end

  module BattleConstruction
    def new(*args, **kwargs, &block)
      KaitoShield.install!
      super(*args, **kwargs, &block)
    end
  end
end

Battle.singleton_class.prepend(KaitoShield::BattleConstruction)

#===============================================================================
# FunctionCode = GiveUserShield
# Flags = ShieldPercent_25   (default: 25; supports 1..100)
# A status move that adds shield to the user. This is NOT a healing move.
#===============================================================================
class Battle::Move::GiveUserShield < Battle::Move
  def canSnatch?; return true; end

  def kaito_shield_percent
    flag = @flags.find { |f| f.to_s[/^ShieldPercent_\d+$/i] }
    percent = flag ? flag.to_s.split("_").last.to_i : 25
    return [[percent, 1].max, 100].min
  end

  def pbMoveFailed?(user, targets)
    return false if user.pbCanGainShield?
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectGeneral(user)
    user.pbGainShieldPercent(kaito_shield_percent)
  end
end

#===============================================================================
# FunctionCode = GiveTargetShield
# Flags = ShieldPercent_25
# Intended for Target = NearAllyOrUser. Does not restore real HP.
#===============================================================================
class Battle::Move::GiveTargetShield < Battle::Move::GiveUserShield
  def canSnatch?; return false; end

  def pbMoveFailed?(user, targets); return false; end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if target.pbCanGainShield?
    @battle.pbDisplay(_INTL("But it failed!")) if show_message
    return true
  end

  def pbEffectGeneral(user); end

  def pbEffectAgainstTarget(user, target)
    target.pbGainShieldPercent(kaito_shield_percent)
  end
end
