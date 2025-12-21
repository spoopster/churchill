ChurchillMod = RegisterMod("ChurchillMod", 1) ---@type ModReference

ChurchillMod.PLAYER_CHURCHILL = Isaac.GetPlayerTypeByName("Churchill", false) ---@type PlayerType

ChurchillMod.SFX_WINDUP = Isaac.GetSoundIdByName("Churchill Windup") ---@type SoundEffect
ChurchillMod.SFX_WINDDOWN = Isaac.GetSoundIdByName("Churchill Winddown") ---@type SoundEffect

include("scripts.churchill")


function ChurchillMod:lerp(a, b, f)
    return a*(1-f)+b*f
end
function ChurchillMod:toTps(n)
    return 30/(n+1)
end
function ChurchillMod:toFireDelay(n)
    return (30/n)-1
end

if(EID) then
    local iconSprite = Sprite("gfx/eid_icons.anm2", true)
    EID:addIcon("Player"..tostring(ChurchillMod.PLAYER_CHURCHILL), "Players", 0, 16, 16, 0, 0, iconSprite)

    EID.descriptions["en_us"].CharacterInfo[ChurchillMod.PLAYER_CHURCHILL] = {
        "Churchill",
        "\2 x0.3 fire rate while wound down, \1 x1.5 fire rate while wound up#Hold the Bomb button ({{ButtonLB}}) to wind up#While winding up, you are immobile#Maximum of 4 seconds wound up"
    }
    EID:addBirthright(
        ChurchillMod.PLAYER_CHURCHILL,
        "{{Bomb}} +5 Bombs#Immunity to explosions#Can be wound up for 10 seconds instead of 4#Placing a bomb makes it instantly explode and sets your wind up duration to the maximum"
    )
end