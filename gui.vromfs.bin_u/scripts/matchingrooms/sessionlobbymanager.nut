from "%scripts/dagui_natives.nut" import in_flight_menu, is_online_available
from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
import "%scripts/matchingRooms/lobbyStates.nut" as lobbyStates
from "%scripts/options/optionsConsts.nut" import misCountries

let { addListenersWithoutEnv, DEFAULT_HANDLER, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { search, isEqual, isArray, isDataBlock, isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { INVALID_SQUAD_ID, INVALID_ROOM_ID, SERVER_ERROR_ROOM_PASSWORD_MISMATCH } = require("matching.errors")
let { set_game_mode, get_game_mode, get_game_type } = require("mission")
let { deferOnce } = require("dagor.workcycle")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { isInFlight } = require("gameplayBinding")
let { getCdBaseDifficulty, get_cd_preset } = require("guiOptions")
let { get_mp_session_id_str } = require("multiplayer")
let { isDynamicWon, dynamicMissionPlayed } = require("dynamicMission")
let { leave_mp_session, quit_to_debriefing, interrupt_multiplayer } = require("guiMission")
let { getPenaltyStatus, BAN } = require("penalty")
let DataBlock = require("DataBlock")
let base64 = require("base64")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let events = getGlobalModule("events")
let { loadHandler, handlersManager, isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let ecs = require("%sqstd/ecs.nut")
let { EventOnConnectedToServer } = require("net")
let { MatchingRoomExtraParams = null } = require_optional("dasevents")
let { set_last_session_debug_info } = require("%scripts/matchingRooms/sessionDebugInfo.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { matchingApiFunc, matchingRpcSubscribe, checkMatchingError } = require("%scripts/matching/api.nut")
let { notifyQueueLeave } = require("%scripts/matching/serviceNotifications/match.nut")
let { gen_rnd_password, get_array_by_bit_value } = require("%scripts/utils_sa.nut")
let { SessionLobbyState, sessionLobbyStatus, getSessionLobbyGameMode, isInSessionRoom, getSessionInfo,
  getSessionLobbyMissionData, updateSessionLobbyPlayersInfo, isMeSessionLobbyRoomOwner, isInSessionLobbyEventRoom,
  resetSessionLobbyPlayersInfo, isInJoiningGame, hasSessionInLobby, getSessionLobbyMyState, isWaitForQueueRoom,
  getSessionLobbyChatRoomPassword, canJoinSession, isRoomInSession, isSessionStartedInRoom, getMembersCount,
  getSessionLobbyPlayerInfoByUid, isMemberHost, isUserMission, getSessionLobbyPublicParam,
  getRoomCreatorUid, getSessionLobbyMaxMembersCount
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { needAutoInviteSquadToSessionRoom, haveLobby, getAvailableTeamOfRoom, getRoomTeamData,
  canSetReadyInLobby, canChangeTeamInLobby, canBeSpectator, getRoomUnitTypesMask, getRoomEvent,
  getRoomMGameMode
} = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { invitePlayerToSessionRoom, getRoomMemberPublicParam, isRoomMemberOperator,
  isRoomMemberInSession
} = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { setMemberAttributes, roomSetReadyState, setRoomAttributes, roomSetPassword, serializeDyncampaign,
  requestLeaveRoom, roomStartSession, requestDestroyRoom, requestJoinRoom, requestCreateRoom
} = require("%scripts/matching/serviceNotifications/mroomsApi.nut")
let { web_rpc } = require("%scripts/webRPC.nut")
let { getProfileInfo } = require("%scripts/user/userInfoStats.nut")
let { getStats, getMissionsComplete } = require("%scripts/myStats.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { userIdInt64, userName, isMyUserId } = require("%scripts/user/profileStates.nut")
let { addDelayedAction } = require("%scripts/utils/delayedActions.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { updateIconPlayersInfo, initListLabelsSquad } = require("%scripts/statistics/squadIcon.nut")
let { debug_dump_stack } = require("dagor.debug")
let { getSessionLobbyMissionName, getUrlOrFileMissionMetaInfo
} = require("%scripts/missions/missionsUtilsModule.nut")
let { updateOverrideSlotbar, resetSlotbarOverrided, getSlotbarOverrideCountriesByMissionName
} = require("%scripts/slotbar/slotbarOverride.nut")
let { addRecentContacts, getContactsGroupUidList } = require("%scripts/contacts/contactsManager.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { isGameModeCoop } = require("%scripts/matchingRooms/matchingGameModesUtils.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { gui_start_mainmenu } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { isRemoteMissionVar, is_user_mission } = require("%scripts/missions/missionsStates.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getMaxEconomicRank } = require("%appGlobals/ranks_common_shared.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { showMsgboxIfEacInactive } = require("%scripts/penitentiary/antiCheat.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { checkShowMultiplayerAasWarningMsg } = require("%scripts/user/antiAddictSystem.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")
let { getEventEconomicName, isEventWithLobby } = require("%scripts/events/eventInfo.nut")
let { clearMpChatLog } = require("%scripts/chat/mpChatModel.nut")
let { setUserPresence } = require("%scripts/userPresence.nut")

/*
SessionLobby API

  all:
    createSessionLobbyRoom(missionSettings)
    isInSessionRoom
    joinSessionRoom
    leaveSessionRoom
    setReady(bool)
    syncAllInfo

  room owner:
    destroyRoom
    updateRoomAttributes(missionSettings)
    invitePlayerToSessionRoom(uid)
    kickPlayerFromRoom(uid)
    startSession

  squad leader:
    startCoopBySquad(missionSettings)

*/

const NET_SERVER_LOST = 0x82220002  //for sessionLobbyHostCb
const NET_SERVER_QUIT_FROM_GAME = 0x82220003

local last_round = true
local delayedJoinRoomFunc = null

let needCheckReconnect = Watched(false)
let isReconnectChecking = mkWatched(persist, "isReconnectChecking", false)

let allowed_mission_settings = { //only this settings are allowed in room
                              //default params used only to check type atm
  name = null
  missionURL = null
  players = 12
  hidden = false  //can be found by search rooms

  creator = ""
  hasPassword = false
  cluster = ""
  allowJIP = true
  coop = true
  friendOnly = false
  country_allies = ["country_ussr"]
  country_axis = ["country_germany"]

  mission = {
    name = "stalingrad_GSn"
    loc_name = ""
    postfix = ""
    _gameMode = 12
    _gameType = 0
    difficulty = "arcade"
    custDifficulty = "0"
    environment = "Day"
    weather = "cloudy"

    maxRespawns = -1
    timeLimit = 0
    killLimit = 0

    raceLaps = 1
    raceWinners = 1
    raceForceCannotShoot = false

    isBotsAllowed = true
    useTankBots = false
    ranks = {}
    useShipBots = false
    keepDead = true
    isLimitedAmmo = false
    isLimitedFuel = false
    optionalTakeOff = false
    dedicatedReplay = false
    allowWebUi = -1
    useKillStreaks = false
    disableAirfields = false
    spawnAiTankOnTankMaps = true
    allowEmptyTeams = false

    isHelicoptersAllowed = false
    isAirplanesAllowed = false
    isTanksAllowed = false
    isShipsAllowed = false

    takeoffMode = 0
    currentMissionIdx = -1
    allowedTagsPreset = ""

    locName = ""
    locDesc = ""
  }
}

function checkSquadAutoInviteToRoom() {
  if (!g_squad_manager.isSquadLeader() || !needAutoInviteSquadToSessionRoom())
    return

  let sMembers = g_squad_manager.getMembers()
  foreach (uid, member in sMembers)
    if (member.online
        && member.isReady
        && !member.isMe()
        && !search(SessionLobbyState.members, @(m) m.userId == uid)) {
      invitePlayerToSessionRoom(uid)
    }
}

function updateMyState() {
  local newState = PLAYER_IN_LOBBY_NOT_READY
  if (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY || sessionLobbyStatus.get() == lobbyStates.START_SESSION)
    newState = SessionLobbyState.isReady ? PLAYER_IN_LOBBY_READY : PLAYER_IN_LOBBY_NOT_READY
  else if (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY_HIDDEN)
    newState = PLAYER_IN_LOBBY_READY
  else if (sessionLobbyStatus.get() == lobbyStates.IN_SESSION)
    newState = PLAYER_IN_FLIGHT
  else if (sessionLobbyStatus.get() == lobbyStates.IN_DEBRIEFING)
    newState = PLAYER_IN_STATISTICS_BEFORE_LOBBY

  SessionLobbyState.myState = newState
  return SessionLobbyState.myState
}

function syncMyInfo(newInfo, cb = @(_) null) {
  if (isInArray(sessionLobbyStatus.get(), [lobbyStates.NOT_IN_ROOM, lobbyStates.WAIT_FOR_QUEUE_ROOM, lobbyStates.CREATING_ROOM, lobbyStates.JOINING_ROOM])
      || !haveLobby()
      || SessionLobbyState.isLeavingLobbySession)
    return

  local syncData = newInfo
  if (!SessionLobbyState._syncedMyInfo)
    SessionLobbyState._syncedMyInfo = newInfo
  else {
    syncData = {}
    foreach (key, value in newInfo) {
      if (key in SessionLobbyState._syncedMyInfo) {
        if (SessionLobbyState._syncedMyInfo[key] == value)
          continue
        if (type(value) == "array" || type(value) == "table")
          if (isEqual(SessionLobbyState._syncedMyInfo[key], value))
            continue
      }
      syncData[key] <- value
      SessionLobbyState._syncedMyInfo[key] <- value
    }
  }

  // DIRTY HACK: Server ignores spectator=true flag if it is sent before pressing Ready button,
  // when Referee joins into already started Skirmish mission.
  if (newInfo?.state == lobbyStates.IN_ROOM)
    syncData.spectator <- SessionLobbyState._syncedMyInfo?.spectator ?? false

  let info = {
    roomId = SessionLobbyState.roomId
    public = syncData
  }

  // Sends info to server
  setMemberAttributes(info, cb)
  broadcastEvent("LobbyMyInfoChanged", syncData)
}

function updateReadyAndSyncMyInfo(ready) {
  SessionLobbyState.isReady = ready
  syncMyInfo({ state = updateMyState() })
  broadcastEvent("LobbyReadyChanged")
}

function updateMemberHostParams(member = null) { //null = host leave
  SessionLobbyState.memberHostId = member ? member.memberId : -1
}

function syncAllInfo() {
  let myInfo = getProfileInfo()
  let myStats = getStats()
  let squadId = g_squad_manager.getSquadData().id
  syncMyInfo({
    team = SessionLobbyState.team
    squad = getSessionLobbyGameMode() == GM_SKIRMISH && squadId != "" ? squadId.tointeger() : INVALID_SQUAD_ID
    country = SessionLobbyState.countryData?.country
    selAirs = SessionLobbyState.countryData?.selAirs
    slots = SessionLobbyState.countryData?.slots
    spectator = SessionLobbyState.spectator
    clanTag = myInfo.clanTag
    title = myStats ? myStats.title : ""
    state = updateMyState()
  })
}

function setMyTeamInRoom(newTeam, silent = false) { //return is team changed
  local _team = newTeam
  let canPlayTeam = getAvailableTeamOfRoom()

  if (canPlayTeam == Team.A || canPlayTeam == Team.B)
    _team = canPlayTeam

  if (SessionLobbyState.team == _team)
    return false

  SessionLobbyState.team = _team

  if (!silent)
    syncMyInfo({ team = SessionLobbyState.team }, @(_) broadcastEvent("MySessionLobbyInfoSynced"))

  return true
}

function setSessionLobbyReady(ready, silent = false, forceRequest = false) { //return is my info changed
  if (!forceRequest && SessionLobbyState.isReady == ready)
    return false
  if (ready && !canSetReadyInLobby(silent)) {
    if (SessionLobbyState.isReady)
      ready = false
    else
      return false
  }

  if (!isInSessionRoom.get()) {
    SessionLobbyState.isReady = false
    return ready
  }

  SessionLobbyState.isReadyInSetStateRoom = ready
  roomSetReadyState(
    { state = ready, roomId = SessionLobbyState.roomId },
    function(p) {
      SessionLobbyState.isReadyInSetStateRoom = null
      if (!isInSessionRoom.get()) {
        SessionLobbyState.isReady = false
        return
      }

      let wasReady = SessionLobbyState.isReady
      local needUpdateState = !silent
      SessionLobbyState.isReady = ready

      //if we receive error on set ready, result is ready == false always.
      if (!checkMatchingError(p, !silent)) {
        SessionLobbyState.isReady = false
        needUpdateState = true
      }

      if (SessionLobbyState.isReady == wasReady)
        return

      if (needUpdateState)
        syncMyInfo({ state = updateMyState() })
      broadcastEvent("LobbyReadyChanged")
    })
  return true
}

function checkMyTeamInRoom() { //returns changed data
  let data = {}

  if (!haveLobby())
    return data

  local setTeamTo = SessionLobbyState.team
  if (getAvailableTeamOfRoom() == Team.none) {
    if (setSessionLobbyReady(false, true))
      data.state <- updateMyState()
    setTeamTo = SessionLobbyState.crsSetTeamTo
  }

  if (setTeamTo != Team.none && setMyTeamInRoom(setTeamTo, true)) {
    data.team <- SessionLobbyState.team
    let myCountry = profileCountrySq.value
    let availableCountries = getRoomTeamData(SessionLobbyState.team)?.countries ?? []
    if (availableCountries.len() > 0 && !isInArray(myCountry, availableCountries))
      switchProfileCountry(availableCountries[0])
  }
  return data
}

function switchMyTeamInRoom(skipTeamAny = false) {
  if (!canChangeTeamInLobby())
    return false

  local newTeam = SessionLobbyState.team + 1
  if (newTeam >= Team.none)
    newTeam = skipTeamAny ? 1 : 0
  return setMyTeamInRoom(newTeam)
}

function setSessionLobbyCountryData(data) { //return is data changed
  local changed = !SessionLobbyState.countryData || !isEqual(SessionLobbyState.countryData, data)
  SessionLobbyState.countryData = data
  let teamDataChanges = checkMyTeamInRoom()
  changed = changed || teamDataChanges.len() > 0
  if (!changed)
    return false

  foreach (i, v in teamDataChanges)
    data[i] <- v
  syncMyInfo(data, @(_) broadcastEvent("MySessionLobbyInfoSynced"))
  return true
}

function setSpectator(newSpectator) { //return is spectator changed
  if (!canBeSpectator())
    newSpectator = false
  if (SessionLobbyState.spectator == newSpectator)
    return false

  SessionLobbyState.spectator = newSpectator
  syncMyInfo({ spectator = SessionLobbyState.spectator }, @(_) broadcastEvent("MySessionLobbyInfoSynced"))
  return true
}

function switchSpectator() {
  if (!canBeSpectator() && !SessionLobbyState.spectator)
    return false

  local newSpectator = !SessionLobbyState.spectator
  return setSpectator(newSpectator)
}

function validateTeamAndReady() {
  let teamDataChanges = checkMyTeamInRoom()
  if (!teamDataChanges.len()) {
    if (SessionLobbyState.isReady && !canSetReadyInLobby(true))
      setSessionLobbyReady(false)
    return
  }
  syncMyInfo(teamDataChanges, @(_) broadcastEvent("MySessionLobbyInfoSynced"))
}

function userInUidsList(list_name) {
  let ids = getSessionInfo()?[list_name]
  if (isArray(ids))
    return isInArray(userIdInt64.value, ids)
  return false
}

function updateCrsSettings() {
  SessionLobbyState.isSpectatorSelectLocked = false

  if (userInUidsList("referees") || userInUidsList("spectators")) {
    SessionLobbyState.isSpectatorSelectLocked = true
    setSpectator(SessionLobbyState.isSpectatorSelectLocked)
  }

  SessionLobbyState.crsSetTeamTo = Team.none
  foreach (team in events.getSidesList()) {
    let players = getSessionInfo()?[events.getTeamName(team)].players
    if (!isArray(players))
      continue

    foreach (uid in players)
      if (isMyUserId(uid)) {
        SessionLobbyState.crsSetTeamTo = team
        break
      }

    if (SessionLobbyState.crsSetTeamTo != Team.none)
      break
  }
}

function initMyParamsByMemberInfo(me = null) {
  if (!me)
    me = search(SessionLobbyState.members, function(m) { return isMyUserId(m.userId) })
  if (!me)
    return

  let myTeam = getRoomMemberPublicParam(me, "team")
  if (myTeam != Team.Any && myTeam != SessionLobbyState.team)
    SessionLobbyState.team = myTeam

  if (myTeam == Team.Any)
    validateTeamAndReady()
}

function addTeamsInfoToSettings(v_settings, teamDataA, teamDataB) {
  v_settings[events.getTeamName(Team.A)] <- teamDataA
  v_settings[events.getTeamName(Team.B)] <- teamDataB
}

function fillTeamsInfo(v_settings, _misBlk) {
  //!!fill simmetric teams data
  let teamData = {}
  teamData.allowedCrafts <- []

  foreach (unitType in unitTypes.types)
    if (unitType.isAvailableByMissionSettings(v_settings.mission) && unitType.isPresentOnMatching) {
      let rule = { ["class"] = unitType.getMissionAllowedCraftsClassName() }
      if (v_settings?.mranks)
        rule.mranks <- v_settings.mranks
      teamData.allowedCrafts.append(rule)
    }

  //!!fill assymetric teamdata
  let teamDataA = teamData
  local teamDataB = clone teamData

  //in future better to comletely remove old countries selection, and use only countries in teamData
  teamDataA.countries <- v_settings.country_allies
  teamDataB.countries <- v_settings.country_axis

  addTeamsInfoToSettings(v_settings, teamDataA, teamDataB)
}

function leaveEventSessionWithRetry() {
  SessionLobbyState.isLeavingLobbySession = true
  let self = callee()
  matchingApiFunc("mrooms.leave_session",
    function(params) {
      // there is a some lag between actual disconnect from host and disconnect detection
      // just try to leave until host says that player is not in session anymore
      if (params?.error_id == "MATCH.PLAYER_IN_SESSION")
        addDelayedAction(self, 1000)
      else {
        SessionLobbyState.isLeavingLobbySession = false
        broadcastEvent("LobbyStatusChange")
      }
    })
}

function getDifficulty(room = null) {
  let diffValue = getSessionLobbyMissionData(room)?.difficulty
  let difficulty = (diffValue == "custom")
    ? g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty())
    : g_difficulty.getDifficultyByName(diffValue)
  return difficulty
}

function calcEdiff(room = null) {
  return getDifficulty(room).getEdiffByUnitMask(getRoomUnitTypesMask(room))
}

function updatePlayersInfo() {
  updateSessionLobbyPlayersInfo()
  updateIconPlayersInfo()
}

function setCustomPlayersInfo(customPlayersInfo) {
  SessionLobbyState.playersInfo = customPlayersInfo
  updateIconPlayersInfo()
}

function setIngamePresence(roomPublic, roomId) {
  local team = 0
  let myPinfo = getSessionLobbyPlayerInfoByUid(userIdInt64.value)
  if (myPinfo != null)
    team = myPinfo.team

  let inGamePresence = {
    gameModeId = getTblValue("game_mode_id", roomPublic)
    gameQueueId = getTblValue("game_queue_id", roomPublic)
    mission    = getTblValue("mission", roomPublic)
    roomId     = roomId
    team       = team
  }
  setUserPresence({ in_game_ex = inGamePresence })
}

function setExternalSessionId(extId) {
  if (SessionLobbyState.settings?.externalSessionId == extId)
    return

  SessionLobbyState.settings["externalSessionId"] <- extId
  setRoomAttributes({ roomId = SessionLobbyState.roomId, public = SessionLobbyState.settings }, @(p) broadcastEvent("RoomAttributesUpdated", p))
}

function setSettings(v_settings, notify = false, checkEqual = true) {
  if (type(v_settings) == "array") {
    log("v_settings param, public info, is array, instead of table")
    debug_dump_stack()
    return
  }

  if (checkEqual && isEqual(SessionLobbyState.settings, v_settings))
    return

  //v_settings can be publick date of room, and it does not need to be updated settings somewhere else
  SessionLobbyState.settings = clone v_settings
  //not mission room settings
  SessionLobbyState.settings.connect_on_join <- !haveLobby()

  updateCrsSettings()
  updatePlayersInfo()
  updateOverrideSlotbar(getSessionLobbyMissionName(true))

  SessionLobbyState.curEdiff = calcEdiff(SessionLobbyState.settings)

  SessionLobbyState.roomUpdated = notify || !isMeSessionLobbyRoomOwner.get() || !isInSessionRoom.get() || isInSessionLobbyEventRoom.get()
  if (!SessionLobbyState.roomUpdated)
    setRoomAttributes({ roomId = SessionLobbyState.roomId, public = SessionLobbyState.settings }, @(p) broadcastEvent("RoomAttributesUpdated", p))

  if (isInSessionRoom.get())
    validateTeamAndReady()

  let newGm = getSessionLobbyGameMode()
  if (newGm >= 0)
    set_game_mode(newGm)

  broadcastEvent("LobbySettingsChange")
}

function checkDynamicSettings(silent = false, v_settings = null) {
  if (!isMeSessionLobbyRoomOwner.get() && isInSessionRoom.get())
    return

  if (!v_settings) {
    if (!SessionLobbyState.settings || !SessionLobbyState.settings.len())
      return //owner have joined back to the room, and not receive settings yet
    v_settings = SessionLobbyState.settings
  }
  else
    silent = true //no need to update when custom settings checked

  local changed = false
  let wasHidden = getTblValue("hidden", v_settings, false)
  v_settings.hidden <- getTblValue("coop", v_settings, false)
    || (isRoomInSession.get() && !getTblValue("allowJIP", v_settings, true))
  changed = changed || (wasHidden != v_settings.hidden) // warning disable: -const-in-bool-expr

  let wasPassword = getTblValue("hasPassword", v_settings, false)
  v_settings.hasPassword <- SessionLobbyState.password != ""
  changed = changed || (wasPassword != v_settings.hasPassword)

  if (changed && !silent)
    setSettings(SessionLobbyState.settings, false, false)
}

function changeRoomPassword(v_password) {
  if (type(v_password) != "string" || SessionLobbyState.password == v_password)
    return

  if (isMeSessionLobbyRoomOwner.get() && sessionLobbyStatus.get() != lobbyStates.NOT_IN_ROOM && sessionLobbyStatus.get() != lobbyStates.CREATING_ROOM) {
    let prevPass = SessionLobbyState.password
    roomSetPassword({ roomId = SessionLobbyState.roomId, password = v_password },
      function(p) {
        if (!checkMatchingError(p)) {
          SessionLobbyState.password = prevPass
          checkDynamicSettings()
        }
      })
  }
  SessionLobbyState.password = v_password
}

function resetParams() {
  SessionLobbyState.settings.clear()
  changeRoomPassword("") //reset password after leave room
  updateMemberHostParams(null)
  SessionLobbyState.team = Team.Any
  SessionLobbyState.isRoomByQueue = false
  isInSessionLobbyEventRoom.set(false)
  SessionLobbyState.myState = PLAYER_IN_LOBBY_NOT_READY
  SessionLobbyState.roomUpdated = false
  SessionLobbyState.spectator = false
  SessionLobbyState._syncedMyInfo = null
  SessionLobbyState.needJoinSessionAfterMyInfoApply = false
  SessionLobbyState.isLeavingLobbySession = false
  resetSessionLobbyPlayersInfo()
  resetSlotbarOverrided()
  setUserPresence({ in_game_ex = null })
}

function guiStartMpLobby() {
  if (sessionLobbyStatus.get() != lobbyStates.IN_LOBBY) {
    gui_start_mainmenu()
    return
  }

  local backFromLobby = { eventbusName = "gui_start_mainmenu" }
  if (getSessionLobbyGameMode() == GM_SKIRMISH && !isRemoteMissionVar.get())
    backFromLobby = { eventbusName = "guiStartSkirmish" }
  else {
    let lastEvent = getRoomEvent()
    if (lastEvent && events.eventRequiresTicket(lastEvent) && events.getEventActiveTicket(lastEvent) == null) {
      gui_start_mainmenu()
      return
    }
  }

  isRemoteMissionVar.set(false)
  loadHandler(gui_handlers.MPLobby, { backSceneParams = backFromLobby })
}

let joiningGameWaitBox = @() loadHandler(gui_handlers.JoiningGameWaitBox)

function switchStatus(v_status) {
  if (sessionLobbyStatus.get() == v_status)
    return

  let wasInRoom = isInSessionRoom.get()
  let wasStatus = sessionLobbyStatus.get()
  let wasSessionInLobby = isInSessionLobbyEventRoom.get()
  sessionLobbyStatus.set(v_status)  //for easy notify other handlers about change status
  if (isInJoiningGame.get())
    joiningGameWaitBox()
  if (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY) {
    //delay to allow current view handlers to catch room state change event before destroy
    deferOnce(guiStartMpLobby)
  }

  if (sessionLobbyStatus.get() == lobbyStates.IN_DEBRIEFING && hasSessionInLobby())
    leaveEventSessionWithRetry()

  if (sessionLobbyStatus.get() == lobbyStates.NOT_IN_ROOM || sessionLobbyStatus.get() == lobbyStates.IN_DEBRIEFING)
    setSessionLobbyReady(false, true)
  if (sessionLobbyStatus.get() == lobbyStates.NOT_IN_ROOM) {
    resetParams()
    if (wasStatus == lobbyStates.JOINING_SESSION)
      ::destroy_session_scripted("on leave room while joining session")
  }
  if (sessionLobbyStatus.get() == lobbyStates.JOINING_SESSION)
    addRecentContacts(g_squad_manager.getSquadMembersDataForContact())

  let curState = getSessionLobbyMyState()
  let newState = updateMyState()
  if (curState != newState)
    syncMyInfo({ state = newState })

  broadcastEvent("LobbyStatusChange")
  eventbus_send("setIsMultiplayerState", { isMultiplayer = isInSessionRoom.get() })
  if (wasInRoom != isInSessionRoom.get())
    broadcastEvent("LobbyIsInRoomChanged", { wasSessionInLobby })
}

function switchStatusChecked(oldStatusList, newStatus) {
  if (isInArray(sessionLobbyStatus.get(), oldStatusList))
    switchStatus(newStatus)
}

function setWaitForQueueRoom(set) {
  if (sessionLobbyStatus.get() == lobbyStates.NOT_IN_ROOM || sessionLobbyStatus.get() == lobbyStates.WAIT_FOR_QUEUE_ROOM)
    switchStatus(set ? lobbyStates.WAIT_FOR_QUEUE_ROOM : lobbyStates.NOT_IN_ROOM)
}

function leaveWaitForQueueRoom() {
  if (!isWaitForQueueRoom.get())
    return

  setWaitForQueueRoom(false)
  addPopup(null, loc("NET_CANNOT_ENTER_SESSION"))
}

function findParam(key, tbl1, tbl2) {
  if (key in tbl1)
    return tbl1[key]
  if (key in tbl2)
    return tbl2[key]
  return null
}

function validateMissionCountry(country, fullCountriesList) {
  if (isInArray(country, fullCountriesList))
    return null
  if (isInArray($"country_{country}", fullCountriesList))
    return $"country_{country}"
  return null
}

function prepareSettings(missionSettings) {
  let _settings = {}
  let mission = missionSettings.mission

  foreach (key, v in allowed_mission_settings) {
    if (key == "mission")
      continue
    local value = findParam(key, missionSettings, mission)
    if (type(v) == "array" && type(value) != "array")
      value = [value]
    _settings[key] <- value //value == null will clear param on server
  }

  _settings.mission <- {}
  foreach (key, _v in allowed_mission_settings.mission) {
    local value = findParam(key, mission, missionSettings)
    if (key == "postfix")
      value = getTblValue(key, missionSettings)
    if (value == null)
      continue

    _settings.mission[key] <- isDataBlock(value) ? convertBlk(value) : value
  }

  _settings.mission.keepOwnUnits <- mission?.editSlotbar?.keepOwnUnits ?? true
  _settings.creator <- userName.value
  _settings.mission.originalMissionName <- getTblValue("name", _settings.mission, "")
  if ("postfix" in _settings.mission && _settings.mission.postfix) {
    let ending = "_tm"
    local nameNoTm = _settings.mission.name
    if (nameNoTm.len() > ending.len() && nameNoTm.slice(nameNoTm.len() - ending.len()) == ending)
      nameNoTm = nameNoTm.slice(0, nameNoTm.len() - ending.len())
    _settings.mission.loc_name = $"{nameNoTm}{_settings.mission.postfix}"
    _settings.mission.name = $"{_settings.mission.name}{_settings.mission.postfix}"
  }
  if (is_user_mission(mission))
    _settings.userMissionName <- loc($"missions/{mission.name}")
  if (!("_gameMode" in _settings.mission))
    _settings.mission._gameMode <- get_game_mode()
  if (!("_gameType" in _settings.mission))
    _settings.mission._gameType <- get_game_type()
  if (getTblValue("coop", _settings) == null)
    _settings.coop <- isGameModeCoop(_settings.mission._gameMode)
  if (("difficulty" in _settings.mission) && _settings.mission.difficulty == "custom")
    _settings.mission.custDifficulty <- get_cd_preset(DIFFICULTY_CUSTOM)

  //validate Countries
  let countriesType = getTblValue("countriesType", missionSettings, misCountries.ALL)
  local fullCountriesList = getSlotbarOverrideCountriesByMissionName(_settings.mission.originalMissionName)
  if (!fullCountriesList.len())
    fullCountriesList = clone shopCountriesList
  foreach (name in ["country_allies", "country_axis"]) {
    local countries = null
    if (countriesType == misCountries.BY_MISSION) {
      countries = getTblValue(name, _settings, [])
      for (local i = countries.len() - 1; i >= 0; i--) {
        countries[i] = validateMissionCountry(countries[i], fullCountriesList)
        if (!countries[i])
          countries.remove(i)
      }
    }
    else if (countriesType == misCountries.SYMMETRIC || countriesType == misCountries.CUSTOM) {
      let bitMaskKey = (countriesType == misCountries.SYMMETRIC) ? "country_allies" : name
      countries = get_array_by_bit_value(getTblValue($"{bitMaskKey}_bitmask", missionSettings, 0), shopCountriesList)
    }
    _settings[name] <- (countries && countries.len()) ? countries : fullCountriesList
  }

  let userAllowedUnitTypesMask = missionSettings?.userAllowedUnitTypesMask ?? 0
  if (userAllowedUnitTypesMask)
    foreach (unitType in unitTypes.types)
      if (unitType.isAvailableByMissionSettings(_settings.mission) && !(userAllowedUnitTypesMask & unitType.bit) && unitType.isPresentOnMatching)
        _settings.mission[unitType.missionSettingsAvailabilityFlag] = false

  local mrankMin = missionSettings?.mrankMin ?? 0
  local mrankMax = missionSettings?.mrankMax ?? getMaxEconomicRank()
  if (mrankMin > mrankMax) {
    let temp = mrankMin
    mrankMin = mrankMax
    mrankMax = temp
  }
  if (mrankMin > 0 || mrankMax < getMaxEconomicRank())
    _settings.mranks <- { min = mrankMin, max = mrankMax }

  _settings.chatPassword <- isInSessionRoom.get() ? getSessionLobbyChatRoomPassword() : gen_rnd_password(16)
  if (!isEmpty(SessionLobbyState.settings?.externalSessionId))
    _settings.externalSessionId <- SessionLobbyState.settings?.externalSessionId
  if (!isEmpty(SessionLobbyState.settings?.psnMatchId))
    _settings.psnMatchId <- SessionLobbyState.settings?.psnMatchId

  fillTeamsInfo(_settings, mission)

  checkDynamicSettings(true, _settings)
  setSettings(_settings)
}

function returnStatusToRoom() {
  local newStatus = lobbyStates.IN_ROOM
  if (haveLobby())
    newStatus = SessionLobbyState.isRoomByQueue ? lobbyStates.IN_LOBBY_HIDDEN : lobbyStates.IN_LOBBY
  switchStatus(newStatus)
}

function updateRoomAttributes(missionSettings) {
  if (!isMeSessionLobbyRoomOwner.get())
    return

  prepareSettings(missionSettings)
}

function continueCoopWithSquad(missionSettings) {
  switchStatus(lobbyStates.IN_ROOM)
  prepareSettings(missionSettings)
}

//return true if success
function goForwardSessionLobbyAfterDebriefing() {
  if (!haveLobby() || !isInSessionRoom.get())
    return false

  SessionLobbyState.isRoomByQueue = false //from now it not room by queue because we are back to lobby from session
  if (sessionLobbyStatus.get() == lobbyStates.IN_LOBBY)
    guiStartMpLobby()
  else
    returnStatusToRoom()
  return true
}

let sendSessionRoomLeavedEvent = @() broadcastEvent("SessionRoomLeaved")

function leaveSessionRoom() {
  if (sessionLobbyStatus.get() == lobbyStates.NOT_IN_ROOM || sessionLobbyStatus.get() == lobbyStates.WAIT_FOR_QUEUE_ROOM) {
    setWaitForQueueRoom(false)
    return
  }

  requestLeaveRoom({}, @(_) sendSessionRoomLeavedEvent())
}

function joinEventSession(needLeaveRoomOnError = false, params = null) {
  matchingApiFunc("mrooms.join_session",
    function(params_) {
      if (!checkMatchingError(params_) && needLeaveRoomOnError)
        leaveSessionRoom()
    },
    params
  )
}

//matching update slots from char when ready flag set to true
function checkUpdateMatchingSlots() {
  if (hasSessionInLobby()) {
    if (SessionLobbyState.isInLobbySession)
      joinEventSession(false, { update_profile = true })
  }
  else if (SessionLobbyState.isReady && (SessionLobbyState.isReadyInSetStateRoom == null || SessionLobbyState.isReadyInSetStateRoom))
    setSessionLobbyReady(SessionLobbyState.isReady, true, true)
}

function tryJoinSession(needLeaveRoomOnError = false) {
  if (!canJoinSession())
    return false

  if (hasSessionInLobby()) {
    joinEventSession(needLeaveRoomOnError)
    return true
  }
  if (isRoomInSession.get()) {
    setSessionLobbyReady(true)
    return true
  }
  return false
}

function checkLeaveRoomInDebriefing() {
  if (get_game_mode() == GM_DYNAMIC && !isDynamicWon())
    return

  if (!last_round)
    return

  if (isInSessionRoom.get() && !haveLobby())
    leaveSessionRoom()
}

function setRoomInSession(newIsInSession) {
  if (newIsInSession == isRoomInSession.get())
    return

  isRoomInSession.set(newIsInSession)
  if (!isInSessionRoom.get())
    return

  broadcastEvent("LobbyRoomInSession")
  if (isMeSessionLobbyRoomOwner.get())
    checkDynamicSettings()
}

function onSettingsChanged(p) {
  if (SessionLobbyState.roomId != p.roomId)
    return
  let set = getTblValue("public", p)
  if (!set)
    return

  if ("last_round" in set) {
    last_round = set.last_round
    log($"last round {last_round}")
  }

  let newSet = clone SessionLobbyState.settings
  foreach (k, v in set)
    if (v == null) {
      newSet?.$rawdelete(k)
    }
    else
      newSet[k] <- v

  setSettings(newSet, true)
  setRoomInSession(isSessionStartedInRoom())
}

function mergeTblChanges(tblBase, tblNew) {
  if (tblNew == null)
    return tblBase

  foreach (key, value in tblNew)
    if (value != null)
      tblBase[key] <- value
    else if (key in tblBase)
      tblBase.$rawdelete(key)
  return tblBase
}

function onMemberInfoUpdate(params) {
  if (params.roomId != SessionLobbyState.roomId)
    return
  if (isMemberHost(params))
    return updateMemberHostParams(params)

  local member = null
  foreach (m in SessionLobbyState.members)
    if (m.memberId == params.memberId) {
      member = m
      break
    }
  if (!member)
    return

  foreach (tblName in ["public", "private"])
    if (tblName in params)
      if (tblName in member)
        mergeTblChanges(member[tblName], params[tblName])
      else
        member[tblName] <- params[tblName]

  if (isMyUserId(member.userId)) {
    isMeSessionLobbyRoomOwner.set(isRoomMemberOperator(member))
    SessionLobbyState.isInLobbySession = isRoomMemberInSession(member)
    initMyParamsByMemberInfo(member)
    let ready = getTblValue("ready", getTblValue("public", member, {}), null)
    if (!hasSessionInLobby() && ready != null && ready != SessionLobbyState.isReady)
      updateReadyAndSyncMyInfo(ready)
    else if (SessionLobbyState.needJoinSessionAfterMyInfoApply)
      tryJoinSession(true)
    SessionLobbyState.needJoinSessionAfterMyInfoApply = false
  }
  broadcastEvent("LobbyMemberInfoChanged")
}

function isMissionReady() {
  return !isUserMission() ||
    (sessionLobbyStatus.get() != lobbyStates.UPLOAD_CONTENT && SessionLobbyState.uploadedMissionId == getSessionLobbyMissionName())
}

function uploadUserMission(afterDoneFunc = null) {
  if (!isInSessionRoom.get() || !isUserMission() || sessionLobbyStatus.get() == lobbyStates.UPLOAD_CONTENT)
    return

  let missionId = getSessionLobbyMissionName()
  if (SessionLobbyState.uploadedMissionId == missionId) {
    afterDoneFunc?()
    return
  }

  let missionInfo = DataBlock()
  missionInfo.setFrom(getUrlOrFileMissionMetaInfo(missionId))
  let missionBlk = DataBlock()
  if (missionInfo)
    missionBlk.load(missionInfo.mis_file)
  //dlog("GP: upload mission!")
  //debugTableData(missionBlk)

  let blkData = base64.encodeBlk(missionBlk)
  //dlog($"GP: data = {blkData}")
  //debugTableData(blkData)
  if (!blkData || !("result" in blkData) || !blkData.result.len()) {
    showInfoMsgBox(loc("msg/cant_load_user_mission"))
    return
  }

  switchStatus(lobbyStates.UPLOAD_CONTENT)
  setRoomAttributes({ roomId = SessionLobbyState.roomId, private = { userMission = blkData.result } },
                        function(p) {
                          if (!checkMatchingError(p)) {
                            returnStatusToRoom()
                            return
                          }
                          SessionLobbyState.uploadedMissionId = missionId
                          returnStatusToRoom()
                          if (afterDoneFunc)
                            afterDoneFunc()
                        })
}

function destroyRoom() {
  if (!isMeSessionLobbyRoomOwner.get())
    return

  requestDestroyRoom({ roomId = SessionLobbyState.roomId }, @(_) null)
  sendSessionRoomLeavedEvent()
}

function startSession() {
  if (sessionLobbyStatus.get() != lobbyStates.IN_ROOM
      && sessionLobbyStatus.get() != lobbyStates.IN_LOBBY
      && sessionLobbyStatus.get() != lobbyStates.IN_LOBBY_HIDDEN)
    return
  if (!isMissionReady()) {
    let self = callee()
    uploadUserMission(self)
    return
  }
  log("start session")

  roomStartSession({ roomId = SessionLobbyState.roomId, cluster = getSessionLobbyPublicParam("cluster", "EU") },
    function(p) {
      if (!isInSessionRoom.get())
        return
      if (!checkMatchingError(p)) {
        if (!haveLobby())
          destroyRoom()
        else if (isInMenu())
          returnStatusToRoom()
        return
      }
      switchStatus(lobbyStates.JOINING_SESSION)
    })
  switchStatus(lobbyStates.START_SESSION)
}

function checkAutoStart() {
  if (isMeSessionLobbyRoomOwner.get() && !SessionLobbyState.isRoomByQueue && !haveLobby() && SessionLobbyState.roomUpdated
      && g_squad_manager.getOnlineMembersCount() <= getMembersCount())
    startSession()
}

function onMemberJoin(params) {
  if (isMemberHost(params))
    return updateMemberHostParams(params)

  foreach (m in SessionLobbyState.members)
    if (m.memberId == params.memberId) {
      onMemberInfoUpdate(params)
      return
    }
  SessionLobbyState.members.append(params)
  broadcastEvent("LobbyMembersChanged")
  checkAutoStart()
}

function afterRoomUpdate(params) {
  if (!checkMatchingError(params, false))
    return destroyRoom()

  SessionLobbyState.roomUpdated = true
  checkAutoStart()
}

function sessionLobbyHostCb(res) {
  if ((type(res) == "table") && ("errCode" in res)) {
    local errorCode;
    if (res.errCode == 0) {
      if (get_game_mode() == GM_DOMINATION)
        errorCode = NET_SERVER_LOST
      else
        errorCode = NET_SERVER_QUIT_FROM_GAME
    }
    else
      errorCode = res.errCode

    needCheckReconnect.set(true)

    if (isInSessionRoom.get())
      if (haveLobby())
        returnStatusToRoom()
      else
        leaveSessionRoom()

    ::error_message_box("yn1/connect_error", errorCode,
      [["ok", @() ::destroy_session_scripted("on error message from host") ]],
      "ok",
      { saved = true })
  }
}

function sendJoinRoomRequest(join_params, _cb = function(...) {}) {
  if (isInSessionRoom.get())
    leaveSessionRoom() //leave old room before join the new one

  leave_mp_session()

  if (!isMeSessionLobbyRoomOwner.get()) {
    setSettings({})
    SessionLobbyState.members = []
  }

  set_last_session_debug_info(
    ("roomId" in join_params) ? ($"room:{join_params.roomId}") :
    ("battleId" in join_params) ? ($"battle:{join_params.battleId}") :
    ""
  )

  switchStatus(lobbyStates.JOINING_ROOM)
  requestJoinRoom(join_params, @(p) broadcastEvent("JoinedToSessionRoom", p))
}

function joinBattle(battleId) {
  ::queues.leaveAllQueuesSilent()
  notifyQueueLeave({})
  isMeSessionLobbyRoomOwner.set(false)
  SessionLobbyState.isRoomByQueue = false
  sendJoinRoomRequest({ battleId = battleId })
}

function joinSessionRoom(v_roomId, senderId = "", v_password = null,
                                cb = function(...) {}) { //by default not a queue, but no id too
  if (SessionLobbyState.roomId == v_roomId && isInSessionRoom.get())
    return

  if (!isLoggedIn.get() || isInSessionRoom.get()) {
    let self = callee()
    delayedJoinRoomFunc =  @() self(v_roomId, senderId, v_password, cb)

    if (isInSessionRoom.get())
      leaveSessionRoom()
    return
  }

  isMeSessionLobbyRoomOwner.set(isMyUserId(senderId))
  SessionLobbyState.isRoomByQueue = senderId == null

  if (SessionLobbyState.isRoomByQueue)
    notifyQueueLeave({})
  else
    ::queues.leaveAllQueuesSilent()

  if (v_password && v_password.len())
    changeRoomPassword(v_password)

  let joinParams = { roomId = v_roomId }
  if (SessionLobbyState.password != "")
    joinParams.password <- SessionLobbyState.password

  sendJoinRoomRequest(joinParams, cb)
}

function reconnect(roomId, gameModeName) {
  let event = events.getEvent(gameModeName)
  if (!showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event))
    return

  if (event != null) {
    checkShowMultiplayerAasWarningMsg(@() joinSessionRoom(roomId))
    return
  }

  joinSessionRoom(roomId)
}

function onCheckReconnect(response) {
  isReconnectChecking(false)

  let roomId = response?.roomId
  let gameModeName = response?.game_mode_name
  if (!roomId || !gameModeName)
    return

  scene_msg_box("backToBattle_dialog", null, loc("msgbox/return_to_battle_session"), [
    ["yes", @() reconnect(roomId, gameModeName)],
    ["no"]], "yes")
}

function isMeBanned() {
  return getPenaltyStatus().status == BAN
}

function checkReconnect() {
  if (isReconnectChecking.value || !isLoggedIn.get() || isInBattleState.value || isMeBanned())
    return

  isReconnectChecking(true)
  matchingApiFunc("match.check_reconnect", onCheckReconnect)
}

function afterLeaveRoom() {
  if (delayedJoinRoomFunc != null) {
    deferOnce(delayedJoinRoomFunc)
    delayedJoinRoomFunc = null
  }
  SessionLobbyState.roomId = INVALID_ROOM_ID
  switchStatus(lobbyStates.NOT_IN_ROOM)

  if (needCheckReconnect.get()) {
    needCheckReconnect.set(false)
    deferOnce(checkReconnect) //notify room leave will be received soon
  }
}

function joinSessionRoomWithPassword(joinRoomId, prevPass = "", wasEntered = false) {
  if (joinRoomId == "") {
    assert(false, "SessionLobby Error: try to join room with password with empty room id")
    return
  }

  openEditBoxDialog({
    value = prevPass
    title = loc("mainmenu/password")
    label = wasEntered ? loc("matching/SERVER_ERROR_ROOM_PASSWORD_MISMATCH") : ""
    isPassword = true
    allowEmpty = false
    okFunc = @(pass) joinSessionRoom(joinRoomId, "", pass)
  })
}

function joinSessionLobbyFoundRoom(room) { //by default not a queue, but no id too
  if (("hasPassword" in room) && room.hasPassword && getRoomCreatorUid(room) != userName.value)
    joinSessionRoomWithPassword(room.roomId)
  else
    joinSessionRoom(room.roomId)
}

function afterRoomJoining(params) {
  if (params.error == SERVER_ERROR_ROOM_PASSWORD_MISMATCH) {
    let joinRoomId = params.roomId //not_in_room status will clear room Id
    let oldPass = params.password
    switchStatus(lobbyStates.NOT_IN_ROOM)
    joinSessionRoomWithPassword(joinRoomId, oldPass, oldPass != "")
    return
  }

  if (!checkMatchingError(params))
    return switchStatus(lobbyStates.NOT_IN_ROOM)

  SessionLobbyState.roomId = params.roomId
  SessionLobbyState.roomUpdated = true
  SessionLobbyState.members = getTblValue("members", params, [])
  initMyParamsByMemberInfo()
  clearMpChatLog()
  ::g_squad_utils.updateMyCountryData()

  let public = getTblValue("public", params, SessionLobbyState.settings)
  if (!isMeSessionLobbyRoomOwner.get() || isEmpty(SessionLobbyState.settings)) {
    setSettings(public)

    let mGameMode = getRoomMGameMode()
    if (mGameMode) {
      setIngamePresence(public, SessionLobbyState.roomId)
      isInSessionLobbyEventRoom.set(isEventWithLobby(mGameMode))
    }
    log($"Joined room: isInSessionLobbyEventRoom {isInSessionLobbyEventRoom.get()}")

    if (SessionLobbyState.isRoomByQueue && !isSessionStartedInRoom())
      SessionLobbyState.isRoomByQueue = false
    if (isInSessionLobbyEventRoom.get() && !SessionLobbyState.isRoomByQueue && haveLobby())
      SessionLobbyState.needJoinSessionAfterMyInfoApply = true
  }

  for (local i = SessionLobbyState.members.len() - 1; i >= 0; i--)
    if (isMemberHost(SessionLobbyState.members[i])) {
      updateMemberHostParams(SessionLobbyState.members[i])
      SessionLobbyState.members.remove(i)
    }
    else if (isMyUserId(SessionLobbyState.members[i].userId))
      isMeSessionLobbyRoomOwner.set(isRoomMemberOperator(SessionLobbyState.members[i]))

  returnStatusToRoom()
  syncAllInfo()

  checkSquadAutoInviteToRoom()

  let event = getRoomEvent()
  if (event) {
    if (events.isEventVisibleInEventsWindow(event))
      saveLocalByAccount("lastPlayedEvent", {
        eventName = event.name
        economicName = getEventEconomicName(event)
      })

    broadcastEvent("AfterJoinEventRoom", event)
  }

  if (isMeSessionLobbyRoomOwner.get() && get_game_mode() == GM_DYNAMIC && !dynamicMissionPlayed()) {
    serializeDyncampaign(
      function(p) {
        if (checkMatchingError(p))
          checkAutoStart()
        else
          destroyRoom()
      })
  }
  else
    checkAutoStart()
  initListLabelsSquad()

  last_round = public?.last_round ?? true
  setRoomInSession(isSessionStartedInRoom())
  broadcastEvent("RoomJoined", params)
}

function afterRoomCreation(params) {
  if (!checkMatchingError(params))
    return switchStatus(lobbyStates.NOT_IN_ROOM)

  isMeSessionLobbyRoomOwner.set(true)
  SessionLobbyState.isRoomByQueue = false
  afterRoomJoining(params)
}

function startCoopBySquad(missionSettings) {
  if (sessionLobbyStatus.get() != lobbyStates.NOT_IN_ROOM)
    return false

  prepareSettings(missionSettings)

  requestCreateRoom({ size = 4, public = SessionLobbyState.settings }, afterRoomCreation)
  switchStatus(lobbyStates.CREATING_ROOM)
  return true
}

function createSessionLobbyRoom(missionSettings) {
  if (sessionLobbyStatus.get() != lobbyStates.NOT_IN_ROOM)
    return false

  prepareSettings(missionSettings)

  let initParams = {
    size = getSessionLobbyMaxMembersCount()
    public = SessionLobbyState.settings
  }
  if (SessionLobbyState.password && SessionLobbyState.password != "")
    initParams.password <- SessionLobbyState.password
  let blacklist = getContactsGroupUidList(EPL_BLOCKLIST)
  if (blacklist.len())
    initParams.blacklist <- blacklist

  requestCreateRoom(initParams, afterRoomCreation)
  switchStatus(lobbyStates.CREATING_ROOM)
  return true
}

function createSessionLobbyEventRoom(mGameMode, lobbyParams) {
  if (sessionLobbyStatus.get() != lobbyStates.NOT_IN_ROOM)
    return false

  let params = {
    public = {
      game_mode_id = mGameMode.gameModeId
    }
    custom_matching_lobby = lobbyParams
  }

  isInSessionLobbyEventRoom.set(true)
  requestCreateRoom(params, afterRoomCreation)
  switchStatus(lobbyStates.CREATING_ROOM)
  return true
}

function onMemberLeave(params, kicked = false) {
  if (isMemberHost(params))
    return updateMemberHostParams(null)

  foreach (idx, m in SessionLobbyState.members)
    if (params.memberId == m.memberId) {
      SessionLobbyState.members.remove(idx)
      if (isMyUserId(m.userId)) {
        afterLeaveRoom()
        if (kicked) {
          if (!isInMenu()) {
            quit_to_debriefing()
            interrupt_multiplayer(true)
            in_flight_menu(false)
          }
          scene_msg_box("you_kicked_out_of_battle", null, loc("matching/msg_kicked"),
                          [["ok", function () {}]], "ok",
                          { saved = true })
        }
      }
      broadcastEvent("LobbyMembersChanged")
      break
    }
}

function LoadingStateChange(_) {
  if (handlersManager.isInLoading)
    return

  if (isInFlight())
    switchStatusChecked(
      [lobbyStates.IN_ROOM, lobbyStates.IN_LOBBY, lobbyStates.IN_LOBBY_HIDDEN,
       lobbyStates.JOINING_SESSION],
      lobbyStates.IN_SESSION
    )
  else
    switchStatusChecked(
      [lobbyStates.IN_SESSION, lobbyStates.JOINING_SESSION],
      lobbyStates.IN_DEBRIEFING
    )
}

addListenersWithoutEnv({
  SquadStatusChanged         = @(_) checkSquadAutoInviteToRoom()
  LoadingStateChange
  MatchingDisconnect         = @(_) leaveSessionRoom()
  function MatchingConnect(_) {
    leaveSessionRoom()
    checkReconnect()
  }
  UnitRepaired               = @(_) checkUpdateMatchingSlots()
  SlotbarUnitChanged         = @(_) checkUpdateMatchingSlots()
  MySessionLobbyInfoSynced   = @(_) checkUpdateMatchingSlots()
  RoomAttributesUpdated      = @(p) afterRoomUpdate(p)
  SessionRoomLeaved          = @(_) afterLeaveRoom()
  JoinedToSessionRoom        = @(p) afterRoomJoining(p)
}, DEFAULT_HANDLER)

function rpcJoinBattle(params) {
  if (!is_online_available())
    return "client not ready"
  let battleId = params.battleId
  if (type(battleId) != "string")
    return "bad battleId type"
  if (g_squad_manager.getSquadSize() > 1)
    return "player is in squad"
  if (isInSessionRoom.get())
    return "already in room"
  if (isInFlight())
    return "already in session"
  if (!showMsgboxIfEacInactive({ enableEAC = true }))
    return "EAC is not active"
  if (!showMsgboxIfSoundModsNotAllowed({ allowSoundMods = false }))
    return "sound mods not allowed"

  checkShowMultiplayerAasWarningMsg(function() {
    log($"join to battle with id {battleId}")
    joinBattle(battleId)
  })
  return "ok"
}

web_rpc.register_handler("join_battle", rpcJoinBattle)

matchingRpcSubscribe("match.notify_wait_for_session_join",
  @(_) setWaitForQueueRoom(true))
matchingRpcSubscribe("match.notify_join_session_aborted",
  @(_) leaveWaitForQueueRoom())

ecs.register_es("on_connected_to_server_es", {
  [EventOnConnectedToServer] = function() {
    if (MatchingRoomExtraParams == null)
      return
    let { routeEvaluationChance = 0.0, ddosSimulationChance = 0.0, ddosSimulationAddRtt = 0 } =  getRoomEvent()
    ecs.g_entity_mgr.broadcastEvent(MatchingRoomExtraParams({
        routeEvaluationChance = routeEvaluationChance,
        ddosSimulationChance = ddosSimulationChance,
        ddosSimulationAddRtt = ddosSimulationAddRtt,
    }));
  },
})

eventbus_subscribe("notify_session_start", function notify_session_start(...) {
  let sessionId = get_mp_session_id_str()
  if (sessionId != "")
    set_last_session_debug_info($"sid:{sessionId}")

  log("notify_session_start")
  sendBqEvent("CLIENT_BATTLE_2", "joining_session", {
    gm = get_game_mode()
    sessionId = sessionId
    missionsComplete = getMissionsComplete()
  })
  switchStatus(lobbyStates.JOINING_SESSION)
})

eventbus_subscribe("on_sign_out", function(...) {
  if (!isInSessionRoom.get())
    return
  leaveSessionRoom()
})

eventbus_subscribe("on_connection_failed", function on_connection_failed(evt) {
  let text = evt.reason
  if (!isInSessionRoom.get())
    return
  ::destroy_session_scripted("on_connection_failed")
  leaveSessionRoom()
  showInfoMsgBox(text, "on_connection_failed")
})

return {
  setMyTeamInRoom
  setSessionLobbyReady
  switchMyTeamInRoom
  setSessionLobbyCountryData
  switchSpectator
  setCustomPlayersInfo
  setExternalSessionId
  changeRoomPassword
  guiStartMpLobby
  setWaitForQueueRoom
  updateRoomAttributes
  continueCoopWithSquad
  goForwardSessionLobbyAfterDebriefing
  leaveSessionRoom
  tryJoinSession
  checkLeaveRoomInDebriefing
  onSettingsChanged
  onMemberInfoUpdate
  startSession
  onMemberJoin
  sessionLobbyHostCb
  joinSessionRoom
  checkReconnect
  joinBattle
  joinSessionLobbyFoundRoom
  startCoopBySquad
  createSessionLobbyRoom
  createSessionLobbyEventRoom
  onMemberLeave
}
