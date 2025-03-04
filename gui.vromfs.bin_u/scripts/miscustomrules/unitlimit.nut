from "%scripts/dagui_library.nut" import *
from "%scripts/misCustomRules/ruleConsts.nut" import RESPAWNS_UNLIMITED

let u = require("%sqStdLibs/helpers/u.nut")
let { getUnitRoleIcon, getRoleText } = require("%scripts/unit/unitInfoRoles.nut")
let { getUnitClassTypeByExpClass } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { get_weapon_icons_text } = require("%scripts/weaponry/weaponryInfo.nut")

let UnitLimitBase = class {
  name = ""
  respawnsLeft = 0
  distributed = RESPAWNS_UNLIMITED
  presetInfo = null
  nameLocId = null

  constructor(v_name, v_respawnsLeft, params = {}) {
    this.name = v_name
    this.respawnsLeft = v_respawnsLeft
    this.distributed = params?.distributed ?? RESPAWNS_UNLIMITED
    this.presetInfo = params?.presetInfo
    this.nameLocId = params?.nameLocId
  }

  function isSame(unitLimit) {
    return this.name == unitLimit.name && this.getclass() == unitLimit.getclass()
  }

  function getRespawnsLeftText() {
    return this.respawnsLeft == RESPAWNS_UNLIMITED ? loc("options/resp_unlimited") : this.respawnsLeft
  }

  function getText() {
    return this.name
  }
}

let UnitLimitByUnitName = class (UnitLimitBase) {
  function getText() {
    let unitName = this.nameLocId != null ? loc(this.nameLocId) : getUnitName(this.name)
    local res = "".concat(unitName, loc("ui/colon"), colorize("activeTextColor", this.getRespawnsLeftText()))
    let weaponPresetIconsText = get_weapon_icons_text(
      this.name, getTblValue("weaponPresetId", this.presetInfo)
    )

    if (!u.isEmpty(weaponPresetIconsText))
      res = "".concat(res, loc("ui/parentheses/space", {
        text = "".concat(weaponPresetIconsText, getTblValue("teamUnitPresetAmount", this.presetInfo, 0))
      }))

    if (this.distributed != null && this.distributed != RESPAWNS_UNLIMITED) {
      local text = this.distributed > 0 ? colorize("userlogColoredText", this.distributed) : this.distributed
      if (!u.isEmpty(weaponPresetIconsText))
        text = "".concat(text, loc("ui/parentheses/space", {
          text ="".concat(weaponPresetIconsText, getTblValue("userUnitPresetAmount", this.presetInfo, 0))
        }))
      res = "".concat(res, " + ", text)
    }

    return res
  }
}

let UnitLimitByUnitRole = class (UnitLimitBase) {
  function getText() {
    let fontIcon = colorize("activeTextColor", getUnitRoleIcon(this.name))
    return "".concat(fontIcon, getRoleText(this.name), loc("ui/colon"), colorize("activeTextColor", this.getRespawnsLeftText()))
  }
}

let UnitLimitByUnitExpClass = class (UnitLimitBase) {
  function getText() {
    let expClassType = getUnitClassTypeByExpClass(this.name)
    let fontIcon = colorize("activeTextColor", expClassType.getFontIcon())
    return "".concat(fontIcon, expClassType.getName(), loc("ui/colon"), colorize("activeTextColor", this.getRespawnsLeftText()))
  }
}

let ActiveLimitByUnitExpClass = class (UnitLimitBase) {
  function getText() {
    let expClassType = getUnitClassTypeByExpClass(this.name)
    let fontIcon = colorize("activeTextColor", expClassType.getFontIcon())
    local amountText = ""
    if (this.distributed == RESPAWNS_UNLIMITED || this.respawnsLeft == RESPAWNS_UNLIMITED)
      amountText = colorize("activeTextColor", this.getRespawnsLeftText())
    else {
      let color = (this.distributed < this.respawnsLeft) ? "userlogColoredText" : "activeTextColor"
      amountText = "".concat(colorize(color, this.distributed), "/", this.getRespawnsLeftText())
    }
    return "".concat(loc("multiplayer/active_at_once", { nameOrIcon = fontIcon }), loc("ui/colon"), amountText)
  }
}

let UnitLimitByUnitType = class (UnitLimitBase) {
  function getText() {
    let unitTypeName = this.name
    let unitType = unitTypes[unitTypeName]
    let fontIcon = colorize("activeTextColor", unitType.fontIcon)
    let armyLocName = unitTypeName == "SHIP" ? loc("mainmenu/fleet") : unitType.getArmyLocName()
    return $"{fontIcon}{armyLocName}{loc("ui/colon")}{colorize("activeTextColor", this.getRespawnsLeftText())}"
  }
}

return {
  UnitLimitByUnitName
  UnitLimitByUnitRole
  UnitLimitByUnitExpClass
  ActiveLimitByUnitExpClass
  UnitLimitByUnitType
}