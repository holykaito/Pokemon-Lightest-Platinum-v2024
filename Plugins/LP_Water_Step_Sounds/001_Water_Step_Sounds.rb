# Pokemon Essentials v21.1
# Put your two sound files in Audio/SE, then edit the names below.
module LPWaterStepSounds
  SURF_SE       = "Water surf"
  PUDDLE_SE     = "Walk on puddle"
  SURF_VOLUME   = 75
  PUDDLE_VOLUME = 75
  SURF_PITCH    = 100
  PUDDLE_PITCH  = 100
  PUDDLE_TAG    = 16

  def self.play_step
    return if !$game_player || !$PokemonGlobal
    return if $PokemonGlobal.diving
    if $PokemonGlobal.surfing
      play(SURF_SE, SURF_VOLUME, SURF_PITCH)
    elsif !$PokemonGlobal.bicycle &&
          $game_player.pbTerrainTag(true).id_number == PUDDLE_TAG
      play(PUDDLE_SE, PUDDLE_VOLUME, PUDDLE_PITCH)
    end
  end

  def self.play(name, volume, pitch)
    return if !name || name.empty?
    # Missing files are skipped so unfinished audio setup cannot crash a step.
    return if !pbResolveAudioSE(name)
    pbSEPlay(name, volume, pitch)
  end
end

EventHandlers.add(:on_player_step_taken, :lp_water_step_sounds,
  proc { LPWaterStepSounds.play_step }
)
