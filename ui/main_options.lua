local addonName, ptable = ...
local O = addonName .. "OptionsPanel"
WarheadAutoParty.OptionsPanel = CreateFrame("Frame", O)
WarheadAutoParty.OptionsPanel.name = addonName
local OptionsPanel = WarheadAutoParty.OptionsPanel

-- switch flag. 'false' signals that reset must be made. 'true' allows redraw the screen keeping values
local MakeACopy = true

-- Title
local title = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetText(addonName .." ".. WarheadAutoParty.defaults.version)

-- Description
local notes = GetAddOnMetadata(addonName, "Notes")
local subText = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subText:SetText(notes)

-- Reset button
local ResetButton = CreateFrame("Button", nil, OptionsPanel, "OptionsButtonTemplate")
ResetButton:SetText("Сброс")
ResetButton:SetScript("OnClick", function()
	ptable.TempConfig = CopyTable(WarheadAutoParty.defaults)
	MakeACopy = false;
	WarheadAutoParty.OptionsPanel.refresh();
end)

local function newCheckbox(name, caption, config)
    local cb = CreateFrame("CheckButton", "$parent"..name, OptionsPanel, "OptionsCheckButtonTemplate")
    _G[cb:GetName().."Text"]:SetText(caption and caption or name)
    cb:SetScript("OnClick", function(self)
		ptable.TempConfig[config] = self:GetChecked()
    end)
    return cb
end

-- 'Enable' CheckBox
local Enable = newCheckbox("enabled", "Включить авто приём в пати", "enabled")
local EnableWhisper = newCheckbox("moduleWhisper", "Шёпот", "moduleWhisper")
local EnableGuild = newCheckbox("moduleGuild", "Гильдия", "moduleGuild")
local EnableSay = newCheckbox("moduleSay", "Сказать", "moduleSay")
local Debug = newCheckbox("Debug", "Дебаг", "debug")

-- Control placement
title:SetPoint("TOPLEFT", 16, -16)
subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
ResetButton:SetPoint("TOPRIGHT", OptionsPanel, "TOPRIGHT", -10, -10)

-- Options
Enable:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -14)

-- Modules
local modules = OptionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
modules:SetText("Модули")
modules:SetPoint("TOPLEFT", Enable, "BOTTOMLEFT", 0, -10)

EnableWhisper:SetPoint("TOPLEFT", modules, "BOTTOMLEFT", 0, -10)
EnableGuild:SetPoint("TOPLEFT", EnableWhisper, "BOTTOMLEFT", 0, 0)
EnableSay:SetPoint("TOPLEFT", EnableGuild, "BOTTOMLEFT", 0, 0)
Debug:SetPoint("TOPLEFT", ResetButton, "BOTTOMLEFT", 0, -10)

OptionsPanel.refresh = function()
	if (MakeACopy) then
		ptable.TempConfig = CopyTable(WarheadAutoPartyCharacterDB)
	end

	Enable:SetChecked(ptable.TempConfig.enabled)
	Debug:SetChecked(ptable.TempConfig.debug)
	EnableWhisper:SetChecked(ptable.TempConfig.moduleWhisper)
	EnableGuild:SetChecked(ptable.TempConfig.moduleGuild)
	EnableSay:SetChecked(ptable.TempConfig.moduleSay)

	MakeACopy = true
end

OptionsPanel.default = function()
	ptable.TempConfig = CopyTable(WarheadAutoParty.defaults)
end

OptionsPanel.okay = function()
	WarheadAutoPartyCharacterDB = CopyTable(ptable.TempConfig)
	WarheadAutoParty:SetEnabled(WarheadAutoPartyCharacterDB.enabled)
end

InterfaceOptions_AddCategory(OptionsPanel)
