from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

const OFFLINE_SQUAD_TEXT_COLOR = "contactOfflineColor"

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let squadsListData = require("%scripts/squads/clanSquadsList.nut")
let squadApplications = require("%scripts/squads/squadApplications.nut")
::dagui_propid.add_name_id("leaderUid")

::gui_handlers.MyClanSquadsListModal <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "%gui/clans/clanSquadsModal.blk"
  squadsListObj = null
  dummyButtonsListObj = null
  minListItems = 5
  onlineUsersTable = null

  squadButtonsList = [
    {
      id = "btn_squad_info"
      buttonClass ="image"
      shortcut = ""
      showOnSelect = "hover"
      btnName = "X"
      btnKey = "X"
      tooltip = @() loc("squad/info")
      img = "#ui/gameuiskin#btn_help.svg"
      funcName = "onSquadInfo"
      isHidden = false
      isDisabled = false
    },
    {
      id = "btn_application"
      buttonClass ="image"
      shortcut = ""
      showOnSelect = "hover"
      btnName = "A"
      btnKey = "A"
      tooltip = @() loc("squad/membership_request")
      img = "#ui/gameuiskin#btn_invite.svg"
      funcName = "onApplication"
      isHidden = true
      isDisabled = true
    },
    {
      id = "btn_revoke_application"
      buttonClass ="image"
      shortcut = ""
      showOnSelect = "hover"
      btnName = "A"
      btnKey = "A"
      isColoredImg = "yes"
      tooltip = @() loc("squad/revoke_membership_request")
      img = "#ui/gameuiskin#icon_primary_fail.svg"
      funcName = "onRevokeApplication"
      isHidden = true
      isDisabled = true
    }
  ]

  curList = null
  selectedSquad = null
  selectedIndex = 0

  static function open()
  {
    ::gui_start_modal_wnd(::gui_handlers.MyClanSquadsListModal)
  }

  function initScreen()
  {
    squadsListObj = this.scene.findObject("clan_squads_list")
    dummyButtonsListObj = this.scene.findObject("clan_squads_modal")
    if (!checkObj(squadsListObj))
      return this.goBack()
    curList = []
    selectedSquad = null
    onlineUsersTable = {}
    let view = { squad = array(minListItems, {buttonsList = createSquadButtons()}) }
    local blk = ::handyman.renderCached(("%gui/clans/clanSquadsList"), view)
    this.guiScene.appendWithBlk(squadsListObj, blk, this)

    blk = createDummyButtons()
    this.guiScene.appendWithBlk(dummyButtonsListObj, blk, this)

    this.scene.findObject("squad_list_update").setUserData(this)

    refreshOnlineUsersTable()
    updateSquadsList()
    updateSquadsListInfo(curList.len())
  }

  function createSquadButtons()
  {
    local markUp = ""
    foreach (buttonView in squadButtonsList)
      markUp += ::handyman.renderCached("%gui/commonParts/button", buttonView)
    return markUp
  }

  function createDummyButtons()
  {
    local markUp = ""
    foreach (buttonView in squadButtonsList)
      markUp += ::handyman.renderCached("%gui/commonParts/dummyButton", buttonView)
    return markUp
  }

  function refreshList()
  {
    squadsListData.requestList()
  }

  function updateSquadsList()
  {
    let newList = clone squadsListData.getList()
    let total = max(newList.len(), curList.len())
    local isSelected = false
    for(local i = 0; i < total; i++)
    {
      updateSquadInfo(i, curList?[i], newList?[i])
      if (!isSelected && ::u.isEqual(selectedSquad, newList?[i]) && (selectedIndex != -1))
        {
          if (selectedIndex != i)
          {
            squadsListObj.setValue(i)
            selectedIndex = i
          }
          selectedSquad = newList?[i]
          isSelected = true
        }
    }
    curList = newList
    if (!isSelected && newList.len()>0)
    {
      selectedIndex = clamp(selectedIndex, 0, newList.len() - 1)
      selectedSquad = newList[selectedIndex]
      squadsListObj.setValue(selectedIndex)
    }
    else
      if (newList.len() <= 0)
      {
        selectedSquad = null
        selectedIndex = -1
        ::gui_bhv.posNavigator.clearSelect(squadsListObj)
      }
    updateSquadDummyButtons()
    updateSquadsListInfo(curList.len())
  }

  function updateSquadInfo(idx, curSquad, newSquad)
  {
    if (curSquad == newSquad || (::u.isEqual(curSquad, newSquad)))
      return

    let obj = getSquadObj(idx)
    let show = newSquad ? true: false
    obj.show(show)
    obj.enable(show)
    if (!show)
      return null
    obj.findObject("leader_name").setValue(getLeaderName(newSquad))
    obj.findObject("num_members").setValue(getNumMembers(newSquad))
    obj.findObject("btn_user_options").leaderUid = newSquad?.leader
    obj.findObject("btn_squad_info").leaderUid = newSquad?.leader
    obj.findObject("application_disabled").show(
      !(newSquad?.data?.properties?.isApplicationsEnabled ?? true))
    fillPresence(obj, newSquad)
    let buttonsContainerObj = obj.findObject("buttons_container")
    buttonsContainerObj.leaderUid = newSquad?.leader

    updateSquadButtons(buttonsContainerObj, newSquad)
  }

  function fillPresence(obj, squad)
  {
    obj.findObject("presence").setValue(!isSquadOnline(squad)
      ? colorize(OFFLINE_SQUAD_TEXT_COLOR, loc("matching/SQUAD_LEADER_OFFLINE"))
      : getPresence(squad))
  }

  function updateSquadButtons(obj, squad)
  {
    let show = canApplyForMembership(squad)
    let btnObj = ::showBtn("btn_application", show, obj)
    if (checkObj(btnObj) && show)
      btnObj.tooltip = getInvitationInSquad(squad) ? loc("squad/join") : loc("squad/membership_request")

    ::showBtn("btn_revoke_application", canRevokeApplication(squad), obj)
  }

  function updateSquadDummyButtons()
  {
    if (!selectedSquad)
      return
    ::showBtn("btn_application", canApplyForMembership(selectedSquad), dummyButtonsListObj)
    ::showBtn("btn_revoke_application", canRevokeApplication(selectedSquad), dummyButtonsListObj)
  }

  function canApplyForMembership(squad)
  {
    return !squadApplications.hasApplication(squad.leader)
      && !isMySquad(squad)
      && (squad?.data?.properties?.isApplicationsEnabled ?? true)
  }

  function canRevokeApplication(squad)
  {
    return squadApplications.hasApplication(squad.leader)
      && !::g_squad_manager.isInSquad()
  }

  function getInvitationInSquad(squad)
  {
    let uid = ::g_invites_classes.Squad.getUidByParams({squadId = squad.leader})
    return ::g_invites.findInviteByUid(uid)
  }

  function getSquadObj(idx)
  {
    if (squadsListObj.childrenCount() > idx) {
        return squadsListObj.getChild(idx)
    }
    return squadsListObj.getChild(idx-1).getClone(squadsListObj, this)
  }

  function isMySquad(squad)
  {
    if (!::g_squad_manager.isInSquad())
      return false

    return isInArray(::my_user_id_int64, squad?.members ?? [])
      || squad?.leader.tostring() == ::g_squad_manager.getLeaderUid()
  }

  function getLeaderName(squad)
  {
    let contact = ::getContact(squad?.leader.tostring())
    return contact? contact.getName() : ""
  }

  function getNumMembers(squad)
  {
    return loc("squad/size", { numMembers = getNumberMembers(squad)
                          maxMembers = getMaxMembers(squad)})
  }

  function getPresence(squad)
  {
    let presenceParams = squad?.data?.presence ?? {}
    return ::g_presence_type.getByPresenceParams(presenceParams).getLocText(presenceParams)
  }

  function onUpdate(_obj, _dt)
  {
    refreshList()
  }

  function updateSquadsListInfo(visibleSquadsAmount)
  {
    let needWaitIcon = !visibleSquadsAmount && squadsListData.isInUpdate
      && !squadsListData.isListValid()
    this.scene.findObject("items_list_wait_icon").show(needWaitIcon)

    local infoText = ""
    if (!visibleSquadsAmount && squadsListData.isListValid())
      infoText = loc("clan/no_squads_in_clan")

    this.scene.findObject("items_list_msg").setValue(infoText)
  }

  function getNumberMembers(squad)
  {
    return (squad?.members ?? []).len()
  }

  function getMaxMembers(squad)
  {
    return squad?.data?.properties?.maxMembers ?? ""
  }

  function onItemSelect(obj)
  {
    let countListItem = curList.len()
    if (countListItem <= 0)
      {
        selectedSquad = null
        selectedIndex = -1
        return
      }

    let index = obj.getValue()
    if (index < 0 || index >= countListItem)
    {
      return
    }

    selectedIndex = index
    selectedSquad = curList[index]
    updateSquadDummyButtons()
  }

  function onLeaderClick(obj)
  {
    let actionSquad = getSquadByObj(obj)
    if (!actionSquad)
      return

    obj = getSquadObj(curList.indexof(actionSquad)).findObject("btn_user_options")
    let position = obj.getPosRC()
    position[1] += obj.getSize()[1]
    let leaderUid = actionSquad?.leader.tostring()
    let contact = leaderUid && ::getContact(leaderUid)
    let leaderName = contact? contact.getName(): ""
    ::g_chat.showPlayerRClickMenu(leaderName, null, contact, position)
  }

  function getSelectedSquadInHover()
  {
    if (!squadsListObj.isHovered())
      return null

    if (selectedIndex < 0 || selectedIndex >= squadsListObj.childrenCount())
      return null

    let squadObj = squadsListObj.getChild(selectedIndex)
    if (!squadObj.isHovered())
      return null

    return selectedSquad
  }

  function getSquadByObj(obj)
  {
    if (!obj)
      return null

    let leaderUidStr = obj?.leaderUid ?? obj.getParent()?.leaderUid
    if (!leaderUidStr)
      return getSelectedSquadInHover()

    let leaderUid = ::to_integer_safe(leaderUidStr)
    foreach (squad in curList)
      if (squad?.leader && squad?.leader == leaderUid)
        return squad

    return null
  }

  function applicationToSquad(actionSquad) {
    let invite = getInvitationInSquad(actionSquad)
    if (invite)
    {
      invite.accept()
      return
    }

    ::g_squad_manager.membershipAplication(actionSquad?.leader)
  }

  revokeApplication = @(actionSquad) ::g_squad_manager.revokeMembershipAplication(actionSquad?.leader)

  function onApplication(obj)
  {
    let actionSquad = getSquadByObj(obj)
    if (!actionSquad)
      return

    applicationToSquad(actionSquad)
  }

  function onRevokeApplication(obj)
  {
    let actionSquad = getSquadByObj(obj)
    if (!actionSquad)
      return

    revokeApplication(actionSquad)
  }

  function onSquadInfo(obj)
  {
    let actionSquad = getSquadByObj(obj)
    if (!actionSquad)
      return

    obj = getSquadObj(curList.indexof(actionSquad)).findObject("btn_squad_info")
    ::gui_handlers.clanSquadInfoWnd.open(obj, actionSquad)
  }

  function onEventPlayerApplicationsChanged(params)
  {
    updateSquadButtonsByleadersUid(params.leadersArr)
  }

  function onEventClanSquadsListChanged(_params)
  {
    updateSquadsList()
  }

  function onEventClanRoomMembersChanged(params = {})
  {
    refreshUserOnlineData(params)
  }

  function updateSquadOnlineStatus(contact)
  {
    let contactUid = contact.uid.tointeger()
    let idx = curList.findindex(@(squad) squad.leader == contactUid)
    if (idx == null)
      return

    let obj = getSquadObj(idx)
    let squad = curList[idx]
    fillPresence(obj, squad)
    updateSquadButtons(obj, squad)
  }

  function refreshOnlineUsersTable()
  {
    let roomId = ::g_chat_room_type.CLAN.roomPrefix + ::clan_get_my_clan_id()
    let room = ::g_chat.getRoomById(roomId)
    if (!room || !("users" in room))
      return

    foreach (user in room.users)
    {
      let contact = ::Contact.getByName(user.name)
      if (contact)
        onlineUsersTable[contact.uid.tointeger()] <- true
    }
  }

  function refreshUserOnlineData(params)
  {
    if (!("nick" in params) || !("presence" in params))
      return

    let contact = ::Contact.getByName(params.nick)
    if (!contact)
      return

    let uid = contact.uid.tointeger()
    onlineUsersTable[uid] <- params.presence != ::g_contact_presence.OFFLINE

    updateSquadOnlineStatus(contact)
  }

  function isSquadOnline(squad)
  {
    return onlineUsersTable?[squad.leader] ?? false
  }

  function onEventSquadStatusChanged(_params)
  {
    if (!::g_squad_manager.isInSquad())
      return false

    let leaderUid = ::g_squad_manager.getLeaderUid()
    if (!leaderUid || leaderUid == "")
      return

    updateSquadButtonsByleadersUid([leaderUid.tointeger()])
  }

  function onEventInviteReceived(params)
  {
    let leaderUid = params.invite?.leaderId
    if (!leaderUid)
      return

    updateSquadButtonsByleadersUid([leaderUid.tointeger()])
  }

  function updateSquadButtonsByleadersUid(leadersArr)
  {
    if (!curList.len())
      return

    local leader = null
    local obj = null
    for (local i = 0; i < curList.len(); i++)
    {
      leader = curList[i].leader
      if (isInArray(leader, leadersArr))
      {
        obj = getSquadObj(i)
        updateSquadButtons(obj, curList[i])
      }
    }
    updateSquadDummyButtons()
  }

  function onSquadActivate() {
    if (canApplyForMembership(selectedSquad)) {
      applicationToSquad(selectedSquad)
      return
    }

    if (canRevokeApplication(selectedSquad)) {
      revokeApplication(selectedSquad)
      return
    }
  }
}
