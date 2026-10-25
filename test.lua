setmetatable(package.loaded, {__mode="v"})
local computer = require("computer")
local unicode = require("unicode")
local event = require("event")
local component = require("component")
local thread = require("thread")

local image = require("Image")
local filesystem = require("FilesystemLib")
local screen = require "Screen"

DataBase = require("lib.Antonesku.Database")

local gui = require("GUI")
require("lib.Antonesku.AdvancedGUI")
require("lib.Antonesku.PrizeList")

local cacheImages = require("cacheImages") --0.5 мб ОЗУ

local settings = require("lib.Antonesku.Settings")
local log = require("lib.Antonesku.Log")

require("lib.Antonesku.Advance")
----------------------------------------------------------------------------
local workspace = gui.workspace()
----------------------------------------------------------------------------
--TODO: Дать нормальные названия. Структуризировать
--TODO: Добавить пометки о возможности продажи
--TODO: Определить размер изображения и переделать imageContainer в slider
--TODO: Попробывать вместо нескольких страниц сделать несколько workspace. Попробывал. Х*рня вышла
--TODO: Убрать дублирование функций в либах
----------------------------------------------------------------------------
--? Добавить кнопку удалить в itemsInfoDataTableList
--? Добавить кнопку для прерывания сессии
--? Мб вынести разметку в отдельный файл
--? Исправить неактивность prizesDataTableList при первом запуске (хз че ему надо вообще). Фикс есть, корявый
--? Добавить label у dataTableFormComboBox
----------------------------------------------------------------------------
-- Слайдер из AdvancedGUI переопределяет стандартный

-- Эта др*нь жрёт 1.2 мб ОЗУ при бездействии. Библиотеки не в счет
-- ~0.07 мб на картинку
-- Если грузить cacheImages в casePage:load, можно не хранить их в памяти, когда casePage неактивна. Но это увеличит прогрузку casePage
----------------------------------------------------------------------------
local programInfo = {
    developer = "Antonesku", -- Кто ответственный за лопату?
    version = "0.1",
    year = "2024"
}
----------------------------------------------------------------------------
--[[
    ПЕРЕМЕННЫЕ
]]
local admins = {
    "Antonesku", "Stawlie_", "NikkyFreaky"
}

local MULTIPLIER_CHANCE = 100

local chatBox = component.isAvailable("chat_box") and component.chat_box
local redControllerList, transposerList, filesystemList = {}, {}, {}
local sides = {
    [0] = "Низ",
    [1] = "Верх",
    [2] = "Зад / Север",
    [3] = "Перед / Юг",
    [4] = "Право / Запад",
    [5] = "Лево / Восток",
}

local items = {}
----------------------------------------------------------------------------
for address, componentType in pairs(component.list()) do
    if componentType == "redstone" then
        table.insert(redControllerList, address)
    elseif componentType == "transposer" then
        table.insert(transposerList, address)
    elseif componentType == "filesystem" then
        table.insert(filesystemList, address)
    end
end
----------------------------------------------------------------------------
--[[
    СТРУКТУРА БД
]]
local currencyDataTable = DataBase:createTable("currency", {
    ["display_name"] = {type = DataBase.STRING, displayName = "Отображаемое имя"},
    ["unit"] = {type = DataBase.STRING},
    ["minecraft_name"] = {type = DataBase.STRING, isRequired = true},
    ["balance"] = {type = DataBase.FLOAT, defaultValue = 0}
})

local itemsInfoDataTable = DataBase:createTable("infoItems", {
    ["display_name"] = {type = DataBase.STRING},
    ["img"] = {type = DataBase.STRING}
})

local priceItemsDataTable = DataBase:createTable("priceItems", {
    ["info_item_id"] = {type = DataBase.STRING},
    ["currency_id"] = {type = DataBase.NUMBER},
    ["price"] = {type = DataBase.FLOAT}
})
priceItemsDataTable:setDependentColumn("info_item_id", itemsInfoDataTable)
priceItemsDataTable:setDependentColumn("currency_id", currencyDataTable)

local rareDataTable = DataBase:createTable("rare", {
    ["display_name"] = {type = DataBase.STRING},
    ["chance"] = {type = DataBase.FLOAT, isRequired = true},
    ["color"] = {type = DataBase.NUMBER, defaultValue = 0xFAC564},
    ["is_big_win"] = {type = DataBase.BOOLEAN, defaultValue = false},
    ["msg"] = {type = DataBase.STRING}
})

local caseDataTable = DataBase:createTable("case", {
    ["display_name"] = {type = DataBase.STRING},
    ["description"] = {type = DataBase.STRING},
    ["sell_items_available"] = {type = DataBase.BOOLEAN},
    ["img"] = {type = DataBase.STRING, isRequired = true},
    ["hidden"] = {type = DataBase.BOOLEAN}
})

local priceCasesDataTable = DataBase:createTable("priceCases", {
    ["case_id"] = {type = DataBase.NUMBER},
    ["currency_id"] = {type = DataBase.NUMBER},
    ["price"] = {type = DataBase.FLOAT, isRequired = true}
})
priceCasesDataTable:setDependentColumn("currency_id", currencyDataTable)
priceCasesDataTable:setDependentColumn("case_id", caseDataTable)

local prizesCaseDataTable = DataBase:createTable("prizesCase", {
    ["case_id"] = {type = DataBase.NUMBER, isRequired = true},
    ["info_item_id"] = {type = DataBase.STRING, isRequired = true},
    ["amount"] = {type = DataBase.NUMBER, isRequired = true, defaultValue = 1},
    ["display_name"] = {type = DataBase.STRING},
    ["rare_id"] = {type = DataBase.NUMBER, isRequired = true}
})
prizesCaseDataTable:setDependentColumn("case_id", caseDataTable)
prizesCaseDataTable:setDependentColumn("info_item_id", itemsInfoDataTable)
prizesCaseDataTable:setDependentColumn("rare_id", rareDataTable)
----------------------------------------------------------------------------
--[[
    ОБОЛОЧКА
]]
local wrapper = workspace:addChild(gui.container(1, 1, workspace.width, workspace.height))
----------------------------------------------------------------------------
--[[
    ПЕРВОНАЧАЛЬНАЯ НАСТРОЙКА
]]
local baseSettingsPage = wrapper:addChild(gui.container(1, 1, wrapper.width, wrapper.height))
baseSettingsPage:addChild(gui.panel(1, 1, baseSettingsPage.width, baseSettingsPage.height, 0xEEEEEE))
baseSettingsPage.hidden = true

baseSettingsPage:addChild(gui.label(1, 2, baseSettingsPage.width, 1, 0x2D2D2D, "Первоначальная настройка")):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)

local redControllerReplenishmentLabel = baseSettingsPage:addChild(gui.label(4, 5, 30, 1, 0x2D2D2D, "Красный контроллер пополнения"))
local redControllerReplenishmentComboBox = baseSettingsPage:addChild(gui.settingsComboBox(redControllerReplenishmentLabel.localX - 1, redControllerReplenishmentLabel.localY + 1, 45, "redControllerReplenishment", redControllerList))
redControllerReplenishmentComboBox.isRequired = true

local transposerReplenishmentLabel = baseSettingsPage:addChild(gui.label(redControllerReplenishmentLabel.localX, redControllerReplenishmentComboBox.localY + redControllerReplenishmentComboBox.height + 2, 30, 1, 0x2D2D2D, "Транспозер пополнения"))
local transposerReplenishmentComboBox = baseSettingsPage:addChild(gui.settingsComboBox(transposerReplenishmentLabel.localX - 1, transposerReplenishmentLabel.localY + 1, 45, "transposerReplenishment", transposerList))
transposerReplenishmentComboBox.isRequired = true

local sideInputLabel = baseSettingsPage:addChild(gui.label(transposerReplenishmentLabel.localX, transposerReplenishmentComboBox.localY + transposerReplenishmentComboBox.height + 2, 30, 1, 0x2D2D2D, "Сторона для забора"))
local sideInputComboBox = baseSettingsPage:addChild(gui.settingsComboBox(sideInputLabel.localX - 1, sideInputLabel.localY + 1, 45, "sideInput", sides, settings.KEY_TABLE))
sideInputComboBox.isRequired = true

local sideOutputLabel = baseSettingsPage:addChild(gui.label(sideInputLabel.localX, sideInputComboBox.localY + sideInputComboBox.height + 2, 30, 1, 0x2D2D2D, "Сторона для выдачи"))
local sideOutputComboBox = baseSettingsPage:addChild(gui.settingsComboBox(sideOutputLabel.localX - 1, sideOutputLabel.localY + 1, 45, "sideOutput", sides, settings.KEY_TABLE))
sideOutputComboBox.isRequired = true

local logsFilesystemLabel = baseSettingsPage:addChild(gui.label(sideInputLabel.localX, sideOutputComboBox.localY + sideOutputComboBox.height + 2, 30, 1, 0x2D2D2D, "Файловая система логов"))
local logsFilesystemComboBox = baseSettingsPage:addChild(gui.settingsComboBox(logsFilesystemLabel.localX - 1, logsFilesystemLabel.localY + 1, 45, "logsFilesystem", filesystemList))

