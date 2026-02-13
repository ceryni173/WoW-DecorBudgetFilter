-- DecorBudgetFilter.lua v2.0.0
-- Filters housing catalog items by placement budget cost (1 / 3 / 5 / All)
--
-- Works on both:
--   HouseEditorFrame.StoragePanel (in-house editor)
--   HousingDashboardFrame.CatalogContent (dashboard catalog)
--
-- Uses Blizzard's catalog data pipeline (SetCatalogData) instead of Show/Hide.
-- Adds a modern WowStyle1DropdownTemplate next to Blizzard's filter button.

-- ---------------------------------------------------------------------------
-- 1. SAVED VARIABLES + CONSTANTS
-- ---------------------------------------------------------------------------

local ADDON_NAME = "DecorBudgetFilter"
local VERSION = "2.0.0"

-- Protect against nil/corrupted saved variables
if type(DecorBudgetFilterDB) ~= "table" then
  DecorBudgetFilterDB = {}
end

DecorBudgetFilterDB.budget = DecorBudgetFilterDB.budget or 0
DecorBudgetFilterDB.debug = DecorBudgetFilterDB.debug or false

local BUDGET_TIERS = {1, 3, 5}

local function dbg(...)
  if DecorBudgetFilterDB and DecorBudgetFilterDB.debug then
    print("|cff66ccffDBF:|r", ...)
  end
end

local function NormalizeBudget(v)
  if type(v) == "string" then
    if v:lower() == "all" then return 0 end
    v = tonumber(v)
  end
  if type(v) ~= "number" then return 0 end
  if v == 0 or v == 1 or v == 3 or v == 5 then return v end
  return 0
end

DecorBudgetFilterDB.budget = NormalizeBudget(DecorBudgetFilterDB.budget)

-- ---------------------------------------------------------------------------
-- 2. CORE FILTER FUNCTION
-- ---------------------------------------------------------------------------

local function FilterEntriesByBudget(entries, budget)
  if budget == 0 or not entries then return entries end
  local filtered = {}
  for i = 1, #entries do
    local info = C_HousingCatalog.GetCatalogEntryInfo(entries[i])
    if info and info.placementCost == budget then
      filtered[#filtered + 1] = entries[i]
    end
  end
  return filtered
end

-- ---------------------------------------------------------------------------
-- 3. POST-FILTER HOOK (runs after Blizzard's UpdateCatalogData)
-- ---------------------------------------------------------------------------

local function ApplyBudgetPostFilter(self)
  local budget = DecorBudgetFilterDB.budget
  if budget == 0 then return end
  if not self:IsShown() then return end
  if self.customCatalogData then return end

  -- Skip featured/bundles category (StorageFrame only)
  if self.Categories and self.Categories.IsFeaturedCategoryFocused
     and self.Categories:IsFeaturedCategoryFocused() then
    return
  end

  if not self.catalogSearcher then return end

  local entries = self.catalogSearcher:GetCatalogSearchResults()
  if not entries then return end

  local filtered = FilterEntriesByBudget(entries, budget)
  self.OptionsContainer:SetCatalogData(filtered, true)

  dbg("Filtered:", #filtered, "/", #entries, "budget:", budget)
end

-- ---------------------------------------------------------------------------
-- 4. UI: BUDGET DROPDOWN (WowStyle1DropdownTemplate)
-- ---------------------------------------------------------------------------

local hookedFrames = {}

local function RefreshAllCatalogs()
  for frame in pairs(hookedFrames) do
    if frame and frame:IsShown() and frame.UpdateCatalogData then
      frame:UpdateCatalogData()
    end
  end
end

local function CreateBudgetDropdown(catalogFrame, name)
  if not catalogFrame or not catalogFrame.Filters then return end
  if catalogFrame._dbfDropdown then return end

  local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil,
                             catalogFrame, "WowStyle1DropdownTemplate")
  if not ok or not dropdown then
    dbg("Failed to create WowStyle1DropdownTemplate for", name)
    return
  end

  dropdown:SetWidth(110)

  -- Re-anchor the header lane: [SearchBox] -- [DBF Dropdown] -- [Filters]
  -- The two catalog frames use opposite anchoring strategies so we handle each.
  local searchBox = catalogFrame.SearchBox
  local filters   = catalogFrame.Filters

  if name == "StoragePanel" then
    -- Storage: SearchBox stretches L->R, Filters anchored to SearchBox.
    -- Break the chain and re-anchor to make room for the dropdown.
    --   XML originals:
    --     SearchBox  TOPLEFT(20,-20)  TOPRIGHT(-160,-20)  h=30
    --     Filters    LEFT(SearchBox.RIGHT+10)  RIGHT(parent-25)  h=20

    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", 20, -20)
    searchBox:SetPoint("TOPRIGHT", -270, -20)   -- narrower (was -160)
    searchBox:SetHeight(30)

    dropdown:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)

    filters:ClearAllPoints()
    filters:SetPoint("LEFT", dropdown, "RIGHT", 6, 0)
    filters:SetSize(100, 20)
  else
    -- Dashboard: Filters fixed at TOPRIGHT, SearchBox anchored to Filters.
    --   XML originals:
    --     Filters    TOPRIGHT(-10,-30)  100x20
    --     SearchBox  RIGHT(Filters.LEFT-10)  150x30

    dropdown:SetPoint("RIGHT", filters, "LEFT", -6, 0)

    searchBox:ClearAllPoints()
    searchBox:SetPoint("RIGHT", dropdown, "LEFT", -6, 0)
    searchBox:SetSize(150, 30)
  end

  -- Menu setup
  dropdown:SetupMenu(function(dd, rootDescription)
    rootDescription:SetTag("DBF_BUDGET_FILTER")
    rootDescription:CreateTitle("Placement Budget")

    -- "All" option
    rootDescription:CreateRadio(
      "All Costs",
      function() return DecorBudgetFilterDB.budget == 0 end,
      function()
        DecorBudgetFilterDB.budget = 0
        RefreshAllCatalogs()
      end
    )

    -- Budget tiers
    for _, cost in ipairs(BUDGET_TIERS) do
      rootDescription:CreateRadio(
        "Budget " .. cost,
        function() return DecorBudgetFilterDB.budget == cost end,
        function()
          DecorBudgetFilterDB.budget = cost
          RefreshAllCatalogs()
        end
      )
    end
  end)

  catalogFrame._dbfDropdown = dropdown
  dbg("Created dropdown on", name)
end

-- ---------------------------------------------------------------------------
-- 5. INITIALIZATION
-- ---------------------------------------------------------------------------

local function HookFrame(frame, name)
  if not frame or hookedFrames[frame] then return false end
  hookedFrames[frame] = true

  hooksecurefunc(frame, "UpdateCatalogData", ApplyBudgetPostFilter)

  -- Create dropdown now if frame is visible, otherwise on first show
  if frame:IsShown() then
    CreateBudgetDropdown(frame, name)
  end
  frame:HookScript("OnShow", function(self)
    CreateBudgetDropdown(self, name)
  end)

  dbg("Hooked", name)
  return true
end

local function TryHookStoragePanel()
  local panel = HouseEditorFrame and HouseEditorFrame.StoragePanel
  if panel then
    return HookFrame(panel, "StoragePanel")
  end
  return false
end

local function TryHookDashboard()
  local catalog = HousingDashboardFrame and HousingDashboardFrame.CatalogContent
  if catalog then
    return HookFrame(catalog, "Dashboard")
  end
  return false
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_HouseEditor" then
      if not TryHookStoragePanel() then
        C_Timer.After(0, TryHookStoragePanel)
      end
    elseif arg1 == "Blizzard_HousingDashboard" then
      if not TryHookDashboard() then
        C_Timer.After(0, TryHookDashboard)
      end
    end

  elseif event == "PLAYER_LOGIN" then
    -- Handle already-loaded addons (e.g. after /reload)
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if isLoaded("Blizzard_HouseEditor") then
      TryHookStoragePanel()
    end
    if isLoaded("Blizzard_HousingDashboard") then
      TryHookDashboard()
    end

    print("|cff66ccffDecorBudgetFilter|r v" .. VERSION .. " loaded - |cffffd100/dbf|r for help")
  end
end)

