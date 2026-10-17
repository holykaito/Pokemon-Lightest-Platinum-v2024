# Shared frozen / poison / toxic status animations - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:Frozen, Common:Poison and Common:Toxic.
# No graphics/audio imports or stat/HP calculation hooks are required.
module FrozenPoisonVisual
  VERSION = "1.1"
  DURATIONS = { :frozen=>0.94, :poison=>0.86, :toxic=>0.98 }
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
    if kind==:frozen
      crystal = Bitmap.new(36,64)
      polygon(crystal,[[18,2],[30,20],[28,50],[18,60],[6,48],[5,22]],Color.new(103,176,223,205))
      polygon(crystal,[[18,5],[18,57],[8,46],[8,23]],Color.new(186,231,251,235))
      polygon(crystal,[[18,5],[27,21],[25,48],[18,57]],Color.new(139,204,244,225))
      polygon(crystal,[[18,5],[26,21],[18,28],[8,23]],Color.new(238,254,255,245))
      polygon(crystal,[[18,28],[23,35],[18,57]],Color.new(222,246,255,210))
      crystal.fill_rect(11,24,2,18,Color.new(249,255,255,245))
      frost = Bitmap.new(24,24)
      frost.fill_rect(11,2,2,20,Color.new(208,244,255,220))
      frost.fill_rect(2,11,20,2,Color.new(208,244,255,220))
      polygon(frost,[[4,5],[6,4],[20,18],[18,20]],Color.new(172,222,254,200))
      polygon(frost,[[18,4],[20,6],[6,20],[4,18]],Color.new(172,222,254,200))
      frost.fill_rect(10,10,4,4,Color.new(255,255,255,255))
      mist = Bitmap.new(40,40)
      [[17,8],[12,14],[7,22]].each { |r,a| disc(mist,20,20,r,Color.new(179,227,249,a)) }
      [crystal,frost,mist]
    else
      dark = kind==:toxic ? [111,52,146] : [144,88,177]
      light = kind==:toxic ? [214,143,229] : [211,170,237]
      bubble = Bitmap.new(40,40)
      disc(bubble,20,20,15,Color.new(*dark,205))
      disc(bubble,20,19,12,Color.new(*light,145))
      disc(bubble,18,16,8,Color.new(*light,185))
      bubble.fill_rect(11,10,4,6,Color.new(249,225,255,235))
      bubble.fill_rect(15,9,5,2,Color.new(249,225,255,195))
      bubble.fill_rect(23,27,5,2,Color.new(*light,190))
      cloud = Bitmap.new(48,48)
      [[21,16],[16,28],[10,38]].each { |r,a| disc(cloud,24,24,r,Color.new(*dark,a)) }
      pop = Bitmap.new(24,24)
      [[10,1,3,6],[10,17,3,6],[1,10,6,3],[17,10,6,3]].each { |p| pop.fill_rect(*p,Color.new(*light,230)) }
      drop = Bitmap.new(14,20)
      polygon(drop,[[7,1],[12,11],[11,16],[7,18],[3,16],[2,11]],Color.new(*dark,225))
      polygon(drop,[[7,4],[9,12],[7,15],[4,12]],Color.new(*light,245))
      drop.fill_rect(5,10,2,3,Color.new(250,228,255,235))
      wisp = Bitmap.new(14,40)
      40.times do |y|
        v = Math.sin(y/39.0*Math::PI)
        width = [1,(v*5).round].max
        wisp.fill_rect(7-width,y,width*2,1,Color.new(*dark,(v*85).round))
        wisp.fill_rect(6,y,2,1,Color.new(*light,(v*155).round))
      end
      [bubble,cloud,pop,drop,wisp]
    end
  end
  def self.play_se(kind)
    names = case kind
            when :frozen then ["PRSFX- Frozen","PRSFX- Freeze Dry1"]
            when :toxic then ["PRSFX- Toxic1","PRSFX- Poison","Poison"]
            else ["PRSFX- Poison","Poison","PRSFX- Poison Gas"]
            end
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",70,100)
      break
    end
  end
  def self.kind(name)
    case name.to_s.downcase
    when "frozen","freeze" then :frozen
    when "poison" then :poison
    when "toxic" then :toxic
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if FrozenPoisonVisual.kind(name)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      kind = FrozenPoisonVisual.kind(name)
      return super unless kind
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @frozen_poison_visual_boxes
      pbFrozenPoisonVisual(source,kind)
    end
    def pbFrozenPoisonVisualHideHP
      return unless @frozen_poison_visual_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @frozen_poison_visual_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbFrozenPoisonVisualHideHP if @frozen_poison_visual_boxes
      super
    end
    def pbFrozenPoisonVisual(source,kind)
      sprites,bitmaps = [],[]
      @frozen_poison_visual_boxes = {}
      begin
        @briefMessage = false
        pbFrozenPoisonVisualHideHP
        FrozenPoisonVisual.play_se(kind)
        bitmaps.concat(FrozenPoisonVisual.assets(kind))
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
        aura.color = kind==:frozen ? Color.new(160,221,252,220) : Color.new(206,134,224,210)
        if kind==:frozen
          crystals = Array.new(7) { make.call(bitmaps[0],18,60,z+3,0) }
          flakes = Array.new(20) { make.call(bitmaps[1],12,12,z+4,1) }
          clouds = Array.new(5) { make.call(bitmaps[2],20,20,z-1,0) }
        else
          bubbles = Array.new(kind==:toxic ? 14 : 10) { make.call(bitmaps[0],20,20,z+3,0) }
          clouds = Array.new(kind==:toxic ? 9 : 6) { make.call(bitmaps[1],24,24,z-1,0) }
          pops = Array.new(bubbles.size) { make.call(bitmaps[2],12,12,z+4,0) }
          drops = Array.new(bubbles.size*3) { make.call(bitmaps[3],7,10,z+4,0) }
          wisps = Array.new(22) { make.call(bitmaps[4],7,20,z+2,0) }
        end
        frames = [(Graphics.frame_rate*FrozenPoisonVisual::DURATIONS[kind]).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.12,(1-t)/0.20,1.0].min
          if kind==:frozen
            form = [[t/0.28,0].max,1].min
            release = [[(t-0.68)/0.32,0].max,1].min
            aura.opacity = (fade*(30+35*Math.sin(t*Math::PI))).round
            crystals.each_with_index do |s,i|
              a = i*Math::PI*2/7
              s.x = cx+Math.cos(a)*radius*(0.7+release*0.25)
              s.y = foot-2-(i%3)*height*0.22+Math.sin(a)*7-release*12
              s.z = Math.sin(a)>0 ? z+3 : z-1
              size = (0.50+i%3*0.10)*(0.15+form*0.85)
              s.zoom_x = size*(1-release*0.25)
              s.zoom_y = size*(1-release*0.40)
              s.angle = Math.cos(a)*(7+release*28)
              s.opacity = (fade*(1-release)*215).round
            end
            flakes.each_with_index do |s,i|
              a = i*2.399+t*0.6
              r = radius*(0.45+(i%3)*0.17+release*0.45)
              s.x = cx+Math.cos(a)*r
              s.y = foot-height*0.45+Math.sin(a)*height*0.49+release*22
              s.zoom_x = s.zoom_y = 0.16+i%4*0.055
              s.angle = i*23+t*42
              s.opacity = (fade*(0.35+0.65*release)*220).round
            end
            clouds.each_with_index do |s,i|
              s.x = cx+(i-2)*radius*0.45+Math.sin(t*4+i)*5
              s.y = foot-5-t*height*0.30
              s.zoom_x,s.zoom_y = 1.1+t*0.5,0.35+t*0.2
              s.opacity = (fade*135).round
            end
          else
            aura.opacity = (fade*(kind==:toxic ? 65 : 42)*(0.75+0.25*Math.sin(t*11))).round
            bubbles.each_with_index do |s,i|
              delay = (i%5)*0.038+(i/5)*0.13
              p = [[(t-delay)/0.68,0].max,1].min
              a = i*2.399+t*2.0
              side = i%2==0 ? -1 : 1
              s.x = cx+Math.cos(a)*radius*(0.8+i%3*0.12)+Math.sin(p*7+i)*8
              s.y = foot-2-p*(height*0.93+18)+Math.sin(a)*9
              size = 0.47+i%4*0.115
              inflate = 0.75+0.38*Math.sin(p*Math::PI)
              s.zoom_x = size*inflate*(1+0.08*Math.sin(p*13+i))
              s.zoom_y = size*inflate*(1-0.10*Math.sin(p*13+i))
              s.z = Math.sin(a)>0 ? z+3 : z-1
              visible = [p/0.10,(0.83-p)/0.08,1.0].min
              s.opacity = (fade*[visible,0].max*245).round
              burst = [[(p-0.76)/0.24,0].max,1].min
              pop = pops[i]
              pop.x,pop.y,pop.z = s.x,s.y,s.z+1
              pop.zoom_x = pop.zoom_y = size*(1+burst*1.4)
              pop.opacity = (fade*Math.sin(burst*Math::PI)*170).round
              3.times do |j|
                d = drops[i*3+j]
                a2 = j*Math::PI*2/3+i*0.7
                d.x = s.x+Math.cos(a2)*burst*(15+size*13)
                d.y = s.y+Math.sin(a2)*burst*17+burst*burst*16
                d.z = s.z+1
                d.zoom_x = d.zoom_y = 0.38+size*0.24
                d.angle = -Math.cos(a2)*burst*65
                d.opacity = (fade*Math.sin(burst*Math::PI)*240).round
              end
            end
            wisps.each_with_index do |s,i|
              u = (i%11)/10.0
              a = u*Math::PI*2.3-t*3.6+(i/11)*Math::PI
              s.x = cx+Math.cos(a)*radius*(0.9+0.12*Math.sin(t*6))
              s.y = foot-u*(height+8)+Math.sin(a)*7
              s.z = Math.sin(a)>0 ? z+2 : z-1
              s.zoom_x = 0.45+0.20*Math.sin(u*Math::PI)
              s.zoom_y = 0.40+0.24*Math.sin(u*Math::PI)
              s.angle = Math.sin(a)*55
              s.opacity = (fade*Math.sin(u*Math::PI)*(kind==:toxic ? 190 : 155)).round
            end
            clouds.each_with_index do |s,i|
              p = (t*0.8+i*0.12)%1.0
              a = i*2.399-t*1.6
              s.x = cx+Math.cos(a)*radius*0.72
              s.y = foot-p*height*0.92
              s.zoom_x = 0.7+p*0.6
              s.zoom_y = 0.45+p*0.45
              s.opacity = (fade*Math.sin(p*Math::PI)*(kind==:toxic ? 205 : 165)).round
            end
          end
          pbUpdate
        end
      ensure
        boxes = @frozen_poison_visual_boxes
        @frozen_poison_visual_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(FrozenPoisonVisual::SceneHooks)