local confirmSettingsButton = baseSettingsPage:addChild(gui.button(140, 46, 15, 3, 0x2D2D2D, 0xEEEEEE, 0xEEEEEE, 0x2D2D2D, "Подтвердить"))
----------------------------------------------------------------------------
--[[
    АДМИНКА
]]
local adminPage = {}
local function loadAdminPage()
    require("lib.Antonesku.DataTableList")
    require("lib.Antonesku.DataTableForm")
    adminPage.page = wrapper:addChild(gui.container(1, 1, wrapper.width, wrapper.height))
    adminPage.page.hidden = true

    adminPage.header = adminPage.page:addChild(gui.container(1, 1, adminPage.page.width, 3))
    adminPage.header:addChild(gui.panel(1, 1, adminPage.header.width, adminPage.header.height, 0x2D2D2D))
    adminPage.headerLogo = adminPage.header:addChild(gui.label(1, 1, 20, adminPage.header.height, 0xF0F0F0, "Админ-панель"))
    adminPage.headerLogo:setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)

    adminPage.headerTabsPanel, adminPage.tabsArea = gui.tabs(
        adminPage.headerLogo.localX + adminPage.headerLogo.width + 10, 1, 80, adminPage.headerLogo.height,
        adminPage.header.localX, adminPage.header.localY + adminPage.header.height, adminPage.page.width, adminPage.page.height - adminPage.header.height,
        workspace
        )
    adminPage.backButton = adminPage.header:addChild(gui.button(145 + 1, 1, 15, 3, 0x2D2D2D, 0xFFFFFF, 0xFFFFFF, 0x2D2D2D, "🔙 На главную"))
    adminPage.header:addChild(adminPage.headerTabsPanel)
    adminPage.page:addChild(adminPage.tabsArea)
    ----------------------------------------------------------------------------
    adminPage.currencyTab = adminPage.headerTabsPanel:addTab("Валюта")
    adminPage.currencyTab.dataTableList = adminPage.currencyTab:addChild(gui.dataTableList(3, 2, 40, 45, currencyDataTable, "display_name", {gui.DATATABLE_CONTROL_PANEL_ADD_BUTTON, gui.DATATABLE_CONTROL_PANEL_DELETE_BUTTON}))
    adminPage.currencyTab.dataTableList:refill()

    adminPage.currencyTab.dataTableForm = adminPage.currencyTab:addChild(gui.dataTableForm(adminPage.currencyTab.dataTableList.localX + adminPage.currencyTab.dataTableList.width + 2, adminPage.currencyTab.dataTableList.localY, 54, 25, adminPage.currencyTab.dataTableList))
    adminPage.currencyTab.dataTableForm:addChild(gui.panel(1, 1, adminPage.currencyTab.dataTableForm.width, adminPage.currencyTab.dataTableForm.height, 0xE1E1E1))
    adminPage.currencyTab.dataTableForm:addLabelInput(3, 2, adminPage.currencyTab.dataTableForm.width - 4, "display_name", "Название валюты")
    adminPage.currencyTab.dataTableForm:addLabelInput(3, 7, adminPage.currencyTab.dataTableForm.width - 4, "unit", "Единица измерения")
    adminPage.currencyTab.dataTableForm:addLabelInput(3, 12, adminPage.currencyTab.dataTableForm.width - 4, "minecraft_name", "ID предмета")
    adminPage.currencyTab.dataTableForm:addLabelInput(3, 17, adminPage.currencyTab.dataTableForm.width - 4, "balance", "Текущий баланс")
    adminPage.currencyTab.dataTableForm:setSubmitButton(adminPage.currencyTab.dataTableForm.width - 16, adminPage.currencyTab.dataTableForm.height - 3, 15, 3, "Добавить")

    adminPage.currencyTab.dataTableList.scrolledList:setActiveItem(1)
    ----------------------------------------------------------------------------
    adminPage.itemsTab = adminPage.headerTabsPanel:addTab("Предметы")
    adminPage.itemsTab.dataTableList = adminPage.itemsTab:addChild(gui.dataTableList(3, 2, 40, 45, itemsInfoDataTable, "display_name"))
    adminPage.itemsTab.dataTableList:refill()

    adminPage.itemsTab.dataTableForm = adminPage.itemsTab:addChild(gui.dataTableForm(adminPage.currencyTab.dataTableList.localX + adminPage.currencyTab.dataTableList.width + 2, adminPage.currencyTab.dataTableList.localY, 90, 19, adminPage.itemsTab.dataTableList))
    adminPage.itemsTab.dataTableForm:addChild(gui.panel(1, 1, adminPage.itemsTab.dataTableForm.width, adminPage.itemsTab.dataTableForm.height, 0xE1E1E1))
    adminPage.itemsTab.itemInfoIdLabel = adminPage.itemsTab.dataTableForm:addChild(gui.label(4, 2, adminPage.itemsTab.dataTableForm.width - 4, 1, 0x2D2D2D, ""))
    adminPage.itemsTab.dataTableForm:addLabelInput(3, 4, adminPage.itemsTab.dataTableForm.width - 4, "display_name", "Отображаемое имя")
    adminPage.itemsTab.dataTableForm:addLabelInput(3, 9, adminPage.itemsTab.dataTableForm.width - 4, "img", "Изображение (Не используется)")
    ----------------------------------------------------------------------------
    --Шлак
    function adminPage.itemsTab.dataTableForm:addPriceForm(x, y, width, height)
        local priceForm = adminPage.itemsTab.dataTableForm:addChild(gui.container(x, y, width, height))
        priceForm.items = {}
        function priceForm:clear()
            if #self.items == 0 then
                return
            end
            self.items = {}
            self:removeChildren()
        end

        function priceForm:addItem(currencyId, currencyDisplayName, priceId, priceRow, itemInfoId)
            local price = gui.container(1, #self.items + 1, self.width, 1)

            local currencyLabel = price:addChild(gui.label(1, 1, unicode.len(currencyDisplayName), 1, 0x2D2D2D, currencyDisplayName .. ":"))
            local currencyInput = price:addChild(gui.input(currencyLabel.localX + currencyLabel.width + 1, 1, price.width - currencyLabel.width, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, tostring(priceRow and tostring(priceRow["price"]) or "")))

            currencyInput.onInputFinished = function()
                local isConverted, value = gui.convertValue(priceItemsDataTable.columns["price"].type, currencyInput.text)
                if isConverted then
                    if priceId then
                        if value == DataBase.NIL then
                            priceItemsDataTable:delete(priceId)
                            priceId = nil
                        else
                            priceItemsDataTable:update(priceId, {["price"] = value})
                        end
                    else
                        if not(value == DataBase.NIL) then
                            local id, row =  priceItemsDataTable:add({["currency_id"] = currencyId, ["info_item_id"] = itemInfoId, ["price"] = value})
                            priceId = id
                        end
                    end
                else
                    if priceId then
                        currencyInput.text = tostring(priceRow["price"])
                    else
                        currencyInput.text = ""
                    end
                end
            end

            table.insert(self.items, price)
            return self:addChild(price)
        end

        function priceForm:fill()
            local itemInfoId = adminPage.itemsTab.dataTableList.selectedItemId
            for id, row in pairs(currencyDataTable.data) do
                local queryDataTable = priceItemsDataTable:query(DataBase.SELECT, "row.currency_id == " .. tostring(id) .. " and row.info_item_id == \"" .. tostring(itemInfoId) .. "\"")
                local priceId, priceRow = next(queryDataTable.data)

                queryDataTable:destroy()
                self:addItem(id, row["display_name"] or ("ID:" .. tostring(id)), priceId, priceRow, itemInfoId)
            end
        end

        return self:addChild(priceForm)
    end
    
    adminPage.itemsTab.itemsPriceForm = adminPage.itemsTab.dataTableForm:addPriceForm(4, 14, 30, 5)
    adminPage.itemsTab.dataTableList.onItemSelected = function(index, id)
        adminPage.itemsTab.itemsPriceForm:clear()
        adminPage.itemsTab.itemsPriceForm:fill()
        adminPage.itemsTab.itemInfoIdLabel.text = id
    end
    
    adminPage.itemsTab.dataTableList.scrolledList:setActiveItem(1)
    ----------------------------------------------------------------------------
    adminPage.rareTab = adminPage.headerTabsPanel:addTab("Редкость")
    adminPage.rareTab.dataTableList = adminPage.rareTab:addChild(gui.dataTableList(3, 2, 40, 45, rareDataTable, "display_name", {gui.DATATABLE_CONTROL_PANEL_ADD_BUTTON, gui.DATATABLE_CONTROL_PANEL_DELETE_BUTTON}))
    adminPage.rareTab.dataTableList:refill()
    
    adminPage.rareTab.dataTableForm = adminPage.rareTab:addChild(gui.dataTableForm(adminPage.rareTab.dataTableList.localX + adminPage.rareTab.dataTableList.width + 2, adminPage.rareTab.dataTableList.localY, 80, 22, adminPage.rareTab.dataTableList))
    adminPage.rareTab.dataTableForm:addChild(gui.panel(1, 1, adminPage.rareTab.dataTableForm.width, adminPage.rareTab.dataTableForm.height, 0xE1E1E1))
    adminPage.rareTab.dataTableForm:addLabelInput(3, 2, adminPage.rareTab.dataTableForm.width - 4, "display_name", "Название")
    adminPage.rareTab.chanceInput = adminPage.rareTab.dataTableForm:addLabelInput(3, 7, math.modf((adminPage.rareTab.dataTableForm.width - 3) / 2) - 1, "chance", "Шанс выпадения, % (min - 0.01)")
    adminPage.rareTab.dataTableForm:addColorSelector(adminPage.rareTab.chanceInput.localX + adminPage.rareTab.chanceInput.width + 2, adminPage.rareTab.chanceInput.localY + 1, adminPage.rareTab.chanceInput.width, "color", "Цвет")
    adminPage.rareTab.rareMsgInput = adminPage.rareTab.dataTableForm:addLabelInput(3, 14, adminPage.rareTab.dataTableForm.width - 4, "msg", "Текст уведомления. [item] заменится на выпавший предмет")
    adminPage.rareTab.dataTableForm:setSubmitButton(adminPage.rareTab.dataTableForm.width - 16, adminPage.rareTab.dataTableForm.height - 3, 15, 3, "Добавить")
    
    adminPage.rareTab.dataTableForm:addSwitch(4, 12, 29, "is_big_win", "Включить уведомления:").switch.onValueChanged = function(columnName, value, changer)
        adminPage.rareTab.rareMsgInput.hidden = not(value)
    end
    
    adminPage.rareTab.dataTableList.scrolledList:setActiveItem(1)
    ----------------------------------------------------------------------------
    adminPage.caseTab = adminPage.headerTabsPanel:addTab("Кейсы")
    adminPage.caseTab.dataTableList = adminPage.caseTab:addChild(gui.dataTableList(3, 2, 40, 45, caseDataTable, "display_name", {gui.DATATABLE_CONTROL_PANEL_ADD_BUTTON, gui.DATATABLE_CONTROL_PANEL_DELETE_BUTTON}))
    adminPage.caseTab.dataTableList:refill()
    
    adminPage.caseTab.dataTableForm = adminPage.caseTab:addChild(gui.dataTableForm(adminPage.caseTab.dataTableList.localX + adminPage.caseTab.dataTableList.width + 2, adminPage.caseTab.dataTableList.localY, 114, 45, adminPage.caseTab.dataTableList))
    adminPage.caseTab.dataTableForm:addChild(gui.panel(1, 1, adminPage.caseTab.dataTableForm.width, adminPage.caseTab.dataTableForm.height, 0xE1E1E1))
    adminPage.caseTab.caseNameInput = adminPage.caseTab.dataTableForm:addLabelInput(3, 2, math.modf(adminPage.caseTab.dataTableForm.width / 2 - 3), "display_name", "Название")
    adminPage.caseTab.dataTableForm:addChild(gui.label(adminPage.caseTab.caseNameInput.localX + adminPage.caseTab.caseNameInput.width + 2, adminPage.caseTab.caseNameInput.localY , adminPage.caseTab.caseNameInput.width, 1, 0x2D2D2D, "Изображение * "))
    
    adminPage.caseTab.caseImgComboBox = adminPage.caseTab.dataTableForm:addComboBox(adminPage.caseTab.caseNameInput.localX + adminPage.caseTab.caseNameInput.width + 2, adminPage.caseTab.caseNameInput.localY + 1, adminPage.caseTab.caseNameInput.width, "img", {})
    --[override]
    function adminPage.caseTab.caseImgComboBox:fill()
        self.array = filesystem.list("home/img")
        for _, fileName in pairs(self.array) do
            local name, extension = unicode.sub(fileName, 1, #fileName - 4), unicode.sub(fileName, #fileName - 2, #fileName)
    
            if extension == "pic" then
                local item = self:addItem(name)
                item.value = name
            end
        end
        return true
    end
    adminPage.caseTab.caseImgComboBox:refill()
    
    adminPage.caseTab.dataTableForm:addLabelInput(3, 7, adminPage.caseTab.dataTableForm.width - 4, "description", "Описание")
    adminPage.caseTab.dataTableForm:addSwitch(4, 12, 35, "sell_items_available", "Включить продажу предметов:")
    adminPage.caseTab.dataTableForm:addSwitch(adminPage.caseTab.caseImgComboBox.localX, 12, 15, "hidden", "Скрыть:")
    adminPage.caseTab.dataTableForm:setSubmitButton(adminPage.caseTab.dataTableForm.width - 16, adminPage.caseTab.dataTableForm.height - 3, 15, 3, "Добавить")
    
    --Шлак x2
    function adminPage.caseTab.dataTableForm:addPriceForm(x, y, width, height)
        local priceForm = self:addChild(gui.container(x, y, width, height))
        priceForm.items = {}
        function priceForm:clear()
            if #self.items == 0 then
                return
            end
            self.items = {}
            self:removeChildren()
        end
    
        function priceForm:addItem(currencyId, currencyDisplayName, priceId, priceRow, caseId)
            currencyDisplayName = currencyDisplayName .. ":"
            local price = gui.container(1, #self.items + 1, self.width, 1)
    
            local currencyLabel = price:addChild(gui.label(1, 1, unicode.len(currencyDisplayName), 1, 0x2D2D2D, currencyDisplayName))
            local currencyInput = price:addChild(gui.input(currencyLabel.localX + currencyLabel.width, 1, price.width - currencyLabel.width, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, tostring(priceRow and tostring(priceRow["price"]) or "")))
    
            currencyInput.onInputFinished = function()
                local isConverted, value = gui.convertValue(priceCasesDataTable.columns["price"].type, currencyInput.text)
                if isConverted then
                    if priceId then
                        if value == DataBase.NIL then
                            priceCasesDataTable:delete(priceId)
                            priceId = nil
                        else
                            priceCasesDataTable:update(priceId, {["price"] = value})
                        end
                    else
                        if not(value == DataBase.NIL) then
                            local id, row =  priceCasesDataTable:add({["currency_id"] = currencyId, ["case_id"] = caseId, ["price"] = value})
                            priceId, priceRow = id, row
                        end
                    end
                else
                    if priceId then
                        currencyInput.text = tostring(priceRow["price"])
                    else
                        currencyInput.text = ""
                    end
                end
            end
            table.insert(self.items, price)
    
            return self:addChild(price)
        end
    
        function priceForm:fill()
            local caseId = adminPage.caseTab.dataTableList.selectedItemId
            for id, row in pairs(currencyDataTable.data) do
                local queryDataTable = priceCasesDataTable:query(DataBase.SELECT, "row.currency_id == " .. tostring(id) .. " and row.case_id == " .. tostring(caseId))
                local priceId, priceRow = next(queryDataTable.data)
                queryDataTable:destroy()
                self:addItem(id, row["display_name"] or ("ID:" .. tostring(id)), priceId, priceRow, caseId)
            end
        end
    
        return self:addChild(priceForm)
    end
    adminPage.caseTab.casePriceForm = adminPage.caseTab.dataTableForm:addPriceForm(4, 14, 30, 5)
    ----------------------------------------------------------------------------
    adminPage.caseTab.prizesCaseDataTableList = adminPage.caseTab.dataTableForm:addChild(gui.dataTableList(adminPage.caseTab.caseNameInput.localX, 20, adminPage.caseTab.caseNameInput.width, 24, prizesCaseDataTable, "display_name", {gui.DATATABLE_CONTROL_PANEL_ADD_BUTTON, gui.DATATABLE_CONTROL_PANEL_DELETE_BUTTON}))
    adminPage.caseTab.prizesCaseDataTableList.hidden = true
    
    adminPage.caseTab.prizesCaseDataTableForm = adminPage.caseTab.dataTableForm:addChild(gui.dataTableForm(adminPage.caseTab.caseImgComboBox.localX, adminPage.caseTab.prizesCaseDataTableList.localY, adminPage.caseTab.caseImgComboBox.width, adminPage.caseTab.prizesCaseDataTableList.height + 1, adminPage.caseTab.prizesCaseDataTableList))
    adminPage.caseTab.prizesCaseDataTableForm:addChild(gui.panel(1, 1, adminPage.caseTab.dataTableForm.width, adminPage.caseTab.dataTableForm.height, 0xd9d9d9))
    adminPage.caseTab.prizesCaseDataTableForm.hidden = true
    
    adminPage.caseTab.prizesCaseDataTableForm:addChild(gui.label(4, 2, adminPage.caseTab.prizesCaseDataTableForm.width - 4, 1, 0x2D2D2D, "Выберите предмет *"))
    adminPage.caseTab.prizeItemComboBox = adminPage.caseTab.prizesCaseDataTableForm:addComboBox(3, 3, adminPage.caseTab.prizesCaseDataTableForm.width - 4, "info_item_id", itemsInfoDataTable.data, "display_name")
    adminPage.caseTab.prizeItemComboBox:refill()
    
    adminPage.caseTab.prizesCaseDataTableForm:addChild(gui.label(4, 7, adminPage.caseTab.prizesCaseDataTableForm.width - 4, 1, 0x2D2D2D, "Выберите редкость *"))
    adminPage.caseTab.prizeRareComboBox = adminPage.caseTab.prizesCaseDataTableForm:addComboBox(3, 8, adminPage.caseTab.prizesCaseDataTableForm.width - 4, "rare_id", rareDataTable.data, "display_name")
    adminPage.caseTab.prizeRareComboBox:refill()
    
    adminPage.caseTab.prizeNameInput = adminPage.caseTab.prizesCaseDataTableForm:addLabelInput(3, 12, adminPage.caseTab.prizesCaseDataTableForm.width - 4, "display_name", "Отображаемое имя в кейсе")
    
    adminPage.caseTab.prizesCaseDataTableForm:addLabelInput(3, 17, adminPage.caseTab.prizesCaseDataTableForm.width - 4, "amount", "Количество выдачи")
    
    adminPage.caseTab.prizesCaseDataTableForm:setSubmitButton(adminPage.caseTab.prizesCaseDataTableForm.width - 16, adminPage.caseTab.prizesCaseDataTableForm.height - 3, 15, 3, "Добавить")
    
    adminPage.caseTab.prizeItemComboBox.onValueChanged = function(columnName, value, changer)
        if changer == gui.CHANGER_USER and adminPage.caseTab.prizesCaseDataTableList.selectedItemId then
            local currenctPrizeName = adminPage.caseTab.prizeNameInput.input:getValue()
            local itemDisplayName = itemsInfoDataTable.data[value]["display_name"]
    
            if prizesCaseDataTable.data[adminPage.caseTab.prizesCaseDataTableList.selectedItemId]["display_name"] == nil or prizesCaseDataTable.data[adminPage.caseTab.prizesCaseDataTableList.selectedItemId]["display_name"] == itemDisplayName or currenctPrizeName == DataBase.NIL then
                if prizesCaseDataTable.data[adminPage.caseTab.prizesCaseDataTableList.selectedItemId]["display_name"] == itemDisplayName then
                    prizesCaseDataTable:update(adminPage.caseTab.prizesCaseDataTableList.selectedItemId, {["display_name"] = DataBase.NIL})
                end
                adminPage.caseTab.prizeNameInput.input.text = itemDisplayName
                adminPage.caseTab.prizesCaseDataTableList:getItemByIndex(adminPage.caseTab.prizesCaseDataTableList.scrolledList.selectedItemIndex).text = itemDisplayName
            end
        end
    end
    
    adminPage.caseTab.prizeNameInput.input.onValueChanged = function(columnName, value, changer)
        if changer == gui.CHANGER_USER and adminPage.caseTab.prizesCaseDataTableList.selectedItemId then
            local itemInfoId = adminPage.caseTab.prizeItemComboBox:getValue()
            if itemInfoId ~= DataBase.NIL and itemInfoId ~= nil then
                local itemDisplayName = itemsInfoDataTable.data[itemInfoId]["display_name"]
                if itemDisplayName == value then
                    prizesCaseDataTable:update(adminPage.caseTab.prizesCaseDataTableList.selectedItemId, {["display_name"] = DataBase.NIL})
                    return
                end
                if value == DataBase.NIL or value == nil then
                    adminPage.caseTab.prizeNameInput.input.text = itemDisplayName
                    adminPage.caseTab.prizesCaseDataTableList:getItemByIndex(adminPage.caseTab.prizesCaseDataTableList.scrolledList.selectedItemIndex).text = itemDisplayName
                end
            end
        end
    end
    
    adminPage.caseTab.prizesCaseDataTableList.onItemSelected = function (index, id)
        if id then
            adminPage.caseTab.prizeItemComboBox.onValueChanged("info_item_id", adminPage.caseTab.prizeItemComboBox:getValue(), gui.CHANGER_USER)
        end
    end
    
    adminPage.caseTab.prizesCaseDataTableForm.onRowAdded = function (id, row)
        local item = adminPage.caseTab.prizesCaseDataTableList:getItemByIndex(adminPage.caseTab.prizesCaseDataTableList.scrolledList.selectedItemIndex)
        if item.text == "" or item.text == "nil" then
            local name = itemsInfoDataTable.data[row["info_item_id"]]["display_name"] or ""
            adminPage.caseTab.prizeNameInput.input.text = name
            item.text = name
        end
    end
    
    --[override]
    function adminPage.caseTab.prizesCaseDataTableList:fill()
        for id, row in pairs(self.queryDataTable.data) do
            self:addItemWithId(id, row[self.displayedColumn] or itemsInfoDataTable.data[row["info_item_id"]]["display_name"] or ("ID:" .. tostring(id)))
        end
    end
    
    adminPage.caseTab.dataTableList.onItemSelected = function(index, id)
        adminPage.caseTab.casePriceForm:clear()
        adminPage.caseTab.casePriceForm:fill()
    
        if id then
            adminPage.caseTab.prizesCaseDataTableForm.data["case_id"] = id
            if adminPage.caseTab.prizesCaseDataTableList.queryDataTable then
                adminPage.caseTab.prizesCaseDataTableList.queryDataTable:destroy()
            end
            adminPage.caseTab.prizesCaseDataTableList.hidden = false
    
            local prizesCaseQuertyDataTable = prizesCaseDataTable:query(DataBase.SELECT, "row.case_id == " .. tostring(id))
            adminPage.caseTab.prizesCaseDataTableList.queryDataTable = prizesCaseQuertyDataTable
            adminPage.caseTab.prizesCaseDataTableList:refill()
    
            adminPage.caseTab.casePriceForm.hidden = false
        else
            adminPage.caseTab.prizesCaseDataTableList.hidden = true
            adminPage.caseTab.prizesCaseDataTableForm.hidden = true
            adminPage.caseTab.casePriceForm.hidden = true
        end
    
        adminPage.caseTab.prizeItemComboBox.array = itemsInfoDataTable.data
    end
    
    adminPage.caseTab.dataTableForm.onRowAdded = function()
        adminPage.caseTab.dataTableList.scrolledList:setActiveItem(adminPage.caseTab.dataTableList.scrolledList.selectedItemIndex)
    end
    
    adminPage.caseTab.dataTableList.scrolledList:setActiveItem(1)
    adminPage.caseTab.prizesCaseDataTableList.scrolledList:setActiveItem(1) --Костыльный фикс ненажимаемого списка при первом запуске
    ----------------------------------------------------------------------------
    adminPage.caseTab.onTouch = function()
        adminPage.caseTab.prizeItemComboBox:refill()
        adminPage.caseTab.prizeRareComboBox:refill()
    end
    ----------------------------------------------------------------------------
    --[[
        НАСТРОЙКИ
    ]]
    adminPage.settingsTab = adminPage.headerTabsPanel:addTab("Настройки")
    
    adminPage.settingsTab:addChild(gui.label(4, 2, 50, 1, 0x2D2D2D, "Красный контроллер пополнения баланса"))
    adminPage.settingsTab:addChild(gui.settingsComboBox(3, 3, 50, "redControllerReplenishment", redControllerList))
    
    adminPage.settingsTab:addChild(gui.label(58, 2, 50, 1, 0x2D2D2D, "Транспозер пополнения баланса"))
    adminPage.settingsTab:addChild(gui.settingsComboBox(57, 3, 50, "transposerReplenishment", transposerList))
    
    adminPage.settingsTab:addChild(gui.label(4, 7, 50, 1, 0x2D2D2D, "Сторона извлечения предметов"))
    adminPage.settingsTab:addChild(gui.settingsComboBox(3, 8, 50, "sideInput", sides, settings.KEY_TABLE))
    
    adminPage.settingsTab:addChild(gui.label(58, 7, 50, 1, 0x2D2D2D, "Сторона для выдачи предметов"))
    adminPage.settingsTab:addChild(gui.settingsComboBox(57, 8, 50, "sideOutput", sides, settings.KEY_TABLE))
    
    adminPage.settingsTab:addChild(gui.label(4, 12, 50, 1, 0x2D2D2D, "Имя чатбокса"))
    adminPage.settingsTab:addChild(gui.settingsInput(3, 13, 50, "chatBoxName")).onValueChanged = function(identifier, value)
        if value and chatBox then
            value = value:gsub('&', '§')
            chatBox.setName(value or "Кейсы")
        end
    end
    
    adminPage.settingsTab:addChild(gui.label(58, 12, 50, 1, 0x2D2D2D, "Выбираемая валюта (требуется рестарт)"))
    adminPage.settingsTab:addChild(gui.settingsComboBox(57, 13, 50, "defaultCurrencyId", currencyDataTable.data, "display_name", settings.KEY_TABLE))
    
    adminPage.settingsTab:addChild(gui.label(4, 17, 50, 1, 0x2D2D2D, "Файловая система логов"))
    adminPage.settingsTab:addChild(gui.settingsComboBox(3, 18, 50, "logsFilesystem", filesystemList)).onValueChanged = function(identifier, value)
        log.setFilesystemAddress(value)
    end
    
    adminPage.settingsTab:addChild(gui.label(4, 22, 50, 1, 0x2D2D2D, "Имя изображения (Максимальное - 97x26)"))
    adminPage.settingsTab.imageNameInput = adminPage.settingsTab:addChild(gui.input(3, 23, 50, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, ""))
    adminPage.settingsTab:addChild(gui.label(58, 22, 50, 1, 0x2D2D2D, "Код изображения pastebin"))
    adminPage.settingsTab.imageUploadInput = adminPage.settingsTab:addChild(gui.input(57, 23, 35, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, ""))
    adminPage.settingsTab.imageUploadButton = adminPage.settingsTab:addChild(gui.button(adminPage.settingsTab.imageUploadInput.localX + adminPage.settingsTab.imageUploadInput.width, adminPage.settingsTab.imageUploadInput.localY, 15, 3, 0x2D2D2D, 0x9ACD32, 0x9ACD32, 0x2D2D2D, "Загрузить"))
    ----------------------------------------------------------------------------
    --[[
        ЛОГИ
    ]]
    adminPage.logsTab = adminPage.headerTabsPanel:addTab("Логи")
    --Уровень регулярок уже ПРЕВОСХОДИТ БОГОВ
    local logs_patterns = {
        "%d*:%d*:%d*", "dateTime", 0, 0,
        "Пользователь [^%s]*", "user", 13, 0,
        "кейс \".*\"", "caseName", 4, 0,
        "получил \".*\"", "prizeName", 7, 0,
        "Стоимость: .*%. В", "price", 11, 3,
        "Валюта: .*", "currency", 8, 0,
        "Редкость: .* %|", "rare", 10, 2,
        "Выдано", "given", 0, 0,
        "Продано", "sold", 0, 0,
        "Ошибка", "err", 0, 0,
        "x%d*", "amount", 0, 0
    }
    local logs_color_scheme = {
        dateTime = 0xE9967A,
        user = 0x9ACD32,
        caseName = 0xDA70D6,
        price = 0xFAC564,
        currency = 0x1E90FF,
        prizeName = 0xFFFF00,
        rare = 0xDA70D6,
        given = 0x7CFC00,
        sold = 0x7CFC00,
        amount = 0xFAC564,
        err = 0xB22222,
    
        background = 0x1E1E1E,
        text = 0xE1E1E1,
        strings = 0x99FF80,
        loops = 0xFFFF98,
        comments = 0x898989,
        boolean = 0xFFDB40,
        logic = 0xFFCC66,
        numbers = 0x66DBFF,
        functions = 0xFFCC66,
        compares = 0xFFCC66,
        lineNumbersBackground = 0x2D2D2D,
        lineNumbersText = 0xC3C3C3,
        scrollBarBackground = 0x2D2D2D,
        scrollBarForeground = 0x5A5A5A,
        selection = 0x4B4B4B,
        indentation = 0x2D2D2D
    }
    adminPage.logsTab.logsRefreshButton = adminPage.logsTab:addChild(gui.button(3, 2, 32, 3, 0x2D2D2D, 0x1E90FF, 0x1E90FF, 0x2D2D2D, "Обновить"))
    adminPage.logsTab.logsList = adminPage.logsTab:addChild(gui.scrolledList(3, 5, 32, 45, 3))
    
    adminPage.logsTab.logsViewer = adminPage.logsTab:addChild(gui.codeView(37, 2, 122, 45, 1, 1, 1, {}, {}, logs_patterns , logs_color_scheme, true, {}))
    ----------------------------------------------------------------------------
    adminPage.caseTab:active()
    adminPage.headerTabsPanel.selectedItem = 4
end
----------------------------------------------------------------------------
--[[
    ГЛАВНАЯ
]]
local mainPage = wrapper:addChild(gui.container(1, 1, wrapper.width, wrapper.height))
mainPage.hidden = true
mainPage:addChild(gui.panel(1, 1, mainPage.width, mainPage.height, 0xEEEEEE))

local sideBar = mainPage:addChild(gui.container(120, 1, workspace.width - 120 + 1, 50))
sideBar:addChild(gui.panel(1, 1, sideBar.width, sideBar.height, 0x2D2D2D))

sideBar:addChild(gui.label(1, 2, sideBar.width, 1, 0xFFFFFF, "Текущий пользователь")):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
local currentUserLabel = sideBar:addChild(gui.label(1, 3, sideBar.width, 1, 0xFF0000, "Никого :(")):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
--local sessionStopButton = sideBar:addChild(gui.roundedButton(13, currentUserLabel.localY + 1, 18, 1, 0x808080, 0x3a3a3a, 0x3a3a3a, 0x808080, "Завешить сессию"))

local currentUserLine = sideBar:addChild(gui.label(1, currentUserLabel.localY + 2, sideBar.width, 1, 0x696969, string.rep("⎯", 15))):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)

local balanceLabel = sideBar:addChild(gui.label(1, currentUserLine.localY + 2, sideBar.width, 1, 0xFFFFFF, "Баланс")):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
local balanceHelpLabel = sideBar:addChild(gui.label(25, balanceLabel.localY, 1, 1, 0xA9A9A9, "ⓘ"))

local currencyComboBox = sideBar:addChild(gui.comboBox(3, balanceLabel.localY + 2, 27, 1, 0x3a3a3a, 0xEEEEEE, 0x808080, 0x2D2D2D))
local sumBalanceLabel = sideBar:addChild(gui.label(currencyComboBox.localX + currencyComboBox.width + 1, currencyComboBox.localY, 10, 1, 0xFFD700, "пуфто:("))

local helpButton = sideBar:addChild(gui.button(23, 17, 17, 3, 0x3a3a3a, 0xFFFFFF, 0xFFFFFF, 0x3a3a3a, "Помощь"))

local helpContainer = mainPage:addChild(gui.container(1, 1, mainPage.width, mainPage.height))
helpContainer.hidden = true
helpContainer.panel = helpContainer:addChild(gui.panel(1, 1, helpContainer.width, helpContainer.height, gui.BACKGROUND_CONTAINER_PANEL_COLOR, 0.05))
helpContainer.panel.eventHandler = function(parentContainer, object, e1)
    if e1 == "touch" then
        helpContainer.hidden = true
        parentContainer:draw()
    end
end

local helpContainerContent = helpContainer:addChild(gui.container(25, 5, 110, 40))

local adminButton = sideBar:addChild(gui.button(3, 17, 17, 3, 0x3a3a3a, 0xFFFFFF, 0xFFFFFF, 0x3a3a3a, "Админка"))
adminButton.hidden = true
sideBar:addChild(gui.label(1, 22, sideBar.width, 1, 0xFFFFFF, "Последние большие выигрыши")):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
sideBar:addChild(gui.label(1, 21 + 2, sideBar.width, 1, 0x696969, string.rep("▁", 15))):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
local lastWinsContainer = sideBar:addChild(gui.container(2, 25, sideBar.width - 2, 24))

sideBar:addChild(gui.label(2, sideBar.height, sideBar.width, 1, 0x696969, "by " .. programInfo.developer .. " | " .. programInfo.year)):setAlignment(gui.ALIGNMENT_HORIZONTAL_LEFT, gui.ALIGNMENT_VERTICAL_CENTER)
sideBar:addChild(gui.label(1, sideBar.height, sideBar.width, 1, 0x696969, "v" .. programInfo.version)):setAlignment(gui.ALIGNMENT_HORIZONTAL_RIGHT, gui.ALIGNMENT_VERTICAL_CENTER)

local sliderX, sliderY = gui.getAlignmentCoordinates(
    1,
    1,
    mainPage.width - sideBar.width,
    mainPage.height,
    gui.ALIGNMENT_HORIZONTAL_CENTER,
    gui.ALIGNMENT_VERTICAL_CENTER,
    115,
    35
)
local slider = mainPage:addChild(gui.slider(math.floor(sliderX), math.floor(sliderY), 115, 40, 7, 16))
----------------------------------------------------------------------------
--[[
    КЕЙС
]]
local casePage = wrapper:addChild(gui.container(1, 1, wrapper.width, wrapper.height))
casePage:addChild(gui.panel(1, 1, casePage.width, casePage.height, 0xEEEEEE))
casePage.hidden = true

local prizesListLabel = casePage:addChild(gui.label(2, 31, 50, 1, 0x2D2D2D, "Список призов"))
prizesListLabel:setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
casePage:addChild(gui.label(prizesListLabel.localX, prizesListLabel.localY + 1, prizesListLabel.width, 1, 0xE1E1E1, string.rep('⎯', 8))):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
local prizeList = casePage:addChild(gui.prizesList(prizesListLabel.localX, prizesListLabel.localY + 2, prizesListLabel.width, 17))

local historyLabel = casePage:addChild(gui.label(110, prizesListLabel.localY, 50, 1, 0x2D2D2D, "История"))
historyLabel:setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
casePage:addChild(gui.label(historyLabel.localX, historyLabel.localY + 1, historyLabel.width, 1, 0xE1E1E1, string.rep('⎯', 5))):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
local historyList = casePage:addChild(gui.prizesList(historyLabel.localX, historyLabel.localY + 2, historyLabel.width, 17))

local caseOpenContainerWidth, caseOpenContainerHeight = image.getWidth(cacheImages.explosionFrames[1]), image.getHeight(cacheImages.explosionFrames[1])
local caseOpenContainerX, caseOpenContainerY = gui.getAlignmentCoordinates(
    1,
    1,
    casePage.width,
    caseOpenContainerHeight,
    gui.ALIGNMENT_HORIZONTAL_CENTER,
    gui.ALIGNMENT_VERTICAL_TOP,
    caseOpenContainerWidth,
    caseOpenContainerHeight
)

local casePrizeX, casePrizeY = gui.getAlignmentCoordinates(
    caseOpenContainerX,
    caseOpenContainerY,
    caseOpenContainerWidth,
    caseOpenContainerHeight,
    gui.ALIGNMENT_HORIZONTAL_CENTER,
    gui.ALIGNMENT_VERTICAL_CENTER,
    50,
    6
)
local casePrize = casePage:addChild(gui.prizeCard(math.floor(casePrizeX), math.floor(casePrizeY) + 1, 50))

local caseOpenContainer = casePage:addChild(gui.container(caseOpenContainerX, 2, caseOpenContainerWidth, caseOpenContainerHeight))
caseOpenContainer.hidden = true
local caseOpenImage = caseOpenContainer:addChild(gui.image(1, 1, cacheImages.explosionFrames[1]))

local caseOpenX, _ = gui.getAlignmentCoordinates(
    caseOpenContainer.localX,
    1,
    caseOpenContainer.width,
    1,
    gui.ALIGNMENT_HORIZONTAL_CENTER,
    gui.ALIGNMENT_VERTICAL_TOP,
    20,
    1
)

local caseOpenButton = casePage:addChild(gui.button(caseOpenX, caseOpenContainer.localY + caseOpenContainer.height + 2, 20, 3, 0x2D2D2D, 0xEEEEEE, 0xEEEEEE, 0x2D2D2D, "Открыть"))

local caseAnimationSwitch = casePage:addChild(gui.switchAndLabel(2, caseOpenButton.localY + 1, 18, 8, 0x66DB80, 0xDCDCDC, 0xA9A9A9, 0x696969, "Анимация:", true))
local caseAutoOpenSwitch = casePage:addChild(gui.switchAndLabel(caseAnimationSwitch.localX + caseAnimationSwitch.width + 4, caseOpenButton.localY + 1, 24, 8, 0x66DB80, 0xDCDCDC, 0xA9A9A9, 0x696969, "Авто-открытие:", false))

local caseBackButton = casePage:addChild(gui.roundedButton(2, 1, 15, 3, 0xE1E1E1, 0x2D2D2D, 0x2D2D2D, 0xE1E1E1, "🔙 На главную"))

local caseBalanceX, _ = gui.getAlignmentCoordinates(
    1,
    1,
    casePage.width,
    1,
    gui.ALIGNMENT_HORIZONTAL_CENTER,
    gui.ALIGNMENT_VERTICAL_CENTER,
    30,
    1
)

local caseBalance = casePage:addChild(gui.container(caseBalanceX, 31, 30, 6))

local caseBalanceLabel = caseBalance:addChild(gui.label(1, 1, caseBalance.width, 1, 0x2D2D2D, "Состояние счета")):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_TOP)

caseBalance:addChild(gui.label(1, 2, caseBalanceLabel.width, 1, 0xE1E1E1, string.rep('⎯', 9))):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)

