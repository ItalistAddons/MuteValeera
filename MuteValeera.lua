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
local GetCVarAPI = type(GetCVar) == "function" and GetCVar or nil
local GetCVarBoolAPI = type(GetCVarBool) == "function" and GetCVarBool or nil
local SetCVarAPI = type(SetCVar) == "function" and SetCVar or nil
local UnitGUIDAPI = type(UnitGUID) == "function" and UnitGUID or nil
local UnitExistsAPI = type(UnitExists) == "function" and UnitExists or nil
local tinsert, tsort, tconcat, wipe = table.insert, table.sort, table.concat, table.wipe
local pairs, ipairs, tonumber = pairs, ipairs, tonumber
local unpack = unpack or table.unpack

local warnedMissingSoundAPI = false
local CHAT_BUBBLE_CVAR = "chatBubbles"
local VALEERA_COMPANION_UNIT_TOKENS = {
  "companion",
  "delvecompanion",
  "follower",
}
local BUBBLE_SOURCE_GUID_METHODS = {
  "GetSourceGUID",
  "GetGUID",
}
local BUBBLE_SOURCE_TOKEN_METHODS = {
  "GetSourceUnit",
  "GetSourceUnitToken",
  "GetUnitToken",
}

local RefreshBubbleState

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
local isMuted, muteCritical, muteBubbles, muteDundun, muteNanea
local isInitialized = false
local settingsCategory
local isInDelve = false
local activeBubbleStrategy = "off"
local bubbleTicker
local forcedBubbleCVar = false
local bubbleCVarBackup
local suppressOwnCVarUpdate = false
local selectiveBubbleSupport = nil

local DEFAULTS = {
  isMuted = true,
  muteCritical = false,
  muteBubbles = true,
  muteDundun = true,
  muteNanea = true,
  bubbleFallbackMode = "auto",
  version = ADDON_VERSION,
  customList = {},
}

-- Built-in Valeera sound IDs come from the Wago Tools Valeera file search on
-- pages 9-15. This set is limited to vo_120 companion assets that were updated
-- after build 12.0.0.63534 while staying in that audited candidate pool.
local baseMuteList = {
  7243762, 7243934, 7329273, 7430043, 7430047, 7430050, 7430053, 7430056, 7430059, 7430063,
  7430066, 7430069, 7430072, 7430075, 7430078, 7430082, 7430086, 7430089, 7430092, 7430095,
  7430098, 7430101, 7430104, 7430107, 7430110, 7430113, 7430116, 7430119, 7430122, 7430125,
  7430156, 7430159, 7430162, 7430165, 7430168, 7430171, 7430174, 7430177, 7430180, 7430183,
  7430186, 7430189, 7430192, 7430196, 7430199, 7430202, 7430205, 7430208, 7430211, 7430230,
  7430233, 7430237, 7430257, 7430268, 7430275, 7430283, 7430294, 7430314, 7430324, 7430333,
  7430336, 7430339, 7430342, 7430345, 7430348, 7430351, 7430354, 7430357, 7430360, 7430363,
  7430366, 7430369, 7430372, 7430375, 7430378, 7430381, 7430384, 7430388, 7430391, 7430394,
  7430397, 7430400, 7430405, 7430416, 7430423, 7430428, 7430431, 7430434, 7430437, 7430440,
  7430443, 7430446, 7430449, 7430452, 7430456, 7430459, 7430462, 7430465, 7430468, 7430471,
  7430474, 7430477, 7430480, 7430483, 7430486, 7430489, 7430492, 7430498, 7430506, 7430512,
  7430516, 7430519, 7430538, 7430547, 7430550, 7430555, 7430561, 7430565, 7430733, 7430740,
  7430751, 7430754, 7430778, 7430781, 7430784, 7430787, 7430790, 7430793, 7430796, 7430799,
  7430864, 7430867, 7430870, 7430881, 7430973, 7430985, 7430989, 7431077, 7431084, 7431087,
  7431093, 7431103, 7431106, 7431109, 7431112, 7431115, 7431119, 7431123, 7440991, 7461759,
}

