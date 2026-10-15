MOVE ANIMATION ALIAS 2.0 - Pokemon Essentials v21.1

CAI DAT
1. Xoa ban plugin Move Animation Alias 1.0 cu (ca file Ruby cu).
2. Chep thu muc MoveAnimationAlias trong Plugins cua goi nay vao Plugins cua game.
   Chi giu mot ban plugin. Khong chep de v2 vao thu muc van con file v1 ten khac.
3. Them dong Animation vao section cua move trong PBS/moves*.txt.
4. Khoi dong game o Debug va giu Ctrl de buoc compile lai plugins/PBS.

CU PHAP
Animation = ENDURE
  Muon animation cua Endure nhu v1.

Animation = HYPERFANG,INGRAIN
  Hai animation bat dau cung mot thoi diem va chay trong cung mot vong update.
  Moi animation giu nguyen thoi luong va thoi diem hieu ung/am thanh goc.

Animation = HYPERFANG,INGRAIN@Target
  Nhu tren, nhung doi vai user/target RIENG cho Ingrain.
  Hieu ung Ingrain von o phia user duoc chuyen sang phia target.
  @Target doi vai cho toan bo animation do, khong chi mot nhom hat.
  @User hoac khong co hau to: giu huong goc.

QUY TAC
- Neu move da co animation rieng thi van uu tien animation rieng.
- Bo qua Animation hoan toan neu khong can muon/ket hop.
- Animation dau tien hop le dieu khien sprite Pokemon.
- Animation thu hai tro di khong dieu khien truc tiep hai sprite Pokemon that;
  chung van hien particles, timings, am thanh, background va foreground.
- Chi muon animation da duoc gan cho move nguon trong Animation Editor.
- Muc sai cu phap/ID hoac thieu animation se bi bo qua. Neu tat ca deu thieu,
  game quay ve cach tim animation mac dinh.
- Trong doubles/triples, giong engine goc, animation su dung target dau tien.
- Hai am thanh co the chong nhau. Background/foreground dac cua mot animation
  co the che animation con lai; plugin khong tu bien tap lai noi dung hinh anh.
- Dung chung thoi diem bat dau khong co nghia cac hieu ung noi bo deu xuat hien
  ngay frame dau: moi animation van giu timeline goc.
- Chi thay doi hinh anh/am thanh, khong ap dung hieu ung chien dau cua move nguon.

KIEM TRA
Da doi chieu voi GameData::Move, PBAnimationPlayerX va Battle::Scene trong repo,
bao gom phan an/hien databox cua Deluxe Battle Kit. Da kiem tra cu phap Ruby.
Chua chay kiem thu hinh anh trong RPG Maker XP/mkxp-z.
Sau cai dat, thu move o ca hai phe, voi doi thu co Substitute va trong doubles;
kiem tra sprite, shadow, databox va ket thuc animation binh thuong.

KHONG SU DUNG CHUNG VOI BAN V1
Day la ban thay the hoan toan, khong phai file bo sung cho v1.
Chi danh cho legacy PBAnimationPlayerX cua Essentials v21.1.
