local TickInterval = engine.TickInterval
local GetGravity = physenv.GetGravity
local TraceHull = util.TraceHull
local Simple = timer.Simple
local max = math.max
local addonName = "Projectile Flight"
local allowedClasses = {
	npc_grenade_bugbait = true,
	prop_combine_ball = false,
	npc_grenade_frag = false,
	crossbow_bolt = true,
	grenade_ar2 = false,
	rpg_missile = true
}
do
	local fileName = string.gsub(string.lower(addonName), "[%p%s%c]+", "_") .. ".json"
	if file.Exists(fileName, "DATA") then
		local json = file.Read(fileName, "DATA")
		if isstring(json) then
			local tbl = util.JSONToTable(json)
			if istable(tbl) then
				table.Merge(allowedClasses, tbl)
			end
		end
	else
		file.Write(fileName, util.TableToJSON(allowedClasses, true))
	end
end
do
	local flags = bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY)
	for className, default in pairs(allowedClasses) do
		local ConVar = CreateConVar("mp_allow_flight_on_" .. className, default and "1" or "0", flags, "Allows players to fly on '" .. className .. "'.", 0, 1)
		allowedClasses[className] = ConVar:GetBool()
		cvars.AddChangeCallback(ConVar:GetName(), function(_, __, value)
			allowedClasses[className] = tobool(value)
		end, addonName)
	end
end
local MOVETYPE_WALK = MOVETYPE_WALK
hook.Add("OnEntityCreated", addonName, function(self)
	if not allowedClasses[self:GetClass()] then
		return
	end
	return Simple(0, function()
		if not self:IsValid() then
			return
		end
		local owner = self:GetOwner()
		if not (owner:IsValid() and owner:IsPlayer() and owner:GetMoveType() == MOVETYPE_WALK) then
			return
		end
		if owner:GetInfo("cl_projectile_flight_automatic") == "1" then
			if owner:KeyDown(IN_WALK) then
				return
			end
		elseif not owner:KeyDown(IN_WALK) then
			return
		end
		owner[addonName] = self
	end)
end)
local MOVETYPE_NONE = MOVETYPE_NONE
local traceResult = { }
local trace = {
	output = traceResult
}
local halfTickInterval = 0
return hook.Add("Move", addonName, function(self, mv)
	local entity = self[addonName]
	if not entity then
		return
	end
	if not (entity:IsValid() and entity:GetMoveType() ~= MOVETYPE_NONE) then
		self[addonName] = nil
		return
	end
	local velocity = entity:GetVelocity()
	if not (self:Alive() and not mv:KeyDown(IN_JUMP) and self:GetMoveType() == MOVETYPE_WALK) then
		mv:SetVelocity(velocity)
		self[addonName] = nil
		return
	end
	local mins, maxs = self:GetCollisionBounds()
	mins[3] = maxs[3] / 2
	local filter = entity[addonName]
	if not filter then
		local className = entity:GetClass()
		filter = function(traceEntity)
			do
				local _exp_0 = traceEntity:GetClass()
				if "player" == _exp_0 then
					return traceEntity ~= self
				elseif className == _exp_0 then
					return traceEntity:GetOwner() ~= self
				end
			end
			return true
		end
		entity[addonName] = filter
	end
	halfTickInterval = TickInterval() * 0.5
	velocity = velocity * halfTickInterval
	trace.start = entity:WorldSpaceCenter()
	trace.endpos = trace.start - velocity
	trace.mins, trace.maxs = mins, maxs
	trace.filter = filter
	TraceHull(trace)
	if traceResult.Hit then
		self[addonName] = nil
		return
	end
	mv:SetOrigin(trace.start)
	return mv:SetVelocity(velocity - max(1, self:GetGravity()) * GetGravity() * halfTickInterval)
end)
