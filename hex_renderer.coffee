class HexSprite

  constructor: (@cell, texture, x, y, width, height) ->
    @sprite = new PIXI.Sprite(texture)
    @sprite.width = width
    @sprite.height = height
    @sprite.pivot.set(width / 2, height / 2)
    @sprite.position.set(x, y)
    @sprite.interactive = true
    @sprite.gridx = @cell.x
    @sprite.gridy = @cell.y

  update: (steps) ->
    #@sprite.rotation = @cell.angle * 1e-3
    @sprite.tint = @cell.color

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
    @currentWidth = @texture.width
    @currentHeight = @texture.height
    @hexSprites = {}

  resize: (@w, @h) ->
    @renderer.resize(@w, @h)
    @stage.position.set(@w / 2, @h / 2)

  animate: (millis=0) ->
    # draw, finally
    @renderer.render(@stage)

  #maps grid x/y to window x/y
  gridToWindow: (cellx, celly) ->
    x = @windowx + (cellx - @gridx) * @currentWidth
    y = @windowy + (celly - @gridy) * @currentHeight * 3 / 4
    if Math.abs(celly) % 2 == 1
      x += @currentWidth / 2
    return [x, y]

  hexSpriteClick: (x, y) ->
    #@core.sendAttack(@protocol, e.target.gridx, e.target.gridy)

  update: (steps, cells) ->
    for cell in cells
      #TODO: key doesn't work for grid size larger than 10
      key = "#{cell.x}#{cell.y}"
      if not (key of @hexSprites)
        if @firstSprite #and cell.owner != null and cell.owner.name == @playerName
          #map grid location to window location
          @gridx = cell.x
          @gridy = cell.y
          @firstSprite = false
        #add new cell to sprite list
        [x, y] = @gridToWindow(cell.x, cell.y)
        @hexSprites[key] = new HexSprite(cell, @texture, x, y, @currentWidth, @currentHeight)
        @hexSprites[key].sprite.click = (e) => @hexSpriteClick(e.target.gridx, e.target.gridy)
        @hexSprites[key].sprite.tap = (e) => @hexSpriteClick(e.target.gridx, e.target.gridy)
        @stage.addChild(@hexSprites[key].sprite)
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
        #update position of all existing hexs
        for key, hexSprite of @hexSprites
          hexSprite.sprite.position.x += difx
          hexSprite.sprite.position.y += dify
      @lastDragx = x
      @lastDragy = y
      
  onMouseUp: () ->
    @mouseDown = @dragging = false
    @lastDragx = @lastDragy = -1
    
  onMouseWheel: (delta) ->
    #delta = Math.abs(e.originalEvent.wheelDelta) / e.originalEvent.wheelDelta
    if (delta < 0 and @currentWidth < @texture.width / 2) or (delta > 0 and @currentWidth > @texture.width * 2)
      return
    #update currentWidth so we know how big and where to draw new hexs
    @currentWidth += delta * 10
    @currentHeight += delta * 11
    for key, hexSprite of @hexSprites
      hexSprite.sprite.width = @currentWidth
      hexSprite.sprite.height = @currentHeight
      hexSprite.sprite.pivot.set(@currentWidth / 2, @currentHeight / 2)
      [x,y] = @gridToWindow(hexSprite.sprite.gridx, hexSprite.sprite.gridy)
      hexSprite.sprite.position.set(x,y)

# public interface
(window ? {}).HexRenderer = exports.HexRenderer = HexRenderer
