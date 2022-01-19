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
local Joystick = joystick.Joystick

local event_channel = love.thread.getChannel("event_channel")
local main_channel = love.thread.getChannel("main_channel")

local pw = require "physics_wrapper"

local bodyIter: pw.EachSpaceBodyIter
local shapeIter: pw.EachBodyShapeIter

local record Tank
    prev_posx: number
    prev_posy: number
    first_render: boolean
    body: pw.Body
    id: integer
end

--local tanks: {pw.Body} = {}
local tanks: {Tank} = {}

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

    pipeline:pushCode("poly_shape_smart", [[
    local inspect = require 'inspect'
    local col = {1, 0, 0, 1}
    local inspect = require "inspect"

    -- какое название лучше?
    local hash = {}

    local verts = nil
    --local id = nil

    while true do
        love.graphics.setColor(col)

        local id = graphic_command_channel:demand()
        local cmd = graphic_command_channel:demand()

        -- команды cmd:
        -- new      - создать новый объект
        -- draw     - рисовать существущий
        -- ?????? draw_new - обновить координаты и рисовать ???????
        -- remove   - удалить объект

        if cmd == "new" then
            verts = graphic_command_channel:demand()
            hash[id] = verts
        elseif cmd == "draw" then
            verts = hash[id]
        elseif cmd == "remove" then
            hash[id] = nil
        end

        --print('id', id)
        --print('cmd', cmd)
        --print('verts', inspect(verts))

        love.graphics.polygon('fill', verts)

        coroutine.yield()
    end
    ]])

    pipeline:pushCode("poly_shape_fs_write", [[
    local fs = love.filesystem
    local serpent = require "serpent"

    local col = {1, 0, 0, 1}
    local inspect = require "inspect"
    while true do
        love.graphics.setColor(col)

        local verts = graphic_command_channel:demand()
        --local verts = graphic_command_channel:pop()
        love.graphics.polygon('fill', verts)

        --fs.append('verts.txt', serpent.dump(verts) .. "\n")

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

    pipeline:pushCode('set_transform', [[
    local gr = love.graphics
    local yield = coroutine.yield
    while true do
        gr.applyTransform(graphic_command_channel:demand())
        yield()
    end
    ]])

    pipeline:pushCode('pop_transform', [[
    local gr = love.graphics
    local yield = coroutine.yield
    while true do
        gr.origin()
        yield()
    end
    ]])

    -- }}}
end

--local tanks_num = 20
local tanks_num = 500

local id_counter = 0

local function make_id(): integer
    id_counter = id_counter + 1
    return id_counter
end

local camera: love.math.Transform = love.math.newTransform()

local function spawnPolyShapesObjects()
    local w, h = love.graphics.getDimensions()
    for _ = 1, tanks_num do
        local xp, yp = love.math.random(1, w), love.math.random(1, h)
        local body = pw.newBoxBody(xp, yp)
        local tank: Tank = {
            first_render = true,
            body = body,
            id = make_id(),
        }
        body.user_data = tank
        table.insert(tanks, tank)

        local minx, miny = -6000, -6000
        local maxx, maxy = 12000, 12000
        local rand = love.math.random
        local posx, posy = rand(minx, maxx), rand(miny, maxy)

        body:bodySetPosition(posx, posy)
    end
end

local function init()
    initJoy()
    initRenderCode()
    pw.init(pipeline)
    spawnPolyShapesObjects()
    debug_print("phys", 'pw.getBodies()', inspect(pw.getBodies()))
    last_render = love.timer.getTime()
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

local function render_tanks()
    pw.eachSpaceBody(bodyIter)
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

    pipeline:open('set_transform')
    pipeline:push(camera)
    pipeline:close()

    render_tanks()

    pipeline:openAndClose('pop_transform')

    print_io_rate()
    circle_under_mouse()
    pipeline:openAndClose 'print_debug_filters'

    pipeline:sync()
end

local is_stop = false
local lvec = require "vector-light"

