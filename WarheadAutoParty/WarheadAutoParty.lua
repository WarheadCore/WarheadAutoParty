--[[
    #
    # This file is part of the WarheadCore Project.
    #
]]--

local _G = _G 	--Rumors say that global _G is called by lookup in a super-global table. Have no idea whether it is true.
local _ 		--Sometimes blizzard exposes "_" variable as a global.
local addonName, ptable = ...
local TOCVersion = GetAddOnMetadata(addonName, "Version")
local SelfName = GetUnitName("player", false)
local GuildRoster = GuildRoster

WarheadAutoParty = LibStub("AceAddon-3.0"):NewAddon("WarheadAutoParty", "AceEvent-3.0", "AceConsole-3.0")

WarheadAutoParty.defaults =
{
    enabled = true,
    moduleWhisper = true,
    moduleGuild = false,
    moduleSay = false,
    wordsParty = { "+", "++", "+++", "пати", "gfnb" },
    version = TOCVersion,
    debug = true,
    makeRaid = false,
    autoAcceptPartyFromFriends = true,
    autoAcceptPartyFromGuild = true,
    addAssistViaWhisper = true,
    convertToRaidViaWhisper = true
}

WarheadAutoParty.OptionsPanel = nil
WarheadAutoParty.NeedRaid = 0
WarheadAutoParty.GroupMembers = {}

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
    if inGroup and not inRaid and membersCount == 5 then
        if not WarheadAutoPartyADB.makeRaid then
            return false
        end

        if WarheadAutoPartyADB.makeRaid then
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

    for index, value in ipairs(WarheadAutoPartyADB.wordsParty) do
        if value == message then
            return true
        end
    end

    return false
end

function WarheadAutoParty:IsAssistWords(message)
    for index, value in ipairs(WarheadAutoPartyADB.wordsAssist) do
        if value == message then
            return true
        end
    end

    return false
end

function WarheadAutoParty:IsMakeRaidWords(message)
    for index, value in ipairs(WarheadAutoPartyADB.wordsMakeRaid) do
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
    return SelfName == self:GetCleanPlayerName(playerName)
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

function WarheadAutoParty:InvitePlayer(playerName)
    if not self:CanInvite() then
        return
    end

    -- Just check self :D
    if self:IsPlayerSelf(playerName) then
        if WarheadAutoPartyADB.debug then
            print("|cFFFF0000[WH.Inv]:|r Вы не можете пригласить в пати самого себя")
        end

        return
    end

    local cleanPlayerName = self:GetCleanPlayerName(playerName)

    if UnitInParty(cleanPlayerName) then
        if WarheadAutoPartyADB.debug then
            print("|cFFFF0000[WH.Inv]:|r |cff14ECCF["..playerName.."]|r Уже в вашей пати")
        end

        SendChatMessage('WH: Ты уже в моей пати...', "WHISPER", nil, playerName)
        return
    end

    if WarheadAutoPartyADB.debug then
        print("|cFFFF0000[WH.Inv]:|r Приглашение игрока |cff14ECCF["..playerName.."]") ;
    end

    -- SendChatMessage('Я уловил твоё ключевое слово ['..message..'] Держи пати :)', "WHISPER", nil, playerName)
    InviteUnit(playerName)
end

function WarheadAutoParty:AddAssistForPlayer(playerName)
    local inRaid = IsInRaid()
    local isLeader = UnitIsGroupLeader('player')
    local cleanPlayerName = self:GetCleanPlayerName(playerName)

    -- Just check self :D
    if self:IsPlayerSelf(playerName) then
        if WarheadAutoPartyADB.debug then
            print("|cFFFF0000[WH.Inv]:|r Вы не можете выдать ассиста самому себе")
        end

        return
    end

    if not UnitInParty(cleanPlayerName) then
        if WarheadAutoPartyADB.debug then
            print("|cFFFF0000[WH.Inv]:|r Игрок |cff14ECCF["..playerName.."]|r не в вашей пати")
        end

        SendChatMessage('WH: Ты не в моей пати...', "WHISPER", nil, playerName)
        return
    end

    if not inRaid then
        SendChatMessage('Мы с тобой даже не в рейде...', "WHISPER", nil, playerName)
        return
    end

    if not isLeader then
        SendChatMessage('Я не лидер рейда...', "WHISPER", nil, playerName)
        return
    end

    if WarheadAutoPartyADB.debug then
        print("|cFFFF0000[WH.Inv]:|r Выдача ассиста игроку |cff14ECCF["..playerName.."]") ;
    end

    SendChatMessage('Я уловил твоё ключевое слово. Выдал тебе ассиста :)', "WHISPER", nil, playerName)
    PromoteToAssistant(cleanPlayerName)
