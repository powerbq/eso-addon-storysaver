StorySaverSettings = {}

StorySaverSettings.values = {}
StorySaverSettings.defaults = {
    showOptionDate = true,
    deleteDialoguesOlderThan = 0,
    useOptionsDates = true,
    deleteSubtitlesOlderThan = 0,
    deleteBooksOlderThan = 0,
    deleteItemsOlderThan = 0,
    deleteOn = 'manually',
    optimizeOn = 'manually',
}

function StorySaverSettings:SelectSource()
    if StorySaver.accountSavedVariables.settingsAccountWide then
        if StorySaver.accountSavedVariables.settings == nil then
            StorySaver.accountSavedVariables.settings = StorySaver.characterSavedVariables.settings
        end
        StorySaver.characterSavedVariables.settings = nil
        self.values = StorySaver.accountSavedVariables.settings
    else
        if StorySaver.characterSavedVariables.settings == nil then
            StorySaver.characterSavedVariables.settings = StorySaver.accountSavedVariables.settings
        end
        StorySaver.accountSavedVariables.settings = nil
        self.values = StorySaver.characterSavedVariables.settings
    end
end

function StorySaverSettings:Cleanup()
    for key, _ in pairs(self.values) do
        local delete = true

        for defaultKey, _ in pairs(self.defaults) do
            if defaultKey == key then
                delete = false
                break
            end
        end

        if delete then
            self.values[key] = nil
        end
    end
end

function StorySaverSettings:SetupPanel()
    self:SelectSource()
    self:Cleanup()

    local panelName = StorySaver.name .. ' Settings'

    local panelData = {
        type = 'panel',
        name = panelName,
        author = '@f1rex',
    }
    self.panel = LibAddonMenu2:RegisterAddonPanel(panelName, panelData)

    local optionsData = {
        {
            type = 'header',
            name = GetString(STORY_SAVER_SETTINGS_GENERAL),
        },
        {
            type = 'checkbox',
            name = GetString(STORY_SAVER_SETTINGS_ACCOUNT_WIDE),
            getFunc = function()
                return StorySaver.accountSavedVariables.settingsAccountWide
            end,
            setFunc = function(value)
                StorySaver.accountSavedVariables.settingsAccountWide = value

                self:SelectSource()
                self:Cleanup()
            end,
        },
        {
            type = 'header',
            name = GetString(STORY_SAVER_SETTINGS_INTERFACE),
        },
        {
            type = 'checkbox',
            name = GetString(STORY_SAVER_SETTINGS_OPTION_DATE),
            getFunc = function()
                return self.values.showOptionDate
            end,
            setFunc = function(value)
                self.values.showOptionDate = value
            end,
            default = self.defaults.showOptionDate,
        },
        {
            type = 'header',
            name = GetString(STORY_SAVER_SETTINGS_DATA_DELETION),
        },
        {
            type = 'editbox',
            name = GetString(STORY_SAVER_SETTINGS_DELETE_DIALOGUES),
            getFunc = function()
                return self.values.deleteDialoguesOlderThan
            end,
            setFunc = function(value)
                self.values.deleteDialoguesOlderThan = tonumber(value)
            end,
            textType = TEXT_TYPE_NUMERIC,
            default = self.defaults.deleteDialoguesOlderThan,
        },
        {
            type = 'checkbox',
            name = GetString(STORY_SAVER_SETTINGS_USE_OPTIONS_DATES),
            getFunc = function()
                return self.values.useOptionsDates
            end,
            setFunc = function(value)
                self.values.useOptionsDates = value
            end,
            textType = TEXT_TYPE_NUMERIC,
            default = self.defaults.useOptionsDates,
        },
        {
            type = 'editbox',
            name = GetString(STORY_SAVER_SETTINGS_DELETE_SUBTITLES),
            getFunc = function()
                return self.values.deleteSubtitlesOlderThan
            end,
            setFunc = function(value)
                self.values.deleteSubtitlesOlderThan = tonumber(value)
            end,
            textType = TEXT_TYPE_NUMERIC,
            default = self.defaults.deleteSubtitlesOlderThan,
        },
        {
            type = 'editbox',
            name = GetString(STORY_SAVER_SETTINGS_DELETE_BOOKS),
            getFunc = function()
                return self.values.deleteBooksOlderThan
            end,
            setFunc = function(value)
                self.values.deleteBooksOlderThan = tonumber(value)
            end,
            textType = TEXT_TYPE_NUMERIC,
            default = self.defaults.deleteBooksOlderThan,
        },
        {
            type = 'editbox',
            name = GetString(STORY_SAVER_SETTINGS_DELETE_ITEMS),
            getFunc = function()
                return self.values.deleteItemsOlderThan
            end,
            setFunc = function(value)
                self.values.deleteItemsOlderThan = tonumber(value)
            end,
            textType = TEXT_TYPE_NUMERIC,
            default = self.defaults.deleteItemsOlderThan,
        },
        {
            type = 'dropdown',
            name = GetString(STORY_SAVER_SETTINGS_DELETE_ON),
            choices = {
                GetString(STORY_SAVER_SETTINGS_MANUALLY),
                GetString(STORY_SAVER_SETTINGS_LOAD),
            },
            choicesValues = {
                'manually',
                'load',
            },
            getFunc = function()
                return self.values.deleteOn
            end,
            setFunc = function(value)
                self.values.deleteOn = value
            end,
            default = self.defaults.deleteOn,
        },
        {
            type = 'button',
            name = GetString(STORY_SAVER_SETTINGS_DELETE_BUTTON),
            func = function()
                StorySaver:DeleteOldData()
            end,
            isDangerous = true,
        },
        {
            type = 'header',
            name = GetString(STORY_SAVER_SETTINGS_DATA_OPTIMIZATION),
        },
        {
            type = 'dropdown',
            name = GetString(STORY_SAVER_SETTINGS_OPTIMIZE_ON),
            choices = {
                GetString(STORY_SAVER_SETTINGS_MANUALLY),
                GetString(STORY_SAVER_SETTINGS_LOAD),
            },
            choicesValues = {
                'manually',
                'load',
            },
            getFunc = function()
                return self.values.optimizeOn
            end,
            setFunc = function(value)
                self.values.optimizeOn = value
            end,
            default = self.defaults.optimizeOn,
        },
        {
            type = 'button',
            name = GetString(STORY_SAVER_SETTINGS_OPTIMIZE_BUTTON),
            func = function()
                StorySaver:OptimizeStorage()
            end,
            isDangerous = true,
        },
    }
    LibAddonMenu2:RegisterOptionControls(panelName, optionsData)
end