# Custom move animations: hide HP/databoxes and play existing Audio/SE/Anim SEs.
# Essentials v21.1. ADD this file alongside all previous animation .rb files.
# It wraps the animations at runtime, after all plugins have loaded.
# No image, audio download, PBS change or replacement animation file is needed.
module CustomAnimationPresentation
  VERSION = "1.0"
  MOVE_VISUALS = {
    :SKYKICK => :SkyKickVisual, :RIDERKICK => :RiderKickVisual,
    :SHADOWFANGS => :ShadowFangsVisual, :SHADOWFANG => :ShadowFangsVisual,
    :FAIRYSPHERES => :FairySpheresVisual, :FAIRYSPHERE => :FairySpheresVisual,
    :MYSTICDANCE => :MysticDanceVisual, :STORMDRIVE => :StormDriveVisual,
    :DRAGONCURRENT => :DragonCurrentVisual, :CURSEDTERRAIN => :CursedTerrainVisual,
    :MOONYNIGHT => :GloomMoonlightVisual, :GLOOMMOONLIGHT => :GloomMoonlightVisual
  }

  # [time in animation seconds, filename BELOW Audio/SE/Anim/, volume, pitch]
  def self.move_cues(id,hit)
    case id
    when :SKYKICK
      [[0.0,"PRSFX- Wind",65,115],[0.49,"PRSFX- Jump Kick1",70,110],
       [1.00,"PRSFX- Jump Kick2",85,105]]
    when :RIDERKICK
      [[0.0,"PRSFX- Quiver Dance",60,105],[0.45,"PRSFX- Hi Jump Kick1",75,105],
       [1.53,"PRSFX- Megakick",90,95]]
    when :SHADOWFANGS,:SHADOWFANG
      [[0.0,"PRSFX- Ominous Wind",65,85],[1.18,"PRSFX- Hyper Fang",85,85]]
    when :FAIRYSPHERES,:FAIRYSPHERE
      pitch = [110+hit.to_i*5,135].min
      if hit.to_i==0
        [[0.0,"PRSFX- Fairy Wind",60,115],[0.42,"PRSFX- Moonblast1",65,pitch],
         [0.86,"PRSFX- Moonblast2",75,pitch]]
      else
        [[0.0,"PRSFX- Moonblast1",65,pitch],[0.35,"PRSFX- Moonblast2",75,pitch]]
      end
    when :MYSTICDANCE
      [[0.0,"PRSFX- Dragon Dance",80,100],[2.04,"PRSFX- Ancient Power2",60,110]]
    when :STORMDRIVE
      if hit.to_i==1
        [[0.0,"PRSFX- Charge",75,90],[0.66,"PRSFX- Thunderbolt1",65,95],
         [1.30,"PRSFX- Thunder Wave",60,105]]
      else
        [[0.0,"PRSFX- Wild Charge1",80,100],[0.72,"PRSFX- Thunderbolt2",90,90]]
      end
    when :DRAGONCURRENT
      if hit.to_i==1
        [[0.0,"PRSFX- Dive1",75,100],[0.40,"PRSFX- Dive2",75,100],
         [1.18,"PRSFX- Dive3",65,95]]
      else
        [[0.0,"PRSFX- Dive3",75,95],[0.80,"PRSFX- Dragon Rush2",85,105],
         [1.24,"PRSFX- Whirlpool2",80,95]]
      end
    when :CURSEDTERRAIN
      [[0.0,"PRSFX- Curse",80,85],[0.64,"PRSFX- Curse2",75,95]]
    when :MOONYNIGHT,:GLOOMMOONLIGHT
      [[0.0,"PRSFX- Moonlight",80,85],[0.92,"PRSFX- Dark Pulse1",55,85]]
    else
      []
    end
  end

  def self.play(cue)
    @resolved ||= {}
    names = cue[1].is_a?(Array) ? cue[1] : [cue[1]]
    cache_key = names.join("|")
    unless @resolved.key?(cache_key)
      @resolved[cache_key] = names.find do |name|
        [".wav",".ogg",".mp3",".flac",".mid",".midi"].any? do |ext|
          File.file?("Audio/SE/Anim/#{name}#{ext}")
        end
      end
    end
    name = @resolved[cache_key]
    pbSEPlay("Anim/#{name}",cue[2],cue[3]) if name
  end

  def self.install
    klass = Battle::Scene
    klass.prepend(Presentation) unless klass.ancestors.include?(Presentation)
  end

  module Presentation
    def pbAnimation(moveID,user,targets,hitNum=0)
      visual = CustomAnimationPresentation::MOVE_VISUALS[moveID]
      return super unless visual && Object.const_defined?(visual)
      return super if @battle && !@battle.showAnims
      pbCustomAnimationPresent(CustomAnimationPresentation.move_cues(moveID,hitNum)) { super }
    end

    def pbCommonAnimation(name,user=nil,target=nil)
      return super if @custom_animation_presentation
      return super if @battle && !@battle.showAnims
      key = name.to_s.gsub(/[^a-z]/i,"").downcase
      cues = case key
             when "grassyterrain"
               return super unless defined?(GrassyTerrainVisual)
               full = @grassy_visual_cast_requested || !@grassy_visual_layer || !@grassy_visual_seen_active
               return super unless full
               [[0.0,"PRSFX- Grassy Terrain",80,100]]
             when "gloommoon"
               return super unless defined?(GloomMoonlightVisual)
               CustomAnimationPresentation.move_cues(:MOONYNIGHT,0)
             when "statup"
               return super unless defined?(StatChangeVisual)
               [[0.0,["Common/StatUp","PRSFX- Stat Up"],75,105]]
             when "statdown"
               return super unless defined?(StatChangeVisual)
               [[0.0,["Common/StatDown","PRSFX- Stat Down"],75,95]]
             else
               return super
             end
      pbCustomAnimationPresent(cues) { super }
    end

    def pbCustomAnimationPresent(cues)
      return yield if @custom_animation_presentation
      # Keep each original visibility flag, including already hidden boxes.
      context = { :saved=>{}, :clock=>0.0, :queue=>cues.map { |c| c.dup }.sort_by { |c| c[0] } }
      @custom_animation_presentation = context
      begin
        pbCustomAnimationHideHP
        pbCustomAnimationPlayDue
        yield
      ensure
        @custom_animation_presentation = nil
        context[:saved].each_value do |entry|
          sprite,visible = entry
          sprite.visible = visible if sprite && !sprite.disposed?
        end
      end
    end

    def pbCustomAnimationHideHP
      context = @custom_animation_presentation
      return unless context && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        context[:saved][sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end

    def pbCustomAnimationPlayDue
      context = @custom_animation_presentation
      return unless context
      while context[:queue][0] && context[:queue][0][0]<=context[:clock]+0.000001
        CustomAnimationPresentation.play(context[:queue].shift)
      end
    end

    def pbGraphicsUpdate
      if @custom_animation_presentation
        # Repeat before Graphics.update: another plugin may refresh a databox.
        pbCustomAnimationHideHP
        pbCustomAnimationPlayDue
        @custom_animation_presentation[:clock] += 1.0/[Graphics.frame_rate,1].max
      end
      super
    end
  end

  module Installer
    def pbGraphicsUpdate
      # Lazy installation puts Presentation above the previous animation
      # prepends regardless of .rb filename or plugin compilation order.
      CustomAnimationPresentation.install
      super
    end
  end
end
Battle::Scene.prepend(CustomAnimationPresentation::Installer)
