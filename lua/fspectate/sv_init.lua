util.AddNetworkString( "fSpectate" )
util.AddNetworkString( "fSpectateTarget" )
util.AddNetworkString( "fSpectateName" )

local function findPlayer( info )
    if not info or info == "" then return nil end
    local pls = player.GetAll()

    for k = 1, #pls do
        local v = pls[k]
        if tonumber( info ) == v:UserID() then return v end
        if info == v:SteamID() then return v end
        if string.find( string.lower( v:Nick() ), string.lower( tostring( info ) ), 1, true ) ~= nil then return v end
    end

    return nil
end

local fSpectating = {}

-- For Lua Refresh
for _, ply in ipairs( player.GetHumans() ) do
    fSpectating[ply] = ply.fSpectating
end

local function clearInvalidSpectators()
    for ply, _ in pairs( fSpectating ) do
        if not IsValid( ply ) then
            fSpectating[ply] = nil
        end
    end
end

local function startSpectating( ply, target )
    local canSpectate = hook.Call( "fSpectate_canSpectate", nil, ply, target )
    if canSpectate == false then return end
    -- Clear invalid spectators from the fSpectating table to prevent build up.
    clearInvalidSpectators()
    ply.fSpectatingEnt = target
    ply.fSpectating = true
    fSpectating[ply] = true
    ply:ExitVehicle()
    net.Start( "fSpectate" )
    net.WriteBool( target == nil )

    if IsValid( ply.fSpectatingEnt ) then
        net.WriteEntity( ply.fSpectatingEnt )
    end

    net.Send( ply )

    local targetText
    if IsValid( target ) then
        if target:IsPlayer() then
            targetText = target:Nick() .. " (" .. target:SteamID() .. ")"
        else
            local targetOwner = target:CPPIGetOwner()
            if targetOwner then
                targetText = target:GetClass() .. " owned by: " .. targetOwner:Nick() .. " (" .. targetOwner:SteamID() .. ")"
            else
                targetText = target:GetClass()
            end
        end
    else
        targetText = ""
    end

    ply:ChatPrint( "You are now spectating " .. targetText )
    hook.Call( "fSpectate_start", nil, ply, target )
end

local function Spectate( ply, _, args )
    CAMI.PlayerHasAccess( ply, "fSpectate", function( b, _ )
        if not b then
            ply:ChatPrint( "No Access!" )

            return
        end

        local target = findPlayer( args[1] )

        if target == ply then
            ply:ChatPrint( "Invalid target!" )

            return
        end

        startSpectating( ply, target )
    end )
end

net.Receive( "fSpectateName", function( _, ply )
    Spectate( ply, _, { net.ReadString() } )
end )

net.Receive( "fSpectateTarget", function( _, ply )
    CAMI.PlayerHasAccess( ply, "fSpectate", function( b, _ )
        if not b then
            ply:ChatPrint( "No Access!" )

            return
        end

        startSpectating( ply, net.ReadEntity() )
    end )
end )

local function TPToPos( ply, _, args )
    if GAMEMODE_NAME == "terrortown" then return end
    CAMI.PlayerHasAccess( ply, "fSpectateTeleport", function( b, _ )
        if not b then
            ply:ChatPrint( "No Access!" )

            return
        end

        local x, y, z = string.match( args[1] or "", "([-0-9\\.]+),%s?([-0-9\\.]+),%s?([-0-9\\.]+)" )
        local vx, vy, vz = string.match( args[2] or "", "([-0-9\\.]+),%s?([-0-9\\.]+),%s?([-0-9\\.]+)" )
        local pos = Vector( tonumber( x ), tonumber( y ), tonumber( z ) )
        local vel = Vector( tonumber( vx or 0 ), tonumber( vy or 0 ), tonumber( vz or 0 ) )
        if not args[1] or not x or not y or not z then return end
        ply:SetPos( pos )

        if vx and vy and vz then
            ply:SetVelocity( vel )
        end

        hook.Call( "FTPToPos", nil, ply, pos )
    end )
end

concommand.Add( "FTPToPos", TPToPos )

local function SpectateVisibility( ply, _ )
    if not ply.fSpectating then return end

    if IsValid( ply.fSpectatingEnt ) then
        AddOriginToPVS( ply.fSpectatingEnt:IsPlayer() and ply.fSpectatingEnt:GetShootPos() or ply.fSpectatingEnt:GetPos() )
    end

    if ply.fSpectatePos then
        AddOriginToPVS( ply.fSpectatePos )
    end
