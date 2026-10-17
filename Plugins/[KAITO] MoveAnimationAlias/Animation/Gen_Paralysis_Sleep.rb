# Shared paralysis / sleep status animations - Pokemon Essentials v21.1.
# Add to an existing plugin folder. Replaces Common:Paralysis and Common:Sleep only.
# No graphics/audio imports or stat/HP calculation hooks are required.
module ParalysisSleepVisual
  VERSION = "1.0"
  PARALYSIS_DURATION = 0.82
  SLEEP_DURATION = 1.08
  def self.line(b,x0,y0,x1,y1,width,color)
    steps = [(x1-x0).abs,(y1-y0).abs,1].max
    (0..steps).each do |i|
      x = (x0+(x1-x0)*i.to_f/steps).round
      y = (y0+(y1-y0)*i.to_f/steps).round
      b.fill_rect(x-width/2,y-width/2,width,width,color)
    end
  end
  def self.spark
    b = Bitmap.new(20,20)
    b.fill_rect(9,2,2,16,Color.new(255,228,143,200))
    b.fill_rect(2,9,16,2,Color.new(255,228,143,200))
    b.fill_rect(8,8,4,4,Color.new(255,255,235,255))
    b
  end
  def self.assets(kind)
    if kind==:paralysis
      bolts = Array.new(4) do |i|
        b = Bitmap.new(36,64)
        x = [15,20,17,13][i]
        points = [[x,4],[9,20],[23,25],[13,40],[26,44],[17,59]]
        [[5,Color.new(225,156,52,135)],[3,Color.new(255,224,118,250)],[1,Color.new(255,255,220,255)]].each do |w,c|
          points.each_cons(2) { |p,q| line(b,p[0],p[1],q[0],q[1],w,c) }
        end
        line(b,14,38,5,31,2,Color.new(255,230,141,220))
        line(b,22,26,31,18,2,Color.new(255,230,141,220))
        b
      end
      bolts+[spark]
    else
      bubble = Bitmap.new(40,40)
      360.times do |i|
        a = i*Math::PI/180
        [15,16].each do |r|
          bubble.fill_rect((20+Math.cos(a)*r).round,(20+Math.sin(a)*r).round,1,1,
            Color.new(195,209,250,r==16 ? 165 : 65))
        end
      end
      bubble.fill_rect(10,10,3,5,Color.new(246,247,255,200))
      bubble.fill_rect(13,8,4,2,Color.new(246,247,255,170))
      zed = Bitmap.new(28,32)
      [[4,Color.new(159,150,210,155)],[2,Color.new(222,217,255,255)]].each do |w,c|
        [[5,6,22,6],[22,6,6,25],[6,25,23,25]].each { |p| line(zed,*p,w,c) }
      end
      star = spark
      [bubble,zed,star]
    end
  end
  def self.play_se(kind)
    names = kind==:paralysis ? ["PRSFX- Paralysis","Paralyze1","PRSFX- Thunder Wave"] : ["PRSFX- Sleep","Sleep","PRSFX- Yawn"]
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext| File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",kind==:paralysis ? 70 : 65,100)
      break
    end
  end
  def self.kind(name)
    return :paralysis if ["paralysis","paralyze"].include?(name.to_s.downcase)
    return :sleep if name.to_s.downcase=="sleep"
    nil
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if ParalysisSleepVisual.kind(name)
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      kind = ParalysisSleepVisual.kind(name)
      return super unless kind
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @paralysis_sleep_visual_boxes
      pbParalysisSleepVisual(source,kind)
    end
    def pbParalysisSleepVisualHideHP
      return unless @paralysis_sleep_visual_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @paralysis_sleep_visual_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbParalysisSleepVisualHideHP if @paralysis_sleep_visual_boxes
      super
    end
    def pbParalysisSleepVisual(source,kind)
      sprites,bitmaps = [],[]
      @paralysis_sleep_visual_boxes = {}
      begin
        @briefMessage = false
        pbParalysisSleepVisualHideHP
        ParalysisSleepVisual.play_se(kind)
        bitmaps.concat(ParalysisSleepVisual.assets(kind))
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
        aura.color = kind==:paralysis ? Color.new(255,226,130,200) : Color.new(201,205,247,200)
        if kind==:paralysis
          bolts = Array.new(8) { |i| make.call(bitmaps[i%4],18,32,z+3,0) }
          sparks = Array.new(14) { make.call(bitmaps[4],10,10,z+4,1) }
        else
          bubbles = Array.new(8) { make.call(bitmaps[0],20,20,z+2,0) }
          zeds = Array.new(3) { make.call(bitmaps[1],14,16,z+4,0) }
          stars = Array.new(10) { make.call(bitmaps[2],10,10,z+2,1) }
        end
        duration = kind==:paralysis ? ParalysisSleepVisual::PARALYSIS_DURATION : ParalysisSleepVisual::SLEEP_DURATION
        frames = [(Graphics.frame_rate*duration).round,2].max
        frames.times do |f|
          t = f.to_f/(frames-1)
          fade = [t/0.10,(1-t)/0.18,1.0].min
          if kind==:paralysis
            flash = [0.16,0.43,0.70].map { |at| [1-(t-at).abs/0.10,0].max }.max
            aura.opacity = (flash*fade*95).round
            bolts.each_with_index do |s,i|
              a = i*Math::PI*2/8
              s.bitmap = bitmaps[((t*24).floor+i)%4]
              s.x = cx+Math.cos(a)*radius*0.95
              s.y = foot-height*0.48+Math.sin(a)*height*0.43
              s.zoom_x = 0.46+(i%3)*0.065
              s.zoom_y = 0.48+(i%2)*0.08
              s.angle = Math.cos(a)*22
              s.z = i%3==0 ? z-1 : z+3
              gate = ((t*35).floor+i)%3==0 ? 0.35 : 1.0
              s.opacity = (flash*fade*gate*255).round
            end
            sparks.each_with_index do |s,i|
              a = i*2.399+t*1.4
              s.x = cx+Math.cos(a)*radius*(0.7+i%3*0.12)
              s.y = foot-height*0.48+Math.sin(a)*height*0.52
              s.zoom_x = s.zoom_y = 0.17+i%3*0.075
              s.angle = i*23+t*70
              s.opacity = (flash*fade*235).round
            end
          else
            aura.opacity = (fade*(22+25*Math.sin(t*Math::PI)**2)).round
            bubbles.each_with_index do |s,i|
              p = [[(t-(i%4)*0.075)/0.73,0].max,1].min
              side = i%2==0 ? -1 : 1
              s.x = cx+side*(radius*0.38+p*16)+Math.sin(p*5+i)*7
              s.y = foot-height*0.55-p*(height*0.43+24)+(i%3)*7
              s.zoom_x = s.zoom_y = 0.22+i%3*0.095+p*0.08
              s.opacity = (fade*Math.sin(p*Math::PI)*200).round
              s.z = i%3==0 ? z-1 : z+2
            end
            zeds.each_with_index do |s,i|
              p = [[(t-i*0.16)/0.62,0].max,1].min
              s.x = cx+radius*0.25+p*26+Math.sin(p*4+i)*4
              s.y = foot-height*0.86-p*37
              s.zoom_x = s.zoom_y = 0.35+i*0.075+p*0.07
              s.angle = Math.sin(p*4+i)*7
              s.opacity = (fade*Math.sin(p*Math::PI)*245).round
            end
            stars.each_with_index do |s,i|
              a = i*2.399+t*0.8
              s.x = cx+Math.cos(a)*radius*0.87
              s.y = foot-height*0.55+Math.sin(a)*height*0.45-t*9
              s.zoom_x = s.zoom_y = 0.10+i%3*0.035
              s.opacity = (fade*(0.5+0.5*Math.sin(t*8+i))*105).round
            end
          end
          pbUpdate
        end
      ensure
        boxes = @paralysis_sleep_visual_boxes
        @paralysis_sleep_visual_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(ParalysisSleepVisual::SceneHooks)
