pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- sl2z by kisonecat
cartdata("kisonecat_sl2z_1")

state = "title"
low_time = 10
remaining_time = time()
died_at_time = -1000

generators = {
   {{1, 0},{-1,1}},
   {{1, 0},{ 1,1}},
   {{1, 1},{ 0,1}},
   {{1,-1},{ 0,1}}   
}

function matmul( m1, m2 )
   if #m1[1] ~= #m2 then
      return nil
   end 
 
   local result = {}
 
   for i = 1, #m1 do
      result[i] = {}
      for j = 1, #m2[1] do
	 result[i][j] = 0
	 for k = 1, #m2 do
	    result[i][j] = result[i][j] + m1[i][k] * m2[k][j]
	 end
      end
   end
   
   return result
end

function random_sl2z()
   local result = {{1,0},{0,1}}

   for i = 1, 5+flr(rnd(5)) do
      result = matmul( result, generators[ceil(rnd(4))] )
   end

   return result
end

function start_round()
   matrix = random_sl2z()
   word = ""
   drawn = matrix
   timer = 0
   deadline = time() + 24
   almost_out_of_time = false
end

function start_playing()
   -- randomize color assignments
   for i = 0, 7 do
      for j = 0, 7 do
	 poke(0x4300 + 8*j + i, 17*flr(rnd(16)))
      end
   end

   state = "playing"
   start_round()
   score = 0
   lives = 2
end

