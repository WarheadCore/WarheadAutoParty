--[[
Feel free to use this source code for any purpose ( except developing nuclear weapon! :)
Please keep original author statement.
@author Alex Shubert (alex.shubert@gmail.com)
]]--
local _G = _G 	--Rumors say that global _G is called by lookup in a super-global table. Have no idea whether it is true.
local _ 		--Sometimes blizzard exposes "_" variable as a global.
local addonName, ptable = ...
local TOCVersion = GetAddOnMetadata(addonName, "Version")

WarheadAutoParty = LibStub("AceAddon-3.0"):NewAddon("WarheadAutoParty", "AceEvent-3.0", "AceConsole-3.0")

WarheadAutoParty.defaults =
{
    enabled = true,
    moduleWhisper = true,
    moduleGuild = true,
    moduleSay = false,
    words = { "+", "++", "+++", "пати" },
    version = TOCVersion,
    debug = true,
    makeRaid = false,
    acceptPartyGuild = true
}

WarheadAutoParty.OptionsPanel = nil

function WarheadAutoParty:CanInvite()
    local inGroup = IsInGroup()
    local inRaid = IsInRaid()
    local isLeader = UnitIsGroupLeader('player')
    local isAssist = UnitIsGroupAssistant("player")
    local membersCount = GetNumGroupMembers()

    -- Always can if no any group
    if not inGroup then
        return true
    end

    -- Can convert to raid
    if inGroup and membersCount == 5 then
        if not WarheadAutoPartyCharacterDB.makeRaid then
            return false
        end

        if WarheadAutoPartyCharacterDB.makeRaid then
            ConvertToRaid()
            return true
        end
    end

    -- Group leader
    if inGroup and isLeader then
        return true
    end

    -- Raid leader or raid assist
    if inRaid and (isLeader or isAssist) then
        return true
    end

    return false
end

function WarheadAutoParty:IsInviteWords(message)
    message = string.lower(message)

    for index, value in ipairs(WarheadAutoPartyCharacterDB.words) do
        if value == message then
            return true
        end
    end

    return false
end

function WarheadAutoParty:GetCleanPlayerName(playerName)
    if (string.find(playerName, "-") == nil) then
        return playerName
    end

    local name = string.match(playerName, "^.-%-")
    return name:sub(0, strlen(name) - 1)
end

function WarheadAutoParty:IsPlayerSelf(playerName)
    return GetUnitName("player", false) == self:GetCleanPlayerName(playerName)
end

function WarheadAutoParty:IsPlayerInSameGuild(playerName)
    local _, numOnlineMembers = GetNumGuildMembers()

    for i = 1, numOnlineMembers do
        local guildPlayerName = GetGuildRosterInfo(i)

        if (guildPlayerName:find(playerName)) then
            return true
        end
    end

    return false
end

function WarheadAutoParty:InvitePlayer(playerName, message)
    -- Check message
    if not self:IsInviteWords(message) then
        return
    end

    if not self:CanInvite() then
        return
    end

    -- Just check self :D
    if self:IsPlayerSelf(playerName) then
        if WarheadAutoPartyCharacterDB.debug then
            print("|cFFFF0000[WH.Inv]:|r Вы не можете пригласить в пати самого себя")
        end

        return
    end

    local cleanPlayerName = self:GetCleanPlayerName(playerName)

    if UnitInParty(cleanPlayerName) then
        if WarheadAutoPartyCharacterDB.debug then
            print("|cFFFF0000[WH.Inv]:|r |cff14ECCF["..playerName.."]|r Уже в вашей пати")
        end

        SendChatMessage('WH: Ты уже в моей пати...', "WHISPER", nil, playerName)
        return
    end

    if WarheadAutoPartyCharacterDB.debug then
        print("|cFFFF0000[WH.Inv]:|r Приглашение игрока |cff14ECCF["..playerName.."]") ;
    end

    -- SendChatMessage('Я уловил твоё ключевое слово ['..message..'] Держи пати :)', "WHISPER", nil, playerName)
    InviteUnit(playerName)
