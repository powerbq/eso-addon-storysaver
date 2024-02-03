StorySaver = {}

StorySaver.name = 'StorySaver'

StorySaver.coreHandleChatterOptionClicked = nil
StorySaver.coreSetupBook = nil
StorySaver.coreAddQuestItem = nil
StorySaver.interface = nil

StorySaver.characterSavedVariablesDefaults = {}
StorySaver.characterSavedVariablesDefaults['dialogues'] = {}
StorySaver.characterSavedVariablesDefaults['subtitles'] = {}
StorySaver.characterSavedVariablesDefaults['books'] = {}
StorySaver.characterSavedVariablesDefaults['items'] = {}

StorySaver.accountSavedVariablesDefaults = {}
StorySaver.accountSavedVariablesDefaults['dialogues'] = {}
StorySaver.accountSavedVariablesDefaults['subtitles'] = {}
StorySaver.accountSavedVariablesDefaults['books'] = {}

function StorySaver:GetAccountCache(eventType, name)
    if self.accountSavedVariables[eventType][name] == nil then
        self.accountSavedVariables[eventType][name] = {}
    end

    return self.accountSavedVariables[eventType][name]
end

function StorySaver:CleanupEvents(eventType, name)
    local i = 0

    for eventId, _ in pairs(self.characterSavedVariables[eventType][name]) do
        i = i + 1
    end

    if i == 0 then
        self.characterSavedVariables[eventType][name] = nil
    end
end

function StorySaver:RemoveEvent(eventType, name, eventId)
    local eventData = self.characterSavedVariables[eventType][name][eventId]

    self.characterSavedVariables[eventType][name][eventId] = nil

    self:CleanupEvents(eventType, name)
end

function StorySaver:IsEventDuplicate(eventType, name, eventId)
    local currentEventId, currentEventData = eventId, self.characterSavedVariables[eventType][name][eventId]

    for eventId, eventData in pairs(self.characterSavedVariables[eventType][name]) do
        if eventId ~= currentEventId then
            if eventData.hash == currentEventData.hash then
                if eventType ~= 'dialogues' then
                    return true
                else
                    if eventData.selectedOptionHash == currentEventData.selectedOptionHash then
                        if #eventData.optionHashes == #currentEventData.optionHashes then
                            local fullMatch = true
                            for i = 1, #eventData.optionHashes do
                                if eventData.optionHashes[i] ~= currentEventData.optionHashes[i] then
                                    fullMatch = false
                                    break
                                end
                            end

                            return fullMatch
                        end
                    end
                end
            end
        end
    end

    return false
end

function StorySaver:Deduplication()
    local eventTypes = { 'dialogues', 'subtitles', 'books', 'items' }
    for _, eventType in pairs(eventTypes) do
        for name, events in pairs(self.characterSavedVariables[eventType]) do
            local keys = {}
            for eventId, _ in pairs(events) do
                table.insert(keys, eventId)
            end

            table.sort(keys, function(a, b) return a > b end)

            for _, eventId in ipairs(keys) do
                if StorySaver:IsEventDuplicate(eventType, name, eventId) then
                    StorySaver:RemoveEvent(eventType, name, eventId)
                end
            end

            self:CleanupEvents(eventType, name)
        end
    end
end

function StorySaver:NewEvent(eventType, name)
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

    if self.characterSavedVariables[eventType][name] == nil then
        self.characterSavedVariables[eventType][name] = {}
    end

    self.characterSavedVariables[eventType][name][eventId] = eventData

    return eventId, eventData
end

function StorySaver.OnDialogue(...)
    local eventType = 'dialogues'
    local name = GetUnitName('interact')

    local area = ZO_InteractWindowTargetAreaBodyText
    local body = area:GetText()
    local hash = HashString(body) .. '-' .. #body

    if #body == 0 then
        return
    end

    local accountCache = StorySaver:GetAccountCache(eventType, name)
    accountCache[hash] = body

    local eventId, eventData = StorySaver:NewEvent(eventType, name)
    eventData.hash = hash
    eventData.optionHashes = {}
    eventData.selectedOptionHash = StorySaver.lastSelectedOptionHash

    StorySaver.lastSelectedOptionHash = nil

    local cnt = ZO_InteractWindowPlayerAreaOptions:GetNumChildren()
    for i = 1, cnt do
        area = ZO_InteractWindowPlayerAreaOptions:GetChild(i)
        body = area:GetText()
        hash = HashString(body) .. '-' .. #body

        local accountCache = StorySaver:GetAccountCache(eventType, name)
        accountCache[hash] = body

        eventData.optionHashes[i] = hash

        local nextArea = ZO_InteractWindowPlayerAreaOptions:GetChild(i + 1)
        if nextArea:IsHidden() then
            break
        end
    end

    if StorySaver:IsEventDuplicate(eventType, name, eventId) then
        StorySaver:RemoveEvent(eventType, name, eventId)
    end

    StorySaver.interface:TriggerRefreshData()
