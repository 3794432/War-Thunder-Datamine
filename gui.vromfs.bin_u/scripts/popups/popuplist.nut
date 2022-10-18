from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let popupList = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType              = handlerType.MODAL
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupList"
  btnWidth             = null
  align                = ALIGN.BOTTOM

  //init params
  parentObj            = null
  buttonsList          = null
  onClickCb            = null
  visualStyle          = null

  function getSceneTplView() {
    return {
      buttons = buttonsList
      underPopupClick    = "hidePopupList"
      underPopupDblClick = "hidePopupList"
      btnWidth = btnWidth
      visualStyle = visualStyle
    }
  }

  function initScreen() {
    align = ::g_dagui_utils.setPopupMenuPosAndAlign(
      parentObj, align, this.scene.findObject("popup_list"))
  }

  function onItemClick(obj) {
    onClickCb?(obj)
    this.goBack()
  }

  function hidePopupList(_obj) {
    this.goBack()
  }
}

::gui_handlers.popupList <- popupList

return {
  openPopupList = @(params = {}) ::handlersManager.loadHandler(popupList, params)
}
