#===============================================================================
# Advanced AI System - Illusion Perception
#
# Reason: vanilla Essentials stores Zoroark's real types/ability on the battler
# even while Illusion is active (the effect is cosmetic in the engine). The AI
# read those real values via pbTypes / pbHasType? and made decisions as if it
# could see through the disguise. Result: Illusion had zero strategic weight
# against any AI-controlled trainer.
#
# This module installs an opt-in perception scope. While a scope is active, an
# opposing battler with PBEffects::Illusion set reports the disguised Pokemon's
# types/ability instead of its real ones. The AI's top-level decision methods
# are wrapped to enter the scope; the actual battle engine never does, so move
# resolution, damage calculation, and ability triggers stay accurate.
#
# Once an Illusion is broken (via direct damage), the disguised Pokemon's
# personal ID is recorded for the remainder of the battle — the AI can't be
# fooled by the same Zoroark twice.
#===============================================================================

# mkxp-z's bundled Ruby doesn't ship the `set` stdlib. Requiring it in $DEBUG
# prints a rescued LoadError, so use the small Hash-backed implementation this
# feature needs. A runtime-provided Set is retained when one already exists.
unless defined?(Set)
  class Set
    include Enumerable
    def initialize(enum = nil); @hash = {}; enum&.each { |e| @hash[e] = true }; end
    def add(o); @hash[o] = true; self; end
    alias << add
    def include?(o); @hash.key?(o); end
    alias member? include?
    def delete(o); @hash.delete(o); self; end
    def each(&blk); return to_enum(:each) unless blk; @hash.each_key(&blk); self; end
    def to_a; @hash.keys; end
    def size; @hash.size; end
    def empty?; @hash.empty?; end
  end
end

module AdvancedAI
  module IllusionPerception
    @active_observer = nil
    @exposed_pids = {}

    class << self
      attr_reader :active_observer

      # Enter perception scope. While inside, opposing battlers with active
      # Illusion are read through their disguise. Single-threaded; Essentials
      # battles never run concurrently so a module variable is sufficient.
      def with_perception(observer)
        prev = @active_observer
        @active_observer = observer
        yield
      ensure
        @active_observer = prev
      end

      def mark_exposed(battler)
        return unless battler && battler.respond_to?(:pokemon) && battler.pokemon
        battle = battler.respond_to?(:battle) ? battler.battle : nil
        return unless battle
        (@exposed_pids[battle.object_id] ||= Set.new) << battler.pokemon.personalID
      end

      def exposed?(battler)
        return false unless battler && battler.respond_to?(:pokemon) && battler.pokemon
        battle = battler.respond_to?(:battle) ? battler.battle : nil
        return false unless battle
        bucket = @exposed_pids[battle.object_id]
        return false unless bucket
        bucket.include?(battler.pokemon.personalID)
      end

      def clear_for_battle(battle)
        return unless battle
        @exposed_pids.delete(battle.object_id)
      end

      # Returns the disguised Pokemon (a Pokemon object) when perception should
      # fire for `target`, otherwise nil. Perception fires only when a scope is
      # active, the target opposes the observer, Illusion is currently up, and
      # the disguise has not been broken earlier this battle.
      def disguise_for(target)
        return nil unless @active_observer
        return nil unless target.is_a?(Battle::Battler)
        disguise = target.effects[PBEffects::Illusion] rescue nil
        return nil unless disguise
        return nil unless target.opposes?(@active_observer)
        return nil if exposed?(target)
        disguise
      end
    end
  end
end

#===============================================================================
# Battler overrides — only divert when an AI perception scope is active.
#===============================================================================
class Battle::Battler
  alias_method :pbTypes_aai_pre_illusion, :pbTypes
  def pbTypes(withExtraType = false)
    disguise = AdvancedAI::IllusionPerception.disguise_for(self)
    return pbTypes_aai_pre_illusion(withExtraType) unless disguise
    ret = Array(disguise.types).uniq
    if withExtraType && @effects[PBEffects::ExtraType] && !ret.include?(@effects[PBEffects::ExtraType])
      ret.push(@effects[PBEffects::ExtraType])
    end
    ret
  end

  alias_method :pbHasType_aai_pre_illusion?, :pbHasType?
  def pbHasType?(check_type)
    disguise = AdvancedAI::IllusionPerception.disguise_for(self)
    return pbHasType_aai_pre_illusion?(check_type) unless disguise
    return false unless check_type
    type_id = GameData::Type.get(check_type).id rescue nil
    return false unless type_id
    active = pbTypes(true)   # routed through override above
    active.include?(type_id)
  end
end

#===============================================================================
# Expose Illusion the moment it breaks. Essentials clears
# effects[PBEffects::Illusion] inside the damage pipeline; we hook the same
# path so the AI immediately registers the exposure for the rest of the battle.
#===============================================================================
class Battle::Battler
  alias_method :pbEffectsOnMakingHit_aai_pre_illusion, :pbEffectsOnMakingHit if method_defined?(:pbEffectsOnMakingHit)
end

if Battle::Battler.method_defined?(:pbEffectsOnMakingHit_aai_pre_illusion)
  class Battle::Battler
    def pbEffectsOnMakingHit(move, user, target)
      had_illusion = target.effects[PBEffects::Illusion] rescue nil
      pbEffectsOnMakingHit_aai_pre_illusion(move, user, target)
      if had_illusion && target.effects[PBEffects::Illusion].nil?
        AdvancedAI::IllusionPerception.mark_exposed(target)
      end
    end
  end
end

#===============================================================================
# Per-battle cleanup. Hooks pbStartBattle so leftover exposure from a previous
# session can't bleed forward (shouldn't matter in practice, but cheap to be
# safe).
#===============================================================================
class Battle
  alias_method :pbStartBattle_aai_pre_illusion, :pbStartBattle
  def pbStartBattle
    AdvancedAI::IllusionPerception.clear_for_battle(self)
    pbStartBattle_aai_pre_illusion
  end
end

#===============================================================================
# AI entry points — enter perception scope around every decision the AI makes.
# Engine paths outside these wrappers never enter the scope, so real damage,
# real ability triggers, and real type resolution stay untouched.
#===============================================================================
class Battle::AI
  alias_method :pbDefaultChooseEnemyCommand_aai_pre_illusion, :pbDefaultChooseEnemyCommand
  def pbDefaultChooseEnemyCommand(idxBattler)
    observer = @battlers[idxBattler] rescue nil
    AdvancedAI::IllusionPerception.with_perception(observer) do
      pbDefaultChooseEnemyCommand_aai_pre_illusion(idxBattler)
    end
  end

  alias_method :pbDefaultChooseNewEnemy_aai_pre_illusion, :pbDefaultChooseNewEnemy
  def pbDefaultChooseNewEnemy(idxBattler)
    observer = @battlers[idxBattler] rescue nil
    AdvancedAI::IllusionPerception.with_perception(observer) do
      pbDefaultChooseNewEnemy_aai_pre_illusion(idxBattler)
    end
  end
end
