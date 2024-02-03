StorySaver = {}

StorySaver.name = 'StorySaver'

StorySaver.coreHandleChatterOptionClicked = nil
StorySaver.coreSetupBook = nil
StorySaver.coreAddQuestItem = nil
StorySaver.interface = nil

StorySaver.currentWorldName = GetWorldName()
StorySaver.currentCharacterName = GetUnitName('player')

StorySaver.accountSavedVariablesDefaults = {}
StorySaver.accountSavedVariablesDefaults['cache'] = {}
StorySaver.accountSavedVariablesDefaults['cache']['dialogues'] = {}
StorySaver.accountSavedVariablesDefaults['cache']['subtitles'] = {}
StorySaver.accountSavedVariablesDefaults['cache']['books'] = {}
StorySaver.accountSavedVariablesDefaults['events'] = {}

StorySaver.accountSavedVariablesDefaults['events'][StorySaver.currentWorldName] = {}
StorySaver.accountSavedVariablesDefaults['events'][StorySaver.currentWorldName][StorySaver.currentCharacterName] = {}
StorySaver.accountSavedVariablesDefaults['events'][StorySaver.currentWorldName][StorySaver.currentCharacterName]['dialogues'] = {}
StorySaver.accountSavedVariablesDefaults['events'][StorySaver.currentWorldName][StorySaver.currentCharacterName]['subtitles'] = {}
StorySaver.accountSavedVariablesDefaults['events'][StorySaver.currentWorldName][StorySaver.currentCharacterName]['books'] = {}
StorySaver.accountSavedVariablesDefaults['events'][StorySaver.currentWorldName][StorySaver.currentCharacterName]['items'] = {}

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

    d(self.name .. ': ' .. string.format(GetString(STORY_SAVER_RECORDS_DELETED_FROM_CACHE), recordsDeleted))
end

function StorySaver:CleanupEventsForName(eventType, name)
    for _, _ in pairs(self.events[eventType][name]) do
        return
    end

    self.events[eventType][name] = nil
end

function StorySaver:CleanupEvents()
    for eventType, events in pairs(self.events) do
        for name, _ in pairs(events) do
            self:CleanupEventsForName(eventType, name)
        end
    end
end

function StorySaver:RemoveEvent(eventType, name, eventId)
    self.events[eventType][name][eventId] = nil
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

function StorySaver.GetOptionTypes()
    local optionTypes = {}

    for i = 1, GetChatterOptionCount() do
        local optionType
        _, optionType = GetChatterOption(i)

        optionTypes[optionType] = true
    end

    return optionTypes
end

function StorySaver.OnDialogue(...)
    local eventType = 'dialogues'
    local name = GetUnitName('interact')

    --local body, numOptions, atGreeting = GetChatterData()
    local area = ZO_InteractWindowTargetAreaBodyText
    local body = area:GetText()
    if #body == 0 then
        return
    end
    local hash = HashString(body) .. '-' .. #body

    local optionTypes = StorySaver.GetOptionTypes()
    if optionTypes[CHATTER_START_TRADINGHOUSE] and not optionTypes[CHATTER_START_BANK] then
        return
    end

    local accountCache = StorySaver:GetCache(eventType, name)
    accountCache[hash] = body

    local eventData = StorySaver:GetEventWithHash(eventType, name, hash)
    if eventData == nil then
        eventData = StorySaver:NewEvent(eventType, name, hash)
    end

    if eventData.selectedOptionHashes[StorySaver.lastSelectedOptionHash] == nil then
        eventData.selectedOptionHashes[StorySaver.lastSelectedOptionHash] = {}
        eventData.selectedOptionHashes[StorySaver.lastSelectedOptionHash]['timeStamp'] = GetTimeStamp()
    end
    StorySaver.lastSelectedOptionHash = ''

    for i = 1, GetChatterOptionCount() do
        local optionType
        body, optionType = GetChatterOption(i)
        hash = HashString(body) .. '-' .. #body

        accountCache = StorySaver:GetCache(eventType, name)
        accountCache[hash] = body

        if eventData.optionHashes[hash] == nil then
            eventData.optionHashes[hash] = {}
            eventData.optionHashes[hash]['type'] = optionType
            eventData.optionHashes[hash]['timeStamp'] = GetTimeStamp()
        end
    end

    StorySaver.interface:TriggerRefreshData()
end

