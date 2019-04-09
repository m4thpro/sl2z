pico-8 cartridge // http://www.pico-8.com
version 8
__lua__
-- sl2z by kisonecat

matrix = {{2,1},{1,1}}

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

function _update()
   a = {{1,1},{0,1}}
   ainv = {{1,-1},{0,1}}
   b = {{1,0},{1,1}}
   binv = {{1,0},{-1,1}}

   local action = nil
   
   if (btnp(0)) then action = {{1,-1},{0,1}} end
   if (btnp(1)) then action = {{1,1},{0,1}} end
   if (btnp(2)) then action = {{1,0},{-1,1}} end
   if (btnp(3)) then action = {{1,0},{1,1}} end   

   if action != nil then
      matrix = matmul(matrix, action)
   end
   
   -- if (btn(0)) then x=x-1 end
   -- if (btn(1)) then x=x+1 end
   -- if (btn(2)) then y=y-1 end
   -- if (btn(3)) then y=y+1 end
end


function _draw()
   cls()
   print(matrix[1][1],10,10)
   print(matrix[2][1],30,10)
   print(matrix[1][2],10,20)
   print(matrix[2][2],30,20)
end
