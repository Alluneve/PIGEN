local ADDON_NAME = "PIGEN"

local db
local DB_VERSION = 1

local lastLinkedItem

local SPECS = {
    {
        key = "shadow",
        label = "Shadow",
        macro = "ShadowPI",
    },
    {
        key = "discipline",
        label = "Discipline",
        macro = "DiscoPI",
    },
    {
        key = "holy",
        label = "Holy",
        macro = "HolyPI",
    },
}

local function createSavedLine(key, orderNumber, enabled, displayText, macroText, macroVariable, tooltip)
    return {
        key = key,
        orderNumber = orderNumber,
        enabled = enabled,
        displayText = displayText,
        macroText = macroText,
        macroVariable = macroVariable,
        tooltip = tooltip,
    }
end

local DEFAULT_LINES = {
    createSavedLine("head", 1, false, "Use Head", "/use 1", nil, "use the on use effect of your helm"),
    createSavedLine("neck", 2, false, "Use Neck", "/use 2", nil, "use the on use effect of your necklace"),
    createSavedLine("shoulder", 3, false, "Use Shoulder", "/use 3", nil, "use the on use effect of your shoulders"),
    createSavedLine("shirt", 4, false, "Use Shirt", "/use 4", nil, "use the on use effect of your shirt"),
    createSavedLine("chest", 5, false, "Use Chest", "/use 5", nil, "use the on use effect of your chest"),
    createSavedLine("waist", 6, false, "Use Waist", "/use 6", nil, "use the on use effect of your belt"),
    createSavedLine("legs", 7, false, "Use Legs", "/use 7", nil, "use the on use effect of your pants"),
    createSavedLine("feet", 8, false, "Use Feet", "/use 8", nil, "use the on use effect of your feet"),
    createSavedLine("wrist", 9, false, "Use Wrist", "/use 9", nil, "use the on use effect of your wrists"),
    createSavedLine("hands", 10, false, "Use Hands", "/use 10", nil, "use the on use effect of your gloves"),
    createSavedLine("finger1", 11, false, "Use Finger 1", "/use 11", nil, "use the on use effect of your first ring"),
    createSavedLine("finger2", 12, false, "Use Finger 2", "/use 12", nil, "use the on use effect of your second ring"),
    createSavedLine("trinket1", 13, false, "Use Trinket 1", "/use 13", nil, "use the on use effect of your first trinket"),
    createSavedLine("trinket2", 14, false, "Use Trinket 2", "/use 14", nil,
        "use the on use effect of your second trinket"),
    createSavedLine("back", 15, false, "Use Back", "/use 15", nil, "use the on use effect of your cape"),
    createSavedLine("mainhand", 16, false, "Use Main Hand", "/use 16", nil,
        "use the on use effect of your mainhand or twohanded weapon"),
    createSavedLine("offhand", 17, false, "Use Off Hand", "/use 17", nil, "use the on use effect of your offhand weapon"),
    createSavedLine("ranged", 18, false, "Use Ranged", "/use 18", nil,
        "use the on use effect of your ranged weapon (classic only)"),
    createSavedLine("tabard", 19, false, "Use Tabard", "/use 19", nil, "use the on use effect of your tabard"),
    createSavedLine("potion", 20, false, "Use Potion", "/use %s", "Minor Healing Potion", "use your potion"),
    createSavedLine("custom1", 21, false, "Custom 1", "%s", "", "insert a custom macro line"),
    createSavedLine("pi", 22, true, "Cast Power Infusion",
        "/cast [@%s,exists,help,nodead][@player,help,nodead] Power Infusion", nil, "cast PI"),
}

local function createDefaultLines()
    local lines = {}

    for _, entry in ipairs(DEFAULT_LINES) do
        table.insert(lines, {
            key = entry.key,
            orderNumber = entry.orderNumber,
            enabled = entry.enabled,
            displayText = entry.displayText,
            macroText = entry.macroText,
            macroVariable = entry.macroVariable,
            tooltip = entry.tooltip,
        })
    end

    return lines
end


local function FindCharacterMacro(name)
    for index = 121, 150 do
        local macroName = GetMacroInfo(index)

        if macroName == name then
            return index
        end
    end
end


