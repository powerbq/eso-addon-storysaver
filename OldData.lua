StorySaverOldData = {}

function StorySaverOldData:CombineDialogueOptions(name, targetEventId)
    local targetEventData = StorySaver.events['dialogues'][name][targetEventId]
    if targetEventData == nil then
        return
    end

    for eventId, eventData in pairs(StorySaver.events['dialogues'][name]) do
        if eventId ~= targetEventId and eventData.hash == targetEventData.hash then
            for selectedOptionHash, data in pairs(eventData.selectedOptionHashes) do
                if targetEventData.selectedOptionHashes[selectedOptionHash] == nil then
                    targetEventData.selectedOptionHashes[selectedOptionHash] = data
                end
            end
            for optionHash, data in pairs(eventData.optionHashes) do
                if targetEventData.optionHashes[optionHash] == nil then
                    targetEventData.optionHashes[optionHash] = data
                end
            end

            StorySaver:DeleteEvent('dialogues', name, eventId)
        end
    end
end

function StorySaverOldData:OptimizeDialogues()
    for name, events in pairs(StorySaver.events['dialogues']) do
        local keys = {}
        for eventId, _ in pairs(events) do
            table.insert(keys, eventId)
        end

        table.sort(keys, function(a, b)
            return a < b
        end)

        for _, eventId in ipairs(keys) do
            self:CombineDialogueOptions(name, eventId)
        end
    end
end

function StorySaverOldData:IsEventDuplicate(eventType, name, currentEventId)
    local currentEventData = StorySaver.events[eventType][name][currentEventId]

    for eventId, eventData in pairs(StorySaver.events[eventType][name]) do
        if eventId ~= currentEventId then
            if eventData.hash == currentEventData.hash then
                return true
            end
        end
    end

    return false
end

function StorySaverOldData:OptimizeOthers()
    local eventTypes = { 'subtitles', 'books', 'items' }
    for _, eventType in pairs(eventTypes) do
        for name, events in pairs(StorySaver.events[eventType]) do
            local keys = {}
            for eventId, _ in pairs(events) do
                table.insert(keys, eventId)
            end

            table.sort(keys, function(a, b)
                return a > b
            end)

            for _, eventId in ipairs(keys) do
                if self:IsEventDuplicate(eventType, name, eventId) then
                    StorySaver:DeleteEvent(eventType, name, eventId)
                end
            end
        end
    end
end

function StorySaverOldData:UpdateSchemaV1()
    if StorySaver.accountSavedVariables.zones ~= nil then
        StorySaver.accountSavedVariables.zones = nil
    end

    if StorySaver.characterSavedVariables.events ~= nil then
        for oldEventId, eventData in pairs(StorySaver.characterSavedVariables.events) do
            local oldEventType = tonumber(string.sub(oldEventId, -1))
            local name = eventData.name
            local timeStamp, eventNumber = StorySaver:ParseEventId(oldEventId)
            local eventId = timeStamp .. '-' .. eventNumber
            local eventType
            if oldEventType == 1 then
                eventType = 'dialogues'
            elseif oldEventType == 2 then
                eventType = 'subtitles'
            elseif oldEventType == 3 then
                eventType = 'books'
            end

            if StorySaver.characterSavedVariables[eventType][name] == nil then
                StorySaver.characterSavedVariables[eventType][name] = {}
            end

            StorySaver.characterSavedVariables[eventType][name][eventId] = eventData
            StorySaver.characterSavedVariables[eventType][name][eventId].name = nil
        end

        StorySaver.characterSavedVariables.events = nil
    end
end

function StorySaverOldData:UpdateSchemaV2()
    if StorySaver.accountSavedVariables.dialogues ~= nil then
        StorySaver.accountSavedVariables.cache.dialogues = StorySaver.accountSavedVariables.dialogues
        StorySaver.accountSavedVariables.dialogues = nil
    end

    if StorySaver.accountSavedVariables.subtitles ~= nil then
        StorySaver.accountSavedVariables.cache.subtitles = StorySaver.accountSavedVariables.subtitles
        StorySaver.accountSavedVariables.subtitles = nil
    end

    if StorySaver.accountSavedVariables.books ~= nil then
        StorySaver.accountSavedVariables.cache.books = StorySaver.accountSavedVariables.books
        StorySaver.accountSavedVariables.books = nil
    end

    if StorySaver.characterSavedVariables.dialogues ~= nil then
        StorySaver.events.dialogues = StorySaver.characterSavedVariables.dialogues
        StorySaver.characterSavedVariables.dialogues = nil

        for _, dialogueEvents in pairs(StorySaver.events.dialogues) do
            for eventId, eventData in pairs(dialogueEvents) do
                local timeStamp, _ = StorySaver:ParseEventId(eventId)

                eventData.selectedOptionHashes = {}

                local selectedOptionHash = eventData.selectedOptionHash
                eventData.selectedOptionHash = nil
                if selectedOptionHash ~= nil then
                    eventData.selectedOptionHashes[selectedOptionHash] = {}
                    eventData.selectedOptionHashes[selectedOptionHash]['timeStamp'] = timeStamp
                else
                    eventData.selectedOptionHashes[''] = {}
                    eventData.selectedOptionHashes['']['timeStamp'] = timeStamp
                end

                local oldOptionHashes = eventData.optionHashes
                eventData.optionHashes = {}

                for i = 1, #oldOptionHashes do
                    local optionHash = oldOptionHashes[i]

                    eventData.optionHashes[optionHash] = {}
                    eventData.optionHashes[optionHash]['timeStamp'] = timeStamp
                    if selectedOptionHash ~= nil then
                        eventData.optionHashes[optionHash]['type'] = CHATTER_TALK_CHOICE
                    else
                        eventData.optionHashes[optionHash]['type'] = CHATTER_START_TALK
                    end
                end
            end
        end

        self:OptimizeDialogues()
        self:OptimizeOthers()
    end

    if StorySaver.characterSavedVariables.subtitles ~= nil then
        StorySaver.events.subtitles = StorySaver.characterSavedVariables.subtitles
        StorySaver.characterSavedVariables.subtitles = nil
    end

    if StorySaver.characterSavedVariables.books ~= nil then
        StorySaver.events.books = StorySaver.characterSavedVariables.books
        StorySaver.characterSavedVariables.books = nil
    end

    if StorySaver.characterSavedVariables.items ~= nil then
        StorySaver.events.items = StorySaver.characterSavedVariables.items
        StorySaver.characterSavedVariables.items = nil
    end
end

function StorySaverOldData:UpdateSchema()
    self:UpdateSchemaV1()
    self:UpdateSchemaV2()
end
