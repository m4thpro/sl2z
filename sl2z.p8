pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- sl2z by kisonecat

generators = {
   {{1, 0},{ 1,1}},
   {{1, 0},{-1,1}},
   {{1,-1},{ 0,1}},
   {{1, 1},{ 0,1}}   
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

function _update()
   local action = nil
   local symbol = nil

   if (btnp(0)) then symbol = "\139"; action = generators[1] end
   if (btnp(1)) then symbol = "\145"; action = generators[2] end
   if (btnp(2)) then symbol = "\148"; action = generators[3] end
   if (btnp(3)) then symbol = "\131"; action = generators[4] end
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
   end

   remaining_time = deadline - time()

   if #word > 13 then
      start_round()
   end
   
   if (remaining_time < 0) then
      remaining_time = 0
      start_round()      
   end
   
   if (abs(matrix[1][1]) == 1 and matrix[2][1] == 0 and
       matrix[1][2] == 0 and abs(matrix[2][2] == 1)) then
      start_round()
      score = score + shr(flr(10*remaining_time),16)

      if (score > dget(0)) then
	 dset(0, score)
      end
   end
end

function printo(text,x,y)
   for i= -1,1 do
      for j= -1,1 do
	 print(text,x+i,y+j,0)
      end
   end
   print(text,x,y,15)
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
 
function _draw()
   local speed = 1.0
   local t = (time() - timer) / speed
   local s = 1 - t

   if (t > 1) then
      matrix = drawn
   end
   
   local m00 = s*matrix[1][1] + t*drawn[1][1]
   local m01 = s*matrix[1][2] + t*drawn[1][2]
   local m10 = s*matrix[2][1] + t*drawn[2][1]
   local m11 = s*matrix[2][2] + t*drawn[2][2]
   
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

   --print( stat(1),50,50 )
   
   printo(drawn[1][1],10,20)
   printo(drawn[2][1],30,20)
   printo(drawn[1][2],10,30)
   printo(drawn[2][2],30,30)
   printo(word,10,40)

   printo("score " .. padded(6,bignum(score)) .. " time " .. padded(3,tostr(flr(10*remaining_time))),64 - (21*4)/2,2)
   printo("   hi " .. padded(6,bignum(dget(0))) ,64 - (21*4)/2,8)
end

function _init()
   -- randomize color assignments
   for i = 0, 7 do
      for j = 0, 7 do
	 poke(0x4300 + 8*j + i, 17*flr(rnd(16)))
      end
   end

   start_round()
   score = 0

   cartdata("kisonecat_sl2z_1")
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
