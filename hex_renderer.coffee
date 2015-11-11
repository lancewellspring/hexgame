class HexSprite

  constructor: (@cell, texture, x, y, stage) ->
    @sprite = new PIXI.Sprite(texture)
    @sprite.pivot.set(@sprite.width / 2, @sprite.height / 2)
    @sprite.position.set(x, y)
    @sprite.interactive = true
    @sprite.gridx = @cell.x
    @sprite.gridy = @cell.y
    @sprite.overTint = 0x000000
    stage.addChild(@sprite)

    @unitText = new PIXI.Text('', {fill:0xffffff})
    @unitText.width = @unitText.width / 1.5
    @unitText.height = @unitText.height / 1.5
    @centerUnitText(x, y)
    stage.addChild(@unitText)
    @unitTextWidth = @unitText.width

  centerUnitText: (x, y) ->
    @unitText.position.x = x - @unitText.width / 2
    @unitText.position.y = y - @unitText.height / 2

  update: (steps) ->
    @sprite.tint = @cell.color | @sprite.overTint
    if @cell.owner?
      @unitText.text = @cell.units
      if @unitText.width > @unitTextWidth
        @centerUnitText(@sprite.position.x, @sprite.position.y)
        @unitTextWidth = @unitText.width

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

  #maps grid x/y to window x/y
  gridToWindow: (cellx, celly) ->
    x = (cellx - @centerHex.x) * @texture.width
    y = (celly - @centerHex.y) * @texture.height * 3 / 4
    if Math.abs(celly) % 2 == 1
      x += @texture.width / 2
    return [x, y]

  removeHex: (hex) ->
    key = "#{hex.x}|#{hex.y}"
    if key of @hexSprites
      @innerStage.removeChild(@hexSprites[key].sprite)
      @innerStage.removeChild(@hexSprites[key].unitText)
      delete @hexSprites[key]

  update: (steps, cells) ->
    for cell in cells
      key = "#{cell.x}|#{cell.y}"
      if not (key of @hexSprites)
        if not @centerHex?
          # center the player's view on the spawn location (first hex)
          @centerHex = { x: cell.x, y: cell.y }
        #add new cell to sprite list
        [x, y] = @gridToWindow(cell.x, cell.y)
        @hexSprites[key] = new HexSprite(cell, @texture, x, y, @innerStage)
        @hexSprites[key].sprite.click = (e) => @hexSpriteClick(e.target.gridx, e.target.gridy)
        @hexSprites[key].sprite.tap = (e) => @hexSpriteClick(e.target.gridx, e.target.gridy)
        @hexSprites[key].sprite.mouseover = (e) -> e.target.overTint = 0x343434
        @hexSprites[key].sprite.mouseout = (e) -> e.target.overTint = 0
      @hexSprites[key].update(steps)

  onMouseDown: () ->
    @mouseDown = true

  onMouseMove: (x, y) ->
    if @mouseDown
      @dragging = true
      if @lastDrag?
        #update grid to window mapping, so we know where to draw new hexs
        @innerStage.position.x += (x - @lastDrag.x) / @outerStage.scale.x
        @innerStage.position.y += (y - @lastDrag.y) / @outerStage.scale.y
        @lastDrag.x = x
        @lastDrag.y = y
      else
        @lastDrag = { x: x, y: y }

  onMouseUp: () ->
    @mouseDown = @dragging = false
    @lastDrag = null

  onMouseWheel: (delta) ->
    ds = delta * .1
    if 0.5 < @outerStage.scale.x + ds < 2 and 0.5 < @outerStage.scale.y + ds < 2
      @outerStage.scale.x += ds
      @outerStage.scale.y += ds

  autoScroll: () ->
    # TODO: fit visible hex to screen
    #bounds = @outerStage.getBounds()


# public interface
(window ? {}).HexRenderer = exports.HexRenderer = HexRenderer