end

function WarheadAutoParty:MakeRaidFromWhisper(playerName)
    local inRaid = IsInRaid()
    local isLeader = UnitIsGroupLeader('player')
    local cleanPlayerName = self:GetCleanPlayerName(playerName)

    if not UnitInParty(cleanPlayerName) then
        if WarheadAutoPartyADB.debug then
            print("|cFFFF0000[WH.Inv]:|r Игрок |cff14ECCF["..playerName.."]|r не в вашей пати")
        end

        SendChatMessage('WH: Ты не в моей пати...', "WHISPER", nil, playerName)
        return
    end

    if inRaid then
        SendChatMessage('Мы с тобой уже в рейде...', "WHISPER", nil, playerName)
        return
    end

    if not isLeader then
        SendChatMessage('Я не лидер рейда...', "WHISPER", nil, playerName)
        return
    end

    if WarheadAutoPartyADB.debug then
        print("|cFFFF0000[WH.Inv]:|r Конвертация группы в рейд...") ;
    end

    SendChatMessage('Я уловил твоё ключевое слово. Конвертнул группу в рейд :)', "WHISPER", nil, playerName)
    ConvertToRaid()
end

function WarheadAutoParty:InviteAllFromList()
    if WarheadAutoParty.GroupMembers == nil then
        return
    end

    for i = 1, #WarheadAutoParty.GroupMembers do
        InviteUnit(WarheadAutoParty.GroupMembers[i])
    end
end

function WarheadAutoParty:DisbandAndCollectGroup(membersCount)
    table.wipe(WarheadAutoParty.GroupMembers)

    -- Make members list
    for j = 1, membersCount do
		local name = GetRaidRosterInfo(j)

        if name ~= SelfName then
            table.insert(WarheadAutoParty.GroupMembers, name)
            UninviteUnit(name)
        end
	end
end

function WarheadAutoParty:SendWHMessageToChat(message, usingRW)
    if not IsInGroup() then
        print(message)
        return
    end

    local sendChannelType = "PARTY"

    if not IsInGroup(2) then
        if IsInRaid() then
            if usingRW then
                sendChannelType = "RAID_WARNING"
            else
                sendChannelType = "RAID"
            end
        end
    elseif IsInGroup(2) then
        sendChannelType = "INSTANCE_CHAT"
    end

    SendChatMessage(message, sendChannelType)
end

function WarheadAutoParty:ReInviteParty()
    local inInstance = IsInInstance()
    local inGroup = IsInGroup()
    local inRaid = IsInRaid()
    local isLeader = UnitIsGroupLeader('player')
    local membersCount = GetNumGroupMembers() or 0

    if not inGroup then
        print("|cFFFF0000[WH.Inv]:|r Нельзя пересобрать пати, когда вы не в ней")
        return
    end

    if not isLeader then
        print("|cFFFF0000[WH.Inv]:|r У вас нет прав на роспуск группы, чтобы начать пересбор пати")
        return
    end

    if inInstance then
        print("|cFFFF0000[WH.Inv]:|r Вы находитесь в инсте, нужно выйти из него")
        return
    end

    self:SendWHMessageToChat('WH: Начался процесс пересбора пати. Количество игроков: '..membersCount, true)

    local needConvertToRaid = false

    if not IsInGroup(2) and inRaid then
        needConvertToRaid = true
        self:SendWHMessageToChat('WH: Будет создан рейд', true)
    end

    self:DisbandAndCollectGroup(membersCount)
    self:InviteAllFromList()

    if needConvertToRaid then
        WarheadAutoParty.NeedRaid = 2
    end
end

function WarheadAutoParty:OnInitialize()
    self:RegisterChatCommand("wh", "ConsoleComand")
end

function WarheadAutoParty:SetEnabled(enabled)
    WarheadAutoPartyADB.enabled = not not enabled
end

