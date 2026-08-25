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


local function AddCheckbox(category, spec, key, label, tooltip, default)
    local setting = Settings.RegisterAddOnSetting(
        category,
        ADDON_NAME .. "_" .. spec.key .. "_" .. key,
        key,
        db[spec.key],
        type(default),
        label,
        default
    )

    Settings.CreateCheckbox(
        category,
        setting,
        tooltip
    )
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

local function RegisterSettings()
    local category, layout =
        Settings.RegisterVerticalLayoutCategory("PIGEN")

    layout:AddInitializer(
        CreateSettingsListSectionHeaderInitializer("General")
    )

    layout:AddInitializer(
        CreateSettingsButtonInitializer(
            "PISETTER",
            "Create",
            CreatePISetterMacro,
            "Creates a character-specific PISETTER macro.",
            true
        )
    )

    for _, spec in ipairs(SPECS) do
        layout:AddInitializer(
            CreateSettingsListSectionHeaderInitializer(spec.label)
        )

        AddCheckbox(
            category,
            spec,
            "enabled",
            "Generate " .. spec.macro,
            "Create and maintain the " .. spec.macro .. " macro.",
            true
        )

        for slot = 1, #SLOT_NAMES do
            AddCheckbox(
                category,
                spec,
                "slot" .. slot,
                "Use " .. slot .. " - " .. SLOT_NAMES[slot],
                "Add /use " .. slot .. " to " .. spec.macro .. ".",
                false
            )
        end
    end

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
    end

    local category = RegisterSettings()

    SLASH_PIGEN1 = "/pigen"

    SlashCmdList.PIGEN = function(message)
        if message == "options" then
            Settings.OpenToCategory(category:GetID())
            return
        end

        GenerateMacros()
    end
end)
