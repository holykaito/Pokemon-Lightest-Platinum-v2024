# MAG Fatigue / Winded / Vertigo animations - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:Fatigue, Common:Winded and Common:Vertigo.
# No graphics/audio imports or stat/HP calculation hooks are required.
module MAGStatusVisual
  VERSION = "1.0"
  DURATIONS = { :fatigue=>0.92, :winded=>0.96, :vertigo=>1.04 }
  def self.disc(b,cx,cy,r,color)
    (-r..r).each do |dy|
      dx = Math.sqrt(r*r-dy*dy).floor
      b.fill_rect(cx-dx,cy+dy,dx*2+1,1,color)
    end
  end
  def self.polygon(b,points,color)
    low,high = points.map { |p| p[1] }.minmax
    (low..high).each do |y|
      xs = []
      points.each_with_index do |p,i|
        q = points[(i+1)%points.length]
        next unless (p[1]<=y && q[1]>y) || (q[1]<=y && p[1]>y)
        xs << p[0]+(y-p[1]).to_f*(q[0]-p[0])/(q[1]-p[1])
      end
      xs.sort.each_slice(2) { |l,r| b.fill_rect(l.ceil,y,[r.floor-l.ceil+1,1].max,1,color) if r }
    end
  end
  def self.assets(kind)
    colors = case kind
             when :fatigue then [[181,113,100],[237,171,138],[255,231,194]]
             when :winded then [[129,166,185],[191,223,234],[242,252,255]]
             else [[180,140,92],[236,204,142],[255,246,211]]
             end
    dark,light,white = colors
    drop = Bitmap.new(24,36)
    polygon(drop,[[12,2],[20,20],[19,29],[12,33],[5,29],[4,20]],Color.new(*dark,220))
    polygon(drop,[[12,7],[17,21],[16,27],[11,29],[7,25],[7,20]],Color.new(*light,250))
    drop.fill_rect(8,19,2,7,Color.new(*white,250))
    chip = Bitmap.new(20,28)
    polygon(chip,[[10,2],[17,9],[14,15],[16,20],[8,26],[3,18],[6,13],[4,8]],Color.new(*dark,215))
    polygon(chip,[[10,5],[14,10],[11,15],[12,20],[8,23],[6,18],[9,13],[7,9]],Color.new(*light,245))
    chip.fill_rect(9,8,2,5,Color.new(*white,245))
    ring = Bitmap.new(128,128)
    360.times do |i|
      next if kind!=:winded && i%45>27
      a = i*Math::PI/180
      ring.fill_rect((64+Math.cos(a)*51).round,(64+Math.sin(a)*51).round,2,2,Color.new(*light,180))
      if kind==:winded && i%90<45
        ring.fill_rect((64+Math.cos(a)*44).round,(64+Math.sin(a)*44).round,2,2,Color.new(*white,175))
      end
    end
    trail = Bitmap.new(14,48)
    48.times do |y|
      v = Math.sin(y/47.0*Math::PI)
      width = [1,(v*5).round].max
      trail.fill_rect(7-width,y,width*2,1,Color.new(*dark,(v*65).round))
      trail.fill_rect(6,y,2,1,Color.new(*light,(v*190).round))
    end
    spiral = Bitmap.new(96,96)
    720.times do |i|
      u = i/719.0
      a = u*Math::PI*3.8
      r = 5+u*36
      x,y = (48+Math.cos(a)*r).round,(48+Math.sin(a)*r).round
      spiral.fill_rect(x-1,y-1,3,3,Color.new(*dark,145))
      spiral.fill_rect(x,y,2,2,Color.new(*white,235))
    end
    puff = Bitmap.new(40,40)
    [[17,12],[12,22],[7,32]].each { |r,a| disc(puff,20,20,r,Color.new(*light,a)) }
    [drop,chip,ring,trail,spiral,puff]
  end
  def self.play_se(kind)
    names = case kind
            when :fatigue then ["PRSFX- Leer","PRSFX- Tickle"]
            when :winded then ["PRSFX- Wind","Wind1","PRSFX- Whirlwind"]
            else ["PRSFX- Dizzy Punch1","Confuse","PRSFX- Confused"]
            end
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",kind==:winded ? 65 : 70,kind==:fatigue ? 85 : 100)
      break
    end
  end
  def self.kind(name)
    case name.to_s.downcase
    when "fatigue" then :fatigue
    when "winded" then :winded
    when "vertigo" then :vertigo
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if MAGStatusVisual.kind(name)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      kind = MAGStatusVisual.kind(name)
      return super unless kind
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @mag_status_visual_boxes
      pbMAGStatusVisual(source,kind)
    end
    def pbMAGStatusVisualHideHP
      return unless @mag_status_visual_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @mag_status_visual_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbMAGStatusVisualHideHP if @mag_status_visual_boxes
      super
    end
    def pbMAGStatusVisual(source,kind)
      sprites,bitmaps = [],[]
      @mag_status_visual_boxes = {}
      begin
        @briefMessage = false
        pbMAGStatusVisualHideHP
        MAGStatusVisual.play_se(kind)
        bitmaps.concat(MAGStatusVisual.assets(kind))
        make = proc do |b,ox,oy,z,blend|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap,s.ox,s.oy,s.z,s.blend_type = b,ox,oy,z,blend
          s
        end
        cx = source.x+(source.src_rect.width/2.0-source.ox)*source.zoom_x
        foot = source.y+(source.src_rect.height-source.oy)*source.zoom_y
        height = [[source.src_rect.height*source.zoom_y,60].max,180].min
        radius = [[source.src_rect.width*source.zoom_x*0.46,29].max,68].min
        z = source.z
        aura_b = source.bitmap.clone
        bitmaps << aura_b
        aura = make.call(aura_b,source.ox,source.oy,z+1,1)
        aura.src_rect.set(source.src_rect.x,source.src_rect.y,source.src_rect.width,source.src_rect.height)
        aura.x,aura.y = source.x,source.y
        aura.zoom_x,aura.zoom_y,aura.mirror = source.zoom_x,source.zoom_y,source.mirror
        aura.color = case kind
                     when :fatigue then Color.new(238,173,145,185)
                     when :winded then Color.new(186,223,240,180)
                     else Color.new(243,216,162,180)
                     end
        if kind==:fatigue
          drops = Array.new(3) { make.call(bitmaps[0],12,18,z+3,0) }
          chips = Array.new(18) { make.call(bitmaps[1],10,14,z+3,0) }
          rings = Array.new(3) { make.call(bitmaps[2],64,64,z-1,0) }
          trails = Array.new(10) { make.call(bitmaps[3],7,24,z+2,0) }
        elsif kind==:winded
          rings = Array.new(3) { make.call(bitmaps[2],64,64,z+3,0) }
          gusts = Array.new(14) { make.call(bitmaps[3],7,24,z+2,0) }
          puffs = Array.new(6) { make.call(bitmaps[5],20,20,z+2,0) }
          drop = make.call(bitmaps[0],12,18,z+4,0)
        else
          spirals = Array.new(3) { make.call(bitmaps[4],48,48,z+3,0) }
          chips = Array.new(7) { make.call(bitmaps[1],10,14,z+4,0) }
          floor = make.call(bitmaps[2],64,64,z-1,0)
        end
        frames = [(Graphics.frame_rate*MAGStatusVisual::DURATIONS[kind]).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.12,(1-t)/0.20,1.0].min
          head = foot-height*0.88
          if kind==:fatigue
            aura.opacity = (fade*(18+18*Math.sin(t*Math::PI))).round
            drops.each_with_index do |s,i|
              p = [[(t-i*0.12)/0.66,0].max,1].min
              s.x = cx+radius*(i==0 ? 0.65 : -0.55)+Math.sin(t*5+i)*3
              s.y = head+10+p*(18+i*8)
              s.zoom_x = s.zoom_y = 0.34+i*0.025
              s.opacity = (fade*Math.sin(p*Math::PI)*235).round
            end
            chips.each_with_index do |s,i|
              p = [[(t-(i%6)*0.035)/0.72,0].max,1].min
              a = i*2.399+t*0.7
              s.x = cx+Math.cos(a)*radius*(0.9-p*0.45)
              s.y = foot-height*0.75+p*(height*0.75+10)+Math.sin(a)*8
              s.zoom_x = 0.32+i%3*0.09
              s.zoom_y = 0.36+i%3*0.10
              s.angle = Math.sin(a)*25+t*12
              s.z = Math.sin(a)>0 ? z+3 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)*240).round
            end
            rings.each_with_index do |s,i|
              p = [[(t-i*0.10)/0.70,0].max,1].min
              s.x = cx
              s.y = foot-height*0.68+p*height*0.68
              scale = radius/51.0*(1.05-p*0.60)
              s.zoom_x,s.zoom_y = scale,scale*0.21
              s.opacity = (fade*Math.sin(p*Math::PI)*190).round
            end
            trails.each_with_index do |s,i|
              p = (t*0.8+i*0.11)%1.0
              a = i*2.399
              s.x = cx+Math.cos(a)*radius*0.76
              s.y = foot-height+p*height
              s.zoom_x,s.zoom_y = 0.36,0.48
              s.angle = Math.cos(a)*12
              s.opacity = (fade*Math.sin(p*Math::PI)*165).round
            end
          elsif kind==:winded
            breath = [0.16,0.43,0.70].map { |at| [1-(t-at).abs/0.13,0].max }.max
            aura.opacity = (fade*(12+25*breath)).round
            rings.each_with_index do |s,i|
              p = [[(t-i*0.23)/0.40,0].max,1].min
              side = i%2==0 ? 1 : -1
              s.x = cx+side*(radius*0.25+p*(radius*0.65+14))
              s.y = foot-height*0.58-p*8
              scale = radius/51.0*(0.18+p*0.60)
              s.zoom_x,s.zoom_y = scale*0.45,scale*0.70
              s.angle = side*10
              s.opacity = (fade*Math.sin(p*Math::PI)*240).round
            end
            gusts.each_with_index do |s,i|
              p = [[(t-(i%3)*0.22)/0.38,0].max,1].min
              side = i%2==0 ? 1 : -1
              a = i*2.399
              s.x = cx+side*(radius*0.25+p*(radius*0.9+20))
              s.y = foot-height*0.55+Math.sin(a)*16-Math.sin(p*Math::PI)*7
              s.zoom_x,s.zoom_y = 0.36,0.32+p*0.36
              s.angle = side*(65+Math.sin(a)*15)
              s.z = i%3==0 ? z-1 : z+2
              s.opacity = (fade*Math.sin(p*Math::PI)*210).round
            end
            puffs.each_with_index do |s,i|
              p = [[(t-(i%3)*0.22)/0.42,0].max,1].min
              side = i%2==0 ? 1 : -1
              s.x = cx+side*(radius*0.28+p*radius*0.8)
              s.y = foot-height*0.56-p*10
              s.zoom_x,s.zoom_y = 0.45+p*0.8,0.30+p*0.4
              s.opacity = (fade*Math.sin(p*Math::PI)*160).round
            end
            drop.x = cx+radius*0.58
            drop.y = head+8+t*10
            drop.zoom_x = drop.zoom_y = 0.34
            drop.opacity = (fade*Math.sin(t*Math::PI)*190).round
          else
            sway = Math.sin(t*Math::PI*3)*7
            aura.opacity = (fade*25).round
            spirals.each_with_index do |s,i|
              s.x = cx+sway*(0.65+i*0.17)
              s.y = head-4+(i-1)*10+Math.sin(t*8+i)*3
              scale = (radius/42.0)*(0.78+i*0.12)
              s.zoom_x,s.zoom_y = scale,scale*(0.22+i*0.04)
              s.angle = Math.sin(t*7+i)*(4+i*2)
              s.z = i==1 ? z+3 : z-1
              s.opacity = (fade*(205-i*25)).round
            end
            chips.each_with_index do |s,i|
              a = i*Math::PI*2/7-t*Math::PI*3.1
              s.x = cx+sway+Math.cos(a)*(radius+8)
              s.y = head+Math.sin(a)*16
              s.zoom_x = 0.26+(i%2)*0.06
              s.zoom_y = 0.26+(i%2)*0.06
              s.angle = t*130+i*35
              s.z = Math.sin(a)>0 ? z+4 : z-1
              s.opacity = (fade*235).round
            end
            floor.x,floor.y = cx+sway*0.3,foot-2
            scale = radius/51.0*(0.85+Math.sin(t*8)*0.08)
            floor.zoom_x,floor.zoom_y = scale,scale*0.23
            floor.opacity = (fade*85).round
          end
          pbUpdate
        end
      ensure
        boxes = @mag_status_visual_boxes
        @mag_status_visual_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(MAGStatusVisual::SceneHooks)
