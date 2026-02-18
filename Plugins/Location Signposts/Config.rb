class LocationWindow
  # The path to the signpost images
  # Default: "Graphics/Maps/"
  PATH = "Graphics/Maps/"

  # Speed of the signpost animations (in frames)
  SHOW_FRAMES       = 18  # Show signpost
  HIDE_FRAMES       = 18  # Hide signpost
  HIDE_FRAMES_MENU  = 10  # Hide signpost (when a menu is opened)

  # Duration of the signpost (in frames)
  # Default: 140
  DURATION = 140

  # The signpost images to use and the keywords to match
  # "Filename" => ["Map name keyword 1","Map name keyword 2", ...]
  SIGNPOSTS = {
      "Route_2" => ["Route", "Path", "Duong", "Đường"],
      "Town_1"  => ["Town", "Village", "Thi tran", "Thị trấn", "Lang", "Làng"],
      "Lake_1"  => ["Lake", "Ho", "Hồ"],
      "Cave_1"  => ["Cave", "Hang"],
      "City_1"  => ["City", "Thanh pho", "Thành Phố", "Do thi", "Đô thị"],
      "Forest_1" => ["Forest", "Woods", "Rừng", "Rung"],
      "HGSS_8" => ["Gym", "Stadium", "Academy", "Dao quan", "Đạo quán", "Hoc vien", "Học viện", "Nhà thi đấu", "Nha thi dau"],
      "Blank"   => ["Blank"]
  }
end