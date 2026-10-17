# Shared confusion / infatuation animations - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:Confusion and Common:Attract only.
# No graphics/audio imports or stat/HP calculation hooks are required.
module ConfusionAttractVisual
  VERSION = "1.0"
  DURATIONS = { :confusion=>0.96, :attract=>1.08 }
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
    if kind==:confusion
      star = Bitmap.new(36,36)
      points = Array.new(10) do |i|
        a = i*Math::PI/5-Math::PI/2
        r = i.even? ? 16 : 7
        [(18+Math.cos(a)*r).round,(18+Math.sin(a)*r).round]
      end
      polygon(star,points,Color.new(209,151,61,235))
      inner = points.map { |x,y| [18+(x-18)*0.78,18+(y-18)*0.78].map(&:round) }
      polygon(star,inner,Color.new(255,225,132,255))
      polygon(star,[[18,6],[20,15],[27,17],[18,19],[15,26],[15,18],[9,15],[16,14]],Color.new(255,251,210,240))
      halo = Bitmap.new(128,128)
      360.times do |i|
        next if i%36>20
        a = i*Math::PI/180
        halo.fill_rect((64+Math.cos(a)*51).round,(64+Math.sin(a)*51).round,2,2,Color.new(248,213,131,145))
      end
      dot = Bitmap.new(12,12)
      dot.fill_rect(4,2,4,8,Color.new(255,223,128,150))
      dot.fill_rect(2,4,8,4,Color.new(255,223,128,150))
      dot.fill_rect(4,4,4,4,Color.new(255,255,219,240))
      [star,halo,dot]
    else
      heart = Bitmap.new(36,36)
      polygon(heart,[[18,31],[4,18],[2,12],[4,6],[10,3],[15,4],[18,8],
        [21,4],[27,3],[32,6],[34,12],[32,18]],Color.new(211,114,157,235))
      polygon(heart,[[18,28],[7,17],[5,12],[7,8],[11,6],[15,7],[18,12],
        [22,7],[27,6],[30,9],[31,13],[29,17]],Color.new(250,174,205,255))
      polygon(heart,[[18,26],[10,17],[8,12],[10,9],[14,10],[18,15],
        [23,10],[27,9],[29,13],[27,17]],Color.new(255,200,222,240))
      heart.fill_rect(9,9,3,6,Color.new(255,245,250,250))
      heart.fill_rect(12,8,3,2,Color.new(255,245,250,235))
      ring = Bitmap.new(128,128)
      360.times do |i|
        a = i*Math::PI/180
        ring.fill_rect((64+Math.cos(a)*51).round,(64+Math.sin(a)*51).round,2,2,Color.new(247,174,211,145))
      end
      glint = Bitmap.new(20,20)
      glint.fill_rect(9,2,2,16,Color.new(255,202,227,190))
      glint.fill_rect(2,9,16,2,Color.new(255,202,227,190))
      glint.fill_rect(8,8,4,4,Color.new(255,245,250,255))
      [heart,ring,glint]
    end
  end
  def self.play_se(kind)
    names = kind==:confusion ? ["PRSFX- Confused","Confuse","PRSFX- Confusion"] : ["PRSFX- Attract","infatuated","PRSFX- Attract1"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",70,100)
      break
    end
  end
  def self.kind(name)
    case name.to_s.downcase
    when "confusion","confused" then :confusion
    when "attract","infatuation","infatuated" then :attract
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if ConfusionAttractVisual.kind(name)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      kind = ConfusionAttractVisual.kind(name)
      return super unless kind
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @confusion_attract_visual_boxes
      pbConfusionAttractVisual(source,kind)
    end
    def pbConfusionAttractVisualHideHP
      return unless @confusion_attract_visual_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @confusion_attract_visual_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbConfusionAttractVisualHideHP if @confusion_attract_visual_boxes
      super
    end
    def pbConfusionAttractVisual(source,kind)
      sprites,bitmaps = [],[]
      @confusion_attract_visual_boxes = {}
      begin
        @briefMessage = false
        pbConfusionAttractVisualHideHP
        ConfusionAttractVisual.play_se(kind)
        bitmaps.concat(ConfusionAttractVisual.assets(kind))
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
        aura.color = kind==:confusion ? Color.new(255,225,151,200) : Color.new(251,176,211,210)
        halo = make.call(bitmaps[1],64,64,z-1,0)
        if kind==:confusion
          stars = Array.new(5) { make.call(bitmaps[0],18,18,z+4,0) }
          trails = Array.new(15) { make.call(bitmaps[2],6,6,z+2,1) }
        else
          hearts = Array.new(7) { make.call(bitmaps[0],18,18,z+3,0) }
          main = make.call(bitmaps[0],18,18,z+4,0)
          glints = Array.new(16) { make.call(bitmaps[2],10,10,z+4,1) }
        end
        frames = [(Graphics.frame_rate*ConfusionAttractVisual::DURATIONS[kind]).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.12,(1-t)/0.20,1.0].min
          if kind==:confusion
            head = foot-height*0.88
            orbit = radius*0.95+5
            aura.opacity = (fade*22).round
            halo.x,halo.y = cx,head
            halo.zoom_x,halo.zoom_y = orbit/51.0,orbit/51.0*0.26
            halo.opacity = (fade*155).round
            stars.each_with_index do |s,i|
              a = i*Math::PI*2/5+t*Math::PI*3.6
              s.x = cx+Math.cos(a)*orbit
              s.y = head+Math.sin(a)*12+Math.sin(t*7+i)*3
              s.z = Math.sin(a)>0 ? z+4 : z-1
              scale = 0.44+0.08*Math.sin(a)
              s.zoom_x = s.zoom_y = scale
              s.angle = t*65+i*19
              s.opacity = (fade*245).round
              3.times do |j|
                q = trails[i*3+j]
                tail = a-(j+1)*0.15
                q.x = cx+Math.cos(tail)*orbit
                q.y = head+Math.sin(tail)*12
                q.z = Math.sin(tail)>0 ? z+2 : z-1
                q.zoom_x = q.zoom_y = 0.26-j*0.045
                q.opacity = (fade*(150-j*38)).round
              end
            end
          else
            pulse = Math.exp(-((t-0.50)/0.13)**2)
            aura.opacity = (fade*(18+50*pulse)).round
            hearts.each_with_index do |s,i|
              p = [[(t-(i%4)*0.055)/0.78,0].max,1].min
              a = i*2.399+t*1.5
              s.x = cx+Math.cos(a)*radius*(0.72+p*0.32)+Math.sin(p*5+i)*5
              s.y = foot-height*0.17-p*(height*0.84+24)+Math.sin(a)*8
              beat = 1+0.08*Math.sin(t*14+i)
              s.zoom_x = s.zoom_y = (0.36+i%3*0.095)*beat
              s.angle = Math.sin(p*4+i)*12
              s.z = Math.sin(a)>0 ? z+3 : z-1
              s.opacity = (fade*Math.sin(p*Math::PI)*240).round
            end
            main.x = cx
            main.y = foot-height*0.57-t*8
            main.zoom_x = main.zoom_y = 0.42+pulse*0.22
            main.opacity = (fade*pulse*245).round
            halo.x,halo.y = main.x,main.y
            scale = radius/51.0*(0.4+t*1.15)
            halo.zoom_x = halo.zoom_y = scale
            halo.opacity = (fade*pulse*115).round
            glints.each_with_index do |s,i|
              a = i*2.399+t*0.8
              s.x = cx+Math.cos(a)*radius*(0.6+t*0.3)
              s.y = foot-height*0.50+Math.sin(a)*height*0.47-t*13
              s.zoom_x = s.zoom_y = 0.12+i%3*0.055
              s.angle = t*45+i*21
              s.opacity = (fade*(0.5+0.5*Math.sin(t*9+i))*165).round
            end
          end
          pbUpdate
        end
      ensure
        boxes = @confusion_attract_visual_boxes
        @confusion_attract_visual_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(ConfusionAttractVisual::SceneHooks)
