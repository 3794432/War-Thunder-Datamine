from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { round } = require("math")
let { get_time_msec } = require("dagor.time")
let { split_by_chars } = require("string")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")
let time = require("%scripts/time.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let ItemLifetimeModifier = require("%scripts/items/itemLifetimeModifier.nut")

let collection = {}

local ItemGenerator = class {
  id = -1
  genType = ""
  exchange = null
  bundle  = null
  timestamp = ""
  rawCraftTime = 0
  lifetimeModifier = null

  isPack = false
  hasHiddenItems = false
  hiddenTopPrizeParams = null
  tags = null

  _contentUnpacked = null

  constructor(itemDefDesc)
  {
    id = itemDefDesc.itemdefid
    genType = itemDefDesc?.type ?? ""
    exchange = itemDefDesc?.exchange ?? ""
    bundle   = itemDefDesc?.bundle ?? ""
    isPack   = isInArray(genType, [ "bundle", "delayedexchange" ])
    tags     = itemDefDesc?.tags
    timestamp = itemDefDesc?.Timestamp ?? ""
    rawCraftTime = time.getSecondsFromTemplate(itemDefDesc?.lifetime ?? "")
    let lifetimeModifierText = itemDefDesc?.lifetime_modifier
    if (!::u.isEmpty(lifetimeModifierText))
      lifetimeModifier = ItemLifetimeModifier(lifetimeModifierText)
  }

  _exchangeRecipes = null
  _exchangeRecipesUpdateTime = 0

  function getCraftTime()
  {
    local result = rawCraftTime
    if (lifetimeModifier != null)
    {
      let mul = lifetimeModifier.calculate()
      result = max(1, round(result * mul))
    }
    return result
  }

  function getRecipes(needUpdateRecipesList = true)
  {
    if (!_exchangeRecipes
      || (needUpdateRecipesList && _exchangeRecipesUpdateTime <= ::ItemsManager.extInventoryUpdateTime))
    {
      let generatorId = id
      let generatorCraftTime = getCraftTime()
      let parsedRecipes = inventoryClient.parseRecipesString(exchange)
      let isDisassemble = tags?.isDisassemble ?? false
      let localizationPresetName = tags?.customLocalizationPreset
      let effectOnStartCraftPresetName = tags?.effectOnStartCraft
      let allowableComponents = getAllowableRecipeComponents()
      let showRecipeAsProduct = tags?.showRecipeAsProduct
      _exchangeRecipes = ::u.map(parsedRecipes, @(parsedRecipe) ExchangeRecipes({
         parsedRecipe
         generatorId
         craftTime = generatorCraftTime
         isDisassemble
         localizationPresetName
         effectOnStartCraftPresetName
         allowableComponents
         showRecipeAsProduct
      }))

      // Adding additional recipes
      local hasAdditionalRecipes = false
      foreach (itemBlk in workshop.getItemAdditionalRecipesById(id))
      {
        foreach (paramName in ["fakeRecipe", "trueRecipe"])
          foreach (itemdefId in itemBlk % paramName)
          {
            ::ItemsManager.findItemById(itemdefId) // calls pending generators list update
            let gen = collection?[itemdefId]
            let additionalParsedRecipes = gen ? inventoryClient.parseRecipesString(gen.exchange) : []
            _exchangeRecipes.extend(::u.map(additionalParsedRecipes, @(pr) ExchangeRecipes({
              parsedRecipe = pr
              generatorId = gen.id
              craftTime = gen.getCraftTime()
              isFake = paramName != "trueRecipe"
              isDisassemble = isDisassemble
              localizationPresetName = gen?.tags?.customLocalizationPreset ?? localizationPresetName
              effectOnStartCraftPresetName = gen?.tags?.effectOnStartCraft
              allowableComponents = gen?.getAllowableRecipeComponents() ?? allowableComponents
              showRecipeAsProduct = gen?.tags?.showRecipeAsProduct
            })))
            hasAdditionalRecipes = hasAdditionalRecipes || additionalParsedRecipes.len() > 0
          }
        break
      }
      if (hasAdditionalRecipes)
      {
        local minIdx = _exchangeRecipes[0].idx
        ::math.init_rnd(::my_user_id_int64 + id)
        _exchangeRecipes = ::u.shuffle(_exchangeRecipes)
        foreach (recipe in _exchangeRecipes)
          recipe.idx = minIdx++
        ::randomize()
      }

      _exchangeRecipesUpdateTime = get_time_msec()
    }
    return ::u.filter(_exchangeRecipes, @(ec) ec.isEnabled())
  }

  function getUsableRecipes() {
    let showAllowableRecipesOnly = tags?.showAllowableRecipesOnly ?? false
    let recipes = getRecipes() ?? []
    if (!showAllowableRecipesOnly)
      return recipes

    local filteredRecipes = []
    local maxMultiComponentCount = 0
    foreach (recipe in recipes) {
      if (!recipe.isUsable)
        continue
      let multiComponentCount = recipe.components.filter(@(c) c.curQuantity > c.reqQuantity).len()
      if (multiComponentCount < maxMultiComponentCount)
        continue
      if (multiComponentCount == maxMultiComponentCount) {
        filteredRecipes.append(recipe)
        continue
      }

      maxMultiComponentCount = multiComponentCount
      filteredRecipes = [recipe]
    }
    return filteredRecipes
  }

  function getRecipesWithComponent(componentItemdefId)
  {
    return ::u.filter(getRecipes(), @(ec) ec.hasComponent(componentItemdefId))
  }

  function _unpackContent(contentRank = null)
  {
    _contentUnpacked = []
    let parsedBundles = inventoryClient.parseRecipesString(bundle)
    let trophyWeightsBlk = ::get_game_settings_blk()?.visualizationTrophyWeights
    let trophyWeightsBlockCount = trophyWeightsBlk?.blockCount() ?? 0
    foreach (set in parsedBundles)
      foreach (cfg in set.components)
      {
        let item = ::ItemsManager.findItemById(cfg.itemdefid)
        let generator = !item ? collection?[cfg.itemdefid] : null
        let rank = contentRank != null ? min(cfg.quantity, contentRank) : cfg.quantity
        if (item)
        {
          if (item.isHiddenItem())
            continue
          let b = ::DataBlock()
          b.item =  item.id
          b.rank = rank
          if (tags?.showFreq)
            b.dropChance = tags.showFreq.tointeger() / 100.0
          if (trophyWeightsBlk != null && trophyWeightsBlockCount > 0
            && rank <= trophyWeightsBlockCount)
          {
            let weightBlock = trophyWeightsBlk.getBlock(rank - 1)
            b.weight = weightBlock.getBlockName()
          }
          _contentUnpacked.append(b)
        }
        else if (generator)
        {
          let content = generator.getContent(rank)
          hasHiddenItems = hasHiddenItems || generator.hasHiddenItems
          hiddenTopPrizeParams = hiddenTopPrizeParams || generator.hiddenTopPrizeParams
          _contentUnpacked.extend(content)
        }
      }

    let isBundleHidden = !_contentUnpacked.len()
    hasHiddenItems = hasHiddenItems || isBundleHidden
    hiddenTopPrizeParams = isBundleHidden ? tags : hiddenTopPrizeParams
  }

  function getContent(contentRank = null)
  {
    if (!_contentUnpacked)
      _unpackContent(contentRank)
    return _contentUnpacked
  }

  function isHiddenTopPrize(prize)
  {
    let content = getContent()
    if (!hasHiddenItems || !prize?.item)
      return false
    foreach (v in content)
      if (prize.item == v?.item)
        return false
    return true
  }

  function getRecipeByUid(uid)
  {
    return ::u.search(getRecipes(), @(r) r.uid == uid)
  }

  function markAllRecipes()
  {
    let recipes = getRecipes()
    if (!ExchangeRecipes.hasFakeRecipes(recipes))
      return

    let markedRecipes = []
    foreach(recipe in recipes)
      if (recipe.markRecipe(false, false))
        markedRecipes.append(recipe.uid)

    ExchangeRecipes.saveMarkedRecipes(markedRecipes)
  }

  isDelayedxchange = @() genType == "delayedexchange"
  getContentNoRecursion = @() getContent()

  function getAllowableRecipeComponents() {
    let allowableItemsForRecipes = tags?.allowableItemsForRecipes
    if (allowableItemsForRecipes == null)
      return null

    let allowableItems = {}
    foreach (itemId in split_by_chars(allowableItemsForRecipes, "_"))
      allowableItems[::to_integer_safe(itemId, itemId, false)] <- true

    return allowableItems
  }
}

let get = function(itemdefId) {
  ::ItemsManager.findItemById(itemdefId) // calls pending generators list update
  return collection?[itemdefId]
}

let add = function(itemDefDesc) {
  if (itemDefDesc?.Timestamp != collection?[itemDefDesc.itemdefid]?.timestamp)
    collection[itemDefDesc.itemdefid] <- ItemGenerator(itemDefDesc)
}

let findGenByReceptUid = @(recipeUid)
  ::u.search(collection, @(gen) ::u.search(gen.getRecipes(false),
    @(recipe) recipe.uid == recipeUid
     && (recipe.isDisassemble || !gen.isDelayedxchange())) != null) //!!!FIX ME There should be no two recipes with the same uid.

return {
  get = get
  add = add
  findGenByReceptUid = findGenByReceptUid
}
