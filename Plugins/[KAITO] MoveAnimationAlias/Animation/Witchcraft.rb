# Witchcraft - Pokemon Essentials v21.1. Move ID: WITCHCRAFT.
# Install in Plugins/[KAITO] Plugin/ and recompile.
# Fairy witch seal -> small luminous dragon-head sigil -> transmutation scales.
# Presentation only. Native move handles Dragon typing and Attack reduction.
module WitchcraftVisual
  VERSION = "3.0"
  MOVE_IDS = [:WITCHCRAFT]
  DURATION = 2.65
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



  # Compact, abstract dragon-head rune; no full-body creature or sprite substitution.
  def self.dragon_sigil
    b=Bitmap.new(96,112)
    shape=[[48,102],[25,88],[22,73],[9,64],[21,58],[18,42],[10,10],
           [30,26],[35,40],[48,34],[61,40],[66,26],[86,10],[78,42],
           [75,58],[87,64],[74,73],[71,88]]
    begin
      polygon(b,shape,Color.new(173,111,223,38))
      paths=[shape+[shape.first],
             [[20,23],[29,45],[35,40]],[[76,23],[67,45],[61,40]],
             [[29,54],[40,59],[34,65]],[[67,54],[56,59],[62,65]],
             [[34,76],[40,84],[48,89],[56,84],[62,76]],
             [[48,47],[43,68],[48,74],[53,68],[48,47]],
             [[37,88],[48,96],[59,88]]]
      paths.each_with_index do |path,i|
        path.each_cons(2) do |p,q|
          line(b,*p,*q,5,Color.new(181,111,236,55))
          line(b,*p,*q,2,i<3 ? Color.new(247,206,255,245) : Color.new(218,248,183,235))
        end
      end
      b
    rescue
      b.dispose unless b.disposed?;raise
    end
  end
  def self.assets
    a=[]
    begin
      seal=Bitmap.new(192,192);a<<seal
      [85,73,36].each_with_index do |r,lane|
        180.times do |i|
          ang=i*Math::PI/90
          seal.fill_rect((96+Math.cos(ang)*r).round,(96+Math.sin(ang)*r).round,2,2,Color.new(221,151+lane*20,243,200))
        end
      end
      pts=Array.new(6) { |i|ang=i*Math::PI/3-Math::PI/2;[96+Math.cos(ang)*68,96+Math.sin(ang)*68] }
      [0,1].each { |start|[start,(start+2)%6,(start+4)%6,start].each_cons(2) { |i,j|line(seal,*pts[i],*pts[j],2,Color.new(209,148,247,210)) } }
      12.times do |i|
        ang=i*Math::PI/6
        x,y=96+Math.cos(ang)*80,96+Math.sin(ang)*80
        line(seal,x-2,y-3,x+2,y+3,2,Color.new(209,249,180,230))
      end
      a<<dragon_sigil
      scale=Bitmap.new(24,30);a<<scale
      polygon(scale,[[2,5],[12,1],[22,5],[20,19],[12,28],[4,19]],Color.new(104,68,147,245))
      polygon(scale,[[4,6],[12,3],[20,6],[17,18],[12,24],[7,18]],Color.new(182,225,159,245))
      line(scale,5,7,12,11,2,Color.new(246,248,200,240))
      line(scale,12,11,19,7,2,Color.new(246,248,200,240))
      spark=Bitmap.new(20,20);a<<spark
      polygon(spark,[[10,0],[12,7],[19,10],[12,12],[10,19],[7,12],[0,10],[7,7]],Color.new(247,202,255,245))
      spark.fill_rect(8,8,4,4,Color.new(255,255,224,255))
      ring=Bitmap.new(144,144);a<<ring
      160.times do |i|
        ang=i*Math::PI/80
        ring.fill_rect((72+Math.cos(ang)*63).round,(72+Math.sin(ang)*63).round,2,2,Color.new(220,248,177,210))
      end
      halo=Bitmap.new(160,160);a<<halo
      (6..72).step(6).to_a.reverse.each do |r|
        (-r..r).each do |y|
          h=Math.sqrt(r*r-y*y).floor
          halo.fill_rect(80-h,80+y,h*2+1,1,Color.new(163,96,210,((1-r/78.0)*17).round))
        end
      end
      veil=Bitmap.new(Graphics.width,Graphics.height);a<<veil
      veil.fill_rect(0,0,Graphics.width,Graphics.height,Color.new(27,16,40,255))
      4.times do |i|
        glyph=Bitmap.new(32,40);a<<glyph
        paths=[[[4,20],[16,4],[28,20],[16,36],[4,20]],
               [[4,6],[16,18],[28,6],[16,18],[16,36]],
               [[5,10],[26,10],[5,30],[26,30]],
               [[6,34],[6,6],[26,6],[26,20],[6,20]]][i]
        paths.each_cons(2) { |p,q|line(glyph,*p,*q,2,Color.new(230,168,255,235)) }
        glyph.fill_rect(14,17,4,5,Color.new(219,250,183,255))
      end
      4.times do |frame|
        flame=Bitmap.new(40,80);a<<flame
        left=[];right=[]
        24.times do |i|
          p=i/23.0;y=75-p*70;x=20+Math.sin(p*7+frame*Math::PI/2)*p*8
          half=(1-p)**0.7*(5+Math.sin(p*Math::PI)*7)
          left<<[x-half,y];right<<[x+half,y]
        end
        polygon(flame,left+right.reverse,Color.new(140,73,191,160))
        polygon(flame,(left+right.reverse).map { |x,y|[20+(x-20)*0.55,75+(y-75)*0.82] },Color.new(223,161,246,195))
      end
      a
    rescue
      a.each { |b|b.dispose unless b.disposed? };raise
    end
  end
  CUES = [[0.07,["PRSFX- Fairy Lock","PRSFX- Trick"],55,105],
          [0.32,["PRSFX- Magic Room","PRSFX- Trick Room","PRSFX- Psychic"],60,100],
          [0.56,["PRSFX- Dragon Pulse","PRSFX- Dragon Breath"],65,120],
          [0.76,["PRSFX- Charm","PRSFX- Fairy Wind"],50,110]]
  def self.sound(cue)
    _,names,volume,pitch=cue
    names.each do |name|
      next unless [".wav",".ogg",".mp3"].any? { |ext|File.file?("Audio/SE/Anim/#{name}#{ext}") }
      pbSEPlay("Anim/#{name}",volume,pitch);break
    end
  end
  module SceneHooks
    def pbAnimation(moveID,user,targets,hitNum=0)
      return super unless WitchcraftVisual::MOVE_IDS.include?(moveID)
      return if @battle && !@battle.showAnims
      return if @witchcraft_boxes
      entries=(targets.is_a?(Array) ? targets : [targets]).compact.select { |b|b.respond_to?(:index) }
      return super if entries.empty?
      entries=entries.uniq { |b|b.index }.select do |b|
        s=@sprites && @sprites["pokemon_#{b.index}"]
        s && !s.disposed? && s.bitmap &&
          !(b.respond_to?(:isCommander?) && b.isCommander?) &&
          !(s.respond_to?(:vanishMode) && s.vanishMode>0)
      end
      return if entries.empty?
      pbWitchcraftVisual(user,entries)
    end
    def pbWitchcraftHideHP
      return unless @witchcraft_boxes && @sprites
      @sprites.each do |key,s|
        next unless key.to_s.start_with?("dataBox_") && s && !s.disposed?
        @witchcraft_boxes[s.object_id]||=[s,s.visible];s.visible=false
      end
    end
    def pbGraphicsUpdate
      pbWitchcraftHideHP if @witchcraft_boxes
      super
    end
    def pbWitchcraftVisual(user,targets)
      sprites,bitmaps=[],[]
      @witchcraft_boxes={}
      begin
        @briefMessage=false;pbWitchcraftHideHP
        bitmaps.concat(WitchcraftVisual.assets)
        seal_b,dragon_b,scale_b,spark_b,ring_b,halo_b,veil_b=bitmaps
        make=proc do |b,ox,oy,z|
          s=Sprite.new(@viewport);sprites<<s;s.bitmap,s.ox,s.oy,s.z=b,ox,oy,z;s.opacity=0;s
        end
        veil=make.call(veil_b,0,0,20_000)
        groups=targets.map do |b|
          src=@sprites["pokemon_#{b.index}"]
          cx=src.x+(src.src_rect.width/2.0-src.ox)*src.zoom_x
          cy=src.y+(src.src_rect.height*0.50-src.oy)*src.zoom_y
          ground=src.y+(src.src_rect.height-src.oy)*src.zoom_y
          size=[[(src.src_rect.height*src.zoom_y+30)/150.0,0.7].max,1.15].min
          {cx:cx,cy:cy,ground:ground,size:size,
           seal:make.call(seal_b,96,96,20_004),dragon:make.call(dragon_b,48,56,20_020),
           halo:make.call(halo_b,80,80,20_005),rings:Array.new(3) {make.call(ring_b,72,72,20_011)},
           glyphs:Array.new(8) { |i|make.call(bitmaps[7+i%4],16,20,20_012)},
           flames:Array.new(8) {make.call(bitmaps[11],20,75,20_014)},
           scales:Array.new(30) {make.call(scale_b,12,15,20_023)},
           sparks:Array.new(32) {make.call(spark_b,10,10,20_018)}}
        end
        cues=WitchcraftVisual::CUES;cue_index=0
        frames=[(Graphics.frame_rate*WitchcraftVisual::DURATION).round,2].max
        frames.times do |f|
          t=f.to_f/(frames-1)
          while cue_index<cues.size && t>=cues[cue_index][0]
            WitchcraftVisual.sound(cues[cue_index]);cue_index+=1
          end
          env=[t/0.14,(1-t)/0.18,1].min;veil.opacity=(env*93).round
          groups.each do |g|
            cx,cy,size=g.values_at(:cx,:cy,:size)
            weave=[[(t-0.06)/0.50,0].max,1].min
            reveal=[[(t-0.37)/0.55,0].max,1].min
            release=[[(t-0.72)/0.28,0].max,1].min
            seal=g[:seal];seal.x,seal.y=cx,g[:ground]
            seal.zoom_x=size*(0.55+weave*0.75);seal.zoom_y=seal.zoom_x*0.34
            seal.opacity=(env*190).round
            halo=g[:halo];halo.x,halo.y=cx,cy;halo.zoom_x=halo.zoom_y=size*1.6
            halo.opacity=(env*(100+Math.sin(reveal*Math::PI)*95)).round
            morph=Math.sin(reveal*Math::PI)**0.65
            dragon=g[:dragon];dragon.x,dragon.y=cx,cy-5*size
            dragon.zoom_x=dragon.zoom_y=size*(0.56+0.10*morph)
            dragon.opacity=(morph*250).round
            g[:rings].each_with_index do |s,i|
              p=(t-0.18-i*0.12)/0.46
              s.x,s.y=cx,cy;s.angle=i*58+t*35
              s.zoom_x=size*(1.55-[p,0].max*0.7);s.zoom_y=s.zoom_x*(i==0 ? 0.8 : 0.30)
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)*205).round : 0
            end
            g[:glyphs].each_with_index do |s,i|
              a=i*Math::PI/4-t*2.2;r=size*(82-weave*22+release*35)
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.80
              s.angle=Math.sin(t*4+i)*12;s.zoom_x=s.zoom_y=size*0.50
              s.opacity=(env*(1-release)*220).round
            end
            g[:flames].each_with_index do |s,i|
              a=i*Math::PI/4+t*1.4
              s.bitmap=bitmaps[11+(f/4+i)%4]
              s.x=cx+Math.cos(a)*size*48;s.y=g[:ground]+Math.sin(a)*size*18
              s.zoom_x=size*0.56;s.zoom_y=size*(0.7+Math.sin(t*18+i)*0.08)
              s.opacity=(env*(1-release)*(90+weave*75)).round
            end
            g[:scales].each_with_index do |s,i|
              p=(t-0.64-i%6*0.025)/0.29
              a=i*2.399;r=15+[p,0].max*(55+i%4*10)
              s.x=cx+Math.cos(a)*r*size
              s.y=cy+Math.sin(a)*r*0.55*size-[p,0].max*34
              s.zoom_x=size*(0.20+i%3*0.07);s.zoom_y=s.zoom_x
              s.angle=i*29+[p,0].max*90
              s.opacity=p>=0 && p<=1 ? (Math.sin(p*Math::PI)**0.6*240).round : 0
            end
            g[:sparks].each_with_index do |s,i|
              p=(t*1.8+i*0.047)%1;a=i*2.399+t*1.2
              r=(1-p)*(85+i%3*12)*size
              s.x=cx+Math.cos(a)*r;s.y=cy+Math.sin(a)*r*0.75
              s.zoom_x=s.zoom_y=0.12+i%4*0.06;s.angle=t*90+i*13
              s.opacity=(Math.sin(p*Math::PI)*env*(1-release)*210).round
            end
          end
          pbUpdate
        end
      ensure
        boxes=@witchcraft_boxes;@witchcraft_boxes=nil
        boxes.each_value { |s,v|s.visible=v if s && !s.disposed? } if boxes
        sprites.reverse_each { |s|s.dispose unless s.disposed? }
        bitmaps.each { |b|b.dispose unless b.disposed? }
      end
    end
  end
end
Battle::Scene.prepend(WitchcraftVisual::SceneHooks)
