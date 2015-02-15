--[[


]]

--[[ Setup the addon ]]
CID = {}
CID.addonName = "Character Info Durability" -- Addon Name
CID.addonFolder = "CharacterInfoDurability" -- Folder of the Addon
CID.addonNameAbr = "CID"                    -- Short abbreviation
--[[ end setup ]]


-- Additional addon setup
CID.lastUpdate = 0;
CID.durability = false
CID.version = '@project-version@'
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
    autorepair = false,
    autorepairType = nil,
    popup = false,
}

function CID:OnInitialize()
    self:Print('Character Info Durability Loaded... '..self.version..'-'..self.versionRev)

    -- Check saved variables
    if not CID_Global or type(CID_Global) ~= 'table' then CID_Global = CID_GlobalDefault end
    if not CID_Local or type(CID_Local) ~= 'table' then CID_Local = CID_LocalDefault end

    -- Add slash handler
    self:AddSlashHandler({'cid', 'cinfodura', 'charactertnfodurability'}, function(...) CID:SlashHandler(...) end)

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
    self:RegisterEvent("PLAYER_DEAD", function() CID:CalculateDurability() end)
    self:RegisterEvent("MERCHANT_SHOW", function() CID:RepairPopup() end)
    self:RegisterEvent("MERCHANT_CLOSED", function() CID:RepairPopupHide() end)

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
    local minFormated = self:FormatDurability(self.durability.minItem, self.durability.minItem < .35);
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
            color = "ff0026"; -- Red
        elseif value < .5 then
            color = "f6a01a"; -- Orange
        end

        return '|cFF'..color..formated..'%|r'
    else
        return formated..'%'
    end
end

-- Update the text of LDB
function CID:LDBText()
    if self.durability and self.durability.average and self.durability.minItem then
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

    local avgFormated = self:FormatDurability(average);
    local minFormated = self:FormatDurability(minItem);
    
    if minFormated and avgFormated then
        text1 = format(gsub(DURABILITY_TEMPLATE, '%%d', '%%s'), minFormated, avgFormated)
    end

    if average ~= 1 and minSlot then
        local itemLink = GetInventoryItemLink('player', minSlot)
        text2 = format("%s: %s", self.iidName[minSlot], itemLink)
    end
    
    return text1, text2
end

function CID:RepairPopup()
    if not CanMerchantRepair() then return false end

    if not StaticPopupDialogs["CID_REPAIR"] then
        StaticPopupDialogs["CID_REPAIR"] = {
            text = REPAIR_COST.." %s",
            button1 = USE_PERSONAL_FUNDS,
            button2 = CANCEL,
            OnAccept = function() -- Personal Gold
                    CID:Repair()
                end,
            OnAlt = function() -- Guild Bank
                    CID:Repair(1)
                end,
            OnCancel = function() -- Cancel
                end,
            whileDead = false,
            hideOnEscape = true,
        }
    end

    if CanGuildBankRepair() then
        StaticPopupDialogs["CID_REPAIR"].button3 = GUILDCONTROL_OPTION15
    else
        StaticPopupDialogs["CID_REPAIR"].button3 = nil
    end

    local repairAllCost, canRepair = GetRepairAllCost()

    -- Only show the popup if we are over 0 to repair
    if repairAllCost > 0 then
        if self:GetAutoRepair() then
            self:Repair(self:GetAutoRepairType())
        elseif self:GetPopup() then
            StaticPopup_Show("CID_REPAIR", GetCoinTextureString(repairAllCost))
        end
    end
end

function CID:RepairPopupHide()
    StaticPopup_Hide("CID_REPAIR")
end

function CID:Repair(useGuildMoney)

    local repairAllCost, canRepair = GetRepairAllCost()
    self:Print(REPAIR_COST, GetCoinTextureString(repairAllCost))

    -- Do the repair
    RepairAllItems(useGuildMoney)
    PlaySound("ITEM_REPAIR")
end

