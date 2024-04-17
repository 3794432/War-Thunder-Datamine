
from "%scripts/dagui_library.nut" import *

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let unitStatus = require("%scripts/unit/unitStatus.nut")
let { get_balance } = require("%scripts/user/balance.nut")
let { canBuyUnit, isUnitGift } = require("%scripts/unit/unitInfo.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")

function getUnitBuyTypes(unit) {
  let res = []
  if(unit.isSquadronVehicle())
    res.append("squadron")
  if(isUnitSpecial(unit))
    res.append("premium")
  if(::canBuyUnitOnline(unit))
    res.append("shop")
  if(::canBuyUnitOnMarketplace(unit))
    res.append("marketPlace")


  if(res.len() == 0 && ((unit.reqUnlock != null && !isUnlockOpened(unit.reqUnlock)) || isUnitGift(unit)))
    return ["conditionToReceive"]

  if(res.len() == 0)
    return ["researchable"]

  return res
}

function isIntersects(arr1, arr2) {
  return arr1.filter(@(v) arr2.contains(v)).len() > 0
}

function isFullyIncluded(refArr, testArr) {
  return refArr.filter(@(v) testArr.contains(v)).len() == testArr.len()
}

function balanceEnough(unit) {
  let canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)
  let unitCost = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)
  let { wp, gold } = get_balance()

  return {
    isGoldEnough = gold >= unitCost.gold
    isWpEnough = wp >= unitCost.wp
  }
}

function getUnitAvailabilityForBuyType(unit) {
  let unitBuyTypes = getUnitBuyTypes(unit)
  let isShopVehicle = unitBuyTypes.contains("shop")
  let isStockVehicle = unitBuyTypes.contains("marketPlace")
  let isPremiumVehicle = unitBuyTypes.contains("premium")
  let isSquadronVehicle = unitBuyTypes.contains("squadron")
  let isResearchableVehicle = unitBuyTypes.contains("researchable")

  let res = []
  let hasDiscount = ::g_discount.getUnitDiscountByName(unit.name) > 0
  if(((isSquadronVehicle && ::isUnitResearched(unit)) || !isSquadronVehicle) && hasDiscount)
    res.append("discount")

  if(isShopVehicle || isStockVehicle)
    return res.append("available")

  let { isGoldEnough } = balanceEnough(unit)
  let canBuyNotResearchedUnit = unitStatus.canBuyNotResearched(unit)

  if(isResearchableVehicle && (canBuyNotResearchedUnit || canBuyUnit(unit)))
    return res.append("available")

  if((isPremiumVehicle || (isSquadronVehicle && canBuyNotResearchedUnit && !isResearchableVehicle)) && isGoldEnough)
    return res.append("available")

  return res
}

return {
  getUnitBuyTypes
  isIntersects
  isFullyIncluded
  getUnitAvailabilityForBuyType
}