function StorySaver.OnDialogueOptionSelected(obj, area)
    local eventType = 'dialogues'
    local name = GetUnitName('interact')
    local body = area:GetText()
    local hash = HashString(body) .. '-' .. #body

    local accountCache = StorySaver:GetCache(eventType, name)
    accountCache[hash] = body

    StorySaver.lastSelectedOptionHash = hash

    StorySaver.coreHandleChatterOptionClicked(obj, area)
end

function StorySaver.OnDialogueEnd(...)
    StorySaver.lastSelectedOptionHash = ''
end

function StorySaver.OnSubtitle(arg1, msgType, from, body)
    if msgType ~= CHAT_CHANNEL_MONSTER_EMOTE and msgType ~= CHAT_CHANNEL_MONSTER_SAY and msgType ~= CHAT_CHANNEL_MONSTER_WHISPER and msgType ~= CHAT_CHANNEL_MONSTER_YELL then
        return
    end

    local eventType = 'subtitles'
    local name = zo_strformat('<<C:1>>', from)
    local hash = HashString(body) .. '-' .. #body

    if StorySaver:GetEventWithHash(eventType, name, hash) ~= nil then
        return
    end

    local accountCache = StorySaver:GetCache(eventType, name)
    accountCache[hash] = body

    StorySaver:NewEvent(eventType, name, hash)

    StorySaver.interface:TriggerRefreshData()
end

function StorySaver.OnBook(obj, name, body, medium, showTitle, ...)
    local eventType = 'books'
    local hash = HashString(body) .. '-' .. #body

    if StorySaver:GetEventWithHash(eventType, name, hash) ~= nil then
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

    local accountCache = StorySaver:GetCache(eventType, name)
    accountCache[hash] = parts

    local eventData = StorySaver:NewEvent(eventType, name, hash)
    eventData.medium = medium
    eventData.showTitle = showTitle

    StorySaver.interface:TriggerRefreshData()

    StorySaver.coreSetupBook(obj, name, body, medium, showTitle, ...)
end

function StorySaver.OnItem(obj, questItem, ...)
    local eventType = 'items'
    local name = questItem.name

    if StorySaver:GetEventWithHash(eventType, name, questItem.questItemId) ~= nil then
        return
    end

    StorySaver:NewEvent(eventType, name, questItem.questItemId)

    StorySaver.interface:TriggerRefreshData()

    StorySaver.coreAddQuestItem(obj, questItem, ...)
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

function StorySaver:Initialize()
    if self.coreHandleChatterOptionClicked ~= nil or self.coreSetupBook ~= nil or self.coreAddQuestItem ~= nil then
        return
    end

    self.eventNumber = 0
    self.lastSelectedOptionHash = ''

    self.accountSavedVariables = ZO_SavedVars:NewAccountWide(self.name .. 'SavedVariables', 1, nil, self.accountSavedVariablesDefaults, nil, nil)

    self.events = self.accountSavedVariables.events[self.currentWorldName][self.currentCharacterName]

    self.coreHandleChatterOptionClicked = INTERACTION.HandleChatterOptionClicked
    self.coreSetupBook = LORE_READER.SetupBook
    self.coreAddQuestItem = ZO_InventoryManager.AddQuestItem

    INTERACTION.HandleChatterOptionClicked = self.OnDialogueOptionSelected
    LORE_READER.SetupBook = self.OnBook
    ZO_InventoryManager.AddQuestItem = self.OnItem

    StorySaverOldData:UpdateSchema()

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CHATTER_BEGIN, self.OnDialogue)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CONVERSATION_UPDATED, self.OnDialogue)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_OFFERED, self.OnDialogue)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_COMPLETE_DIALOG, self.OnDialogue)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CHATTER_END, self.OnDialogueEnd)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_QUEST_COMPLETE, self.OnDialogueEnd)
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_CHAT_MESSAGE_CHANNEL, self.OnSubtitle)

    self.interface = ZO_SortFilterList.New(StorySaverInterface, StorySaverEventListFrame)
    self.interface:InitializeInterface()
end

function StorySaver.OnAddOnLoaded(arg1, addOnName)
    if addOnName ~= StorySaver.name then
        return
    end

    StorySaver:Initialize()
end

EVENT_MANAGER:RegisterForEvent(StorySaver.name, EVENT_ADD_ON_LOADED, StorySaver.OnAddOnLoaded)
