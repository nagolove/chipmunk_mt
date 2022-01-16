-- vim: set colorcolumn=85
-- vim: fdm=marker

local colorize = require 'ansicolors2'.ansicolors
local inspect = require "inspect"
local dprint = require 'debug_print'
local sformat = string.format
local debug_print = dprint.debug_print

dprint.set_filter { 
    [1] = { "joy" },
    [2] = { 'phys' },
    [3] = { "thread", 'someName' },
    [4] = { "graphics" },
    [5] = { "input" },
    [6] = { "verts" },
    --[7] = { "phys" },
    --[8] = { "phys" },
    --[9] = { "phys" },
    --[0] = { "phys" },
}

debug_print('thread', colorize('%{yellow}>>>>>%{reset} chipmunk_mt started'))

require 'joystate'
require "love"
require "love_inc".require_pls()
require 'pipeline'

local Cm = require 'chipmunk'

love.filesystem.setRequirePath("?.lua;?/init.lua;scenes/chipmunk_mt/?.lua")
--local format = string.format
local joystick = love.joystick

local event_channel = love.thread.getChannel("event_channel")
local main_channel = love.thread.getChannel("main_channel")

local pw = require "physics_wrapper"

local bodyIter: pw.EachSpaceBodyIter
local shapeIter: pw.EachBodyShapeIter

local tanks: {pw.Body} = {}

--[[ {{{
-- chipmunk.d.tl

local record Chipmunk
    record Space
        record Gravity
            x: number
            y: number
        end

        iterations: integer
        gravity: Gravity    
    end

    cpSpaceNew: function(): Space
end

return Chipmunk
-- main.tl

local C = require("chipmunk")
local space = C.cpSpaceNew()
space.iterations = 20
space.gravity.x = 0
space.gravity.y = -100

-- }}}
--]]

local last_render: number

local pipeline = Pipeline.new("scenes/chipmunk_mt")

-- Как часто перекомпилировать код рисовки?
-- Варианты - 
--  * по таймеру
--  * используя метод :peek() на каждой итерации цикла
-- Сейчас функция компилируется один раз при загрузке файла исходного текста
-- потока.

local joy: love.joystick.Joystick
local joyState: JoyState

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
    -- {{{
    local rendercode: string

    --rendercode = [[
    --local col = {1, 1, 1, 1}
    ----love.graphics.setColor(col)
    --while true do
        ----love.graphics.setColor(col)
        --coroutine.yield()
    --end
    --]]
    --pipeline:pushCode("rect", rendercode)

    rendercode = [[
    local font = love.graphics.newFont(24)
    while true do
        local old_font = love.graphics.getFont()

        love.graphics.setColor{0, 0, 0}
        love.graphics.setFont(font)

        local msg = graphic_command_channel:demand()
        local x = math.floor(graphic_command_channel:demand())
        local y = math.floor(graphic_command_channel:demand())
        love.graphics.print(msg, x, y)

        love.graphics.setFont(old_font)

        coroutine.yield()
    end
    ]]
    pipeline:pushCode('formated_text', rendercode)

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

    -- Допустимо-ли переопределение функций? Или добавить специальный флаг?
    -- Нормально-ли использовать константы?
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

    -- }}}
end

--local tanks_num = 20
local tanks_num = 500

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

local function print_io_rate()
    local bytes = pipeline:get_received_in_sec()
    local msg = sformat("received_in_sec = %d", math.floor(bytes / 1024))
    pipeline:open('formated_text')
    pipeline:push(msg)
    pipeline:push(0)
    pipeline:push(140)
    pipeline:close()
end

--[[
Откуда берутся мелькания при рисовке?
Значит, что данные не сихронизируются? То есть основной поток получает
не все данные и ждет их. В это время он рисует часть картинки, ждет,
рисует вторую часть. В момент ожидания видно мелькание? Но картинка
слишком простая.
--]]
local function render()
    pipeline:openAndClose('clear')
    pw.eachSpaceBody(bodyIter)
    circle_under_mouse()

    print_io_rate()

    pipeline:openAndClose 'print_debug_filters'

    pipeline:sync()
end

local is_stop = false

