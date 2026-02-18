#===============================================================================
# Cinematic OP Plugin v1.1
#===============================================================================
if defined?(Scene_Intro) && defined?(ModularTitle)
  class Scene_Intro
    def main
      Graphics.transition(0)
      Input.update
      species = ModularTitle::SPECIES
      species = species.upcase.to_sym if species.is_a?(String)
      species = GameData::Species.get(species).id
      @cry = species.nil? ? nil : GameData::Species.cry_filename(species, ModularTitle::SPECIES_FORM)
      @skip = false
      self.cyclePics
      Graphics.play_movie("Movies/#{IntroConfig::VIDEO_NAME}.ogv", 
                          IntroConfig::VIDEO_VOLUME, 
                          IntroConfig::VIDEO_CANCELABLE)
      @screen = ModularTitleScreen.new
      @screen.playBGM
      @screen.intro
      self.update
      Graphics.freeze
    end
  end
else
  class IntroEventScene < EventScene
    def initialize(viewport = nil)
      super(viewport)
      @pic = addImage(0, 0, "")
      @pic.setOpacity(0, 0)        
      @pic2 = addImage(0, 0, "")   
      @pic2.setOpacity(0, 0)       
      @index = 0

      if SPLASH_IMAGES.empty?
        open_title_screen(self, nil)
      else
        open_splash(self, nil)
      end
    end

    def open_splash(_scene, *args)
      onCTrigger.clear
      @pic.name = "Graphics/Titles/" + SPLASH_IMAGES[@index]
      @pic.moveOpacity(0, FADE_TICKS, 255)
      pictureWait
      @timer = System.uptime   
      onUpdate.set(method(:splash_update)) 
      onCTrigger.set(method(:close_splash)) 
    end

    def close_splash(scene, args)
      onUpdate.clear
      onCTrigger.clear
      @pic.moveOpacity(0, FADE_TICKS, 0)
      pictureWait
      @index += 1   # Move to the next picture
      if @index >= SPLASH_IMAGES.length
        play_intro_video
      else
        open_splash(scene, args)
      end
    end

    def splash_update(scene, args)
      close_splash(scene, args) if System.uptime - @timer >= SECONDS_PER_SPLASH
    end

    def play_intro_video
      # Play the intro video
      Graphics.play_movie("Movies/#{IntroConfig::VIDEO_NAME}.ogv", 
                          IntroConfig::VIDEO_VOLUME, 
                          IntroConfig::VIDEO_CANCELABLE)
      open_title_screen(self, nil)
    end

    def open_title_screen(_scene, *args)
      onUpdate.clear
      onCTrigger.clear
      @pic.name = "Graphics/Titles/" + TITLE_BG_IMAGE
      @pic.moveOpacity(0, FADE_TICKS, 255)
      @pic2.name = "Graphics/Titles/" + TITLE_START_IMAGE
      @pic2.setXY(0, TITLE_START_IMAGE_X, TITLE_START_IMAGE_Y)
      @pic2.setVisible(0, true)
      @pic2.moveOpacity(0, FADE_TICKS, 255)
      pictureWait
      pbBGMPlay($data_system.title_bgm)
      onUpdate.set(method(:title_screen_update))
      onCTrigger.set(method(:close_title_screen))
    end

    def close_title_screen(scene, *args)
      fade_out_title_screen(scene)
      sscene = PokemonLoad_Scene.new
      sscreen = PokemonLoadScreen.new(sscene)
      sscreen.pbStartLoadScreen
    end
  end
end
