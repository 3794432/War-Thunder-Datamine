from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let ExchangeRecipes = require("%scripts/items/exchangeRecipes.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { ceil } = require("math")

let u = require("%sqStdLibs/helpers/u.nut")
let stdMath = require("%sqstd/math.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { findChildIndex } = require("%sqDagui/daguiUtil.nut")

local MIN_ITEMS_IN_ROW = 7

::gui_handlers.RecipesListWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "%gui/items/recipesListWnd"

  recipesList = null
  curRecipe = null

  headerText = ""
  buttonText = "#item/assemble"
  onAcceptCb = null //if return true, recipes list will not close.
  alignObj = null
  align = "bottom"
  needMarkRecipes = false
  showRecipeAsProduct = false
  showTutorial = false

  function getSceneTplView()
  {
    recipesList = clone recipesList
    let hasMarkers = ExchangeRecipes.hasFakeRecipes(recipesList)
    if (hasMarkers)
      recipesList.sort(@(a, b) a.idx <=> b.idx)
    else
      recipesList.sort(@(a, b) b.isUsable <=> a.isUsable
        || a.sortReqQuantityComponents <=> b.sortReqQuantityComponents
        || a.idx <=> b.idx)
    curRecipe = recipesList[0]

    local maxRecipeLen = 1
    foreach(r in recipesList)
      maxRecipeLen = max(maxRecipeLen, r.getVisibleMarkupComponents())

    let recipeWidthPx = maxRecipeLen * to_pixels("0.5@itemWidth")
    let recipeHeightPx = to_pixels("0.5@itemHeight")
    let minColumns = ceil(MIN_ITEMS_IN_ROW.tofloat() / maxRecipeLen).tointeger()
    let columns = max(minColumns,
      stdMath.calc_golden_ratio_columns(recipesList.len(), recipeWidthPx / (recipeHeightPx || 1)))
    let rows = ceil(recipesList.len().tofloat() / columns).tointeger()

    local itemsInRow = 0 //some columns are thinner than max
    local columnWidth = 0
    let separatorsIdx = []
    foreach(i, recipe in recipesList)
    {
      let recipeWidth = recipe.getVisibleMarkupComponents()
      columnWidth = max(columnWidth, recipeWidth)
      if (i == 0 || (i % rows))
        continue
      itemsInRow += columnWidth
      columnWidth = recipeWidth
      separatorsIdx.append(i + separatorsIdx.len())
    }
    foreach (idx in separatorsIdx)
      recipesList.insert(idx, { isSeparator = true })

    itemsInRow += columnWidth

    let res = {
      maxRecipeLen
      recipesList = recipesList
      columns
      rows
      itemsInRow = max(itemsInRow, MIN_ITEMS_IN_ROW)
      hasMarkers
      showRecipeAsProduct = showRecipeAsProduct
    }

    foreach(key in ["headerText", "buttonText"])
      res[key] <- this[key]
    return res
  }

  function initScreen()
  {
    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, this.scene.findObject("main_frame"))
    needMarkRecipes = ExchangeRecipes.hasFakeRecipes(recipesList)
    let recipesListObj = this.scene.findObject("recipes_list")
    if (recipesList.len() > 0)
      recipesListObj.setValue(0)

    this.guiScene.applyPendingChanges(false)
    ::move_mouse_on_child_by_value(recipesListObj)
    updateCurRecipeInfo()

    if (showTutorial)
      startTutorial()
  }

  function startTutorial()
  {
    let steps = [{
      obj = getUsableRecipeObjs().map(@(r) { obj = r, hasArrow = true })
      text = loc("workshop/tutorial/selectRecipe")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::GAMEPAD_ENTER_SHORTCUT
      cb = @() selectRecipe()
    },
    {
      obj = this.scene.findObject("btn_apply")
      text = loc("workshop/tutorial/pressButton", {
        button_name = buttonText
      })
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::GAMEPAD_ENTER_SHORTCUT
      cb = @() onRecipeApply()
    }]
    ::gui_modal_tutor(steps, this, true)
  }

  function selectRecipe()
  {
    let recipesListObj = this.scene.findObject("recipes_list")
    if (!recipesListObj?.isValid())
      return

    let cursorPos = ::get_dagui_mouse_cursor_pos_RC()
    let idx = findChildIndex(recipesListObj, function(childObj) {
      let posRC = childObj.getPosRC()
      let size = childObj.getSize()
      return cursorPos[0] >= posRC[0] && cursorPos[0] <= posRC[0] + size[0]
        && cursorPos[1] >= posRC[1] && cursorPos[1] <= posRC[1] + size[1]
    })

    if (idx == -1 || idx == recipesListObj.getValue())
      return

    recipesListObj.setValue(idx)
  }

  function getUsableRecipeObjs()
  {
    let res = []
    let recipesListObj = this.scene.findObject("recipes_list")
    foreach (recipe in recipesList)
      if (!recipe?.isSeparator && recipe.isUsable && !recipe.isRecipeLocked())
        res.append(recipesListObj.findObject($"id_{recipe.uid}"))
    return res
  }

  function updateCurRecipeInfo()
  {
    let infoObj = this.scene.findObject("selected_recipe_info")
    let markup = curRecipe ? curRecipe.getTextMarkup() + curRecipe.getMarkDescMarkup() : ""
    this.guiScene.replaceContentFromText(infoObj, markup, markup.len(), this)

    updateButtons()
  }

  function updateButtons()
  {
    local btnObj = this.scene.findObject("btn_apply")
    btnObj.inactiveColor = curRecipe?.isUsable && !curRecipe.isRecipeLocked() ? "no" : "yes"

    local btnText = loc(curRecipe.getActionButtonLocId() ?? buttonText)
    if (curRecipe.hasCraftTime())
      btnText += " " + loc("ui/parentheses", {text = curRecipe.getCraftTimeText()})
    btnObj.setValue(btnText)

    if (!needMarkRecipes)
      return

    btnObj = this.scene.findObject("btn_mark")
    btnObj.show(needMarkRecipes && (curRecipe?.mark ?? MARK_RECIPE.NONE) < MARK_RECIPE.USED)
    btnObj.setValue(getMarkBtnText())
  }

  function onRecipeSelect(obj)
  {
    let newRecipe = recipesList?[obj.getValue()]
    if (!u.isRecipe(newRecipe) || newRecipe == curRecipe)
      return
    curRecipe = newRecipe
    updateCurRecipeInfo()
  }

  function onRecipeApply()
  {
    if (curRecipe && curRecipe.isRecipeLocked())
      return ::scene_msg_box("cant_cancel_craft", null,
        colorize("badTextColor", loc(curRecipe.getCantAssembleMarkedFakeLocId())),
        [[ "ok" ]],
        "ok")

    local needLeaveWndOpen = false
    if (curRecipe && onAcceptCb)
      needLeaveWndOpen = onAcceptCb(curRecipe)
    if (!needLeaveWndOpen)
      this.goBack()
  }

  getMarkBtnText = @() loc(curRecipe.mark == MARK_RECIPE.BY_USER
    ? "item/recipes/unmarkFake"
    : "item/recipes/markFake")

  function onRecipeMark()
  {
    if(!curRecipe || !needMarkRecipes)
      return

    curRecipe.markRecipe(true)
    let recipeObj = this.scene.findObject("id_"+ curRecipe.uid)
    if (!checkObj(recipeObj))
      return

    recipeObj.isRecipeLocked = curRecipe.isRecipeLocked() ? "yes" : "no"
    let markImgObj = recipeObj.findObject("img_"+ curRecipe.uid)
    markImgObj["background-image"] = curRecipe.getMarkIcon()
    markImgObj.tooltip = curRecipe.getMarkTooltip()
    updateCurRecipeInfo()
  }
}

return {
  open = function(params) {
    let recipesList = params?.recipesList
    if (!recipesList || !recipesList.len())
      return
    ::handlersManager.loadHandler(::gui_handlers.RecipesListWnd, params)
  }
}