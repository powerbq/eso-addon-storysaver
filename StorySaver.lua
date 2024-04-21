StorySaver = {}

StorySaver.name = 'StorySaver'

StorySaver.initialized = false

function StorySaver:GetCache(eventType, name)
    if self.accountSavedVariables.cache[eventType][name] == nil then
        self.accountSavedVariables.cache[eventType][name] = {}
    end

    return self.accountSavedVariables.cache[eventType][name]
end

function StorySaver:CleanupCacheForName(eventType, name)
    local recordsDeleted = 0

    if eventType == 'items' then
        return recordsDeleted
    end

    for hash, _ in pairs(self.accountSavedVariables.cache[eventType][name]) do
        local exists = false

        local events = self.events[eventType][name]
        if events == nil then
            events = {}
        end
        for _, eventData in pairs(events) do
            if hash == eventData.hash then
                exists = true
                break
            end

            if eventType == 'dialogues' then
                for selectedOptionHash, _ in pairs(eventData.selectedOptionHashes) do
                    if hash == selectedOptionHash then
                        exists = true
                        break
                    end
                end

                if exists then
                    break
                end

                for optionHash, _ in pairs(eventData.optionHashes) do
                    if hash == optionHash then
                        exists = true
                        break
                    end
                end
            end
        end

        if not exists then
            self.accountSavedVariables.cache[eventType][name][hash] = nil

            recordsDeleted = recordsDeleted + 1
        end
    end

    for _, _ in pairs(StorySaver.accountSavedVariables.cache[eventType][name]) do
        return recordsDeleted
    end

    StorySaver.accountSavedVariables.cache[eventType][name] = nil

    return recordsDeleted
end

function StorySaver:CleanupCache()
    local recordsDeleted = 0

    local eventTypes = { 'dialogues', 'subtitles', 'books' }
    for _, eventType in pairs(eventTypes) do
        for name, _ in pairs(self.accountSavedVariables.cache[eventType]) do
            recordsDeleted = recordsDeleted + self:CleanupCacheForName(eventType, name)
        end
    end

    d(self.name .. ': ' .. string.format(GetString(STORY_SAVER_CLEANUP_CACHE), recordsDeleted))
end

function StorySaver:CleanupEventsForName(eventType, name)
    for _, _ in pairs(self.events[eventType][name]) do
        return
    end

    self.events[eventType][name] = nil
end

function StorySaver:CleanupEvents()
    for eventType, names in pairs(self.events) do
        for name, _ in pairs(names) do
            self:CleanupEventsForName(eventType, name)
        end
    end
end

function StorySaver:OptimizeStorage()
    StorySaver:CleanupEvents()
    StorySaver:CleanupCache()
end

function StorySaver:DeleteEvent(eventType, name, eventId)
    self.events[eventType][name][eventId] = nil
end

function StorySaver:ParseEventId(eventId)
    local timeStamp, eventNumber

    for part in eventId:gmatch('([^-]+)') do
        if timeStamp == nil then
            timeStamp = part
        elseif eventNumber == nil then
            eventNumber = tonumber(part)
        end
    end

    return timeStamp, eventNumber
end

