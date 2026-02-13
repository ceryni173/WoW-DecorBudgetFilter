-- DecorBudgetFilter.lua
-- Filter Housing Storage/Catalog by *placement budget cost* (house icon: 1 / 3 / 5)
-- Behaviour: show ONLY items whose placementCost == selected value.
-- Includes "All" option to disable filtering and show everything.
--
-- Built to work with:
--   HouseEditorFrame.StoragePanel.OptionsContainer.ScrollBox:ForEachFrame(...)
-- where each element commonly has element.entryInfo.

-- Protect against nil/corrupted saved variables
if type(DecorBudgetFilterDB) ~= "table" then
  DecorBudgetFilterDB = {}
end

DecorBudgetFilterDB = DecorBudgetFilterDB or {}
DecorBudgetFilterDB.budget = DecorBudgetFilterDB.budget or 0
DecorBudgetFilterDB.showUnknown = DecorBudgetFilterDB.showUnknown or false
DecorBudgetFilterDB.debug = DecorBudgetFilterDB.debug or false

-- Cache for placement cost lookups
local costCache = {}
local CACHE_MAX_SIZE = 500
local cacheSize = 0

-- Debounce timer for filter application
local filterTimer = nil
local FILTER_DELAY = 0.05

-- Item count tracking
local lastFilterStats = {touched = 0, shown = 0, hidden = 0, unknown = 0}

local function dbg(...)
  if DecorBudgetFilterDB and DecorBudgetFilterDB.debug then
    print("|cff66ccffDecorBudgetFilter:|r", ...)
  end
end

local function normalizeBudget(v)
  if type(v) == "string" then
    local lower = v:lower()
    if lower == "all" then return 0 end
    v = tonumber(v)
  end

  if type(v) ~= "number" then return 0 end
  if v < 0 or v > 1000 then return 0 end

  if v == 0 then return 0 end
  if v == 1 or v == 3 or v == 5 then return v end
  if v <= 1 then return 1 end
  if v <= 3 then return 3 end
  return 5
end

-- Validate and normalize saved budget on load
DecorBudgetFilterDB.budget = normalizeBudget(DecorBudgetFilterDB.budget)

-- Clear cache when it gets too large
local function ClearCostCache()
  wipe(costCache)
  cacheSize = 0
end

-- Get placement cost from entryInfo with simple caching
local function GetCostFromEntryInfo(entryInfo)
  if type(entryInfo) ~= "table" then return nil end

  -- Generate simple cache key
  local key = tostring(entryInfo.itemID or entryInfo.recordID or entryInfo.entryID or "")
  if key == "" then return nil end

  -- Return cached value if available
  if costCache[key] ~= nil then
    return costCache[key]
  end

  -- Read placement cost directly
  local cost = nil
  if type(entryInfo.placementCost) == "number" then
    cost = entryInfo.placementCost
  end

  -- Cache the result
  if cost ~= nil then
    costCache[key] = cost
    cacheSize = cacheSize + 1
    if cacheSize > CACHE_MAX_SIZE then
      ClearCostCache()
    end
  end

  return cost
end

-- ---------------------------------------------------------------------------
-- ScrollBox discovery
-- ---------------------------------------------------------------------------

local function GetStorageScrollBox()
  local panel = _G.HouseEditorFrame and _G.HouseEditorFrame.StoragePanel
  if not panel then return nil end
  local oc = panel.OptionsContainer
  if not oc then return nil end
  local sb = oc.ScrollBox
  if sb and sb.ForEachFrame then return sb end
  return nil
end

-- ---------------------------------------------------------------------------
-- Filtering logic (EQUALS selected value, or All)
-- ---------------------------------------------------------------------------