caseBalance:addChild(gui.label(1, 4, 7, 1, 0x696969, "Валюта:"))
caseBalance:addChild(gui.label(1, 5, 7, 1, 0x696969, "Баланс:"))
local caseBalanceCurrencyNameLabel = caseBalance:addChild(gui.label(9, 4, caseBalance.width - 9, 1, 0x2D2D2D, ""))
local caseBalanceCurrencyBalanceLabel = caseBalance:addChild(gui.label(9, 5, caseBalance.width - 9, 1, 0xFFA500, ""))

local caseInfo = casePage:addChild(gui.container(caseBackButton.localX, caseBackButton.localY + caseBackButton.height + 1, 30, 4))
local caseInfoLabel = caseInfo:addChild(gui.label(1, 1, caseInfo.width, 1, 0x2D2D2D, "Информация"))
caseInfo:addChild(gui.label(1, 2, caseInfoLabel.width, 1, 0xE1E1E1, string.rep('⎯', 8)))
caseInfo:addChild(gui.label(1, 3, 7, 1, 0x696969, "Кейс:"))
caseInfo:addChild(gui.label(1, 4, 7, 1, 0x696969, "Цена:"))
local caseInfoName = caseInfo:addChild(gui.label(7, 3, caseBalance.width - 6, 1, 0x2D2D2D, ""))
local caseInfoPrice = caseInfo:addChild(gui.label(7, 4, caseBalance.width - 6, 1, 0xFFA500, ""))

