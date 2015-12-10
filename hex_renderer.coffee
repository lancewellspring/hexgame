class Animation

  #path should be a list of objects, with the points along the path and how long it takes to get to each of them.  The starting point should be at the end of path list.
  constructor: (@displayObject, @path, @doneCallback) ->
    @calcNext()
    @done = false
    @stepCount = 0

  calcNext: () ->
    if @path.length > 0
      @slope = {x:@path[0].x - @displayObject.x, y:@path[0].y - @displayObject.y}
    else
      @done = true
      if @doneCallback?
        @doneCallback()

  update: (steps) ->
    if not @done
      @stepCount += steps
      if @stepCount > @path[0].steps
        @displayObject.position.x = @path[0].x
        @displayObject.position.y = @path[0].y
        steps = @stepCount - @path[0].steps
        @stepCount -= @path[0].steps
        @path.splice(0, 1)
        @calcNext()
      if @path.length > 0
        stepRatio = steps / @path[0].steps
        xdist = stepRatio * @slope.x
        ydist = stepRatio * @slope.y
        @displayObject.position.x += xdist
        @displayObject.position.y += ydist

class UnitSlider
  constructor: (@parent) ->
    graphics = new PIXI.Graphics()
    graphics.lineStyle(2, 0xffffff, 1)
    graphics.drawCircle(0, 0, @parent.width / 4)
    texture = graphics.generateTexture()

    @sprite = new PIXI.Sprite(texture)
    @sprite.position.set(@parent.width / 2 - @sprite.width / 2, @parent.height / 2 - @sprite.height / 2)
    @sprite.interactive = false
    @sprite.tint = @parent.tint
    @sprite.scale.set(.1, .1)
    @parent.addChild(@sprite)

    @done = false

  setSize: (size) ->
    @sprite.width = size
    @sprite.height = size
    @sprite.position.x = @parent.width / 2 - @sprite.width / 2
    @sprite.position.y = @parent.height / 2 - @sprite.height / 2

  destroy: () ->
    @parent.removeChild(@sprite)
    @sprite.destroy()

class HexSprite

  constructor: (@cell, texture, x, y, stage, @selectHexCallback, @unitsSelectCallback, @unitsCancelCallback) ->
    @key = @cell.key
    @selectPos = null
    @unitSlider = null
    @unitsSelected = 0
    @selected = false

    @sprite = new PIXI.Sprite(texture)
    @sprite.pivot.set(@sprite.width / 2, @sprite.height / 2)
    @sprite.position.set(x, y)
    @sprite.interactive = true
    # @sprite.click = @sprite.tap = (e) =>
      # @selectHexCallback(this)
    @sprite.mousedown = @sprite.touchstart = (e) =>
      if @unitsSelected > 0
        @unitsCancelCallback(this)
      @unitsSelected = 0
      @selectHexCallback(this)
      @selectPos = e.data.getLocalPosition(@sprite)
    @sprite.mousemove = @sprite.touchmove = (e) =>
      if @selectPos? and @selected
        if @unitSlider == null
          @unitSlider = new UnitSlider(@sprite)
        newPos = e.data.getLocalPosition(@sprite)
        dif = Math.sqrt(Math.pow(newPos.x - @selectPos.x, 2) + Math.pow(newPos.y - @selectPos.y, 2)) * 2
        dif = Math.min(dif, @sprite.width * .5)
        @unitSlider.setSize(dif)
        @unitText.text = Math.round(dif / (@sprite.width * .5) * @cell.units)
    @sprite.mouseup = @sprite.touchend = @sprite.mouseupoutside = @sprite.touchendoutside = (e) =>
      if @selectPos?
        if @unitSlider == null
          @unitsSelected = Math.floor(@cell.units / 2)
        else
          @unitsSelected = parseInt(@unitText.text)
        if @unitsSelected > 0
          console.log("sending " + @unitsSelected)
          @unitsSelectCallback(this, @unitsSelected)
          @unitsSelected = 0
        @selectPos = null
        @unitSlider?.destroy()
        @unitSlider = null
        @selected = false
    #mouse leaves hex before mouseup
    # @sprite.mouseout = (e) =>
      # if @unitsSelected == 0
        # @selectPos = null
        # @unitSlider?.destroy()
        # @unitSlider = null
        # @selected = false

    stage.addChild(@sprite)

    @unitText = new PIXI.Text('', {fill:0xffffff})
    @unitText.width = @unitText.width / 1.5
    @unitText.height = @unitText.height / 1.5
    @centerUnitText(x, y)
    @sprite.addChild(@unitText)

  select: () ->
    @selected = true

  centerUnitText: () ->
    @unitText.position.x = @sprite.width / 2 - @unitText.width / 2
    @unitText.position.y = @sprite.height/ 2 - @unitText.height / 2
    @unitTextWidth = @unitText.width

  update: (steps) ->
    @sprite.tint = @cell.color
    if @cell.owner?
      if @unitSlider == null
        @unitText.text = @cell.units
      if @unitText.width != @unitTextWidth
        @centerUnitText(@sprite.position.x, @sprite.position.y)
    else
      @unitText.text = ''

  destroy: () ->
    @sprite.destroy()
    @unitText.destroy()

