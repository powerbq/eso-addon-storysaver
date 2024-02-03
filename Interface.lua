ZO_CreateStringId('SI_BINDING_NAME_TOGGLE_STORY_SAVER', 'Toggle Story Saver')
ZO_CreateStringId('SI_WINDOW_TITLE_STORY_SAVER', 'Story Saver')

StorySaverInterface = ZO_SortFilterList:Subclass()

function StorySaverInterface:InitializeInterface()
    self.scrollData = ZO_ScrollList_GetDataList(self.list)

    ZO_ScrollList_AddDataType(self.list, 1, 'StorySaverEventListRow', 40, function(control, data)
        self:SetupRow(control, data)
    end)
    ZO_ScrollList_EnableHighlight(self.list, 'ZO_ThinListHighlight')

    self.sortKeys = {
        name = { tiebreaker = 'eventId', tieBreakerSortOrder = ZO_SORT_ORDER_DOWN, },
        zoneName = { tiebreaker = 'eventId', tieBreakerSortOrder = ZO_SORT_ORDER_DOWN, },
        eventId = {}
    }
    self.sortFunction = function(listEntry1, listEntry2)
        return ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, self.sortKeys, self.currentSortOrder)
    end
    self.sortHeaderGroup:SelectHeaderByKey('eventId')

    self.search = ZO_StringSearch:New()
    self.search:AddProcessor(1, function(arg1, data, search, arg4)
        return zo_plainstrfind(data.body:lower(), search)
    end)

    ESO_Dialogs['StorySaverDeduplicationDialog'] = {
        title = {
            text = GetString(STORY_SAVER_DEDUPLICATION),
        },
        mainText = {
            text = GetString(STORY_SAVER_CONFIRM),
        },
        buttons = {
            [1] = {
                text = SI_DIALOG_CONFIRM,
                callback = function(...)
                    StorySaver:Deduplication()
                    self:RefreshData()
                end,
            },
            [2] = {
                text = SI_DIALOG_CANCEL,
            },
        },
    }

    ESO_Dialogs['StorySaverRemoveRecordDialog'] = {
        title = {
            text = GetString(STORY_SAVER_REMOVE),
        },
        mainText = {
            text = GetString(STORY_SAVER_CONFIRM),
        },
        buttons = {
            [1] = {
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    StorySaver:RemoveEvent(dialog.data.eventType, dialog.data.name, dialog.data.eventId)
                    self:RefreshData()
                end,
            },
            [2] = {
                text = SI_DIALOG_CANCEL,
            },
        },
    }

    self.keybindStripDescriptor = {
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            keybind = 'UI_SHORTCUT_SECONDARY',
            name = function()
                return GetString(STORY_SAVER_DEDUPLICATION)
            end,
            callback = function()
                ZO_Dialogs_ShowDialog('StorySaverDeduplicationDialog')
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            keybind = 'UI_SHORTCUT_PRIMARY',
            name = function()
                return GetString(STORY_SAVER_READ)
            end,
            visible = function()
                return self.mouseOverRow and self.mouseOverRow.data.eventType == 'books'
            end,
            callback = function()
                self:Read(self.mouseOverRow.data)
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            keybind = 'UI_SHORTCUT_SHOW_QUEST_ON_MAP',
            name = function()
                return GetString(STORY_SAVER_MAP)
            end,
            visible = function()
                return self.mouseOverRow
            end,
            callback = function()
                self:ShowOnMap(self.mouseOverRow.data)
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            keybind = 'UI_SHORTCUT_NEGATIVE',
            name = function()
                return GetString(STORY_SAVER_REMOVE)
            end,
            visible = function()
                return self.mouseOverRow
            end,
            callback = function()
                ZO_Dialogs_ShowDialog('StorySaverRemoveRecordDialog', self.mouseOverRow.data)
            end,
        },
    }

    local scene = ZO_Scene:New('storySaver', SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_STANDARD_RIGHT_PANEL)
    scene:AddFragment(CODEX_WINDOW_SOUNDS)
    scene:AddFragment(RIGHT_BG_FRAGMENT)
    scene:AddFragment(TITLE_FRAGMENT)
    scene:AddFragment(ZO_SetTitleFragment:New(SI_WINDOW_TITLE_STORY_SAVER))
    scene:AddFragment(ZO_FadeSceneFragment:New(StorySaverEventListFrame))
    scene:RegisterCallback('StateChange',
        function(oldState, newState)
            if (newState == SCENE_SHOWING) then
                self:AddKeybinds()
            elseif (newState == SCENE_HIDDEN) then
                self:RemoveKeybinds()
            end
        end)

    SLASH_COMMANDS['/storysaver'] = function()
        if StorySaverEventListFrame:IsHidden() then
            self:RefreshData()

            SCENE_MANAGER:Show('storySaver')
        else
            SCENE_MANAGER:Hide('storySaver')
        end
    end
