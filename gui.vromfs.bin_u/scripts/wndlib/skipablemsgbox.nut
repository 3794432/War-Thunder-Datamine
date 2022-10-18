from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


::gui_handlers.SkipableMsgBox <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/weaponry/skipableMsgBox.blk"

  parentHandler = null
  onStartPressed = null
  cancelFunc = null
  skipFunc = null
  isCanceled = true
  isStarted = false

  message = ""
  list = ""
  startBtnText = ""
  ableToStartAndSkip = true

  function initScreen()
  {
    updateSkipCheckBox()

    let msgTextObj = this.scene.findObject("msgText")
    if (checkObj(msgTextObj))
      msgTextObj.setValue(message)

    let listTextObj = this.scene.findObject("listText")
    if (checkObj(listTextObj))
      listTextObj.setValue(list)

    let btnSelectObj = this.scene.findObject("btn_select")
    if (checkObj(btnSelectObj))
      btnSelectObj.show(ableToStartAndSkip)

    let btnCancelObj = this.scene.findObject("btn_cancel")
    if(checkObj(btnCancelObj))
      btnCancelObj.setValue(loc(ableToStartAndSkip ? "mainmenu/btnCancel" : "mainmenu/btnOk"))

    if (startBtnText != "")
      setDoubleTextToButton(this.scene, "btn_select", startBtnText)
  }

  function updateSkipCheckBox()
  {
    let skipObj = this.scene.findObject("skip_this")
    if (checkObj(skipObj))
    {
      skipObj.show(ableToStartAndSkip && skipFunc)
      skipObj.enable(ableToStartAndSkip && skipFunc)
    }
  }

  function onSkipMessageBox(obj)
  {
    if (!obj)
      return

    if (skipFunc)
      skipFunc(obj.getValue())
  }

  function onStart()
  {
    isCanceled = false
    if (parentHandler && onStartPressed)
      isStarted = true

    this.goBack()
  }

  function afterModalDestroy()
  {
    if (isCanceled)
      ::call_for_handler(parentHandler, cancelFunc)
    if (isStarted)
      ::call_for_handler(parentHandler, onStartPressed)
  }
}
