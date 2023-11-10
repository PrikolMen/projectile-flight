local engine_TickInterval = engine.TickInterval
local physenv_GetGravity = physenv.GetGravity
local util_TraceHull = util.TraceHull
local timer_Simple = timer.Simple
local math_max = math.max
local IsValid = IsValid

local addonName = "Projectile Flight"
local allowedClasses = {
    ["npc_grenade_bugbait"] = true,
    ["prop_combine_ball"] = false,
    ["npc_grenade_frag"] = false,
    ["crossbow_bolt"] = true,
    ["rpg_missile"] = true,
    ["grenade_ar2"] = false
}

do

    local fileName = string.gsub( string.lower( addonName ), "[%p%s%c]+", "_" ) .. ".json"
    if file.Exists( fileName, "DATA" ) then
        local json = file.Read( fileName, "DATA" )
        if isstring( json ) then
            local tbl = util.JSONToTable( json )
            if istable( tbl ) then
                table.Merge( allowedClasses, tbl )
            end
        end
    else
        file.Write( fileName, util.TableToJSON( allowedClasses, true ) )
    end

end

local cvarFlags = bit.bor( FCVAR_ARCHIVE, FCVAR_NOTIFY )
for className, default in pairs( allowedClasses ) do
    local conVar = CreateConVar( "mp_allow_flight_on_" .. className, default and "1" or "0", cvarFlags, "Allows players to fly on '" .. className .. "'.", 0, 1 )
    allowedClasses[ className ] = conVar:GetBool()
    cvars.AddChangeCallback( conVar:GetName(), function( _, __, value )
        allowedClasses[ className ] = tobool( value )
    end, addonName )
end

local MOVETYPE_WALK = MOVETYPE_WALK
local MOVETYPE_NONE = MOVETYPE_NONE

hook.Add( "OnEntityCreated", addonName, function( entity )
    if not allowedClasses[ entity:GetClass() ] then return end

    timer_Simple( 0, function()
        if not entity:IsValid() then return end

        local ply = entity:GetOwner()
        if not IsValid( ply ) then return end
        if not ply:IsPlayer() then return end
        if ply:GetMoveType() ~= MOVETYPE_WALK then return end

        if ply:GetInfo( "cl_projectile_flight_automatic" ) == "1" then
            if ply:KeyDown( IN_WALK ) then return end
        elseif not ply:KeyDown( IN_WALK ) then return end

        ply[ addonName ] = entity
    end )
end )

hook.Add( "Move", addonName, function( ply, mv )
    local entity = ply[ addonName ]
    if not entity then return end

    if not entity:IsValid() or not ply:Alive() or ply:GetMoveType() ~= MOVETYPE_WALK or entity:GetMoveType() == MOVETYPE_NONE then
        ply[ addonName ] = nil
        return
    end

    local velocity = entity:GetVelocity()
    if mv:KeyDown( IN_JUMP ) then
        mv:SetVelocity( velocity )
        ply[ addonName ] = nil
        return
    end

    local mins, maxs
    if mv:KeyDown( IN_DUCK ) then
        mins, maxs = ply:GetHullDuck()
    else
        mins, maxs = ply:GetHull()
    end

    mins[ 3 ] = maxs[ 3 ] / 2

    local filter = entity[ addonName ]
    if not filter then
        filter = { ply, entity }
        entity[ addonName ] = entity[ addonName ]
    end

    local tickInterval = engine_TickInterval()
    velocity = velocity * tickInterval / 2

    local pos = entity:LocalToWorld( entity:OBBCenter() )
    if util_TraceHull( { start = pos, endpos = pos - velocity, filter = filter, mins = mins, maxs = maxs } ).Hit then
        ply[ addonName ] = nil
        return
    end

    mv:SetOrigin( pos )
    mv:SetVelocity( velocity - math_max( 1, ply:GetGravity() ) * physenv_GetGravity() * tickInterval / 2 )
end )