#===============================================================================
# RETREAT — Chạy khỏi sân, thay cho hoạt ảnh thu hồi
# Yêu cầu: 000_AnimationCore.rb
# Thay toàn bộ code Retreat cũ.
#===============================================================================

module KaitoRetreatVisual
  module SceneHooks
    #---------------------------------------------------------------------------
    # Chưa chạy animation ở bước dùng chiêu.
    # Đợi game xử lý chọn Pokémon và gọi pbRecall.
    #---------------------------------------------------------------------------
    def pbAnimation(move_id, user, targets, hit_num = 0)
      return super unless move_id == :RETREAT
      return super if @kaito_retreat_drawing
      return super unless user && @battle && @battle.showAnims

      # Pokémon hoang dùng Retreat để chạy khỏi trận.
      if user.wild?
        result = super
        ["pokemon_#{user.index}", "shadow_#{user.index}"].each do |key|
          sprite = @sprites[key]
          sprite.visible = false if sprite && !sprite.disposed?
        end
        return result
      end

      @kaito_retreat_pending ||= {}
      @kaito_retreat_pending[user.index] = [
        user.pokemon, user.pokemonIndex
      ]
      nil
    end

    #---------------------------------------------------------------------------
    # Thay riêng phần thu hồi của Retreat bằng động tác chạy khỏi sân.
    # Các lần thu hồi khác vẫn dùng hoạt ảnh mặc định.
    #---------------------------------------------------------------------------
    def pbRecall(idxBattler)
      pending = @kaito_retreat_pending &&
                @kaito_retreat_pending.delete(idxBattler)
      battler = @battle.battlers[idxBattler]

      valid = pending && battler &&
              pending[0].equal?(battler.pokemon) &&
              pending[1] == battler.pokemonIndex

      return super unless valid && @battle.showAnims

      @briefMessage = false

      begin
        @kaito_retreat_drawing = true
        pbAnimation(:RETREAT, battler, [battler], 0)
      ensure
        @kaito_retreat_drawing = false
      end

      # Core vừa dọn bản sao và trả visibility về.
      # Ẩn ngay trước lần cập nhật hình tiếp theo để không lóe lại sprite.
      ["pokemon_#{idxBattler}", "shadow_#{idxBattler}"].each do |key|
        sprite = @sprites[key]
        sprite.visible = false if sprite && !sprite.disposed?
      end

      # Vẫn chạy phần đóng bảng HP.
      animation = Battle::Scene::Animation::DataBoxDisappear.new(
        @sprites, @viewport, idxBattler
      )
      begin
        loop do
          animation.update
          pbUpdate
          break if animation.animDone?
        end
      ensure
        animation.dispose
      end

      nil
    end

    # Xóa dấu Retreat cũ khi vị trí nhận Pokémon mới.
    def pbSendOutBattlers(sendOuts, startBattle = false)
      if @kaito_retreat_pending
        sendOuts.each do |entry|
          @kaito_retreat_pending.delete(entry[0])
        end
      end
      super
    end
  end
end

#===============================================================================
# Hoạt ảnh rút lui — được gọi tại thời điểm pbRecall
#===============================================================================

