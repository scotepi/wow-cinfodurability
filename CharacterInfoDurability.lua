--[[


]]

--[[ Setup the addon ]]
CID = {}
CID.cache = {}
CID.events = {}
CID.frame = CreateFrame("Frame", "CIDFrame")
CID.addonName = "Character Info Durability"
CID.addonNameAbr = "CID"
--[[ end setup ]]


-- Temp settings we don't care about
CID.lastUpdate = 0;

-- Settings to be move to saved variables
CID.debug = false
CID.color = true

-- inventoryID to name
CID.iidName = {
    [INVSLOT_HEAD] = INVTYPE_HEAD,
    [INVSLOT_NECK] = INVTYPE_NECK,
    [INVSLOT_SHOULDER] = INVTYPE_SHOULDER,
    [INVSLOT_BODY] = INVTYPE_BODY,
    [INVSLOT_CHEST] = INVTYPE_CHEST,
    [INVSLOT_WAIST] = INVTYPE_WAIST,
    [INVSLOT_LEGS] = INVTYPE_LEGS,
    [INVSLOT_FEET] = INVTYPE_FEET,
    [INVSLOT_WRIST] = INVTYPE_WRIST,
    [INVSLOT_HAND] = INVTYPE_HAND,
    [INVSLOT_FINGER1] = INVTYPE_FINGER,
    [INVSLOT_FINGER2] = INVTYPE_FINGER,
    [INVSLOT_TRINKET1] = INVTYPE_TRINKET,
    [INVSLOT_TRINKET2] = INVTYPE_TRINKET,
    [INVSLOT_BACK] = INVTYPE_CLOAK,
    [INVSLOT_MAINHAND] = INVTYPE_WEAPONMAINHAND,
    [INVSLOT_OFFHAND] = INVTYPE_WEAPONOFFHAND,
    [INVSLOT_RANGED] = INVTYPE_RANGED,
    [INVSLOT_TABARD] = INVTYPE_TABARD,
}

local CID_GlobalDefault = {
    color = true,
}
local CID_LocalDefault = {
    debug = false,
}

function CID:OnInitialize()
    self:Print('Character Info Durability Loaded... r@project-revision@')

    -- Check saved variables
    if not CID_Global or type(CID_Global) ~= 'table' then CID_Global = CID_GlobalDefault end
    if not CID_Local or type(CID_Local) ~= 'table' then CID_Local = CID_LocalDefault end

    -- Add to Paperdoll
    table.insert(PAPERDOLL_STATCATEGORIES["GENERAL"].stats, 'CharacterInfoDurability')
    PAPERDOLL_STATINFO['CharacterInfoDurability'] = {
        updateFunc = function(...) CID:UpdatePaperDollFrame(...); end
    }

    -- Register events
    -- self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() CID:UpdatePaperDollFrame() end)
    -- self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", function() CID:UpdatePaperDollFrame() end)
end

function CID:Durability(item) 
    local durability, max = GetInventoryItemDurability(item)
    local average = false

    if max then
        average = durability / max
    end

    return average, durability, max
end

function CID:DurabilityAverage()
    local slots = {}
    local durability = 0
    local total = 0
    local minItem = 1
    local minSlot = false

    for i = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local a, d, m = self:Durability(i)

        slots[i] = {
            average = a,
            durability = d,
            max = m,
        }

        if d and m then
            durability = durability + d
            total = total + m
        end

        if a and a < minItem then
            minItem = a
            minSlot = i
        end
    end

    local average = false

    if total > 0 then
        average = durability / total
    end

    return average, minItem, minSlot, slots
end

function CID:UpdatePaperDollFrame(statFrame, unit)
    if not statFrame then return false end
    if self.lastUpdate == time() then return false end


    local average, minItem, minSlot, slots = self:DurabilityAverage();
    self.lastUpdate = time();

    self:Debug("Updating PaperDoll", average, min)
    minFormated = self:FormatDurability(minItem, false);
    avgFormatedC = self:FormatDurability(average);
    minFormatedC = self:FormatDurability(minItem);
    
    PaperDollFrame_SetLabelAndText(statFrame, DURABILITY, minFormated, false);
    statFrame.tooltip = format(gsub(DURABILITY_TEMPLATE, '%%d', '%%s'), minFormatedC, avgFormatedC)

    if average ~= 1 then
        statFrame.tooltip2 = format("%s: %s", self.iidName[minSlot], GetInventoryItemLink('player', minSlot))
    end
    
    statFrame:Show()
end

function CID:FormatDurability(value, colorize)
    if type(colorize) == 'nil' then colorize = true end

    local formated = (("%%.%df"):format(0)):format(value * 100);

    if colorize and self:GetColor() then
        local color = "058633"
        
        if value < .25 then
            color = "720026";
        elseif value < .5 then
            color = "f6a01a";
        end

        return '|cFF'..color..formated..'%|r'
    else
        return formated..'%'
    end
end







--[[ Setters / Getters / Togglers ]]
function CID:SetDebug(v) CID_Local.debug = v end
function CID:GetDebug() return CID_Local.debug end
function CID:ToggleDebug() self:SetDebug(not self:GetDebug()) end

function CID:SetColor(v) CID_Global.color = v end
function CID:GetColor() return CID_Global.color end
function CID:ToggleColor() self:SetColor(not self:GetColor()) end






--[[ Ace3 Like methods and supporters ]]
function CID:RegisterEvent(event, callback)
    self.events[event] = callback
    self.frame:RegisterEvent(event)
end

function CID:OnEvent(event, ...)
    if type(self.events[event]) == 'function' then
        self.events[event](...);
    else
        self:Debug('No Callback for', event, ...)
    end
end

function CID:Print(...) print('|cFF3079ED'..self.addonNameAbr..':|r', ...); end
function CID:Debug(...) if self:GetDebug() then print('|cFFFF0000'..self.addonNameAbr..' Debug:|r', ...); end end

-- Special Functions
local function OnEvent(self, ...) CID:OnEvent(...) end

-- Register handlers
CID.frame:SetScript("OnEvent", OnEvent);
CID:RegisterEvent("PLAYER_LOGIN", function() CID:OnInitialize(); end);