local function ApplyBudgetFilter()
  local sb = GetStorageScrollBox()
  if not sb then
    dbg("No StoragePanel.OptionsContainer.ScrollBox yet")
    return
  end

  local selected = normalizeBudget(DecorBudgetFilterDB.budget)

  -- All = show everything, no other logic
  if selected == 0 then
    sb:ForEachFrame(function(element)
      if element and element.Show then
        element:Show()
      end
    end)
    dbg("Filter: All (no filtering)")
    return
  end

  local showUnknown = DecorBudgetFilterDB.showUnknown == true
  local touched, shown, hidden, unknown = 0, 0, 0, 0

  sb:ForEachFrame(function(element)
    -- Safety check
    if not element then return end

    local entryInfo = element.entryInfo

    -- Fallback: some builds store it in elementData
    if not entryInfo and element.GetElementData then
      local ok, data = pcall(element.GetElementData, element)
      if ok and type(data) == "table" then
        entryInfo = data.entryInfo or data
      end
    end

    local cost = GetCostFromEntryInfo(entryInfo)
    touched = touched + 1

    if cost == nil then
      unknown = unknown + 1
      if showUnknown then
        if element.Show then element:Show() end
        shown = shown + 1
      else
        if element.Hide then element:Hide() end
        hidden = hidden + 1
      end
      return
    end

    if cost == selected then
      if element.Show then element:Show() end
      shown = shown + 1
    else
      if element.Hide then element:Hide() end
      hidden = hidden + 1
    end
  end)

  dbg(("Filter budget=%d touched=%d shown=%d hidden=%d unknown=%d"):format(selected, touched, shown, hidden, unknown))

  -- Store stats for UI display
  lastFilterStats.touched = touched
  lastFilterStats.shown = shown
  lastFilterStats.hidden = hidden
  lastFilterStats.unknown = unknown

  -- Update count label if it exists
  local panel = _G.HouseEditorFrame and _G.HouseEditorFrame.StoragePanel
  if panel and panel.DecorBudgetFilter and panel.DecorBudgetFilter.CountLabel then
    local countLabel = panel.DecorBudgetFilter.CountLabel
    if selected == 0 then
      countLabel:SetText(string.format("|cff888888Showing all %d items|r", touched))
    else
      countLabel:SetText(string.format("|cff888888Showing %d/%d items|r", shown, touched))
    end
  end
end

-- Debounced version to prevent excessive filter applications
local function ApplyBudgetFilterDebounced()
  if filterTimer then
    filterTimer:Cancel()
  end
  filterTimer = C_Timer.NewTimer(FILTER_DELAY, ApplyBudgetFilter)
end

local function HookScrollBoxRefreshes()
  local sb = GetStorageScrollBox()
  if not sb or sb.DecorBudgetFilterHooked then return end
  sb.DecorBudgetFilterHooked = true

  -- Use debounced version to prevent excessive filter calls
  if sb.Update then
    hooksecurefunc(sb, "Update", ApplyBudgetFilterDebounced)
  end
  if sb.FullUpdate then
    hooksecurefunc(sb, "FullUpdate", ApplyBudgetFilterDebounced)
  end

  dbg("Hooked ScrollBox refreshes")
end

-- ---------------------------------------------------------------------------
-- UI: add dropdown as a "floating" control above the modal (always visible)
-- ---------------------------------------------------------------------------