local sellPrizeContainer = casePage:addChild(gui.container(casePrize.localX, casePrize.localY + 8, casePrize.width, 3))
local sellPrizeButton = sellPrizeContainer:addChild(gui.roundedButton(5, 1, 17, 3, 0x3a3a3a, 0xEEEEEE, 0xEEEEEE, 0x3a3a3a, "Продать" .. string.rep(' ', 6)))
local sellPrizePriceLabel = sellPrizeContainer:addChild(gui.label(sellPrizeButton.localX + sellPrizeButton.width - 9, sellPrizeButton.localY + 1, 9, 1, 0xFAC564, "")):setAlignment(gui.ALIGNMENT_HORIZONTAL_CENTER, gui.ALIGNMENT_VERTICAL_CENTER)
sellPrizePriceLabel.eventHandler = function(...)
    local args = {...}
    local eventName = args[3]
    if eventName == "touch" and (not sellPrizeButton.animated or not sellPrizeButton.animationStarted)then
        sellPrizeButton:press(...)
    end
end
local takePrizeButton = sellPrizeContainer:addChild(gui.roundedButton(sellPrizeContainer.width - 5 - 17, 1, 17, 3, 0x3a3a3a, 0xEEEEEE, 0xEEEEEE, 0x3a3a3a, "Забрать"))
sellPrizeContainer.hidden = true