local function BuildMacro(spec, target)
    local lines = {
        "#showtooltip Power Infusion",
    }

    local savedLines = db[spec.key].lines

    table.sort(savedLines, function(a, b)
        return a.orderNumber < b.orderNumber
    end)

    for _, line in ipairs(savedLines) do
        if line.enabled then
            local macroLine

            if line.key == "pi" then
                macroLine = string.format(line.macroText, target)
            elseif line.macroVariable ~= nil then
                if line.macroVariable ~= "" then
                    macroLine = string.format(line.macroText, line.macroVariable)
                end
            else
                macroLine = line.macroText
            end

            if macroLine and macroLine ~= "" then
                lines[#lines + 1] = macroLine
            end
        end
    end

    return table.concat(lines, "\n")
end


local function GenerateMacros()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("PIGEN: Cannot update macros in combat.")
        return
    end

    local target = GetUnitName("target", true) or "player"

    local created = 0
    local updated = 0
    local deleted = 0

    for _, spec in ipairs(SPECS) do
        local settings = db[spec.key]
        local index = FindCharacterMacro(spec.macro)

        if settings.enabled then
            local body = BuildMacro(spec, target)

            if #body > 255 then
                UIErrorsFrame:AddMessage(
                    "PIGEN: " .. spec.macro .. " is longer than 255 characters."
                )
            elseif index then
                local _, _, currentBody = GetMacroInfo(index)

                if currentBody ~= body then
                    EditMacro(
                        index,
                        spec.macro,
                        "INV_Misc_QuestionMark",
                        body
                    )

                    updated = updated + 1
                end
            else
                local newMacro = CreateMacro(
                    spec.macro,
                    "INV_Misc_QuestionMark",
                    body,
                    true
                )

                if newMacro then
                    created = created + 1
                end
            end
        elseif index then
            DeleteMacro(index)
            deleted = deleted + 1
        end
    end

    UIErrorsFrame:AddMessage(
        string.format(
            "PIGEN: %d created, %d updated, %d deleted - target: %s",
            created,
            updated,
            deleted,
            target
        )
    )
end


local function CreateCheckbox(parent, label, x, y, getVal, setVal, tooltip)
    local cb = CreateFrame(
        "CheckButton",
        nil,
        parent,
        "InterfaceOptionsCheckButtonTemplate"
    )

    cb:SetPoint("TOPLEFT", x, y)
    cb.Text:SetText(label)
    cb:SetChecked(getVal())

    cb:SetScript("OnClick", function(self)
        setVal(self:GetChecked())
    end)

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        cb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    return cb
end


local function CreateEditBox(parent, label, x, y, width, getVal, setVal, tooltip, appendItem)
    local text = parent:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormal"
    )

    text:SetPoint("TOPLEFT", x, y)
    text:SetText(label)

    local eb = CreateFrame(
        "EditBox",
        nil,
        parent,
        "InputBoxTemplate"
    )

    eb:SetPoint("TOPLEFT", x, y - 20)
    eb:SetSize(width, 22)
    eb:SetAutoFocus(false)
    eb:SetText(getVal() or "")
    eb:SetCursorPosition(0)

    eb:SetScript("OnEnterPressed", function(self)
        setVal(self:GetText())
        self:ClearFocus()
    end)

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    eb:SetScript("OnEditFocusLost", function(self)
        setVal(self:GetText())
    end)

    if tooltip then
        eb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label)
            GameTooltip:AddLine(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        eb:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    local itemButton = CreateFrame(
        "Button",
        nil,
        parent,
        "UIPanelButtonTemplate"
    )

    itemButton:SetSize(80, 22)
    itemButton:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    itemButton:SetText(appendItem and "Add Item" or "Use Item")

    itemButton:SetScript("OnClick", function()
        if not lastLinkedItem then
            print("PIGEN: No item has been shift-clicked yet.")
            return
        end

        local value

        if appendItem then
            local current = eb:GetText()

            if current == "" then
                value = lastLinkedItem
            else
                value = current .. " " .. lastLinkedItem
            end
        else
            value = lastLinkedItem
        end

        eb:SetText(value)
        eb:SetCursorPosition(#value)
        setVal(value)
    end)

    return eb
end


local function AddCheckboxWithText(parent, label, x, y, getVal, setVal, tooltip, textLabel, textWidth, getTextVal,
                                   setTextVal, textTooltip, appendItem)
    local cb = CreateCheckbox(
        parent,
        label,
        x,
        y,
        getVal,
        setVal,
        tooltip
    )

    CreateEditBox(
        parent,
        textLabel,
        x + 30,
        y - 30,
        textWidth,
        getTextVal,
        setTextVal,
        textTooltip,
        appendItem
    )

    return cb
end

local function NormalizeLineOrder(lines)
    for index, line in ipairs(lines) do
        line.orderNumber = index
    end
end

local function GetNextCustomNumber(lines)
    local highest = 0

    for _, line in ipairs(lines) do
        local number = line.key:match("^custom(%d+)$")

        if number then
            highest = math.max(highest, tonumber(number))
        end
    end

    return highest + 1
end

local function AddCustomLine(lines)
    local number = GetNextCustomNumber(lines)

    table.insert(
        lines,
        createSavedLine(
            "custom" .. number,
            #lines + 1,
            false,
            "Custom " .. number,
            "%s",
            "",
            "Insert a custom macro line"
        )
    )

    NormalizeLineOrder(lines)
end

local function DeleteCustomLine(lines, line)
    for index, entry in ipairs(lines) do
        if entry == line then
            table.remove(lines, index)
            break
        end
    end

    NormalizeLineOrder(lines)
end


local function CreatePISetterMacro()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("PIGEN: Cannot create macro in combat.")
        return
    end

    local name = "PISETTER"
    local body = "/pigen generate"
    local icon = C_Spell.GetSpellTexture(10060)
    local index = FindCharacterMacro(name)

    if index then
        EditMacro(index, name, icon, body)
        UIErrorsFrame:AddMessage("PIGEN: PISETTER updated.")
    else
        CreateMacro(name, icon, body, true)
        UIErrorsFrame:AddMessage("PIGEN: PISETTER created.")
    end
end


local function BuildOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = ADDON_NAME

    local scrollFrame = CreateFrame(
        "ScrollFrame",
        nil,
        panel,
        "UIPanelScrollFrameTemplate"
    )

    scrollFrame:SetPoint("TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(550, 1000)
    scrollFrame:SetScrollChild(content)

    local title = content:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )

    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("PIGEN")

    local generalHeader = content:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )

    generalHeader:SetPoint("TOPLEFT", 10, -45)
    generalHeader:SetText("General")

    local piSetterButton = CreateFrame(
        "Button",
        nil,
        content,
        "UIPanelButtonTemplate"
    )

    piSetterButton:SetSize(160, 22)
    piSetterButton:SetPoint("TOPLEFT", 10, -75)
    piSetterButton:SetText("Create PISETTER")
    piSetterButton:SetScript("OnClick", CreatePISetterMacro)

    local specsStartY = -120
    local sections = {}

    local function LayoutSections()
        local yOff = specsStartY

        for _, section in ipairs(sections) do
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)

            yOff = yOff - section:GetHeight()
        end

        content:SetSize(
            550,
            math.abs(yOff) + 30
        )
    end

    for _, spec in ipairs(SPECS) do
        local specSettings = db[spec.key]
        local lines = specSettings.lines

        local section = CreateFrame("Frame", nil, content)
        section:SetSize(500, 100)

        table.insert(sections, section)

        local specHeader = section:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalLarge"
        )

        specHeader:SetPoint("TOPLEFT", 0, 0)
        specHeader:SetText(spec.label)

        CreateCheckbox(
            section,
            "Generate " .. spec.macro,
            0,
            -28,
            function()
                return specSettings.enabled
            end,
            function(value)
                specSettings.enabled = value
            end,
            "Create and maintain the " .. spec.macro .. " macro."
        )

        local addCustomButton = CreateFrame(
            "Button",
            nil,
            section,
            "UIPanelButtonTemplate"
        )

        addCustomButton:SetSize(140, 22)
        addCustomButton:SetPoint("TOPLEFT", 20, -60)
        addCustomButton:SetText("Add Custom Line")

        local reorderHint = section:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontHighlightSmall"
        )

        reorderHint:SetPoint("TOPLEFT", 20, -90)
        reorderHint:SetText("Drag the :: handle or line name to reorder the generated macro lines.")

        local lineContainer = CreateFrame("Frame", nil, section)
        lineContainer:SetPoint("TOPLEFT", 20, -112)
        lineContainer:SetSize(480, 1)

        local rows = {}

        local function LayoutRows()
            local rowY = 0

            for _, row in ipairs(rows) do
                row:ClearAllPoints()
                row:SetPoint(
                    "TOPLEFT",
                    lineContainer,
                    "TOPLEFT",
                    0,
                    rowY
                )

                rowY = rowY - row:GetHeight()
            end
        end

        local function UpdateSectionHeight()
            local totalHeight = 0

            for _, row in ipairs(rows) do
                totalHeight = totalHeight + row:GetHeight()
            end

            lineContainer:SetHeight(math.max(totalHeight, 1))
            section:SetHeight(127 + totalHeight)

            LayoutSections()
        end

        local function FindRowIndex(row)
            for index, currentRow in ipairs(rows) do
                if currentRow == row then
                    return index
                end
            end
        end

        local function GetDragIndex(row)
            local _, cursorY = GetCursorPosition()
            cursorY = cursorY / UIParent:GetEffectiveScale()

            local newIndex = 1

            for _, otherRow in ipairs(rows) do
                if otherRow ~= row then
                    local _, otherY = otherRow:GetCenter()

                    if otherY and cursorY < otherY then
                        newIndex = newIndex + 1
                    end
                end
            end

            return newIndex
        end

        local function MoveRow(row, newIndex)
            local oldIndex = FindRowIndex(row)

            if not oldIndex or oldIndex == newIndex then
                return
            end

            local movedRow = table.remove(rows, oldIndex)
            local movedLine = table.remove(lines, oldIndex)

            table.insert(rows, newIndex, movedRow)
            table.insert(lines, newIndex, movedLine)

            NormalizeLineOrder(lines)
            LayoutRows()
        end

        local function MakeDragTarget(target, row)
            target:RegisterForDrag("LeftButton")

            target:SetScript("OnDragStart", function(self)
                row:SetAlpha(0.5)

                self:SetScript("OnUpdate", function()
                    local newIndex = GetDragIndex(row)
                    MoveRow(row, newIndex)
                end)
            end)

            target:SetScript("OnDragStop", function(self)
                self:SetScript("OnUpdate", nil)

                row:SetAlpha(1)

                NormalizeLineOrder(lines)
                LayoutRows()
            end)
        end

        local RefreshRows

        RefreshRows = function()
            for _, row in ipairs(rows) do
                row:Hide()
            end

            rows = {}

            table.sort(lines, function(a, b)
                return a.orderNumber < b.orderNumber
            end)

            NormalizeLineOrder(lines)

            for _, line in ipairs(lines) do
                local entry = line
                local isCustom = entry.key:match("^custom%d+$") ~= nil
                local rowHeight = entry.macroVariable ~= nil and 75 or 25

                local row = CreateFrame(
                    "Frame",
                    nil,
                    lineContainer
                )

                row:SetSize(480, rowHeight)

                local dragHandle = CreateFrame(
                    "Button",
                    nil,
                    row
                )

                dragHandle:SetSize(20, 20)
                dragHandle:SetPoint("TOPLEFT", 0, 0)

                local dragText = dragHandle:CreateFontString(
                    nil,
                    "OVERLAY",
                    "GameFontNormal"
                )

                dragText:SetPoint("CENTER")
                dragText:SetText("::")

                MakeDragTarget(dragHandle, row)

                local checkbox

                if entry.macroVariable ~= nil then
                    checkbox = AddCheckboxWithText(
                        row,
                        entry.displayText,
                        25,
                        0,
                        function()
                            return entry.enabled
                        end,
                        function(value)
                            entry.enabled = value
                        end,
                        entry.tooltip,
                        "Value",
                        340,
                        function()
                            return entry.macroVariable
                        end,
                        function(value)
                            entry.macroVariable = value
                        end,
                        entry.tooltip,
                        isCustom
                    )
                else
                    checkbox = CreateCheckbox(
                        row,
                        entry.displayText,
                        25,
                        0,
                        function()
                            return entry.enabled
                        end,
                        function(value)
                            entry.enabled = value
                        end,
                        entry.tooltip
                    )
                end

                local labelDrag = CreateFrame(
                    "Button",
                    nil,
                    row
                )

                labelDrag:SetPoint(
                    "LEFT",
                    checkbox.Text,
                    "LEFT",
                    0,
                    0
                )

                labelDrag:SetSize(
                    math.max(checkbox.Text:GetStringWidth(), 1),
                    20
                )

                MakeDragTarget(labelDrag, row)

                labelDrag:SetScript("OnClick", function()
                    checkbox:Click()
                end)

                if entry.tooltip then
                    labelDrag:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(entry.displayText)
                        GameTooltip:AddLine(
                            entry.tooltip,
                            1,
                            1,
                            1,
                            true
                        )
                        GameTooltip:Show()
                    end)

                    labelDrag:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                end

                if isCustom then
                    local deleteButton = CreateFrame(
                        "Button",
                        nil,
                        row,
                        "UIPanelButtonTemplate"
                    )

                    deleteButton:SetSize(65, 22)
                    deleteButton:SetPoint("TOPRIGHT", -5, 0)
                    deleteButton:SetText("Delete")

                    deleteButton:SetScript("OnClick", function()
                        DeleteCustomLine(lines, entry)
                        RefreshRows()
                    end)
                end

                table.insert(rows, row)
            end

            LayoutRows()
            UpdateSectionHeight()
        end

        addCustomButton:SetScript("OnClick", function()
            AddCustomLine(lines)
            RefreshRows()
        end)

        RefreshRows()
    end

    LayoutSections()

    return panel