function WarheadAutoParty:OnEnable()
    if (not WarheadAutoPartyADB) or (not WarheadAutoPartyADB.version or (WarheadAutoPartyADB.version < TOCVersion)) then
        WarheadAutoPartyADB = nil
        self:Print("-- Reset")
    end

    if not WarheadAutoPartyADB then
        _G.WarheadAutoPartyADB = CopyTable(self.defaults)
    end

    local DB = WarheadAutoPartyADB

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
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("CONFIRM_SUMMON")
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

    if #arg ~= 0 then
        print("|cFFFF0000[WH.Inv]:|r Выполнение команды:", arg)
    end

    if (#arg == 0) then
        self:ShowOptions()
    elseif arg == "on" then
        self:SetEnabled(true)
        self:Print("|cFFFF0000[WH.Inv]:|r Аддон включен")
    elseif arg == "off" then
        self:SetEnabled(false)
        self:Print("|cFFFF0000[WH.Inv]:|r Аддон выключен")
    elseif arg == "reinv" then
        self:ReInviteParty()
    end
end

function WarheadAutoParty:CHAT_MSG_WHISPER(...)
    if not WarheadAutoPartyADB.enabled then
        return
    end

    local arg1, message, playerName = ...

    -- Try add party
    if WarheadAutoPartyADB.moduleWhisper and self:IsInviteWords(message) then
        self:InvitePlayer(playerName)
        return
    end

    if WarheadAutoPartyADB.addAssistViaWhisper and message == "WH:Assist" then
        self:AddAssistForPlayer(playerName)
        return
    end

    if WarheadAutoPartyADB.convertToRaidViaWhisper and message == "WH:Raid" then
        self:MakeRaidFromWhisper(playerName)
        return
    end
end

function WarheadAutoParty:CHAT_MSG_GUILD(...)
	if not WarheadAutoPartyADB.enabled then
        return
    end

    local arg1, message, playerName = ...

    -- Try add party
    if WarheadAutoPartyADB.moduleGuild and self:IsInviteWords(message) then
        self:InvitePlayer(playerName)
    end
end

function WarheadAutoParty:CHAT_MSG_SAY(...)
	if not WarheadAutoPartyADB.enabled then
        return
    end

    local arg1, message, playerName = ...

    if WarheadAutoPartyADB.moduleSay and self:IsInviteWords(message) then
        self:InvitePlayer(playerName)
    end
end

function WarheadAutoParty:PARTY_INVITE_REQUEST(...)
    if not WarheadAutoPartyADB.enabled then
        return
    end

    local _, playerName = ...

    if IsInGroup() then
        return
    end

    local friendName, guildMemberName;
    local isAccepted = false;

    if GetNumFriends() > 0 and WarheadAutoPartyADB.autoAcceptPartyFromFriends then
        ShowFriends()

        for friendIndex = 1, GetNumFriends() do
            friendName = GetFriendInfo(friendIndex)
            if friendName and (friendName == playerName) then
                AcceptGroup()
                isAccepted = true
                print("|cFFFF0000[WH]:|r Игрок |cff14ECCF"..playerName.."|r из списка выших друзей, принимаем пати")
                break
            end
        end
    end

    if IsInGuild() and WarheadAutoPartyADB.autoAcceptPartyFromGuild and not isAccepted then
        GuildRoster()

        for guildIndex = 1, GetNumGuildMembers(true) do
            guildMemberName = GetGuildRosterInfo(guildIndex)
            if guildMemberName and (self:GetCleanPlayerName(guildMemberName) == playerName) then
                AcceptGroup()
                isAccepted = true
                print("|cFFFF0000[WH]:|r Игрок |cff14ECCF"..playerName.."|r из вашей гильдии, принимаем пати")
                break
            end
        end
    end

    if not isAccepted then
        return
    end

    AcceptGroup()
    StaticPopup_Hide("PARTY_INVITE")
end

function WarheadAutoParty:GROUP_ROSTER_UPDATE(...)
    if WarheadAutoParty.NeedRaid == 0 then
        return
    end

    local membersCount = GetNumGroupMembers() or 0
    if membersCount == 0 then
        WarheadAutoParty.NeedRaid = 1
        return
    end

    if not (WarheadAutoParty.NeedRaid == 1) or membersCount < 2 then
        return
    end

    WarheadAutoParty.NeedRaid = 0

    if not UnitIsGroupLeader('player') then
        return
    end

    ConvertToRaid()
end

function WarheadAutoParty:CONFIRM_SUMMON(...)
    self:SendWHMessageToChat(string.format("Вижу суммон от %s в %s", GetSummonConfirmSummoner(), GetSummonConfirmAreaName()), false)
end