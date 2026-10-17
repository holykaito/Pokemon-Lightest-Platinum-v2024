# Shared HP-recovery animation - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:HealthUp only.
# No graphics/audio imports or stat/HP calculation hooks are required.
module HealingVisual
  VERSION = "1.0"
  DURATION = 0.96
  def self.disc(b,cx,cy,r,color)
    (-r..r).each do |dy|
      dx = Math.sqrt(r*r-dy*dy).floor
      b.fill_rect(cx-dx,cy+dy,dx*2+1,1,color)
    end
  end
  def self.assets
    orb = Bitmap.new(24,24)
    [[10,[89,211,168,35]],[7,[116,229,183,100]],[4,[170,249,212,220]],[2,[250,255,231,255]]].each do |r,c|
      disc(orb,12,12,r,Color.new(*c))
    end
    cross = Bitmap.new(24,24)
    [[4,Color.new(73,184,143,125)],[3,Color.new(133,230,188,240)],[1,Color.new(244,255,229,255)]].each do |w,c|
      cross.fill_rect(12-w,3,w*2+1,19,c)
      cross.fill_rect(3,12-w,19,w*2+1,c)
    end
    ring = Bitmap.new(128,128)
    360.times do |i|
      a = i*Math::PI/180
      [[50,Color.new(104,217,177,100)],[52,Color.new(191,255,220,230)]].each do |r,c|
        ring.fill_rect((64+Math.cos(a)*r).round,(64+Math.sin(a)*r).round,2,2,c)
      end
    end
    spark = Bitmap.new(20,20)
    spark.fill_rect(9,2,2,16,Color.new(156,243,211,200))
    spark.fill_rect(2,9,16,2,Color.new(156,243,211,200))
    spark.fill_rect(8,8,4,4,Color.new(253,255,230,255))
    [orb,cross,ring,spark]
  end
  def self.play_se
    ["PRSFX- Health Up","Recovery","PRSFX- Recover"].each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",75,105)
      break
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if name.to_s.downcase=="healthup"
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      return super unless name.to_s.downcase=="healthup"
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @healing_visual_boxes
      pbHealingVisual(source)
    end
    def pbHealingVisualHideHP
      return unless @healing_visual_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @healing_visual_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbHealingVisualHideHP if @healing_visual_boxes
      super
    end
    def pbHealingVisual(source)
      sprites,bitmaps = [],[]
      @healing_visual_boxes = {}
      begin
        @briefMessage = false
        pbHealingVisualHideHP
        HealingVisual.play_se
        bitmaps.concat(HealingVisual.assets)
        orb_b,cross_b,ring_b,spark_b = bitmaps
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
        aura.color = Color.new(166,246,204,230)
        rings = Array.new(3) { make.call(ring_b,64,64,z-1,1) }
        crosses = Array.new(7) { make.call(cross_b,12,12,z+3,0) }
        motes = Array.new(24) { make.call(orb_b,12,12,z+2,1) }
        sparks = Array.new(16) { make.call(spark_b,10,10,z+4,1) }
        frames = [(Graphics.frame_rate*HealingVisual::DURATION).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.12,(1-t)/0.18,1.0].min
          pulse = Math.exp(-((t-0.71)/0.13)**2)
          aura.opacity = (fade*(25+65*pulse)).round
          rings.each_with_index do |s,i|
            p = [[(t-i*0.12)/0.65,0].max,1].min
            s.x = cx
            s.y = foot-2-p*(i==0 ? 0 : height*0.55)
            scale = radius/51.0*(0.45+p*0.9)
            s.zoom_x,s.zoom_y = scale,scale*0.23
            s.opacity = (fade*Math.sin(p*Math::PI)*(i==0 ? 215 : 125)).round
          end
          crosses.each_with_index do |s,i|
            p = [[(t-i*0.045)/0.70,0].max,1].min
            a = i*Math::PI*2/7+t*2.8
            gather = [[(p-0.58)/0.42,0].max,1].min
            s.x = cx+Math.cos(a)*radius*0.95*(1-gather)
            s.y = foot-8-p*(height*0.78)+Math.sin(a)*9
            s.z = Math.sin(a)>0 ? z+3 : z-1
            s.zoom_x = s.zoom_y = 0.45+0.16*Math.sin(p*Math::PI)
            s.opacity = (fade*Math.sin(p*Math::PI)*250).round
          end
          motes.each_with_index do |s,i|
            p = [[(t-(i%8)*0.027)/0.74,0].max,1].min
            a = i*2.399+t*3.6
            r = radius*(0.9+0.2*Math.sin(a))*(1-p*0.85)
            s.x = cx+Math.cos(a)*r
            s.y = foot-4-p*height*0.64+Math.sin(a)*10
            s.z = Math.sin(a)>0 ? z+2 : z-1
            s.zoom_x = s.zoom_y = 0.30+(i%3)*0.12
            s.opacity = (fade*Math.sin(p*Math::PI)*225).round
          end
          burst = [[(t-0.55)/0.4,0].max,1].min
          sparks.each_with_index do |s,i|
            a = i*Math::PI*2/16
            r = (7+burst*radius*0.85)
            s.x = cx+Math.cos(a)*r
            s.y = foot-height*0.48+Math.sin(a)*r*0.65-burst*12
            s.zoom_x = s.zoom_y = 0.18+(i%3)*0.08
            s.angle = t*70+i*19
            s.opacity = (fade*Math.sin(burst*Math::PI)*235).round
          end
          pbUpdate
        end
      ensure
        boxes = @healing_visual_boxes
        @healing_visual_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(HealingVisual::SceneHooks)