end

function StorySaver.OnDialogueOptionSelected(obj, area)
    local eventType = 'dialogues'
    local name = GetUnitName('interact')
    local body = area:GetText()
    local hash = HashString(body) .. '-' .. #body

    local accountCache = StorySaver:GetAccountCache(eventType, name)
    accountCache[hash] = body

    StorySaver.lastSelectedOptionHash = hash

    StorySaver.coreHandleChatterOptionClicked(obj, area)
end

function StorySaver.OnDialogueEnd(...)
    StorySaver.lastSelectedOptionHash = nil
end

function StorySaver.OnSubtitle(arg1, msgType, from, body)
    if msgType ~= CHAT_CHANNEL_MONSTER_EMOTE and msgType ~= CHAT_CHANNEL_MONSTER_SAY and msgType ~= CHAT_CHANNEL_MONSTER_WHISPER and msgType ~= CHAT_CHANNEL_MONSTER_YELL then
        return
    end

    local eventType = 'subtitles'
    local name = zo_strformat('<<C:1>>', from)
    local hash = HashString(body) .. '-' .. #body

    local accountCache = StorySaver:GetAccountCache(eventType, name)
    accountCache[hash] = body

    local eventId, eventData = StorySaver:NewEvent(eventType, name)
    eventData.hash = hash

    if StorySaver:IsEventDuplicate(eventType, name, eventId) then
        StorySaver:RemoveEvent(eventType, name, eventId)
    end

    StorySaver.interface:TriggerRefreshData()
end

function StorySaver.OnBook(obj, name, body, medium, showTitle, ...)
    local eventType = 'books'
    local hash = HashString(body) .. '-' .. #body

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

    local accountCache = StorySaver:GetAccountCache(eventType, name)
    accountCache[hash] = parts

    local eventId, eventData = StorySaver:NewEvent(eventType, name)
    eventData.hash = hash
    eventData.medium = medium
    eventData.showTitle = showTitle

    if StorySaver:IsEventDuplicate(eventType, name, eventId) then
        StorySaver:RemoveEvent(eventType, name, eventId)
    end

    StorySaver.interface:TriggerRefreshData()

    StorySaver.coreSetupBook(obj, name, body, medium, showTitle, ...)
end

function StorySaver.OnItem(obj, questItem, ...)
    local eventType = 'items'
    local name = questItem.name

    local eventId, eventData = StorySaver:NewEvent(eventType, name)
    eventData.hash = questItem.questItemId

    if StorySaver:IsEventDuplicate(eventType, name, eventId) then
        StorySaver:RemoveEvent(eventType, name, eventId)
    end

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

function StorySaver:UpdateSchema()
    if self.accountSavedVariables.zones ~= nil then
        self.accountSavedVariables.zones = nil
    end

    if self.characterSavedVariables.events ~= nil then
        for oldEventId, eventData in pairs(self.characterSavedVariables.events) do
            local oldEventType = tonumber(string.sub(oldEventId, -1))
            local name = eventData.name
            local timeStamp, eventNumber = self:ParseEventId(oldEventId)
            local eventId = timeStamp .. '-' .. eventNumber
            local eventType
            if oldEventType == 1 then
                eventType = 'dialogues'
            elseif oldEventType == 2 then
                eventType = 'subtitles'
            elseif oldEventType == 3 then
                eventType = 'books'
            end

            if self.characterSavedVariables[eventType][name] == nil then
                self.characterSavedVariables[eventType][name] = {}
            end

            self.characterSavedVariables[eventType][name][eventId] = eventData
            self.characterSavedVariables[eventType][name][eventId].name = nil
        end

        self.characterSavedVariables.events = nil
    end
end

function StorySaver:Initialize()
    if self.coreHandleChatterOptionClicked ~= nil or self.coreSetupBook ~= nil or self.coreAddQuestItem ~= nil then
        return
    end

    self.eventNumber = 0
    self.lastSelectedOptionHash = nil

    self.characterSavedVariables = ZO_SavedVars:New(self.name .. 'SavedVariables', 1, nil, self.characterSavedVariablesDefaults, GetWorldName(), nil)
    self.accountSavedVariables = ZO_SavedVars:NewAccountWide(self.name .. 'SavedVariables', 1, nil, self.accountSavedVariablesDefaults, nil, nil)

    self.coreHandleChatterOptionClicked = INTERACTION.HandleChatterOptionClicked
    self.coreSetupBook = LORE_READER.SetupBook
    self.coreAddQuestItem = ZO_InventoryManager.AddQuestItem

    INTERACTION.HandleChatterOptionClicked = self.OnDialogueOptionSelected
    LORE_READER.SetupBook = self.OnBook
    ZO_InventoryManager.AddQuestItem = self.OnItem

    self:UpdateSchema()

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
