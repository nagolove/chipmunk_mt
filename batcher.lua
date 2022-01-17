-- vim: fdm=marker
-- vim: set colorcolumn=85

meshBufferSize = 1024
local gr = love.graphics

local ffi = require('ffi')
ffi.cdef[[
typedef struct {
  float x, y;
  float u, v;
  unsigned char r, g, b, a;
} fm_vertex;
]]
local vertex_size = ffi.sizeof('fm_vertex')
print('vertex_size', vertex_size)
local pixel_size = ffi.sizeof('unsigned char[4]')
print('pixel_size', pixel_size)
local num_verts = meshBufferSize * 6
--local imageData = love.image.newImageData(num_verts / pixel_size * vertex_size, 1)
--local byteData = love.data.newByteData(num_verts * pixel_size)
--print("width", num_verts / pixel_size * vertex_size, 1)
--local dataptr = ffi.cast("fm_vertex*", imageData:getPointer())
--local dataptr = ffi.cast("fm_vertex*", byteData:getPointer())

local colorWhite = {1, 1, 1, 1}

local inspect = require 'inspect'

local function printImageData(imageData)
    local dataptr = ffi.cast("fm_vertex*", imageData:getPointer())
    for i = 0, baseMeshCount * 6 do
        local vert = dataptr[i]
        print("[" .. tostring(i) .. "] x, y, u, v, r, g, b, a", x, y, u, v, r, g, b, a)
        print('i', i)
        print("vert.x", vert.x)
        print("vert.y", vert.y)
        print("vert.u", vert.u)
        print("vert.v", vert.v)
        print("vert.r", vert.r)
        print("vert.g", vert.g)
        print("vert.b", vert.b)
        print("vert.a", vert.a)
    end
end

local function printImageData2file(imageData, fname)
    local dataptr = ffi.cast("fm_vertex*", imageData:getPointer())
    for i = 0, baseMeshCount * 6 do
        local vert = dataptr[i]
        local x, y, u, v, r, g, b, a = vert.x, vert.y, vert.u, vert.v, vert.r, vert.g, vert.b, vert.b, vert.a
        local s = 
            "[" .. tostring(i) .. "] " ..  
            x .. " " .. y .. " " .. 
            u .. " " .. v .. " " ..  
            r .. " " .. g .. " " ..  
            b .. " " .. a .. "\n"
        love.filesystem.append(fname, s)
    end
end

Batch = {}

function Batch.new(texfname)
    local self = setmetatable({}, { __index = Batch, })
    self.imageData = love.image.newImageData(num_verts / pixel_size * vertex_size, 1)
    self.dataptr = ffi.cast("fm_vertex*", self.imageData:getPointer())
    
    self.mesh = gr.newMesh(meshBufferSize * 6, "triangles", "dynamic")
    --self.image = love.graphics.newImage(SCENE_PREFIX .. "/tank_body_small.png")
    self.image = love.graphics.newImage(SCENE_PREFIX .. "/" .. texfname)
    self.mesh:setTexture(self.image)

    self.meshIndex = 0
    self.meshCount = 0

    return self
end

function Batch:flush()
    self.mesh:setVertices(self.imageData)
    --basesMesh:setDrawRange(1, baseMeshIndex)
    --printImageData(imageData)
    --os.exit()

    love.graphics.setColor(colorWhite)
    love.graphics.draw(self.mesh, 0, 0)
    self.meshIndex = 0
    self.meshCount = 0
end

