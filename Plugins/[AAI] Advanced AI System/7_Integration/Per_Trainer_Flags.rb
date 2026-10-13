#===============================================================================
# Per-trainer Skill and Flags in PBS/trainers.txt
#
# The AAI docs show `Skill` and `Flags` on an individual trainer, but stock
# Essentials v21 only defines them on the trainer TYPE (trainer_types.txt) —
# GameData::Trainer::SCHEMA has just SectionName/Items/LoseText/Pokemon, and
# to_trainer never copies skill or flags. Anything written per trainer was
# silently dropped, so e.g. Flags = ReserveLastPokemon did nothing.
#
# PluginManager.runPlugins runs before Compiler.main and the compiler reads
# GameData::Trainer.schema at runtime, so extending it here is enough for the
# keys to compile. nil keeps the old behaviour: inherit from the trainer type.
#===============================================================================
module GameData
  class Trainer
    SCHEMA["Skill"]      = [:skill_level, "u"]  unless SCHEMA.has_key?("Skill")
    SCHEMA["SkillLevel"] = [:skill_level, "u"]  unless SCHEMA.has_key?("SkillLevel")
    SCHEMA["Flags"]      = [:flags,       "*s"] unless SCHEMA.has_key?("Flags")

    attr_reader :skill_level, :flags

    alias_method :aai_ptf_initialize, :initialize unless method_defined?(:aai_ptf_initialize)
    def initialize(hash)
      aai_ptf_initialize(hash)
      @skill_level = hash[:skill_level]
      @flags       = hash[:flags]
    end

    alias_method :aai_ptf_to_trainer, :to_trainer unless method_defined?(:aai_ptf_to_trainer)
    def to_trainer
      trainer = aai_ptf_to_trainer
      return trainer unless trainer
      trainer.skill_level = @skill_level if @skill_level
      trainer.flags       = @flags.clone if @flags
      trainer
    end
  end
end

class NPCTrainer
  attr_writer :skill_level, :flags

  alias_method :aai_ptf_skill_level, :skill_level unless method_defined?(:aai_ptf_skill_level)
  def skill_level; return @skill_level || aai_ptf_skill_level; end

  alias_method :aai_ptf_flags, :flags unless method_defined?(:aai_ptf_flags)
  def flags; return @flags || aai_ptf_flags; end

  alias_method :aai_ptf_has_flag?, :has_flag? unless method_defined?(:aai_ptf_has_flag?)
  def has_flag?(flag)
    return @flags.any? { |f| f.to_s.casecmp?(flag.to_s) } if @flags
    aai_ptf_has_flag?(flag)
  end
end

class Battle::AI::AITrainer
  alias_method :aai_ptf_set_up_skill, :set_up_skill unless method_defined?(:aai_ptf_set_up_skill)

  def set_up_skill
    aai_ptf_set_up_skill
    override = AdvancedAI.mode_skill_override
    @skill = override if @side == 1 && @trainer && override
  end
end