end

function WarheadAutoParty:OnInitialize()
    self:RegisterChatCommand("wh", "ConsoleComand")
end

function WarheadAutoParty:SetEnabled(enabled)
    WarheadAutoPartyCharacterDB.enabled = not not enabled
end

function WarheadAutoParty:OnEnable()
    if (not WarheadAutoPartyCharacterDB) or (not WarheadAutoPartyCharacterDB.version or (WarheadAutoPartyCharacterDB.version < TOCVersion)) then
        WarheadAutoPartyCharacterDB = nil
        self:Print("-- Reset")
    end

    if not WarheadAutoPartyCharacterDB then
        _G.WarheadAutoPartyCharacterDB = CopyTable(self.defaults)
    end

    local DB = WarheadAutoPartyCharacterDB

    self:SetEnabled(DB.enabled)
    self:RegisterEvents()
end

function WarheadAutoParty:OnDisable()
  self:UnregisterAllEvents()
end

function WarheadAutoParty:RegisterEvents()
    self:RegisterEvent("CHAT_MSG_WHISPER")
    self:RegisterEvent("CHAT_MSG_GUILD")
    self:RegisterEvent("CHAT_MSG_SAY")
    self:RegisterEvent("PARTY_INVITE_REQUEST")
end

function WarheadAutoParty:ShowOptions()
    -- too much things became tainted if called in combat.
    if InCombatLockdown() then return end
    if (InterfaceOptionsFrame:IsVisible() and InterfaceOptionsFrameAddOns.selection) then
        if (InterfaceOptionsFrameAddOns.selection:GetName() == WarheadAutoParty.OptionsPanel:GetName()) then
            InterfaceOptionsFrameOkay:Click()
        end
    else
        -- http://wowpedia.org/Patch_5.3.0/API_changes double call is a workaround
        InterfaceOptionsFrame_OpenToCategory(WarheadAutoParty.OptionsPanel)
        InterfaceOptionsFrame_OpenToCategory(WarheadAutoParty.OptionsPanel)
    end
end

function WarheadAutoParty:ConsoleComand(arg)
    arg = strlower(arg)
    if (#arg == 0) then
        self:ShowOptions()
    elseif arg == "on" then
        self:SetEnabled(true)
        self:Print("|cFFFF0000[WH Автоинвайт]:|r Аддон включен")
    elseif arg == "off"  then
        self:SetEnabled(false)
        self:Print("|cFFFF0000[WH Автоинвайт]:|r Аддон выключен")
    end
end

function WarheadAutoParty:CHAT_MSG_WHISPER(...)
    if not WarheadAutoPartyCharacterDB.enabled or not WarheadAutoPartyCharacterDB.moduleWhisper then
        return
    end

    local arg1, message, playerName = ...
    self:InvitePlayer(playerName, message)
end

function WarheadAutoParty:CHAT_MSG_GUILD(...)
	if not WarheadAutoPartyCharacterDB.enabled or not WarheadAutoPartyCharacterDB.moduleGuild then
        return
    end

    local arg1, message, playerName = ...
    self:InvitePlayer(playerName, message)
end

function WarheadAutoParty:CHAT_MSG_SAY(...)
	if not WarheadAutoPartyCharacterDB.enabled or not WarheadAutoPartyCharacterDB.moduleSay then
        return
    end

    local arg1, message, playerName = ...
    self:InvitePlayer(playerName, message)
end

function WarheadAutoParty:PARTY_INVITE_REQUEST(...)
    if not WarheadAutoPartyCharacterDB.enabled or not WarheadAutoPartyCharacterDB.acceptPartyGuild then
        return
    end

    local arg1, playerName = ...

    if not IsInGuild() then
        return
    end

    if not self:IsPlayerInSameGuild(playerName) then
        return
    end

    print("|cFFFF0000[WH]:|r Игрок |cff14ECCF"..playerName.."|r из вашей гильдии, принимаем пати")
    AcceptGroup()
    StaticPopup_Hide("PARTY_INVITE")
end