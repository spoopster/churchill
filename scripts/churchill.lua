local sfx = SFXManager()

local START_LAG = 20
local END_LAG = 16

local DMG_MULT = 1.05

local BASE_TEARS_MULT = 0.3
local WINDUP_TEARS_MULT = 1.4

local MAX_WINDUP_DURATION = 60*4
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

    if(data.HELD_BOMB>=START_LAG) then
        pl.Velocity = Vector.Zero
    elseif(data.HELD_BOMB>0) then
        pl.Velocity = pl.Velocity*0.6
    end

    if(sp:IsEventTriggered("WindUpSFX")) then
        sfx:Stop(ChurchillMod.SFX_WINDDOWN)
        sfx:Play(ChurchillMod.SFX_WINDUP, 1, 2, false, 1+math.random(-5,5)/5*0.1)

        --pl:AddCacheFlags(CacheFlag.CACHE_FIREDELAY, true)

        data.WINDUP = math.min((data.WINDUP or 0)+WINDUP_PER, MAX_WINDUP_DURATION)
    end

    data.WINDUP = data.WINDUP or 0
    if(data.WINDUP>0 and data.WINDUP%WINDDOWN_FREQ==1) then
        local selFrame = data.WINDUP//WINDDOWN_FREQ % 4

        local map = pl:GetCostumeLayerMap()
        local descs = pl:GetCostumeSpriteDescs()
        for _, mapdata in ipairs(map) do
            if(mapdata.costumeIndex~=-1) then
                local desc = descs[mapdata.costumeIndex+1]
                local costumeSp = desc:GetSprite()

                if(string.find(costumeSp:GetFilename(), "costume_churchill")) then
                    local path = "gfx/characters/costume_churchill"..tostring(selFrame)..".png"
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
    end
end
ChurchillMod:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputstuff)

---@param pl EntityPlayer
local function churchillTearsMult(_, pl)
    if(pl:GetPlayerType()~=ChurchillMod.PLAYER_CHURCHILL) then return end

    local lerp = pl:GetData().CURRENT_TEARS or 0
    local tearsMult = ChurchillMod:lerp(BASE_TEARS_MULT, WINDUP_TEARS_MULT, lerp)

    pl.MaxFireDelay = pl.MaxFireDelay/tearsMult
end
ChurchillMod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE, CallbackPriority.LATE, churchillTearsMult, CacheFlag.CACHE_FIREDELAY)

---@param pl EntityPlayer
local function churchillDamageMult(_, pl)
    if(pl:GetPlayerType()~=ChurchillMod.PLAYER_CHURCHILL) then return end

    pl.Damage = pl.Damage*DMG_MULT
end
ChurchillMod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, churchillDamageMult, CacheFlag.CACHE_DAMAGE)