include( "sh_cami.lua" )
include( "fspectate/sh_init.lua" )

if SERVER then
    AddCSLuaFile( "sh_cami.lua" )
    AddCSLuaFile( "fspectate/cl_init.lua" )
    AddCSLuaFile( "fspectate/sh_init.lua" )

    include( "fspectate/sv_init.lua" )
elseif CLIENT then
    include( "fspectate/cl_init.lua" )
end
