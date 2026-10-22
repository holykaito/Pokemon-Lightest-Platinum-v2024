# encoding: UTF-8
# Pokemon Essentials 21.1. Self-drawn UI; no extra graphics required.
module ZenithNewPokemon
  ENABLED = true
  MIN_READ_TIME = 3.0        # Ignore close presses during these first seconds.
  FONT_NAME = "UTM Neo Sans Intel"
  TEXT_SIZE = 16            # Same fixed size for entry, abilities and innates.
  FADE_IN = 0.30
  FADE_OUT = 0.35
  # true: every opposing species, once per battle (useful for testing).
  SHOW_KNOWN = false
  WIDTH = 492
  HEIGHT = 372
  STATS = [[:HP, "HP"], [:ATTACK, "Atk"], [:DEFENSE, "Def"],
           [:SPECIAL_ATTACK, "Sp.Atk"], [:SPECIAL_DEFENSE, "Sp.Def"],
           [:SPEED, "Speed"]]
  TYPE_COLORS = {
    :NORMAL => [155, 158, 143], :FIRE => [220, 100, 57],
    :WATER => [61, 135, 214], :ELECTRIC => [197, 160, 35],
    :GRASS => [76, 157, 80], :ICE => [64, 160, 173],
    :FIGHTING => [185, 77, 70], :POISON => [151, 78, 174],
    :GROUND => [171, 135, 70], :FLYING => [126, 120, 199],
    :PSYCHIC => [211, 82, 132], :BUG => [131, 155, 45],
    :ROCK => [155, 139, 71], :GHOST => [114, 90, 155],
    :DRAGON => [97, 96, 190], :DARK => [104, 98, 100],
    :STEEL => [122, 146, 164], :FAIRY => [191, 117, 164]
  }

  def self.fade_opacity(elapsed, duration, fading_out = false)
    progress = duration > 0 ? [[elapsed / duration, 0.0].max, 1.0].min : 1.0
    # Smooth ease, instead of a hard linear transition.
    progress = progress * progress * (3.0 - 2.0 * progress)
    return (255 * (fading_out ? 1.0 - progress : progress)).round
  end

  def self.close_pressed?
    return Input.trigger?(Input::USE)
  end

  # Read the complete pool; never call Pokemon#getInnateList, which samples
  # a random set in this project's Innate Abilities plugin.
  def self.innate_ids(data)
    if defined?(GameData::InnateSet)
      set = GameData::InnateSet.get_species_form(data.species, data.form)
      return [] if !set
      values = set.is_a?(Hash) ? set[:innates] : set.innates
      return Array(values).flatten.compact.uniq
    end
    return data.respond_to?(:innates) ? Array(data.innates).flatten.compact.uniq : []
  end

  def self.ability_names(ids)
    return ids.compact.uniq.map do |id|
      ability = GameData::Ability.try_get(id)
      ability ? ability.name : id.to_s
    end
  end

  # Read native GIF/PNG frames without the battle UI's sprite scaling.
  class NativePortrait < Sprite
    attr_reader :image_width, :image_height

    def load_pokemon(pokemon)
      self.zoom_x = self.zoom_y = 1.0
      self.ox = self.oy = 0
      @image_width = @image_height = 0
      file = GameData::Species.sprite_filename(pokemon.species, pokemon.form,
               pokemon.gender, pokemon.shiny?, pokemon.shadowPokemon?, false, pokemon.egg?)
      return if !file
      @animation = AnimatedBitmap.new(file)
      bitmap = @animation.bitmap
      @strip = !bitmap.animated? && @animation.length == 1 && bitmap.width > bitmap.height * 2
      @frame_count = @strip ? (bitmap.width / bitmap.height) : @animation.length
      @frame_index = 0
      @frame_started = System.uptime
      @bounds = nil
      if bitmap.animated?
        # Union of all frames: trim transparent margins, never the character.
        bitmap.frame_count.times do |i|
          bitmap.goto_and_stop(i)
          include_bounds(bitmap, 0, bitmap.width, bitmap.height)
        end
        bitmap.goto_and_stop(0)
        bitmap.play
      elsif @strip
        @frame_count.times do |i|
          include_bounds(bitmap, i * bitmap.height, bitmap.height, bitmap.height)
        end
      else
        @animation.each { |frame| include_bounds(frame, 0, frame.width, frame.height) }
      end
      @bounds ||= [0, 0, @strip ? bitmap.height - 1 : bitmap.width - 1, bitmap.height - 1]
      @image_width = @bounds[2] - @bounds[0] + 1
      @image_height = @bounds[3] - @bounds[1] + 1
      refresh_frame
    end

    def include_bounds(bitmap, offset_x, width, height)
      height.times do |y|
        width.times do |x|
          next if @bounds && x >= @bounds[0] && x <= @bounds[2] && y >= @bounds[1] && y <= @bounds[3]
          next if bitmap.get_pixel(offset_x + x, y).alpha == 0
          if @bounds
            @bounds = [[@bounds[0], x].min, [@bounds[1], y].min,
                       [@bounds[2], x].max, [@bounds[3], y].max]
          else
            @bounds = [x, y, x, y]
          end
        end
      end
    end

    def refresh_frame
      return if !@animation
      self.bitmap = @animation.bitmap
      offset = @strip ? @frame_index * self.bitmap.height : 0
      self.src_rect.set(offset + @bounds[0], @bounds[1], @image_width, @image_height)
    end

    def update
      return if !@animation
      @animation.update
      @frame_index = ((System.uptime - @frame_started) / 0.10).floor % @frame_count if @strip
      refresh_frame
    end

    def dispose
      self.bitmap = nil if !disposed?
      @animation.dispose if @animation && !@animation.disposed?
      @animation = nil
      super
    end
  end

  class Popup
    def initialize(scene, pokemon)
      @scene, @pokemon = scene, pokemon
      @sprites, @bitmaps = [], []
      @scroll_y = 0
    end

    def run
      begin
        build
        started = System.uptime
        closing_at = nil
        loop do
          @scene.pbUpdate
          elapsed = System.uptime - started
          if !closing_at && elapsed >= MIN_READ_TIME && ZenithNewPokemon.close_pressed?
            closing_at = System.uptime
          end
          if closing_at
            closing_elapsed = System.uptime - closing_at
            break if closing_elapsed >= FADE_OUT
            opacity = ZenithNewPokemon.fade_opacity(closing_elapsed, FADE_OUT, true)
          else
            opacity = ZenithNewPokemon.fade_opacity(elapsed, FADE_IN)
            update_scroll
            refresh_footer(elapsed)
          end
          @sprites.each { |s| s.opacity = opacity }
          @portrait.update
        end
      ensure
        dispose
      end
    end

    def dispose
      @sprites.reverse_each { |s| s.dispose if !s.disposed? }
      @bitmaps.each { |b| b.dispose if !b.disposed? }
      @body_viewport.dispose if @body_viewport && !@body_viewport.disposed?
      @viewport.dispose if @viewport && !@viewport.disposed?
    end

    def new_bitmap(w, h)
      bitmap = Bitmap.new(w, h)
      @bitmaps << bitmap
      bitmap.text_offset_y = 0
      bitmap.font.name = FONT_NAME
      bitmap.font.bold = false
      bitmap.font.italic = false
      return bitmap
    end

    def sprite(bitmap = nil, viewport = @viewport)
      ret = Sprite.new(viewport)
      @sprites << ret
      ret.bitmap = bitmap if bitmap
      ret.zoom_x = ret.zoom_y = 1.0
      ret.opacity = 0
      return ret
    end

    def build
      # Integer coordinates and 1:1 bitmaps throughout. Never shrink the panel.
      @width = [WIDTH, Graphics.width - 16].min
      @height = [HEIGHT, Graphics.height - 12].min
      @left = (Graphics.width - @width) / 2
      @top = (Graphics.height - @height) / 2
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99999
      dim = new_bitmap(Graphics.width, Graphics.height)
      dim.fill_rect(0, 0, dim.width, dim.height, Color.new(17, 36, 58, 105))
      sprite(dim)
      @frame_canvas = new_bitmap(@width, @height)
      frame = sprite(@frame_canvas)
      frame.x, frame.y = @left, @top
      @canvas = @frame_canvas
      @data = @pokemon.species_data
      @body_width = @width - 28
      title = @data.name
      title += " - #{@data.form_name}" if @data.form > 0 && @data.form_name && !@data.form_name.empty?
      title_lines, title_line_height = measure(title, @width - 78, 22)
      @body_top = [38, title_lines.length * title_line_height + 14].max
      @footer_y = @height - 32
      @body_height = @footer_y - 8 - @body_top
      @body_viewport = Viewport.new(@left + 14, @top + @body_top, @body_width, @body_height)
      @body_viewport.z = @viewport.z + 1
      @portrait = NativePortrait.new(@body_viewport)
      @sprites << @portrait
      @portrait.opacity = 0
      @portrait.load_pokemon(@pokemon)
		prepare_body

		# Thu gọn chiều cao theo nội dung.
		@body_height = [@body_height, @content_height].min
		@footer_y = @body_top + @body_height + 6
		@height = @footer_y + 32

		# Căn giữa lại popup và vùng nội dung.
		@top = (Graphics.height - @height) / 2
		frame.y = @top
		@body_viewport.rect.set(
		  @left + 14,
		  @top + @body_top,
		  @body_width,
		  @body_height
		)

		draw_frame(title)
      draw_body
      apply_scroll
      refresh_footer(0)
    end

    def measure(text, width, size = TEXT_SIZE)
      @canvas.font.size = size
      return wrap(text, width), [@canvas.text_size("Ag").height, size + 4].max
    end

    def prepare_body
      @left_width = [154, @portrait.image_width + 16].max
      @stacked = @left_width + 218 > @body_width
      @left_width = @body_width if @stacked
      @top_height = [136, @portrait.image_height + 42].max
      @stats_y = @stacked ? @top_height + 6 : 0
      @stats_x = @stacked ? 0 : @left_width + 8
      @stats_width = @body_width - @stats_x
      @entry_y = (@stacked ? @stats_y + 140 : @top_height) + 6
      @entry = @data.pokedex_entry.to_s.gsub(/\s+/, " ").strip
      @entry = _INTL("Chưa có mô tả Pokédex.") if @entry.empty?
      lines, lh = measure(@entry, @body_width - 20)
      @entry_height = [lines.length * lh + 12, 34].max
      @ability_text = ZenithNewPokemon.ability_names(Array(@data.abilities) + Array(@data.hidden_abilities)).join(" / ")
      @innate_text = ZenithNewPokemon.ability_names(ZenithNewPokemon.innate_ids(@data)).join(" / ")
      @ability_text = _INTL("Không có") if @ability_text.empty?
      @innate_text = _INTL("Không có") if @innate_text.empty?
      @ability_y = @entry_y + @entry_height + 6
      lines, lh = measure(@ability_text, @body_width - 100)
      @ability_height = [lines.length * lh + 12, 32].max
      @innate_y = @ability_y + @ability_height + 6
      lines, lh = measure(@innate_text, @body_width - 100)
      @innate_height = [lines.length * lh + 12, 32].max
      @content_height = @innate_y + @innate_height + 2
      @scroll_max = [@content_height - @body_height, 0].max
      @body_canvas = new_bitmap(@body_width, @content_height)
      @body_sprite = sprite(@body_canvas, @body_viewport)
      @body_sprite.z = 0
      @portrait.z = 1
    end

    def wrap(text, width)
      result = []
      text.to_s.split("\n", -1).each do |paragraph|
        line = ""
        paragraph.split(/\s+/).each do |word|
          candidate = line.empty? ? word : "#{line} #{word}"
          if @canvas.text_size(candidate).width <= width
            line = candidate
            next
          end
          result << line if !line.empty?
          line = ""
          word.each_char do |char|
            if !line.empty? && @canvas.text_size(line + char).width > width
              result << line
              line = ""
            end
            line += char
          end
        end
        result << line
      end
      return result
    end

    def text_box(text, x, y, w, size = TEXT_SIZE, color = nil)
      @canvas.font.color = color || Color.new(37, 57, 80)
      lines, lh = measure(text, w, size)
      lines.each_with_index { |line, i| @canvas.draw_text(x, y + i * lh, w, lh, line) }
    end

    def rounded(x, y, w, h, radius, color)
      radius = [radius, w / 2, h / 2].min
      h.times do |row|
        dy = row < radius ? radius - row - 0.5 : row >= h - radius ? row - (h - radius) + 0.5 : 0
        inset = dy > 0 ? (radius - Math.sqrt([radius * radius - dy * dy, 0].max)).ceil : 0
        @canvas.fill_rect(x + inset, y + row, w - 2 * inset, 1, color)
      end
    end

    def circle(cx, cy, radius, color)
      (-radius..radius).each do |dy|
        half = Math.sqrt([radius * radius - dy * dy, 0].max).floor
        @canvas.fill_rect(cx - half, cy + dy, half * 2 + 1, 1, color)
      end
    end

    def card(x, y, w, h, tint = nil)
      rounded(x, y, w, h, 8, Color.new(211, 226, 238))
      rounded(x + 1, y + 1, w - 2, h - 2, 7, tint || Color.new(255, 255, 255))
    end

    def draw_frame(title)
      @canvas = @frame_canvas
      rounded(0, 0, @width, @height, 13, Color.new(181, 207, 226))
      rounded(1, 1, @width - 2, @height - 2, 12, Color.new(244, 249, 253))
      rounded(14, 9, 4, @body_top - 18, 2, Color.new(64, 160, 193))
      text_box(title, 26, 7, @width - 78, 22)
      cx = @width - 33
      circle(cx, 21, 11, Color.new(198, 220, 234))
      circle(cx, 21, 9, Color.new(244, 249, 253))
      @canvas.fill_rect(cx - 9, 20, 19, 2, Color.new(198, 220, 234))
      circle(cx, 21, 4, Color.new(198, 220, 234))
      circle(cx, 21, 2, Color.new(255, 255, 255))
    end

    def draw_body
      @canvas = @body_canvas
      @canvas.fill_rect(0, 0, @body_width, @content_height, Color.new(244, 249, 253))
      ink = Color.new(37, 57, 80)
      muted = Color.new(98, 121, 143)
      accent = Color.new(34, 117, 161)
      card(0, 0, @left_width, @top_height, Color.new(235, 246, 251))
      @portrait_x = (@left_width - @portrait.image_width) / 2
      @portrait_y = (@top_height - 30 - @portrait.image_height) / 2
      radius = [(@left_width - 22) / 2, (@top_height - 36) / 2].min
      cx, cy = @left_width / 2, (@top_height - 30) / 2
      circle(cx, cy, radius, Color.new(218, 236, 246))
      circle(cx, cy, radius - 2, Color.new(240, 249, 253))
      types = @data.types.uniq
      badge_width = (@left_width - 12 - [types.length - 1, 0].max * 4) / [types.length, 1].max
      types.each_with_index do |id, i|
        x = 6 + i * (badge_width + 4)
        rgb = TYPE_COLORS[id] || [88, 126, 155]
        rounded(x, @top_height - 25, badge_width, 20, 5, Color.new(*rgb))
        text_box(GameData::Type.get(id).name, x + 5, @top_height - 24, badge_width - 10, 14, Color.new(255, 255, 255))
      end
      card(@stats_x, @stats_y, @stats_width, @stacked ? 140 : @top_height)
      sx, sy = @stats_x, @stats_y
      text_box(_INTL("CHỈ SỐ CƠ BẢN"), sx + 10, sy + 6, @stats_width - 90, 12, accent)
      stats = @data.base_stats
      total = STATS.inject(0) { |sum, pair| sum + (stats[pair[0]] || 0) }
      text_box("BST #{total}", sx + @stats_width - 75, sy + 6, 68, 12, accent)
      palette = [[103,177,113], [225,146,83], [205,176,80], [97,157,212], [149,132,196], [200,125,162]]
      STATS.each_with_index do |pair, i|
        id, label = pair
        y = sy + 28 + i * 17
        value = stats[id] || 0
        rounded(sx + 7, y, @stats_width - 14, 17, 3, Color.new(246, 249, 252)) if i.even?
        text_box(label, sx + 12, y - 1, 54, 14, muted)
        text_box(value.to_s, sx + 67, y - 1, 32, 14, ink)
        bar_x, bar_w = sx + 104, @stats_width - 116
        rounded(bar_x, y + 5, bar_w, 6, 3, Color.new(225, 233, 241))
        length = [[value.to_f / 255 * bar_w, 0].max, bar_w].min.round
        rounded(bar_x, y + 5, length, 6, 3, Color.new(*palette[i])) if length > 0
      end
      card(0, @entry_y, @body_width, @entry_height)
      text_box(@entry, 10, @entry_y + 6, @body_width - 20, TEXT_SIZE, ink)
      [[@ability_y, @ability_height, "ABILITY", @ability_text, [227,240,249]],
       [@innate_y, @innate_height, "INNATE", @innate_text, [233,237,251]]].each do |y, h, label, text, rgb|
        card(0, y, @body_width, h)
        rounded(1, y + 1, 78, h - 2, 7, Color.new(*rgb))
        text_box(label, 10, y + (h - 18) / 2, 67, 13, accent)
        text_box(text, 90, y + 6, @body_width - 100, TEXT_SIZE, ink)
      end
    end

    def update_scroll
      return if @scroll_max == 0
      old = @scroll_y
      @scroll_y = [@scroll_y - 16, 0].max if Input.repeat?(Input::UP)
      @scroll_y = [@scroll_y + 16, @scroll_max].min if Input.repeat?(Input::DOWN)
      apply_scroll if old != @scroll_y
    end

    def apply_scroll
      @body_sprite.x = 0
      @body_sprite.y = -@scroll_y
      @portrait.x = @portrait_x
      @portrait.y = @portrait_y - @scroll_y
    end

    def refresh_footer(elapsed)
      remaining = [MIN_READ_TIME - elapsed, 0].max.ceil
      return if @footer_second == remaining
      @footer_second = remaining
      @canvas = @frame_canvas
      # Opaque repaint: clear_rect would expose the battle through round corners.
      @canvas.fill_rect(14, @footer_y, @width - 28, 23, Color.new(244, 249, 253))
      rounded(14, @footer_y, @width - 28, 22, 7, Color.new(230, 240, 248))
      if remaining > 0
        text_box(_INTL("Có thể đóng sau") + " #{remaining}s", 25, @footer_y + 2, @width - 55, 14, Color.new(91, 116, 139))
      else
        rounded(24, @footer_y + 3, 25, 16, 4, Color.new(32, 113, 157))
        text_box("A", 31, @footer_y + 1, 16, 14, Color.new(255, 255, 255))
        text_box(_INTL("Nhấn A để tiếp tục"), 59, @footer_y + 2, 265, 14, Color.new(35, 88, 120))
      end
      if @scroll_max > 0
        text_box(_INTL("Lên/Xuống: xem"), @width - 153, @footer_y + 3, 133, 12, Color.new(91, 116, 139))
      end
    end
  end

  # Use aliases, rather than prepend, so plugins loaded later can safely alias
  # these methods without capturing a prepended wrapper that calls super.
  class ::Battle
    alias zenith_popup_original_pbSetSeen pbSetSeen
    alias zenith_popup_original_pbSendOut pbSendOut
    alias zenith_popup_original_pbStartBattleSendOut pbStartBattleSendOut

    def pbSetSeen(battler)
      candidate = nil
      if ZenithNewPokemon.enabled? && @internalBattle &&
      battler.is_a?(Battle::Battler) &&
         opposes?(battler.index) && !battler.pokemon.egg?
        pokemon = battler.displayPokemon
        key = pokemon.species
        @zenith_popup_pending ||= []
        @zenith_popup_scheduled ||= {}
        if !@zenith_popup_scheduled[key] &&
           (SHOW_KNOWN || !pbPlayer.pokedex.seen?(key))
          candidate = [key, pokemon]
        end
      end
      result = zenith_popup_original_pbSetSeen(battler)
      if candidate
        @zenith_popup_scheduled[candidate[0]] = true
        @zenith_popup_pending << candidate[1]
      end
      zenith_flush_popups if @zenith_popup_ready && @zenith_popup_send_depth.to_i == 0
      return result
    end

    def pbSendOut(*args)
      @zenith_popup_send_depth = @zenith_popup_send_depth.to_i + 1
      begin
        result = zenith_popup_original_pbSendOut(*args)
      ensure
        @zenith_popup_send_depth -= 1
      end
      zenith_flush_popups if @zenith_popup_ready && @zenith_popup_send_depth == 0
      return result
    end

    def pbStartBattleSendOut(*args)
      @zenith_popup_ready = false
      result = zenith_popup_original_pbStartBattleSendOut(*args)
      @zenith_popup_ready = true
      zenith_flush_popups
      return result
    end

    def zenith_flush_popups
      return if @zenith_popup_showing || !@zenith_popup_pending || @zenith_popup_pending.empty?
      return if !@scene.respond_to?(:pbZenithNewPokemonPopup)
      @zenith_popup_showing = true
      begin
        until @zenith_popup_pending.empty?
          @scene.pbZenithNewPokemonPopup(@zenith_popup_pending.shift)
        end
      ensure
        @zenith_popup_showing = false
      end
    end
  end

  class ::Battle::Scene
    def pbZenithNewPokemonPopup(pokemon)
      Popup.new(self, pokemon).run
    end
  end
end

#===============================================================================
# Lưu thiết lập popup. Save cũ mặc định bật.
#===============================================================================
class PokemonSystem
  def zenith_new_pokemon_popup
    return @zenith_new_pokemon_popup || 0
  end

  def zenith_new_pokemon_popup=(value)
    @zenith_new_pokemon_popup = value
  end
end

module ZenithNewPokemon
  def self.enabled?
    return false if !ENABLED
    return true if !$PokemonSystem
    return $PokemonSystem.zenith_new_pokemon_popup == 0
  end
end

#===============================================================================
# Thêm công tắc vào Options.
#===============================================================================
MenuHandlers.add(:options_menu, :zenith_new_pokemon_popup, {
  "name"        => _INTL("Popup Pokémon mới"),
  "order"       => 45,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Bật"), _INTL("Tắt")],
  "description" => _INTL("Hiện bảng giới thiệu khi gặp một loài Pokémon chưa từng thấy."),
  "get_proc"    => proc {
    next $PokemonSystem.zenith_new_pokemon_popup
  },
  "set_proc"    => proc { |value, _scene|
    $PokemonSystem.zenith_new_pokemon_popup = value
  }
})