-- Keep the partial/full UX intact even though no verified critical subset exists yet.
local criticalMuteList = {}

-- Dundun (rat companion + Abundance-event VO). All 39 entries audited from Wago Tools
-- search "Dundun", builds 12.0.0.63534 and 12.0.0.64741. Gaps at _15 and _27 confirmed
-- absent in the community listfile.
local dundunMuteList = {
  7249707, 7251759, 7251762, 7251765, 7251768, 7251771, 7251774, 7251777,
  7251784, 7251787, 7251790, 7251793, 7251796, 7251799,
  7251805, 7251808, 7251811, 7251814, 7251817, 7251820, 7251823, 7251826,
  7251829, 7251836, 7251839, 7251842,
  7251845, 7261433, 7273124, 7273905, 7273906, 7273907, 7273908, 7273909,
  7273910, 7273911,
  7609114, 7609115, 7609116,
}

-- Nanea (Loa Speaker Nanea Revantusk — Nalorakk's Den). All 33 entries audited from
-- Wago Tools search "Nanea", builds 12.0.0.63534, 12.0.0.63854, and 12.0.0.64741.
local naneaMuteList = {
  7272801, 7272803, 7272804, 7272805, 7272806, 7272807, 7272808, 7272809, 7272810,
  7329285, 7329286, 7329292, 7329293, 7329294, 7329295, 7329296, 7329297, 7329298,
  7329299, 7329301, 7329302, 7329304, 7329305, 7329306, 7329307, 7329308,
  7490224, 7490227, 7490229, 7490232, 7490242, 7490245,
  7633293,
}

local function GetTrackedValeeraCompanion()
  for _, unitToken in ipairs(VALEERA_COMPANION_UNIT_TOKENS) do
    local guid = UnitGUIDAPI and UnitGUIDAPI(unitToken)
    if guid then
      return guid, unitToken
    end

    if UnitExistsAPI and UnitExistsAPI(unitToken) then
      return nil, unitToken
    end
  end
end

local function GetBubbleSourceGUID(bubble)
  if not bubble then
    return nil
  end

  for _, methodName in ipairs(BUBBLE_SOURCE_GUID_METHODS) do
    local method = bubble[methodName]
    if type(method) == "function" then
      local ok, value = pcall(method, bubble)
      if ok and type(value) == "string" and value ~= "" then
        return value
      end
    end
  end
end

local function GetBubbleSourceUnitToken(bubble)
  if not bubble then
    return nil
  end

  for _, methodName in ipairs(BUBBLE_SOURCE_TOKEN_METHODS) do
    local method = bubble[methodName]
    if type(method) == "function" then
      local ok, value = pcall(method, bubble)
      if ok and type(value) == "string" and value ~= "" then
        return string.lower(value)
      end
    end
  end
end

local function HideBubbleFrame(bubble)
  if bubble and type(bubble.Hide) == "function" then
    pcall(bubble.Hide, bubble)
  end
end

local function StopSelectiveBubbleSuppression()
  if bubbleTicker then
    bubbleTicker:Cancel()
    bubbleTicker = nil
  end
end

local function RestoreBubbleCVars()
  if forcedBubbleCVar and bubbleCVarBackup and SetCVarAPI then
    suppressOwnCVarUpdate = true
    if bubbleCVarBackup[CHAT_BUBBLE_CVAR] ~= nil then
      pcall(SetCVarAPI, CHAT_BUBBLE_CVAR, bubbleCVarBackup[CHAT_BUBBLE_CVAR])
    end
    suppressOwnCVarUpdate = false
  end

  forcedBubbleCVar = false
  bubbleCVarBackup = nil
end

local function ApplyDelveWideBubbleFallback()
  if not (GetCVarAPI and SetCVarAPI) then
    return false
  end

  if not bubbleCVarBackup then
    bubbleCVarBackup = {
      [CHAT_BUBBLE_CVAR] = GetCVarAPI(CHAT_BUBBLE_CVAR),
    }
  end

  suppressOwnCVarUpdate = true
  local ok = pcall(SetCVarAPI, CHAT_BUBBLE_CVAR, "0")
  suppressOwnCVarUpdate = false

  forcedBubbleCVar = ok
  return ok
end

local function EvaluateSelectiveBubbleSupport()
  if selectiveBubbleSupport == false then
    return false
  end

  if not (C_ChatBubbles and type(C_ChatBubbles.GetAllChatBubbles) == "function") then
    selectiveBubbleSupport = false
    return false
  end

  if not (C_Timer and type(C_Timer.NewTicker) == "function") then
    selectiveBubbleSupport = false
    return false
  end

  local companionGuid, companionUnitToken = GetTrackedValeeraCompanion()
  if not (companionGuid or companionUnitToken) then
    return nil
  end

  local ok, bubbles = pcall(C_ChatBubbles.GetAllChatBubbles)
  if not ok or type(bubbles) ~= "table" then
    selectiveBubbleSupport = false
    return false
  end

  local sawBubble = false
  for _, bubble in ipairs(bubbles) do
    sawBubble = true
    if GetBubbleSourceGUID(bubble) or GetBubbleSourceUnitToken(bubble) then
      selectiveBubbleSupport = true
      return true
    end
  end

  if sawBubble then
    selectiveBubbleSupport = false
    return false
  end

  return nil
end

local function HideSelectiveValeeraBubbles()
  local companionGuid, companionUnitToken = GetTrackedValeeraCompanion()
  if not (companionGuid or companionUnitToken) then
    return true
  end

  local ok, bubbles = pcall(C_ChatBubbles.GetAllChatBubbles)
  if not ok or type(bubbles) ~= "table" then
    selectiveBubbleSupport = false
    return false
  end

  local sawBubble = false
  local sawOwnerMetadata = false

  for _, bubble in ipairs(bubbles) do
    sawBubble = true

    local sourceUnitToken = GetBubbleSourceUnitToken(bubble)
    local sourceGuid = GetBubbleSourceGUID(bubble)
    if not sourceGuid and sourceUnitToken and UnitGUIDAPI then
      sourceGuid = UnitGUIDAPI(sourceUnitToken)
    end

    if sourceUnitToken or sourceGuid then
      sawOwnerMetadata = true
    end

    local tokenMatch = sourceUnitToken and sourceUnitToken == companionUnitToken
    local guidMatch = companionGuid and sourceGuid and sourceGuid == companionGuid
    if tokenMatch or guidMatch then
      HideBubbleFrame(bubble)
    end
  end

  if sawBubble and not sawOwnerMetadata then
    selectiveBubbleSupport = false
    return false
  end

  return true
end

local function StartSelectiveBubbleSuppression()
  if bubbleTicker then
    return true
  end

  if EvaluateSelectiveBubbleSupport() ~= true then
    return false
  end

  bubbleTicker = C_Timer.NewTicker(0.2, function()
    if not HideSelectiveValeeraBubbles() then
      StopSelectiveBubbleSuppression()
      if RefreshBubbleState then
        RefreshBubbleState("selective-unsupported")
      end
    end
  end)

  return HideSelectiveValeeraBubbles()
end

local function IsDelveScenarioType(scenarioType)
  local enum = Enum and Enum.ScenarioType
  local delveType = enum and enum.Delve
  return type(delveType) == "number" and scenarioType == delveType
end

local function IsPlayerInDelve()
  for _, apiTable in ipairs({C_DelvesUI, C_Delves}) do
    if type(apiTable) == "table" then
      for _, methodName in ipairs({"IsInDelve", "IsInActiveDelve", "IsPlayerInDelve"}) do
        local method = apiTable[methodName]
        if type(method) == "function" then
          local ok, value = pcall(method)
          if ok and type(value) == "boolean" then
            return value
          end
        end
      end
    end
  end

  if C_ScenarioInfo and type(C_ScenarioInfo.GetScenarioInfo) == "function" then
    local ok, info = pcall(C_ScenarioInfo.GetScenarioInfo)
    if ok and type(info) == "table" then
      if info.isDelve == true then
        return true
      end

      if IsDelveScenarioType(info.scenarioType or info.type) then
        return true
      end
    end
  end

  if type(GetScenarioInfo) == "function" then
    local ok, _, _, _, _, _, _, _, _, scenarioType = pcall(GetScenarioInfo)
    if ok and IsDelveScenarioType(scenarioType) then
      return true
    end
  end

  return false
end

local function UpdateDelveState()
  isInDelve = IsPlayerInDelve()
  return isInDelve
end

local function ApplyBubbleStrategy(strategy)
  if strategy ~= activeBubbleStrategy then
    StopSelectiveBubbleSuppression()
    RestoreBubbleCVars()
    activeBubbleStrategy = "off"
  end

  if strategy == "valeera-only" then
    if StartSelectiveBubbleSuppression() then
      activeBubbleStrategy = "valeera-only"
      return
    end

    strategy = isInDelve and "delve-wide" or "off"
  end

  if strategy == "delve-wide" then
    if ApplyDelveWideBubbleFallback() then
      activeBubbleStrategy = "delve-wide"
      return
    end
  end

  activeBubbleStrategy = "off"
end

RefreshBubbleState = function(reason)
  if not isInitialized then
    return
  end

  UpdateDelveState()

  local shouldSuppressBubbles = settings.isMuted and settings.muteBubbles
  local strategy = "off"
  if shouldSuppressBubbles then
    local support = EvaluateSelectiveBubbleSupport()
    if support == true then
      strategy = "valeera-only"
    elseif isInDelve then
      strategy = "delve-wide"
    end
  end

  ApplyBubbleStrategy(strategy)
end

local function GetBubbleStatusSummary()
  return {
    enabled = settings.muteBubbles and "ON" or "OFF",
    strategy = activeBubbleStrategy,
    delve = isInDelve and "YES" or "NO",
  }
end


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

  if settings.bubbleFallbackMode ~= "auto" then
    settings.bubbleFallbackMode = "auto"
  end

  if oldVersion ~= ADDON_VERSION then
    settings.version = ADDON_VERSION
  end
  
  -- Cache settings locally for performance
  isMuted = settings.isMuted
  muteCritical = settings.muteCritical
  muteBubbles = settings.muteBubbles
  muteDundun = settings.muteDundun
  muteNanea = settings.muteNanea
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

  -- Add Dundun sounds if enabled
  if muteDundun then
    for _, id in ipairs(dundunMuteList) do
      seen[id] = true
    end
  end

  -- Add Nanea sounds if enabled
  if muteNanea then
    for _, id in ipairs(naneaMuteList) do
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
    local bubbleStatus = GetBubbleStatusSummary()
    print(("MuteValeera Status - Mute: %s, Critical: %s, Bubbles: %s, Strategy: %s, Dundun: %s, Nanea: %s, In delve: %s, Total sounds: %d"):format(
      isMuted and "ON" or "OFF",
      muteCritical and "YES" or "NO",
      bubbleStatus.enabled,
      bubbleStatus.strategy,
      muteDundun and "ON" or "OFF",
      muteNanea and "ON" or "OFF",
      bubbleStatus.delve,
      isMuted and muteCount or 0
    ))
    return

  elseif cmd == "bubbles" then
    local bubbleCmd = args[2] and string.lower(args[2]) or "status"
    local bubbleStatus = GetBubbleStatusSummary()

    if bubbleCmd == "on" then
      settings.muteBubbles, muteBubbles = true, true
      RefreshBubbleState("slash-bubbles-on")
      bubbleStatus = GetBubbleStatusSummary()
      print(("MuteValeera: Speech bubble suppression enabled. Active strategy: %s."):format(bubbleStatus.strategy))
      return

    elseif bubbleCmd == "off" then
      settings.muteBubbles, muteBubbles = false, false
      RefreshBubbleState("slash-bubbles-off")
      print("MuteValeera: Speech bubble suppression disabled.")
      return

    elseif bubbleCmd == "toggle" then
      muteBubbles = not muteBubbles
      settings.muteBubbles = muteBubbles
      RefreshBubbleState("slash-bubbles-toggle")
      bubbleStatus = GetBubbleStatusSummary()
      print(("MuteValeera: Speech bubble suppression %s. Active strategy: %s."):format(
        muteBubbles and "enabled" or "disabled",
        bubbleStatus.strategy
      ))
      return

    elseif bubbleCmd == "status" then
      print(("MuteValeera Bubble Status - Enabled: %s, Strategy: %s, In delve: %s"):format(
        bubbleStatus.enabled,
        bubbleStatus.strategy,
        bubbleStatus.delve
      ))
      return
    end

    print(("MuteValeera: Unknown bubbles command '%s'"):format(bubbleCmd))
    print("  Use '/mutevaleera bubbles on', 'off', 'toggle', or 'status'")
    return

  elseif cmd == "dundun" then
    local subCmd = args[2] and string.lower(args[2]) or "status"

    if subCmd == "on" then
      settings.muteDundun, muteDundun = true, true
      print("MuteValeera: Dundun muted.")
    elseif subCmd == "off" then
      settings.muteDundun, muteDundun = false, false
      print("MuteValeera: Dundun unmuted.")
    elseif subCmd == "toggle" then
      muteDundun = not muteDundun
      settings.muteDundun = muteDundun
      print(("MuteValeera: Dundun mute toggled %s"):format(muteDundun and "ON" or "OFF"))
    elseif subCmd == "status" then
      print(("MuteValeera Dundun: %s"):format(muteDundun and "ON" or "OFF"))
      return
    else
      print(("MuteValeera: Unknown dundun command '%s'"):format(subCmd))
      print("  Use '/mutevaleera dundun on', 'off', 'toggle', or 'status'")
      return
    end

  elseif cmd == "nanea" then
    local subCmd = args[2] and string.lower(args[2]) or "status"

    if subCmd == "on" then
      settings.muteNanea, muteNanea = true, true
      print("MuteValeera: Nanea muted.")
    elseif subCmd == "off" then
      settings.muteNanea, muteNanea = false, false
      print("MuteValeera: Nanea unmuted.")
    elseif subCmd == "toggle" then
      muteNanea = not muteNanea
      settings.muteNanea = muteNanea
      print(("MuteValeera: Nanea mute toggled %s"):format(muteNanea and "ON" or "OFF"))
    elseif subCmd == "status" then
      print(("MuteValeera Nanea: %s"):format(muteNanea and "ON" or "OFF"))
      return
    else
      print(("MuteValeera: Unknown nanea command '%s'"):format(subCmd))
      print("  Use '/mutevaleera nanea on', 'off', 'toggle', or 'status'")
      return
    end

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
    print("  Bubbles: bubbles on | bubbles off | bubbles toggle | bubbles status")
    print("  NPCs: dundun on|off|toggle|status | nanea on|off|toggle|status")
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
    print("    bubbles <mode> - Control speech bubble suppression")
    print("    dundun on|off|toggle|status - Mute Dundun voice lines")
    print("    nanea on|off|toggle|status - Mute Nanea voice lines")
    print("  Custom Sound IDs:")
    print("    add <ids> - Add custom sound IDs")
    print("    del <ids> - Remove custom sound IDs")
    print("    list - Show all custom sound IDs")
    print("    clear - Clear all custom IDs (requires confirmation)")
    print("  Advanced:")
    print("    bubbles on|off|toggle|status - Speech bubble controls")
    print("    validate - Check custom IDs for potential issues")
    print("    export - Copy custom IDs for backup/sharing")
    print("    import <ids> - Import custom IDs from string")
    print("    ui - Open settings panel")
    print("  Examples:")
    print("    /mutevaleera add 12345,67890")
    print("    /mutevaleera add 12345 67890 11111")
    print("    /mutevaleera bubbles toggle")
    print("    /mv toggle")
    print("    /mutevaleera import 12345,67890,11111")
    return
    
  else
    print(("MuteValeera: Unknown command '%s'"):format(cmd))
    print("  Use '/mutevaleera help' for commands or '/mutevaleera helpfull' for detailed help")
    return
  end

  ApplyMuteState()
  RefreshBubbleState("command")
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
    desc:SetText("Silences Valeera Sanguinar's repetitive delve companion voice lines and can suppress her speech bubbles in delves.")
    desc:SetJustifyH("LEFT")
    desc:SetWidth(500)
    
    -- Helper: create a checkbox with clickable label and inline description
    local function CreateCheckbox(parent, anchor, label, descText, getFunc, setFunc)
      local container = CreateFrame("Frame", nil, parent)
      container:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
      container:SetSize(500, 52)
      
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
        RefreshBubbleState("settings-sound-toggle")
      end
    )

    local bubbleCheck = CreateCheckbox(
      panel, muteCheck,
      "Mute Valeera speech bubbles",
      "Attempts to hide Valeera's speech bubbles. If selective hiding is unavailable on this client, the addon hides world chat bubbles while you are in delves and restores your previous setting outside.",
      function() return settings.muteBubbles end,
      function(val)
        settings.muteBubbles = val
        muteBubbles = val
        RefreshBubbleState("settings-bubbles-toggle")
      end
    )
    
    -- Mute Critical Lines checkbox
    local criticalCheck = CreateCheckbox(
      panel, bubbleCheck,
      "Also mute critical/important lines",
      "Include critical gameplay-related voice lines (e.g., boss warnings) in muting.",
      function() return settings.muteCritical end,
      function(val)
        settings.muteCritical = val
        muteCritical = val
        ApplyMuteState()
      end
    )
    
    -- Mute Dundun checkbox
    local dundunCheck = CreateCheckbox(
      panel, criticalCheck,
      "Mute Dundun voice lines",
      "Silence Dundun (rat companion) in Abundance events and other content.",
      function() return settings.muteDundun end,
      function(val)
        settings.muteDundun = val
        muteDundun = val
        ApplyMuteState()
      end
    )

    -- Mute Nanea checkbox
    local naneaCheck = CreateCheckbox(
      panel, dundunCheck,
      "Mute Nanea voice lines",
      "Silence Loa Speaker Nanea Revantusk in Nalorakk's Den.",
      function() return settings.muteNanea end,
      function(val)
        settings.muteNanea = val
        muteNanea = val
        ApplyMuteState()
      end
    )

    -- Custom Sound IDs section
    local customHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    customHeader:SetPoint("TOPLEFT", naneaCheck, "BOTTOMLEFT", 0, -20)
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
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("SCENARIO_UPDATE")
eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("CVAR_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
  if event == "ADDON_LOADED" and addonName == ADDON_NAME then
    InitializeSettings()
    ApplyMuteState()
    RefreshBubbleState("addon-loaded")
    
  elseif event == "PLAYER_LOGIN" then
    UpdateDelveState()
    RefreshBubbleState("player-login")
    C_Timer.After(1, function()
      RegisterSettings()
    end)
    
    self:UnregisterEvent("ADDON_LOADED")
    self:UnregisterEvent("PLAYER_LOGIN")

  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "SCENARIO_UPDATE" or event == "SCENARIO_CRITERIA_UPDATE" then
    UpdateDelveState()
    RefreshBubbleState(event)

  elseif event == "CVAR_UPDATE" then
    local cvarName = string.lower(tostring(addonName or ""))
    if not suppressOwnCVarUpdate and cvarName == string.lower(CHAT_BUBBLE_CVAR) and activeBubbleStrategy == "delve-wide" then
      ApplyDelveWideBubbleFallback()
    end

  elseif event == "PLAYER_LOGOUT" then
    StopSelectiveBubbleSuppression()
    RestoreBubbleCVars()
  end
end)