end

local function DebugLines(specKey)
    local spec = db[specKey]

    if not spec then
        print("PIGEN: Unknown spec: " .. specKey)
        return
    end

    for _, line in ipairs(spec.lines) do
        print(
            line.orderNumber,
            line.key,
            tostring(line.enabled),
            line.displayText
        )
    end
end

local function RegisterSettings()
    local panel = BuildOptionsPanel()

    local category = Settings.RegisterCanvasLayoutCategory(
        panel,
        ADDON_NAME
    )

    Settings.RegisterAddOnCategory(category)

    return category
end


local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= ADDON_NAME then
        return
    end

    PIGENDB = PIGENDB or {}

    if PIGENDB.dbVersion ~= DB_VERSION then
        PIGENDB = {
            dbVersion = DB_VERSION
        }
    end

    for _, spec in ipairs(SPECS) do
        PIGENDB[spec.key] = PIGENDB[spec.key] or {}
        if PIGENDB[spec.key].enabled == nil then
            PIGENDB[spec.key].enabled = true
        end
        if not PIGENDB[spec.key].lines then
            PIGENDB[spec.key].lines = createDefaultLines()
        end
    end
    db = PIGENDB

    hooksecurefunc("HandleModifiedItemClick", function(link)
        if not link or not link:find("|Hitem:", 1, true) then
            return
        end

        local itemName = C_Item.GetItemInfo(link)

        if itemName then
            lastLinkedItem = itemName
        end
    end)

    local category = RegisterSettings()

    SLASH_PIGEN1 = "/pigen"

    SlashCmdList.PIGEN = function(message)
        local command, args = message:match("^(%S*)%s*(.-)$")

        if command == "options" or command == "settings" then
            Settings.OpenToCategory(category.ID)
            return
        end

        if command == "debug" then
            local debugCommand, debugArgs = args:match("^(%S*)%s*(.-)$")

            if debugCommand == "lines" then
                DebugLines(debugArgs ~= "" and debugArgs or "shadow")
                return
            end
            if debugCommand == "item" then
                print("PIGEN last clicked item" .. (lastLinkedItem or "none"))
            end

            print("PIGEN debug commands:")
            print("/pigen debug lines [shadow|discipline|holy]")
            print("/pigen debug item")
            return
        end

        if command == "generate" then
            GenerateMacros()
            return
        end

        print("PIGEN commands:")
        print("/pigen debug")
        print("/pigen generate")
        print("/pigen options")
        print("/pigen settings")
    end
end)
