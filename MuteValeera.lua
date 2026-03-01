local ADDON_NAME = ...

local function GetAddonMetadataSafe(addonName, field)
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(addonName, field)
  end
  if GetAddOnMetadata then
    return GetAddOnMetadata(addonName, field)
  end
end

local ADDON_VERSION = GetAddonMetadataSafe(ADDON_NAME, "Version") or "unknown"

-- Local references for performance
local MuteSoundAPI = type(MuteSoundFile) == "function" and MuteSoundFile or nil
local UnmuteSoundAPI = type(UnmuteSoundFile) == "function" and UnmuteSoundFile or nil
local tinsert, tsort, tconcat, wipe = table.insert, table.sort, table.concat, table.wipe
local pairs, ipairs, tonumber = pairs, ipairs, tonumber
local unpack = unpack or table.unpack

local warnedMissingSoundAPI = false

local function SetSoundMuted(soundId, shouldMute)
  local fn = shouldMute and MuteSoundAPI or UnmuteSoundAPI
  if fn then
    fn(soundId)
    return true
  end

  if not warnedMissingSoundAPI then
    warnedMissingSoundAPI = true
    print("MuteValeera: Sound mute API is unavailable on this client. Muting is temporarily disabled.")
  end

  return false
end

-- SavedVariables
MuteValeeraSettings = MuteValeeraSettings or {}
local settings = MuteValeeraSettings

-- State variables
local isMuted, muteCritical
local isInitialized = false
local settingsCategory

local DEFAULTS = {
  isMuted = true,
  muteCritical = false,
  version = ADDON_VERSION,
  customList = {},
}

-- Built-in Valeera sound IDs are intentionally empty for now.
-- The initial candidate pool was the Wago Tools Valeera file search on pages 9-15,
-- filtered to files first introduced after build 12.0.0.63534. No entries met that rule.
local baseMuteList = {}

-- Keep the partial/full UX intact even though no verified critical subset exists yet.
local criticalMuteList = {}

-- Tooltip status is disabled until Valeera companion NPC IDs are confirmed safely.
local VALEERA_NPC_IDS = {}