function simplify(word)
   for i = 0, #word - 1 do
      if sub(word,i,i+1) == "\139\145" then
	 return sub(word,1,i-1) .. sub(word,i+2,#word)
      end
      if sub(word,i,i+1) == "\145\139" then
	 return sub(word,1,i-1) .. sub(word,i+2,#word)
      end
      if sub(word,i,i+1) == "\148\131" then
	 return sub(word,1,i-1) .. sub(word,i+2,#word)
      end
      if sub(word,i,i+1) == "\131\148" then
	 return sub(word,1,i-1) .. sub(word,i+2,#word)
      end
   end

   return word
end

function die()
   sfx(4,0)
   lives = lives - 1
   if (lives == 0) then
      state = "dead"
   end
   died_at_time = time()
end


function _update_dead()
   if (btnp(4)) or (btnp(5)) then
      state = "title"
   end
end

function _update_playing()
   local action = nil
   local symbol = nil

   -- prevent diagonal movement
   if (btnp(0) and 1 or 0) + (btnp(1) and 1 or 0) + (btnp(2) and 1 or 0) + (btnp(3) and 1 or 0) == 1 then
      if (btnp(0)) then symbol = "\139"; action = generators[1] end
      if (btnp(1)) then symbol = "\145"; action = generators[2] end
      if (btnp(2)) then symbol = "\148"; action = generators[3] end
      if (btnp(3)) then symbol = "\131"; action = generators[4] end
   end
   
   if (btnp(4)) then
      if #word > 0 then
	 local last = sub(word,#word,#word)
	 if last == "\145" then symbol = "\139"; action = generators[1] end
	 if last == "\139" then symbol = "\145"; action = generators[2] end
	 if last == "\131" then symbol = "\148"; action = generators[3] end
	 if last == "\148" then symbol = "\131"; action = generators[4] end	    
      end
   end

   if action != nil then
      matrix = drawn
      drawn = matmul(matrix, action)
      word = word .. symbol
      word = simplify(word)
      timer = time()

      if symbol == "\139" then sfx(0,0) end
      if symbol == "\145" then sfx(1,0) end
      if symbol == "\148" then sfx(2,0) end
      if symbol == "\131" then sfx(3,0) end

      if (abs(drawn[1][1]) == 1 and drawn[2][1] == 0 and
	  drawn[1][2] == 0 and abs(drawn[2][2] == 1)) then
	 sfx(5,0) -- about to win	 
      end
   end

   -- lose if too many buttons have been pressed
   if #word > 13 then
      die()
      start_round()
   end

   remaining_time = deadline - time()
   
   -- play "almost out of time" tune
   if (remaining_time < low_time) and not almost_out_of_time then
      almost_out_of_time = true
      sfx(7,1)
   end
   
   if (remaining_time < 0) then
      die()      
      remaining_time = 0
      start_round()      
   end

   if (abs(matrix[1][1]) == 1 and matrix[2][1] == 0 and
       matrix[1][2] == 0 and abs(matrix[2][2] == 1)) then
      start_round()
      sfx(6,0) -- win
      score = score + shr(flr(10*remaining_time),16)

      -- set the high score
      if (score > dget(0)) then dset(0, score) end
   end
end

function printo(text,x,y,c)
   c = c or 8
   for i= -1,1 do
      for j= -1,1 do
	 print(text,x+i,y+j,0)
      end
   end
   print(text,x,y,c)
end

function padded(i, s)
   return sub("0000000000" .. s, #s + 10 - i + 1, #s + 10)
end

function bignum(val)
   if (val == 0) then return "0" end
   
   local s = ""
   local v = abs(val)
   while (v!=0) do
     s = shl(v % 0x0.000a, 16)..s
     v /= 10
   end
   if (val<0)  s = "-"..s
   return s 
 end

function _draw_dead()
   _draw_playing()
   local message = "game over"
   printo(message, 64 - #message * 2, 100, 8 + ((time() % 0.5 > 0.25) and 0 or 1) )
end

function draw_plane(m00, m01, m10, m11)
   local vmem = 0x6000

   local dx, nx
   local dy, ny
   local cx, cy

   local x, c

   local dxd = m01^2/256 + 1/8*m01*m11
   local nxd = m00*m01/256 + m01*m10/16 + m00*m11/16
   local dyd = m01^2/256 + m01*m11/8

   local m012 = m01^2
   local m0001 = m00*m01
   
   local y = 127 / 32
   local y2 = y*y

   local dx0 = 4*m012 + m11*(m11 - 4*m01)
   local nx0 = 4*m0001 - 2*m01*m10 - 2*m00*m11 + m10*m11
   local dy0 = 4*m012 - 4*m01*m11 + m11^2
   
   for j = 1, 64 do
      dx =  m012*y2 + dx0
      nx =  m0001*y2 + nx0
      dy =  m012*y2 + dy0
      ny =  (-m01*m10 + m00*m11)*y
      y2 += 1/256 - y/8
      y -= 1/16
      
      x = -2/8
      for i = 1, 64 do
	 dx += m012*x + dxd
	 nx += m0001*x + nxd
	 dy += m012*x + dyd
	 x += 1/16/8
	 
	 --c = (flr(2*nx/dx)%8) + (flr(2*ny/dy)%8)
	 c = peek( 0x4300 + 8*(flr(2*nx/dx)%8) + (flr(2*ny/dy)%8) )
	 --poke( vmem, 17 * c )
	 --poke( vmem + 64, 17 * c )
	 poke( vmem, c )
	 poke( vmem + 64, c )
	 vmem = vmem + 1
      end
      vmem = vmem + 64
   end
end

function draw_matrix(m11, m12, m21, m22, center_y)
   pal(15,0)
   local left = max(#tostr(m11),#tostr(m12))
   local right = max(#tostr(m21),#tostr(m22))
   
   spr(64, 64 - left*4 - 12, 1 + center_y - 16, 1, 4)
   spr(64, 64 + right*4 + 12, 1 + center_y - 16, 1, 4, true)
   pal(15,15)

   printo(m11,64 - #tostr(m11)*4,center_y - 6,7)
   printo(m21,64 + 9 + right * 4 - #tostr(m21)*4,center_y - 6,7)
   printo(m12,64 - #tostr(m12)*4,center_y + 5,7)
   printo(m22,64 + 9 + right * 4 - #tostr(m22)*4,center_y + 5,7)

end

function _draw_playing()
   local speed = 1.0

   -- faster if we are about to win
   if (abs(drawn[1][1]) == 1 and drawn[2][1] == 0 and
       drawn[1][2] == 0 and abs(drawn[2][2] == 1)) then
      speed = 0.25
   end
   
   local t = (time() - timer) / speed
   local s = 1 - t

   if (t > 1) then
      matrix = drawn
   end
   
   local m00 = s*matrix[1][1] + t*drawn[1][1]
   local m01 = s*matrix[1][2] + t*drawn[1][2]
   local m10 = s*matrix[2][1] + t*drawn[2][1]
   local m11 = s*matrix[2][2] + t*drawn[2][2]
   
   draw_plane(m00, m01, m10, m11)

   local center_y = 45
   draw_matrix( drawn[1][1], drawn[1][2], drawn[2][1], drawn[2][2], center_y )
   printo(word,64 - 4*#word,center_y + 30, 7)

   printo("score " .. padded(6,bignum(score)), 6, 2, 6)
   printo("   hi " .. padded(6,bignum(dget(0))) ,6,8, 5)
   local timecolor = 6
   if (remaining_time < low_time) then
      timecolor = 8 + ((time() % 0.5 > 0.25) and 0 or 1)
   end
   printo(" time " .. padded(3,tostr(flr(10*remaining_time))),54,2, timecolor)

   local livecolor = 6
   if (time() - died_at_time < 3) and lives > 0 then
      livecolor = 8 + ((time() % 0.5 > 0.25) and 0 or 1)
   end
   
   printo(" lives " .. tostr(lives),91,2, livecolor)
end

function how_to_play()
   state = "howto"
end

title_menu = 0
menu = {
   start_playing,
   how_to_play
}

function _update_title()
   if btnp(2) or btnp(3) then
      title_menu = 1 - title_menu
   end

   if btnp(4) or btnp(5) then
      menu[title_menu + 1]()
   end
end

function _update_howto()
   if btnp(4) or btnp(5) then
      state = "title"
   end
end

function _draw_title()
   local s = time() % 16 / 16

   for i = 0, 7 do
      for j = 0, 7 do
	 local c = (i + j) % 2
	 poke(0x4300 + 8*j + i, 17*c)
      end
   end

   draw_plane(1, sin(s), 0, 1)

   spr(0, 64 - 12*4 + 2, 25, 12, 4 )

   local blinking = (sin(time() * 2) > 0) and 7 or 9
   printo("start game", 45, 80, (title_menu == 0) and blinking or 6 )
   printo("how to play", 45, 88, (title_menu == 1) and blinking or 6 )

   printo("\143", 45 - 9, 80 + 8*title_menu, blinking )
end

function _draw_howto()
   local s = time() % 16 / 16

   for i = 0, 7 do
      for j = 0, 7 do
	 local c = (i + j) % 2
	 poke(0x4300 + 8*j + i, 17*c)
      end
   end

   draw_plane(1, sin(s), 0, 1)

   instructions = {
      --"012345678901234567890123456789"
      "\148 and \131 affect the second row",
      "\148 adds the first row",
      "\131 subtracts the first row",
      "",
      "\139 and \145 affect the first row",
      "\139 subtracts the second row",
      "\145 adds the second row",
      "",
      "the goal is to get to",
   }

   for i = 1, #instructions do
      printo(instructions[i], 2, 8*i, 7 )
   end

   draw_matrix( 1, 0, 0, 1, 96 )
end

updaters = { playing = _update_playing,
	     title = _update_title,
	     howto = _update_howto,
	     dead = _update_dead }
drawers = { playing = _draw_playing,
	    title = _draw_title,
	    howto = _draw_howto,
	    dead = _draw_dead }

function _update()
   updaters[state]()
end

function _draw()
   drawers[state]()
end

function _init()
   -- i find the music unpleasant
   -- music(0, 0, 15)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000001d0000000000000000000000005500000000000000000000000000000000000000000000
0000000005666d100500005555555100000000000000000000000000600000155555555555555510000d10000000000000000000000000000000000000000000
00000001650001651700005d777d5100000000000000000000000006500000d6677766dd67dd6750000060000000000000000000000000000000000000000000
000000075000000d67000000d7d000000000000000000000000000560000006d761000007500d600000056000000000000000000000000000000000000000000
000000d60000000077000000d7d00000000000000000000000000060000000675000000d60017100000006100000000000000000000000000000000000000000
000000650000000057000000d7d000000000000000000000000005600000007d0000001710065000000005600000000000000000000000000000000000000000
000000750000000007000000d7d00000000000000000000000000650000000710000006d00560000000000700000000000000000000000000000000000000000
000000760000000006000000d7d00000000000000000000000001700000000500000057000750000000000650000000000000000000000000000000000000000
000000675000000005000000d7d0000000000000000000000000560000000000000007500d600000000000560000000000000000000000000000000000000000
000000577500000000000000d7d00000000000000000000000006d00000000000000d60017000000000000570000000000000000000000000000000000000000
0000000d7776510000000000d7d00000000000000000000000007500000000000001700065000000000000171000000000000000000000000000000000000000
000000005777776500000000d7d00000000000000000000000007500000000000006500560000000000000075000000000000000000000000000000000000000
000000000015677760000000d7d00000000000000000000000007100000000000056000710000000000000075000000000000000000000000000000000000000
000000000000005776000000d7d00000000000001dd6650000017100000000000071006d00000000000000075000000000000000000000000000000000000000
000000000000000077100000d7d0000000000001d0005750000170000000000006d005700000000000000006d000000000000000000000000000000000000000
000000100000000057500000d7d000000000d00d0000067000017000000000005700075000000055000000065000000000000000000000000000000000000000
000000d00000000007d00000d7d000000000d0076000057500007100000000006500d60000000075000000075000000000000000000000000000000000000000
000000600000000006d00000d7d000000000600dd000057500007100000000056001710000000571000000075000000000000000000000000000000000000000
000000700000000007500000d7d00000000160000000067000007500000000171006d00000000670000000071000000000000000000000000000000000000000
0000007d0000000017100000d7d000000006d00000001750000065000000006d0057000000006670000000171000000000000000000000000000000000000000
00000076500000006d000000d7d0000000d7d00000006d000000dd00000005700075000000576560000000570000000000000000000000000000000000000000
00000070d6500016d000005567655555d7775000000dd000000056000000076dd67ddddd6777d6d0000000d60000000000000000000000000000000000000000
0000005001d666650000005ddddddddddddd1000005d000000000700000005ddddddddddddddd510000000650000000000000000000000000000000000000000
000000000000000000000000000000000000000005d0000100000650000000000000000000000000000000700000000000000000000000000000000000000000
0000000000000000000000000000000000000000150000510000056000000000000000000000000000000dd00000000000000000000000000000000000000000
00000000000000000000000000000000000000016ddddd6000000061000000000000000000000000000006000000000000000000000000000000000000000000
000000000000000000000000000000000000000677777770000000160000000000000000000000000000d5000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000d500000000000000000000000000160000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000610000000000000000000000000600000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000fff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000f7f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ff7f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ff77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f77ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00ff7ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f77f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ff77f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f77ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f77f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f77ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ff77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ff7ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f77f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00f77ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00ff77f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f77ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000ff77f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000ff7f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000fff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222220000000000000000000011100000000000000000000000001110000000000000000011100000000000001111111111111111111111
22222222222222222222200660066006606660666011106660666066606660666066601110666066606660666011106660666060601111111111111111111111
22222222222222222222206000600060606060600011106060606060606060606060601110060006006660600011100060006060601111111111111111111111
22222222222222222222206660602060606600660111106060606060606060606060601111060106006060660111106660666066601111111111111111111111
22222222222222222222200060600060606060600011106060606060606060606060601111060006006060600011106000600000601111111111111111111111
22222222222222222222206600066066006060666011106660666066606660666066601111060066606060666011106660666010601111111111111111111111
22222222222222222222200002000000000000000011100000000000000000000000001111000000000000000011100000000010001111111111111111111111
22222222222222222222222222222222105050555011105550555055505550555055501111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222105050050011105050505000500050505050501111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222105550050111105050505055505550555055501111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222105050050011105050505050005000005000501111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222105050555011105550555055505550105010501111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222100000000011100000000000000000100010001111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111110001111111111111111111111111111111100011111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111110701111111111111111111111111111111107011111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111100701111111111111111111111111111111107001111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111007701111111111111111111111111111111107700111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111077001111111111111111111111111111111100770111111111111111111111111111111111111111
22222222222222222222222222222222111111111111110070011111111111111111111111111111111110070011111111111111111111111111111111111111
22222222222222222222222222222222111111111111110770111111111111111111111111111111111111077011111111111111111111111111111111111111
22222222222222222222222222222222111111111111100770111111111000011111111111110000011111077001111111111111111111111111111111111111
22222222222222222222222222222222111111111111107700111111111077011111111111110777011111007701111111111111111111111111111111111111
22222222222222222222222222222222111111111111107701111111111007011111111111110007011111107701111111111111111111111111111111111111
22222222222222222222222222222222111111111111107701111111111107011111111111110777011111107701111111111111111111111111111111111111
22222222222222222222222222222222111111111111107701111111111007001111111111110700011111107701111111111111111111111111111111111111
22222222222222222222222222222222111111111111107701111111111077701111111111110777011111107701111111111111111111111111111111111111
22222222222222222222222222222222111111111111007701111111111000001111111111110000011111107700111111111111111111111111111111111111
22222222222222222222222222222222111111111111077001111111111111111111111111111111111111100770111111111111111111111111111111111111
22222222222222222222222222222222111111111111077011111111111111111111111111111111111111110770111111111111111111111111111111111111
22222222222222222222222222222222111111111111077001111111111111111111111111111111111111100770111111111111111111111111111111111111
22222222222222222222222222222222111111111111007701111111111111111111111111111111111111107700111111111111111111111111111111111111
22222222222222222222222222222222111111111111107701111111111000011111111111110000111111107701111111111111111111111111111111111111
22222222222222222222222222222222111111111111107701111111111077011111111111110770111111107701111111111111111111111111111111111111
22222222222222222222222222222222111111111111107701111110000007011111111100000070111111107701111111111111111111111111111111111111
22222222222222222222222222222222111111111111107701111110777007011111111107770070111111107701111111111111111111111111111111111111
22222222222222222222222222222222111111111111107701111110000007001111111100000070011111107701111111111111111111111111111111111111
22222222222222222222222222222222111111111111110700111111111077701111111111110777011111007011111111111111111111111111111111111111
22222222222222222222222222222222111111111111110770111111111000001111111111110000011111077011111111111111111111111111111111111111
22222222222222222222222222222222111111111111110770011111111111111111111111111111111110077011111111111111111111111111111111111111
22222222222222222222222222222222111111111111110077011111111111111111111111111111111110770011111111111111111111111111111111111111
22222222222222222222222222222222111111111111111077001111111111111111111111111111111100770111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111007701111111111111111111111111111111107700111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111100701111111111111111111111111111111107001111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111110001111111111111111111111111111111100011111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222266666666222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222222222266666666222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222266666666666666222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222222266666666666666222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222666666666666666666222222222222222211111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222222666666666666666666222222222222222211111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222266666666666666666666222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222222266666666666666666666222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111111111
22222222666666666666666666666666222222222222222222222211111111111111111111111111111111111111111111111111111111111111111111111111
22222222666666666666666666666666222222222222222222222211111111111111111111111111111111111111111111111111111111111111111111111111
22222266666666666666666666666666222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111
22222266666666666666666666666666222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111
22222266666666666666666666666666222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111
22222266666666666666666666666666222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111111111
22226666666666666666666666666666222222222222222222222222221111111111111111111111111111111111111111111111111111111111111111111111
22226666666666666666666666666666222222222222222222222222221111111111111111111111111111111111111111111111111111111111111111111111
22666666666666666666666666666666222222222222222222222222222211111111111111111111111111111111111111111111111111111111111111111111
22666666666666666666666666666666222222222222222222222222222211111111111111111111111111111111111111111111111111111111111111111111
22666666666666666666666666666666222222222222222222222222222211111111111111111111111111111111111111111111111111111111111111111111
22666666666666666666666666666666222222222222222222222222222211111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
66666666666666666666666666666666222222222222222222222222222222111111111111111111111111111111111111111111111111111111111111111111
00000066666666666666666666eeeeee111122222222222222222222999999bbbbbbbb1111111111111111111111111111111111111111111111111111111111
00000066666666666666666666eeeeee111122222222222222222222999999bbbbbbbb1111111111111111111111111111111111111111111111111111111111
0000000000006666666666eeeeeeeeee111111112222222222999999999999bbbbbbbbbbbbbb1111111111111111111111111111111111111111111111111111
0000000000006666666666eeeeeeeeee111111112222222222999999999999bbbbbbbbbbbbbb1111111111111111111111111111111111111111111111111111
00000000000000006666eeeeeeeeeeee111111111122229999999999999999bbbbbbbbbbbbbbbbbb111111111111111111111111111111111111111111111111
00000000000000006666eeeeeeeeeeee111111111122229999999999999999bbbbbbbbbbbbbbbbbb111111111111111111111111111111111111111111111111
000000000000000000eeeeeeeeeeeeee111111111111999999999999999999bbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111111111111111
000000000000000000eeeeeeeeeeeeee111111111111999999999999999999bbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111111111111111
0000000000000000777777eeeeeeeeee11111111cccccc9999999999999999bbbbbbbbbbbbbbbbbbbbbbbb111111111111111111111111111111111111111111
0000000000000000777777eeeeeeeeee11111111cccccc9999999999999999bbbbbbbbbbbbbbbbbbbbbbbb111111111111111111111111111111111111111111
000000000000000077777777eeee0000661111cccccccc9999999999999999bbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111111111
000000000000000077777777eeee0000661111cccccccc9999999999999999bbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111111111
77000000000000007777777700000000666666cccccccc99999999999999bbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111111111
77000000000000007777777700000000666666cccccccc99999999999999bbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111111111
7700000000000000777777777700000066664444cccccc99999999999999bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb11111111111111111111111111111111111111
7700000000000000777777777700000066664444cccccc99999999999999bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb11111111111111111111111111111111111111
7777000000ffffff2222777777778888cc444444cc9999111111999999bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb111111111111111111111111111111111111
7777000000ffffff2222777777778888cc444444cc9999111111999999bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb111111111111111111111111111111111111
777777ffffffffff2222bbbb44448888cc1111111199991111111111bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb111111111111111111111111111111111111
777777ffffffffff2222bbbb44448888cc1111111199991111111111bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb111111111111111111111111111111111111
777788ffffffffff2222bbbb661111ffddddcc11119999111111111188bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
777788ffffffffff2222bbbb661111ffddddcc11119999111111111188bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
77888888ffffff55ccccaaaa5522335588884488880000aa111111888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
77888888ffffff55ccccaaaa5522335588884488880000aa111111888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
888888888888555555cc888833888866889966aaaa00aaaaaa888888888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
888888888888555555cc888833888866889966aaaa00aaaaaa888888888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
8888888888111155aaaa9911ddbb8888aaaa11bb225555aa33338888888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
8888888888111155aaaa9911ddbb8888aaaa11bb225555aa33338888888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
88888888881111113311111188cc33ff8844cceeffff113333338888888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
88888888881111113311111188cc33ff8844cceeffff113333338888888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
88888888881111113388bb11ff664422110011227788113333338888888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111
88888888881111113388bb11ff664422110011227788113333338888888888bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb1111111111111111111111111111111111

__sfx__
000100000f150111501315015150181501a1501c1501e150221000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000100001e1501c1501b1501915018150171501515014150221000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00010000210502205023050240502505027050290502b0502c0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000300502f0502d0502b05029050250502305021050210500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000a00001c4500845008450180001e0001d000180001c0001c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001bb501db5020b502ab5029b0037b0026b0026b0000b0000b0000b0000b0000b0000b0026b0028b0000b0000b0000b0000b0000b0000b0000b0000b0000b0000b0000b0000b0000b0000b0000b0000b00
0008000019d501dd5021d501cd5020d5025d5020d5026d502bd5000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d0000d00
0003000004e5004e5009e0008e3009e000be500be5009e0009e000de500de3009e000fe500fe3000e0012e5012e3000e000fe500fe3001e0012e5012e4000e000fe500fe3000e0012e5012e4000e000fe500fe30
001000000c0100000013010000000c010000001301013000110100e0001101011000130100c000150100c0000c010170000c0101000013010100001301013000110100c0001101010000110100c0000c01010000
00100000100101110010010111001301015100100101110015010171000e0100c100100100e1001101013100100100e10010010111001701015100170100c1001501017100150101c10015010001000c0100c100
001000000c010111001001000000100100000010010000000e010000000e0100000010010000000c0100000010010000001001000000100100000010010000000e010000000e010000000e010000000c01000000
001000001002000000100100000013020000000c02000000110200000011020000000c020000000c020000000c020000000c0200000013020000000c020000001102000000110200000011020000000c02000000
0010000013210000000020000000102100000000200000000e2100000000200000000c210000000020000000132100000000200000000c2100000000200000000e2100000000200000000e210000000020000000
001000001021000000002000000013210000000020000000152100000000200000000c210000000020000000132100000000200000000c2100000000200000001521000000002000000015210000000020000000
__music__
01 08090c44
00 080a0d44
00 0a0b0c44
02 080b0d44

