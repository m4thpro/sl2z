pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
-- sl2z by kisonecat

generators = {
   {{1,-1},{ 0,1}},
   {{1, 1},{ 0,1}},
   {{1, 0},{-1,1}},
   {{1, 0},{ 1,1}}
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

matrix = random_sl2z()
word = ""
matrix = {{1,0},{0,1}}
drawn = {{1,0},{0,1}}
timer = 0

function _update()
   local action = nil
   local symbol = nil
   
   if (btnp(0)) then symbol = "a"; action = generators[1] end
   if (btnp(1)) then symbol = "a!"; action = generators[2] end
   if (btnp(2)) then symbol = "b"; action = generators[3] end
   if (btnp(3)) then symbol = "b!"; action = generators[4] end

   if action != nil then
      matrix = drawn
      drawn = matmul(matrix, action)
      word = word .. symbol
      timer = time()
   end

   --if matrix[1][1] == 1 and matrix[2][1] == 0 and matrix[1][2] == 0 and matrix[2][2] == 1 then
   --matrix = random_sl2z()
   --end
end

function _draw()
   cls()

   local speed = 0.25
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

   local scale  = 0.5
   local y = 127 / 32
   local x

   local dxd = m01^2/256 + 1/8*m01*m11
   local nxd = m00*m01/256 + m01*m10/16 + m00*m11/16
   local dyd = m01^2/256 + m01*m11/8
   
   for j = 1, 128 do
      dx =  m01^2*y^2 + 4*m01^2 - 4*m01*m11 + m11^2
      nx =  m00*m01*y^2 + 4*m00*m01 - 2*m01*m10 - 2*m00*m11 + m10*m11
      dy =  m01^2*y^2 + 4*m01^2 - 4*m01*m11 + m11^2
      ny =  -m01*m10*y + m00*m11*y
      y -= 1/32
      
      x = -2
      for i = 1, 64 do
	 dx +=  m01^2*x/8 + dxd
	 nx +=  m00*m01*x/8 + nxd
	 dy +=  m01^2*x/8 + dyd
	 x += 1/16
	 
	 if (ny % dy < 0.5 * dy) == (nx % dx < 0.5 * dx) then
	    poke( vmem, 17 )
	 end
	 vmem = vmem + 1
      end      
   end
    
   print(matrix[1][1],10,10)
   print(matrix[2][1],30,10)
   print(matrix[1][2],10,20)
   print(matrix[2][2],30,20)
   print(word,10,40)
end
