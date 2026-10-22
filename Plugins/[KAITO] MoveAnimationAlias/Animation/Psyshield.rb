# Psyshield - Pokemon Essentials v21.1. Move ID PSYSHIELD.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# Crystalline psychic shield assembles around the user, seals and shimmers.
# Presentation only: GiveUserShield handles shield HP and all shield mechanics.
module PsyshieldVisual
  VERSION = "1.0"
  MOVE_IDS = [:PSYSHIELD]
  DURATION = 1.95
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




  SHAPE = [[100,10],[173,38],[180,113],[159,169],[100,225],[41,169],[20,113],[27,38]]
  def self.assets
    a=[]
    begin
      # Eight independent panels share a canvas and meet at one common centre.
      SHAPE.each_with_index do |p,i|
        b=Bitmap.new(200,240);a<<b;q=SHAPE[(i+1)%SHAPE.size]
        polygon(b,[[100,109],p,q],Color.new(139+i%3*16,102+i%2*20,228,72+i%3*8))
        line(b,100,109,*p,1,Color.new(208,184,255,110))
      end
      border=Bitmap.new(200,240);a<<border
      [1.0,0.90].each_with_index do |size,j|
        points=SHAPE.map { |x,y|[100+(x-100)*size,112+(y-112)*size] }
        (points+[points.first]).each_cons(2) do |p,q|
          line(border,*p,*q,j==0 ? 3 : 1,Color.new(221+j*20,188+j*30,255,j==0 ? 230 : 145))
        end
      end
      polygon(border,[[100,70],[120,105],[100,143],[80,105]],Color.new(185,138,247,110))
      [[100,70],[120,105],[100,143],[80,105],[100,70]].each_cons(2) { |p,q|line(border,*p,*q,2,Color.new(236,215,255,235)) }
      polygon(border,[[100,84],[107,105],[100,128],[93,105]],Color.new(255,239,255,235))
      star=Bitmap.new(20,20);a<<star
      polygon(star,[[10,0],[12,7],[19,10],[12,12],[10,19],[7,12],[0,10],[7,7]],Color.new(230,200,255,245))
      star.fill_rect(8,8,4,4,Color.new(255,249,255,255))
      crystal=Bitmap.new(20,32);a<<crystal
      polygon(crystal,[[10,1],[18,15],[10,31],[2,15]],Color.new(147,104,225,240))
      polygon(crystal,[[10,2],[10,16],[3,15]],Color.new(248,209,255,255))
      polygon(crystal,[[10,16],[17,15],[10,29]],Color.new(210,171,253,245))
      ring=Bitmap.new(160,160);a<<ring
      180.times do |i|
        a0=i*Math::PI/90
        ring.fill_rect((80+Math.cos(a0)*70).round,(80+Math.sin(a0)*70).round,2,2,Color.new(220,181,255,205))
      end
      halo=Bitmap.new(160,192);a<<halo
      (8..72).step(8).to_a.reverse.each do |r|
        (-r..r).each do |y|
          h=Math.sqrt(r*r-y*y).floor
          halo.fill_rect(80-h,96+(y*1.15).round,h*2+1,2,Color.new(151,102,222,((1-r/80.0)*14).round))
        end
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(24,20,43,255))
      # Moving reflection is clipped to the shield outline, not a screen-wide flash.
      12.times do |frame|
        shine=Bitmap.new(200,240);a<<shine
        (10..224).each do |y|
          xs=[]
          SHAPE.each_with_index do |p,i|
            q=SHAPE[(i+1)%SHAPE.size]
            next unless (p[1]<=y && q[1]>y) || (q[1]<=y && p[1]>y)
            xs<<p[0]+(y-p[1]).to_f*(q[0]-p[0])/(q[1]-p[1])
          end
          next if xs.size<2
          left,right=xs.minmax
          centre=-160+frame*35+y*0.48
          [[18,Color.new(247,220,255,45)],[7,Color.new(255,244,255,105)]].each do |width,c|
            l=[left,centre-width].max.ceil;r=[right,centre+width].min.floor
            shine.fill_rect(l,y,r-l+1,1,c) if r>=l
          end
        end
      end
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.07,["PRSFX- Light Screen","PRSFX- Calm Mind"],55,110],
          [0.38,["PRSFX- Barrier","PRSFX- Reflect"],68,105],
          [0.64,["PRSFX- Reflect","PRSFX- Light Screen"],58,120]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless PsyshieldVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @psyshield_boxes
      targets=[user] if user && user.respond_to?(:index)
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbPsyshieldVisual(user,entries)
    end
    def pbPsyshieldHideHP
      return unless @psyshield_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @psyshield_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbPsyshieldHideHP if @psyshield_boxes
      super
    end
    def pbPsyshieldVisual(user,targets)
      sprites,bitmaps=[],[]
      @psyshield_boxes={}
      begin
        @briefMessage=false;pbPsyshieldHideHP
        bitmaps.concat(PsyshieldVisual.assets)
        border_b,star_b,crystal_b,ring_b,halo_b,veil_b=bitmaps[8,6]
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        veil=make.call(veil_b,0,0,20_000)
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"]
          cx=src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          cy=src.y+(src.src_rect.height*0.50-src.oy)*src.zoom_y
          size=[[(src.src_rect.height*src.zoom_y+38)/215.0,0.56].max,1.18].min
          {cx:cx,cy:cy,size:size,ground:src.y+(src.src_rect.height-src.oy)*src.zoom_y,
           panels:Array.new(8) { |i|make.call(bitmaps[i],100,112,20_011)},
           border:make.call(border_b,100,112,20_014),shine:make.call(bitmaps[14],100,112,20_015),
           halo:make.call(halo_b,80,96,20_005),
           rings:Array.new(3) {make.call(ring_b,80,80,20_009)},
           motes:Array.new(28) {make.call(star_b,10,10,20_018)},
           crystals:Array.new(16) {make.call(crystal_b,10,16,20_019)}}
        end
        frames=[(Graphics.frame_rate*PsyshieldVisual::DURATION).round,2].max;cue_index=0
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<PsyshieldVisual::CUES.size && t>=PsyshieldVisual::CUES[cue_index][0]
            PsyshieldVisual.sound(PsyshieldVisual::CUES[cue_index]);cue_index+=1
          end
          env=[t/0.12,(1-t)/0.20,1].min;veil.opacity=(env*55).round
          groups.each do |g|
            cx,cy,size=g.values_at(:cx,:cy,:size)
            formed=[[(t-0.15)/0.33,0].max,1].min
            release=[[(t-0.83)/0.17,0].max,1].min
            g[:panels].each_with_index do |s,i|
              p=[[(t-0.12-i*0.022)/0.22,0].max,1].min
              eased=1-(1-p)**3
              angle=i*Math::PI/4-Math::PI/2
              dist=(1-eased)*58*size
              s.x=cx+Math.cos(angle)*dist;s.y=cy+Math.sin(angle)*dist+release*4
              s.zoom_x=s.zoom_y=size*(0.84+eased*0.16+release*0.07)
              s.opacity=(p*env*255).round
            end
            border=g[:border];border.x,border.y=cx,cy+release*4
            border.zoom_x=border.zoom_y=size*(1+release*0.07)
            border.opacity=(formed*env*255).round
            shine=g[:shine]
            phase=[[(t-0.48)/0.33,0].max,0.999].min
            shine.bitmap=bitmaps[14+(phase*12).floor]
            shine.x,shine.y=border.x,border.y;shine.zoom_x,shine.zoom_y=border.zoom_x,border.zoom_y
            shine.opacity=t>=0.48 && t<0.81 ? 245 : 0
            halo=g[:halo];halo.x,halo.y=cx,cy
            halo.zoom_x=halo.zoom_y=size*(1.35+Math.sin(t*Math::PI)*0.25)
            halo.opacity=(env*(70+formed*80)).round
            g[:rings].each_with_index do |s,i|
              p=(t-[0.08,0.48,0.65][i])/0.28
              s.x=cx;s.y=i==0 ? g[:ground] : cy
              s.zoom_x=size*(0.55+[p,0].max*1.25)
              s.zoom_y=s.zoom_x*(i==0 ? 0.27 : 1.05)
              s.opacity=p>=0 && p<=1 ? ((1-p)*formed*190).round : 0
            end
            g[:motes].each_with_index do |s,i|
              p=(t-0.02-i%7*0.023)/0.33
              a=i*2.399;r=(1-[[p,0].max,1].min)*(70+i%4*13)*size
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*1.1
              s.zoom_x=s.zoom_y=0.12+i%4*0.055;s.angle=i*19+t*65
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)**0.5*230).round : 0
            end
            g[:crystals].each_with_index do |s,i|
              p=(t-0.49-i%4*0.025)/0.35;a=i*Math::PI/8
              r=(65+[p,0].max*25)*size
              s.x=cx+Math.cos(a)*r*0.82;s.y=cy+Math.sin(a)*r*1.1-[p,0].max*15
              s.zoom_x=s.zoom_y=size*(0.21+i%3*0.055)
              s.angle=-a*180/Math::PI+90
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*215).round : 0
            end
          end
          pbUpdate
        end
      ensure
        boxes=@psyshield_boxes;@psyshield_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(PsyshieldVisual::SceneHooks)
