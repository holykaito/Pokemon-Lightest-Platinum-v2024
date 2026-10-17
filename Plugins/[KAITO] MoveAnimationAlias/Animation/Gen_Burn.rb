# Shared burn-status animation - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:Burn only.
# No graphics/audio imports or stat/HP calculation hooks are required.
module BurnVisual
  VERSION = "1.0"
  DURATION = 0.86
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
  def self.assets
    flames = Array.new(4) do |i|
      b = Bitmap.new(36,56)
      tip = [15,21,18,12][i]
      polygon(b,[[18,54],[7,51],[3,42],[5,31],[10,35],[11,20],
        [tip,3],[24,19],[25,30],[30,23],[32,40],[28,50]],Color.new(202,56,35,215))
      polygon(b,[[18,52],[8,47],[7,38],[12,41],[14,25],[tip,10],
        [22,29],[25,38],[28,33],[29,44],[24,51]],Color.new(255,128,43,250))
      polygon(b,[[18,51],[12,47],[12,40],[17,30],[19,22+i*2],
        [21,39],[25,43],[23,49]],Color.new(255,213,102,255))
      polygon(b,[[18,50],[15,46],[18,37],[21,46],[21,49]],Color.new(255,249,206,255))
      b
    end
    ember = Bitmap.new(12,18)
    ember.fill_rect(3,4,6,11,Color.new(235,77,31,105))
    ember.fill_rect(4,3,4,10,Color.new(255,151,62,235))
    ember.fill_rect(5,4,2,5,Color.new(255,243,178,255))
    glow = Bitmap.new(32,32)
    [[14,[222,75,39,12]],[10,[255,117,47,25]],[6,[255,177,75,50]]].each do |r,c|
      disc(glow,16,16,r,Color.new(*c))
    end
    smoke = Bitmap.new(32,32)
    [[13,24],[9,40],[5,55]].each { |r,a| disc(smoke,16,16,r,Color.new(94,78,80,a)) }
    flames+[ember,glow,smoke]
  end
  def self.play_se
    ["PRSFX- Burn","PRSFX- Ember","Fire1"].each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",75,105)
      break
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if name.to_s.downcase=="burn"
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      return super unless name.to_s.downcase=="burn"
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @burn_visual_boxes
      pbBurnVisual(source)
    end
    def pbBurnVisualHideHP
      return unless @burn_visual_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @burn_visual_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbBurnVisualHideHP if @burn_visual_boxes
      super
    end
    def pbBurnVisual(source)
      sprites,bitmaps = [],[]
      @burn_visual_boxes = {}
      begin
        @briefMessage = false
        pbBurnVisualHideHP
        BurnVisual.play_se
        bitmaps.concat(BurnVisual.assets)
        flame_bs = bitmaps[0,4]
        ember_b,glow_b,smoke_b = bitmaps[4,3]
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
        aura.color = Color.new(255,127,64,200)
        flames = Array.new(6) { |i| make.call(flame_bs[i%4],18,54,z+3,0) }
        embers = Array.new(24) { make.call(ember_b,6,9,z+4,1) }
        glows = Array.new(6) { make.call(glow_b,16,16,z+2,1) }
        smoke = Array.new(7) { make.call(smoke_b,16,16,z-1,0) }
        frames = [(Graphics.frame_rate*BurnVisual::DURATION).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.10,(1-t)/0.22,1.0].min
          flare = Math.exp(-((t-0.32)/0.20)**2)
          aura.opacity = (fade*(16+44*flare+7*Math.sin(t*37))).round
          flames.each_with_index do |s,i|
            p = [[(t-(i%3)*0.035)/0.8,0].max,1].min
            a = i*Math::PI*2/6+t*0.6
            flicker = 0.88+0.12*Math.sin(t*38+i*2.7)
            s.bitmap = flame_bs[((t*18).floor+i)%4]
            s.x = cx+Math.cos(a)*radius*(0.66+0.1*Math.sin(t*8+i))
            s.y = foot-3-(i%2)*height*0.22-p*height*0.12
            s.z = Math.sin(a)>0 ? z+3 : z-1
            size = (0.53+i%3*0.075)*(0.8+flare*0.2)
            s.zoom_x,s.zoom_y = size*flicker,size*(1.0+Math.sin(t*31+i)*0.12)
            s.opacity = (fade*Math.sin(p*Math::PI)**0.45*250).round
            g = glows[i]
            g.x,g.y,g.z = s.x,s.y-12,s.z-1
            g.zoom_x,g.zoom_y = size*2.5,size*2.1
            g.opacity = (fade*(100+65*flare)).round
          end
          embers.each_with_index do |s,i|
            p = [[(t-(i%6)*0.035)/0.73,0].max,1].min
            a = i*2.399
            s.x = cx+Math.cos(a)*radius*0.84+Math.sin(t*8+i)*9
            s.y = foot-8-p*(height+18)+Math.sin(a)*10
            s.z = Math.sin(a)>0 ? z+4 : z-1
            s.zoom_x = 0.28+i%3*0.10
            s.zoom_y = 0.32+i%4*0.10
            s.angle = Math.sin(t*7+i)*24
            s.opacity = (fade*Math.sin(p*Math::PI)*240).round
          end
          smoke.each_with_index do |s,i|
            p = [[(t-0.18-(i%3)*0.045)/0.72,0].max,1].min
            s.x = cx+Math.cos(i*2.399)*radius*0.65+Math.sin(t*4+i)*10
            s.y = foot-height*0.22-p*height*0.75
            s.zoom_x = s.zoom_y = 0.55+p*0.65
            s.opacity = (fade*Math.sin(p*Math::PI)*130).round
          end
          pbUpdate
        end
      ensure
        boxes = @burn_visual_boxes
        @burn_visual_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(BurnVisual::SceneHooks)