-- slash handler
function CID:SlashHandler(msg)
    msg = strlower(msg) -- we don't care about case
    local command, rest = msg:match("^(%S*)%s*(.-)$")

    if command == 'color' or commane == 'c' then
        if rest == '1' or rest == 'on' or rest == 'true' then
            self:SetColor(true)
        elseif rest == '0' or rest == 'off' or rest == 'false' then
            self:SetColor(false)
        else
            self:ToggleColor()
        end

        self:LDBText()
        self:Print(COLORIZE, self:GetColor())
    

    elseif command == 'popup' or command == 'prompt' then
        if rest == '1' or rest == 'on' or rest == 'true' then
            self:SetPopup(true)
        elseif rest == '0' or rest == 'off' or rest == 'false' then
            self:SetPopup(false)
        else
            self:TogglePopup()
        end

        self:Print(REPAIR_ITEMS..':', self:GetAutoRepair())

    elseif command == 'autorepair' or command == 'auto' then
        if rest == '1' or rest == 'on' or rest == 'true' then
            self:SetAutoRepair(true)
        elseif rest == '0' or rest == 'off' or rest == 'false' then
            self:SetAutoRepair(false)
        else
            self:ToggleAutoRepair()
        end

        self:Print(REPAIR_ITEMS..':', self:GetAutoRepair())


    elseif command == 'useguild' or command == 'guild'  or command == 'guildbank' then
        if rest == '1' or rest == 'on' or rest == 'true' then
            self:SetAutoRepairType(1)
        elseif rest == '0' or rest == 'off' or rest == 'false' then
            self:SetAutoRepairType(nil)
        else
            self:ToggleAutoRepairType()
        end

        self:Print(GUILDCONTROL_OPTION15..':', self:GetAutoRepairType() or false)


    elseif command == 'debug' then
        self:ToggleDebug()
        self:Print('Debug', self:GetDebug())
    

    else
        self:Print('/cid color [on|off]', COLORIZE, self:GetColor())
        self:Print('/cid autorepair [on|off]', REPAIR_ITEMS..':', self:GetAutoRepair())
        self:Print('/cid useguild [on|off]', GUILDCONTROL_OPTION15..':', self:GetAutoRepairType() or false)

    end
end





--[[ Setters / Getters / Togglers ]]
function CID:SetDebug(v) CID_Local.debug = v end
function CID:GetDebug() return CID_Local.debug end
function CID:ToggleDebug() self:SetDebug(not self:GetDebug()) end

function CID:SetColor(v) CID_Global.color = v end
function CID:GetColor() return CID_Global.color end
function CID:ToggleColor() self:SetColor(not self:GetColor()) end

function CID:SetAutoRepair(v) CID_Local.autorepair = v end
function CID:GetAutoRepair() return CID_Local.autorepair end
function CID:ToggleAutoRepair() self:SetAutoRepair(not self:GetAutoRepair()) end

function CID:SetPopup(v) CID_Local.popup = v end
function CID:GetPopup() return CID_Local.popup end
function CID:TogglePopup() self:SetPopup(not self:GetPopup()) end

function CID:SetAutoRepairType(v) CID_Local.autorepairType = v end
function CID:GetAutoRepairType() return CID_Local.autorepairType end
function CID:ToggleAutoRepairType() 
    if self:GetAutoRepairType() == 1 then 
        self:SetAutoRepairType(nil) 
    else 
        self:SetAutoRepairType(1)
    end
end


--[[ Simplifying methods ]]
function CID:AddSlashHandler(tbl, handler)
    if type(tbl) ~= 'table' then return false end

    for i,slash in pairs(tbl) do
        if strsub(slash,0,1) ~= '/' then slash = '/'..slash end
        _G['SLASH_'..self.addonFolder..i] = slash
    end

    SlashCmdList[self.addonFolder] = handler
end

--[[ Ace3 Like methods and supporters ]]
CID.events = {}
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
CID.frame = CreateFrame("Frame", "CIDFrame")
CID.frame:SetScript("OnEvent", OnEvent);
CID:RegisterEvent("PLAYER_LOGIN", function() CID:OnInitialize(); end);