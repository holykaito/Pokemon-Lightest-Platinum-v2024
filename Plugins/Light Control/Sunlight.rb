class Scene_Map
  alias original_update update
  def update
    original_update
    # Kiểm tra xem người chơi có ở ngoài trời không
    if $game_map.metadata&.outdoor_map && daytime? && !$game_switches[Sunlight]
      add_sunlight_effect
    else
      remove_sunlight_effect
    end
  end

  def daytime?
    time = pbGetTimeNow
    return (time.hour >= 6 && time.hour <= 18) # Ban ngày từ 6h đến 18h
  end

  def add_sunlight_effect
    # Đảm bảo hiệu ứng không bị tạo lại nhiều lần
    return if @sunlight_sprite
    @sunlight_sprite = Sprite.new(Viewport.new(245, 205, Graphics.width, Graphics.height))
    @sunlight_sprite.bitmap = RPG::Cache.picture("Sunlight")
    @sunlight_sprite.opacity = 200  # Độ trong suốt (0-255)
    @sunlight_sprite.z = 200  # Luôn ở trên cùng
  end

  def remove_sunlight_effect
    # Xóa hiệu ứng nếu tồn tại
    if @sunlight_sprite
      @sunlight_sprite.dispose
      @sunlight_sprite = nil
    end
  end
end