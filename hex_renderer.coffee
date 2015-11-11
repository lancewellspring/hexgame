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
    @lastDragx = @lastDragy = -1
    [@w, @h] = [canvas.width, canvas.height]
    #variables used to map grid x/y to window x/y
    @gridx = @gridy = 0
    @windowx = 0
    @windowy = 0
    options =
      view: canvas
      antialias: true
      interactive: true
      backgroundColor: 0x000000
    @renderer = new PIXI.autoDetectRenderer(@w, @h, options)
    @stage = new PIXI.Container()

    @firstSprite = true

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
    @stage.position.set(@w / 2, @h / 2)

  animate: (millis=0) ->
    # draw, finally
    @renderer.render(@stage)
    if @onScreenshot?
      # take a screenshot - must be done immediately after the PIXI render
      @onScreenshot(@renderer.view.toDataURL())
      @onScreenshot = null

  takeScreenshot: (callback) ->
    @onScreenshot = callback

  #maps grid x/y to window x/y
  gridToWindow: (cellx, celly) ->
    x = @windowx + (cellx - @gridx) * @texture.width
    y = @windowy + (celly - @gridy) * @texture.height * 3 / 4
    if Math.abs(celly) % 2 == 1
      x += @texture.width / 2
    return [x, y]

  hexSpriteClick: (x, y) ->
    #@core.sendAttack(@protocol, e.target.gridx, e.target.gridy)

  removeHex: (hex) ->
    key = "#{hex.x}|#{hex.y}"
    if key of @hexSprites
      @stage.removeChild(@hexSprites[key].sprite)
      @stage.removeChild(@hexSprites[key].unitText)
      delete @hexSprites[key]

  update: (steps, cells) ->
    for cell in cells
      key = "#{cell.x}|#{cell.y}"
      if not (key of @hexSprites)
        if @firstSprite #and cell.owner != null and cell.owner.name == @playerName
          #map grid location to window location
          @gridx = cell.x
          @gridy = cell.y
          @firstSprite = false
        #add new cell to sprite list
        [x, y] = @gridToWindow(cell.x, cell.y)
        @hexSprites[key] = new HexSprite(cell, @texture, x, y, @stage)
        @hexSprites[key].sprite.click = (e) => @hexSpriteClick(e.target.gridx, e.target.gridy)
        @hexSprites[key].sprite.tap = (e) => @hexSpriteClick(e.target.gridx, e.target.gridy)
        @hexSprites[key].sprite.mouseover = (e) => e.target.overTint = 0x343434
        @hexSprites[key].sprite.mouseout = (e) => e.target.overTint = 0
      @hexSprites[key].update(steps)

  onMouseDown: () ->
    @mouseDown = true

  onMouseMove: (x, y) ->
    if @mouseDown
      @dragging = true;
      difx = (x - @lastDragx) / 1.2
      dify = (y- @lastDragy) / 1.2
      if @lastDragx >= 0
        #update grid to window mapping, so we know where to draw new hexs
        @windowx += difx
        @windowy += dify
        @stage.position.x += difx
        @stage.position.y += dify
      @lastDragx = x
      @lastDragy = y

  onMouseUp: () ->
    @mouseDown = @dragging = false
    @lastDragx = @lastDragy = -1

  onMouseWheel: (delta) ->
    if @stage.scale.x + delta * .1 < .5 or @stage.scale.y + delta * .1 > 2
      return
    @stage.scale.x += delta * .1 
    @stage.scale.y += delta * .1 

  autoScroll: () ->
    # fit visible hex to screen
    bounds = @stage.getBounds()


# public interface
(window ? {}).HexRenderer = exports.HexRenderer = HexRenderer
