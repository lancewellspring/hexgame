class HexSprite

  constructor: (@cell, texture, x, y, width, height) ->
    @sprite = new PIXI.Sprite(texture)
    @sprite.width = width
    @sprite.height = height
    @sprite.pivot.set(@sprite.width / 2, @sprite.height / 2)
    @sprite.position.set(x, y)
    @sprite.interactive = true
    @sprite.gridx = @cell.x
    @sprite.gridy = @cell.y
    # @sprite.click = @sprite.tap = (e) =>
      # #color = Math.floor(Math.random() * (1 << 24)) | 0x282828
      # #@protocol.move(HexCore.setColor(@cell.index, color))
      # #@protocol.move(HexCore.setSpeed(@cell.index, @cell.speed * -1))
      # @click(e)

  update: (steps) ->
    #@sprite.rotation = @cell.angle * 1e-3
    @sprite.tint = @cell.color

class HexRenderer

  _hexCoords = (i, size) -> [
    Math.sin(Math.PI / 3 * i) * size,
    Math.cos(Math.PI / 3 * i) * size,
  ]

  constructor: (@core, @protocol, @playerName, canvas) ->
    @mouseDown = @dragging = false
    @lastDragx = @lastDragy = -1
    [@w, @h] = [canvas.width, canvas.height]
    #variables used to map grid x/y to window x/y
    @gridx = @gridy = 0
    @windowx = @w/2
    @windowy = @h/2
    options =
      view: canvas
      antialias: true
      interactive: true
      backgroundColor: 0x000000
    @renderer = new PIXI.autoDetectRenderer(@w, @h, options)
    @stage = new PIXI.Container()

    @protocol.start(@playerName)
    #@core.players[@playerName] = new Player(@playerName, @protocol)
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
    # @cells = []
    # [xs, ys] = [[-1, 0, +1], [+1, -1, +1]]
    # for [c, x, y] in _.zip(@core.cells, xs, ys)
      # cell = new HexSprite(c, @protocol, texture, x * 64, y * 55)
      # @cells.push(cell)
      # @stage.addChild(cell.sprite)

  resize: (@w, @h) ->
    @renderer.resize(@w, @h)
    @stage.position.set(@w / 2, @h / 2)

  animate: (millis=0) ->
    # request the next frame
    requestAnimationFrame((x) => @animate(x))
    # calculate elapsed time since last frame
    steps = Math.round(millis - (@last_millis ? millis))
    # TODO - huge hacks here. run at 15/16th speed to prevent getting ahead of the server (which would cause the client to lag until the server catches up)
    steps -= 1
    @last_millis = millis
    # update game and animations
    if steps > 0
      @core.update(steps)
      @update(steps)
    # draw, finally
    @renderer.render(@stage)

  #maps grid x/y to window x/y
  gridToWindow: (cellx, celly) ->
    x = @windowx + (cellx - @gridx) * @currentWidth
    y = @windowy + (celly - @gridy) * @currentHeight * 3 / 4
    if Math.abs(celly) % 2 == 1
      x += @currentWidth / 2
    return [x, y]
    
  #TODO: incomplete, not sure if needed
  windowToGrid: (winx, winy) ->
    x = (winx - @windowx) / @texture.width
    y = (winy - @windowy) / @texture.height * 4 / 3

  hexSpriteClick: (e) ->
    @protocol.attack([@playerName, e.target.gridx, e.target.gridy])

  update: (steps) ->
    #TODO: I'm not a fan of the way renderer gets cells from core, need to think about doing it differently (a way that would also work for core notifying renderer when to hide cells as well)
    #loop through cores cells instead, and add any new ones to sprite list
    for cell in @core.cells
      key = "#{cell.x}#{cell.y}"
      if not (key of @hexSprites)
        if @firstSprite and cell.owner != null and cell.owner.name == @playerName
          #map grid location to window location
          #TODO: this should be placing the first hex in the middle of the screen, but its not working
          @gridx = cell.x
          @gridy = cell.y
          console.log("x y: " + @gridx + " " + @gridy)
          firstSprite = false
        #add new cell to sprite list
        [x, y] = @gridToWindow(cell.x, cell.y)
        @hexSprites[key] = new HexSprite(cell, @texture, x, y, @currentWidth, @currentHeight)
        @hexSprites[key].sprite.click = (e) => @hexSpriteClick(e)
        @stage.addChild(@hexSprites[key].sprite)
      @hexSprites[key].update(steps)
      
  onMouseDown: (e) ->
    @mouseDown = true
    
  onMouseMove: (e) ->
    if @mouseDown
      @dragging = true;
      difx = (e.clientX - @lastDragx) / 1.2
      dify = (e.clientY - @lastDragy) / 1.2
      if @lastDragx >= 0 
        #update grid to window mapping, so we know where to draw new hexs
        @windowx += difx
        @windowy += dify
        #update position of all existing hexs
        for key, hexSprite of @hexSprites
          hexSprite.sprite.position.x += difx
          hexSprite.sprite.position.y += dify
      @lastDragx = e.clientX
      @lastDragy = e.clientY
      
  onMouseUp: (e) ->
    @mouseDown = @dragging = false
    @lastDragx = @lastDragy = -1
    
  onMouseWheel: (e) ->
    delta = Math.abs(e.originalEvent.wheelDelta) / e.originalEvent.wheelDelta
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
(exports ? window).HexRenderer = HexRenderer
