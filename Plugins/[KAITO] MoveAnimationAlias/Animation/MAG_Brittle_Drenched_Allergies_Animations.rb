# MAG Brittle / Drenched / Allergies animations - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:Brittle, Common:Drenched and Common:Allergies.
# No graphics/audio imports or stat/HP calculation hooks are required.
module MAGBrittleDrenchedAllergiesVisual
  VERSION = "1.0"
  DURATIONS = { :brittle=>0.96, :drenched=>1.00, :allergies=>1.04 }
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
  def self.line(b,x0,y0,x1,y1,width,color)
    n = [(x1-x0).abs,(y1-y0).abs,1].max
    (0..n).each do |i|
      x = (x0+(x1-x0)*i.to_f/n).round
      y = (y0+(y1-y0)*i.to_f/n).round
      b.fill_rect(x-width/2,y-width/2,width,width,color)
    end
  end
  def self.assets(kind)
    if kind==:brittle
      crack = Bitmap.new(64,64)
      segments = [[31,5,26,21],[26,21,35,31],[35,31,29,44],[29,44,34,59],
        [26,21,13,17],[13,17,6,23],[35,31,48,23],[48,23,57,27],
        [29,44,15,48],[15,48,11,57],[35,31,43,44],[43,44,54,47]]
      [[4,Color.new(89,83,110,195)],[2,Color.new(216,212,237,250)]].each do |w,c|
        segments.each { |seg| line(crack,*seg,w,c) }
      end
      chip = Bitmap.new(26,32)
      polygon(chip,[[4,4],[17,2],[22,12],[17,17],[22,26],[10,30],[3,20],[9,14]],Color.new(109,111,137,245))
      polygon(chip,[[6,6],[16,5],[18,12],[13,18],[17,24],[10,26],[6,20],[11,13]],Color.new(195,201,224,250))
      polygon(chip,[[6,6],[16,5],[11,13],[6,20]],Color.new(244,242,255,255))
      glint = Bitmap.new(20,20)
      glint.fill_rect(9,2,2,16,Color.new(215,218,247,190))
      glint.fill_rect(2,9,16,2,Color.new(215,218,247,190))
      glint.fill_rect(8,8,4,4,Color.new(255,252,255,255))
      [crack,chip,glint]
    elsif kind==:drenched
      drop = Bitmap.new(26,38)
      polygon(drop,[[13,1],[22,18],[23,27],[19,33],[12,36],[5,32],[2,25],[5,17]],Color.new(70,149,199,210))
      polygon(drop,[[13,5],[19,19],[20,26],[17,31],[11,33],[6,29],[5,24],[8,17]],Color.new(137,216,246,240))
      polygon(drop,[[11,13],[8,23],[8,28],[11,30],[11,23],[14,17]],Color.new(237,254,255,245))
      ring = Bitmap.new(128,128)
      360.times do |i|
        a = i*Math::PI/180
        [[50,Color.new(103,188,230,165)],[52,Color.new(208,248,255,235)]].each do |r,c|
          ring.fill_rect((64+Math.cos(a)*r).round,(64+Math.sin(a)*r).round,2,2,c)
        end
      end
      stream = Bitmap.new(12,64)
      64.times do |y|
        v = Math.sin(y/63.0*Math::PI)
        stream.fill_rect(3,y,6,1,Color.new(106,195,235,(v*95).round))
        stream.fill_rect(5,y,2,1,Color.new(222,252,255,(v*220).round))
      end
      bead = Bitmap.new(18,18)
      disc(bead,9,9,6,Color.new(98,184,226,180))
      disc(bead,8,8,4,Color.new(185,242,255,240))
      bead.fill_rect(6,5,2,3,Color.new(253,255,255,255))
      [drop,ring,stream,bead]
    else
      pollen = Bitmap.new(28,28)
      [[9,9],[19,10],[8,18],[18,19]].each { |x,y| disc(pollen,x,y,6,Color.new(190,185,102,180)) }
      [[10,10],[18,11],[9,17],[17,18]].each { |x,y| disc(pollen,x,y,4,Color.new(246,224,137,235)) }
      disc(pollen,14,14,5,Color.new(255,248,188,250))
      pollen.fill_rect(11,11,3,3,Color.new(255,255,225,255))
      cloud = Bitmap.new(48,48)
      [[21,10],[15,20],[8,29]].each { |r,a| disc(cloud,24,24,r,Color.new(232,227,167,a)) }
      gust = Bitmap.new(64,40)
      180.times do |i|
        a = (i-90)*Math::PI/180
        x,y = (20+Math.cos(a)*27).round,(20+Math.sin(a)*15).round
        gust.fill_rect(x,y,2,2,Color.new(238,244,205,200))
      end
      gust.fill_rect(3,7,20,2,Color.new(205,217,155,150))
      gust.fill_rect(7,31,18,2,Color.new(205,217,155,150))
      grain = Bitmap.new(14,18)
      polygon(grain,[[7,1],[12,8],[7,16],[2,9]],Color.new(153,178,104,225))
      polygon(grain,[[7,3],[9,9],[7,13],[5,9]],Color.new(229,231,159,245))
      [pollen,cloud,gust,grain]
    end
  end
  def self.play_se(kind)
    names = case kind
            when :brittle then ["PRSFX- Mirror Shatter","PRSFX- Spike Cannon"]
            when :drenched then ["PRSFX- Soak","PRSFX- Water Sport","PRSFX- Splash"]
            else ["PRSFX- Cotton Spore","PRSFX- Stun Spore","PRSFX- Sweet Scent"]
            end
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",70,kind==:allergies ? 110 : 100)
      break
    end
  end
  def self.kind(name)
    case name.to_s.downcase
    when "brittle" then :brittle
    when "drenched" then :drenched
    when "allergies" then :allergies
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if MAGBrittleDrenchedAllergiesVisual.kind(name)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      kind = MAGBrittleDrenchedAllergiesVisual.kind(name)
      return super unless kind
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @mag_brittle_drenched_allergies_boxes
      pbMAGBrittleDrenchedAllergiesVisual(source,kind)
    end
    def pbMAGBrittleDrenchedAllergiesVisualHideHP
      return unless @mag_brittle_drenched_allergies_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @mag_brittle_drenched_allergies_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbMAGBrittleDrenchedAllergiesVisualHideHP if @mag_brittle_drenched_allergies_boxes
      super
    end
    def pbMAGBrittleDrenchedAllergiesVisual(source,kind)
      sprites,bitmaps = [],[]
      @mag_brittle_drenched_allergies_boxes = {}
      begin
        @briefMessage = false
        pbMAGBrittleDrenchedAllergiesVisualHideHP
        MAGBrittleDrenchedAllergiesVisual.play_se(kind)
        bitmaps.concat(MAGBrittleDrenchedAllergiesVisual.assets(kind))
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
                     when :brittle then Color.new(204,204,233,220)
                     when :drenched then Color.new(135,217,246,205)
                     else Color.new(234,226,160,185)
                     end
        if kind==:brittle
          cracks = Array.new(5) { make.call(bitmaps[0],32,32,z+3,0) }
          chips = Array.new(18) { make.call(bitmaps[1],13,16,z+4,0) }
          glints = Array.new(12) { make.call(bitmaps[2],10,10,z+4,1) }
        elsif kind==:drenched
          drops = Array.new(8) { make.call(bitmaps[0],13,19,z+3,0) }
          rings = Array.new(3) { make.call(bitmaps[1],64,64,z-1,0) }
          streams = Array.new(7) { make.call(bitmaps[2],6,32,z+2,0) }
          beads = Array.new(18) { make.call(bitmaps[3],9,9,z+4,0) }
        else
          pollen = Array.new(18) { make.call(bitmaps[0],14,14,z+3,0) }
          clouds = Array.new(6) { make.call(bitmaps[1],24,24,z-1,0) }
          gusts = Array.new(3) { make.call(bitmaps[2],32,20,z+4,0) }
          grains = Array.new(14) { make.call(bitmaps[3],7,9,z+4,0) }
        end
        frames = [(Graphics.frame_rate*MAGBrittleDrenchedAllergiesVisual::DURATIONS[kind]).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.10,(1-t)/0.20,1.0].min
          head = foot-height*0.88
          if kind==:brittle
            fracture = [1-(t-0.35).abs/0.25,0].max
            aura.opacity = (fade*(18+50*fracture)).round
            cracks.each_with_index do |s,i|
              a = i*2.399
              grow = [[(t-i*0.035)/0.22,0].max,1].min
              s.x = cx+Math.cos(a)*radius*0.50
              s.y = foot-height*(0.24+(i%3)*0.23)+Math.sin(a)*4
              s.zoom_x = s.zoom_y = 0.42+grow*0.16
              s.angle = i*47
              s.opacity = (fade*grow*(1-[t-0.56,0].max*1.7)*225).round
            end
            chips.each_with_index do |s,i|
              p = [[(t-0.25-(i%4)*0.035)/0.65,0].max,1].min
              a = i*2.399
              s.x = cx+Math.cos(a)*radius*(0.42+p*0.82)
              s.y = foot-height*0.53+Math.sin(a)*height*0.30-Math.sin(p*Math::PI)*8+p*p*36
              s.zoom_x = s.zoom_y = 0.30+i%3*0.09
              s.angle = i*27+t*(i%2==0 ? 175 : -175)
              s.z = Math.sin(a)>0 ? z+4 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)*245).round
            end
            glints.each_with_index do |s,i|
              a = i*2.399
              s.x = cx+Math.cos(a)*radius*0.72
              s.y = foot-height*0.50+Math.sin(a)*height*0.40
              s.zoom_x = s.zoom_y = 0.17+i%3*0.06
              s.angle = i*21+t*40
              s.opacity = (fade*fracture*230).round
            end
          elsif kind==:drenched
            aura.opacity = (fade*(36+18*Math.sin(t*Math::PI))).round
            drops.each_with_index do |s,i|
              p = [[(t-(i%4)*0.05)/0.76,0].max,1].min
              a = i*2.399
              s.x = cx+Math.cos(a)*radius*0.78+Math.sin(p*4+i)*3
              s.y = head+10+p*p*(height*0.87+10)+Math.sin(a)*10
              s.zoom_x = (0.42+i%3*0.10)*(1-0.10*p)
              s.zoom_y = 0.46+i%3*0.11+p*0.10
              s.z = Math.sin(a)>0 ? z+3 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)**0.4*240).round
            end
            streams.each_with_index do |s,i|
              s.x = cx+(i-3)*radius*0.25+Math.sin(t*5+i)*2
              s.y = foot-height*0.58+t*height*0.26
              s.zoom_x = 0.38+i%2*0.12
              s.zoom_y = height/128.0*(0.7+Math.sin(t*6+i)*0.10)
              s.z = i%3==0 ? z-1 : z+2
              s.opacity = (fade*(145+i%2*25)).round
            end
            rings.each_with_index do |s,i|
              p = [[(t-0.20-i*0.15)/0.52,0].max,1].min
              scale = radius/51.0*(0.25+p*1.0)
              s.x,s.y = cx,foot-1
              s.zoom_x,s.zoom_y = scale,scale*0.22
              s.opacity = (fade*Math.sin(p*Math::PI)*220).round
            end
            beads.each_with_index do |s,i|
              p = [[(t-0.34-(i%3)*0.07)/0.52,0].max,1].min
              a = i*2.399
              s.x = cx+Math.cos(a)*radius*(0.35+p*0.8)
              s.y = foot-2-Math.sin(p*Math::PI)*(10+i%3*4)+Math.sin(a)*4
              s.zoom_x = s.zoom_y = 0.25+i%3*0.085
              s.opacity = (fade*Math.sin(p*Math::PI)*240).round
            end
          else
            sneeze = [[(t-0.50)/0.38,0].max,1].min
            side = cx<Graphics.width/2 ? 1 : -1
            aura.opacity = (fade*(16+26*Math.sin(t*Math::PI))).round
            pollen.each_with_index do |s,i|
              p = [[(t-(i%5)*0.025)/0.83,0].max,1].min
              a = i*2.399+t*2.8
              s.x = cx+Math.cos(a)*radius*(0.76+sneeze*0.45)+side*sneeze*14
              s.y = head+16+Math.sin(a)*height*0.34-Math.sin(p*Math::PI)*8
              s.zoom_x = s.zoom_y = 0.26+i%4*0.08
              s.angle = t*110+i*29
              s.z = Math.sin(a)>0 ? z+3 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)*230).round
            end
            clouds.each_with_index do |s,i|
              a = i*2.399+t*0.8
              s.x = cx+Math.cos(a)*radius*0.7+side*sneeze*10
              s.y = head+14+Math.sin(a)*18
              s.zoom_x,s.zoom_y = 0.8+t*0.35,0.42+t*0.15
              s.opacity = (fade*155).round
            end
            gusts.each_with_index do |s,i|
              p = [[(t-0.49-i*0.035)/0.33,0].max,1].min
              s.x = cx+side*(radius*0.35+p*(radius*0.8+18))
              s.y = head+18+(i-1)*7-p*4
              s.zoom_x = 0.40+p*0.3
              s.zoom_y = 0.34+p*0.15
              s.mirror = side<0
              s.angle = (i-1)*side*10
              s.opacity = (fade*Math.sin(p*Math::PI)*235).round
            end
            grains.each_with_index do |s,i|
              a = i*2.399
              s.x = cx+side*(radius*0.3+sneeze*(radius+22))+Math.cos(a)*sneeze*15
              s.y = head+18+Math.sin(a)*sneeze*25
              s.zoom_x = s.zoom_y = 0.28+i%3*0.10
              s.angle = i*23+sneeze*150
              s.opacity = (fade*Math.sin(sneeze*Math::PI)*240).round
            end
          end
          pbUpdate
        end
      ensure
        boxes = @mag_brittle_drenched_allergies_boxes
        @mag_brittle_drenched_allergies_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(MAGBrittleDrenchedAllergiesVisual::SceneHooks)
