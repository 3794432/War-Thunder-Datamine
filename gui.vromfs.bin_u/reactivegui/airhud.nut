local radarComponent = require("radarComponent.nut")
local tws = require("tws.nut")
local opticAtgmSight = require("opticAtgmSight.nut")
local {OpticAtgmSightVisible, AtgmTrackerVisible, IsLaserDesignatorEnabled, LaserPoint, IsWeaponHudVisible} = require("planeState.nut")
local {IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated, CollapsedIcon} = require("twsState.nut")
local {hudFontHgt, greenColor, fontOutlineColor, fontOutlineFxFactor} = require("style/airHudStyle.nut")
local {safeAreaSizeHud, bw, bh, rw, rh} = require("style/screenState.nut")
local aamAim = require("rocketAamAim.nut")
local agmAim = require("agmAim.nut")


local style = {
  color = greenColor
  lineForeground = {
    color = greenColor
    fillColor = greenColor
    lineWidth = max(hdpx(1) * LINE_WIDTH, 1.4)
    font = Fonts.hud
    fontFxColor = fontOutlineColor
    fontFxFactor = fontOutlineFxFactor
    fontFx = FFT_GLOW
    fontSize = hudFontHgt
  }
}

local rwrPic = Picture("!ui/gameuiskin#rwr_stby_icon")
local function mkTws (colorStyle) {
  local twsPosX = IsTwsActivated.value ? bw() + rw(1) : bw() + rw(74)
  local twsPosY = IsTwsActivated.value ? bh() + rh(37) : bh() + rh(3)
  local twsSize = IsTwsActivated.value ? sh(20) : sh(5)
  if (IsTwsActivated.value || !CollapsedIcon.value){
    return @() {
    children = (!IsMlwsLwsHudVisible.value && !IsRwrHudVisible.value) ? null :
      tws({
          colorStyle = colorStyle,
          pos = [twsPosX, twsPosY],
          size = [twsSize, twsSize],
          relativCircleSize = 43
        })
    }
  }
  else if (IsMlwsLwsHudVisible.value || IsRwrHudVisible.value){
    return @() style.__merge({
      pos = [twsPosX, twsPosY]
      size = [twsSize, twsSize]
      rendObj = ROBJ_IMAGE
      image = rwrPic
      color = style.color
    })
  }
  else
    return null
}

local radarPic = Picture("!ui/gameuiskin#radar_stby_icon")
local function mkRadar() {
  local radarVisible = radarComponent.state.IsRadarVisible.value || radarComponent.state.IsRadar2Visible.value
  local radarSize = radarVisible ? sh(28) : sh(5)
  local radarPosX = radarVisible ? bw() + rw(99) - radarSize: bw() + rw(74)
  local radarPosY = radarVisible ? bh() + rh(43) : bh() + rh(30)
  if (radarVisible || !CollapsedIcon.value){
    return {
      children = radarComponent.mkRadar(radarPosX, radarPosY, radarSize, true)
    }
  }
  else if (radarComponent.state.IsRadarHudVisible.value){
    return style.__merge({
      pos = [radarPosX, radarPosY]
      size = [radarSize, radarSize]
      rendObj = ROBJ_IMAGE
      image = radarPic
      color = style.color
    })
  }
  else
    return null
}

local agmAimIndicator = @() {
  watch = AtgmTrackerVisible
  size = flex()
  children = AtgmTrackerVisible.value ? [agmAim(style, @() style.color)] : []
}

local laserPoint = {
  size = [ph(1), ph(1)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = style.color
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 100, 100]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [LaserPoint[0], LaserPoint[1]]
    }
  }
}

local laserPointComponent = @() {
  watch = IsLaserDesignatorEnabled
  size = flex()
  children = IsLaserDesignatorEnabled.value ? laserPoint : null
}

local function weaponHud() {
  return @(){
    watch = IsWeaponHudVisible
    children = IsWeaponHudVisible.value
    ? [
      aamAim(style, @() greenColor)
      agmAim(style, @() greenColor)
    ]
    : null
  }
}

local function Root() {
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    watch = [IsMlwsLwsHudVisible, IsRwrHudVisible, IsTwsActivated,
      radarComponent.state.IsRadarVisible, radarComponent.state.IsRadar2Visible,
      radarComponent.state.IsRadarHudVisible, OpticAtgmSightVisible, safeAreaSizeHud]
    children = [
      mkRadar()
      mkTws(style)
      OpticAtgmSightVisible.value ? opticAtgmSight(sw(100), sh(100)) : null
      agmAimIndicator
      laserPointComponent
      weaponHud()
    ]
  }
}


return Root
