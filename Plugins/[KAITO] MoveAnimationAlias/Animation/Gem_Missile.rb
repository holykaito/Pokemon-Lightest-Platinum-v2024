# Gem Missile - Pokemon Essentials v21.1. Move ID GEMMISSILE.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# Fast faceted gem projectile, refracted light trail and prismatic crystal impact.
# Presentation only: original move handles priority and its single damage hit.
module GemMissileVisual
  VERSION = "1.0"
  MOVE_IDS = [:GEMMISSILE]
  DURATION = 1.35
  def self.polygon(b,points,c)
    low,high=points.map { |p|p[1] }.minmax
    (low.floor..high.ceil).each do |y|
      xs=[]
      points.each_with_index do |p,i|
        q=points[(i+1)%points.length]
        next unless (p[1]<=y && q[1]>y) || (q[1]<=y && p[1]>y)
        xs<<p[0]+(y-p[1]).to_f*(q[0]-p[0])/(q[1]-p[1])
      end
      xs.sort.each_slice(2) { |l,r|b.fill_rect(l.ceil,y,[r.floor-l.ceil+1,1].max,1,c) if r }
    end
  end
  def self.line(b,x1,y1,x2,y2,width,c)
    n=[(x2-x1).abs.round,(y2-y1).abs.round,1].max
    (0..n).each do |i|
      p=i.to_f/n
      b.fill_rect((x1+(x2-x1)*p).round-width/2,(y1+(y2-y1)*p).round-width/2,width,width,c)
    end
  end


  def self.assets
    a=[]
    begin
      palettes=[[[84,57,139],[219,170,252],[86,157,230],[177,223,255]],
                [[37,106,155],[154,233,251],[78,160,220],[222,250,255]],
                [[141,101,49],[255,224,160],[217,153,85],[255,248,220]]]
      palettes.each do |dark,lit,side,core|
        gem=Bitmap.new(44,68);a<<gem
        polygon(gem,[[22,1],[41,21],[35,51],[22,66],[9,51],[3,21]],Color.new(*dark,255))
        polygon(gem,[[22,3],[22,24],[5,21]],Color.new(*lit,255))
        polygon(gem,[[22,3],[39,21],[22,24]],Color.new(*side,255))
        polygon(gem,[[5,23],[20,27],[20,61],[10,49]],Color.new(*side,255))
        polygon(gem,[[24,27],[39,23],[34,49],[24,61]],Color.new(*lit,255))
        polygon(gem,[[22,7],[27,26],[22,61],[17,26]],Color.new(*core,245))
        line(gem,22,7,22,58,1,Color.new(255,251,255,255))
        line(gem,7,22,21,26,1,Color.new(255,231,252,230))
        line(gem,23,26,37,22,1,Color.new(224,247,255,230))
      end
      star=Bitmap.new(20,20);a<<star
      polygon(star,[[10,0],[12,7],[19,10],[12,12],[10,19],[7,12],[0,10],[7,7]],Color.new(227,222,255,245))
      star.fill_rect(8,8,4,4,Color.new(255,253,233,255))
      trail=Bitmap.new(144,12);a<<trail
      [[5,Color.new(178,119,237,95)],[2,Color.new(184,230,255,210)]].each do |width,col|
        polygon(trail,[[0,6],[126,6-width],[143,6],[126,6+width]],col)
      end
      halo=Bitmap.new(80,80);a<<halo
      80.times do |y|
        80.times do |x|
          r=((x-39.5)**2+(y-39.5)**2)/1560.25;next if r>1
          alpha=((Math.exp(-r*4)-Math.exp(-4))/(1-Math.exp(-4))*80).round
          halo.fill_rect(x,y,1,1,Color.new(174,182,255,alpha)) if alpha>0
        end
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(23,23,43,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.07,["PRSFX- Power Gem1","PRSFX- Ancient Power1"],50,125],
          [0.27,["PRSFX- Swift1","PRSFX- Power Gem1"],65,135],
          [0.50,["PRSFX- Ancient Power2","PRSFX- Power Gem1"],77,125]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless GemMissileVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @gem_missile_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbGemMissileVisual(user,entries)
    end
    def pbGemMissileHideHP
      return unless @gem_missile_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @gem_missile_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbGemMissileHideHP if @gem_missile_boxes
      super
    end
    def pbGemMissileVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @gem_missile_boxes={}
      begin
        @briefMessage=false;pbGemMissileHideHP
        bitmaps.concat(GemMissileVisual.assets)
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        src=user && user.respond_to?(:index) && @sprites["pokemon_#{user.index}"]
        src=nil if src && (src.disposed? || !src.bitmap)
        first=@sprites["pokemon_#{targets[0].index}"]
        sx=src ? src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x : Graphics.width-first.x
        sy=src ? src.y+(src.src_rect.height*0.50-src.oy)*src.zoom_y : Graphics.height*0.5
        veil=make.call(bitmaps[6],0,0,20_000)
        gather=Array.new(12) { |i|make.call(bitmaps[i%3],22,34,20_012)}
        groups=targets.map do |b|
          target=@sprites["pokemon_#{b.index}"]
          bmp=target.bitmap.clone;bitmaps<<bmp;copy=make.call(bmp,target.ox,target.oy,20_006)
          copy.src_rect.set(target.src_rect.x,target.src_rect.y,target.src_rect.width,target.src_rect.height)
          copy.x,copy.y=target.x,target.y;copy.zoom_x,copy.zoom_y=target.zoom_x,target.zoom_y
          copy.mirror,copy.visible,copy.opacity=target.mirror,target.visible,target.opacity
          copy.color=target.color.clone;copy.tone=target.tone.clone if target.respond_to?(:tone)
          hidden[target.object_id]=[target,target.visible];target.visible=false
          cx=target.x+(target.src_rect.width/2.0-target.ox)*target.zoom_x
          cy=target.y+(target.src_rect.height/2.0-target.oy)*target.zoom_y
          {copy:copy,x:target.x,y:target.y,cx:cx,cy:cy,color:target.color.clone,
           gem:make.call(bitmaps[0],22,34,20_020),halo:make.call(bitmaps[5],40,40,20_008),
           trails:Array.new(4) {make.call(bitmaps[4],144,6,20_014)},
           chips:Array.new(36) { |i|make.call(bitmaps[i%3],22,34,20_025)},
           glints:Array.new(18) {make.call(bitmaps[3],10,10,20_027)}}
        end
        frames=[(Graphics.frame_rate*GemMissileVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<GemMissileVisual::CUES.size && t>=GemMissileVisual::CUES[cue_index][0]
            GemMissileVisual.sound(GemMissileVisual::CUES[cue_index]);cue_index+=1
          end
          veil.opacity=([t/0.12,(1-t)/0.20,1].min*45).round
          gather.each_with_index do |s,i|
            p=(t-0.015-i%4*0.018)/0.22;a=i*2.399+p*2.8
            r=(1-[[p,0].max,1].min)*41
            s.x=sx+Math.cos(a)*r;s.y=sy+Math.sin(a)*r*0.8
            s.zoom_x=s.zoom_y=0.14+i%3*0.025;s.angle=i*31+p*110
            s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)**0.4*235).round : 0
          end
          groups.each do |g|
            cx,cy=g.values_at(:cx,:cy);dx,dy=cx-sx,cy-sy
            theta=Math.atan2(dy,dx);angle=-theta*180/Math::PI
            q=[[(t-0.27)/0.23,0].max,1].min
            travel=q**1.35
            gem=g[:gem];gem.x=sx+dx*travel;gem.y=sy+dy*travel-Math.sin(travel*Math::PI)*12
            gem.angle=angle-90
            formation=[[(t-0.10)/0.17,0].max,1].min
            gem.zoom_x=0.30+formation*0.32;gem.zoom_y=0.30+formation*0.42
            gem.opacity=t>=0.10 && t<0.50 ? (formation*255).round : 0
            g[:trails].each_with_index do |s,i|
              p=(t-0.27-i*0.014)/0.23
              v=[[p,0].max,1].min**1.35
              s.x=sx+dx*v;s.y=sy+dy*v-Math.sin(v*Math::PI)*12+(i-1.5)*2
              s.angle=angle;s.zoom_x=0.32+i*0.07;s.zoom_y=0.40-i*0.055
              s.opacity=t>=0.27 && t<0.55 && p>=0 && p<=1 ? (175-i*30) : 0
            end
            impact=[[(t-0.50)/0.37,0].max,1].min
            halo=g[:halo];halo.x,halo.y=cx,cy;halo.zoom_x=halo.zoom_y=0.45+impact*1.7
            halo.opacity=t>=0.50 ? ((1-impact)**1.3*230).round : 0
            shake=t>=0.50 ? (1-impact)*4 : 0
            g[:copy].x=g[:x]+Math.sin(f*2.6)*shake;g[:copy].y=g[:y]+Math.cos(f*2.3)*shake*0.4
            g[:copy].color=t>=0.50 && t<0.60 ? Color.new(223,226,255,((0.60-t)/0.10*130).round) : g[:color]
            g[:chips].each_with_index do |s,i|
              p=(t-0.50-i%4*0.007)/0.36;a=i*2.399
              r=5+[p,0].max*(33+i%5*17)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.75+[p,0].max**2*28
              s.zoom_x=s.zoom_y=0.09+i%4*0.035;s.angle=i*29+[p,0].max*(i.even? ? 150 : -150)
              s.opacity=p>=0 && p<=1 ? ((1-p)**0.55*250).round : 0
            end
            g[:glints].each_with_index do |s,i|
              p=(t-0.51-i%3*0.022)/0.25;a=i*2.399
              r=10+[p,0].max*(24+i%4*14)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.74
              s.zoom_x=s.zoom_y=0.14+i%3*0.08;s.angle=i*17+t*60
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)**1.5*235).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        boxes=@gem_missile_boxes;@gem_missile_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(GemMissileVisual::SceneHooks)
