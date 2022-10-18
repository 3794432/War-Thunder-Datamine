from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let time = require("%scripts/time.nut")
let { get_time_msec } = require("dagor.time")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")


::queue_classes.Base <- class
{
  id = 0
  name = ""
  typeBit = QUEUE_TYPE_BIT.UNKNOWN //FIX ME: should to rename this also
  queueType = ::g_queue_type.UNKNOWN
  state = queueStates.NOT_IN_QUEUE

  params = null //params = { clusters = array of strings, mode = string, country = string, team = int}
                //params.members = { [uid] = { country, slots } }
  activateTime = -1
  queueUidsList = null // { <queueUid> = <getQueueData> }
  queueStats = null //created on first stats income. We dont know stats version before
  selfActivated = false

  constructor(queueId, v_queueType, v_params)
  {
    id = queueId
    queueType = v_queueType
    params = v_params || {}

    typeBit = queueType.bit
    queueUidsList = {}
    selfActivated = getTblValue("queueSelfActivated", params, false)

    init()
    addQueueByParams(params)
  }

  function init() {}

  // return <is somethind in queue parameters changed>
  function addQueueByParams(_qParams)
  {
    return false
  }

  //return true if queue changed
  function removeQueueByParams(_leaveData)
  {
    return false
  }

  function addQueueByUid(queueUid, queueParms)
  {
    if (queueUid != null)
      queueUidsList[queueUid] <- queueParms
  }

  function removeQueueByUid(queueUid)
  {
    delete queueUidsList[queueUid]
  }

  function clearAllQueues()
  {
    queueUidsList.clear()
  }

  function isActive()
  {
    return queueUidsList.len() > 0
  }

  function getQueueData(_qParams)
  {
    return {}
  }

  function getTeamCode()
  {
    return getTblValue("team", params, Team.Any)
  }

  function getBattleName()
  {
    return ""
  }

  getDescription = @() "".concat( colorize("activeTextColor", getBattleName()), "\n",
    loc("options/country"), loc("ui/colon"), loc(params?.country ?? ""))

  function getActiveTime()
  {
    if (activateTime >= 0)
      return time.millisecondsToSeconds(get_time_msec() - activateTime)

    return 0
  }

  function join(_successCallback, _errorCallback) {}
  function leave(_successCallback, _errorCallback, _needShowError = false) {}
  static function leaveAll(_successCallback, _errorCallback, _needShowError = false) {}

  function hasCustomMode() { return false }
  //is already exist queue with custom mode.
  //custom mode can be switched off, but squad leader can set to queue with custom mode.
  function isCustomModeQUeued() { return false }
  //when custom mode switched on, it will be queued automatically
  function isCustomModeSwitchedOn() { return false }
  function switchCustomMode(_shouldQueue) {}
  static function isAllowedToSwitchCustomMode()
    { return !::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader() }
  hasActualQueueData = @() true
  actualizeData = @() null
}