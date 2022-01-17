--[[
local record Render
    base_present: function(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, x4: number, y4 : number, rx: number, ry: number, rw: number, rh: number)
    base_present2: function(x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, x4: number, y4 : number, rx: number, ry: number, rw: number, rh: number)
    base_flush: function()
    base_incponiter: function()
end
--]]

require "love"

global record Batch
    new: function(texfname: string): Batch
    prepare: function(Batch)
    present: function(Batch,
        x1: number, y1: number, 
        x2: number, y2: number, 
        x3: number, y3: number, 
        x4: number, y4: number,
        rx: number, ry: number, 
        rw: number, rh: number,
        color: {number}
    )
    flush: function(Batch)

    image: love.graphics.Image
    imageData: love.image.ImageData
    dataptr: any
    meshIndex: integer
    meshCount: integer
end

global Batch_mt: metatable<Batch> = {
    __index = Batch,
}

--return Render
return Batch
