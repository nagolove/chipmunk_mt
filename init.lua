local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table


local colorize = require('ansicolors2').ansicolors
local inspect = require("inspect")
local dprint = require('debug_print')
local debug_print = dprint.debug_print

dprint.set_filter({
   [1] = { "joy" },
   [2] = { 'phys' },
   [3] = { "thread", 'someName' },
   [4] = { "graphics" },
   [5] = { "input" },
   [6] = { "verts" },




})

debug_print('thread', colorize('%{yellow}>>>>>%{reset} chipmunk_mt started'))

require('joystate')
require("love")
require("love_inc").require_pls()
require('pipeline')

local Cm = require('chipmunk')

love.filesystem.setRequirePath("?.lua;?/init.lua;scenes/chipmunk_mt/?.lua")

local joystick = love.joystick

local event_channel = love.thread.getChannel("event_channel")
local main_channel = love.thread.getChannel("main_channel")

local pw = require("physics_wrapper")

local bodyIter
local shapeIter

local tanks = {}






























local last_render

local pipeline = Pipeline.new("scenes/chipmunk_mt")








local joy
local joyState

local function initJoy()
   for _, j in ipairs(joystick.getJoysticks()) do
      debug_print("joy", colorize('%{green}' .. inspect(j)))
   end
   joy = joystick.getJoysticks()[1]
   if joy then
      debug_print("joy", colorize('%{green}avaible ' .. joy:getButtonCount() .. ' buttons'))
      debug_print("joy", colorize('%{green}hats num: ' .. joy:getHatCount()))
   end
   joyState = JoyState.new(joy)
end

local function initRenderCode()

   local rendercode











   rendercode = [[
    while true do
        local w, h = love.graphics.getDimensions()
        --local x, y = math.random() * w, math.random() * h
        local x, y = w / 2, h / 2
        love.graphics.setColor{0, 0, 0}
        love.graphics.print("Hello from Siberia!", x, y)
        coroutine.yield()
    end
    ]]
   pipeline:pushCode('text', rendercode)

   rendercode = [[
    -- Загружать текстуры здесь
    -- Загружать текстуры здесь
    -- Загружать текстуры здесь
    -- Загружать текстуры здесь

    while true do
        local y = graphic_command_channel:demand()
        local x = graphic_command_channel:demand()
        local rad = graphic_command_channel:demand()
        love.graphics.setColor{0, 0, 1}
        love.graphics.circle('fill', x, y, rad)
        coroutine.yield()
    end
    ]]
   pipeline:pushCode('circle_under_mouse', rendercode)



   pipeline:pushCode('clear', [[
    while true do
        love.graphics.clear{0.5, 0.5, 0.5}
        coroutine.yield()
    end
    ]])

   pipeline:pushCode("poly_shape", [[
    local col = {1, 0, 0, 1}
    local inspect = require "inspect"
    while true do
        love.graphics.setColor(col)

        local verts = graphic_command_channel:demand()
        --local verts = graphic_command_channel:pop()
        love.graphics.polygon('fill', verts)
        --love.graphics.circle('fill', 500, 500, 100)

        coroutine.yield()
    end
    ]])

   pipeline:pushCode("print_debug_filters", [[
    local render = require "debug_print".render
    while true do
        render(0, 0)
        coroutine.yield()
    end
    ]])


end

local tanks_num = 100

local function init()

   initJoy()
   initRenderCode()
   pw.init(pipeline)
   last_render = love.timer.getTime()

   local w, h = love.graphics.getDimensions()
   for _ = 1, tanks_num do
      local xp, yp = love.math.random(1, w), love.math.random(1, h)
      table.insert(tanks, pw.newBoxBody(xp, yp))
   end

   debug_print("phys", 'pw.getBodies()', inspect(pw.getBodies()))
end

local function circle_under_mouse()
   local draw_calls = 2
   local x, y = love.mouse.getPosition()
   local rad = 50
   for _ = 1, draw_calls do
      pipeline:open('circle_under_mouse')
      pipeline:push(y)
      pipeline:push(x)
      pipeline:push(rad)
      pipeline:close()
   end
end








local function render()
   pipeline:openAndClose('clear')
   pw.eachSpaceBody(bodyIter)
   circle_under_mouse()
   pipeline:openAndClose('text')
   pipeline:openAndClose('print_debug_filters')

   pipeline:sync()
end





















local is_stop = false

local function eachShape(b, shape)
   debug_print('phys', 'eachShape call')

   local shape_type = pw.polyShapeGetType(shape)

   if shape_type == pw.CP_POLY_SHAPE then





      local num = pw.polyShapeGetCount(shape)
      local verts = {}
      for i = 0, num - 1 do
         local vert = pw.polyShapeGetVert(shape, i)


         table.insert(verts, vert.x)
         table.insert(verts, vert.y)
      end

      if verts then
         pipeline:open('poly_shape')
         pipeline:push(verts)
         pipeline:close()
      end

   end

end

local function eachBody(b)
   local body = pw.cpBody2Body(b)
   if body then


      pw.eachBodyShape(b, shapeIter)
   else

   end
end

bodyIter = pw.newEachSpaceBodyIter(eachBody)
shapeIter = pw.newEachBodyShapeIter(eachShape)

local function applyInput()
   local leftBtn, rightBtn, downBtn, upBtn = 3, 2, 1, 4
   local k = 0.1
   local tank = tanks[1]
   if joy then
      local dx, dy, _ = joy:getAxes()
      if dx and dy then
         local divisor = 20
         dx, dy = dx / divisor, dy / divisor
         tank:applyImpulse(dx, dy)
      end

      if joy:isDown(leftBtn) then
         tank:applyImpulse(-1. * k, 0)

      elseif joy:isDown(rightBtn) then
         tank:applyImpulse(1. * k, 0)

      elseif joy:isDown(upBtn) then
         tank:applyImpulse(0, -1 * k)

      elseif joy:isDown(downBtn) then
         tank:applyImpulse(0, 1 * k)

      end
   end
end

local function updateJoyState()
   joyState:update()
   if joyState.state and joyState.state ~= "" then
      debug_print('joy', joyState.state)
   end
end

local function mainloop()
   while not is_stop do

      local events = event_channel:pop()
      if events then
         for _, e in ipairs(events) do
            local evtype = (e)[1]
            if evtype == "mousemoved" then


            elseif evtype == "keypressed" then
               local key = (e)[2]
               local scancode = (e)[3]

               local msg = '%{green}keypressed '
               debug_print('input', colorize(msg .. key .. ' ' .. scancode))

               dprint.keypressed(scancode)

               if scancode == "escape" then
                  is_stop = true
                  debug_print('input', colorize('%{blue}escape pressed'))
                  break
               end




            elseif evtype == "mousepressed" then





            end
         end
      end


      local nt = love.timer.getTime()
      local pause = 1. / 300.

      local diff = nt - last_render
      if diff >= pause then
         last_render = nt


         render()
      end




      pw.update(diff)

      applyInput()






      updateJoyState()

      local timeout = 0.0001
      love.timer.sleep(timeout)
   end
end

init()
mainloop()

if is_stop then
   pw.free()
   main_channel:push('quit')
   debug_print('thread', 'Thread resources are freed')
end


debug_print('thread', colorize('%{yellow}<<<<<%{reset} chipmunk_mt finished'))