class UnitSprite

  #A circle that represents a group of units as its travelling between hexs.
  constructor: (@stage, player, hexs, units, duration) ->
    graphics = new PIXI.Graphics()
    graphics.lineStyle(2, 0xffffff, 1)
    graphics.beginFill(0x404040)
    graphics.drawCircle(0, 0, Math.sqrt(units)*2)
    graphics.endFill()
    texture = graphics.generateTexture()

    @sprite = new PIXI.Sprite(texture)
    @sprite.position.set(hexs[0].sprite.position.x - @sprite.width / 2, hexs[0].sprite.position.y - @sprite.height / 2)
    hexs.splice(0,1)
    @sprite.interactive = false
    @sprite.tint = player.color
    @stage.addChild(@sprite)

    path = []
    steps = duration / hexs.length
    for h in hexs
      #TODO: figure out how in the world there are undefined hexs here.
      if h?
        path.push({x:h.sprite.position.x - @sprite.width / 2, y:h.sprite.position.y - @sprite.height / 2, steps:steps})
    @animation = new Animation(@sprite, path, @destroy)

  update: (steps) ->

  destroy: () =>
    @stage.removeChild(@sprite)
    @sprite.destroy()

class HexRenderer

  _hexCoords = (i, size) -> [
    Math.sin(Math.PI / 3 * i) * size,
    Math.cos(Math.PI / 3 * i) * size,
  ]

  constructor: (canvas) ->
    @mouseDown = @dragging = false
    [@w, @h] = [canvas.width, canvas.height]
    options =
      view: canvas
      antialias: true
      interactive: true
      backgroundColor: 0x000000
    @renderer = new PIXI.autoDetectRenderer(@w, @h, options)

    ###
    There are two main stages: outer and inner. The outer stage is permanently
    positioned with (0, 0) at the center of the visible screen, and the inner
    stage is relatively positioned by player panning. On the other hand, the
    inner stage is permanently set to a zoom level of 1, and the outer stage is
    relatively zoomed by player pinching/scrolling. This is because we always
    want to zoom at the center of the screen, not at the spawn hex. (More
    technically, we first need to *translate* to the middle of the screen, then
    *scale* at that point, then *translate* again to the player's location; and
    that set of operations can't be (easily) achieved in a single container.)
    The inner stage should contain all game elements (i.e. hex cells).
    ###
    @outerStage = new PIXI.Container()
    @innerStage = new PIXI.Container()
    @outerStage.addChild(@innerStage)

    graphics = new PIXI.Graphics()
    graphics.lineStyle(4, 0xffffff, 1)
    graphics.beginFill(0x404040)
    for i in [0..6]
      [x, y] = _hexCoords(i, 32)
      if i == 0
        graphics.moveTo(x, y)
      else
        graphics.lineTo(x, y)
    graphics.endFill()
    @texture = graphics.generateTexture()
    @hexSprites = {}
    @animations = []

  resize: (@w, @h) ->
    @renderer.resize(@w, @h)
    @outerStage.position.set(@w / 2, @h / 2)

  animate: (millis=0) ->
    # draw, finally
    @renderer.render(@outerStage)
    if @onScreenshot?
      # take a screenshot - must be done immediately after the PIXI render
      @onScreenshot(@renderer.view.toDataURL())
      @onScreenshot = null

  takeScreenshot: (callback) ->
    @onScreenshot = callback

  startUnitAnimation: (player, hexs, units, duration) ->
    hexSprites = []
    for h in hexs
      hexSprites.push(@hexSprites[h.key])
    unitSprite = new UnitSprite(@innerStage, player, hexSprites, units, duration)
    @animations.push(unitSprite.animation)

  #maps grid x/y to window x/y
  gridToWindow: (cellx, celly) ->
    x = (cellx - @centerHex.x) * @texture.width
    y = (celly - @centerHex.y) * @texture.height * 3 / 4
    if Math.abs(celly) % 2 == 1
      x += @texture.width / 2
    return [x, y]

  removeHex: (hex) ->
    if hex.key of @hexSprites
      @hexSprites[hex.key].destroy()
      @innerStage.removeChild(@hexSprites[hex.key].sprite)
      @innerStage.removeChild(@hexSprites[hex.key].unitText)
      delete @hexSprites[hex.key]

  update: (steps, cells) ->
    for cell in cells
      if not (cell.key of @hexSprites)
        if not @centerHex?
          # center the player's view on the spawn location (first hex)
          @centerHex = { x: cell.x, y: cell.y }
        #add new cell to sprite list
        [x, y] = @gridToWindow(cell.x, cell.y)
        @hexSprites[cell.key] = new HexSprite(cell, @texture, x, y, @innerStage, @selectHexCallback, @unitsSelectCallback, @unitsCancelCallback)
      @hexSprites[cell.key].update(steps)
    i = 0
    while i < @animations.length
      if @animations[i].done
        @animations.splice(i, 1)
      else
        @animations[i].update(steps)
        i++

  onMouseDown: () ->
    @mouseDown = true

  onMouseMove: (x, y) ->

  onMouseUp: (x, y) ->
    @mouseDown = @dragging = false
    @lastDrag = null

  onMouseWheel: (delta) ->
    ds = delta * .1
    if 0.5 < @outerStage.scale.x + ds < 2 and 0.5 < @outerStage.scale.y + ds < 2
      @outerStage.scale.x += ds
      @outerStage.scale.y += ds

  autoPan: (x, y) ->
    # x = @innerStage.x - x
    # y = @innerStage.y - y
    dist = Math.sqrt(Math.pow(@innerStage.x-x,2) + Math.pow(@innerStage.y-y,2))
    @animations.push(new Animation(@innerStage, [{x:-x, y:-y, steps:dist}]))


# public interface
(window ? {}).HexRenderer = exports.HexRenderer = HexRenderer