local function CreateBudgetUI()
  local panel = _G.HouseEditorFrame and _G.HouseEditorFrame.StoragePanel
  if not panel then
    dbg("CreateBudgetUI: No StoragePanel found")
    return
  end
  if panel.DecorBudgetFilter then
    dbg("CreateBudgetUI: UI already exists")
    return
  end
  if not panel.SearchBox then
    dbg("CreateBudgetUI: No SearchBox found")
    return
  end

  dbg("CreateBudgetUI: Creating UI...")
  local dd = CreateFrame("Frame", "DecorBudgetFilterDropdown", panel, "UIDropDownMenuTemplate")
  dd:ClearAllPoints()
  -- Position above the main content area, floating at the top (positive Y moves UP)
  dd:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, 40)

  dd:SetFrameStrata("DIALOG")
  dd:SetFrameLevel((panel:GetFrameLevel() or 0) + 80)
  dd:SetClampedToScreen(true)

  panel.DecorBudgetFilter = dd

  -- Enhanced label with color - always shows current budget
  local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  label:ClearAllPoints()
  label:SetPoint("RIGHT", dd, "LEFT", 6, 2)
  local budgetText = DecorBudgetFilterDB.budget == 0 and "|cff00ff00All|r" or "|cffffd100" .. DecorBudgetFilterDB.budget .. "|r"
  label:SetText("|cff66ccffBudget:|r " .. budgetText)
  label:SetDrawLayer("OVERLAY")

  -- Store label reference for updates
  dd.BudgetLabel = label

  -- Add item count label below the budget label
  local countLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  countLabel:ClearAllPoints()
  countLabel:SetPoint("TOP", label, "BOTTOM", 0, -2)
  countLabel:SetText("|cff888888Showing all items|r")
  countLabel:SetDrawLayer("OVERLAY")
  dd.CountLabel = countLabel

  -- Add tooltip to dropdown
  dd:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Decor Placement Budget Filter", 1, 1, 1)
    GameTooltip:AddLine("Filter items by their placement cost", nil, nil, nil, true)
    GameTooltip:AddLine(" ", nil, nil, nil, true)
    GameTooltip:AddLine("|cff00ff00All|r - Show all items", nil, nil, nil, true)
    GameTooltip:AddLine("|cffffd1001, 3, 5|r - Show only items with this cost", nil, nil, nil, true)
    GameTooltip:AddLine("|cffaaaaaa ", nil, nil, nil, true)
    GameTooltip:AddLine("|cffaaaaaa(Right-click to clear filter)|r", nil, nil, nil, true)
    GameTooltip:Show()
  end)
  dd:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  -- Right-click to clear filter
  dd:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and DecorBudgetFilterDB.budget ~= 0 then
      DecorBudgetFilterDB.budget = 0
      UIDropDownMenu_SetSelectedValue(dd, 0)
      local budgetText = "|cff00ff00All|r"
      label:SetText("|cff66ccffBudget:|r " .. budgetText)
      ApplyBudgetFilterDebounced()
      print("|cff66ccffDecorBudgetFilter:|r Filter cleared")
    end
  end)

  local function OnSelect(self)
    DecorBudgetFilterDB.budget = normalizeBudget(self.value)
    UIDropDownMenu_SetSelectedValue(dd, DecorBudgetFilterDB.budget)
    ApplyBudgetFilterDebounced()

    -- Update label to always show current budget
    local budgetText = DecorBudgetFilterDB.budget == 0 and "|cff00ff00All|r" or "|cffffd100" .. DecorBudgetFilterDB.budget .. "|r"
    label:SetText("|cff66ccffBudget:|r " .. budgetText)
  end

  UIDropDownMenu_Initialize(dd, function()
    local title = UIDropDownMenu_CreateInfo()
    title.isTitle = true
    title.text = "|cff66ccffPlacement Budget Filter|r"
    title.notCheckable = true
    UIDropDownMenu_AddButton(title)

    -- All option with color
    local all = UIDropDownMenu_CreateInfo()
    all.text = "|cff00ff00All (No Filter)|r"
    all.value = 0
    all.func = OnSelect
    all.checked = (DecorBudgetFilterDB.budget == 0)
    UIDropDownMenu_AddButton(all)

    -- Exact tiers with colors and descriptions
    local tierColors = {
      [1] = "|cff90ee90",  -- Light green
      [3] = "|cffffd100",  -- Gold
      [5] = "|cffff6b6b",  -- Light red
    }
    for _, v in ipairs({1, 3, 5}) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = tierColors[v] .. v .. "|r"
      info.value = v
      info.func = OnSelect
      info.checked = (DecorBudgetFilterDB.budget == v)
      UIDropDownMenu_AddButton(info)
    end

    -- Separator
    local sep = UIDropDownMenu_CreateInfo()
    sep.disabled = true
    sep.notCheckable = true
    sep.text = "---------------"
    UIDropDownMenu_AddButton(sep)

    -- Unknown cost toggle with better styling
    local unk = UIDropDownMenu_CreateInfo()
    local checkMark = DecorBudgetFilterDB.showUnknown and "|cff00ff00✓|r " or "|cff888888○|r "
    unk.text = checkMark .. "Show Unknown Cost"
    unk.notCheckable = true
    unk.func = function()
      DecorBudgetFilterDB.showUnknown = not (DecorBudgetFilterDB.showUnknown == true)
      ApplyBudgetFilterDebounced()
      CloseDropDownMenus()
    end
    unk.tooltipTitle = "Show Unknown Cost Items"
    unk.tooltipText = "When enabled, items without a detectable placement cost will be shown regardless of filter."
    UIDropDownMenu_AddButton(unk)
  end)

  UIDropDownMenu_SetWidth(dd, 70)
  UIDropDownMenu_SetSelectedValue(dd, DecorBudgetFilterDB.budget)

  -- Ensure the dropdown and label are visible
  dd:Show()
  label:Show()
  countLabel:Show()

  dbg("Budget UI created successfully - dropdown should be visible")
end

-- ---------------------------------------------------------------------------
-- Init: wait for StoragePanel to exist, hook OnShow
-- ---------------------------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  print("|cff66ccffDecorBudgetFilter|r v0.4.1 loaded - Type |cffffd100/decorbudget|r for help")

  local hookAttempts = 0
  local MAX_HOOK_ATTEMPTS = 60  -- Stop after 30 seconds

  local function tryHook()
    hookAttempts = hookAttempts + 1

    if not (_G.HouseEditorFrame and _G.HouseEditorFrame.StoragePanel) then
      -- Stop trying after max attempts to prevent infinite polling
      if hookAttempts < MAX_HOOK_ATTEMPTS then
        C_Timer.After(0.5, tryHook)
      else
        dbg("Max hook attempts reached - HouseEditorFrame not found")
      end
      return
    end

    local panel = _G.HouseEditorFrame.StoragePanel
    if panel.DecorBudgetHookedShow then return end
    panel.DecorBudgetHookedShow = true

    panel:HookScript("OnShow", function()
      CreateBudgetUI()
      HookScrollBoxRefreshes()
      ApplyBudgetFilterDebounced()
    end)

    if panel:IsShown() then
      CreateBudgetUI()
      HookScrollBoxRefreshes()
      ApplyBudgetFilterDebounced()
    end

    dbg("Successfully hooked HouseEditorFrame.StoragePanel")
  end

  tryHook()
