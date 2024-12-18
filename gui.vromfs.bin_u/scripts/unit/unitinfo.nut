from "%scripts/dagui_natives.nut" import is_era_available, shop_get_unit_exp, wp_get_cost, wp_get_cost_gold
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { get_ranks_blk } = require("blkGetters")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { Cost } = require("%scripts/money.nut")
let { findUnitNoCase, getEsUnitType } = require("%scripts/unit/unitParams.nut")

enum bit_unit_status {
  locked      = 1
  canResearch = 2
  inResearch  = 4
  researched  = 8
  canBuy      = 16
  owned       = 32
  mounted     = 64
  disabled    = 128
  broken      = 256
  inRent      = 512
  empty       = 1024
}

let getUnitTypeText = @(esUnitType) unitTypes.getByEsUnitType(esUnitType).name
let getUnitTypeByText = @(typeName, caseSensitive = false) unitTypes.getByName(typeName, caseSensitive).esUnitType

function get_unit_icon_by_unit(unit, iconName) {
  let esUnitType = getEsUnitType(unit)
  let t = unitTypes.getByEsUnitType(esUnitType)
  return $"{t.uiSkin}{iconName}.ddsx"
}

function image_for_air(air) {
  if (type(air) == "string")
    air = getAircraftByName(air)
  if (!air)
    return ""
  return air.customImage ?? get_unit_icon_by_unit(air, air.name)
}

function getUnitTypeTextByUnit(unit) {
  return getUnitTypeText(getEsUnitType(unit))
}

function getUnitCountry(unit) {
  return unit?.shopCountry ?? ""
}

function getUnitName(unit, shopName = true) {
  let unitId = u.isUnit(unit) ? unit.name
    : u.isString(unit) ? unit
    : ""
  let localized = loc($"{unitId}{shopName ? "_shop" : "_0"}", unitId)
  return shopName ? localized.replace(" ", nbsp) : localized
}

function getUnitCountryIcon(unit, needOperatorCountry = false) {
  return getCountryIcon(needOperatorCountry ? unit.getOperatorCountry() : unit.shopCountry)
}

function getUnitsNeedBuyToOpenNextInEra(countryId, unitType, rank, ranksBlk = null) {
  ranksBlk = ranksBlk || get_ranks_blk()
  let unitTypeText = getUnitTypeText(unitType)

  local rankToOpen = ranksBlk?.needBuyToOpenNextInEra[countryId][$"needBuyToOpenNextInEra{unitTypeText}{rank}"]
  if (rankToOpen != null)
    return rankToOpen

  rankToOpen = ranksBlk?.needBuyToOpenNextInEra[countryId][$"needBuyToOpenNextInEra{rank}"]
  if (rankToOpen != null)
    return rankToOpen

  return -1
}

function getRomanNumeralRankByUnitName (unitName) {
  let unit = unitName ? findUnitNoCase(unitName) : null
  return unit ? get_roman_numeral(unit.rank) : null
}

function getUnitReqExp(unit) {
  if (!("reqExp" in unit))
    return 0
  return unit.reqExp
}

function getUnitExp(unit) {
  return shop_get_unit_exp(unit.name)
}

function getUnitRealCost(unit) {
  return Cost(unit.cost, unit.costGold)
}

function getUnitCost(unit) {
  return Cost(wp_get_cost(unit.name), wp_get_cost_gold(unit.name))
}

function getPrevUnit(unit) {
  return "reqAir" in unit ? getAircraftByName(unit.reqAir) : null
}

return {
  bit_unit_status,
  getUnitTypeTextByUnit, getUnitName,//next
  getUnitCountry, getUnitCountryIcon, getUnitsNeedBuyToOpenNextInEra,
  getRomanNumeralRankByUnitName
  getUnitReqExp
  getUnitExp
  getUnitRealCost
  getUnitCost
  getPrevUnit
  get_unit_icon_by_unit
  getUnitTypeText
  getUnitTypeByText
  image_for_air
}