KaitoAnimation.register(
  :RETREAT,
  duration: 0.90,
  require_target: false,
  setup: proc do |a|
    a.sound_at(0.12, ["PRSFX- Agility"], 55, 115)

    original = a.battler_sprite
    cx, cy = a.center

    a[:cx] = cx
    a[:cy] = cy
    a[:ground] = original.y +
      (original.src_rect.height - original.oy) * original.zoom_y

    a[:direction] = a.user.index.even? ? -1 : 1

    body = a.copy(a.user, hide_original: true, z: 20_020)
    a[:body] = body
    a[:base_x] = body.x
    a[:base_y] = body.y
    a[:base_angle] = body.angle

    # Đủ xa để cả sprite ra khỏi viewport.
    a[:distance] = Graphics.width +
      original.src_rect.width * original.zoom_x.abs + 100

    if a.user.respond_to?(:shadowSprite)
      shadow = a.user.shadowSprite
      a.hide(shadow) if shadow && !shadow.disposed?
    end

    #---------------------------------------------------------------------------
    # Dư ảnh cùng tỷ lệ với Pokémon
    #---------------------------------------------------------------------------
    a[:ghosts] = Array.new(3) do |i|
      ghost = a.copy(
        a.user,
        force_visible: true,
        z: 20_016 + i
      )
      ghost.color = Color.new(159, 201, 217, 145)
      ghost.opacity = 0
      ghost
    end

    #---------------------------------------------------------------------------
    # Bụi chân
    #---------------------------------------------------------------------------
    dust = a.bitmap(38, 26) do |b|
      a.polygon(
        b,
        [[1, 17], [6, 7], [15, 5], [21, 1],
         [31, 6], [33, 13], [37, 18], [30, 24],
         [13, 25], [4, 22]],
        Color.new(198, 189, 168, 125)
      )
      a.polygon(
        b,
        [[7, 16], [15, 10], [25, 10], [31, 17],
         [24, 21], [13, 21]],
        Color.new(234, 228, 207, 110)
      )
    end
    a[:dust] = Array.new(14) { a.sprite(dust, z: 20_024) }

    #---------------------------------------------------------------------------
    # Vệt gió
    #---------------------------------------------------------------------------
    wind = a.bitmap(96, 12) do |b|
      a.polygon(
        b,
        [[0, 6], [73, 1], [95, 6], [73, 11]],
        Color.new(186, 224, 239, 150)
      )
      a.polygon(
        b,
        [[16, 6], [79, 4], [95, 6], [79, 7]],
        Color.new(240, 254, 255, 210)
      )
    end
    a[:wind] = Array.new(4) { a.sprite(wind, z: 20_025) }
  end
) do |a, _t|
  sec = a.seconds
  direction = a[:direction]

  #=============================================================================
  # LẤY ĐÀ → TĂNG TỐC → RA KHỎI SÂN
  #=============================================================================
  brace = Math.sin(a.clamp(sec / 0.18) * Math::PI)
  run = a.clamp((sec - 0.15) / 0.57)
  travel = run * run * a[:distance]

  body = a[:body]
  body.x = a[:base_x] - direction * brace * 3 +
           direction * travel
  body.y = a[:base_y] + brace * 2 -
           Math.sin(run * Math::PI * 5).abs * 3 * (1.0 - run)
  body.angle = a[:base_angle] - direction * run * 5
  body.opacity = sec < 0.77 ? 255 : 0

  # Dư ảnh chạy cùng hướng, trễ hơn thân chính.
  a[:ghosts].each_with_index do |ghost, i|
    delayed = a.clamp((sec - 0.18 - i * 0.025) / 0.57)
    distance = delayed * delayed * a[:distance]
    envelope = a.clamp((sec - 0.19) / 0.10) *
               a.clamp((0.74 - sec) / 0.17)

    ghost.x = a[:base_x] + direction * distance
    ghost.y = a[:base_y]
    ghost.angle = a[:base_angle] - direction * delayed * 5
    ghost.opacity = (envelope * (65 - i * 15)).to_i
  end

  # Bụi lưu lại tại chỗ xuất phát.
  a[:dust].each_with_index do |dust, i|
    q = (sec - 0.18 - i % 7 * 0.025) / 0.47
    p = a.clamp(q)

    dust.x = a[:cx] - direction * (p * (20 + i % 4 * 9))
    dust.y = a[:ground] -
             Math.sin(p * Math::PI) * (5 + i % 3 * 5)
    dust.angle = i * 29
    dust.zoom_x = 0.25 + p * 0.85
    dust.zoom_y = 0.20 + p * 0.45
    dust.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 155).to_i : 0
  end

  # Vệt gió kéo theo hướng chạy.
  a[:wind].each_with_index do |wind, i|
    q = (sec - 0.21 - i * 0.035) / 0.35
    p = a.clamp(q)

    wind.x = a[:cx] + direction * (p * 95 - 15)
    wind.y = a[:cy] + (i - 1.5) * 12
    wind.mirror = direction < 0
    wind.zoom_x = 0.40 + p * 0.65
    wind.zoom_y = 0.45
    wind.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 185).to_i : 0
  end
end

unless Battle::Scene.ancestors.include?(KaitoRetreatVisual::SceneHooks)
  Battle::Scene.prepend(KaitoRetreatVisual::SceneHooks)
end