function Batch:present(
    x1, y1, x2, y2, x3, y3, x4, y4,
    rx, ry, rw, rh, color
)
    -- {{{
    
    -- размеры текстуры в пикселях
    local imgw, imgh = self.image:getDimensions()
    -- нормализованная ширина и высота
    local unitw, unith = rw / imgw, rh / imgh
    -- нормализованные координаты левого верхнего угла выделения
    local x_, y_ = rx / imgw, ry / imgh

    --local vertex

    --vertex = dataptr[self.meshIndex + 1]
    self.dataptr[self.meshIndex].x = x1
    self.dataptr[self.meshIndex].y = y1
    self.dataptr[self.meshIndex].u = x_ + unitw
    self.dataptr[self.meshIndex].v = y_
    self.dataptr[self.meshIndex].r = color[1] * 255
    self.dataptr[self.meshIndex].g = color[2] * 255
    self.dataptr[self.meshIndex].b = color[3] * 255
    self.dataptr[self.meshIndex].a = color[4] * 255

    --vertex = dataptr[self.meshIndex + 2]
    self.dataptr[self.meshIndex + 1].x = x2
    self.dataptr[self.meshIndex + 1].y = y2
    self.dataptr[self.meshIndex + 1].u = x_ + unitw
    self.dataptr[self.meshIndex + 1].v = y_ + unith
    self.dataptr[self.meshIndex + 1].r = color[1] * 255
    self.dataptr[self.meshIndex + 1].g = color[2] * 255
    self.dataptr[self.meshIndex + 1].b = color[3] * 255
    self.dataptr[self.meshIndex + 1].a = color[4] * 255

    --vertex = dataptr[self.meshIndex + 3]
    self.dataptr[self.meshIndex + 2].x = x4
    self.dataptr[self.meshIndex + 2].y = y4
    self.dataptr[self.meshIndex + 2].u = x_
    self.dataptr[self.meshIndex + 2].v = y_
    self.dataptr[self.meshIndex + 2].r = color[1] * 255
    self.dataptr[self.meshIndex + 2].g = color[2] * 255
    self.dataptr[self.meshIndex + 2].b = color[3] * 255
    self.dataptr[self.meshIndex + 2].a = color[4] * 255

    --vertex = dataptr[self.meshIndex + 5]
    self.dataptr[self.meshIndex + 4].x = x2
    self.dataptr[self.meshIndex + 4].y = y2
    self.dataptr[self.meshIndex + 4].u = x_ + unitw
    self.dataptr[self.meshIndex + 4].v = y_ + unith
    self.dataptr[self.meshIndex + 4].r = color[1] * 255
    self.dataptr[self.meshIndex + 4].g = color[2] * 255
    self.dataptr[self.meshIndex + 4].b = color[3] * 255
    self.dataptr[self.meshIndex + 4].a = color[4] * 255

    --vertex = dataptr[self.meshIndex + 6]
    self.dataptr[self.meshIndex + 5].x = x3
    self.dataptr[self.meshIndex + 5].y = y3
    self.dataptr[self.meshIndex + 5].u = x_
    self.dataptr[self.meshIndex + 5].v = y_ + unith
    self.dataptr[self.meshIndex + 5].r = color[1] * 255
    self.dataptr[self.meshIndex + 5].g = color[2] * 255
    self.dataptr[self.meshIndex + 5].b = color[3] * 255
    self.dataptr[self.meshIndex + 5].a = color[4] * 255

    --vertex = dataptr[self.meshIndex + 4]
    self.dataptr[self.meshIndex + 3].x = x4
    self.dataptr[self.meshIndex + 3].y = y4
    self.dataptr[self.meshIndex + 3].u = x_
    self.dataptr[self.meshIndex + 3].v = y_
    self.dataptr[self.meshIndex + 3].r = color[1] * 255
    self.dataptr[self.meshIndex + 3].g = color[2] * 255
    self.dataptr[self.meshIndex + 3].b = color[3] * 255
    self.dataptr[self.meshIndex + 3].a = color[4] * 255

     --DEBUG_TEXCOORDS 
    -- {{{
    if DEBUG_TEXCOORDS then
        --print('Do some printf.')
        --print('help me.')
    end
    -- }}}
    --]]

    --basesMesh:setVertices(basesMeshVerts, 1 + 6 * baseMeshCount, 6)

    --basesMesh:setVertices(basesMeshVerts)
    --basesMesh:setVertices(imageData, 1, 6)
    --basesMesh:setVertices(imageData)

    --basesMesh:setVertices(imageData, 1 + 6 * baseMeshCount, 6)
    --basesMesh:setVertices(basesMeshVerts, 1 + baseMeshIndex, 6)
    
    --print('baseMeshIndex', baseMeshIndex)
    --print('basesMesh:getDrawRange()', basesMesh:getDrawRange())

    --print('----------------------------------------------------------')
    --printMesh(basesMesh)
    --print('----------------------------------------------------------')
    
    if baseMeshIndex ~= 0 then
        --basesMesh:setDrawRange(1, baseMeshIndex/2)
    end
    --print("self.meshVerts", inspect(self.meshVerts))
    self.meshIndex = self.meshIndex + 6
    self.meshCount = self.meshCount + 1
    -- }}}
end

function Batch:prepare()
    self.meshIndex = 0
    self.meshCount = 0
end

--[[
return {
    base_present = base_present2,
    base_incponiter = base_incponiter,
    base_flush = base_flush,
}
--]]
