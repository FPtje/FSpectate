if not CAMI then return end

CAMI.RegisterPrivilege{
    Name = "fSpectate",
    MinAccess = "admin"
}

CAMI.RegisterPrivilege{
    Name = "fSpectateTeleport",
    MinAccess = "admin"
}