local function gather_verts(shape: Cm.cpShape): {number}
    local num = pw.polyShapeGetCount(shape)
    local verts = {}
    for i = 0, num - 1 do
        local vert = pw.polyShapeGetVert(shape, i)
        table.insert(verts, vert.x)
        table.insert(verts, vert.y)
    end
    return verts
end

local function eachShape_smart(b: Cm.cpBody, shape: Cm.cpShape)
    --debug_print('phys', 'eachShape call')

    local shape_type = pw.polyShapeGetType(shape)

    if shape_type == pw.CP_POLY_SHAPE then

        -- Возможно стоит поместить формирование таблички в 
        -- вспомогательную библиотеку или переписать с прямым доступом к
        -- shape->planes[i].v0

        local body_wrap = pw.cpBody2Body(b)
        local tank = body_wrap.user_data as Tank

        if not tank then
            error("tank is nil")
        end

        pipeline:open('poly_shape_smart')
        pipeline:push(tank.id)

        if tank.first_render then
            local verts = gather_verts(shape)
            pipeline:push('new')
            pipeline:push(verts)

            tank.first_render = false
            tank.prev_posx = body_wrap.body.p.x
            tank.prev_posy = body_wrap.body.p.y
        else
            -- сравнивать не только линейную скорость, но и угловую
            local len = lvec.len(b.v.x, b.v.y)
            local epsilon = 0.0001 
            if len < epsilon then
                pipeline:push('draw')
                --print('draw')
            else
                --pipeline:push('draw')
                local verts = gather_verts(shape)
                pipeline:push('new')
                pipeline:push(verts)
                tank.first_render = true
            end

        end

        pipeline:close()
    end
    --]]
end

local function eachShape(b: Cm.cpBody, shape: Cm.cpShape)
    local shape_type = pw.polyShapeGetType(shape)
    if shape_type == pw.CP_POLY_SHAPE then

        --local body_wrap = pw.cpBody2Body(b)
        --local tank = body_wrap.user_data as Tank

        pipeline:open('poly_shape')
        local verts = gather_verts(shape)
        pipeline:push(verts)
        pipeline:close()
    end
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
--shapeIter = pw.newEachBodyShapeIter(eachShape)
shapeIter = pw.newEachBodyShapeIter(eachShape_smart)

-- применять dt с прошлого кадра или dt полученный из pipeline?
local function cameraScale(j: Joystick)
    local axes = {j:getAxes()}
    local dy = axes[2]
    local factor = 0.01
    if dy > 0 then
        camera:scale(1 + factor, 1 + factor)
    elseif dy < 0 then
        camera:scale(1 - factor, 1 - factor)
    end
end

-- применять dt с прошлого кадра или dt полученный из pipeline?
local function cameraMovement(j: Joystick)
    local axes = {j:getAxes()}
    local dx, dy = axes[4], axes[5]
    local amount_x, amount_y = 10, 10
    local tx, ty = 0, 0
    local changed = false

    if dx > 0 then
        changed = true
        tx = -amount_x
    elseif dx < 0 then
        changed = true
        tx = amount_x
    end

    if dy > 0 then
        changed = true
        ty = -amount_y
    elseif dy < 0 then
        changed = true
        ty = amount_y
    end

    if changed then
        camera:translate(tx, ty)
    end
end

local function applyInput()
    local leftBtn, rightBtn, downBtn, upBtn = 3, 2, 1, 4
    local k = 0.1
    local tank: pw.Body = tanks[1].body
    if joy then
        --[[
        local dx, dy, _ = joy:getAxes()
        if dx and dy then
            local divisor = 20
            dx, dy = dx / divisor, dy / divisor
            tank:applyImpulse(dx, dy)
        end
        --]]

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

        cameraScale(joy)
        cameraMovement(joy)
    end
end

local function updateJoyState()
    joyState:update()
    if joyState.state and joyState.state ~= "" then
        --debug_print('joy', joyState.state)
        print('joy', joyState.state)
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

            --local sock = require 'socket'
            --sock.sleep(5)
            --print('os.exit(100)')
            --os.exit(100)
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