local function eachShape(b: Cm.cpBody, shape: Cm.cpShape)
    debug_print('phys', 'eachShape call')

    local shape_type = pw.polyShapeGetType(shape)

    if shape_type == pw.CP_POLY_SHAPE then

        -- Возможно стоит поместить формирование таблички в 
        -- вспомогательную библиотеку или переписать с прямым доступом к
        -- shape->planes[i].v0

        local num = pw.polyShapeGetCount(shape)
        local verts = {}
        for i = 0, num - 1 do
            local vert = pw.polyShapeGetVert(shape, i)
            --print(inspect(vert))
            --debug_print("verts", 'x, y', vert.x, vert.y)
            table.insert(verts, vert.x)
            table.insert(verts, vert.y)
        end

        if verts then
            pipeline:open('poly_shape')
            pipeline:push(verts)
            pipeline:close()
        end

    end
    --]]
end

local function eachBody(b: Cm.cpBody)
    local body = pw.cpBody2Body(b)
    if body then
        --print(colorize('%{green}' .. inspect(body)))
        --print(colorize('%{yellow}' .. body:getInfoStr()))
        pw.eachBodyShape(b, shapeIter)
    else
        --print(colorize('%{red}body is nil ' .. debug.traceback()))
    end
end

bodyIter = pw.newEachSpaceBodyIter(eachBody)
shapeIter = pw.newEachBodyShapeIter(eachShape)

local function applyInput()
    local leftBtn, rightBtn, downBtn, upBtn = 3, 2, 1, 4
    local k = 0.1
    local tank: pw.Body = tanks[1]
    if joy then
        local dx, dy, _ = joy:getAxes()
        if dx and dy then
            local divisor = 20
            dx, dy = dx / divisor, dy / divisor
            tank:applyImpulse(dx, dy)
        end

        if joy:isDown(leftBtn) then
            tank:applyImpulse(-1. * k, 0)
            --print('left')
        elseif joy:isDown(rightBtn) then
            tank:applyImpulse(1. * k, 0)
            --print('right')
        elseif joy:isDown(upBtn) then
            tank:applyImpulse(0, -1 * k)
            --print('up')
        elseif joy:isDown(downBtn) then
            tank:applyImpulse(0, 1 * k)
            --print('down')
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
        --print('mainloop iter')
        local events = event_channel:pop() as {any}
        if events then
            for _, e in ipairs(events) do
                local evtype: string = (e as {string})[1]
                if evtype == "mousemoved" then
                    --mx = math.floor((e as {number})[2])
                    --my = math.floor((e as {number})[3])
                elseif evtype == "keypressed" then
                    local key = (e as {string})[2]
                    local scancode = (e as {string})[3]

                    local msg = '%{green}keypressed '
                    debug_print('input', colorize(msg .. key .. ' ' .. scancode))

                    dprint.keypressed(scancode)

                    if scancode == "escape" then
                        is_stop = true
                        debug_print('input', colorize('%{blue}escape pressed'))
                        break
                    end

                    --msg = '%{yellow}keypressed '
                    --print(colorize(msg .. key .. ' ' .. scancode))

                elseif evtype == "mousepressed" then
                    --local x: number = (e as {number})[2]
                    --local y: number = (e as {number})[3]
                    --local button: number = (e as {number})[4]
                    --local istouch: boolean = (e as {boolean})[5]
                    --local presses: number = (e as {number})[6]
                end
            end
        end
        
        -- Ограничение кадров в секунду до 60
        local nt = love.timer.getTime()
        local pause = 1. / 300.
        --local pause = 1. / 4000.
        local diff = nt - last_render
        if diff >= pause then
            last_render = nt
            --local msg = 'love.timer.getTime() = %f'
            --print(colorize('%{blue}' .. format(msg, love.timer.getTime())))
            render()
        end

        -- UPDATE HERE PLEASE

        -- шаг физики
        pw.update(diff)

        applyInput()
        --print('------------------------------------------------')
        --print('------------------------------------------------')
        --debug_print('phys', tank:getInfoStr())
        --local pos = tank:getPos()
        --debug_print('phys', 'tank pos', pos.x, pos.y)

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
