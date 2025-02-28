from "%rGui/globals/ui_library.nut" import *

let { createScriptComponentWithPos } = require("%rGui/utils/builders.nut")
let { CustomPages } = require("%rGui/planeState/planeToolsState.nut")
let ah64Flt = require("ah64FltPage.nut")
let ah64Wpn = require("ah64WpnPage.nut")
let {f15cWpn, f15jWpn} = require("f15cWpnPage.nut")
let su27Pod = require("mfdSu27Pod.nut")
let ef2000Wpn = require("ef2000WpnPage.nut")
let rafaleWpn = createScriptComponentWithPos("%rGui/planeCockpit/mfdRafaleWpn.das", {
  fontId = Fonts.hud
})


function su30Devices(pos, size) {
  return {
    rendObj = ROBJ_DAS_CANVAS
    pos
    size
    script = load_das("%rGui/planeCockpit/mfdSu30devices.das")
    drawFunc = "draw"
    setupFunc = "setup"
    altDevImage = Picture($"!ui/gameuiskin#mfd_altitude.avif")
    spdDevImage = Picture($"!ui/gameuiskin#mfd_speed.avif")
    varioDevImage = Picture($"!ui/gameuiskin#mfd_vario.avif")
    horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask.avif")
  }
}

function yellow(pos, size) {
  return {
    rendObj = ROBJ_SOLID
    pos = pos
    size = size
    color = Color(255, 255, 0)
  }
}

function red(pos, size) {
  return {
    rendObj = ROBJ_SOLID
    pos = pos
    size = size
    color = Color(255, 0, 0)
  }
}

function blue(pos, size) {
  return {
    rendObj = ROBJ_SOLID
    pos = pos
    size = size
    color = Color(0, 0, 255)
  }
}

let pageByName = {
  yellow,
  red,
  blue,
  ah64Flt,
  ah64Wpn,
  f15cWpn,
  su27Pod,
  f15jWpn,
  ef2000Wpn,
  rafaleWpn,
  su30Devices
}

function mfdCustomPages() {
  let pages = []

  foreach (name, pos in CustomPages.value) {
    if (name != null)
      pages.append(pageByName?[name]?([pos.x, pos.y], [pos.z, pos.w]))
  }
  return {
    watch = CustomPages
    size = flex()
    children = pages
  }
}

return mfdCustomPages