function StorySaver:DeleteOldData()
    local eventsDeleted = 0

    local currentTimeStamp = GetTimeStamp()

    for eventType, names in pairs(self.events) do
        local days
        if eventType == 'dialogues' then
            days = StorySaverSettings.values.deleteDialoguesOlderThan
        elseif eventType == 'subtitles' then
            days = StorySaverSettings.values.deleteSubtitlesOlderThan
        elseif eventType == 'books' then
            days = StorySaverSettings.values.deleteBooksOlderThan
        elseif eventType == 'items' then
            days = StorySaverSettings.values.deleteItemsOlderThan
        end

        if days > 0 then
            local seconds = days * 24 * 60 * 60

            for name, eventIds in pairs(names) do
                for eventId, eventData in pairs(eventIds) do
                    local timeStamp, _ = self:ParseEventId(eventId)
                    timeStamp = tonumber(timeStamp)

                    if eventType == 'dialogues' and StorySaverSettings.values.useOptionsDates then
                        for _, data in pairs(eventData.selectedOptionHashes) do
                            if (data.timeStamp ~= tonumber(data.timeStamp)) then
                                data.timeStamp = tonumber(data.timeStamp)
                            end

                            if data.timeStamp > timeStamp then
                                timeStamp = data.timeStamp
                            end
                        end

                        for _, data in pairs(eventData.optionHashes) do
                            if (data.timeStamp ~= tonumber(data.timeStamp)) then
                                data.timeStamp = tonumber(data.timeStamp)
                            end

                            if data.timeStamp > timeStamp then
                                timeStamp = data.timeStamp
                            end
                        end
                    end

                    if currentTimeStamp - timeStamp > seconds then
                        self:DeleteEvent(eventType, name, eventId)

                        eventsDeleted = eventsDeleted + 1
                    end
                end
            end
        end
    end

    d(self.name .. ': ' .. string.format(GetString(STORY_SAVER_CLEANUP_EVENTS), eventsDeleted))
end

function StorySaver:NewEvent(eventType, name, hash)
    self.eventNumber = self.eventNumber + 1

    local zoneIndex = GetUnitZoneIndex('player')
    local x, y = LibGPS3:LocalToGlobal(GetMapPlayerPosition('player'))

    local eventId = GetTimeStamp() .. '-' .. self.eventNumber
    local eventData = {
        hash = hash,
        zoneIndex = zoneIndex,
        x = x,
        y = y,
    }

    if eventType == 'dialogues' then
        eventData.optionHashes = {}
        eventData.selectedOptionHashes = {}
    end

    if self.events[eventType][name] == nil then
        self.events[eventType][name] = {}
    end

    self.events[eventType][name][eventId] = eventData

    return eventData
end

function StorySaver:GetEventWithHash(eventType, name, hash)
    if self.events[eventType][name] == nil then
        return nil
    end

    for _, eventData in pairs(self.events[eventType][name]) do
        if eventData.hash == hash then
            return eventData
        end
    end

    return nil
end

function StorySaver:ProcessPopulateChatterOption(optionText, optionType)
    if optionText == GetString(SI_GOODBYE) then
        return
    end

    self.lastOptionTypes[optionType] = true

    table.insert(self.lastOptions, {
        body = optionText,
        type = optionType
    })
end

function StorySaver.KeyboardPopulateChatterOption(obj, arg1, arg2, optionText, optionType, ...)
    StorySaver:ProcessPopulateChatterOption(optionText, optionType)

    StorySaver.coreKeyboardPopulateChatterOption(obj, arg1, arg2, optionText, optionType, ...)
end

function StorySaver.GamepadPopulateChatterOption(obj, arg1, arg2, optionText, optionType, ...)
    StorySaver:ProcessPopulateChatterOption(optionText, optionType)

    StorySaver.coreGamepadPopulateChatterOption(obj, arg1, arg2, optionText, optionType, ...)
end

function StorySaver:ProcessHandleChatterOptionClicked(body)
    local eventType = 'dialogues'
    local name = GetUnitName('interact')
    local hash = HashString(body) .. '-' .. #body

    local accountCache = self:GetCache(eventType, name)
    accountCache[hash] = body

    self.lastSelectedOptionHash = hash
end

function StorySaver.KeyboardHandleChatterOptionClicked(obj, area)
    StorySaver:ProcessHandleChatterOptionClicked(area.optionText)

    StorySaver.coreKeyboardHandleChatterOptionClicked(obj, area)
end

function StorySaver.GamepadHandleChatterOptionClicked(obj, selectedData)
    StorySaver:ProcessHandleChatterOptionClicked(selectedData.optionText)

    StorySaver.coreGamepadHandleChatterOptionClicked(obj, selectedData)
end

