# MAG Migraine / Opulent / Blinded / Idolize animations - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:Migraine, Common:Opulent, Common:Blinded and Common:Idolize.
# No graphics/audio imports or stat/HP calculation hooks are required.
module MAGMigraineOpulentBlindedIdolizeVisual
  VERSION = "1.0"
  DURATIONS = { :migraine=>0.94, :opulent=>1.04, :blinded=>0.96, :idolize=>1.08 }
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
  PALETTES = {
    :migraine=>[[140,79,168],[226,158,227],[255,225,251]],
    :opulent=>[[109,73,156],[195,132,223],[255,222,155]],
    :blinded=>[[49,43,76],[108,92,145],[214,200,232]],
    :idolize=>[[207,123,174],[249,187,220],[255,245,190]]
  }
  def self.assets(kind)
    dark,light,white = PALETTES[kind]
    main = Bitmap.new(48,64)
    case kind
    when :migraine
      polygon(main,[[19,4],[11,23],[25,28],[16,45],[28,43],[22,59],[38,34],[25,36],[34,19],[21,21],[28,4]],Color.new(*dark,215))
      polygon(main,[[21,9],[17,23],[29,26],[22,40],[29,38],[24,48],[33,35],[22,39],[30,23],[20,25]],Color.new(*light,250))
      polygon(main,[[21,15],[20,23],[26,26],[23,31],[27,26]],Color.new(*white,255))
    when :opulent
      polygon(main,[[24,2],[19,16],[27,23],[16,34],[23,41],[20,61],[32,42],[25,33],[34,22],[26,15]],Color.new(*dark,235))
      polygon(main,[[24,8],[22,17],[29,23],[20,34],[26,41],[23,54],[29,42],[23,33],[31,23],[24,16]],Color.new(*light,250))
      polygon(main,[[24,14],[24,20],[27,24],[23,29],[25,23]],Color.new(*white,255))
    when :blinded
      polygon(main,[[2,31],[10,22],[23,18],[36,22],[46,31],[36,40],[23,44],[10,40]],Color.new(*light,225))
      polygon(main,[[6,31],[12,25],[23,22],[34,25],[42,31],[34,37],[23,40],[12,37]],Color.new(*dark,245))
      disc(main,24,31,7,Color.new(*white,220))
      disc(main,24,31,4,Color.new(*dark,255))
      polygon(main,[[8,44],[37,14],[41,18],[12,48]],Color.new(*dark,255))
      polygon(main,[[10,43],[38,16],[39,18],[12,46]],Color.new(*white,245))
    else
      polygon(main,[[24,5],[29,24],[43,31],[29,38],[24,57],[19,38],[5,31],[19,24]],Color.new(*dark,225))
      polygon(main,[[24,10],[27,26],[38,31],[27,36],[24,51],[21,36],[10,31],[21,26]],Color.new(*light,255))
      polygon(main,[[24,16],[26,28],[33,31],[26,34],[24,45],[22,34],[15,31],[22,28]],Color.new(*white,255))
    end
    ring = Bitmap.new(128,128)
    360.times do |i|
      next if kind==:opulent && i%40>24
      a = i*Math::PI/180
      ring.fill_rect((64+Math.cos(a)*51).round,(64+Math.sin(a)*51).round,2,2,Color.new(*light,185))
    end
    mote = Bitmap.new(24,24)
    if kind==:opulent
      disc(mote,12,12,9,Color.new(*light,55))
      disc(mote,12,12,5,Color.new(*white,215))
      disc(mote,11,11,2,Color.new(255,251,224,255))
    else
      polygon(mote,[[12,1],[15,9],[23,12],[15,15],[12,23],[9,15],[1,12],[9,9]],Color.new(*light,210))
      mote.fill_rect(10,10,4,4,Color.new(*white,255))
    end
    trail = Bitmap.new(14,48)
    48.times do |y|
      v = Math.sin(y/47.0*Math::PI)
      width = [1,(v*5).round].max
      trail.fill_rect(7-width,y,width*2,1,Color.new(*dark,(v*85).round))
      trail.fill_rect(6,y,2,1,Color.new(*light,(v*195).round))
    end
    cloud = Bitmap.new(40,40)
    [[17,25],[12,40],[7,52]].each { |r,a| disc(cloud,20,20,r,Color.new(*dark,a)) }
    [main,ring,mote,trail,cloud]
  end
  def self.play_se(kind)
    names = case kind
            when :migraine then ["PRSFX- Confusion","PRSFX- Psychic"]
            when :opulent then ["PRSFX- Torment1","PRSFX- Psychic"]
            when :blinded then ["PRSFX- Embargo","PRSFX- Confide"]
            else ["PRSFX- Flatter","PRSFX- Charm"]
            end
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",70,kind==:blinded ? 90 : 100)
      break
    end
  end
  def self.kind(name)
    case name.to_s.downcase
    when "migraine" then :migraine
    when "opulent" then :opulent
    when "blinded" then :blinded
    when "idolize" then :idolize
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if MAGMigraineOpulentBlindedIdolizeVisual.kind(name)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      kind = MAGMigraineOpulentBlindedIdolizeVisual.kind(name)
      return super unless kind
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @mag_migraine_opulent_blinded_idolize_boxes
      pbMAGMigraineOpulentBlindedIdolizeVisual(source,kind)
    end
    def pbMAGMigraineOpulentBlindedIdolizeVisualHideHP
      return unless @mag_migraine_opulent_blinded_idolize_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @mag_migraine_opulent_blinded_idolize_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbMAGMigraineOpulentBlindedIdolizeVisualHideHP if @mag_migraine_opulent_blinded_idolize_boxes
      super
    end
    def pbMAGMigraineOpulentBlindedIdolizeVisual(source,kind)
      sprites,bitmaps = [],[]
      @mag_migraine_opulent_blinded_idolize_boxes = {}
      begin
        @briefMessage = false
        pbMAGMigraineOpulentBlindedIdolizeVisualHideHP
        MAGMigraineOpulentBlindedIdolizeVisual.play_se(kind)
        bitmaps.concat(MAGMigraineOpulentBlindedIdolizeVisual.assets(kind))
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
        tint = MAGMigraineOpulentBlindedIdolizeVisual::PALETTES[kind][1]
        aura.color = Color.new(*tint,205)
        if kind==:blinded
          aura.color = Color.new(51,44,77,235)
          aura.blend_type = 0
        end
        if kind==:migraine
          bolts = Array.new(4) { make.call(bitmaps[0],24,32,z+4,0) }
          rings = Array.new(3) { make.call(bitmaps[1],64,64,z+3,0) }
          motes = Array.new(12) { make.call(bitmaps[2],12,12,z+4,1) }
        elsif kind==:opulent
          fissures = Array.new(5) { make.call(bitmaps[0],24,32,z+3,0) }
          motes = Array.new(24) { make.call(bitmaps[2],12,12,z+4,1) }
          trails = Array.new(18) { make.call(bitmaps[3],7,24,z+2,0) }
        elsif kind==:blinded
          eye = make.call(bitmaps[0],24,32,z+5,0)
          rings = Array.new(2) { make.call(bitmaps[1],64,64,z+3,0) }
          clouds = Array.new(7) { make.call(bitmaps[4],20,20,z+2,0) }
          trails = Array.new(12) { make.call(bitmaps[3],7,24,z+3,0) }
        else
          stars = Array.new(2) { make.call(bitmaps[0],24,32,z+4,0) }
          motes = Array.new(18) { make.call(bitmaps[2],12,12,z+3,1) }
          halo = make.call(bitmaps[1],64,64,z-1,0)
          trails = Array.new(8) { make.call(bitmaps[3],7,24,z+2,0) }
        end
        frames = [(Graphics.frame_rate*MAGMigraineOpulentBlindedIdolizeVisual::DURATIONS[kind]).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.10,(1-t)/0.20,1.0].min
          head = foot-height*0.88
          if kind==:migraine
            pulse = [0.20,0.48,0.75].map { |at| [1-(t-at).abs/0.13,0].max }.max
            aura.opacity = (fade*(12+48*pulse)).round
            bolts.each_with_index do |s,i|
              side = i%2==0 ? -1 : 1
              s.x = cx+side*(radius*0.60+Math.sin(t*15+i)*2)
              s.y = head+8+(i/2)*16
              s.zoom_x,s.zoom_y = 0.42,0.45
              s.angle = side*(12+i*8)
              s.opacity = (fade*pulse*250).round
            end
            rings.each_with_index do |s,i|
              p = [[(t-i*0.22)/0.36,0].max,1].min
              scale = radius/51.0*(1.3-p*0.65)
              s.x,s.y = cx,head+10+Math.sin(t*12)*2
              s.zoom_x,s.zoom_y = scale,scale*0.29
              s.opacity = (fade*Math.sin(p*Math::PI)*210).round
            end
            motes.each_with_index do |s,i|
              a = i*2.399+t*2.4
              s.x = cx+Math.cos(a)*radius*0.88
              s.y = head+8+Math.sin(a)*19
              s.zoom_x = s.zoom_y = 0.14+i%3*0.07
              s.angle = i*21+t*65
              s.opacity = (fade*pulse*210).round
            end
          elsif kind==:opulent
            pulse = 0.5+0.5*Math.sin(t*10)
            aura.opacity = (fade*(18+22*pulse)).round
            fissures.each_with_index do |s,i|
              a = i*2.399
              s.x = cx+Math.cos(a)*radius*0.74
              s.y = foot-height*(0.22+(i%3)*0.23)+Math.sin(a)*5
              s.zoom_x = 0.43+0.04*Math.sin(t*12+i)
              s.zoom_y = 0.49
              s.angle = Math.cos(a)*23
              s.z = Math.sin(a)>0 ? z+3 : z-1
              s.opacity = (fade*(165+55*Math.sin(t*8+i)**2)).round
            end
            motes.each_with_index do |s,i|
              p = (t*0.84+i*0.057)%1.0
              a = i*2.399+t*0.75
              r = radius*(0.40+p*1.05)
              s.x = cx+Math.cos(a)*r
              s.y = foot-height*0.52+Math.sin(a)*height*0.33-p*17
              s.z = Math.sin(a)>0 ? z+4 : z-1
              s.zoom_x = s.zoom_y = 0.27+i%3*0.075
              s.opacity = (fade*Math.sin(p*Math::PI)*235).round
            end
            trails.each_with_index do |s,i|
              p = (t*0.74+i*0.073)%1.0
              a = i*2.399+t*0.7
              s.x = cx+Math.cos(a)*radius*(0.6+p*0.75)
              s.y = foot-height*0.50+Math.sin(a)*height*0.34-p*10
              s.zoom_x,s.zoom_y = 0.28,0.38
              s.angle = Math.cos(a)*65
              s.z = Math.sin(a)>0 ? z+2 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)*175).round
            end
          elsif kind==:blinded
            aura.opacity = (fade*60).round
            eye.x = cx+Math.sin(t*5)*3
            eye.y = head-17
            eye.zoom_x,eye.zoom_y = 0.72,0.65
            eye.opacity = (fade*245).round
            rings.each_with_index do |s,i|
              p = [[(t-i*0.12)/0.60,0].max,1].min
              s.x,s.y = cx,head+12+i*6
              scale = radius/51.0*(1.18-p*0.45)
              s.zoom_x,s.zoom_y = scale,scale*0.23
              s.opacity = (fade*Math.sin(p*Math::PI)*165).round
            end
            clouds.each_with_index do |s,i|
              a = i*2.399-t*1.4
              s.x = cx+Math.cos(a)*radius*0.66
              s.y = head+12+Math.sin(a)*12
              s.zoom_x = 0.80+0.15*Math.sin(t*6+i)
              s.zoom_y = 0.42
              s.opacity = (fade*210).round
            end
            trails.each_with_index do |s,i|
              a = i*Math::PI*2/12-t*2.1
              s.x = cx+Math.cos(a)*radius*0.92
              s.y = head+12+Math.sin(a)*17
              s.zoom_x,s.zoom_y = 0.34,0.30
              s.angle = Math.sin(a)*70
              s.z = Math.sin(a)>0 ? z+3 : z-1
              s.opacity = (fade*180).round
            end
          else
            pulse = 0.5+0.5*Math.sin(t*10-0.8)
            aura.opacity = (fade*(18+27*pulse)).round
            stars.each_with_index do |s,i|
              s.x = cx+(i==0 ? -1 : 1)*(radius*0.39+4)
              s.y = head+3+Math.sin(t*5+i)*3
              size = 0.43+0.10*(i==0 ? pulse : 1-pulse)
              s.zoom_x,s.zoom_y = size,size*0.82
              s.angle = (i==0 ? -1 : 1)*(6+Math.sin(t*5)*5)
              s.opacity = (fade*245).round
            end
            motes.each_with_index do |s,i|
              p = [[(t-(i%5)*0.035)/0.80,0].max,1].min
              a = i*2.399+t*1.0
              s.x = cx+Math.cos(a)*radius*(0.6+p*0.45)
              s.y = foot-height*0.45-p*height*0.60+Math.sin(a)*10
              s.zoom_x = s.zoom_y = 0.16+i%3*0.075
              s.angle = t*70+i*21
              s.z = Math.sin(a)>0 ? z+3 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)*235).round
            end
            halo.x,halo.y = cx,head+8
            scale = radius/51.0*(0.85+0.14*pulse)
            halo.zoom_x,halo.zoom_y = scale,scale*0.34
            halo.opacity = (fade*115).round
            trails.each_with_index do |s,i|
              a = i*Math::PI*2/8
              s.x = cx+Math.cos(a)*radius*0.92
              s.y = head+12+Math.sin(a)*20
              s.zoom_x,s.zoom_y = 0.24,0.25+0.1*pulse
              s.angle = Math.cos(a)*65
              s.opacity = (fade*(90+45*pulse)).round
            end
          end
          pbUpdate
        end
      ensure
        boxes = @mag_migraine_opulent_blinded_idolize_boxes
        @mag_migraine_opulent_blinded_idolize_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(MAGMigraineOpulentBlindedIdolizeVisual::SceneHooks)
