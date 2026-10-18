# Bleed common animation - Pokemon Essentials v21.1.
# Install in Plugins/[KAITO] Plugin/. Replaces Common:Bleed only.
# Call: battle.pbCommonAnimation("Bleed", battler).
# Presentation only: does not inflict Bleed, deduct HP or change healing rules.
module BleedVisual
  VERSION = "1.0"
  DURATION = 1.10
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
    owned=[]
    begin
      drop=Bitmap.new(18,30);owned<<drop
      polygon(drop,[[9,1],[13,13],[16,19],[15,24],[12,28],[6,28],[2,23],[3,17],[6,11]],Color.new(111,12,33,255))
      polygon(drop,[[9,5],[11,15],[14,20],[12,25],[7,25],[4,21],[6,16]],Color.new(208,27,52,255))
      drop.fill_rect(7,17,2,5,Color.new(245,92,105,235))
      drop.fill_rect(8,16,1,2,Color.new(255,164,168,235))
      trail=Bitmap.new(12,64);owned<<trail
      60.times do |y|
        p=y/59.0
        width=[1,(Math.sin(p*Math::PI)*3).round].max
        alpha=(Math.sin(p*Math::PI)**0.55*225).round
        x=6+(Math.sin(p*7)*1.1).round
        trail.fill_rect(x-width,y+2,width*2,1,Color.new(143,15,39,alpha))
        trail.fill_rect(x,y+2,1,1,Color.new(227,48,69,(alpha*0.9).round))
      end
      bead=Bitmap.new(10,12);owned<<bead
      disc(bead,5,7,3,Color.new(128,10,30,255))
      disc(bead,5,6,2,Color.new(221,39,61,255))
      bead.fill_rect(4,4,1,2,Color.new(255,127,143,235))
      stain=Bitmap.new(40,32);owned<<stain
      disc(stain,19,17,12,Color.new(97,12,28,200))
      disc(stain,21,16,10,Color.new(161,16,40,235))
      disc(stain,14,14,7,Color.new(185,26,48,225))
      [[4,9,2],[34,19,2],[8,26,2],[30,5,1],[35,9,1]].each do |x,y,r|
        disc(stain,x,y,r,Color.new(157,15,38,235))
      end
      line_colour=Color.new(226,56,74,185)
      stain.fill_rect(15,10,10,2,line_colour)
      owned
    rescue
      owned.each { |b|b.dispose unless b.disposed? }
      raise
    end
  end
  def self.play_se
    ["PRSFX- Leech Life1","PRSFX- Absorb1","PRSFX- Poison"].each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",62,85)
      break
    end
  end
  module SceneHooks
    def pbCommonAnimationExists?(name)
      return true if name.to_s.downcase=="bleed"
      super
    end
    def pbCommonAnimation(name,user=nil,target=nil)
      return super unless name.to_s.downcase=="bleed"
      return if @battle && !@battle.showAnims
      battler = user || (target.is_a?(Array) ? target[0] : target)
      return super unless battler && battler.respond_to?(:index)
      return if battler.respond_to?(:isCommander?) && battler.isCommander?
      source = @sprites["pokemon_#{battler.index}"]
      return super unless source && !source.disposed? && source.bitmap
      return if source.respond_to?(:vanishMode) && source.vanishMode>0
      return if @bleed_visual_boxes
      pbBleedVisual(source)
    end
    def pbBleedVisualHideHP
      return unless @bleed_visual_boxes && @sprites
      @sprites.each do |key,sprite|
        next unless key.to_s.start_with?("dataBox_") && sprite && !sprite.disposed?
        @bleed_visual_boxes[sprite.object_id] ||= [sprite,sprite.visible]
        sprite.visible = false
      end
    end
    def pbGraphicsUpdate
      pbBleedVisualHideHP if @bleed_visual_boxes
      super
    end
    def pbBleedVisual(source)
      sprites,bitmaps = [],[]
      @bleed_visual_boxes = {}
      begin
        @briefMessage = false
        pbBleedVisualHideHP
        BleedVisual.play_se
        bitmaps.concat(BleedVisual.assets)
        drop_b,trail_b,bead_b,stain_b=bitmaps
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
        # Normal alpha blending preserves a deep blood red, rather than a pink glow.
        drops=Array.new(14) {make.call(drop_b,9,27,z+4,0)}
        trails=Array.new(8) {make.call(trail_b,6,2,z+3,0)}
        beads=Array.new(20) {make.call(bead_b,5,7,z+5,0)}
        stains=Array.new(5) {make.call(stain_b,20,16,z-1,0)}
        frames=[(Graphics.frame_rate*BleedVisual::DURATION).round,2].max
        frames.times do |f|
          t=f.to_f/(frames-1)
          fade=[t/0.10,(1-t)/0.20,1.0].min
          trails.each_with_index do |s,i|
            start=0.045+(i%4)*0.055+(i/4)*0.13
            p=[[(t-start)/0.58,0].max,1].min
            a=i*2.399
            s.x=cx+Math.cos(a)*radius*0.64
            origin=foot-height*(0.30+(i%4)*0.13)
            s.y=origin+p*height*0.18
            s.zoom_x=0.52+i%3*0.10
            s.zoom_y=(0.20+p*0.42)*height/115.0
            s.angle=Math.sin(i)*4
            s.opacity=(fade*Math.sin(p*Math::PI)*230).round
          end
          drops.each_with_index do |s,i|
            start=0.04+(i%7)*0.04+(i/7)*0.19
            p=[[(t-start)/0.48,0].max,1].min
            a=i*2.399
            origin=foot-height*(0.32+(i%4)*0.13)
            s.x=cx+Math.cos(a)*radius*(0.36+i%3*0.19)+Math.sin(i)*p*4
            s.y=origin+(foot+2-origin)*(p*p*0.78+p*0.22)
            size=0.33+i%4*0.075
            s.zoom_x=size*(1-p*0.16)
            s.zoom_y=size*(0.85+p*0.65)
            s.angle=Math.sin(i)*5
            s.opacity=p>0 && p<1 ? (fade*250).round : 0
          end
          beads.each_with_index do |s,i|
            start=i<10 ? 0.15 : 0.43
            p=[[(t-start-(i%5)*0.015)/0.29,0].max,1].min
            a=(i%10)*Math::PI*2/10
            origin_y=foot-height*(i<10 ? 0.61 : 0.40)
            s.x=cx+Math.cos(a)*(7+p*(radius*0.63))
            s.y=origin_y+Math.sin(a)*p*15+p*p*28
            s.zoom_x=s.zoom_y=0.30+i%3*0.12
            s.angle=i*29+p*120
            s.opacity=(fade*Math.sin(p*Math::PI)*(1-p*0.4)*235).round
          end
          stains.each_with_index do |s,i|
            p=[[(t-0.40-i*0.045)/0.23,0].max,1].min
            size=0.22+i%3*0.085
            s.x=cx+(i-2)*radius*0.33
            s.y=foot+3+Math.sin(i*2.4)*3
            s.zoom_x=size*(0.6+p*0.7)
            s.zoom_y=size*0.36*(0.6+p*0.7)
            s.opacity=(fade*Math.sin(p*Math::PI/2)*225).round
          end
          pbUpdate
        end
      ensure
        boxes = @bleed_visual_boxes
        @bleed_visual_boxes = nil
        boxes.each_value { |s,v| s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s| s.dispose unless s.disposed? }
        bitmaps.each { |b| b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(BleedVisual::SceneHooks)
