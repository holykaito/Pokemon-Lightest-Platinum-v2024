#===============================================================================
# INVERSE ROOM — Không gian nghịch đảo
# Yêu cầu: 000_AnimationCore.rb
#===============================================================================

module KaitoInverseRoomVisual
  module_function

  def line(a, bitmap, p1, p2, color, thickness = 2)
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    length = Math.sqrt(dx * dx + dy * dy)
    return if length < 0.5

    nx = -dy / length * thickness / 2.0
    ny = dx / length * thickness / 2.0

    a.polygon(
      bitmap,
      [[p1[0] + nx, p1[1] + ny],
       [p2[0] + nx, p2[1] + ny],
       [p2[0] - nx, p2[1] - ny],
       [p1[0] - nx, p1[1] - ny]],
      color
    )
  end

  def mix(p1, p2, t)
    Array.new(3) { |i| p1[i] + (p2[i] - p1[i]) * t }
  end

  def face_point(points, u, v)
    top = mix(points[0], points[1], u)
    bottom = mix(points[3], points[2], u)
    mix(top, bottom, v)
  end
end

KaitoAnimation.register(
  :INVERSEROOM,
  duration: 2.95,
  require_target: false,
  setup: proc do |a|
    a.sound_at(0.03, ["PRSFX- Magic Room"], 65, 90)
    a.sound_at(0.92, ["PRSFX- Gravity"], 55, 110)
    a.sound_at(1.47, ["PRSFX- Magic Coat"], 75, 85)
    a.sound_at(2.03, ["PRSFX- Magic Room"], 45, 125)

    width = Graphics.width
    height = Graphics.height
    a[:width] = width
    a[:height] = height
    a[:cx] = width / 2.0
    a[:cy] = height * 0.44

    #---------------------------------------------------------------------------
    # Canvas khối hộp, tự vẽ lại theo góc xoay mỗi frame
    #---------------------------------------------------------------------------
    a[:canvas] = a.bitmap(width, height)
    a[:box] = a.sprite(a[:canvas], z: 20_025, centered: false)

    a[:vertices] = [
      [-1, -1, -1], [1, -1, -1],
      [1, 1, -1], [-1, 1, -1],
      [-1, -1, 1], [1, -1, 1],
      [1, 1, 1], [-1, 1, 1]
    ]

    a[:faces] = [
      [0, 3, 2, 1], [4, 5, 6, 7],
      [0, 1, 5, 4], [3, 7, 6, 2],
      [0, 4, 7, 3], [1, 2, 6, 5]
    ]

    a[:edges] = [
      [0, 1], [1, 2], [2, 3], [3, 0],
      [4, 5], [5, 6], [6, 7], [7, 4],
      [0, 4], [1, 5], [2, 6], [3, 7]
    ]

    #---------------------------------------------------------------------------
    # Điểm sáng mở không gian
    #---------------------------------------------------------------------------
    star = a.bitmap(40, 40) do |b|
      a.polygon(
        b,
        [[20, 0], [24, 15], [40, 20], [24, 24],
         [20, 40], [15, 24], [0, 20], [15, 15]],
        Color.new(216, 253, 255, 255)
      )
    end
    a[:star] = a.sprite(star, z: 20_034)

    #---------------------------------------------------------------------------
    # Hai vòng mũi tên chạy ngược chiều
    #---------------------------------------------------------------------------
    arrow_colors = [
      Color.new(166, 115, 255, 245),
      Color.new(132, 246, 240, 245)
    ]

    a[:arrows] = arrow_colors.map do |color|
      bitmap = a.bitmap(144, 144) do |b|
        36.times do |i|
          t1 = 0.30 + i / 36.0 * 5.10
          t2 = 0.30 + (i + 1) / 36.0 * 5.10

          p1 = [72 + Math.cos(t1) * 53, 72 + Math.sin(t1) * 53]
          p2 = [72 + Math.cos(t2) * 53, 72 + Math.sin(t2) * 53]
          KaitoInverseRoomVisual.line(a, b, p1, p2, color, 5)
        end

        theta = 5.40
        x = 72 + Math.cos(theta) * 53
        y = 72 + Math.sin(theta) * 53
        tx = -Math.sin(theta)
        ty = Math.cos(theta)
        nx = Math.cos(theta)
        ny = Math.sin(theta)

        a.polygon(
          b,
          [[x + tx * 13, y + ty * 13],
           [x - tx * 8 + nx * 10, y - ty * 8 + ny * 10],
           [x - tx * 8 - nx * 10, y - ty * 8 - ny * 10]],
          color
        )
      end

      a.sprite(bitmap, z: 20_035)
    end
    a[:arrows][1].mirror = true

    #---------------------------------------------------------------------------
    # Hạt sáng và ô vuông tàn dư
    #---------------------------------------------------------------------------
    particle = a.bitmap(8, 8) do |b|
      b.fill_rect(1, 1, 6, 6, Color.new(167, 226, 255, 220))
      b.fill_rect(3, 3, 2, 2, Color.new(248, 255, 255, 255))
    end
    a[:particles] = Array.new(30) { a.sprite(particle, z: 20_030) }

    tile = a.bitmap(26, 26) do |b|
      b.fill_rect(1, 1, 24, 24, Color.new(145, 103, 228, 65))
      color = Color.new(167, 240, 246, 235)
      b.fill_rect(1, 1, 24, 2, color)
      b.fill_rect(1, 23, 24, 2, color)
      b.fill_rect(1, 1, 2, 24, color)
      b.fill_rect(23, 1, 2, 24, color)
    end
    a[:tiles] = Array.new(18) { a.sprite(tile, z: 20_032) }

    #---------------------------------------------------------------------------
    # Ảnh âm bản của sân đấu cho một nhịp chớp ngắn.
    # Bitmap do core quản lý; ảnh chụp tạm được giải phóng ngay.
    #---------------------------------------------------------------------------
    # Nền trắng + ảnh sân đấu ở chế độ trừ:
    # trắng - màu gốc = màu âm bản.
    # Không cần duyệt từng pixel.
    negative_base = a.bitmap(1, 1) do |b|
      b.fill_rect(0, 0, 1, 1, Color.new(255, 255, 255))
    end

    a[:negative_base] = a.sprite(
      negative_base, z: 20_049, centered: false
    )
    a[:negative_base].zoom_x = width
    a[:negative_base].zoom_y = height

    negative = a.bitmap(width, height) do |b|
      shot = Graphics.snap_to_bitmap
      begin
        b.blt(0, 0, shot, Rect.new(0, 0, width, height))
      ensure
        shot.dispose
      end
    end

    a[:negative] = a.sprite(
      negative, z: 20_050, centered: false
    )
    a[:negative].blend_type = 2
  end
) do |a, _t|
  sec = a.seconds
  width = a[:width]
  height = a[:height]
  cx = a[:cx]
  cy = a[:cy]
  bitmap = a[:canvas]
  bitmap.clear

  #=============================================================================
  # 1. MỞ KHÔNG GIAN
  #=============================================================================
  grow = a.clamp((sec - 0.08) / 0.48)
  grow = grow * grow * (3.0 - 2.0 * grow)

  turn = a.clamp((sec - 1.18) / 0.68)
  eased_turn = turn * turn * (3.0 - 2.0 * turn)
  angle = eased_turn * Math::PI

  burst = a.clamp((sec - 1.94) / 0.42)
  box_fade = a.clamp((2.36 - sec) / 0.39)
  size = grow * (1.0 + burst * 0.55)

  # Xoay nghiêng nhẹ để thấy phối cảnh, sau đó lật quanh trục X 180°.
  vertices = a[:vertices].map do |vx, vy, vz|
    x = vx * width * 0.35 * size
    y = vy * height * 0.25 * size
    z = vz * width * 0.15 * size

    yaw = -0.32
    xx = x * Math.cos(yaw) + z * Math.sin(yaw)
    zz = -x * Math.sin(yaw) + z * Math.cos(yaw)

    yy = y * Math.cos(angle) - zz * Math.sin(angle)
    zzz = y * Math.sin(angle) + zz * Math.cos(angle)
    [xx, yy, zzz]
  end

  focal = width * 1.65
  project = proc do |point|
    perspective = focal / (focal + point[2])
    [cx + point[0] * perspective, cy + point[1] * perspective]
  end

  #=============================================================================
  # 2–3. Ô SÁNG MẤT ỔN ĐỊNH, ĐẢO SÁNG/TỐI KHI LẬT
  #=============================================================================
  if grow > 0 && box_fade > 0
    faces = a[:faces].map do |indices|
      points = indices.map { |i| vertices[i] }
      average_z = points.inject(0.0) { |sum, p| sum + p[2] } / 4.0
      [points, average_z]
    end
    faces.sort_by! { |entry| -entry[1] }

    faces.each_with_index do |entry, face_index|
      points = entry[0]

      # Chỉ vẽ các mặt hướng về camera.
      u = Array.new(3) { |i| points[1][i] - points[0][i] }
      v = Array.new(3) { |i| points[2][i] - points[0][i] }
      normal = [
        u[1] * v[2] - u[2] * v[1],
        u[2] * v[0] - u[0] * v[2],
        u[0] * v[1] - u[1] * v[0]
      ]
      toward_camera = [
        -points[0][0], -points[0][1], -focal - points[0][2]
      ]
      facing = 3.times.inject(0.0) do |sum, i|
        sum + normal[i] * toward_camera[i]
      end
      next if facing <= 0

      4.times do |row|
        4.times do |col|
          index = row * 4 + col
          active = sec >= 0.48 + index * 0.027
          bright = (row + col + face_index).even?
          bright = !bright if turn >= 0.5

          alpha = active ? (bright ? 64 : 15) : 5
          color = bright ?
            Color.new(119, 211, 235, (alpha * box_fade).to_i) :
            Color.new(49, 24, 91, (alpha * box_fade).to_i)

          corners = [
            [col / 4.0, row / 4.0],
            [(col + 1) / 4.0, row / 4.0],
            [(col + 1) / 4.0, (row + 1) / 4.0],
            [col / 4.0, (row + 1) / 4.0]
          ].map do |uu, vv|
            project.call(
              KaitoInverseRoomVisual.face_point(points, uu, vv)
            )
          end

          a.polygon(bitmap, corners, color)
        end
      end

      # Lưới trên từng mặt.
      1.upto(3) do |i|
        t = i / 4.0
        [[t, 0, t, 1], [0, t, 1, t]].each do |coords|
          p1 = project.call(
            KaitoInverseRoomVisual.face_point(points, coords[0], coords[1])
          )
          p2 = project.call(
            KaitoInverseRoomVisual.face_point(points, coords[2], coords[3])
          )
          KaitoInverseRoomVisual.line(
            a, bitmap, p1, p2,
            Color.new(150, 124, 238, (box_fade * 115).to_i), 1
          )
        end
      end
    end

    a[:edges].each_with_index do |edge, i|
      KaitoInverseRoomVisual.line(
        a, bitmap,
        project.call(vertices[edge[0]]),
        project.call(vertices[edge[1]]),
        i.even? ?
          Color.new(146, 237, 244, (box_fade * 235).to_i) :
          Color.new(166, 119, 245, (box_fade * 235).to_i),
        2
      )
    end
  end

  #=============================================================================
  # HẠT SÁNG: BAY LÊN → KHỰNG → RƠI NGƯỢC
  #=============================================================================
  a[:particles].each_with_index do |particle, i|
    start = 0.30 + i % 6 * 0.035
    rise = a.clamp((sec - start) / 0.59)
    fall = a.clamp((sec - 1.20) / 0.67)

    base_x = width * 0.17 + (i * 47 % (width * 0.66).to_i)
    base_y = height * 0.40 + i % 5 * height * 0.07

    particle.x = base_x + Math.sin(i * 2.4) * rise * 7
    particle.y = base_y - rise * 42 + fall * fall * 105
    particle.angle = fall * -140
    particle.zoom_x = 0.45 + i % 3 * 0.20
    particle.zoom_y = particle.zoom_x
    particle.opacity = (
      a.clamp((sec - start) / 0.12) *
      a.clamp((1.97 - sec) / 0.25) * 220
    ).to_i
  end

  # Deux vòng mũi tên quay ngược chiều ở tâm.
  arrow_in = a.clamp((sec - 1.25) / 0.13)
  arrow_out = a.clamp((1.99 - sec) / 0.20)

  a[:arrows].each_with_index do |arrow, i|
    direction = i == 0 ? 1 : -1
    arrow.x = cx
    arrow.y = cy
    arrow.angle = direction * (sec - 1.25) * 240
    arrow.zoom_x = i == 0 ? 0.90 : 0.62
    arrow.zoom_y = arrow.zoom_x
    arrow.opacity = (arrow_in * arrow_out * 245).to_i
  end

  negative_opacity = sec.between?(1.50, 1.58) ? 255 : 0
  a[:negative_base].opacity = negative_opacity
  a[:negative].opacity = negative_opacity

  #=============================================================================
  # 4. THIẾT LẬP ROOM — Lưới bung phủ sân rồi tan
  #=============================================================================
  grid_alpha = a.clamp((sec - 1.98) / 0.14) *
               a.clamp((2.66 - sec) / 0.44)

  if grid_alpha > 0
    1.upto(8) do |i|
      x = width * i / 9.0
      KaitoInverseRoomVisual.line(
        a, bitmap,
        [cx + (x - cx) * (1.0 - burst), cy],
        [x, height],
        Color.new(131, 231, 244, (grid_alpha * 155).to_i), 2
      )
      KaitoInverseRoomVisual.line(
        a, bitmap,
        [cx + (x - cx) * (1.0 - burst), cy],
        [x, 0],
        Color.new(169, 127, 244, (grid_alpha * 130).to_i), 1
      )
    end

    1.upto(6) do |i|
      y = height * i / 7.0
      KaitoInverseRoomVisual.line(
        a, bitmap, [0, y], [width, y],
        Color.new(161, 179, 246, (grid_alpha * 125).to_i), 1
      )
    end
  end
  a[:box].opacity = 255

  # Ô vuông nhỏ tiếp tục xoay ngược sau khi lưới tan.
  a[:tiles].each_with_index do |tile, i|
    q = (sec - 2.10 - i % 5 * 0.025) / 0.70
    p = a.clamp(q)
    theta = i * 2.399

    tile.x = cx + Math.cos(theta) * (55 + i % 5 * 25) * (1.0 + p * 0.12)
    tile.y = cy + Math.sin(theta) * (35 + i % 4 * 20) + p * 12
    tile.angle = i * 23 - p * 120
    tile.zoom_x = 0.32 + i % 4 * 0.12
    tile.zoom_y = tile.zoom_x
    tile.opacity = q.between?(0.0, 1.0) ?
      (Math.sin(p * Math::PI) * 210).to_i : 0
  end

  star = a[:star]
  star.x = cx
  star.y = cy
  star.zoom_x = 0.30 + grow * 1.20
  star.zoom_y = star.zoom_x
  star.angle = sec * 40
  star.opacity = (
    a.clamp(sec / 0.10) *
    a.clamp((0.55 - sec) / 0.30) * 255
  ).to_i
end