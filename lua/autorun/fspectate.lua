include("sh_cami.lua")
include("fspectate/sh_init.lua")

if SERVER then
    include("fspectate/sv_init.lua")
elseif CLIENT then
    include("fspectate/cl_init.lua")
end
