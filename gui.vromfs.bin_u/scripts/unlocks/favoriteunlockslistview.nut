from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.FavoriteUnlocksListView <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/unlocks/favoriteUnlocksList.blk"
  curFavoriteUnlocksBlk = null

  listContainer = null

  unlocksListIsValid = false

  function initScreen()
  {
    this.scene.setUserData(this)
    curFavoriteUnlocksBlk = ::DataBlock()
    listContainer = this.scene.findObject("favorite_unlocks_list")
    updateList()
  }

  function updateList()
  {
    if (!checkObj(listContainer))
      return

    if(!unlocksListIsValid)
      curFavoriteUnlocksBlk.setFrom(::g_unlocks.getFavoriteUnlocks())

    let unlocksObjCount = listContainer.childrenCount()
    let total = max(unlocksObjCount, curFavoriteUnlocksBlk.blockCount())
    if (unlocksObjCount == 0 && total > 0) {
      let blk = ::handyman.renderCached(("%gui/unlocks/unlockItemSimplified"),
        { unlocks = array(total, { hasCloseButton = true, hasHiddenContent = true })})
      this.guiScene.appendWithBlk(listContainer, blk, this)
    }

    for(local i = 0; i < total; i++)
    {
      let unlockObj = getUnlockObj(i)
      ::g_unlock_view.fillSimplifiedUnlockInfo(curFavoriteUnlocksBlk.getBlock(i), unlockObj, this)
    }

    this.showSceneBtn("no_favorites_txt",
      ! (curFavoriteUnlocksBlk.blockCount() && listContainer.childrenCount()))
    unlocksListIsValid = true
  }

  function onEventFavoriteUnlocksChanged(_params)
  {
    unlocksListIsValid = false
    this.doWhenActiveOnce("updateList")
  }

  function onEventProfileUpdated(_params)
  {
    this.doWhenActiveOnce("updateList")
  }

  function onRemoveUnlockFromFavorites(obj)
  {
    ::g_unlocks.removeUnlockFromFavorites(obj.unlockId)
  }

  function getUnlockObj(idx)
  {
    if (listContainer.childrenCount() > idx)
        return listContainer.getChild(idx)

    return listContainer.getChild(idx-1).getClone(listContainer, this)
  }
}
