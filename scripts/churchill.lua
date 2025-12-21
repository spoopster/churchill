local sfx = SFXManager()

local START_LAG = 20
local END_LAG = 16

local DMG_MULT = 1.05

local BASE_TEARS_MULT = 0.3
local WINDUP_TEARS_MULT = 1.5

local MAX_WINDUP_DURATION = 60*4
local BIRTHRIGHT_MAX_WINDUP = 60*10
local WINDUP_PER = 40

local WINDDOWN_FREQ = 9

local FADE_NUM = 3
local FADE_FREQ = 6

---@param pl EntityPlayer
local function churchillInit(_, pl)
    if(pl:GetPlayerType()~=ChurchillMod.PLAYER_CHURCHILL) then return end

    local data = pl:GetData()
    data.HELD_BOMB = 0
    data.NOT_HELD_BOMB = 0

    data.TARGET_TEARS = 0
    data.CURRENT_TEARS = 0

    data.WINDUP = 0

    local sp = pl:GetSprite()
    sp:Load("gfx/characters/character_churchill.anm2", true)
end
ChurchillMod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, churchillInit, PlayerVariant.PLAYER)

---@param pl EntityPlayer
local function churchillUpdate(_, pl)
    if(pl:GetPlayerType()~=ChurchillMod.PLAYER_CHURCHILL) then return end

    local data = pl:GetData()
    local sp = pl:GetSprite()

    data.PLACE_BOMB = nil

    if(Input.IsActionPressed(ButtonAction.ACTION_BOMB, pl.ControllerIndex)) then
        data.HELD_BOMB = (data.HELD_BOMB or 0)+1
    else
        data.NOT_HELD_BOMB = (data.NOT_HELD_BOMB or 0)+1
    end

    if(data.NOT_HELD_BOMB==1) then
        if(data.HELD_BOMB<START_LAG and data.HELD_BOMB>0) then
            data.PLACE_BOMB = true
        end
        data.HELD_BOMB = 0

        pl:PlayExtraAnimation("WindUpEnd")
    end

    if(data.HELD_BOMB==1) then
        data.NOT_HELD_BOMB = 0
        pl:PlayExtraAnimation("WindUpStart")
    elseif(data.HELD_BOMB==START_LAG) then
        pl:PlayExtraAnimation("WindUpIdle")
    end

    if(sp:IsEventTriggered("WindUpSFX")) then
        sfx:Stop(ChurchillMod.SFX_WINDDOWN)
        sfx:Play(ChurchillMod.SFX_WINDUP, 1, 2, false, 1+math.random(-5,5)/5*0.1)

        --pl:AddCacheFlags(CacheFlag.CACHE_FIREDELAY, true)

        local maxDuration = (pl:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) and BIRTHRIGHT_MAX_WINDUP or MAX_WINDUP_DURATION)
        data.WINDUP = math.min((data.WINDUP or 0)+WINDUP_PER, maxDuration)
        data.SUPERCHARGE = nil
    end

    data.WINDUP = data.WINDUP or 0
    if(data.WINDUP>0 and data.WINDUP%WINDDOWN_FREQ==1) then
        local selFrame = data.WINDUP//WINDDOWN_FREQ % 4
        if(data.WINDUP==1) then
            data.SUPERCHARGE = nil
        end

        local map = pl:GetCostumeLayerMap()
        local descs = pl:GetCostumeSpriteDescs()
        for _, mapdata in ipairs(map) do
            if(mapdata.costumeIndex~=-1) then
                local desc = descs[mapdata.costumeIndex+1]
                local costumeSp = desc:GetSprite()

                if(string.find(costumeSp:GetFilename(), "costume_churchill")) then
                    local path = "gfx/characters/costume_churchill"..(data.SUPERCHARGE and "1" or "")..tostring(selFrame)..".png"
                    costumeSp:ReplaceSpritesheet(0, path)
                    costumeSp:LoadGraphics()
                end
            end
        end
    end
    
    if(data.NOT_HELD_BOMB>0) then
        if(data.WINDUP>0) then
            if(data.WINDUP==1) then
                sfx:Stop(ChurchillMod.SFX_WINDDOWN)
            elseif(not sfx:IsPlaying(ChurchillMod.SFX_WINDDOWN)) then
                sfx:Play(ChurchillMod.SFX_WINDDOWN, 0.6, 2, true, 1, 0)
            end

            if(data.WINDUP%6==0) then
                sfx:AdjustPitch(ChurchillMod.SFX_WINDDOWN, 1+math.random(-5,5)/5*0.1)
            end
        end

        data.WINDUP = math.max(0, data.WINDUP-1)
    end

    if(data.WINDUP==0) then
        data.TARGET_TEARS = 0
        data.SUPERCHARGE = nil
    else
        data.TARGET_TEARS = 1
    end

    data.TARGET_TEARS = data.TARGET_TEARS or 0
    data.CURRENT_TEARS = data.CURRENT_TEARS or data.TARGET_TEARS

    if(math.abs(data.CURRENT_TEARS-data.TARGET_TEARS)>0.01) then
        if((data.HELD_BOMB>0 and data.HELD_BOMB%FADE_FREQ==0) or (data.NOT_HELD_BOMB>0 and data.NOT_HELD_BOMB%FADE_FREQ==0)) then
            if(data.TARGET_TEARS>data.CURRENT_TEARS) then
                data.CURRENT_TEARS = math.min(data.TARGET_TEARS, data.CURRENT_TEARS+1/FADE_NUM)
            else
                data.CURRENT_TEARS = math.max(data.TARGET_TEARS, data.CURRENT_TEARS-1/FADE_NUM)
            end

            pl:AddCacheFlags(CacheFlag.CACHE_FIREDELAY, true)
        end
    else
        data.CURRENT_TEARS = data.TARGET_TEARS
    end
