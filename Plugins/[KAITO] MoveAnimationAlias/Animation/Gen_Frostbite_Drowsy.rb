# Shared frostbite / drowsy status animations - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:Frostbite and Common:Drowsy only.
# No graphics/audio imports or stat/HP calculation hooks are required.
module FrostbiteDrowsyVisual
  VERSION = "1.0"
  DURATIONS = { :frostbite=>0.94, :drowsy=>1.04 }
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
    if kind==:frostbite
      crystal = Bitmap.new(28,44)
      polygon(crystal,[[14,2],[24,17],[22,32],[14,41],[5,31],[4,18]],Color.new(100,160,217,230))
      polygon(crystal,[[14,5],[14,38],[7,29],[7,18]],Color.new(182,231,255,245))
      polygon(crystal,[[14,5],[21,18],[19,29],[14,38]],Color.new(124,195,237,240))
      polygon(crystal,[[14,5],[21,18],[14,22],[7,18]],Color.new(239,252,255,255))
      crystal.fill_rect(10,19,2,11,Color.new(255,255,255,245))
      flake = Bitmap.new(24,24)
      flake.fill_rect(11,2,2,20,Color.new(180,227,251,220))
      flake.fill_rect(2,11,20,2,Color.new(180,227,251,220))
      polygon(flake,[[4,5],[6,4],[20,18],[18,20]],Color.new(150,207,245,180))
      polygon(flake,[[18,4],[20,6],[6,20],[4,18]],Color.new(150,207,245,180))
      flake.fill_rect(10,10,4,4,Color.new(249,255,255,255))
      cloud = Bitmap.new(40,40)
      [[17,12],[12,21],[7,32]].each { |r,a| disc(cloud,20,20,r,Color.new(169,214,243,a)) }
      wisp = vapor([113,183,226],[200,241,255])
      [crystal,flake,cloud,wisp]
    else
      moon = Bitmap.new(36,36)
      disc(moon,17,18,13,Color.new(173,155,220,200))
      disc(moon,17,17,11,Color.new(239,225,255,245))
      disc(moon,23,12,11,Color.new(0,0,0,0))
      moon.fill_rect(7,16,2,7,Color.new(255,247,232,235))
      bubble = Bitmap.new(36,36)
      disc(bubble,18,18,13,Color.new(193,182,233,26))
      360.times do |i|
        a = i*Math::PI/180
        bubble.fill_rect((18+Math.cos(a)*13).round,(18+Math.sin(a)*13).round,1,1,Color.new(211,198,246,160))
      end
      bubble.fill_rect(10,9,3,5,Color.new(248,240,255,210))
      cloud = Bitmap.new(40,40)
      [[17,10],[12,16],[7,24]].each { |r,a| disc(cloud,20,20,r,Color.new(191,177,225,a)) }
      wisp = vapor([173,151,213],[227,216,250])
      [moon,bubble,cloud,wisp]
    end
  end
  def self.vapor(dark,light)
    b = Bitmap.new(14,48)
    48.times do |y|
      v = Math.sin(y/47.0*Math::PI)
      width = [1,(v*5).round].max
      b.fill_rect(7-width,y,width*2,1,Color.new(*dark,(v*55).round))
      b.fill_rect(6,y,2,1,Color.new(*light,(v*145).round))
    end
    b
  end
  def self.play_se(kind)
    names = kind==:frostbite ? ["PRSFX- Freeze Dry1","PRSFX- Frozen","PRSFX- Ice Beam"] : ["PRSFX- Yawn","Yawn","PRSFX- Sleep"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",kind==:frostbite ? 70 : 60,100)
      break
    end
  end
  def self.kind(name)
    case name.to_s.downcase
    when "frostbite" then :frostbite
    when "drowsy" then :drowsy
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if FrostbiteDrowsyVisual.kind(name)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      kind = FrostbiteDrowsyVisual.kind(name)
      return super unless kind
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @frostbite_drowsy_visual_boxes
      pbFrostbiteDrowsyVisual(source,kind)
    end
    def pbFrostbiteDrowsyVisualHideHP
      return unless @frostbite_drowsy_visual_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @frostbite_drowsy_visual_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbFrostbiteDrowsyVisualHideHP if @frostbite_drowsy_visual_boxes
      super
    end
    def pbFrostbiteDrowsyVisual(source,kind)
      sprites,bitmaps = [],[]
      @frostbite_drowsy_visual_boxes = {}
      begin
        @briefMessage = false
        pbFrostbiteDrowsyVisualHideHP
        FrostbiteDrowsyVisual.play_se(kind)
        bitmaps.concat(FrostbiteDrowsyVisual.assets(kind))
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
        aura.color = kind==:frostbite ? Color.new(142,211,250,215) : Color.new(211,194,245,190)
        clouds = Array.new(6) { make.call(bitmaps[2],20,20,z-1,0) }
        wisps = Array.new(kind==:frostbite ? 24 : 16) { make.call(bitmaps[3],7,24,z+2,0) }
        if kind==:frostbite
          crystals = Array.new(7) { make.call(bitmaps[0],14,22,z+3,0) }
          flakes = Array.new(20) { make.call(bitmaps[1],12,12,z+4,1) }
        else
          moon = make.call(bitmaps[0],18,18,z+4,0)
          bubbles = Array.new(6) { make.call(bitmaps[1],18,18,z+3,0) }
        end
        frames = [(Graphics.frame_rate*FrostbiteDrowsyVisual::DURATIONS[kind]).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.12,(1-t)/0.20,1.0].min
          if kind==:frostbite
            pulse = 0.5+0.5*Math.sin(t*Math::PI*3-0.6)
            aura.opacity = (fade*(25+38*pulse)).round
            crystals.each_with_index do |s,i|
              a = i*2.399
              grow = [[(t-i*0.025)/0.23,0].max,1].min
              s.x = cx+Math.cos(a)*radius*0.72
              s.y = foot-height*(0.18+(i%3)*0.25)+Math.sin(a)*6
              s.z = Math.sin(a)>0 ? z+3 : z-1
              size = (0.30+i%3*0.075)*(0.5+0.5*grow)
              s.zoom_x,s.zoom_y = size,size*(1+0.08*Math.sin(t*9+i))
              s.angle = Math.cos(a)*18
              s.opacity = (fade*grow*(185+35*pulse)).round
            end
            flakes.each_with_index do |s,i|
              p = (t*0.75+i*0.057)%1.0
              a = i*2.399-t*1.4
              s.x = cx+Math.cos(a)*radius*(0.7+p*0.25)
              s.y = foot-height-18+p*(height+20)
              s.z = Math.sin(a)>0 ? z+4 : z-1
              s.zoom_x = s.zoom_y = 0.12+i%4*0.045
              s.angle = i*19+t*55
              s.opacity = (fade*Math.sin(p*Math::PI)*220).round
            end
          else
            pulse = Math.sin(t*Math::PI)**2
            aura.opacity = (fade*(14+22*pulse)).round
            head = foot-height*0.88
            moon.x = cx+radius*0.52+Math.sin(t*4)*5
            moon.y = head-13-Math.sin(t*Math::PI)*6
            moon.zoom_x = moon.zoom_y = 0.43+0.05*pulse
            moon.angle = Math.sin(t*4)*8
            moon.opacity = (fade*235).round
            bubbles.each_with_index do |s,i|
              p = [[(t-(i%3)*0.10)/0.75,0].max,1].min
              side = i%2==0 ? -1 : 1
              s.x = cx+side*(radius*0.36+p*16)+Math.sin(t*5+i)*5
              s.y = head+15-p*32+Math.sin(p*4+i)*4
              s.zoom_x = s.zoom_y = 0.25+i%3*0.10+0.05*Math.sin(p*Math::PI)
              s.opacity = (fade*Math.sin(p*Math::PI)*190).round
            end
          end
          wisps.each_with_index do |s,i|
            half = kind==:frostbite ? 12 : 8
            u = (i%half).to_f/(half-1)
            a = u*Math::PI*2.2-t*(kind==:frostbite ? 3.2 : 1.25)+(i/half)*Math::PI
            r = radius*(kind==:frostbite ? 0.95 : 0.88)
            s.x = cx+Math.cos(a)*r
            s.y = kind==:frostbite ? foot-u*height+Math.sin(a)*6 : foot-height*0.88+Math.sin(a)*13+u*9
            s.z = Math.sin(a)>0 ? z+2 : z-1
            s.zoom_x = 0.33+0.14*Math.sin(u*Math::PI)
            s.zoom_y = kind==:frostbite ? 0.40 : 0.27
            s.angle = Math.sin(a)*(kind==:frostbite ? 55 : 75)
            s.opacity = (fade*Math.sin(u*Math::PI)*(kind==:frostbite ? 155 : 110)).round
          end
          clouds.each_with_index do |s,i|
            a = i*2.399-t*1.5
            s.x = cx+Math.cos(a)*radius*0.7
            s.y = kind==:frostbite ? foot-5-(i%2)*13-t*8 : foot-height*0.85+Math.sin(a)*15-t*4
            s.zoom_x = 0.9+t*0.3
            s.zoom_y = 0.30+t*0.12
            s.opacity = (fade*(kind==:frostbite ? 165 : 110)).round
          end
          pbUpdate
        end
      ensure
        boxes = @frostbite_drowsy_visual_boxes
        @frostbite_drowsy_visual_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(FrostbiteDrowsyVisual::SceneHooks)