end

hook.Add( "SetupPlayerVisibility", "fSpectate", SpectateVisibility )

local function setSpectatePos( ply, _, args )
    CAMI.PlayerHasAccess( ply, "fSpectate", function( b, _ )
        if not b then return end
        if not ply.fSpectating or not args[3] then return end
        local x, y, z = tonumber( args[1] or 0 ), tonumber( args[2] or 0 ), tonumber( args[3] or 0 )
        ply.fSpectatePos = Vector( x, y, z )
        -- A position update request implies that the spectator is not spectating another player (anymore)
        ply.fSpectatingEnt = nil
    end )
end

concommand.Add( "_fSpectatePosUpdate", setSpectatePos )

local function endSpectate( ply )
    ply.fSpectatingEnt = nil
    ply.fSpectating = nil
    ply.fSpectatePos = nil
    fSpectating[ply] = nil
    hook.Call( "fSpectate_stop", nil, ply )
end

concommand.Add( "fSpectate_StopSpectating", endSpectate )
local vrad = DarkRP and GM.Config.voiceradius
local voiceDistance = DarkRP and GM.Config.voiceDistance * GM.Config.voiceDistance or 302500 -- Default 550 units

local function playerVoice( listener, talker )
    if not fSpectating[listener] then return end
    local canHearLocal, surround = GAMEMODE:PlayerCanHearPlayersVoice( listener, talker )
    -- No need to check other stuff
    if canHearLocal then return canHearLocal, surround end
    local fSpectatingEnt = listener.fSpectatingEnt

    if not IsValid( fSpectatingEnt ) or not fSpectatingEnt:IsPlayer() then
        local spectatePos = IsValid( fSpectatingEnt ) and fSpectatingEnt:GetPos() or listener.fSpectatePos
        if not vrad or not spectatePos then return end
        -- Return whether the listener is a in distance smaller than 550

        return spectatePos:DistToSqr( talker:GetPos() ) < voiceDistance, surround
    end

    -- you can always hear the person you're spectating
    if fSpectatingEnt == talker then return true, surround end
    -- You can hear someone if your spectate target can hear them
    local canHear = GAMEMODE:PlayerCanHearPlayersVoice( fSpectatingEnt, talker )

    return canHear, surround
end

hook.Add( "PlayerCanHearPlayersVoice", "fSpectate", playerVoice )

local function playerSay( talker, message )
    local split = string.Explode( " ", message )

    if split[1] and ( split[1] == "!spectate" or split[1] == "/spectate" ) then
        Spectate( talker, split[1], { split[2] } )

        return ""
    end

    if not DarkRP then return end
    local talkerTeam = team.GetColor( talker:Team() )
    local talkerName = talker:Nick()
    local col = Color( 255, 255, 255, 255 )

    for _, ply in ipairs( player.GetAll() ) do
        if ply == talker or not ply.fSpectating then continue end
        local shootPos = talker:GetShootPos()
        local fSpectatingEnt = ply.fSpectatingEnt

        if ply:GetShootPos():DistToSqr( shootPos ) > 62500 and ( ply.fSpectatePos and shootPos:DistToSqr( ply.fSpectatePos ) <= 360000 or ( IsValid( fSpectatingEnt ) and fSpectatingEnt:IsPlayer() and shootPos:DistToSqr( fSpectatingEnt:GetShootPos() ) <= 90000 ) or ( IsValid( fSpectatingEnt ) and not fSpectatingEnt:IsPlayer() and talker:GetPos():DistToSqr( fSpectatingEnt:GetPos() ) <= 90000 ) ) then
            -- Make sure you don't get it twice
            -- the person is saying it close to where you are roaming
            -- The person you're spectating or someone near the person you're spectating is saying it
            -- Close to the object you're spectating
            DarkRP.talkToPerson( ply, talkerTeam, talkerName, col, message, talker )

            return
        end
    end
end

hook.Add( "PlayerSay", "fSpectate", playerSay )

-- ULX' !spectate command conflicts with mine
-- The concommand "ulx spectate" should still work.
local function fixAdminModIncompat()
    if ULib then
        ULib.removeSayCommand( "!spectate" )
    end

    if serverguard then
        serverguard.command:Remove( "spectate" )
    end
end

hook.Add( "InitPostEntity", "fSpectate", fixAdminModIncompat )
