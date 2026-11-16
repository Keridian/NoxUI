if NUI_CLIENT_BLOQUE then return end -- pre-12.1 client failsafe (NoxUI_ClientGate.lua)
-- Removed: the Resource Bars Advanced per-spec mode was retired in favor of
-- the shared Spec Overrides system (spec groups + editing-as). Legacy
-- advancedSpecs data migrates via NoxUI.MigrateRBAdvancedProfile
-- (NoxUI_Migration.lua) and survives in rb.advancedSpecsBackup.
-- This file is no longer referenced by the TOC and is safe to delete.