end)

SLASH_DECORBUDGETFILTER1 = "/decorbudget"
SLASH_DECORBUDGETFILTER2 = "/dbf"
SlashCmdList.DECORBUDGETFILTER = function(msg)
  if type(msg) ~= "string" then msg = "" end
  msg = msg:gsub("^%s+", ""):gsub("%s+$", ""):lower()

  if msg == "" or msg == "help" then
    print("|cff66ccffDecorBudgetFilter v0.4.1|r")
    print("Usage: |cffffd100/decorbudget|r [all|1|3|5|cache|stats]")
    print("  |cff00ff00all|r - Show all items (no filter)")
    print("  |cff90ee901|r - Show only budget 1 items")
    print("  |cffffd1003|r - Show only budget 3 items")
    print("  |cffff6b6b5|r - Show only budget 5 items")
    print("  |cffaaaaaa cache|r - Show cache statistics")
    print("  |cffaaaaaa stats|r - Show filter statistics")
    print("Current filter: " .. (DecorBudgetFilterDB.budget == 0 and "|cff00ff00All|r" or "|cffffd100" .. DecorBudgetFilterDB.budget .. "|r"))
    return
  end

  if msg == "all" then
    DecorBudgetFilterDB.budget = 0
    print("|cff66ccffDecorBudgetFilter:|r Budget set to |cff00ff00All|r (no filter)")
    ApplyBudgetFilterDebounced()
    return
  end

  if msg == "clear" or msg == "reset" then
    DecorBudgetFilterDB.budget = 0
    DecorBudgetFilterDB.showUnknown = false
    print("|cff66ccffDecorBudgetFilter:|r Settings reset to defaults")
    ApplyBudgetFilterDebounced()
    return
  end

  if msg == "debug" then
    DecorBudgetFilterDB.debug = not DecorBudgetFilterDB.debug
    print("|cff66ccffDecorBudgetFilter:|r Debug mode " .. (DecorBudgetFilterDB.debug and "|cff00ff00enabled|r" or "|cffff6b6bdisabled|r"))
    return
  end

  if msg == "cache" then
    print("|cff66ccffDecorBudgetFilter Cache:|r")
    print(string.format("  Entries: |cffffd100%d|r / %d", cacheSize, CACHE_MAX_SIZE))
    if cacheSize > CACHE_MAX_SIZE * 0.9 then
      print("|cffaaaaaa  Cache will clear when full|r")
    end
    return
  end

  if msg == "stats" then
    print("|cff66ccffDecorBudgetFilter Statistics:|r")
    print(string.format("  Last filter: Budget %s", DecorBudgetFilterDB.budget == 0 and "|cff00ff00All|r" or "|cffffd100" .. DecorBudgetFilterDB.budget .. "|r"))
    print(string.format("  Items touched: |cffffd100%d|r", lastFilterStats.touched))
    print(string.format("  Items shown: |cff00ff00%d|r", lastFilterStats.shown))
    print(string.format("  Items hidden: |cffaaaaaa%d|r", lastFilterStats.hidden))
    if lastFilterStats.unknown > 0 then
      print(string.format("  Unknown cost: |cffff6b6b%d|r", lastFilterStats.unknown))
    end
    return
  end

  local n = tonumber(msg)
  if n then
    local oldBudget = DecorBudgetFilterDB.budget
    DecorBudgetFilterDB.budget = normalizeBudget(n)

    if oldBudget ~= DecorBudgetFilterDB.budget then
      local budgetText = DecorBudgetFilterDB.budget == 0 and "|cff00ff00All|r" or "|cffffd100" .. DecorBudgetFilterDB.budget .. "|r"
      print("|cff66ccffDecorBudgetFilter:|r Budget set to " .. budgetText)
      ApplyBudgetFilterDebounced()
    end
  else
    print("|cffff6b6bDecorBudgetFilter:|r Invalid input. Type |cffffd100/decorbudget help|r for usage")
  end
end