function StorySaver:ProcessOnShowBook(name, body, medium, showTitle, id)
    local eventType = 'books'
    local hash = HashString(body) .. '-' .. #body

    if self:GetEventWithHash(eventType, name, hash) ~= nil then
        return
    end

    local i = 1
    local parts = {}
    local part = ''
    local oldPart = ''

    for word in body:gmatch('([^ ]+)') do
        oldPart = part
        part = part .. word .. ' '

        if #part > 500 then
            parts[i] = oldPart
            part = word .. ' '
            i = i + 1
        end
    end

    parts[i] = part:sub(1, #part - 1)

    local accountCache = self:GetCache(eventType, name)
    accountCache[hash] = parts

    local eventData = self:NewEvent(eventType, name, hash)
    eventData.medium = medium
    eventData.showTitle = showTitle
    eventData.id = id

    self.interface:TriggerRefreshData()
end

function StorySaver.OnShowBook(_, name, body, medium, showTitle, id)
    StorySaver:ProcessOnShowBook(name, body, medium, showTitle, id)
end

function StorySaver:ProcessAddQuestItem(questItem)
    local eventType = 'items'
    local name = questItem.name

    if self:GetEventWithHash(eventType, name, questItem.questItemId) ~= nil then
        return
    end

    self:NewEvent(eventType, name, questItem.questItemId)

    self.interface:TriggerRefreshData()
end

function StorySaver.AddQuestItem(obj, questItem, ...)
    StorySaver:ProcessAddQuestItem(questItem)

    StorySaver.coreAddQuestItem(obj, questItem, ...)
end

function StorySaver:ResetLastData()
    self.lastOptions = {}
    self.lastOptionTypes = {}
    self.lastSelectedOptionHash = ''
end

function StorySaver:ProcessDialogue()
    local eventType = 'dialogues'
    local name = GetUnitName('interact')
    local gender = GetUnitGender('interact')

    local area
    if not IsInGamepadPreferredMode() then
        area = ZO_InteractWindowTargetAreaBodyText
    else
        area = ZO_InteractWindow_GamepadContainerText
    end

    local body = area:GetText()
    if #body == 0 then
        self:ResetLastData()

        return
    end
    local hash = HashString(body) .. '-' .. #body

    if self.lastOptionTypes[CHATTER_START_TRADINGHOUSE] and not self.lastOptionTypes[CHATTER_START_BANK] then
        self:ResetLastData()

        return
    end

    local accountCache = self:GetCache(eventType, name)
    accountCache[hash] = body

    local eventData = self:GetEventWithHash(eventType, name, hash)
    if eventData == nil then
        eventData = self:NewEvent(eventType, name, hash)
    end

    eventData.gender = gender

    if eventData.selectedOptionHashes[self.lastSelectedOptionHash] == nil then
        eventData.selectedOptionHashes[self.lastSelectedOptionHash] = {}
        eventData.selectedOptionHashes[self.lastSelectedOptionHash]['timeStamp'] = GetTimeStamp()
    end

    for _, option in pairs(self.lastOptions) do
        hash = HashString(option.body) .. '-' .. #option.body

        accountCache = self:GetCache(eventType, name)
        accountCache[hash] = option.body

        if eventData.optionHashes[hash] == nil then
            eventData.optionHashes[hash] = {}
            eventData.optionHashes[hash]['type'] = option.type
            eventData.optionHashes[hash]['timeStamp'] = GetTimeStamp()
        end
    end

    self:ResetLastData()

    self.interface:TriggerRefreshData()
end

function StorySaver.OnDialogue(...)
    StorySaver:ProcessDialogue()
end

function StorySaver:ProcessDialogueEnd()
    self:ResetLastData()
end

function StorySaver.OnDialogueEnd(...)
    StorySaver:ProcessDialogueEnd()
end

function StorySaver:ProcessSubtitle(msgType, from, body)
    if msgType ~= CHAT_CHANNEL_MONSTER_EMOTE and msgType ~= CHAT_CHANNEL_MONSTER_SAY and msgType ~= CHAT_CHANNEL_MONSTER_WHISPER and msgType ~= CHAT_CHANNEL_MONSTER_YELL then
        return
    end

    local eventType = 'subtitles'
    local name = zo_strformat('<<C:1>>', from)
    local hash = HashString(body) .. '-' .. #body

    if self:GetEventWithHash(eventType, name, hash) ~= nil then
        return
    end

    local accountCache = self:GetCache(eventType, name)
    accountCache[hash] = body

    self:NewEvent(eventType, name, hash)

    self.interface:TriggerRefreshData()
end

function StorySaver.OnSubtitle(_, msgType, from, body)
    StorySaver:ProcessSubtitle(msgType, from, body)
end

function StorySaver:GetAccountSavedVariablesDefaults(worldName, characterName)
    local defaults = {
        settingsAccountWide = true,
        settings = StorySaverSettings.defaults,
        cache = {
            dialogues = {},
            subtitles = {},
            books = {},
        },
        events = {}
    }

    defaults.events[worldName] = {}
    defaults.events[worldName][characterName] = {}

    local eventTypes = { 'dialogues', 'subtitles', 'books', 'items' }
    for _, eventType in pairs(eventTypes) do
        defaults.events[worldName][characterName][eventType] = {}
    end

    return defaults
end

function StorySaver:GetCharacterSavedVariablesDefaults()
    local defaults = {}

    return defaults
end

function StorySaver:Initialize()
    if self.initialized then
        return
    end

    self:ResetLastData()

    self.eventNumber = 0

    local worldName, characterName = GetWorldName(), GetUnitName('player')

    self.accountSavedVariables = ZO_SavedVars:NewAccountWide(self.name .. 'SavedVariables', 1, nil, self:GetAccountSavedVariablesDefaults(worldName, characterName), nil, nil)
    self.characterSavedVariables = ZO_SavedVars:New(self.name .. 'SavedVariables', 1, nil, self:GetCharacterSavedVariablesDefaults(), worldName, nil)

    self.events = self.accountSavedVariables.events[worldName][characterName]

    self.coreKeyboardPopulateChatterOption = ZO_Interaction.PopulateChatterOption
    self.coreGamepadPopulateChatterOption = ZO_GamepadInteraction.PopulateChatterOption
    self.coreKeyboardHandleChatterOptionClicked = ZO_Interaction.HandleChatterOptionClicked
    self.coreGamepadHandleChatterOptionClicked = ZO_GamepadInteraction.HandleChatterOptionClicked
    self.coreAddQuestItem = ZO_InventoryManager.AddQuestItem

    ZO_Interaction.PopulateChatterOption = self.KeyboardPopulateChatterOption
    ZO_GamepadInteraction.PopulateChatterOption = self.GamepadPopulateChatterOption
    ZO_Interaction.HandleChatterOptionClicked = self.KeyboardHandleChatterOptionClicked
    ZO_GamepadInteraction.HandleChatterOptionClicked = self.GamepadHandleChatterOptionClicked
    ZO_InventoryManager.AddQuestItem = self.AddQuestItem

    StorySaverOldData:UpdateSchema()

    StorySaverSettings:SetupPanel()

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CHATTER_BEGIN, self.OnDialogue)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CONVERSATION_UPDATED, self.OnDialogue)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_OFFERED, self.OnDialogue)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_COMPLETE_DIALOG, self.OnDialogue)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CHATTER_END, self.OnDialogueEnd)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_COMPLETE, self.OnDialogueEnd)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CHAT_MESSAGE_CHANNEL, self.OnSubtitle)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_SHOW_BOOK, self.OnShowBook)

    if StorySaverSettings.values.deleteOn == 'load' then
        self:DeleteOldData()
    end

    if StorySaverSettings.values.optimizeOn == 'load' then
        self:OptimizeStorage()
    end

    self.interface = ZO_SortFilterList.New(StorySaverInterface, StorySaverEventListFrame)
    self.interface:InitializeInterface()

    self.initialized = true
end

function StorySaver.OnAddOnLoaded(_, addOnName)
    if addOnName ~= StorySaver.name then
        return
    end

    StorySaver:Initialize()
end

EVENT_MANAGER:RegisterForEvent(StorySaver.name, EVENT_ADD_ON_LOADED, StorySaver.OnAddOnLoaded)
