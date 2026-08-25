local ADDON_NAME = "PIGEN"

local db

local SLOT_NAMES = {
    "Head",
    "Neck",
    "Shoulder",
    "Shirt",
    "Chest",
    "Waist",
    "Legs",
    "Feet",
    "Wrist",
    "Hands",
    "Finger 1",
    "Finger 2",
    "Trinket 1",
    "Trinket 2",
    "Back",
    "Main Hand",
    "Off Hand",
    "Ranged",
    "Tabard",
}

local SPECS = {
    {
        key = "shadow",
        label = "Shadow",
        macro = "ShadowPI",
    },
    {
        key = "disco",
        label = "Discipline",
        macro = "DiscoPI",
    },
    {
        key = "holy",
        label = "Holy",
        macro = "HolyPI",
    },
}


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

    for slot = 1, #SLOT_NAMES do
        if db[spec.key]["slot" .. slot] then
            lines[#lines + 1] = "/use " .. slot
        end
    end

    if db[spec.key].potion and db[spec.key].potionText ~= "" then
        lines[#lines + 1] = "/use " .. db[spec.key].potionText
    end

    if db[spec.key].custom and db[spec.key].customText ~= "" then
        lines[#lines + 1] = db[spec.key].customText
    end

    lines[#lines + 1] =
        "/cast [@" .. target .. ",exists,nodead][@player,help,nodead] Power Infusion"

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


local function CreateEditBox(parent, x, y, width, getVal, setVal)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")

    eb:SetPoint("TOPLEFT", x, y)
    eb:SetSize(width, 22)
    eb:SetAutoFocus(false)
    eb:SetText(getVal() or "")

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

    return eb
end


local function AddCheckboxWithText(content, spec, key, label, tooltip, yOff)
    local textKey = key .. "Text"

    CreateCheckbox(
        content,
        label,
        10,
        yOff,
        function()
            return db[spec.key][key]
        end,
        function(value)
            db[spec.key][key] = value
        end,
        tooltip
    )

    yOff = yOff - 30

    CreateEditBox(
        content,
        40,
        yOff,
        420,
        function()
            return db[spec.key][textKey]
        end,
        function(value)
            db[spec.key][textKey] = value
        end
    )

    return yOff - 38
end


local function CreatePISetterMacro()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("PIGEN: Cannot create macro in combat.")
        return
    end

    local name = "PISETTER"
    local body = "/pigen"
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

    local yOff = -45

    local generalHeader = content:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalLarge"
    )

    generalHeader:SetPoint("TOPLEFT", 10, yOff)
    generalHeader:SetText("General")

    yOff = yOff - 30

    local piSetterButton = CreateFrame(
        "Button",
        nil,
        content,
        "UIPanelButtonTemplate"
    )

    piSetterButton:SetSize(160, 22)
    piSetterButton:SetPoint("TOPLEFT", 10, yOff)
    piSetterButton:SetText("Create PISETTER")
    piSetterButton:SetScript("OnClick", CreatePISetterMacro)

    yOff = yOff - 45

    for _, spec in ipairs(SPECS) do
        local specHeader = content:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalLarge"
        )

        specHeader:SetPoint("TOPLEFT", 10, yOff)
        specHeader:SetText(spec.label)

        yOff = yOff - 28

        CreateCheckbox(
            content,
            "Generate " .. spec.macro,
            10,
            yOff,
            function()
                return db[spec.key].enabled
            end,
            function(value)
                db[spec.key].enabled = value
            end,
            "Create and maintain the " .. spec.macro .. " macro."
        )

        yOff = yOff - 28

        for slot = 1, #SLOT_NAMES do
            local slotKey = "slot" .. slot

            CreateCheckbox(
                content,
                "Use " .. slot .. " - " .. SLOT_NAMES[slot],
                30,
                yOff,
                function()
                    return db[spec.key][slotKey]
                end,
                function(value)
                    db[spec.key][slotKey] = value
                end,
                "Add /use " .. slot .. " to " .. spec.macro .. "."
            )

            yOff = yOff - 25
        end

        yOff = yOff - 5

        yOff = AddCheckboxWithText(
            content,
            spec,
            "potion",
            "Potion",
            "Add a potion line to " .. spec.macro .. ".",
            yOff
        )

        yOff = AddCheckboxWithText(
            content,
            spec,
            "custom",
            "Custom",
            "Add a custom line to " .. spec.macro .. ".",
            yOff
        )

        yOff = yOff - 15
    end

    content:SetSize(550, math.abs(yOff) + 30)

    return panel
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
    db = PIGENDB

    for _, spec in ipairs(SPECS) do
        db[spec.key] = db[spec.key] or {}

        if db[spec.key].enabled == nil then
            db[spec.key].enabled = true
        end

        db[spec.key].potionText = db[spec.key].potionText or ""
        db[spec.key].customText = db[spec.key].customText or ""
    end

    local category = RegisterSettings()

    SLASH_PIGEN1 = "/pigen"

    SlashCmdList.PIGEN = function(message)
        if message == "options" then
            Settings.OpenToCategory(category.ID)
            return
        end

        GenerateMacros()
    end
end)
