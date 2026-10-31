#===============================================================================
# Zenith Ability Details - Essentials 21.1 / Modular UI Scenes
#===============================================================================
module ZenithAbilityDetails
  FONT_NAME = "UTM Neo Sans Intel"
  FONT_SIZE = 20
  LINE_HEIGHT = 26

  def self.label
    return _INTL("Chi tiết Ability")
  end

  def self.stats_label
    return _INTL("Đổi bảng chỉ số EV/IV")
  end

  def self.install_options
    [:page_skills, :page_innates].each do |page|
      options = UIHandlers.get_info(:summary, page, :options).dup
      options << label if !options.include?(label)
      if page == :page_skills && enhanced_stats? && !options.include?(stats_label)
        options << stats_label
      end
      UIHandlers.edit_hash(:summary, page, "options", options)
    end
  end

  def self.enhanced_stats?
    return false if !Settings.const_defined?(:ENHANCED_STATS_SWITCH)
    return false if !$game_switches
    return !!$game_switches[Settings::ENHANCED_STATS_SWITCH]
  end

  # Match the lock conditions shown on the installed Innate Summary page.
  # Keep original slot numbers, including gaps and duplicate Innates.
  def self.innate_entries(pokemon)
    return [] if !pokemon.respond_to?(:active_innates)
    innates = pokemon.active_innates
    if (innates.nil? || innates.empty?) && pokemon.respond_to?(:assign_innate_abilities)
      pokemon.assign_innate_abilities
      innates = pokemon.active_innates
    end
    entries = []
    Array(innates).first(3).each_with_index do |id, slot|
      next if !id
      if Settings::INNATE_PROGRESS_WITH_LEVEL
        levels = Settings::LEVELS_TO_UNLOCK.find { |row| row.first == pokemon.species }
        levels = levels ? levels.drop(1) : Settings::LEVELS_TO_UNLOCK.last
        required_level = levels && levels[slot]
        next if !required_level || pokemon.level < required_level
      end
      if Settings::INNATE_PROGRESS_WITH_VARIABLE
        count = $game_variables[Settings::INNATE_PROGRESS_VARIABLE].to_i
        next if slot >= count
      end
      ability = GameData::Ability.try_get(id)
      innate = GameData::Innate.try_get(id) if defined?(GameData::Innate)
      next if !ability && !innate
      display = innate || ability
      detail = ability && ability.real_detail
      text = if detail && !detail.strip.empty?
               ability.detail
             else
               display.description
             end
      entries << [display.name, text, _INTL("Innate {1}", slot + 1)]
    end
    return entries
  end

  def self.entries(pokemon, innate_page)
    return innate_entries(pokemon) if innate_page
    ability = GameData::Ability.try_get(pokemon.ability_id)
    return [] if !ability
    return [[ability.name, ability.detail, _INTL("Ability hiện tại")]]
  end

  # Wrap using actual font metrics. Also split a single overlong word safely.
  def self.wrap(bitmap, text, width)
    lines = []
    text.to_s.gsub(/\\n/, "\n").split("\n", -1).each do |paragraph|
      line = ""
      paragraph.split(/\s+/).each do |word|
        candidate = line.empty? ? word : "#{line} #{word}"
        if bitmap.text_size(candidate).width <= width
          line = candidate
          next
        end
        lines << line if !line.empty?
        line = ""
        word.each_char do |char|
          if !line.empty? && bitmap.text_size(line + char).width > width
            lines << line
            line = ""
          end
          line += char
        end
      end
      lines << line
    end
    return lines
  end

  class Viewer
    def initialize(scene, pokemon, entries)
      @scene = scene
      @pokemon = pokemon
      @entries = entries
      @index = 0
      @scroll = 0
    end

    def font(bitmap, size)
      bitmap.font.name = MessageConfig.pbTryFonts(FONT_NAME, MessageConfig.pbGetSystemFontName)
      bitmap.font.size = size
      bitmap.font.bold = false
      bitmap.font.italic = false
      bitmap.font.shadow = false if bitmap.font.respond_to?(:shadow=)
      bitmap.text_offset_y = 0 if bitmap.respond_to?(:text_offset_y=)
    end

    def run
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 100000
      @frame = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      @body_top = 96
      @body_height = Graphics.height - @body_top - 64
      @visible_lines = [@body_height / LINE_HEIGHT, 1].max
      @body = BitmapSprite.new(Graphics.width - 80, @visible_lines * LINE_HEIGHT, @viewport)
      @body.x = 34
      @body.y = @body_top
      @body.z = 1
      font(@body.bitmap, FONT_SIZE)
      refresh_entry
      loop do
        Graphics.update
        Input.update
        @scene.pbUpdate
        if Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          break
        elsif Input.repeat?(Input::LEFT) && @entries.length > 1
          change_entry(-1)
        elsif Input.repeat?(Input::RIGHT) && @entries.length > 1
          change_entry(1)
        elsif Input.repeat?(Input::UP) && @scroll > 0
          @scroll -= 1
          refresh_body
        elsif Input.repeat?(Input::DOWN) && @scroll < @max_scroll
          @scroll += 1
          refresh_body
        end
      end
    ensure
      @body.dispose if @body && !@body.disposed?
      @frame.dispose if @frame && !@frame.disposed?
      @viewport.dispose if @viewport && !@viewport.disposed?
      Input.update
    end

    def change_entry(delta)
      @index = (@index + delta) % @entries.length
      @scroll = 0
      pbPlayCursorSE
      refresh_entry
    end

    def refresh_entry
      @lines = ZenithAbilityDetails.wrap(@body.bitmap, @entries[@index][1], @body.bitmap.width - 4)
      @max_scroll = [@lines.length - @visible_lines, 0].max
      refresh_body
    end

    # Rounded shapes are drawn over an opaque background, without clear_rect.
    def rounded(bitmap, x, y, width, height, radius, color)
      bitmap.fill_rect(x + radius, y, width - radius * 2, height, color)
      height.times do |row|
        dy = if row < radius
               radius - row - 0.5
             elsif row >= height - radius
               row - (height - radius) + 0.5
             else
               0
             end
        inset = dy == 0 ? 0 : (radius - Math.sqrt([radius * radius - dy * dy, 0].max)).ceil
        bitmap.fill_rect(x + inset, y + row, width - inset * 2, 1, color)
      end
    end

    def refresh_frame
      bitmap = @frame.bitmap
      bitmap.clear
      width = Graphics.width
      height = Graphics.height
      # Soft ice-blue background and a restrained header gradient.
      height.times do |y|
        t = y.to_f / height
        bitmap.fill_rect(0, y, width, 1, Color.new(232 + (12 * t).to_i, 243 + (5 * t).to_i, 250 + (2 * t).to_i))
      end
      width.times do |x|
        t = x.to_f / width
        bitmap.fill_rect(x, 0, 1, 4, Color.new(48 + (62 * t).to_i, 134 + (48 * t).to_i, 180 + (26 * t).to_i))
      end
      # Compact title, with no repeated Pokemon name or "current ability" label.
      font(bitmap, 28)
      bitmap.font.bold = true
      bitmap.font.color = Color.new(32, 67, 91)
      title_width = width - (@entries.length > 1 ? 126 : 60)
      bitmap.draw_text(28, 20, title_width, 38, @entries[@index][0])
      rounded(bitmap, 28, 66, 42, 4, 2, Color.new(67, 157, 193))
      if @entries[@index][2] != _INTL("Ability hiện tại")
        font(bitmap, 16)
        bitmap.font.color = Color.new(95, 122, 139)
        bitmap.draw_text(80, 55, width - 160, 24, @entries[@index][2])
      end
      if @entries.length > 1
        rounded(bitmap, width - 92, 26, 64, 28, 10, Color.new(211, 232, 242))
        font(bitmap, 16)
        bitmap.font.color = Color.new(44, 103, 136)
        bitmap.draw_text(width - 92, 26, 64, 28, _INTL("{1}/{2}", @index + 1, @entries.length), 1)
      end
      card_height = @body_height + 28
      rounded(bitmap, 19, 84, width - 36, card_height, 12, Color.new(214, 229, 237))
      rounded(bitmap, 18, 81, width - 36, card_height, 12, Color.new(206, 225, 235))
      rounded(bitmap, 19, 82, width - 38, card_height - 2, 11, Color.new(255, 255, 255))
      # A subtle inset accent replaces a heavy frame.
      rounded(bitmap, 24, 98, 3, 30, 1, Color.new(130, 191, 214))
      if @max_scroll > 0
        track_x = width - 33
        track_y = @body_top + 2
        track_height = @visible_lines * LINE_HEIGHT - 4
        rounded(bitmap, track_x, track_y, 3, track_height, 1, Color.new(232, 240, 245))
        thumb_height = [18, (track_height * @visible_lines.to_f / @lines.length).to_i].max
        thumb_y = track_y + ((track_height - thumb_height) * @scroll.to_f / @max_scroll).round
        rounded(bitmap, track_x, thumb_y, 3, thumb_height, 1, Color.new(102, 169, 197))
      end
      # Separate text boxes avoid font-dependent separator glyphs entirely.
      font(bitmap, 16)
      bitmap.font.color = Color.new(91, 116, 133)
      footer_y = height - 34
      bitmap.draw_text(24, footer_y, 160, 24, _INTL("Lên/Xuống: Cuộn")) if @max_scroll > 0
      if @entries.length > 1
        bitmap.draw_text(180, footer_y, width - 294, 24, _INTL("Trái/Phải: Đổi"), 1)
      end
      rounded(bitmap, width - 106, footer_y - 1, 82, 26, 8, Color.new(221, 235, 243))
      bitmap.font.color = Color.new(57, 99, 125)
      bitmap.draw_text(width - 106, footer_y - 1, 82, 26, _INTL("B: Trở lại"), 1)
    end

    def refresh_body
      bitmap = @body.bitmap
      bitmap.clear
      bitmap.font.color = Color.new(48, 59, 68)
      @lines[@scroll, @visible_lines].each_with_index do |line, i|
        bitmap.draw_text(0, i * LINE_HEIGHT, bitmap.width, LINE_HEIGHT, line)
      end
      refresh_frame
    end
  end
