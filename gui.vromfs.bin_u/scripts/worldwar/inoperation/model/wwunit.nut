from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import INFO_DETAIL

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { format } = require("string")
let { getRoleText } = require("%scripts/unit/unitInfoRoles.nut")
let { getWeaponInfoText, makeWeaponInfoData } = require("%scripts/weaponry/weaponryDescription.nut")
let { getWeaponTypeIcoByWeapon } = require("%scripts/statistics/mpStatisticsUtil.nut")
let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")

let strength_unit_expclass_group = {
  bomber = "bomber"
  assault = "bomber"
  heavy_tank = "tank"
  tank = "tank"
  tank_destroyer = "tank"
  exp_torpedo_boat = "ships"
  exp_gun_boat = "ships"
  exp_torpedo_gun_boat = "ships"
  exp_submarine_chaser = "ships"
  exp_destroyer = "ships"
  exp_cruiser = "ships"
  exp_naval_ferry_barge = "ships"
}

let WwUnit = class {
  name  = ""
  unit = null
  count = -1
  maxCount = -1
  inactiveCount = 0
  weaponPreset = ""
  weaponCount = 0

  wwUnitType = null
  expClass = ""
  stengthGroupExpClass = ""
  isForceControlledByAI = false

  constructor(blk) {
    if (!blk)
      return

    this.name = blk.getBlockName() || (blk?.name ?? "")
    this.unit = getAircraftByName(this.name)

    this.wwUnitType = g_ww_unit_type.getUnitTypeByWwUnit(this)
    this.expClass = this.wwUnitType.expClass || (this.unit ? this.unit.expClass.name : "")
    this.stengthGroupExpClass = strength_unit_expclass_group?[this.expClass] ?? this.expClass

    this.inactiveCount = blk?.inactiveCount ?? 0
    this.count = blk?.count ?? -1
    this.maxCount = blk?.maxCount ?? 0
    this.weaponPreset = blk?.weaponPreset ?? ""
    this.weaponCount = blk?.weaponCount ?? 0
  }

  function isValid() {
    return this.name.len() >  0 &&
           this.count      >= 0
  }

  function getId() {
    return this.name
  }

  function getCount() {
    return this.count
  }

  function setCount(val) {
    this.count = val
  }

  function setForceControlledByAI(val) {
    this.isForceControlledByAI = val
  }

  function getActiveCount() {
    return this.count - this.inactiveCount
  }

  function getMaxCount() {
    return this.maxCount
  }

  function getName() {
    return this.wwUnitType.getUnitName(this.name)
  }

  function getFullName() {
    return format("%d %s", this.count, this.getName())
  }

  function getWwUnitType() {
    return this.wwUnitType
  }

  getShortStringView = kwarg(function getShortStringViewImpl(
    addIcon = true, addPreset = true, hideZeroCount = true, needShopInfo = false, hasIndent = false) {
    let presetData = getWeaponTypeIcoByWeapon(this.name, addPreset ? this.weaponPreset : "")
    let weaponInfoParams = {
      isPrimary = false
      weaponPreset = this.weaponPreset
      detail = INFO_DETAIL.SHORT
      needTextWhenNoWeapons = false
    }
    let presetText = !addPreset || this.weaponPreset == "" ? ""
      : getWeaponInfoText(this.unit, makeWeaponInfoData(this.unit, weaponInfoParams))

    local nameText = this.getName()
    if (needShopInfo && this.unit && !this.isControlledByAI() && !this.unit.canUseByPlayer()) {
      let nameColor = isUnitSpecial(this.unit) ? "@hotkeyColor" : "@weaponWarning"
      nameText = colorize(nameColor, nameText)
    }

    let activeCount = this.getActiveCount()
    let maxCount = this.getMaxCount()
    let totalCount = this.getCount()

    local activeCountStr = activeCount.tostring()
    if (maxCount > 0)
      activeCountStr = $"{activeCountStr}/{maxCount}"

    let res = {
      id = this.name
      isShow = this.maxCount > 0 || this.count > 0 || !hideZeroCount
      unitType = this.getUnitTypeText()
      wwUnitType = this.wwUnitType
      name = nameText
      activeCount = activeCountStr
      columnCountWidth = getStringWidthPx(activeCountStr, "fontNormal", get_cur_gui_scene())
      count = totalCount ? totalCount.tostring() : null
      isControlledByAI = this.isControlledByAI()
      weapon = presetText.len() > 0 ? colorize("@activeTextColor", presetText) : ""
      hasBomb = presetData.bomb.len() > 0
      hasRocket = presetData.rocket.len() > 0
      hasTorpedo = presetData.torpedo.len() > 0
      hasAdditionalGuns = presetData.additionalGuns.len() > 0
      hasPresetWeapon = (presetText.len() > 0) && (this.weaponCount > 0)
      presetCount = addPreset && this.weaponCount < this.count ? this.weaponCount : null
      hasIndent = hasIndent
      country = this.unit?.shopCountry ?? ""
      tooltipId = getTooltipType("UNIT").getTooltipId(this.name, {
        showLocalState = needShopInfo
        needShopInfo = needShopInfo
        showShortestUnitInfo = this.isForceControlledByAI
      })
    }

    if (addIcon) {
      res.icon <- this.getWwUnitClassIco()
      res.shopItemType <- this.getUnitRole()
    }
    return res
  })

  function isInfantry() {
    return g_ww_unit_type.isInfantry(this.wwUnitType.code)
  }

  function isArtillery() {
    return g_ww_unit_type.isArtillery(this.wwUnitType.code)
  }

  function isAir() {
    return g_ww_unit_type.isAir(this.wwUnitType.code)
  }

  function isControlledByAI() {
    return this.isForceControlledByAI || !this.wwUnitType.canBeControlledByPlayer
  }

  function getUnitTypeText() {
    return getRoleText(this.expClass)
  }

  function getUnitStrengthGroupTypeText() {
    return getRoleText(this.stengthGroupExpClass)
  }

  function getWwUnitClassIco() {
    return this.wwUnitType.getUnitClassIcon(this.unit)
  }

  function getUnitRole() {
    local unitRole = this.wwUnitType.getUnitRole(this.unit)
    if (unitRole == "") {
      log("WWar: Army Class: Not found role for unit", this.name, ". Set unknown")
      unitRole = "unknown"
    }

    return unitRole
  }
}

return { WwUnit }
