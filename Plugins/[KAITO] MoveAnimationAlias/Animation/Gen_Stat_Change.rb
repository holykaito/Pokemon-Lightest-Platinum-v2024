# Stat Up / Stat Down - Pokemon Essentials v21.1
# Replaces common animations only, never hooks stat calculation methods.
# Install this .rb in an existing plugin folder. No images or PBS edits.
module StatChangeVisual
  VERSION = "2.2"
  DURATION = 1.05
  UP = [[246,130,65],[255,224,133],[255,250,217]]
  DOWN = [[106,65,213],[130,189,255],[226,241,255]]

  # Small soft motes and tapered light dashes, drawn at native pixel scale.
  def self.mote(palette)
    b=Bitmap.new(8,8)
    b.fill_rect(1,2,6,4,Color.new(*palette[0],65))
    b.fill_rect(2,1,4,6,Color.new(*palette[0],65))
    b.fill_rect(2,2,4,4,Color.new(*palette[1],190))
    b.fill_rect(3,3,2,2,Color.new(*palette[2],255))
    b
  end

  def self.dash(palette)
    b=Bitmap.new(8,28)
    26.times do |y|
      v=Math.sin(y/25.0*Math::PI)
      b.fill_rect(2,y+1,4,1,Color.new(*palette[0],(v*70).round))
      b.fill_rect(3,y+1,2,1,Color.new(*palette[1],(v*220).round))
      b.fill_rect(3,y+1,1,1,Color.new(*palette[2],(v*v*240).round))
    end
    b
  end

  def self.ring(palette)
    b = Bitmap.new(128,128)
    360.times do |i|
      next if i%45>32
      a = i*Math::PI/180
      [49,52].each do |r|
        b.fill_rect((64+Math.cos(a)*r).round,(64+Math.sin(a)*r).round,2,2,
                    Color.new(*palette[1],r==49 ? 190 : 90))
      end
    end
    b
  end

  module SceneHooks
    def pbCommonAnimation(name,user = nil,target = nil)
      key = name.to_s.downcase
      return super unless ["statup","statdown"].include?(key)
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      pbStatChangeVisual(source,key=="statup")
    end

    def pbStatChangeVisual(source,increasing)
      sprites,bitmaps = [],[]
      begin
        @briefMessage = false
        palette = increasing ? StatChangeVisual::UP : StatChangeVisual::DOWN
        make = proc do |b,ox,oy,z|
          s = Sprite.new(@viewport)
          sprites << s
          s.bitmap,s.ox,s.oy,s.z = b,ox,oy,z
          s
        end
        mote_b,dash_b,ring_b = StatChangeVisual.mote(palette),
          StatChangeVisual.dash(palette),StatChangeVisual.ring(palette)
        bitmaps.concat([mote_b,dash_b,ring_b])
        cx = source.x+(source.src_rect.width/2.0-source.ox)*source.zoom_x
        foot = source.y+(source.src_rect.height-source.oy)*source.zoom_y
        height = [[source.src_rect.height*source.zoom_y,60].max,180].min
        radius = [[source.src_rect.width*source.zoom_x*0.46,27].max,68].min
        z = source.z
        # Share one owned bitmap for the local silhouette glow. Never recolour
        # or move the actual Pokemon, preserving status patterns and selection.
        aura_b = source.bitmap.clone
        bitmaps << aura_b
        aura = make.call(aura_b,source.ox,source.oy,z+1)
        aura.src_rect.set(source.src_rect.x,source.src_rect.y,source.src_rect.width,source.src_rect.height)
        aura.x,aura.y = source.x,source.y
        aura.zoom_x,aura.zoom_y,aura.mirror = source.zoom_x,source.zoom_y,source.mirror
        aura.color = Color.new(*palette[1],235)
        aura.blend_type = 1
        dashes = Array.new(22) { make.call(dash_b,4,14,z+4) }
        particles = Array.new(40) { make.call(mote_b,4,4,z+3) }
        # The paired spirals pass behind and in front of the Pokemon.
        strands = Array.new(48) { make.call(dash_b,4,14,z+2) }
        rings = Array.new(3) { make.call(ring_b,64,64,z-2) }
        shock = make.call(ring_b,64,64,z+3)
        (dashes+particles+strands+rings+[shock]).each { |s| s.blend_type=1 }
        frames = [(Graphics.frame_rate*StatChangeVisual::DURATION).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.12,(1-t)/0.22,1.0].min
          pulse = Math.exp(-((t-0.65)/0.13)**2)
          aura.opacity = (fade*(40+75*pulse)).round
          aura.color = Color.new(*palette[1],225)
          dashes.each_with_index do |s,i|
            start=(i%7)*0.035+(i/7)*0.075
            progress=[[(t-start)/0.65,0].max,1].min
            lane=Math.sin(i*2.399)*radius*(0.65+(i%3)*0.14)
            s.x=cx+lane+Math.sin(progress*Math::PI+i)*5
            s.y=increasing ? foot+9-progress*(height+37) : foot-height-28+progress*(height+37)
            s.z=i.even? ? z+4 : z-1
            s.angle=(increasing ? -1 : 1)*(8+Math.sin(i*1.7)*10)
            s.zoom_x=0.55+(i%3)*0.13
            s.zoom_y=0.30+(i%4)*0.13
            s.opacity=(Math.sin(progress*Math::PI)*fade*(175+55*pulse)).round
          end
          strands.each_with_index do |s,i|
            strand = i/24
            u = (i%24)/23.0
            a = u*Math::PI*3.1+t*(increasing ? -5.5 : 5.5)+strand*Math::PI
            vertical = increasing ? u : 1-u
            r = radius*(0.85+Math.sin(u*Math::PI)*0.22)
            s.x = cx+Math.cos(a)*r
            s.y = foot+4-vertical*(height+30)+Math.sin(a)*10
            s.z = Math.sin(a)>0 ? z+3 : z-1
            s.zoom_x = 0.42+0.10*Math.sin(u*Math::PI)
            s.zoom_y = 0.28+0.16*Math.sin(u*Math::PI)
            s.angle = (increasing ? -65 : 65)*Math.sin(a)
            s.opacity = (fade*Math.sin(u*Math::PI)*(120+70*pulse)).round
          end
          particles.each_with_index do |s,i|
            progress = [[(t-0.13-(i%7)*0.035)/0.68,0].max,1].min
            a = i*2.399
            r = radius*(0.5+progress*(increasing ? 1.15 : -0.35))
            s.x = cx+Math.cos(a)*r
            s.y = increasing ? foot-12-progress*(height+45)+Math.sin(a)*14 : foot-height-27+progress*(height+35)+Math.sin(a)*10
            s.zoom_x = s.zoom_y = (0.36+i%4*0.13)*(0.85+0.30*pulse)
            s.angle = t*(increasing ? 140 : -140)+i*23
            s.z = Math.sin(a)>0 ? z+5 : z-1
            s.opacity = (fade*Math.sin(progress*Math::PI)*245).round
          end
          rings.each_with_index do |s,i|
            p = (t*1.25+i/3.0)%1.0
            s.x = cx
            s.y = increasing ? foot-4-p*(height+18) : foot-height-22+p*(height+18)
            scale = radius/50.0*(increasing ? 0.75+0.45*p : 1.25-0.55*p)
            s.zoom_x,s.zoom_y = scale,scale*0.24
            s.angle = 0
            s.opacity = (fade*Math.sin(p*Math::PI)*175).round
            s.z = z-1
          end
          burst = [[(t-0.52)/0.42,0].max,1].min
          scale = radius/50.0*(increasing ? 0.4+burst*1.65 : 1.9-burst*1.5)
          shock.x,shock.y = cx,foot-3
          shock.zoom_x,shock.zoom_y = scale,scale*0.3
          shock.opacity = (Math.sin(burst*Math::PI)*fade*235).round
          pbUpdate
        end
      ensure
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(StatChangeVisual::SceneHooks)
