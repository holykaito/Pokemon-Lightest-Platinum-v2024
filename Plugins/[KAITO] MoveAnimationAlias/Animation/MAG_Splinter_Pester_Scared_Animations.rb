# MAG Splinter / Pester / Scared animations - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:Splinter, Common:Pester and Common:Scared.
# No graphics/audio imports or stat/HP calculation hooks are required.
module MAGSplinterPesterScaredVisual
  VERSION = "1.0"
  DURATIONS = { :splinter=>0.94, :pester=>1.00, :scared=>0.96 }
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
    if kind==:splinter
      shard = Bitmap.new(28,52)
      polygon(shard,[[13,2],[23,14],[18,22],[22,30],[11,49],[7,32],[3,25],[8,16]],Color.new(104,91,83,240))
      polygon(shard,[[13,6],[18,15],[14,23],[17,29],[11,43],[10,29],[6,24],[11,17]],Color.new(194,168,135,255))
      polygon(shard,[[13,6],[13,27],[11,43],[10,28],[8,23]],Color.new(235,217,181,245))
      polygon(shard,[[15,24],[18,29],[13,37]],Color.new(139,124,111,245))
      chip = Bitmap.new(18,20)
      polygon(chip,[[5,2],[14,5],[16,13],[9,18],[2,11]],Color.new(128,109,92,230))
      polygon(chip,[[5,4],[12,6],[9,13],[4,11]],Color.new(222,198,159,250))
      burst = Bitmap.new(24,24)
      polygon(burst,[[12,1],[15,8],[22,6],[17,12],[23,17],[15,16],[12,23],[9,16],[2,18],[7,12],[2,6],[9,8]],Color.new(255,230,177,230))
      dust = Bitmap.new(40,40)
      [[17,12],[12,21],[7,29]].each { |r,a| disc(dust,20,20,r,Color.new(194,174,148,a)) }
      [shard,chip,burst,dust]
    elsif kind==:pester
      bugs = Array.new(2) do |i|
        b = Bitmap.new(32,28)
        if i==0
          polygon(b,[[14,12],[4,3],[1,7],[4,15],[13,17]],Color.new(199,220,174,205))
          polygon(b,[[18,12],[28,3],[31,7],[28,15],[19,17]],Color.new(199,220,174,205))
          polygon(b,[[12,14],[4,15],[3,21],[12,20]],Color.new(224,236,198,150))
          polygon(b,[[20,14],[28,15],[29,21],[20,20]],Color.new(224,236,198,150))
        else
          polygon(b,[[14,13],[8,1],[4,3],[7,11],[13,17]],Color.new(209,229,184,210))
          polygon(b,[[18,13],[24,1],[28,3],[25,11],[19,17]],Color.new(209,229,184,210))
        end
        b.fill_rect(13,10,6,14,Color.new(63,72,53,255))
        b.fill_rect(12,9,8,6,Color.new(81,93,58,255))
        b.fill_rect(14,17,4,2,Color.new(174,193,115,235))
        b.fill_rect(14,21,4,2,Color.new(174,193,115,235))
        b.fill_rect(12,6,2,4,Color.new(63,72,53,245))
        b.fill_rect(18,6,2,4,Color.new(63,72,53,245))
        b.fill_rect(12,11,2,2,Color.new(235,241,165,255))
        b.fill_rect(18,11,2,2,Color.new(235,241,165,255))
        b
      end
      trail = Bitmap.new(12,32)
      32.times do |y|
        v = Math.sin(y/31.0*Math::PI)
        trail.fill_rect(5,y,2,1,Color.new(201,216,158,(v*170).round))
      end
      [bugs[0],bugs[1],trail]
    else
      mark = Bitmap.new(24,44)
      polygon(mark,[[5,3],[19,3],[16,29],[8,29]],Color.new(105,79,136,215))
      polygon(mark,[[8,5],[16,5],[14,27],[10,27]],Color.new(234,217,250,255))
      mark.fill_rect(7,33,10,8,Color.new(105,79,136,215))
      mark.fill_rect(10,34,4,5,Color.new(247,233,255,255))
      shadow = Bitmap.new(28,56)
      polygon(shadow,[[14,2],[18,17],[24,24],[20,35],[25,46],[16,54],[5,49],[8,37],[3,27],[10,18]],Color.new(69,57,95,145))
      polygon(shadow,[[14,8],[15,24],[19,31],[13,43],[15,51],[10,45],[12,31],[9,25]],Color.new(133,107,164,130))
      line = Bitmap.new(12,48)
      48.times do |y|
        v = Math.sin(y/47.0*Math::PI)
        line.fill_rect(4,y,4,1,Color.new(92,73,127,(v*220).round))
        line.fill_rect(5,y,2,1,Color.new(192,166,218,(v*180).round))
      end
      shock = Bitmap.new(20,32)
      polygon(shock,[[10,1],[14,12],[11,16],[15,28],[8,22],[9,15],[5,8]],Color.new(227,210,247,235))
      [mark,shadow,line,shock]
    end
  end
  def self.play_se(kind)
    names = case kind
            when :splinter then ["PRSFX- Spike Cannon","PRSFX- Pin Missile"]
            when :pester then ["PRSFX- Infestation","PRSFX- Bug Buzz"]
            else ["PRSFX- Astonish1","PRSFX- Scary Face"]
            end
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",kind==:pester ? 65 : 75,kind==:scared ? 90 : 100)
      break
    end
  end
  def self.kind(name)
    case name.to_s.downcase
    when "splinter","splinters" then :splinter
    when "pester" then :pester
    when "scared" then :scared
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if MAGSplinterPesterScaredVisual.kind(name)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      kind = MAGSplinterPesterScaredVisual.kind(name)
      return super unless kind
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @mag_splinter_pester_scared_boxes
      pbMAGSplinterPesterScaredVisual(source,kind)
    end
    def pbMAGSplinterPesterScaredVisualHideHP
      return unless @mag_splinter_pester_scared_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @mag_splinter_pester_scared_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbMAGSplinterPesterScaredVisualHideHP if @mag_splinter_pester_scared_boxes
      super
    end
    def pbMAGSplinterPesterScaredVisual(source,kind)
      sprites,bitmaps = [],[]
      @mag_splinter_pester_scared_boxes = {}
      begin
        @briefMessage = false
        pbMAGSplinterPesterScaredVisualHideHP
        MAGSplinterPesterScaredVisual.play_se(kind)
        bitmaps.concat(MAGSplinterPesterScaredVisual.assets(kind))
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
                     when :splinter then Color.new(232,197,147,200)
                     when :pester then Color.new(195,212,148,180)
                     else Color.new(65,53,92,225)
                     end
        aura.blend_type = 0 if kind==:scared
        if kind==:splinter
          shards = Array.new(7) { make.call(bitmaps[0],14,26,z+3,0) }
          chips = Array.new(22) { make.call(bitmaps[1],9,10,z+4,0) }
          impacts = Array.new(7) { make.call(bitmaps[2],12,12,z+4,1) }
          dust = Array.new(6) { make.call(bitmaps[3],20,20,z-1,0) }
        elsif kind==:pester
          bugs = Array.new(12) { make.call(bitmaps[0],16,14,z+3,0) }
          trails = Array.new(24) { make.call(bitmaps[2],6,16,z+2,0) }
        else
          marks = Array.new(2) { make.call(bitmaps[0],12,22,z+5,0) }
          shadows = Array.new(8) { make.call(bitmaps[1],14,28,z+2,0) }
          lines = Array.new(5) { make.call(bitmaps[2],6,24,z+3,0) }
          shocks = Array.new(6) { make.call(bitmaps[3],10,16,z+4,0) }
        end
        frames = [(Graphics.frame_rate*MAGSplinterPesterScaredVisual::DURATIONS[kind]).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.10,(1-t)/0.20,1.0].min
          head = foot-height*0.88
          if kind==:splinter
            flash = [1-(t-0.28).abs/0.18,0].max
            aura.opacity = (fade*(14+42*flash)).round
            shards.each_with_index do |s,i|
              p = [[(t-(i%3)*0.04)/0.72,0].max,1].min
              strike = [p/0.32,1].min
              a = i*2.399
              r = radius*(1.45-strike*0.90)
              s.x = cx+Math.cos(a)*r
              s.y = foot-height*(0.18+(i%3)*0.23)+Math.sin(a)*8+[p-0.55,0].max*18
              size = 0.47+i%3*0.08
              s.zoom_x,s.zoom_y = size,size*(1-[p-0.65,0].max)
              s.angle = Math.cos(a)*38
              s.z = Math.sin(a)>0 ? z+3 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)**0.45*245).round
              q = impacts[i]
              q.x,q.y = s.x,s.y
              q.zoom_x = q.zoom_y = 0.35+[1-(p-0.32).abs/0.14,0].max*0.25
              q.opacity = (fade*[1-(p-0.32).abs/0.12,0].max*235).round
            end
            chips.each_with_index do |s,i|
              p = [[(t-0.16-(i%5)*0.025)/0.68,0].max,1].min
              a = i*2.399
              s.x = cx+Math.cos(a)*radius*(0.45+p*0.85)
              s.y = foot-height*0.42-Math.sin(p*Math::PI)*17+p*p*(height*0.4+13)+Math.sin(a)*14
              s.zoom_x = s.zoom_y = 0.23+i%3*0.08
              s.angle = i*27+t*(i%2==0 ? 150 : -150)
              s.z = Math.sin(a)>0 ? z+4 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)*235).round
            end
            dust.each_with_index do |s,i|
              s.x = cx+(i-2.5)*radius*0.35+Math.sin(t*3+i)*4
              s.y = foot-2-t*5
              s.zoom_x,s.zoom_y = 0.65+t*0.55,0.32+t*0.12
              s.opacity = (fade*165).round
            end
          elsif kind==:pester
            aura.opacity = (fade*20).round
            bugs.each_with_index do |s,i|
              a = i*2.399+t*(i%2==0 ? 6.2 : -5.4)
              r = radius*(0.82+0.25*Math.sin(t*8+i))
              s.x = cx+Math.cos(a)*r+Math.sin(t*21+i)*4
              s.y = foot-height*0.52+Math.sin(a*1.4+i)*height*0.45+Math.sin(t*17+i)*3
              s.z = Math.sin(a)>0 ? z+3 : z-1
              s.bitmap = bitmaps[((t*32).floor+i)%2]
              s.zoom_x = s.zoom_y = 0.39+i%3*0.085
              s.angle = Math.sin(t*15+i)*18
              s.mirror = Math.sin(a)>0
              s.opacity = (fade*245).round
              2.times do |j|
                q = trails[i*2+j]
                q.x = s.x-Math.cos(a)*(5+j*5)
                q.y = s.y+Math.sin(a)*(2+j*2)
                q.z = s.z-1
                q.zoom_x,q.zoom_y = 0.30,0.30+j*0.05
                q.angle = 65+Math.sin(a)*45
                q.opacity = (fade*(130-j*45)).round
              end
            end
          else
            panic = Math.exp(-((t-0.25)/0.14)**2)
            aura.opacity = (fade*(30+35*panic)).round
            marks.each_with_index do |s,i|
              pop = [[(t-i*0.055)/0.16,0].max,1].min
              s.x = cx+(i==0 ? 6 : 19)+Math.sin(t*32+i)*panic*1.5
              s.y = head-17-(1-pop)*9+(i==1 ? 5 : 0)
              s.zoom_x = s.zoom_y = (i==0 ? 0.60 : 0.42)*(0.75+0.25*pop)
              s.angle = i==0 ? -7 : 9
              s.opacity = (fade*pop*245).round
            end
            shadows.each_with_index do |s,i|
              p = (t*0.72+i*0.13)%1.0
              a = i*2.399-t*1.2
              s.x = cx+Math.cos(a)*radius*(0.92-p*0.35)
              s.y = foot-height*0.10-p*height*0.72+Math.sin(a)*8
              s.zoom_x = 0.40+i%3*0.08
              s.zoom_y = 0.42+p*0.20
              s.z = Math.sin(a)>0 ? z+2 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)*160).round
            end
            lines.each_with_index do |s,i|
              s.x = cx+(i-2)*8
              s.y = head+12+Math.sin(t*8+i)*3
              s.zoom_x,s.zoom_y = 0.48,0.34+i%2*0.10
              s.opacity = (fade*(110+65*panic)).round
            end
            shocks.each_with_index do |s,i|
              a = Math::PI+i*Math::PI/5
              s.x = cx+Math.cos(a)*(radius*0.80+8+panic*8)
              s.y = head+Math.sin(a)*23
              s.zoom_x = s.zoom_y = 0.36
              s.angle = (a*180/Math::PI)+90
              s.opacity = (fade*panic*240).round
            end
          end
          pbUpdate
        end
      ensure
        boxes = @mag_splinter_pester_scared_boxes
        @mag_splinter_pester_scared_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(MAGSplinterPesterScaredVisual::SceneHooks)