end
ChurchillMod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, churchillUpdate, PlayerVariant.PLAYER)

-- birthright stuff

---@param firsttime boolean
---@param pl EntityPlayer
local function getBirthright(_, _, _, firsttime, _, _, pl)
    if(firsttime and pl:GetPlayerType()==ChurchillMod.PLAYER_CHURCHILL) then
        pl:AddBombs(5)
    end
end
ChurchillMod:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, getBirthright, CollectibleType.COLLECTIBLE_BIRTHRIGHT)

---@param pl EntityPlayer
---@param bomb EntityBomb
local function placeBomb(_, pl, bomb)
    if(not (pl:GetPlayerType()==ChurchillMod.PLAYER_CHURCHILL and pl:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT))) then return end

    bomb:SetExplosionCountdown(0)
    pl:GetData().WINDUP = BIRTHRIGHT_MAX_WINDUP
    pl:GetData().SUPERCHARGE = true

    for _=1, 8 do
        local angle = math.random(1,360)
        local timeout = math.random(4,8)

        local laser = EntityLaser.ShootAngle(LaserVariant.ELECTRIC, pl.Position, angle, timeout, Vector.Zero, pl)
        laser:SetDamageMultiplier(0)
        laser:SetDisableFollowParent(true)
        laser:SetMaxDistance(math.random(50,150))
    end
end
ChurchillMod:AddCallback(ModCallbacks.MC_POST_PLAYER_USE_BOMB, placeBomb, PlayerVariant.PLAYER)

---@param pl EntityPlayer
---@param flags DamageFlag
local function cancelExplosionDamage(_, pl, _, flags)
    if(not (pl:GetPlayerType()==ChurchillMod.PLAYER_CHURCHILL and pl:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT))) then return end

    if(flags & DamageFlag.DAMAGE_EXPLOSION == DamageFlag.DAMAGE_EXPLOSION) then
        return false
    end
end
ChurchillMod:AddCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG, cancelExplosionDamage)

local MOVE_ACTIONS = {
    [ButtonAction.ACTION_UP] = 0,
    [ButtonAction.ACTION_DOWN] = 0,
    [ButtonAction.ACTION_LEFT] = 0,
    [ButtonAction.ACTION_RIGHT] = 0,
}

---@param ent Entity
---@param hook InputHook
---@param action ButtonAction
local function inputstuff(_, ent, hook, action)
    if(not (ent and ent:ToPlayer())) then return end
    local pl = ent:ToPlayer() or Isaac.GetPlayer() ---@type EntityPlayer
    if(pl:GetPlayerType()~=ChurchillMod.PLAYER_CHURCHILL) then return end

    if(action==ButtonAction.ACTION_BOMB) then
        if(hook==InputHook.IS_ACTION_TRIGGERED or hook==InputHook.IS_ACTION_PRESSED) then
            return (pl:GetData().PLACE_BOMB and true or false)
        elseif(hook==InputHook.GET_ACTION_VALUE) then
            return (pl:GetData().PLACE_BOMB and 1.0 or 0.0)
        end
    elseif(pl:GetData().HELD_BOMB and pl:GetData().HELD_BOMB>0 and MOVE_ACTIONS[action]) then
        if(hook==InputHook.IS_ACTION_PRESSED or hook==InputHook.IS_ACTION_TRIGGERED) then
            return false
        elseif(hook==InputHook.GET_ACTION_VALUE) then
            return 0
        end
    end
end
ChurchillMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputstuff)

---@param pl EntityPlayer
local function churchillTearsMult(_, pl)
    if(pl:GetPlayerType()~=ChurchillMod.PLAYER_CHURCHILL) then return end

    local lerp = pl:GetData().CURRENT_TEARS or 0
    local tearsMult = ChurchillMod:lerp(BASE_TEARS_MULT, WINDUP_TEARS_MULT, lerp)

    pl.MaxFireDelay = ChurchillMod:toFireDelay(ChurchillMod:toTps(pl.MaxFireDelay)*tearsMult)
end
ChurchillMod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE, CallbackPriority.LATE, churchillTearsMult, CacheFlag.CACHE_FIREDELAY)

---@param pl EntityPlayer
local function churchillDamageMult(_, pl)
    if(pl:GetPlayerType()~=ChurchillMod.PLAYER_CHURCHILL) then return end

    pl.Damage = pl.Damage*DMG_MULT
end
ChurchillMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, churchillDamageMult, CacheFlag.CACHE_DAMAGE)