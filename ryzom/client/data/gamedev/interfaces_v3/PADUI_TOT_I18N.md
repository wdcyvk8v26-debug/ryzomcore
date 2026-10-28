# PadUI Omega ToT: native translations

The Omega Target-of-Target extension uses NeL's native `CI18N` dictionaries and namespaced `uiPadUITot...` tokens. There is no second Lua translation table.

## Translation keys

| Key | English meaning |
| --- | --- |
| `uiPadUITotWindow` | Target of Target |
| `uiPadUITotNoVisibleTarget` | No visible target |
| `uiPadUITotLoadingName` | Loading name |
| `uiPadUITotTargetHP` | Target: HP |
| `uiPadUITotTargetSAP` | Target: SAP |
| `uiPadUITotTargetStamina` | Target: Stamina |
| `uiPadUITotTargetOfTargetHP` | Target of Target: HP |
| `uiPadUITotTargetOfTargetSAP` | Target of Target: SAP |
| `uiPadUITotTargetOfTargetStamina` | Target of Target: Stamina |

## Integration

* Native translations reside in `padui_tot_{en,de,fr,es,ru}.uxt`, all supported NeL locale codes.
* At startup, `init.cpp` merges the matching file using `CI18N::loadFromFilename(..., true)`, after Ryzom's base language. If the matching addon file is missing, the English addon is loaded when present. If no addon exists, stock Omega startup is unchanged.
* The add-on files restate `LanguageName` to meet NeL's .uxt parser requirement; the value matches the locale's default name. The `reload=true` setting suppresses duplicate-key warnings for that field. No shipped base .uxt file is edited.
* XML `hardtext` and HUD button text use the native keys; C++ uses `CI18N::get`, Lua uses `i18n.get`.
* Translators should edit one locale's `padui_tot_<lang>.uxt` and retain the exact key set. Display strings change on a client restart when `LanguageCode` changes.

## Testing with isolated Omega profile 9903

Pull `feature/tot-omega-port`, compile only the ToT client, back up the corresponding `9903\user` files, and copy `interaction.xml`, `interaction.lua`, `game_config.xml`, `game_config.lua`, `taskbar.xml`, and **all five `padui_tot_*.uxt` files** into `9903\user`. Restart the client. Check the title, status messages, HUD toggles, and window-manager entry in English and German. Omega baseline `b54cfbdf2` and profile `9902` must remain untouched.

Files must be available in a NeL `CPath`-searchable location; a packaged release must install the addon .uxt files along with the UI resources. Missing files result in unresolved tokens, not a translation-table fallback.