local defaultActionCaseLabel = casePage:addChild(gui.label(caseAutoOpenSwitch.localX, caseAnimationSwitch.localY + 1, 9, 1, 0x696969, "Действие:"))
local defaultActionCaseComboBox = casePage:addChild(gui.comboBox(caseAutoOpenSwitch.localX + caseAutoOpenSwitch.width - caseAutoOpenSwitch.switch.width - 2, defaultActionCaseLabel.localY, 10, 1, 0xEEEEEE, 0x2D2D2D, 0xEEEEEE, 0x888888))
defaultActionCaseComboBox:addItem("Забрать")
defaultActionCaseComboBox:addItem("Продать")
----------------------------------------------------------------------------
--[[
    ЛОГИКА
]]
local function isAdmin(nickname)
    for _, adminNickname in ipairs(admins) do
        if nickname == adminNickname then
            return true
        end
    end
    return false
end

local function removeAllPCUsers()
    for _, userNickname in ipairs(table.pack(computer.users())) do
        computer.removeUser(userNickname)
    end
end
----------------------------------------------------------------------------
local function processTransposers()
    items = {}
    for address, _ in component.list("transposer") do
        if address ~= settings.data.transposerReplenishment then
            local transposer = component.proxy(address)
            local sizeInventory = transposer.getInventorySize(settings.data.sideInput)
            if sizeInventory then
                for i = 1, sizeInventory do
                    local item = transposer.getStackInSlot(settings.data.sideInput, i)
                    if item then
                        local id = item.name .. "|" .. item.label
                        items[id] = {name = item.name, label = item.label, transposerAddress = address, slot = i}

                        if not(itemsInfoDataTable.data[id]) then
                            itemsInfoDataTable:add({
                                ["display_name"] = item.label
                            }, id)
                        end
                    end
                end
            end
        end
    end
end
----------------------------------------------------------------------------
local function addLastWin(prize, user)
    local lastWins = filesystem.readTable("home/last-wins.txt") or {}
    table.insert(lastWins, 1, {name = prize.name, rareColor = prize.color, amount = prize.amount, nickname = user})
    if #lastWins == 6 then
        table.remove(lastWins, 6)
    end
    filesystem.writeTable("home/last-wins.txt", lastWins)
end
----------------------------------------------------------------------------
local session = {
    id = nil, -- ID таймера, кхм, сессии
    duration = 20, -- Продолжительность сессии в секундах
    user = nil,

    onStarted = nil,
    onStoped = nil
}

function session:stop()
    if self.id then
        removeAllPCUsers()
        event.cancel(self.id)
        self.user = nil
        self.id = nil
    end

    if self.onStoped then
        self.onStoped()
    end
end

function session:start(nickname)
    self.id = event.timer(self.duration, function() self:stop() end)
    self.user = nickname
    computer.addUser(self.user)

    if self.onStarted then
        self.onStarted(self.user)
    end
end

function session:refresh()
    if self.id then
        event.cancel(self.id)
        self.id = event.timer(self.duration, function() self:stop() end)
    end
end
----------------------------------------------------------------------------
local currency = {
    id = nil,
    name = nil,
    balance = nil,
    unit = nil,
    --minecraftName = nil,

    onChanged = nil
}

function currency:set(newId)
    local row = currencyDataTable:get(newId)
    if row then
        self.id = newId
        self.name = row["display_name"] or ("ID:" .. tostring(self.id))
        self.unit = row["unit"] or ""
        self.balance = row["balance"]
        --self.minecraftName = row["minecraft_name"]
        if self.onChanged then
            self.onChanged(self.id)
        end
        return true
    end
end
----------------------------------------------------------------------------
local case = {
    id = nil,
    name = nil,
    sellItemsAvailable = nil,
    defaultAction = nil,
    price = nil,
    prize = nil,
    prizes = nil,
    rareList = nil,
    autoOpening = false,
    autoOpeningStarted = false,
    animation = true,

    onStarted = nil,
    onStoped = nil,
    onEnded = nil
}

--TODO: Переделать. По возможности
function case:set(newId)
    if not(newId) then
        return
    else
        self.id = newId
    end

    self.name = caseDataTable:get(self.id)["display_name"] or ("ID:" .. tostring(self.id))
    self.sellItemsAvailable = caseDataTable:get(self.id)["sell_items_available"]

    for _, casePriceRow in pairs(priceCasesDataTable.data) do
        if casePriceRow["case_id"] == self.id and casePriceRow["currency_id"] == currency.id then
            self.price = casePriceRow["price"]
            break
        end
    end
    ------
    self.prizes, self.rareList = {}, {}

    for prizeId, prizeRow in pairs(prizesCaseDataTable.data) do
        if prizeRow["case_id"] == self.id then
            self.prizes[prizeRow["rare_id"]] = self.prizes[prizeRow["rare_id"]] or {}

            local prize = {
                name = prizeRow["display_name"] or itemsInfoDataTable:get(prizeRow["info_item_id"])["display_name"] or tostring(prizeRow["info_item_id"]),
                amount = prizeRow["amount"],
                rareName = rareDataTable:get(prizeRow["rare_id"])["display_name"] or ("ID:" .. tostring(prizeRow["rare_id"])),
                color = rareDataTable:get(prizeRow["rare_id"])["color"],
                id = prizeRow["info_item_id"]
            }

            if self.sellItemsAvailable then
                for priceId, priceRow in pairs(priceItemsDataTable.data) do
                    if prizeRow["info_item_id"] == priceRow["info_item_id"] and priceRow["currency_id"] == currency.id then
                        prize.price = priceRow["price"]
                        break
                    end
                end
            end

            table.insert(self.prizes[prizeRow["rare_id"]], prize)
        end
    end

    for rareId, prize in pairs(self.prizes) do
        table.sort(prize, function(a, b) return unicode.len(a.name) > unicode.len(b.name) end)
        table.insert(self.rareList, {id = rareId, chance = rareDataTable:get(rareId)["chance"]})
    end

    table.sort(self.rareList, function(a, b) return a.chance < b.chance end)

    if #self.rareList > 0 then
        self.rareList[1].range = {min = 1, max = self.rareList[1].chance * MULTIPLIER_CHANCE}
        if #self.rareList > 1 then
            for i = 2, #self.rareList do
                self.rareList[i].range = {
                    min = self.rareList[i-1].range.max + 1,
                    max = self.rareList[i-1].range.max + self.rareList[i].chance * MULTIPLIER_CHANCE
                }
            end
        end
    end
