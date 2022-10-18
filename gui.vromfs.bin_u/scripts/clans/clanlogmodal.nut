from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let playerContextMenu = require("%scripts/user/playerContextMenu.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { read_text_from_file } = require("dagor.fs")
let loadTemplateText = memoize(@(v) read_text_from_file($"{v}.tpl"))

::CLAN_LOG_ROWS_IN_PAGE <- 10
::show_clan_log <- function show_clan_log(clanId)
{
  ::gui_start_modal_wnd(
    ::gui_handlers.clanLogModal,
    {clanId = clanId}
  )
}

::gui_handlers.clanLogModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanLogModal.blk"

  loadButtonId = "button_load_more"

  logListObj = null

  clanId        = null
  requestMarker = null
  selectedIndex = 0

  function initScreen()
  {
    logListObj = this.scene.findObject("log_list")
    if (!checkObj(logListObj))
      return this.goBack()

    fetchLogPage()
  }

  function fetchLogPage()
  {
    ::g_clans.requestClanLog(
      clanId,
      ::CLAN_LOG_ROWS_IN_PAGE,
      requestMarker,
      handleLogData,
      function (_result) {},
      this
    )
  }

  function handleLogData(logData)
  {
    requestMarker = logData.requestMarker

    this.guiScene.setUpdatesEnabled(false, false)
    removeNextButton()
    showLogs(logData)
    if (logData.logEntries.len() >= ::CLAN_LOG_ROWS_IN_PAGE)
      addNextButton()
    this.guiScene.setUpdatesEnabled(true, true)

    selectLogItem()
  }

  function showLogs(logData)
  {
    for (local i = 0; i < logData.logEntries.len(); i++) {
      let author = logData.logEntries[i]?.uN ?? logData.logEntries[i]?.details.uN ?? ""
      logData.logEntries[i] = ::getFilteredClanData(logData.logEntries[i], author)
      if ("details" in logData.logEntries[i])
        logData.logEntries[i].details = ::getFilteredClanData(logData.logEntries[i].details, author)
    }

    let blk = ::handyman.renderCached("%gui/logEntryList", logData, {
      details = loadTemplateText("%gui/clans/clanLogDetails")
    })
    this.guiScene.appendWithBlk(logListObj, blk, this)
  }

  function selectLogItem()
  {
    if (logListObj.childrenCount() <= 0)
      return

    if (selectedIndex >= logListObj.childrenCount())
      selectedIndex = logListObj.childrenCount() - 1

    logListObj.setValue(selectedIndex)
    ::move_mouse_on_child(logListObj, selectedIndex)
  }

  function onUserLinkRClick(_obj, _itype, link) {
    let uid = ::g_string.cutPrefix(link, "uid_", null)

    if (uid == null)
      return

    playerContextMenu.showMenu(::getContact(uid), this)
  }

  function removeNextButton()
  {
    let obj = logListObj.findObject(loadButtonId)
    if (checkObj(obj))
      this.guiScene.destroyElement(obj)
  }

  function addNextButton()
  {
    local obj = logListObj.findObject(loadButtonId)
    if (!obj)
    {
      let data = format("expandable { id:t='%s'}", loadButtonId)
      this.guiScene.appendWithBlk(logListObj, data, this)
      obj = logListObj.findObject(loadButtonId)
    }

    let viewBlk = ::handyman.renderCached("%gui/userLog/userLogRow",
      {
        middle = loc("userlog/showMore")
        hasExpandImg = true
      })
    this.guiScene.replaceContentFromText(obj, viewBlk, viewBlk.len(), this)
  }

  function onItemSelect(obj)
  {
    let listChildrenCount = logListObj.childrenCount()
    if (listChildrenCount <= 0)
      return

    let index = obj.getValue()
    if (index == -1 || index > listChildrenCount - 1)
      return

    selectedIndex = index
    let selectedObj = obj.getChild(index)
    if (checkObj(selectedObj) && selectedObj?.id == loadButtonId)
      fetchLogPage()
  }
}