end

function StorySaverInterface:SortScrollList()
    table.sort(self.scrollData, self.sortFunction)
end

function StorySaverInterface:FilterScrollList()
    ZO_ClearNumericallyIndexedTable(self.scrollData)

    local filterAndSearchControl = GetControl(StorySaverEventListFrame, 'FilterAndSearch')

    local showDialogues = GetControl(filterAndSearchControl, 'Dialogues').checked
    local showSubtitles = GetControl(filterAndSearchControl, 'Subtitles').checked
    local showBooks = GetControl(filterAndSearchControl, 'Books').checked
    local showItems = GetControl(filterAndSearchControl, 'Items').checked
    local search = GetControl(GetControl(filterAndSearchControl, 'Search'), 'Box'):GetText():lower()

    local resultControl = GetControl(filterAndSearchControl, 'Result')

    for i, row in pairs(self.masterList) do
        local skip = false

        local eventType = row.eventType
        if eventType == 'dialogues' and not showDialogues then
            skip = true
        elseif eventType == 'subtitles' and not showSubtitles then
            skip = true
        elseif eventType == 'books' and not showBooks then
            skip = true
        elseif eventType == 'items' and not showItems then
            skip = true
        end

        if not skip and #search > 0 then
            local eventData = row.eventData
            local name = row.name
            local zoneName = row.zoneName
            local hash = eventData.hash

            local body = ''
            if eventType ~= 'items' then
                body = StorySaver:GetAccountCache(eventType, name)[hash]
            end

            if eventType == 'books' then
                body = table.concat(body)
            elseif eventType == 'dialogues' then
                local selectedOptionHash = eventData.selectedOptionHash
                if selectedOptionHash ~= nil then
                    body = body .. '\r\n' .. StorySaver:GetAccountCache(eventType, name)[selectedOptionHash]
                end

                local optionHashes = eventData.optionHashes
                for i = 1, #optionHashes do
                    body = body .. '\r\n' .. StorySaver:GetAccountCache(eventType, name)[optionHashes[i]]
                end
            end

            if not self.search:IsMatch(search, { type = 1, body = name .. '\r\n' .. zoneName .. '\r\n' .. body }) then
                skip = true
            end
        end

        if not skip then
            table.insert(self.scrollData, ZO_ScrollList_CreateDataEntry(1, row))
        end
    end

    resultControl:SetText(string.format(GetString(STORY_SAVER_RESULT), #self.scrollData, #self.masterList))
end

function StorySaverInterface:BuildMasterList()
    self.masterList = {}

    local currentTimeStamp = GetTimeStamp()
    local today = GetDateStringFromTimestamp(currentTimeStamp)

    for _, eventType in pairs({ 'dialogues', 'subtitles', 'books', 'items' }) do
        for name, events in pairs(StorySaver.characterSavedVariables[eventType]) do
            for eventId, eventData in pairs(events) do
                local timeStamp, _ = StorySaver:ParseEventId(eventId)

                local when = GetDateStringFromTimestamp(timeStamp)
                if when == today then
                    when = ZO_FormatDurationAgo(currentTimeStamp - timeStamp)
                end

                local zoneName = zo_strformat('<<C:1>>', GetZoneNameByIndex(eventData.zoneIndex))

                table.insert(self.masterList, { eventType = eventType, name = name, zoneName = zoneName, when = when, eventId = eventId, eventData = eventData })
            end
        end
    end
end

function StorySaverInterface:SetupRow(control, data)
    control.data = data

    local typeControl = GetControl(control, 'Type')
    local nameControl = GetControl(control, 'Name')
    local zoneControl = GetControl(control, 'Zone')
    local whenControl = GetControl(control, 'When')

    typeControl:SetTexture(typeControl[data.eventType .. 'Texture'])
    nameControl:SetText(data.name)
    zoneControl:SetText(data.zoneName)
    whenControl:SetText(data.when)

    whenControl.normalColor = ZO_NORMAL_TEXT
    nameControl.normalColor = ZO_NORMAL_TEXT
    zoneControl.normalColor = ZO_NORMAL_TEXT

    ZO_SortFilterList.SetupRow(self, control, data)
end

function StorySaverInterface:OnRowStateChanged(control, state)
    if state then
        self:Row_OnMouseEnter(control)
    else
        self:Row_OnMouseExit(control)
    end

    ClearTooltip(ItemTooltip)

    StorySaverBrowserFrame:SetHidden(true)

    local bodyControl = GetControl(StorySaverBrowserFrame, 'Body')
    local selectedOptionControl = GetControl(StorySaverBrowserFrame, 'SelectedOption')
    local optionsControl = GetControl(StorySaverBrowserFrame, 'Options')
    local topDividerControl = GetControl(StorySaverBrowserFrame, 'TopDivider')
    local bottomDividerControl = GetControl(StorySaverBrowserFrame, 'BottomDivider')

    bodyControl:SetText('')
    selectedOptionControl:SetText('')
    optionsControl:SetText('')

    bodyControl:SetHidden(true)
    selectedOptionControl:SetHidden(true)
    optionsControl:SetHidden(true)
    topDividerControl:SetHidden(true)
    bottomDividerControl:SetHidden(true)

    local eventType = control.data.eventType
    if eventType == 'books' or not state then
        return
    end

    local name = control.data.name
    local eventData = control.data.eventData
    local hash = eventData.hash

    if eventType == 'items' then
        InitializeTooltip(ItemTooltip, control, RIGHT, -92, 0)
        ItemTooltip:SetLink('|H1:quest_item:' .. hash .. '|h|h')
        return
    end

    local body = StorySaver:GetAccountCache(eventType, name)[hash]
    bodyControl:SetText(body)
    bodyControl:SetHidden(false)

    if eventType == 'dialogues' then
        local selectedOptionHash = eventData.selectedOptionHash
        if selectedOptionHash ~= nil then
            body = StorySaver:GetAccountCache(eventType, name)[selectedOptionHash]
            selectedOptionControl:SetText(body)
            selectedOptionControl:SetHidden(false)
            topDividerControl:SetHidden(false)
        end

        local optionsBody = ''

        local optionHashes = eventData.optionHashes
        for i = 1, #optionHashes do
            body = StorySaver:GetAccountCache(eventType, name)[optionHashes[i]]
            if i == 1 then
                optionsBody = body
            else
                optionsBody = optionsBody .. '\r\n' .. body
            end
        end

        if optionsBody ~= '' then
            optionsControl:SetText(optionsBody)
            optionsControl:SetHidden(false)
            bottomDividerControl:SetHidden(false)
        end
    end

    StorySaverBrowserFrame:SetHidden(false)
end

function StorySaverInterface:Read(data)
    local title = data.name
    local eventData = data.eventData
    local medium = eventData.medium
    local showTitle = eventData.showTitle
    local hash = eventData.hash

    local parts = StorySaver:GetAccountCache('books', title)[hash]
    local body = table.concat(parts)

    StorySaver.coreSetupBook(LORE_READER, title, body, medium, showTitle, IsInGamepadPreferredMode())

    SCENE_MANAGER:Push('loreReaderInteraction')
end

function StorySaverInterface:ShowOnMap(data)
    local eventData = data.eventData
    local zoneIndex = eventData.zoneIndex
    local globalX = eventData.x
    local globalY = eventData.y

    ZO_WorldMap_ShowWorldMap()

    local zoneId = GetZoneId(zoneIndex)
    if GetParentZoneId(zoneId) ~= zoneId then
        zoneId = GetParentZoneId(zoneId)
    end

    ZO_WorldMap_SetMapByIndex(GetMapIndexByZoneId(zoneId))

    zo_callLater(function()
        local localX, localY = LibGPS3:GlobalToLocal(globalX, globalY)

        ZO_WorldMap_PanToNormalizedPosition(localX, localY)
        if LibMapPing ~= nil then
            LibMapPing:SetMapPing(MAP_PIN_TYPE_RALLY_POINT, MAP_TYPE_LOCATION_CENTERED, localX, localY)
        end
    end, 1500)
end

function StorySaverInterface:TriggerRefreshData()
    if not StorySaverEventListFrame:IsHidden() then
        self:RefreshData()
    end
end

function StorySaverInterface.SetupCheckableButton(control, texturePrefix)
    control.texturePrefix = texturePrefix
    control.checked = false

    local handler = function()
        control.checked = not control.checked

        if not control.checked then
            control:SetNormalTexture(control.texturePrefix .. 'up' .. '.dds')
            control:SetPressedTexture(control.texturePrefix .. 'up' .. '.dds')
            control:SetMouseOverTexture(control.texturePrefix .. 'over' .. '.dds')
        else
            control:SetNormalTexture(control.texturePrefix .. 'down' .. '.dds')
            control:SetPressedTexture(control.texturePrefix .. 'down' .. '.dds')
            control:SetMouseOverTexture(nil)
        end

        if StorySaver.interface ~= nil then
            StorySaver.interface:RefreshFilters()
        end
    end

    control:SetHandler('OnClicked', handler)

    handler()
end
