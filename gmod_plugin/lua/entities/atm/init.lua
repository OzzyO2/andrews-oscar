AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("libs/imgui.lua")

include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/testmodels/apple_display.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    local PhysObj = self:GetPhysicsObject()
    if PhysObj:IsValid() then
        PhysObj:Wake()
        self:SetColor(Color(150,150,150,255))
    end
end
