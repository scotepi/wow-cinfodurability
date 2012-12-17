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


-- Additional addon setup
CID.lastUpdate = 0;
CID.durability = false
CID.version = GetAddOnMetadata("CharacterInfoDurability", "Version")
CID.versionRev = 'r@project-revision@'
CID.ldb = LibStub:GetLibrary("LibDataBroker-1.1")


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
    self:Print('Character Info Durability Loaded... '..self.version..self.versionRev)

    -- Check saved variables
    if not CID_Global or type(CID_Global) ~= 'table' then CID_Global = CID_GlobalDefault end
    if not CID_Local or type(CID_Local) ~= 'table' then CID_Local = CID_LocalDefault end

    -- Add to Paperdoll
    table.insert(PAPERDOLL_STATCATEGORIES["GENERAL"].stats, 'CharacterInfoDurability')
    PAPERDOLL_STATINFO['CharacterInfoDurability'] = {
        updateFunc = function(...) CID:UpdatePaperDollFrame(...); end
    }

    -- Setup LDB
    local ldbObj = {
        type = "data source",
        icon = "Interface\\Icons\\inv_misc_powder_black",
        label = DURABILITY,
        text = '??',
        category = GetAddOnMetadata("CharacterInfoDurability", "X-Category"),
        version = self.version,
        OnClick = function(...) CID:ToggleColor(); CID:LDBText() end,
        OnTooltipShow = function(...) CID:LDBTooltip(...) end,
    };
    
    -- Start LDB
    self.ldb = self.ldb:NewDataObject(DURABILITY..' NewDataObject', ldbObj);

    -- Register events
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function() CID:CalculateDurability() end)
    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", function() CID:CalculateDurability() end)

    -- Calculate the Durability
    self:CalculateDurability()
end


-- Calculate the average, minimum, minslot and table of items durability
function CID:CalculateDurability()
    
    -- Check that we havent checked this second
    if self.lastUpdate == time() then
        
        -- We have a cache so use it
        if self.durability then
            return self.durability.average, self.durability.minItem, self.durability.minSlot , self.durability.slots
        else
            return false
        end
    end

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

    self.lastUpdate = time();

    self.durability = {
        average = average,
        minItem = minItem,
        minSlot = minSlot,
        slots = slots,
    }
    
    -- Update the LDB text
    self:LDBText()

    return average, minItem, minSlot, slots
end

-- Return the average, current and max durability for a given slot
function CID:Durability(item) 
    local durability, max = GetInventoryItemDurability(item)
    local average = false

    if max then
        average = durability / max
    end

    return average, durability, max
end

-- Update the paperdoll frame text
function CID:UpdatePaperDollFrame(statFrame, unit)
    if not statFrame then return false end

    local text1, text2 = self:TooltipText()

    -- Update Stat Frame
    local minFormated = self:FormatDurability(self.durability.minItem, false);
    PaperDollFrame_SetLabelAndText(statFrame, DURABILITY, minFormated, false);
    
    -- Set the tooltip
    if text1 then statFrame.tooltip = text1 end
    if text2 then statFrame.tooltip2 = text2 end
    
    -- Update the frame
    statFrame:Show()
end

-- Format a 0-1 to a colorized %
function CID:FormatDurability(value, colorize)
    if not value then return false end

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

-- Update the text of LDB
function CID:LDBText()
    if self.durability then
        local avgFormated = self:FormatDurability(self.durability.average)
        local minFormated = self:FormatDurability(self.durability.minItem)

        self.ldb.text = minFormated..' / '..avgFormated
    else
        self.ldb.text = '??'
    end
end

-- Show the LDB tooltip
function CID:LDBTooltip(tt)
    local text1, text2 = self:TooltipText()

    if text1 then tt:AddLine(text1) end
    if text2 then tt:AddLine(text2) end
end

-- return line 1 and 2 for tooltips
function CID:TooltipText()
    local text1, text2 = false
    local average, minItem, minSlot, slots = self:CalculateDurability();

    local avgFormatedC = self:FormatDurability(average);
    local minFormatedC = self:FormatDurability(minItem);
    
    text1 = format(gsub(DURABILITY_TEMPLATE, '%%d', '%%s'), minFormatedC, avgFormatedC)

    if average ~= 1 then
        text2 = format("%s: %s", self.iidName[minSlot], GetInventoryItemLink('player', minSlot))
    end
    
    return text1, text2
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