-- Input validation and sanitization helpers
local function ValidateSoundId(idStr)
  -- Remove any whitespace (WoW doesn't have string:trim, so use gsub)
  idStr = idStr:gsub("^%s*(.-)%s*$", "%1")
  
  if idStr == "" then
    return nil, "empty input"
  end
  
  -- Check for obvious non-numeric characters (but allow scientific notation)
  if idStr:match("[^%d%.eE%+%-]") then
    return nil, "contains invalid characters"
  end
  
  local id = tonumber(idStr)
  if not id then
    return nil, "not a valid number"
  end
  
  -- Check if it's a whole number
  if id ~= math.floor(id) then
    return nil, "must be a whole number"
  end
  
  -- Check range
  if id <= 0 then
    return nil, "must be positive"
  end
  
  if id > 2147483647 then -- Max 32-bit signed integer (WoW limitation)
    return nil, "too large (max: 2,147,483,647)"
  end
  
  -- Convert to integer to avoid floating point precision issues
  return math.floor(id), nil
end

-- Parse comma/space-separated ID list with comprehensive validation
local function ParseIdList(input)
  local results = {
    valid = {},      -- {id = number, original = string}
    invalid = {},    -- {input = string, reason = string}
    empty = false    -- true if input was empty/whitespace only
  }
  
  if not input or input:gsub("%s", "") == "" then
    results.empty = true
    return results
  end
  
  -- Split on commas, semicolons, spaces, and handle various formats
  -- This regex handles: "123, 456; 789 | 101112" etc.
  for idStr in input:gmatch("[^,%s;|]+") do
    local id, error = ValidateSoundId(idStr)
    if id then
      tinsert(results.valid, {id = id, original = idStr})
    else
      tinsert(results.invalid, {input = idStr, reason = error})
    end
  end
  
  return results
end

-- Bulk operations helper for large ID lists
local function ProcessBulkIds(validIds, operation)
  local BATCH_SIZE = 50 -- Process in batches to avoid chat spam
  local processed = 0
  
  for i = 1, #validIds, BATCH_SIZE do
    local batch = {}
    local batchEnd = math.min(i + BATCH_SIZE - 1, #validIds)
    
    for j = i, batchEnd do
      tinsert(batch, validIds[j])
    end
    
    if operation == "add" then
      for _, item in ipairs(batch) do
        settings.customList[item.id] = true
        processed = processed + 1
      end
    elseif operation == "remove" then
      for _, item in ipairs(batch) do
        if settings.customList[item.id] then
          settings.customList[item.id] = nil
          processed = processed + 1
        end
      end
    end
    
    -- Show progress for large operations
    if #validIds > BATCH_SIZE and i > 1 then
      print(("  Processing... %d/%d"):format(batchEnd, #validIds))
    end
  end
  
  return processed
end

-- Check for potential issues with sound ID ranges
local function ValidateIdRange(id)
  local warnings = {}
  
  -- WoW sound ID ranges (approximate)
  if id < 1000 then
    tinsert(warnings, "very low ID (might be system sound)")
  elseif id > 10000000 then
    tinsert(warnings, "very high ID (might not exist)")
  end
  
  -- Common problematic ranges
  if id >= 1 and id <= 100 then
    tinsert(warnings, "system reserved range")
  elseif id >= 174 and id <= 200 then
    tinsert(warnings, "UI sound range")
  end
  
  return warnings
end

local function CopyMissingDefaults(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then
      if type(v) == "table" then
        dst[k] = {}
        CopyMissingDefaults(dst[k], v)
      else
        dst[k] = v
      end
    elseif type(v) == "table" and type(dst[k]) == "table" then
      CopyMissingDefaults(dst[k], v)
    end
  end
end

local function InitializeSettings()
  local oldVersion = settings.version
  CopyMissingDefaults(settings, DEFAULTS)

  if oldVersion ~= ADDON_VERSION then
    settings.version = ADDON_VERSION
    print(("MuteValeera: Settings updated to version %s"):format(ADDON_VERSION))
  end
  
  -- Cache settings locally for performance
  isMuted = settings.isMuted
  muteCritical = settings.muteCritical
  settings.customList = settings.customList or {}
  
  isInitialized = true
end

local function GetFinalMuteList()
  local seen = {}
  
  -- Add base sounds
  for _, id in ipairs(baseMuteList) do 
    seen[id] = true 
  end
  
  -- Add critical sounds if enabled
  if muteCritical then 
    for _, id in ipairs(criticalMuteList) do 
      seen[id] = true 
    end 
  end
  
  -- Add custom sounds
  for id in pairs(settings.customList) do 
    local numId = tonumber(id)
    if numId then
      seen[numId] = true 
    end
  end
  
  -- Convert to sorted array
  local result = {}
  for id in pairs(seen) do 
    tinsert(result, id) 
  end
  tsort(result)
  
  return result
end

local function ApplyMuteState()
  if not isInitialized then 
    return 
  end
  
  local muteList = GetFinalMuteList()
  for _, id in ipairs(muteList) do
    SetSoundMuted(id, isMuted)
  end
end

local function TryOpenSettingsCategory()
  if not (settingsCategory and Settings and Settings.OpenToCategory) then
    print("MuteValeera: Settings panel not available on this client.")
    return
  end

  local categoryID = settingsCategory.GetID and settingsCategory:GetID() or settingsCategory
  if type(categoryID) ~= "number" then
    print("MuteValeera: Settings panel is available, but the category could not be resolved.")
    return
  end

  Settings.OpenToCategory(categoryID)
end

-- Command handling with better error checking
local function HandleSlashCommand(msg)
  if not isInitialized then
    print("MuteValeera: Addon not yet initialized. Please try again.")
    return
  end
  
  local args = {}
  for word in msg:gmatch("%S+") do 
    tinsert(args, word) 
  end
  
  local cmd = args[1] and string.lower(args[1]) or ""
  local rest = msg:match("^%S+%s+(.*)") or ""
  
  if cmd == "on" or cmd == "mute" then
    settings.isMuted, isMuted = true, true
    print("MuteValeera: Valeera muted.")
    
  elseif cmd == "off" or cmd == "unmute" then
    settings.isMuted, isMuted = false, false
    print("MuteValeera: Valeera unmuted.")
    
  elseif cmd == "toggle" then
    isMuted = not isMuted
    settings.isMuted = isMuted
    print(("MuteValeera: Mute toggled %s"):format(isMuted and "ON" or "OFF"))
    
  elseif cmd == "full" then
    settings.muteCritical, muteCritical = true, true
    print("MuteValeera: Critical lines now muted.")
    
  elseif cmd == "partial" then
    settings.muteCritical, muteCritical = false, false
    print("MuteValeera: Partial mute enabled (critical lines allowed).")
    
  elseif cmd == "status" then
    local muteCount = #GetFinalMuteList()
    print(("MuteValeera Status - Mute: %s, Critical mute: %s, Total sounds muted: %d"):format(
      isMuted and "ON" or "OFF", 
      muteCritical and "YES" or "NO",
      isMuted and muteCount or 0
    ))
    return
    
  elseif cmd == "add" then
    if rest == "" then
      print("MuteValeera: Please specify sound IDs to add")
      print("  Examples: /mutevaleera add 12345")
      print("           /mutevaleera add 12345,67890,11111")
      print("           /mutevaleera add 12345 67890 11111")
      return
    end
    
    local parseResults = ParseIdList(rest)
    
    if parseResults.empty then
      print("MuteValeera: No sound IDs found to add.")
      return
    end
    
    -- Check for duplicates and categorize
    local added, duplicates, inBuiltIn, warnings = {}, {}, {}, {}
    
    -- Create lookup tables for built-in lists
    local builtInLookup = {}
    for _, id in ipairs(baseMuteList) do builtInLookup[id] = "base" end
    for _, id in ipairs(criticalMuteList) do builtInLookup[id] = "critical" end
    
    -- Process valid IDs
    for _, item in ipairs(parseResults.valid) do
      local id = item.id
      
      -- Check for range warnings
      local idWarnings = ValidateIdRange(id)
      if #idWarnings > 0 then
        tinsert(warnings, {id = id, warnings = idWarnings})
      end
      
      if builtInLookup[id] then
        tinsert(inBuiltIn, {id = id, list = builtInLookup[id], original = item.original})
      elseif settings.customList[id] then
        tinsert(duplicates, {id = id, original = item.original})
      else
        tinsert(added, {id = id, original = item.original})
      end
    end
    
    -- Handle bulk additions efficiently
    if #added > 0 then
      ProcessBulkIds(added, "add")
    end
    
    -- Provide comprehensive feedback
    local totalProcessed = #parseResults.valid + #parseResults.invalid
    print(("MuteValeera: Processed %d sound ID%s:"):format(totalProcessed, totalProcessed == 1 and "" or "s"))
    
    if #added > 0 then
      local ids = {}
      for _, item in ipairs(added) do tinsert(ids, item.id) end
      tsort(ids)
      
      if #added <= 10 then
        print(("  ✓ Added %d new custom ID%s: %s"):format(#added, #added == 1 and "" or "s", tconcat(ids, ", ")))
      else
        print(("  ✓ Added %d new custom IDs (showing first 10): %s..."):format(
          #added, tconcat({unpack(ids, 1, 10)}, ", ")))
      end
    end
    
    if #duplicates > 0 then
      local ids = {}
      for _, item in ipairs(duplicates) do tinsert(ids, item.id) end
      tsort(ids)
      
      if #duplicates <= 10 then
        print(("  ⚠ Already in custom list (%d): %s"):format(#duplicates, tconcat(ids, ", ")))
      else
        print(("  ⚠ Already in custom list (%d IDs, showing first 10): %s..."):format(
          #duplicates, tconcat({unpack(ids, 1, 10)}, ", ")))
      end
    end
    
    if #inBuiltIn > 0 then
      -- Group by list type
      local baseIds, criticalIds = {}, {}
      for _, item in ipairs(inBuiltIn) do
        if item.list == "base" then
          tinsert(baseIds, item.id)
        else
          tinsert(criticalIds, item.id)
        end
      end
      
      if #baseIds > 0 then
        tsort(baseIds)
        if #baseIds <= 10 then
          print(("  ℹ Already in base mute list (%d): %s"):format(#baseIds, tconcat(baseIds, ", ")))
        else
          print(("  ℹ Already in base mute list (%d IDs, showing first 10): %s..."):format(
            #baseIds, tconcat({unpack(baseIds, 1, 10)}, ", ")))
        end
      end
      
      if #criticalIds > 0 then
        tsort(criticalIds)
        if #criticalIds <= 10 then
          print(("  ℹ Already in critical mute list (%d): %s"):format(#criticalIds, tconcat(criticalIds, ", ")))
        else
          print(("  ℹ Already in critical mute list (%d IDs, showing first 10): %s..."):format(
            #criticalIds, tconcat({unpack(criticalIds, 1, 10)}, ", ")))
        end
      end
    end
    
    if #parseResults.invalid > 0 then
      print(("  ✗ Invalid input%s (%d):"):format(#parseResults.invalid == 1 and "" or "s", #parseResults.invalid))
      local showCount = math.min(5, #parseResults.invalid)
      for i = 1, showCount do
        local item = parseResults.invalid[i]
        print(("    '%s' - %s"):format(item.input, item.reason))
      end
      if #parseResults.invalid > 5 then
        print(("    ... and %d more invalid inputs"):format(#parseResults.invalid - 5))
      end
    end
    
    -- Show warnings for suspicious IDs
    if #warnings > 0 and #warnings <= 5 then
      print("  ⚠ Warnings:")
      for _, warning in ipairs(warnings) do
        print(("    ID %d: %s"):format(warning.id, tconcat(warning.warnings, ", ")))
      end
    elseif #warnings > 5 then
      print(("  Warning: %d sound IDs have potential issues (use '/mutevaleera validate' for details)"):format(#warnings))
    end
    
    -- Summary
    if #added == 0 then
      print("  No new sound IDs were added.")
    else
      local totalCustom = 0
      for _ in pairs(settings.customList) do totalCustom = totalCustom + 1 end
      print(("  Total custom sound IDs: %d"):format(totalCustom))
      
      if totalCustom > 100 then
        print("  Note: Large numbers of custom IDs may impact performance.")
      end
    end
    
  elseif cmd == "del" or cmd == "remove" then
    if rest == "" then
      print("MuteValeera: Please specify sound IDs to remove (e.g., /mutevaleera del 12345,67890)")
      return
    end
    
    local parseResults = ParseIdList(rest)
    
    if parseResults.empty then
      print("MuteValeera: No sound IDs found to remove.")
      return
    end
    
    local removed, notFound = {}, {}
    
    for _, item in ipairs(parseResults.valid) do
      local id = item.id
      
      if settings.customList[id] then
        settings.customList[id] = nil
        tinsert(removed, {id = id, original = item.original})
      else
        tinsert(notFound, {id = id, original = item.original})
      end
    end
    
    -- Provide detailed feedback
    local totalProcessed = #parseResults.valid + #parseResults.invalid
    print(("MuteValeera: Processed %d sound ID%s for removal:"):format(totalProcessed, totalProcessed == 1 and "" or "s"))
    
    if #removed > 0 then
      local ids = {}
      for _, item in ipairs(removed) do tinsert(ids, item.id) end
      tsort(ids)
      print(("  ✓ Removed %d custom ID%s: %s"):format(#removed, #removed == 1 and "" or "s", tconcat(ids, ", ")))
    end
    
    if #notFound > 0 then
      local ids = {}
      for _, item in ipairs(notFound) do tinsert(ids, item.id) end
      tsort(ids)
      print(("  ⚠ Not found in custom list (%d): %s"):format(#notFound, tconcat(ids, ", ")))
    end
    
    if #parseResults.invalid > 0 then
      print(("  ✗ Invalid input%s (%d):"):format(#parseResults.invalid == 1 and "" or "s", #parseResults.invalid))
      for _, item in ipairs(parseResults.invalid) do
        print(("    '%s' - %s"):format(item.input, item.reason))
      end
    end
    
    -- Summary
    if #removed == 0 then
      print("  No sound IDs were removed.")
    else
      local totalCustom = 0
      for _ in pairs(settings.customList) do totalCustom = totalCustom + 1 end
      print(("  Remaining custom sound IDs: %d"):format(totalCustom))
    end
    
  elseif cmd == "validate" then
    local allIds = {}
    for id in pairs(settings.customList) do tinsert(allIds, id) end
    
    if #allIds == 0 then
      print("MuteValeera: No custom sound IDs to validate.")
      return
    end
    
    tsort(allIds)
    
    local suspicious, systemRange, highRange = {}, {}, {}
    
    for _, id in ipairs(allIds) do
      local warnings = ValidateIdRange(id)
      if #warnings > 0 then
        for _, warning in ipairs(warnings) do
          if warning:find("system") then
            tinsert(systemRange, id)
          elseif warning:find("very high") then
            tinsert(highRange, id)
          else
            tinsert(suspicious, {id = id, warning = warning})
          end
        end
      end
    end
    
    print(("MuteValeera: Validation results for %d custom IDs:"):format(#allIds))
    
    if #systemRange > 0 then
      print(("  ⚠ System/UI sound range (%d): %s"):format(#systemRange, tconcat(systemRange, ", ")))
    end
    
    if #highRange > 0 then
      print(("  ⚠ Very high IDs (%d): %s"):format(#highRange, tconcat(highRange, ", ")))
    end
    
    if #suspicious > 0 then
      print("  ⚠ Other warnings:")
      for _, item in ipairs(suspicious) do
        print(("    ID %d: %s"):format(item.id, item.warning))
      end
    end
    
    if #systemRange == 0 and #highRange == 0 and #suspicious == 0 then
      print("  ✓ All custom sound IDs appear to be in normal ranges.")
    end
    return
    
  elseif cmd == "clear" then
    local count = 0
    for _ in pairs(settings.customList) do count = count + 1 end
    
    if count == 0 then
      print("MuteValeera: No custom sound IDs to clear.")
      return
    end
    
    print(("MuteValeera: This will remove all %d custom sound IDs. Type '/mutevaleera clearconfirm' to confirm."):format(count))
    return
    
  elseif cmd == "clearconfirm" then
    local count = 0
    for _ in pairs(settings.customList) do count = count + 1 end
    
    if count == 0 then
      print("MuteValeera: No custom sound IDs to clear.")
      return
    end
    
    wipe(settings.customList)
    print(("MuteValeera: Cleared %d custom sound IDs."):format(count))
    
  elseif cmd == "list" then
    local customIds = {}
    for id in pairs(settings.customList) do tinsert(customIds, id) end
    
    if #customIds == 0 then
      print("MuteValeera: No custom sound IDs configured.")
      return
    end
    
    tsort(customIds)
    print(("MuteValeera: Custom IDs (%d):"):format(#customIds))
    for i = 1, #customIds, 10 do
      local batchEnd = math.min(i + 9, #customIds)
      local batch = {}
      for j = i, batchEnd do tinsert(batch, customIds[j]) end
      print("  " .. tconcat(batch, ", "))
    end
    return
    
  elseif cmd == "export" then
    local customIds = {}
    for id in pairs(settings.customList) do tinsert(customIds, id) end
    
    if #customIds == 0 then
      print("MuteValeera: No custom sound IDs to export.")
      return
    end
    
    tsort(customIds)
    local exportStr = tconcat(customIds, ",")
    local dialog = StaticPopup_Show("MUTEVALEERA_EXPORT")
    if dialog and dialog.editBox then
      dialog.editBox:SetText(exportStr)
      dialog.editBox:HighlightText()
    end
    return
    
  elseif cmd == "import" then
    if rest == "" then
      StaticPopup_Show("MUTEVALEERA_IMPORT")
      return
    end
    
    local parseResults = ParseIdList(rest)
    if parseResults.empty then
      print("MuteValeera: No sound IDs found to import.")
      return
    end
    
    local added, skipped = 0, 0
    for _, item in ipairs(parseResults.valid) do
      if not settings.customList[item.id] then
        settings.customList[item.id] = true
        added = added + 1
      else
        skipped = skipped + 1
      end
    end
    
    print(("MuteValeera: Imported %d new custom ID%s (%d duplicate%s skipped, %d invalid)."):format(
      added, added == 1 and "" or "s",
      skipped, skipped == 1 and "" or "s",
      #parseResults.invalid
    ))
    
  elseif cmd == "ui" or cmd == "config" then
    if InCombatLockdown and InCombatLockdown() then
      print("MuteValeera: Cannot open the settings panel during combat. Try again after combat.")
      return
    end

    TryOpenSettingsCategory()
    return
    
  elseif cmd == "help" or cmd == "" then
    print("MuteValeera Commands:")
    print("  Basic: on | off | toggle | full | partial | status")
    print("  Custom: add <ids> | del <ids> | list | clear")
    print("  Advanced: validate | export | import <ids> | ui")
    print("  Aliases: /mv = /mutevaleera")
    print("  IDs can be separated by commas, spaces, or semicolons")
    return
    
  elseif cmd == "helpfull" then
    print("MuteValeera Detailed Commands:")
    print("  Basic Controls:")
    print("    on | off | toggle - Control muting state")
    print("    full | partial - Include/exclude critical lines")
    print("    status - Show current settings and mute counts")
    print("  Custom Sound IDs:")
    print("    add <ids> - Add custom sound IDs")
    print("    del <ids> - Remove custom sound IDs")
    print("    list - Show all custom sound IDs")
    print("    clear - Clear all custom IDs (requires confirmation)")
    print("  Advanced:")
    print("    validate - Check custom IDs for potential issues")
    print("    export - Copy custom IDs for backup/sharing")
    print("    import <ids> - Import custom IDs from string")
    print("    ui - Open settings panel")
    print("  Examples:")
    print("    /mutevaleera add 12345,67890")
    print("    /mutevaleera add 12345 67890 11111")
    print("    /mv toggle")
    print("    /mutevaleera import 12345,67890,11111")
    return
    
  else
    print(("MuteValeera: Unknown command '%s'"):format(cmd))
    print("  Use '/mutevaleera help' for commands or '/mutevaleera helpfull' for detailed help")
    return
  end

  ApplyMuteState()
end

-- Register slash command
SLASH_MUTEVALEERA1 = "/mutevaleera"
SLASH_MUTEVALEERA2 = "/mv"
SlashCmdList["MUTEVALEERA"] = HandleSlashCommand

-- Export/Import popup dialogs
StaticPopupDialogs["MUTEVALEERA_EXPORT"] = {
  text = "MuteValeera: Copy this export string (Ctrl+C):",
  button1 = "Close",
  hasEditBox = true,
  editBoxWidth = 350,
  OnShow = function(self)
    self.editBox:SetFocus()
    self.editBox:HighlightText()
  end,
  EditBoxOnEscapePressed = function(self)
    self:GetParent():Hide()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

StaticPopupDialogs["MUTEVALEERA_IMPORT"] = {
  text = "MuteValeera: Paste sound IDs to import (comma-separated):",
  button1 = "Import",
  button2 = "Cancel",
  hasEditBox = true,
  editBoxWidth = 350,
  OnAccept = function(self)
    local text = self.editBox:GetText()
    if text and text:gsub("%s", "") ~= "" then
      HandleSlashCommand("import " .. text)
    end
  end,
  EditBoxOnEnterPressed = function(self)
    local parent = self:GetParent()
    local text = self:GetText()
    if text and text:gsub("%s", "") ~= "" then
      HandleSlashCommand("import " .. text)
    end
    parent:Hide()
  end,
  EditBoxOnEscapePressed = function(self)
    self:GetParent():Hide()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- Tooltip enhancement (with error protection)
local function GetTooltipGUID(tooltip, data)
  if data then
    if type(data.guid) == "string" and data.guid ~= "" then
      return data.guid
    end
    if type(data.healthGUID) == "string" and data.healthGUID ~= "" then
      return data.healthGUID
    end
  end

  if tooltip and tooltip.GetUnit then
    local _, unit = tooltip:GetUnit()
    if unit then
      if securecallfunction then
        local guid = securecallfunction(UnitGUID, unit)
        if type(guid) == "string" and guid ~= "" then
          return guid
        end
      else
        local guid = UnitGUID(unit)
        if type(guid) == "string" and guid ~= "" then
          return guid
        end
      end
    end
  end
end

local function SetupTooltip()
  if not (
    TooltipDataProcessor and
    TooltipDataProcessor.AddTooltipPostCall and
    Enum and
    Enum.TooltipDataType and
    Enum.TooltipDataType.Unit
  ) then
    return
  end
  
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
    if not (tooltip and data and isInitialized) then 
      return 
    end
    
    local guid = GetTooltipGUID(tooltip, data)
    if not guid then
      return
    end
    
    -- Locale-independent NPC ID check via GUID
    local isValeera = false
    local _, _, _, _, _, npcIdStr = strsplit("-", guid)
    local npcId = tonumber(npcIdStr)
    if npcId and VALEERA_NPC_IDS[npcId] then
      isValeera = true
    end
    
    if isValeera then
      tooltip:AddLine(" ")
      
      local status, color
      if isMuted and muteCritical then 
        status, color = "Fully muted", "00ff00"
      elseif isMuted then 
        status, color = "Partially muted", "ffff00"
      else 
        status, color = "Not muted", "ff0000" 
      end
      
      tooltip:AddLine(("|cff%sMuteValeera: %s|r"):format(color, status))
      
      if isMuted then
        local muteCount = #GetFinalMuteList()
        tooltip:AddLine(("|cff888888%d sounds muted|r"):format(muteCount))
      end
    end
  end)
end

-- Settings registration (canvas layout — avoids Blizzard setting bleed)
local function RegisterSettings()
  if not (Settings and Settings.RegisterCanvasLayoutCategory) then
    return
  end
  
  local ok, err = pcall(function()
    local panel = CreateFrame("Frame")
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(("Mute Valeera  |cff888888v%s|r"):format(ADDON_VERSION))
    
    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Silences Valeera Sanguinar's repetitive delve companion voice lines.")
    desc:SetJustifyH("LEFT")
    desc:SetWidth(500)
    
    -- Helper: create a checkbox with clickable label and inline description
    local function CreateCheckbox(parent, anchor, label, descText, getFunc, setFunc)
      local container = CreateFrame("Frame", nil, parent)
      container:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
      container:SetSize(500, 40)
      
      local cb = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
      cb:SetPoint("TOPLEFT", 0, 0)
      cb:SetChecked(getFunc())
      cb:SetScript("OnClick", function(self)
        local val = self:GetChecked()
        setFunc(val)
      end)
      
      -- Make label clickable
      local labelBtn = CreateFrame("Button", nil, container)
      labelBtn:SetPoint("LEFT", cb, "RIGHT", 4, 0)
      labelBtn:SetSize(400, 20)
      
      local labelText = labelBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      labelText:SetPoint("LEFT", 0, 0)
      labelText:SetText(label)
      labelText:SetJustifyH("LEFT")
      
      labelBtn:SetScript("OnClick", function()
        cb:Click()
      end)
      
      -- Description text below
      local descStr = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      descStr:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 24, -2)
      descStr:SetText("|cff888888" .. descText .. "|r")
      descStr:SetJustifyH("LEFT")
      descStr:SetWidth(470)
      descStr:SetWordWrap(true)
      
      return container
    end
    
    -- Mute Voice Lines checkbox
    local muteCheck = CreateCheckbox(
      panel, desc,
      "Mute Valeera voice lines",
      "Enable or disable muting of Valeera's repetitive voice lines in delves.",
      function() return settings.isMuted end,
      function(val)
        settings.isMuted = val
        isMuted = val
        ApplyMuteState()
      end
    )
    
    -- Mute Critical Lines checkbox
    local criticalCheck = CreateCheckbox(
      panel, muteCheck,
      "Also mute critical/important lines",
      "Include critical gameplay-related voice lines (e.g., boss warnings) in muting.",
      function() return settings.muteCritical end,
      function(val)
        settings.muteCritical = val
        muteCritical = val
        ApplyMuteState()
      end
    )
    
    -- Custom Sound IDs section
    local customHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customHeader:SetPoint("TOPLEFT", criticalCheck, "BOTTOMLEFT", 0, -20)
    customHeader:SetText("Custom Sound IDs")
    
    local customDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    customDesc:SetPoint("TOPLEFT", customHeader, "BOTTOMLEFT", 0, -4)
    customDesc:SetText("|cff888888Add additional sound IDs to mute. Use /mutevaleera add <ids> or enter below.|r")
    customDesc:SetJustifyH("LEFT")
    customDesc:SetWidth(470)
    
    -- Input box for adding IDs
    local inputBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    inputBox:SetPoint("TOPLEFT", customDesc, "BOTTOMLEFT", 0, -8)
    inputBox:SetSize(280, 20)
    inputBox:SetAutoFocus(false)
    inputBox:SetMaxLetters(200)
    
    local addBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addBtn:SetPoint("LEFT", inputBox, "RIGHT", 8, 0)
    addBtn:SetSize(80, 22)
    addBtn:SetText("Add IDs")
    addBtn:SetScript("OnClick", function()
      local text = inputBox:GetText()
      if text and text:gsub("%s", "") ~= "" then
        HandleSlashCommand("add " .. text)
        inputBox:SetText("")
        panel.refreshCustomList()
      end
    end)
    
    inputBox:SetScript("OnEnterPressed", function(self)
      addBtn:Click()
    end)
    
    inputBox:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
    end)
    
    -- Custom IDs list (scrollable)
    local listLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    listLabel:SetPoint("TOPLEFT", inputBox, "BOTTOMLEFT", 0, -12)
    listLabel:SetText("|cff888888Current custom IDs:|r")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetSize(360, 150)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(340, 1)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Clear all button
    local clearBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearBtn:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -8)
    clearBtn:SetSize(100, 22)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function()
      StaticPopup_Show("MUTEVALEERA_SETTINGS_CLEAR")
    end)
    
    -- Popup for clear confirmation
    StaticPopupDialogs["MUTEVALEERA_SETTINGS_CLEAR"] = {
      text = "Clear all custom sound IDs?",
      button1 = "Clear",
      button2 = "Cancel",
      OnAccept = function()
        wipe(settings.customList)
        ApplyMuteState()
        panel.refreshCustomList()
        print("MuteValeera: All custom sound IDs cleared.")
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
    }
    
    local idLines = {}
    
    function panel.refreshCustomList()
      -- Clear existing lines
      for _, line in ipairs(idLines) do
        line:Hide()
      end
      wipe(idLines)
      
      -- Get sorted custom IDs
      local customIds = {}
      for id in pairs(settings.customList) do
        tinsert(customIds, id)
      end
      tsort(customIds)
      
      if #customIds == 0 then
        local emptyText = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        emptyText:SetPoint("TOPLEFT", 8, -8)
        emptyText:SetText("|cff888888No custom sound IDs configured.|r")
        tinsert(idLines, emptyText)
        scrollChild:SetHeight(30)
        return
      end
      
      -- Create a line for each ID
      local yOffset = -4
      for i, id in ipairs(customIds) do
        local line = CreateFrame("Frame", nil, scrollChild)
        line:SetSize(320, 24)
        line:SetPoint("TOPLEFT", 4, yOffset)
        
        local idText = line:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        idText:SetPoint("LEFT", 4, 0)
        idText:SetText(tostring(id))
        
        local removeBtn = CreateFrame("Button", nil, line, "UIPanelButtonTemplate")
        removeBtn:SetPoint("RIGHT", -4, 0)
        removeBtn:SetSize(60, 20)
        removeBtn:SetText("Remove")
        removeBtn:SetScript("OnClick", function()
          settings.customList[id] = nil
          ApplyMuteState()
          panel.refreshCustomList()
        end)
        
        tinsert(idLines, line)
        yOffset = yOffset - 24
      end
      
      scrollChild:SetHeight(math.max(150, #customIds * 24 + 8))
    end
    
    -- Initial refresh
    panel.refreshCustomList()
    
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Mute Valeera")
    Settings.RegisterAddOnCategory(category)
    settingsCategory = category
  end)
  
  if not ok then
    print("MuteValeera: Settings panel failed to register: " .. tostring(err))
  end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
  if event == "ADDON_LOADED" and addonName == ADDON_NAME then
    InitializeSettings()
    ApplyMuteState()
    
  elseif event == "PLAYER_LOGIN" then
    C_Timer.After(1, function()
      RegisterSettings()
      SetupTooltip()
    end)
    
    self:UnregisterEvent("ADDON_LOADED")
    self:UnregisterEvent("PLAYER_LOGIN")
  end
end)
