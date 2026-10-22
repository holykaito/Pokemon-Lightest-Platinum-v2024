# Berry eating + item activation - Pokemon Essentials v21.1 / Deluxe Battle Kit.
# Install in Plugins/[KAITO] Plugin/ and recompile. No external assets required.
# Replaces Common:EatBerry, Common:UseItem and DBK's pbItemUseAnimation.
# Presentation only: never changes HP, stats, statuses, held items or item handlers.
module BerryItemVisual
  VERSION = "1.0"
  BERRY_SECONDS = 1.04
  ITEM_SECONDS = 0.88
  def self.disc(b,cx,cy,r,c)
    (-r..r).each do |dy|
      dx=Math.sqrt(r*r-dy*dy).floor
      b.fill_rect(cx-dx,cy+dy,dx*2+1,1,c)
    end
  end
  def self.line(b,x1,y1,x2,y2,width,c)
    n=[(x2-x1).abs.round,(y2-y1).abs.round,1].max
    (0..n).each do |i|
      p=i.to_f/n
      b.fill_rect((x1+(x2-x1)*p).round-width/2,(y1+(y2-y1)*p).round-width/2,width,width,c)
    end
  end
  def self.berry_frame(battler)
    # Copy a single native icon frame; the icon sprite owns its original bitmap.
    icon=nil;copy=nil
    begin
      item=battler.item if battler && battler.respond_to?(:item)
      if item && defined?(ItemIconSprite)
        icon=ItemIconSprite.new(0,0,item,nil)
        icon.visible=false
        if icon.bitmap && icon.width>0 && icon.height>0
          copy=Bitmap.new(icon.width,icon.height)
          copy.blt(0,0,icon.bitmap,icon.src_rect)
        end
      end
    rescue StandardError
      copy.dispose if copy && !copy.disposed?
      copy=nil
    ensure
      icon.dispose if icon && !icon.disposed?
    end
    return copy if copy
    b=Bitmap.new(48,48)
    disc(b,23,27,12,Color.new(161,80,47,255))
    disc(b,25,25,11,Color.new(237,159,61,255))
    disc(b,23,21,7,Color.new(255,204,102,255))
    b.fill_rect(18,17,5,3,Color.new(255,239,176,250))
    line(b,24,15,25,8,3,Color.new(103,116,49,255))
    line(b,25,12,33,8,4,Color.new(111,169,72,255))
    line(b,23,13,16,9,3,Color.new(158,193,83,255))
    b
  end
  def self.assets(berry,battler)
    owned=[]
    begin
      orb=Bitmap.new(24,24);owned<<orb
      [[10,[137,200,235,30]],[6,[177,225,243,105]],[3,[232,248,248,240]]].each { |r,c|disc(orb,12,12,r,Color.new(*c)) }
      spark=Bitmap.new(16,16);owned<<spark
      spark.fill_rect(7,2,2,12,Color.new(255,226,157,180))
      spark.fill_rect(2,7,12,2,Color.new(255,226,157,180))
      spark.fill_rect(6,6,4,4,Color.new(255,251,219,250))
      dash=Bitmap.new(8,28);owned<<dash
      26.times do |y|
        a=(Math.sin(y/25.0*Math::PI)*220).round
        dash.fill_rect(3,y+1,2,1,Color.new(185,226,246,a))
      end
      ring=Bitmap.new(96,96);owned<<ring
      360.times do |i|
        next if i%90>74
        a=i*Math::PI/180
        ring.fill_rect((48+Math.cos(a)*39).round,(48+Math.sin(a)*39).round,2,2,Color.new(235,225,171,200))
      end
      crumb=Bitmap.new(8,8);owned<<crumb
      crumb.fill_rect(2,2,4,4,Color.new(209,128,54,240))
      crumb.fill_rect(2,2,3,2,Color.new(255,218,130,255))
      if berry
        whole=berry_frame(battler);owned<<whole
        2.times do |i|
          bite=whole.clone;owned<<bite
          cx,cy=whole.width/2,whole.height/2
          disc(bite,cx+9,cy-4,7,Color.new(0,0,0,0))
          disc(bite,cx+5,cy+8,9,Color.new(0,0,0,0)) if i==1
        end
      end
      owned
    rescue
      owned.each { |b|b.dispose unless b.disposed? }
      raise
    end
  end
  def self.play_se(berry,second=false)
    names=berry ? ["PRSFX- Bug Bite","PRSFX- Bite","PRSFX- Swallow"] : ["UseItem","PRSFX- Stockpile"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",berry ? (second ? 38 : 48) : 65,berry ? (second ? 140 : 125) : 105)
      break
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if ["eatberry","useitem"].include?(name.to_s.downcase)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      key=name.to_s.downcase
      return super unless ["eatberry","useitem"].include?(key)
      return if @battle && !@battle.showAnims
      battler=user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source=@sprites && @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @berry_item_visual_boxes
      pbBerryItemVisual(source,key=="eatberry",battler)
    end
    def pbItemUseAnimation(idxBattler)
      return if @battle && !@battle.showAnims
      return if @berry_item_visual_boxes
      source=@sprites && @sprites["pokemon_#{idxBattler}"]
      return (defined?(super) ? super : nil) unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      battler=@battle.battlers[idxBattler] if @battle && @battle.respond_to?(:battlers)
      return if battler && battler.respond_to?(:isCommander?) && battler.isCommander?
      pbBerryItemVisual(source,false,battler,idxBattler)
    end
    def pbBerryItemVisualHideHP
      return unless @berry_item_visual_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @berry_item_visual_boxes[s.object_id]||=[s,s.visible]
        s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbBerryItemVisualHideHP if @berry_item_visual_boxes
      super
    end
    def pbBerryItemVisual(source,berry,battler=nil,sub_index=nil)
      sprites,bitmaps=[],[]
      @berry_item_visual_boxes={}
      substitute=false
      begin
        @briefMessage=false
        pbBerryItemVisualHideHP
        if !sub_index.nil? && respond_to?(:pbAnimateSubstitute,true)
          substitute=true
          pbAnimateSubstitute(sub_index,:hide)
          source=@sprites["pokemon_#{sub_index}"]
        end
        return unless source && !source.disposed? && source.bitmap
        bitmaps.concat(BerryItemVisual.assets(berry,battler))
        orb_b,spark_b,dash_b,ring_b,crumb_b=bitmaps[0,5]
        make=proc do |b,ox,oy,z,blend|
          s=Sprite.new(@viewport);sprites<<s
          s.bitmap,s.ox,s.oy,s.z,s.blend_type=b,ox,oy,z,blend
          s.opacity=0;s
        end
        cx=source.x+(source.src_rect.width/2.0-source.ox)*source.zoom_x
        foot=source.y+(source.src_rect.height-source.oy)*source.zoom_y
        height=[[source.src_rect.height*source.zoom_y,60].max,180].min
        radius=[[source.src_rect.width*source.zoom_x*0.44,27].max,68].min
        cy=foot-height*0.54;z=source.z
        direction=battler && battler.index.odd? ? -1 : 1
        motes=Array.new(24) {make.call(orb_b,12,12,z+2,1)}
        sparks=Array.new(14) {make.call(spark_b,8,8,z+4,1)}
        dashes=Array.new(10) {make.call(dash_b,4,14,z+3,1)}
        rings=Array.new(2) {make.call(ring_b,48,48,z-1,1)}
        crumbs=berry ? Array.new(16) {make.call(crumb_b,4,4,z+4,0)} : []
        fruit=berry ? make.call(bitmaps[5],bitmaps[5].width/2,bitmaps[5].height/2,z+5,0) : nil
        aura_b=source.bitmap.clone;bitmaps<<aura_b
        aura=make.call(aura_b,source.ox,source.oy,z+1,1)
        aura.src_rect.set(source.src_rect.x,source.src_rect.y,source.src_rect.width,source.src_rect.height)
        aura.x,aura.y=source.x,source.y
        aura.zoom_x,aura.zoom_y,aura.mirror=source.zoom_x,source.zoom_y,source.mirror
        aura.color=berry ? Color.new(246,218,157,200) : Color.new(207,234,249,220)
        duration=berry ? BerryItemVisual::BERRY_SECONDS : BerryItemVisual::ITEM_SECONDS
        frames=[(Graphics.frame_rate*duration).round,2].max
        first=second=false
        frames.times do |f|
          t=f.to_f/(frames-1)
          fade=[t/0.12,(1-t)/0.18,1.0].min
          burst=[[(t-(berry ? 0.49 : 0.30))/(berry ? 0.44 : 0.56),0].max,1].min
          gather=[[t/(berry ? 0.70 : 0.43),0].max,1].min
          if !first && t>=(berry ? 0.30 : 0.08)
            BerryItemVisual.play_se(berry);first=true
          end
          if berry && !second && t>=0.49
            BerryItemVisual.play_se(true,true);second=true
          end
          aura.opacity=(fade*Math.sin(burst*Math::PI)*(berry ? 40 : 75)).round
          if fruit
            stage=t<0.30 ? 0 : (t<0.49 ? 1 : 2)
            fruit.bitmap=bitmaps[5+stage]
            arrival=[[t/0.24,0].max,1].min
            vanish=[[(t-0.57)/0.16,0].max,1].min
            chew=Math.sin([[(t-0.27)/0.30,0].max,1].min*Math::PI*4)
            fruit.x=cx+direction*(radius*0.54+(1-arrival)*22)
            fruit.y=cy+4-(1-arrival)*12+chew*1.5
            size=0.72*(1-vanish*0.55)
            fruit.zoom_x=size*(1+chew*0.07);fruit.zoom_y=size*(1-chew*0.09)
            fruit.angle=direction*(1-arrival)*-18
            fruit.opacity=(fade*(1-vanish)*255).round
          end
          motes.each_with_index do |s,i|
            a=i*2.399+t*2.4
            r=radius*(1.18-gather*0.95)
            s.x=cx+Math.cos(a)*r
            s.y=cy+Math.sin(a)*height*0.42*(1-gather)-t*8
            s.z=Math.sin(a)>0 ? z+2 : z-1
            s.zoom_x=s.zoom_y=0.20+i%3*0.09
            s.opacity=(fade*Math.sin(gather*Math::PI)*(berry ? 105 : 220)).round
          end
          sparks.each_with_index do |s,i|
            a=i*Math::PI*2/14
            r=5+burst*radius*1.1
            s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.76-burst*12
            s.zoom_x=s.zoom_y=0.16+i%3*0.07
            s.angle=t*65+i*19
            s.opacity=(fade*Math.sin(burst*Math::PI)*225).round
          end
          dashes.each_with_index do |s,i|
            a=i*Math::PI*2/10
            r=radius*(0.90-gather*0.70)+burst*radius*0.5
            s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.80
            s.angle=90-a*180/Math::PI
            s.zoom_x,s.zoom_y=0.50,0.23+i%3*0.07
            s.opacity=(fade*Math.sin((gather+burst)*Math::PI/2)*(berry ? 55 : 185)).round
          end
          rings.each_with_index do |s,i|
            p=[[(t-i*0.14)/0.70,0].max,1].min
            size=radius/39.0*(0.55+p*0.75)
            s.x,s.y=cx,foot-3-p*height*0.16
            s.zoom_x,s.zoom_y=size,size*0.22
            s.opacity=(fade*Math.sin(p*Math::PI)*(berry ? 85 : 175)).round
          end
          crumbs.each_with_index do |s,i|
            trigger=i<8 ? 0.30 : 0.49
            p=[[(t-trigger)/0.25,0].max,1].min
            a=i*2.399
            s.x=cx+direction*radius*0.54+Math.cos(a)*p*18
            s.y=cy+Math.sin(a)*p*12+p*p*16
            s.zoom_x=s.zoom_y=0.22+i%3*0.07
            s.angle=i*31+p*130
            s.opacity=(Math.sin(p*Math::PI)*(1-p)*250).round
          end
          pbUpdate
        end
      ensure
        begin
          pbAnimateSubstitute(sub_index,:show) if substitute
        ensure
          boxes=@berry_item_visual_boxes;@berry_item_visual_boxes=nil
          boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
          sprites.reverse_each { |s|s.dispose unless s.disposed? }
          bitmaps.each { |b|b.dispose unless b.disposed? }
        end
      end
    end
  end
end
Battle::Scene.prepend(BerryItemVisual::SceneHooks)

#===============================================================================
# Berry / Item presentation upgrade
# Append to the END of the existing Gen_Berry_Item.rb.
# Uses the existing hooks and drawing helpers.
#===============================================================================
module BerryItemVisual
  module SceneHooks
    def pbBerryItemVisual(source, berry, battler = nil, sub_index = nil)
      sprites, bitmaps = [], []
      substitute = false
      @berry_item_visual_boxes = {}

      begin
        @briefMessage = false
        pbBerryItemVisualHideHP

        if !sub_index.nil? && respond_to?(:pbAnimateSubstitute, true)
          substitute = true
          pbAnimateSubstitute(sub_index, :hide)
          source = @sprites["pokemon_#{sub_index}"]
        end

        return unless source && !source.disposed? && source.bitmap

        bitmaps.concat(BerryItemVisual.assets(berry, battler))
        orb_b, spark_b, dash_b, ring_b, crumb_b = bitmaps[0, 5]

        scale = [Graphics.width / 512.0,
                 Graphics.height / 384.0].min

        make = proc do |bitmap, ox, oy, z, blend|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap, s.ox, s.oy = bitmap, ox, oy
          s.z, s.blend_type = z, blend
          s.opacity = 0
          s
        end

        cx = source.x +
             (source.src_rect.width / 2.0 - source.ox) * source.zoom_x
        foot = source.y +
               (source.src_rect.height - source.oy) * source.zoom_y

        height = [[source.src_rect.height * source.zoom_y,
                   72 * scale].max, 190 * scale].min
        radius = [[source.src_rect.width * source.zoom_x * 0.45,
                   35 * scale].max, 80 * scale].min
        cy = foot - height * 0.53
        z = source.z
        direction = battler && battler.index.odd? ? -1 : 1

        # Only the duplicate glows. The real Pokemon is never recolored.
        glow_b = source.bitmap.clone
        bitmaps << glow_b
        glow = make.call(glow_b, source.ox, source.oy, z + 1, 1)
        glow.src_rect.set(
          source.src_rect.x, source.src_rect.y,
          source.src_rect.width, source.src_rect.height
        )
        glow.x, glow.y = source.x, source.y
        glow.zoom_x, glow.zoom_y = source.zoom_x, source.zoom_y
        glow.mirror = source.mirror
        glow.angle = source.angle
        glow.color = berry ?
          Color.new(255, 206, 99, 220) :
          Color.new(111, 229, 255, 225)

        fruit = nil
        badge = nil
        beam = nil

        if berry
          fruit = make.call(
            bitmaps[5], bitmaps[5].width / 2,
            bitmaps[5].height / 2, z + 12, 0
          )
        else
          # An abstract activation seal, rather than a healing symbol.
          badge_b = Bitmap.new(80, 80)
          bitmaps << badge_b
          gold = Color.new(255, 202, 76, 245)
          pale = Color.new(255, 246, 195, 255)

          [[40, 5], [75, 40], [40, 75], [5, 40]].each_with_index do |p, i|
            q = [[40, 5], [75, 40], [40, 75], [5, 40]][(i + 1) % 4]
            BerryItemVisual.line(badge_b, p[0], p[1], q[0], q[1], 3, gold)
          end

          [[40, 20], [60, 40], [40, 60], [20, 40]].each_with_index do |p, i|
            q = [[40, 20], [60, 40], [40, 60], [20, 40]][(i + 1) % 4]
            BerryItemVisual.line(badge_b, p[0], p[1], q[0], q[1], 2, pale)
          end

          BerryItemVisual.disc(badge_b, 40, 40, 6, pale)
          badge = make.call(badge_b, 40, 40, z + 12, 1)

          # Soft vertical energy column.
          beam_b = Bitmap.new(64, 160)
          bitmaps << beam_b
          64.times do |x|
            horizontal = 1.0 - ((x - 31.5) / 32.0).abs
            40.times do |row|
              y = row * 4
              vertical = Math.sin((y + 2) / 160.0 * Math::PI)
              alpha = (horizontal ** 1.5 * vertical * 155).round
              beam_b.fill_rect(x, y, 1, 4,
                               Color.new(102, 219, 255, alpha))
            end
          end

          beam = make.call(beam_b, 32, 160, z + 2, 1)
          beam.x, beam.y = cx, foot + 5 * scale
          beam.zoom_x = radius * 2.3 / 64.0
          beam.zoom_y = height * 1.55 / 160.0
        end

        rings = Array.new(berry ? 2 : 3) do
          s = make.call(ring_b, 48, 48, z + 4, 1)
          s.color = berry ?
            Color.new(255, 195, 75, 190) :
            Color.new(112, 230, 255, 235)
          s
        end

        sparks = Array.new(berry ? 16 : 28) do
          s = make.call(spark_b, 8, 8, z + 10, 1)
          s.color = berry ?
            Color.new(255, 210, 110, 160) :
            Color.new(126, 232, 255, 245)
          s
        end

        crumbs = berry ? Array.new(24) do
          make.call(crumb_b, 4, 4, z + 14, 0)
        end : []

        rays = berry ? Array.new(10) do
          s = make.call(dash_b, 4, 14, z + 13, 1)
          s.color = Color.new(255, 221, 126, 230)
          s
        end : []

        duration = berry ? 1.80 : 1.65
        frames = [(Graphics.frame_rate * duration).round, 2].max
        first_sound = false
        second_sound = false

        frames.times do |f|
          t = f.to_f / (frames - 1)
          fade = [[t / 0.10, (1 - t) / 0.17, 1.0].min, 0].max

          if berry
            # Large fruit enters, then loses two visible bites.
            arrive = [[t / 0.23, 0].max, 1].min
            arrive = 1 - (1 - arrive) ** 3
            stage = t < 0.32 ? 0 : (t < 0.52 ? 1 : 2)
            vanish = [[(t - 0.66) / 0.14, 0].max, 1].min

            fruit.bitmap = bitmaps[5 + stage]

            bite_a = Math.exp(-((t - 0.32) / 0.035) ** 2)
            bite_b = Math.exp(-((t - 0.52) / 0.035) ** 2)
            bite = bite_a + bite_b

            fruit_x = cx + direction * [radius * 0.72, 26 * scale].max
            fruit_y = cy + 5 * scale

            fruit.x = fruit_x + direction * (1 - arrive) * 40 * scale
            fruit.y = fruit_y - (1 - arrive) * 28 * scale +
                      bite * 4 * scale

            size = 1.45 * scale * (1 - vanish * 0.65)
            fruit.zoom_x = size * (1 + bite * 0.14)
            fruit.zoom_y = size * (1 - bite * 0.20)
            fruit.angle = direction * ((1 - arrive) * -25 + bite * 9)
            fruit.opacity = ((1 - vanish) * fade * 255).round

            unless first_sound
              if t >= 0.32
                BerryItemVisual.play_se(true)
                first_sound = true
              end
            end
            unless second_sound
              if t >= 0.52
                BerryItemVisual.play_se(true, true)
                second_sound = true
              end
            end

            # Distinct bursts of solid crumbs at each bite.
            crumbs.each_with_index do |s, i|
              trigger = i < 12 ? 0.32 : 0.52
              p = (t - trigger) / 0.25
              s.visible = p >= 0 && p <= 1
              next unless s.visible

              n = i % 12
              vx = (n - 5.5) * 8
              vy = -24 - n % 4 * 12

              s.x = fruit_x + vx * p * scale
              s.y = fruit_y + (vy * p + 65 * p * p) * scale
              s.zoom_x = s.zoom_y = (0.70 + n % 3 * 0.20) * scale
              s.angle = n * 31 + p * 250
              s.opacity = ((1 - p * p) * 255).round
            end

            # Short lines make both bites read immediately.
            rays.each_with_index do |s, i|
              trigger = t < 0.48 ? 0.32 : 0.52
              p = (t - trigger) / 0.10
              s.visible = p >= 0 && p <= 1
              next unless s.visible

              a = i * Math::PI * 2 / rays.length
              r = (26 + p * 25) * scale
              s.x = fruit_x + Math.cos(a) * r
              s.y = fruit_y + Math.sin(a) * r * 0.78
              s.angle = 90 - a * 180 / Math::PI
              s.zoom_x = 0.85 * scale
              s.zoom_y = (0.65 - p * 0.20) * scale
              s.opacity = ((1 - p) * 245).round
            end

            finish = [[(t - 0.64) / 0.36, 0].max, 1].min
            glow.opacity = (Math.sin(finish * Math::PI) * 62).round

            sparks.each_with_index do |s, i|
              a = i * Math::PI * 2 / sparks.length
              r = (12 + finish * (radius + 25 * scale))
              s.x = cx + Math.cos(a) * r
              s.y = cy + Math.sin(a) * r * 0.72 -
                    finish * 15 * scale
              s.zoom_x = s.zoom_y = (0.50 + i % 3 * 0.18) * scale
              s.angle = i * 20 + finish * 80
              s.opacity = (Math.sin(finish * Math::PI) * 235).round
            end

            rings.each_with_index do |s, i|
              p = (t - 0.65 - i * 0.055) / 0.29
              s.visible = p >= 0 && p <= 1
              next unless s.visible

              s.x, s.y = cx, foot
              s.zoom_x = (0.40 + p * 1.55) * radius / 39.0
              s.zoom_y = s.zoom_x * 0.25
              s.opacity = ((1 - p) * 180).round
            end
          else
            # Item activation: gold seal -> cyan column -> rising rings.
            unless first_sound
              if t >= 0.19
                BerryItemVisual.play_se(false)
                first_sound = true
              end
            end

            appear = [[t / 0.18, 0].max, 1].min
            disappear = [[(t - 0.39) / 0.19, 0].max, 1].min

            badge.x = cx
            badge.y = [cy - height * 0.28, 43 * scale].max
            badge.zoom_x = badge.zoom_y =
              (0.35 + appear * 0.65 + disappear * 0.45) * scale
            badge.angle = (1 - appear) * -50 + disappear * 22
            badge.opacity = (appear * (1 - disappear) * 255).round

            power = [[(t - 0.18) / 0.70, 0].max, 1].min
            envelope = Math.sin(power * Math::PI)

            beam.opacity = (envelope * 190).round
            beam.zoom_x = radius * (1.9 + envelope * 0.6) / 64.0
            glow.opacity = (envelope * 100).round

            rings.each_with_index do |s, i|
              p = (t - 0.18 - i * 0.115) / 0.52
              s.visible = p >= 0 && p <= 1
              next unless s.visible

              s.x = cx
              s.y = foot - p * height * 1.15
              s.zoom_x = radius / 39.0 *
                         (0.85 + Math.sin(p * Math::PI) * 0.25)
              s.zoom_y = s.zoom_x * 0.30
              s.opacity = (Math.sin(p * Math::PI) * 250).round
            end

            sparks.each_with_index do |s, i|
              start = 0.18 + (i % 7) * 0.045
              p = (t - start) / 0.48
              s.visible = p >= 0 && p <= 1
              next unless s.visible

              a = i * 2.399 + p * 3.4
              r = radius * (0.65 + Math.sin(p * Math::PI) * 0.35)

              s.x = cx + Math.cos(a) * r
              s.y = foot - p * height * 1.30 +
                    Math.sin(a) * 8 * scale
              s.zoom_x = s.zoom_y =
                (0.48 + i % 4 * 0.16) * scale
              s.angle = i * 19 + p * 110
              s.opacity = (Math.sin(p * Math::PI) * 250).round
            end
          end

          pbUpdate
        end
      ensure
        begin
          pbAnimateSubstitute(sub_index, :show) if substitute
        ensure
          boxes = @berry_item_visual_boxes
          @berry_item_visual_boxes = nil

          if boxes
            boxes.each_value do |s, visible|
              s.visible = visible if s && !s.disposed?
            end
          end

          sprites.reverse_each { |s| s.dispose unless s.disposed? }
          bitmaps.each { |b| b.dispose unless b.disposed? }
        end
      end
    end
  end
end

#===============================================================================
# Short HELD ITEM activation.
# Common:UseItem only. Does not override pbItemUseAnimation or EatBerry.
#===============================================================================
module KaitoHeldItemVisual
  DURATION = 0.55

  def self.disc(b, cx, cy, r, color)
    (-r..r).each do |dy|
      dx = Math.sqrt([r * r - dy * dy, 0].max).floor
      b.fill_rect(cx - dx, cy + dy, dx * 2 + 1, 1, color)
    end
  end

  def self.icon_bitmap(battler, owned)
    icon = nil
    begin
      if battler.item && defined?(ItemIconSprite)
        icon = ItemIconSprite.new(0, 0, battler.item, nil)
        icon.visible = false
        if icon.bitmap && icon.src_rect.width > 0 &&
           icon.src_rect.height > 0
          b = Bitmap.new(icon.src_rect.width, icon.src_rect.height)
          owned << b
          b.blt(0, 0, icon.bitmap, icon.src_rect)
          return b
        end
      end
    rescue StandardError
      # Missing item graphics use a small activation emblem.
    ensure
      icon.dispose if icon && !icon.disposed?
    end

    b = Bitmap.new(32, 32)
    owned << b
    13.times do |i|
      half = i <= 6 ? i : 12 - i
      b.fill_rect(16 - half, 9 + i, half * 2 + 1, 1,
                  Color.new(255, 228, 142, 255))
    end
    b
  end

  module SceneHooks
    def pbCommonAnimation(name, user = nil, target = nil)
      return super unless name.to_s.downcase == "useitem"
      return if @battle && !@battle.showAnims
      return if @kaito_held_item_playing

      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?

      source = @sprites && @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode > 0

      pbKaitoHeldItemPulse(source, battler)
    end

    def pbKaitoHeldItemPulse(source, battler)
      sprites, bitmaps = [], []
      @kaito_held_item_playing = true

      begin
        @briefMessage = false
        scale = [Graphics.width / 512.0,
                 Graphics.height / 384.0].min

        make = proc do |b, ox, oy, z, blend|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap, s.ox, s.oy = b, ox, oy
          s.z, s.blend_type = z, blend
          s.opacity = 0
          s
        end

        icon_b = KaitoHeldItemVisual.icon_bitmap(battler, bitmaps)

        ring_b = Bitmap.new(96, 96)
        bitmaps << ring_b
        240.times do |i|
          a = i * Math::PI / 120
          x = (48 + Math.cos(a) * 39).round
          y = (48 + Math.sin(a) * 39).round
          KaitoHeldItemVisual.disc(
            ring_b, x, y, 1, Color.new(255, 225, 141, 235)
          )
        end

        spark_b = Bitmap.new(16, 16)
        bitmaps << spark_b
        spark_b.fill_rect(7, 1, 2, 14, Color.new(255, 229, 158, 220))
        spark_b.fill_rect(1, 7, 14, 2, Color.new(255, 229, 158, 220))
        spark_b.fill_rect(6, 6, 4, 4, Color.new(255, 255, 232, 255))

        cx = source.x +
             (source.src_rect.width / 2.0 - source.ox) * source.zoom_x
        cy = source.y +
             (source.src_rect.height / 2.0 - source.oy) * source.zoom_y

        radius = [[source.src_rect.width * source.zoom_x * 0.40,
                   28 * scale].max, 65 * scale].min
        direction = battler.index.even? ? 1 : -1

        # The actual held item appears beside the Pokemon.
        ix = cx + direction * (radius * 0.75 + 12 * scale)
        iy = cy - 12 * scale

        icon = make.call(
          icon_b, icon_b.width / 2, icon_b.height / 2, source.z + 20, 0
        )
        rings = Array.new(2) do
          make.call(ring_b, 48, 48, source.z + 18, 1)
        end
        sparks = Array.new(10) do
          make.call(spark_b, 8, 8, source.z + 21, 1)
        end

        # Optional existing activation sound.
        ["UseItem", "PRSFX- Stockpile"].each do |name|
          exists = [".ogg", ".wav", ".mp3"].any? do |ext|
            File.file?("Audio/SE/Anim/#{name}#{ext}")
          end
          next unless exists
          pbSEPlay("Anim/#{name}", 45, 120)
          break
        end

        frames = [(Graphics.frame_rate *
                   KaitoHeldItemVisual::DURATION).round, 2].max

        frames.times do |f|
          t = f.to_f / (frames - 1)
          appear = [[t / 0.18, 0].max, 1].min
          disappear = [[(t - 0.62) / 0.38, 0].max, 1].min
          pop = Math.sin(appear * Math::PI) * 0.18
          base_size = 58.0 / [icon_b.width, icon_b.height].max * scale

          icon.x = ix
          icon.y = iy - Math.sin(t * Math::PI) * 7 * scale
          icon.zoom_x = icon.zoom_y =
            base_size * (0.75 + appear * 0.25 + pop)
          icon.opacity = (appear * (1 - disappear) * 255).round

          # A brief white glint passes over the item.
          glint = Math.exp(-((t - 0.24) / 0.075) ** 2)
          icon.color = Color.new(255, 255, 222, (glint * 200).round)

          rings.each_with_index do |s, i|
            p = (t - 0.12 - i * 0.12) / 0.66
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            s.x, s.y = ix, icon.y
            s.zoom_x = s.zoom_y = (0.22 + p * 0.75) * scale
            s.opacity = (Math.sin(p * Math::PI) *
                         (i == 0 ? 210 : 140)).round
          end

          sparks.each_with_index do |s, i|
            p = (t - 0.18) / 0.76
            s.visible = p >= 0 && p <= 1
            next unless s.visible

            a = i * Math::PI * 2 / sparks.length
            r = (13 + p * 37) * scale
            s.x = ix + Math.cos(a) * r
            s.y = iy + Math.sin(a) * r * 0.82 - p * 8 * scale
            s.zoom_x = s.zoom_y =
              (0.38 + i % 3 * 0.13) * scale * (1 - p * 0.35)
            s.angle = i * 23 + p * 55
            s.opacity = (Math.sin(p * Math::PI) * 235).round
          end

          pbUpdate
        end
      ensure
        @kaito_held_item_playing = false
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end

unless Battle::Scene.ancestors.include?(KaitoHeldItemVisual::SceneHooks)
  Battle::Scene.prepend(KaitoHeldItemVisual::SceneHooks)
end