end

# PBS registration and compiled data. Missing fields on old data are harmless.
class GameData::Ability
  SCHEMA["Detail"] = [:real_detail, "q"]
  attr_reader :real_detail

  alias zenith_details_initialize initialize
  def initialize(hash)
    zenith_details_initialize(hash)
    @real_detail = hash[:real_detail]
  end

  def detail
    return description if !@real_detail || @real_detail.strip.empty?
    return pbGetMessageFromHash(MessageTypes::ABILITY_DESCRIPTIONS, @real_detail)
  end
end

# Put Detail strings in the existing Ability description translation section.
module Compiler
  class << self
    alias zenith_details_validate_abilities validate_all_compiled_abilities
    def validate_all_compiled_abilities
      zenith_details_validate_abilities
      strings = []
      GameData::Ability.each do |ability|
        strings << ability.real_description
        detail = ability.real_detail
        strings << detail if detail && !detail.strip.empty?
      end
      MessageTypes.setMessagesAsHash(MessageTypes::ABILITY_DESCRIPTIONS, strings.uniq)
    end
  end
end

# Alias only: preserve MUI's menus and other plugins' custom commands.
class PokemonSummary_Scene
  alias zenith_details_start_scene pbStartScene
  def pbStartScene(*args)
    ZenithAbilityDetails.install_options
    zenith_details_start_scene(*args)
  end

  alias zenith_details_custom_use pbPageCustomUse
  def pbPageCustomUse(page_id)
    # Enhanced UI normally consumes A on Skills before the menu can open.
    return false if page_id == :page_skills && ZenithAbilityDetails.enhanced_stats?
    return zenith_details_custom_use(page_id)
  end

  alias zenith_details_custom_option pbPageCustomOption
  def pbPageCustomOption(command)
    if command == ZenithAbilityDetails.label
      entries = ZenithAbilityDetails.entries(@pokemon, @page_id == :page_innates)
      if entries.empty?
        pbDisplay(_INTL("Chưa có Ability hoặc Innate đã mở khóa để xem."))
      else
        pbPlayDecisionSE
        ZenithAbilityDetails::Viewer.new(self, @pokemon, entries).run
      end
      return true
    elsif command == ZenithAbilityDetails.stats_label
      @statToggle = !@statToggle
      pbPlayDecisionSE
      return true
    end
    return zenith_details_custom_option(command)
  end
end
