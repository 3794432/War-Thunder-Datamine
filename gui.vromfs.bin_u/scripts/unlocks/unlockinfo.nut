//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

let function getMedalRibbonImg(unlockId) {
  return $"!@ui/medals/{unlockId}_ribbon.ddsx"
}

let function hasMedalRibbonImg(unlockId) {
  let unlock = getUnlockById(unlockId)
  return unlock?.hasRibbonImg ?? (unlock?.type == "medal")
}

return {
  getMedalRibbonImg
  hasMedalRibbonImg
}