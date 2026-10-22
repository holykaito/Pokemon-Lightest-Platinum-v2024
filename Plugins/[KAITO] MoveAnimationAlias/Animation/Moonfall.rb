# Moonfall - Pokemon Essentials v21.1. Move ID: MOONFALL.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# One global lunar descent and impact, including the user and every on-field battler.
# Presentation only: no damage/accuracy/protection/HP calculation hooks.
module MoonfallVisual
  VERSION = "1.0"
  MOVE_IDS = [:MOONFALL]
  DURATION = 4.05
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

  def self.ellipse(b,cx,cy,rx,ry,c)
    (-ry.ceil..ry.ceil).each do |y|
      q=1-(y/ry.to_f)**2;next if q<0
      half=(Math.sqrt(q)*rx).floor
      b.fill_rect((cx-half).round,(cy+y).round,half*2+1,1,c)
    end
  end
  def self.assets
    a=[]
    begin
      moon=Bitmap.new(256,256);a<<moon
      244.times do |i|
        y=i-122;half=Math.sqrt([122*122-y*y,0].max).floor
        (-half..half).step(2) do |x|
          light=Math.sqrt([1-(x*x+y*y)/14884.0,0].max)
          shade=[[0.45+light*0.48-x/620.0-y/1200.0,0].max,1].min
          grain=((x*73+y*37)%13)-6
          moon.fill_rect(128+x,128+y,2,1,Color.new((94+shade*151+grain).round,(105+shade*140+grain).round,(139+shade*114+grain).round,255))
        end
      end
      23.times do |i|
        angle=i*2.399;r=20+(i*29)%77
        x=128+Math.cos(angle)*r;y=128+Math.sin(angle)*r
        size=5+(i*7)%12
        ellipse(moon,x,y,size,size*0.66,Color.new(177,176,205,235))
        ellipse(moon,x+1,y+2,size*0.78,size*0.46,Color.new(114,125,160,220))
        ellipse(moon,x-2,y-2,size*0.65,size*0.26,Color.new(222,221,236,225))
      end
      ring=Bitmap.new(192,192);a<<ring
      240.times do |i|
        ang=i*Math::PI/120
        ring.fill_rect((96+Math.cos(ang)*88).round,(96+Math.sin(ang)*88).round,3,2,Color.new(236,222,255,220))
      end
      star=Bitmap.new(24,24);a<<star
      polygon(star,[[12,0],[14,9],[23,12],[14,14],[12,23],[9,14],[0,12],[9,9]],Color.new(241,222,255,235))
      star.fill_rect(10,10,4,4,Color.new(255,251,232,255))
      chip=Bitmap.new(40,48);a<<chip
      polygon(chip,[[4,14],[22,2],[36,16],[33,39],[12,46],[1,30]],Color.new(100,105,137,245))
      polygon(chip,[[4,14],[22,2],[36,16],[19,25]],Color.new(221,216,229,255))
      polygon(chip,[[4,14],[19,25],[12,46],[1,30]],Color.new(155,156,183,255))
      trail=Bitmap.new(12,160);a<<trail
      polygon(trail,[[6,0],[11,143],[6,159],[1,143]],Color.new(189,172,229,130))
      polygon(trail,[[6,25],[8,148],[6,159],[4,148]],Color.new(254,235,224,220))
      puff=Bitmap.new(96,72);a<<puff
      [[46,32,28],[22,42,18],[69,40,22],[43,21,18]].each do |cx,cy,r|
        ellipse(puff,cx,cy,r,r*0.8,Color.new(185,180,195,105))
      end
      crater=Bitmap.new(384,192);a<<crater
      ellipse(crater,192,96,175,64,Color.new(52,44,64,145))
      ellipse(crater,192,96,148,45,Color.new(40,35,55,150))
      17.times do |i|
        ang=i*Math::PI*2/17
        pts=Array.new(5) do |j|
          r=30+j*39
          [192+Math.cos(ang+j%2*0.12)*r,96+Math.sin(ang+j%2*0.12)*r*0.45]
        end
        pts.each_cons(2) do |p,q|
          line(crater,*p,*q,4,Color.new(54,44,66,230))
          line(crater,p[0],p[1]+2,q[0],q[1]+2,1,Color.new(225,206,226,170))
        end
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(13,14,39,255))
      flash=Bitmap.new(Graphics.width,Graphics.height);a<<flash
      flash.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(255,242,227,255))
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.04,["PRSFX- Moonblast1","PRSFX- Cosmic Power"],65,65],
          [0.25,["PRSFX- Draco Meteor1","PRSFX- Moonblast1"],76,75],
          [0.45,["PRSFX- Draco Meteor2","PRSFX- Earth Power"],85,70],
          [0.57,["PRSFX- Explosion","PRSFX- Earthquake"],100,70],
          [0.67,["PRSFX- Earthquake","PRSFX- Rock Slide"],85,60]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless MoonfallVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @moonfall_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      # Gather the whole field once, rather than replaying the descent per target.
      field=if @battle && @battle.respond_to?(:battlers)
              @battle.battlers.compact.select { |b|b.respond_to?(:index) && !(b.respond_to?(:fainted?) && b.fainted?) }
            else
              entries+[user].compact.select { |b|b.respond_to?(:index) }
            end
      entries=(field+entries).uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbMoonfallVisual(user,entries)
    end
    def pbMoonfallHideHP
      return unless @moonfall_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @moonfall_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbMoonfallHideHP if @moonfall_boxes
      super
    end
    def pbMoonfallVisual(user,targets)
      sprites,bitmaps,hidden=[],[],{}
      @moonfall_boxes={}
      view_state=(@viewport && @viewport.respond_to?(:ox)) ? [@viewport.ox,@viewport.oy] : nil
      begin
        @briefMessage=false;pbMoonfallHideHP
        bitmaps.concat(MoonfallVisual.assets)
        moon_b,ring_b,star_b,chip_b,trail_b,puff_b,crater_b,veil_b,flash_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        veil=make.call(veil_b,0,0,20_000);flash=make.call(flash_b,0,0,20_050)
        moon=make.call(moon_b,128,128,20_020)
        corona=Array.new(3) {make.call(ring_b,96,96,20_018)}
        stars=Array.new(80) {make.call(star_b,12,12,20_004)}
        meteors=Array.new(24) {make.call(trail_b,6,160,20_022)}
        waves=Array.new(6) {make.call(ring_b,96,96,20_032)}
        fragments=Array.new(64) {make.call(chip_b,20,24,20_035)}
        dust=Array.new(24) {make.call(puff_b,48,36,20_039)}
        crater=make.call(crater_b,192,96,20_006)
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"];bitmap=src.bitmap.clone;bitmaps<<bitmap
          copy=make.call(bitmap,src.ox,src.oy,20_010)
          copy.src_rect.set(src.src_rect.x,src.src_rect.y,src.src_rect.width,src.src_rect.height)
          copy.x,copy.y=src.x,src.y;copy.zoom_x,copy.zoom_y=src.zoom_x,src.zoom_y
          copy.mirror,copy.visible,copy.opacity=src.mirror,src.visible,src.opacity
          copy.color=src.color.clone;copy.tone=src.tone.clone if src.respond_to?(:tone)
          hidden[src.object_id]=[src,src.visible];src.visible=false
          {copy:copy,x:src.x,y:src.y,color:src.color.clone,
           cx:src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x,
           cy:src.y+(src.src_rect.height/2.0-src.oy)*src.zoom_y,
           ring:make.call(ring_b,96,96,20_031),
           sparks:Array.new(10) {make.call(star_b,12,12,20_036)}}
        end
        w,h=Graphics.width.to_f,Graphics.height.to_f;cx=w*0.50;impact_y=h*0.63
        scale=[w/512.0,h/384.0].min
        frames=[(Graphics.frame_rate*MoonfallVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<MoonfallVisual::CUES.size && t>=MoonfallVisual::CUES[cue_index][0]
            MoonfallVisual.sound(MoonfallVisual::CUES[cue_index]);cue_index+=1
          end
          env=[t/0.12,(1-t)/0.20,1].min
          fall=[[(t-0.10)/0.47,0].max,1].min
          impact=[[(t-0.57)/0.43,0].max,1].min
          veil.opacity=(env*(150+fall*35)).round
          flash.opacity=t>=0.57 && t<0.67 ? ((1-(t-0.57)/0.10)*220).round : 0
          shake=t>=0.57 ? (1-impact)**1.5*13 : (t>0.43 ? (t-0.43)*15 : 0)
          if view_state
            @viewport.ox=view_state[0]+(Math.sin(f*2.4)*shake).round
            @viewport.oy=view_state[1]+(Math.cos(f*2.9)*shake*0.8).round
          end
          moon.x=cx+Math.sin(fall*Math::PI)*w*0.04
          moon.y=-h*0.13+fall*fall*h*0.64
          size=(0.46+fall*1.62)*scale
          moon.zoom_x=moon.zoom_y=size;moon.angle=t*8
          moon.opacity=t<0.57 ? ([t/0.12,1].min*255).round : ([(0.67-t)/0.10,0].max*255).round
          corona.each_with_index do |s,i|
            s.x,s.y=moon.x,moon.y;s.zoom_x=s.zoom_y=size*(1.55+i*0.22)
            s.angle=t*(i.even? ? 10 : -10)
            s.opacity=(moon.opacity*(0.30-i*0.07)).round
          end
          stars.each_with_index do |s,i|
            x=(i*137.53)%w;y=(i*73.21)%(h*0.85)
            s.x=x;s.y=y+fall*fall*20
            s.zoom_x=s.zoom_y=(0.10+i%4*0.05)*scale
            s.opacity=(env*(t<0.57 ? 0.4+Math.sin(t*7+i).abs*0.5 : (1-impact)*0.65)*210).round
          end
          meteors.each_with_index do |s,i|
            p=(t*2.5+i*0.107)%1
            s.x=(i*97.7)%w;s.y=-40+p*(h+100)
            s.angle=-8;s.zoom_x=scale*(0.30+i%3*0.08);s.zoom_y=scale*(0.35+fall*0.55)
            s.opacity=t>=0.22 && t<0.57 ? (Math.sin(p*Math::PI)*fall*200).round : 0
          end
          crater.x,crater.y=cx,impact_y+h*0.06
          crater.zoom_x=w/320.0;crater.zoom_y=h/310.0
          crater.opacity=t>=0.57 ? (env*185).round : 0
          waves.each_with_index do |s,i|
            p=(t-0.57-i*0.047)/0.24
            s.x,s.y=cx,impact_y
            s.zoom_x=(0.2+[p,0].max*6.6)*scale
            s.zoom_y=s.zoom_x*(i.even? ? 0.44 : 0.85)
            s.opacity=p>=0 && p<=1 ? ((1-p)**0.5*230).round : 0
          end
          fragments.each_with_index do |s,i|
            p=(t-0.57-i%5*0.009)/0.39;a=i*2.399
            r=20+[p,0].max*(130+i%7*38)*scale
            s.x=cx+Math.cos(a)*r
            s.y=impact_y+Math.sin(a)*r*0.65-[p,0].max*120*scale+[p,0].max**2*180*scale
            size=(0.20+i%5*0.13)*scale
            s.zoom_x=s.zoom_y=size;s.angle=i*31+[p,0].max*(i.even? ? 220 : -220)
            s.opacity=p>=0 && p<=1 ? ((1-p)**0.65*255).round : 0
          end
          dust.each_with_index do |s,i|
            p=(t-0.59-i%4*0.018)/0.37
            direction=i.even? ? 1 : -1
            s.x=cx+direction*(12+[p,0].max*(100+i%6*35))*scale
            s.y=impact_y+20+i%3*14-[p,0].max*(20+i%4*13)*scale
            size=scale*(0.45+[p,0].max*(1.5+i%3*0.25))
            s.zoom_x=size*1.15;s.zoom_y=size*0.70
            s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)**0.6*210).round : 0
          end
          groups.each do |g|
            g[:copy].x=g[:x]+Math.sin(f*2.5)*shake*0.25
            g[:copy].y=g[:y]+Math.cos(f*2.6)*shake*0.22
            g[:copy].color=t>=0.57 && t<0.71 ? Color.new(245,226,255,((0.71-t)/0.14*185).round) : g[:color]
            p=(t-0.57)/0.22
            s=g[:ring];s.x,s.y=g[:cx],g[:cy];s.zoom_x=s.zoom_y=0.15+[p,0].max*1.1
            s.opacity=p>=0 && p<=1 ? ((1-p)*245).round : 0
            g[:sparks].each_with_index do |s,i|
              a=i*2.399;r=10+[p,0].max*(35+i%3*18)
              s.x=g[:cx]+Math.cos(a)*r;s.y=g[:cy]+Math.sin(a)*r
              s.zoom_x=s.zoom_y=0.16+i%3*0.10;s.angle=i*23+t*90
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*240).round : 0
            end
          end
          hidden.each_value { |s,_|s.visible=false unless s.disposed? };pbUpdate
        end
      ensure
        @viewport.ox,@viewport.oy=view_state if view_state
        boxes=@moonfall_boxes;@moonfall_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        hidden.each_value { |s,v|s.visible=v if s && !s.disposed? }
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(MoonfallVisual::SceneHooks)
