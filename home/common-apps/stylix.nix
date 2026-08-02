_: {
  home.pointerCursor.enable = true;
  stylix.enableReleaseChecks = false;
  # Stylix still writes the legacy programs.opencode.settings.theme key,
  # while current Home Manager requires TUI settings in tui.json.
  stylix.targets.opencode.enable = false;
}