-- ---------------------------------------------------------------------------
-- 6. SLASH COMMANDS
-- ---------------------------------------------------------------------------

SLASH_DECORBUDGETFILTER1 = "/decorbudget"
SLASH_DECORBUDGETFILTER2 = "/dbf"
SlashCmdList.DECORBUDGETFILTER = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()

  if msg == "" or msg == "help" then
    print("|cff66ccffDecorBudgetFilter v" .. VERSION .. "|r")
    print("Usage: |cffffd100/dbf|r [all|1|3|5|debug]")
    print("  |cff00ff00all|r - Show all items (no filter)")
    print("  |cff90ee901|r - Show only budget 1 items")
    print("  |cffffd1003|r - Show only budget 3 items")
    print("  |cffff6b6b5|r - Show only budget 5 items")
    print("  |cffaaaaaadebug|r - Toggle debug output")
    print("Current: " .. (DecorBudgetFilterDB.budget == 0 and "|cff00ff00All|r"
          or "|cffffd100Budget " .. DecorBudgetFilterDB.budget .. "|r"))
    return
  end

  if msg == "all" or msg == "clear" or msg == "reset" then
    DecorBudgetFilterDB.budget = 0
    print("|cff66ccffDBF:|r Filter cleared")
    RefreshAllCatalogs()
    return
  end

  if msg == "debug" then
    DecorBudgetFilterDB.debug = not DecorBudgetFilterDB.debug
    print("|cff66ccffDBF:|r Debug " .. (DecorBudgetFilterDB.debug and "|cff00ff00ON|r" or "|cffff6b6bOFF|r"))
    return
  end

  local n = tonumber(msg)
  if n and (n == 1 or n == 3 or n == 5) then
    DecorBudgetFilterDB.budget = n
    print("|cff66ccffDBF:|r Budget set to |cffffd100" .. n .. "|r")
    RefreshAllCatalogs()
  else
    print("|cffff6b6bDBF:|r Use: |cffffd100/dbf [all|1|3|5]|r")
  end
end