end

function case:randomizePrize()
    local rand = math.random(1, self.rareList[#self.rareList].range.max)
    local randomRare
    for _, rare in pairs(self.rareList) do
        if rand >= rare.range.min and rand <= rare.range.max then
            randomRare = rare
            break
        end
    end

    local prize = self.prizes[randomRare.id][math.random(1, #self.prizes[randomRare.id])]
    prize.rareId = randomRare.id
    return prize
end

function case:onOpeningEnded(status, err)
    local logMsg = "Пользователь " .. (session.user or "Ливнувший_черт") .. " получил \"" .. self.prize.name .. "\" x" .. tostring(self.prize.amount) .. " | " .. tostring(status) .. (err and (": " .. err) or "")
    log.write(logMsg)

    if self.onEnded then
        self.onEnded(self.prize, status, err)
    end
    self.prize = nil
end

function case:endOpening(status, err)
    if case.autoOpeningStarted then
        caseOpenContainer:addAnimation(
            function(animation)

            end,
            function(animation)
                animation:remove()
                self:onOpeningEnded(status, err)

                if self.autoOpeningStarted then
                    self:open()
                end
            end
        ):start(0.5)
    else
        self:onOpeningEnded(status, err)
    end
end

function case:sellPrize()
    currencyDataTable:update(currency.id, {["balance"] = currencyDataTable:get(currency.id)["balance"] + self.prize.price})
    self:endOpening("Продано")
end

local function givePrize(prize)
    local item = items[prize.id]
    if item then
        local transposer = component.proxy(item.transposerAddress)
        local itemInInventory = transposer.getStackInSlot(settings.data.sideInput, item.slot)
        if not(itemInInventory) then
            return false, "Предмет был убран или закончился"
        end
        if itemInInventory.size < prize.amount then
            return false, "Недостаточно предмета в инвентаре"
        end

        local function transferPrize(givedAmount)
            givedAmount = (givedAmount and givedAmount + transposer.transferItem(settings.data.sideInput, settings.data.sideOutput, prize.amount, item.slot, 1)) or (transposer.transferItem(settings.data.sideInput, settings.data.sideOutput, prize.amount, item.slot, 1))
            if givedAmount < prize.amount then
                return false, givedAmount
            end
            return true
        end

        local isTransferAll, givedAmount = transferPrize()
        if isTransferAll then
            return true
        else
            os.sleep(0.2)
            local isTransferAll2, givedAmount = transferPrize(givedAmount)
            if isTransferAll2 then
                return true
            else
                return false, "Недоступен слот выдачи. Не выдано " .. tostring(prize.amount - givedAmount)
            end
        end
    else
        return false, "Предмет не найден"
    end
end

function case:givePrize()
    local isGived, err = givePrize(self.prize)
    if isGived then
        self:endOpening("Выдано")
    else
        self:endOpening("Ошибка", err)
    end
end

function case:showPrizeActions()
    if self.sellItemsAvailable and self.prize.price then
        sellPrizeContainer.hidden = false
        sellPrizePriceLabel.text = tostring(self.prize.price) .. currency.unit
    else
        self:givePrize()
    end
end

function case:prizePefrorm()
    session:refresh()
    if not(self.animation) then
        casePrize:change(self.prize.name, self.prize.rareName, self.prize.color, self.prize.amount)
    end

    if rareDataTable:get(self.prize.rareId)["is_big_win"] then
        addLastWin(self.prize, session.user)

        local msg = rareDataTable:get(self.prize.rareId)["msg"]
        if chatBox and msg then
            msg = msg:gsub('&', '§')
            msg = msg:gsub("%[item%]", self.prize.name)
            msg = msg:gsub("%[user%]", session.user)
            chatBox.say(msg)
        end

        if self.sellItemsAvailable then
            if self.autoOpeningStarted then
                self:stop()
            end
            self:showPrizeActions()
        else
            self:givePrize()
        end
    else
        if self.sellItemsAvailable then
            if self.autoOpeningStarted then
                if defaultActionCaseComboBox.selectedItem == 1 then
                    self:givePrize()
                elseif defaultActionCaseComboBox.selectedItem == 2 then
                    self:sellPrize()
                end
            else
                self:showPrizeActions()
            end
        else
            self:givePrize()
        end
    end
end

function case:startAnimation()
    local currentFrame, count = 1, 0
    local caseOpenAnimation = caseOpenContainer:addAnimation(
        function(animation)
            caseOpenContainer.hidden = false
            if currentFrame > #cacheImages.explosionFrames then
                return
            end
            if count >= (currentFrame - 1) * 4 and count < currentFrame * 4 then
                caseOpenImage.image = cacheImages.explosionFrames[currentFrame]
                currentFrame = currentFrame + 1
            end

            if currentFrame == 3 then
                casePrize.hidden = true
            end

            if currentFrame == 6 then
                casePrize:moveToFront()
                casePrize.hidden = false
                casePrize:change(self.prize.name, self.prize.rareName, self.prize.color, self.prize.amount)
            end

            count = count + 1
        end,
        function(animation)
            caseOpenContainer:moveToFront()
            caseOpenContainer.hidden = true
            caseOpenImage.image = cacheImages.explosionFrames[1]
            animation:remove()

            self:prizePefrorm()
        end
    )
    caseOpenAnimation:start(0.8)
end

function case:stop()
    self.autoOpeningStarted = false
    if self.onStoped then
        self.onStoped()
    end
end

function case:open()
    if currencyDataTable.data[currency.id]["balance"] < case.price then
        chatBox.say("§cНедостаточно средств§6§o, милашка:3")

        if self.autoOpeningStarted then
            self:stop()
        end

        if self.onEnded then
            self.onEnded()
        end

        return
    else
        currencyDataTable:update(currency.id, {["balance"] = currencyDataTable:get(currency.id)["balance"] - case.price})
        log.write("Пользователь " .. session.user .. " купил кейс \"" .. case.name .. "\". Стоимость: " .. tostring(case.price) .. currency.unit .. ". Валюта: " .. currency.name)
    end

    if self.onStarted then
        self.onStarted()
    end

    self.prize = case:randomizePrize()

    if self.autoOpening then
        self.autoOpeningStarted = true
    end

    if case.animation then
        self:startAnimation()
    else
        self:prizePefrorm()
    end
end
----------------------------------------------------------------------------
--[[
    ГЛАВНАЯ. МИШУРА
]]
function currentUserLabel:changeUser(nickname)
    if nickname then
        self.text = nickname
        self.colors.text = 0x9ACD32
    else
        self.text = "Никого :("
        self.colors.text = 0xFF0000
    end
end
----------------------------------------------------------------------------
function sumBalanceLabel:refresh()
    if currency.id then
        sumBalanceLabel.text = tostring(currency.balance) .. currency.unit
    else
        sumBalanceLabel.text = "пуфто:("
    end
end

function currencyComboBox:refill()
    self:clear()
    for id, row in pairs(currencyDataTable.data) do
        local item = self:addItem(row["display_name"] or ("ID:" .. tostring(id)))
        item.id = id
    end
end

function currencyComboBox:setActive(id)
    for i = 1, self:count() do
        local item = self:getItem(i)
        if item.id == id then
            self.selectedItem = i
            return
        end
    end
end

currencyComboBox.onItemSelected = function()
    local id = currencyComboBox:getItem(currencyComboBox.selectedItem).id
    currency:set(id)
end
----------------------------------------------------------------------------
local qrCodeMatrix = {
    1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1,
    1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1,
    1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1,
    1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1,
    1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1,
    1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1,
    1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1,
    1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0,
    0, 1, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 1,
    1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0,
    0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0,
    0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0,
    0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0,
    0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0,
    0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 0,
    1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1,
    0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0,
    0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0,
    1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1,
    1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0,
    1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1,
    1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0,
    1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1,
    1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0
}

do
    helpContainerContent:addChild(gui.label(1, 1, helpContainerContent.width, 1, 0xFAC564, "Пополнения баланса"))
    helpContainerContent:addChild(gui.label(1, 2, helpContainerContent.width, 1, 0x3a3a3a, string.rep("⎯", 15)))
    helpContainerContent:addChild(gui.label(1, 3, helpContainerContent.width, 1, 0xEEEEEE, "Для пополнения баланса положите выбранный предмет в сундук"))
    helpContainerContent:addChild(gui.label(1, 4, helpContainerContent.width, 1, 0xB22222, "Примечание!"))
    helpContainerContent:addChild(gui.label(13, 4, helpContainerContent.width, 1, 0xEEEEEE, "Баланс является общим"))

    helpContainerContent:addChild(gui.label(1, 7, helpContainerContent.width, 1, 0xFAC564, "Как играть"))
    helpContainerContent:addChild(gui.label(1, 8, helpContainerContent.width, 1, 0x3a3a3a, string.rep("⎯", 7)))
    helpContainerContent:addChild(gui.label(1, 9, helpContainerContent.width, 1, 0xEEEEEE, "1. Выберите одну из доступных валют"))
    helpContainerContent:addChild(gui.label(1, 10, helpContainerContent.width, 1, 0xEEEEEE, "2. Пополните баланс"))
    helpContainerContent:addChild(gui.label(1, 11, helpContainerContent.width, 1, 0xEEEEEE, "3. Выберите понравившийся кейс"))
    helpContainerContent:addChild(gui.label(1, 12, helpContainerContent.width, 1, 0xEEEEEE, "4. Выигрывайте!"))

    helpContainerContent:addChild(gui.label(1, 15, helpContainerContent.width, 1, 0xFAC564, "Сессия"))
    helpContainerContent:addChild(gui.label(1, 16, helpContainerContent.width, 1, 0x3a3a3a, string.rep("⎯", 4)))
    helpContainerContent:addChild(gui.label(1, 17, helpContainerContent.width, 1, 0xEEEEEE, "После взаимодействия с программой Вы становитесь единственным, кто может ей пользоваться"))
    helpContainerContent:addChild(gui.label(1, 18, helpContainerContent.width, 1, 0xB22222, "Примечание!"))
    helpContainerContent:addChild(gui.label(13, 18, helpContainerContent.width, 1, 0xEEEEEE, "Сессия автоматически завершается при бездействии сроком в " .. tostring(session.duration) .. "с."))

    helpContainerContent:addChild(gui.label(1, 21, helpContainerContent.width, 1, 0xFAC564, "Ошибки / Пожелания"))
    helpContainerContent:addChild(gui.label(1, 22, helpContainerContent.width, 1, 0x3a3a3a, string.rep("⎯", 15)))
    helpContainerContent:addChild(gui.label(1, 23, helpContainerContent.width, 1, 0xEEEEEE, "Если возникла ошибка или баг, а может у вас есть интересная идея пишите владельцу варпа"))
    helpContainerContent:addChild(gui.label(1, 24, helpContainerContent.width, 1, 0xEEEEEE, "Все исправим, вернем и учтем."))

    helpContainerContent:addChild(gui.label(1, 27, helpContainerContent.width, 1, 0xFAC564, "Видео-инструкция"))
    helpContainerContent:addChild(gui.label(1, 28, helpContainerContent.width, 1, 0x3a3a3a, string.rep("⎯", 12)))

    local qrCodeContainer = helpContainerContent:addChild(gui.container(1, 29, 17, 9))
    qrCodeContainer:addChild(gui.panel(1, 1, qrCodeContainer.width, qrCodeContainer.height, 0xFFFFFF))
    local qrCodeBrailleCanvas = qrCodeContainer:addChild(gui.brailleCanvas(2, 2, 16, 8))

    for i = 1, 29 do
        for j = 1, 29 do
            if qrCodeMatrix[(i - 1) * 29 + j] == 1 then
                qrCodeBrailleCanvas:set(j, i, true, 0x000000)
            end
        end
    end

    helpContainer:moveToFront()
end

helpButton.onTouch = function()
    helpContainer.hidden = false
    mainPage:draw()
end
----------------------------------------------------------------------------
local function lastWinItem(x, y, width, name, amount, color, nickname)
    local lastWin = gui.object(x, y, width, 3)
    lastWin.name = name
    lastWin.amount = amount
    lastWin.color = color
    lastWin.nickname = nickname

    lastWin.textMargin = 2

    lastWin.draw = function(object)
        for i = 0, object.height - 1 do
            local y = object.y + i
            local background, foreground = screen.get(object.x, y)
            screen.set(object.x, y, background, object.color, '▐')
        end
        screen.drawText(object.x + object.textMargin, object.y, 0xEEEEEE, "❖ " .. object.name .. " | x" .. tostring(object.amount))
        screen.drawText(object.x + object.textMargin, object.y + 1, 0x4b4b4b, string.rep("⎯", 13))
        screen.drawText(object.x + object.textMargin, object.y + 2, 0xEEEEEE, object.nickname or "")
    end
    return lastWin
end

function lastWinsContainer:refill()
    local lastWins = filesystem.readTable("home/last-wins.txt") or {}
    lastWinsContainer:removeChildren()
    for i, win in ipairs(lastWins) do
        self:addChild(lastWinItem(1, 1 + (i - 1) * (3 + 2), lastWinsContainer.width, win.name, win.amount, win.rareColor, win.nickname))
    end
end
----------------------------------------------------------------------------
--[[
    КЕЙС. МИШУРА
]]
function caseBalanceCurrencyNameLabel:refresh()
    self.text = currency.name
end

function caseBalanceCurrencyBalanceLabel:refresh()
    self.text = tostring(currency.balance) .. currency.unit
end
----------------------------------------------------------------------------
caseAnimationSwitch.switch.onStateChanged = function(state)
    case.animation = state
end

caseAutoOpenSwitch.switch.onStateChanged = function(state)
    case.autoOpening = state
    if case.sellItemsAvailable and state then
        defaultActionCaseLabel.hidden = false
        defaultActionCaseComboBox.hidden = false
    else
        defaultActionCaseLabel.hidden = true
        defaultActionCaseComboBox.hidden = true
    end
end
----------------------------------------------------------------------------
function prizeList:refill()
    self:clear()

    for _, rare in ipairs(case.rareList) do
        for _, prize in ipairs(case.prizes[rare.id]) do
            self:addItem(prize.name, prize.color)
        end
    end
end
----------------------------------------------------------------------------
--? Перенести в разметку
caseOpenButton.STYLE_DEFAULT_ACTIVE = 1
caseOpenButton.STYLE_DEFAULT_DISABLE = 2
caseOpenButton.STYLE_STOP = 3

local caseOpenSetStyleFunctions = {
    [caseOpenButton.STYLE_DEFAULT_ACTIVE] = function()
        caseOpenButton.disabled = false
        caseOpenButton.text = "Октрыть"
        caseOpenButton.colors.default.background = 0x2D2D2D
        caseOpenButton.colors.default.text = 0xEEEEEE
        caseOpenButton.colors.pressed.background = 0xEEEEEE
        caseOpenButton.colors.pressed.text = 0x2D2D2D
    end,
    [caseOpenButton.STYLE_DEFAULT_DISABLE] = function()
        caseOpenButton.disabled = true
        caseOpenButton.text = "Октрыть"
        caseOpenButton.colors.default.background = 0x2D2D2D
        caseOpenButton.colors.default.text = 0xEEEEEE
        caseOpenButton.colors.pressed.background = 0xEEEEEE
        caseOpenButton.colors.pressed.text = 0x2D2D2D
    end,
    [caseOpenButton.STYLE_STOP] = function()
        caseOpenButton.disabled = false
        caseOpenButton.text = " Стоп"
        caseOpenButton.colors.default.background = 0xFF0000
        caseOpenButton.colors.default.text = 0xEEEEEE
        caseOpenButton.colors.pressed.background = 0xEEEEEE
        caseOpenButton.colors.pressed.text = 0xFF0000
    end
}

function caseOpenButton:setStyle(style)
    caseOpenSetStyleFunctions[style]()
end

caseOpenButton.onTouch = function() --? Если включить свитчи анимации и т.д., нужно переделать на onSomething
    if case.autoOpeningStarted then
        case:stop()
    else
        case:open()
    end
end

sellPrizeButton.onTouch = function()
    if case.prize then
        case:sellPrize()
    end
    sellPrizeContainer.hidden = true
end

takePrizeButton.onTouch = function()
    if case.prize then
        case:givePrize()
    end
    sellPrizeContainer.hidden = true
end
----------------------------------------------------------------------------
function caseInfoName:refresh()
    caseInfoName.text = case.name
end

function caseInfoPrice:refresh()
    caseInfoPrice.text = tostring(case.price) .. currency.unit
end
----------------------------------------------------------------------------
--[[
    АДМИНКА. НАСТРОЙКИ. МИШУРА. ФОНАРЬ. АПТЕКА.
]]
local function loadAdminPageLogic()
    --TODO: Сделать более "аккуратным"
    function adminPage.logsTab.logsViewer:scroll(direction)
        if direction > 0 then
            if adminPage.logsTab.logsViewer.fromLine - 1 >= 1 then
                adminPage.logsTab.logsViewer.fromLine = adminPage.logsTab.logsViewer.fromLine - 4
            end
        else
            if adminPage.logsTab.logsViewer.fromLine + 1 <= #adminPage.logsTab.logsViewer.lines - adminPage.logsTab.logsViewer.height + 1 then
                adminPage.logsTab.logsViewer.fromLine = adminPage.logsTab.logsViewer.fromLine + 4
            end
        end
    end

    adminPage.logsTab.logsViewer.eventHandler = function(workspace, object, eventName, ...)
        local args = {...}
        if eventName == "scroll" then
            local direction = args[4]
            adminPage.logsTab.logsViewer:scroll(direction)
            workspace:draw()
        elseif eventName == "key_down" and args[3] == 208 then
            adminPage.logsTab.logsViewer:scroll(-1)
            workspace:draw()
        elseif eventName =="key_down" and args[3] == 200 then
            adminPage.logsTab.logsViewer:scroll(1)
            workspace:draw()
        end
    end

    function adminPage.logsTab.logsList:refresh()
        self:clear()
        local fileList = log.getFileList()
        for i = #fileList, 1, -1 do
            self:addItem(fileList[i]).onTouch = function()
                local lines = log.getLines(fileList[i])
                adminPage.logsTab.logsViewer.lines = {}
                for j = #lines, 1, -1 do
                    table.insert(adminPage.logsTab.logsViewer.lines, lines[j])
                end
                adminPage.logsTab.logsViewer.fromLine = 1
            end
        end
    end

    adminPage.logsTab.logsRefreshButton.onTouch = function()
        adminPage.logsTab.logsViewer.lines = {}
        adminPage.logsTab.logsList:refresh()
    end
    ----------------------------------------------------------------------------
    adminPage.settingsTab.imageUploadButton.onTouch = function()
        local result, response = pcall(require("internet").request, "https://pastebin.com/raw/" .. adminPage.settingsTab.imageUploadInput.text)
        if result then
            local path = "home/img/" .. adminPage.settingsTab.imageNameInput.text .. ".pic"
            filesystem.remove(path)
            for chunk in response do
                filesystem.append(path, chunk)
            end
            adminPage.caseTab.caseImgComboBox:refill()
            adminPage.caseTab.caseImgComboBox:setValueFromDataBase(adminPage.caseTab.dataTableList.selectedItemId)
            gui.alert("Изображение успешно загружено")
        else
            gui.alert("Ошибка загрузки изображения")
        end
    end

    adminPage.backButton.onTouch = function()
        mainPage:load(true)
    end
end

----------------------------------------------------------------------------
local function checkReplenishmentChest()
    local transposer = component.proxy(settings.data.transposerReplenishment)
    local item = transposer.getStackInSlot(settings.data.sideInput, 1)

    for currencyId, currencyRow in pairs(currencyDataTable.data) do
        if item.name == currencyRow["minecraft_name"] then
            currencyDataTable:update(currencyId, {["balance"] = currencyRow["balance"] + item.size})
            sumBalanceLabel:refresh()
            workspace:draw()
        end
    end
    transposer.transferItem(settings.data.sideInput, settings.data.sideOutput, item.size, 1, 1)
    os.sleep(0.05)
end
----------------------------------------------------------------------------
--[[
    ВЗАИМОДЕЙСТВИЕ СО СТРАНИЦАМИ
]]
function wrapper:hideAll()
    for _, page in pairs(self.children) do
        page.hidden = true
    end
end
----------------------------------------------------------------------------
local isAdminPageLoaded = false
function adminPage:load()
    if not(isAdminPageLoaded) then
        loadAdminPage()
        loadAdminPageLogic()
        isAdminPageLoaded = true
    end
    wrapper:hideAll()
    self.page.hidden = false
    workspace:draw()
end

function casePage:load()
    wrapper:hideAll()
    self.hidden = false

    caseAutoOpenSwitch.switch:setState(false)
    caseAnimationSwitch.switch:setState(true)

    prizeList:refill()
    historyList:clear()

    caseBalanceCurrencyBalanceLabel:refresh()
    caseBalanceCurrencyNameLabel:refresh()

    caseInfoName:refresh()
    caseInfoPrice:refresh()

    casePrize:change("Тут могла быть ваша реклама", "Я не шучу", 0xDA70D6, 1)

    sellPrizeContainer.hidden = true
    defaultActionCaseComboBox.selectedItem = 1
end

function mainPage:load(full) --? Поменять название переменной. Тяжело, тяжело, пиздец
    wrapper:hideAll()
    self.hidden = false

    if full then
        currencyComboBox:refill()
        if settings.data.defaultCurrencyId and currencyDataTable.data[settings.data.defaultCurrencyId] then
            currencyComboBox:setActive(settings.data.defaultCurrencyId)
        end
        if currencyComboBox:getItem(currencyComboBox.selectedItem) then
            currency:set(currencyComboBox:getItem(currencyComboBox.selectedItem).id)
        end
    end

    sumBalanceLabel:refresh()
    lastWinsContainer:refill()

    workspace:draw()
end

function baseSettingsPage:load()
    wrapper:hideAll()
    self.hidden = false
end
----------------------------------------------------------------------------
--КОМАНДЫ ДЛЯ ЧАТБОКСА
local chatFunctions = {
    ["@casExit"] = function()
        if session.id then
            event.cancel(session.id)
            session.id = nil
        end
        removeAllPCUsers()
        for _, adminNickname in ipairs(admins) do
            computer.addUser(adminNickname)
        end
        workspace:stop()
        os.exit()
    end,
    ["@casRestart"] = function()
        if session.id then
            event.cancel(session.id)
            session.id = nil
        end
        removeAllPCUsers()
        for _, adminNickname in ipairs(admins) do
            computer.addUser(adminNickname)
        end
        computer.shutdown(true)
    end,
    ["@casSessionEnd"] = function()
        session:stop()
    end,
    ["@casSessionAdmin"] = function(nickname)
        session:stop()
        session:start(nickname)
    end
}
----------------------------------------------------------------------------
local function chatEventHandler()
    while true do
        local _, _, nickname, msg = event.pull(1, "chat_message")
        if isAdmin(nickname) then
            if chatFunctions[msg] then
                chatFunctions[msg](nickname)
            end
        end
    end
end
----------------------------------------------------------------------------
local function initialization()
    removeAllPCUsers()
    processTransposers()
    -- adminPage.itemsTab.dataTableList:refill()
    -- adminPage.itemsTab.dataTableList.scrolledList:setActiveItem(1)
    log.setFilesystemAddress(settings.data.logsFilesystem)

    mainPage:load(true)

    baseSettingsPage:removeChildren()
    baseSettingsPage:remove()
    baseSettingsPage = nil

    thread.create(chatEventHandler)
end
----------------------------------------------------------------------------
currencyDataTable:addTrigger(DataBase.UPDATE, _, function(id, row)
    if id == currency.id then
        currency:set(id)
    else
        sumBalanceLabel:refresh()
        if not(casePage.hidden) then
            caseBalanceCurrencyBalanceLabel:refresh()
        end
    end

    if isAdminPageLoaded and adminPage.currencyTab.dataTableList.selectedItemId == id then
        adminPage.currencyTab.dataTableList.scrolledList:setActiveItem(adminPage.currencyTab.dataTableList.scrolledList.selectedItem)
    end
end)
----------------------------------------------------------------------------
session.onStoped = function()
    if case.autoOpeningStarted then
        case.autoOpeningStarted = false
    end

    if case.prize then
        case:givePrize()
    end

    if not helpContainer.hidden then helpContainer.hidden = true end

    currentUserLabel:changeUser(session.user)
    mainPage:load(true)
    adminButton.hidden = true
    workspace:draw()
end

session.onStarted = function(nickname)
    currentUserLabel:changeUser(nickname)
    adminButton.hidden = not(isAdmin(nickname))
    workspace:draw()
end
----------------------------------------------------------------------------
currency.onChanged = function(newId)
    currencyComboBox:setActive(newId)
    sumBalanceLabel:refresh()
    if not(casePage.hidden) then
        caseBalanceCurrencyBalanceLabel:refresh()
    end
    slider:refill()
end
----------------------------------------------------------------------------
case.onStarted = function()
    caseAnimationSwitch.switch.disabled = true
    caseAutoOpenSwitch.switch.disabled = true
    caseBackButton.disabled = true
    defaultActionCaseComboBox.disabled = true

    sellPrizeContainer.hidden = true

    if case.autoOpening then
        caseOpenButton:setStyle(caseOpenButton.STYLE_STOP)
    else
        caseOpenButton:setStyle(caseOpenButton.STYLE_DEFAULT_DISABLE)
    end
end

case.onStoped = function()
    caseOpenButton:setStyle(caseOpenButton.STYLE_DEFAULT_DISABLE)
end

case.onEnded = function(prize, status, err)
    if not case.autoOpeningStarted then
        caseAnimationSwitch.switch.disabled = false
        caseAutoOpenSwitch.switch.disabled = false
        caseBackButton.disabled = false
        defaultActionCaseComboBox.disabled = false

        caseOpenButton:setStyle(caseOpenButton.STYLE_DEFAULT_ACTIVE)
    end

    if prize then
        local historyItem = historyList:addItem(prize.name, prize.color)
        historyItem:addChild(gui.label(historyList.width - 5, 1, 5, 1, 0x696969, "x" .. tostring(prize.amount)))

        if status == "Выдано" or status == "Продано" then
            historyItem:addChild(gui.label(historyList.width - 13, 1, 7, 1, 0x2E8B57, status))
        elseif status == "Ошибка" then
            historyItem:addChild(gui.label(historyList.width - 13, 1, 7, 1, 0xB22222, status))
        end

        historyList:maxScrollDown()
    end
end
----------------------------------------------------------------------------
adminButton.onTouch = function()
    if isAdmin(session.user) then
        adminPage:load()
    end
end

caseBackButton.onTouch = function()
    mainPage:load()
end

--TODO: Тоже шляпа какая-то. Желательно переписать
confirmSettingsButton.onTouch = function()
    for identifier, elements in pairs(settings.elements) do
        for _, element in ipairs(elements) do
            local value = element:getValue()
            if value then
                settings:change(identifier, value)
            elseif element.isRequired then
                gui.alert("Стоять, ковбой. Ошибка \"" .. identifier .. "\"")
                return
            end
        end
    end

    for _, elements in pairs(settings.elements) do
        for _, element in ipairs(elements) do
            element:setFileValue()
        end
    end
    initialization()
end
----------------------------------------------------------------------------
function slider:refill() 
    --Есть onAnimationStart, onAnimationEnd. Напоминание
    slider:clear()
    local sortedCaseIDTableByPrice = {}
    for id, row in pairs(priceCasesDataTable.data) do
        if row["currency_id"] == currency.id and caseDataTable.data[row["case_id"]]["hidden"] ~= true then
            table.insert(sortedCaseIDTableByPrice, {id = id, price = row["price"]})
        end
    end

    table.sort(sortedCaseIDTableByPrice, function(a, b)
        return a.price > b.price
    end)

    for _, caseInfoRow in ipairs(sortedCaseIDTableByPrice) do
        local row = priceCasesDataTable.data[caseInfoRow.id]
        local caseId, price = row["case_id"], row["price"]
        local imgPath = "home/img/" .. caseDataTable.data[caseId]["img"] .. ".pic"

        local isFound = false
        for prizeId, prizeRow in pairs(prizesCaseDataTable.data) do
            if prizeRow["case_id"] == caseId then
                isFound = true
                break
            end
        end
        if isFound then
            local slide = slider:addSlide()

            local img = image.load(imgPath)
            local imageContainer = slide:addChild(gui.container(1, 1, image.getWidth(img), image.getHeight(img)))
            local imageX, imageY = gui.getAlignmentCoordinates(
                1,
                1,
                slide.width,
                slide.height,
                gui.ALIGNMENT_HORIZONTAL_CENTER,
                gui.ALIGNMENT_VERTICAL_TOP,
                imageContainer.width,
                imageContainer.height
            )
            imageContainer.localX, imageContainer.localY = math.floor(imageX), math.floor(imageY)

            imageContainer:addChild(gui.image(1, 1, img, false))

            local caseCard = slide:addChild(gui.container(3, imageContainer.localY + 26 + 2, 50, 8)) -- 26 - значение высоты imageContainer, можно поставить imageContainer.height, но тогда нижняя часть будет различаться при разной высоте картинок
            local caseName = caseCard:addChild(gui.label(1, 1, caseCard.width, 1, 0x2D2D2D, caseDataTable.data[caseId]["display_name"] or ("ID:" .. tostring(caseId))))
            caseCard:addChild(gui.label(1, 2, caseCard.width, 1, 0xfabf4b, string.rep('⎯', unicode.len(caseName.text) + 3)))
            local caseDescription = caseCard:addChild(gui.textBlock(1, 3, caseCard.width, 6, 0x6d6d6d, caseDataTable.data[caseId]["description"] or ""))

            local buyButton = slide:addChild(gui.roundedButton(slide.width - 26, caseCard.localY, 17, 3, 0x2D2D2D, 0xFFFFFF, 0xFFFFFF, 0x2D2D2D, "Открыть кейс"))
            local priceCard = slide:addChild(gui.container(buyButton.localX + buyButton.width - 1, buyButton.localY, 9, 3))
            local priceButton = priceCard:addChild(gui.roundedButton(0, 1, priceCard.width, 3, 0x4b4b4b, 0xfac564, 0xFFFFFF, 0x2D2D2D, " " .. tostring(price) .. currencyDataTable.data[currency.id]["unit"]))

            -- if caseDataTable:get(caseId)["sell_items_available"] then
            --     slide:addChild(gui.label(buyButton.localX, buyButton.localY + buyButton.height, 11, 1, 0x696969, "*с продажей"))
            -- end

            buyButton.onTouch = function()
                case:set(caseId)
                casePage:load()
            end
            priceButton.onTouch = buyButton.onTouch
        end
    end
end
----------------------------------------------------------------------------
local function checkBaseSettings()
    local baseSettings = {
        "redControllerReplenishment", "transposerReplenishment", "sideInput", "sideOutput"
    }
    for _, identifier in ipairs(baseSettings) do
        if not(settings.data[identifier]) then
            return
        end
    end
    return true
end
----------------------------------------------------------------------------
workspace.eventHandler = function(...)
    local args = {...}
    local eventName = args[3]

    if eventName == "touch" or eventName == "scroll" then
        local nickname = args[8]
        if not(session.user) then
            session:start(nickname)
        else
            session:refresh()
        end
    elseif eventName == "key_down" then
        local nickname = args[7]
        if not(session.user) then
            session:start(nickname)
        else
            session:refresh()
        end
    elseif eventName == "redstone_changed" then
        local address, power1, power2 = args[4], args[6], args[7]
        if address == settings.data.redControllerReplenishment then
            if power2 > 0 then
                checkReplenishmentChest()
            end
        end
    end
end
----------------------------------------------------------------------------
if checkBaseSettings() then
    initialization()
else
    baseSettingsPage:load()
end
----------------------------------------------------------------------------
local status, err = pcall(function ()
    workspace:draw()
    workspace:start()
end)

if err then
    if session.id then
        event.cancel(session.id)
        session.id = nil
    end

    filesystem.append("home/crash-log.txt", "Мамкин ломатель: " .. (session.user or "неизвестен") .. "\n" .. err .. "\n" .. string.rep("-", 65).. "\n")
    removeAllPCUsers()
    for _, adminNickname in ipairs(admins) do
        computer.addUser(adminNickname)
    end
    if chatBox then
        chatBox.say("Что-то не так. Перезагрузка")
    end
    computer.shutdown(true)
end