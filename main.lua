ChurchillMod = RegisterMod("ChurchillMod", 1) ---@type ModReference

ChurchillMod.PLAYER_CHURCHILL = Isaac.GetPlayerTypeByName("Churchill", false) ---@type PlayerType

ChurchillMod.SFX_WINDUP = Isaac.GetSoundIdByName("Churchill Windup") ---@type SoundEffect
ChurchillMod.SFX_WINDDOWN = Isaac.GetSoundIdByName("Churchill Winddown") ---@type SoundEffect

include("scripts.churchill")


function ChurchillMod:lerp(a, b, f)
    return a*(1-f)+b*f
end