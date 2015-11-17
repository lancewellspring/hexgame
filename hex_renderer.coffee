class Animation

  #path should be a list of objects, with the points along the path and how long it takes to get to each of them
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
        @path.pop()
        @calcNext()
      if @path.length > 0
        stepRatio = steps / @path[0].steps
        xdist = stepRatio * @slope.x
        ydist = stepRatio * @slope.y
        @displayObject.position.x += xdist
        @displayObject.position.y += ydist

#TODO: currently unused, need to add logic to hex_server to kick off moving a unit sprite by passing an action to core via _sync.
class UnitSprite
  #A circle that represents a group of units as its travelling between hexs.
  #TODO: going to need decide what to do when endHex is conquered before the units reach it.
  constructor: (@cell, @startHex, @endHex, duration, stage) ->
    graphics = new PIXI.Graphics()
    graphics.lineStyle(4, 0xffffff, 1)
    graphics.beginFill(0x404040)
    graphics.drawCircle(0, 0, Math.sqrt(@cell.units))
    graphics.endFill()
    texture = graphics.generateTexture()
    
    @sprite = new PIXI.Sprite(texture)
    @sprite.position.set() #TODO: needs to start at a vertex of startHex
    @sprite.interactive = false
    @sprite.tint = @startHex.sprite.tint
    stage.addChild(@sprite)
    
    points = @calculatePath()
    path = []
    steps = duration / points.length
    for p in point
      path.push([p, steps])
    @animation = new Animation(@sprite, @path, @destroy)
    
  #calculate path from start to end, returning a list of points
  calculatePath: () ->
    #TODO: I think I'm gonna leave this to you David, as I'm pretty sure this can use your _hexCoords logic, and I don't care to figure it out right now.
    
  destroy: () ->
    @sprite.destroy()
    
class HexButton

  constructor: (texture, visible, interactive, position, parent) ->
    @sprite = new PIXI.Sprite(texture)
    @sprite.visible = visible
    @sprite.interactive = interactive
    @sprite.click = (e) => clickCallback(e)
    @sprite.tap = (e) => clickCallback(e)
    x = y = 0    
    if position == "mid"
      x = parent.width / 2 - @sprite.width / 2
      y = parent.height / 2 - @sprite.height / 2
    else if position == "left"
      x = @sprite.width / 2
      y = parent.height / 2 - @sprite.height / 2
    else if position == "right"
      x = parent.width / 2 + @sprite.width / 2
      y = parent.height / 2 - @sprite.height / 2
    else
      console.log("unexpected position in HexButton")
    @sprite.position.set(x, y)
    parent.addChild(@sprite)

class HexSprite

  @selectTexture = new PIXI.Texture.fromImage('expander.png')
  @deselectTexture = new PIXI.Texture.fromImage('cancel.png')
  @conquerTexture = new PIXI.Texture.fromImage('crossed-swords.png')
  @raidTexture = new PIXI.Texture.fromImage('arrow-cluster.png')
  @moveTexture = new PIXI.Texture.fromImage('back-forth.png')
  @supplyTexture = new PIXI.Texture.fromImage('profit.png')
  @sliderTexture = new PIXI.Texture.fromImage('vertical-flip.png')

  constructor: (@cell, texture, x, y, stage, highlight, select, cancel, raid, conquer, move, supply) ->
    @gridx = @cell.x
    @gridy = @cell.y
    @highlighted = false
    @selected = false
    
    @sprite = new PIXI.Sprite(texture)
    @sprite.pivot.set(@sprite.width / 2, @sprite.height / 2)
    @sprite.position.set(x, y)
    @sprite.interactive = true
    @sprite.mouseover = (e) => 
      highlight(this)
      @highlighted = true
    @sprite.mouseout = (e) => 
      if not @selected
        cancel(this)
      @mouseout(e)
    stage.addChild(@sprite)

    @unitText = new PIXI.Text('', {fill:0xffffff})
    @unitText.width = @unitText.width / 1.5
    @unitText.height = @unitText.height / 1.5
    @centerUnitText(x, y)
    @sprite.addChild(@unitText)
    
    @selectButton = new HexButton(HexSprite.selectTexture, false, true, "mid", @sprite)
    @selectButton.sprite.click = @selectButton.sprite.tap =(e) => select(this)
    
    @cancelButton = new HexButton(HexSprite.deselectTexture, false, true, "mid", @sprite)
    @cancelButton.sprite.click = @cancelButton.sprite.tap =(e) => cancel(this)
    
    @raidButton = new HexButton(HexSprite.raidTexture, false, true, "left", @sprite)
    @raidButton.sprite.click = @raidButton.sprite.tap = (e) => @setupSlider(@raidButton, raid, -2)
    
    @conquerButton = new HexButton(HexSprite.conquerTexture, false, true, "right", @sprite)
    @conquerButton.sprite.click = @conquerButton.sprite.tap = (e) => @setupSlider(@conquerButton, conquer, -1)
    
    @moveButton = new HexButton(HexSprite.moveTexture, false, true, "left", @sprite)
    @moveButton.sprite.click = @moveButton.sprite.tap = (e) => @setupSlider(@moveButton, move, -2)
    
    @supplyButton = new HexButton(HexSprite.supplyTexture, false, true, "right", @sprite)
    @supplyButton.sprite.click = @supplyButton.sprite.tap = (e) => @setupSlider(@supplyButton, supply, -1)
    
    #display humber of units
    @slideText = new PIXI.Text('', {fill:0xffffff})
    @slideText.scale.set(.75, .75)
    @slideText.visible = false
    @sprite.addChild(@slideText)
    
    #used for determining how many units to use for action
    @slider = new PIXI.Sprite(HexSprite.sliderTexture)
    @slider.visible = false
    @slider.interactive = true
    @slider.mouseup = (e) => 
      if @slider.value > 0
        @slider.action(this, @slider.value)
        @slider.visible = false
        @slideText.visible = false
    @slider.mousemove = (e) =>
      top = 0
      bottom = @slider.height
      localy = e.data.getLocalPosition(@slider).y
      #@sender is set in the showAllied/showEnemy functions
      @slider.value = Math.floor((bottom - localy) / (bottom - top) * @sender.units)
      @slider.value = Math.min(@slider.value, @sender.units)
      @slideText.text = @slider.value
    @sprite.addChild(@slider)
    
  setupSlider: (target, action, dif) ->
    @slider.action = action
    @slider.value = .5
    #positioning is a bit hacky =/
    @slider.position.set(target.sprite.position.x + dif * 8, target.sprite.position.y - 8)
    @slideText.position.set(target.sprite.position.x, target.sprite.position.y + @slider.width / 2 - @slideText.height / 2)
    target.sprite.visible = false
    @slider.visible = true
    @slideText.visible = true

  centerUnitText: () ->
    @unitText.position.x = @sprite.width / 2 - @unitText.width / 2
    @unitText.position.y = @unitText.height / 2
    @unitTextWidth = @unitText.width

  update: (steps) ->
    @sprite.tint = @cell.color
    if @cell.owner?
      @unitText.text = @cell.units
      if @unitText.width != @unitTextWidth
        @centerUnitText(@sprite.position.x, @sprite.position.y)
        
  select: () ->
    @selected = true
    @cancelButton.sprite.visible = true
    @selectButton.sprite.visible = false
    @moveButton.sprite.visible = false
    @supplyButton.sprite.visible = false
    @slider.visible = false
    @slideText.visible = false
        
  deselect: () ->
    @selected = false
    @raidButton.sprite.visible = false
    @conquerButton.sprite.visible = false
    @moveButton.sprite.visible = false
    @supplyButton.sprite.visible = false
    @cancelButton.sprite.visible = false
    @slider.visible = false
    @slideText.visible = false
    if @highlighed
      @selectButton.sprite.visible = true
    
  mouseout: (e) ->
    @selectButton.sprite.visible = false
    @raidButton.sprite.visible = false
    @conquerButton.sprite.visible = false
    @moveButton.sprite.visible = false
    @supplyButton.sprite.visible = false
    @slider.visible = false
    @slideText.visible = false
    @highlighted = false
      
  cancelAction: () ->
    #hide ui for current action
    
  showSelect: () ->
    if not @selected
      @selectButton.sprite.visible = true
    
  showEnemy: (@sender) ->
    if @cell.owner?
      @raidButton.sprite.visible = true
      @conquerButton.sprite.visible = true
    else
      @conquerButton.sprite.visible = true
    
  showAllied: (@sender) ->
    @moveButton.sprite.visible = true
    @supplyButton.sprite.visible = true
    @selectButton.sprite.visible = true
    
  destroy: () ->
    @sprite.destroy()
    @unitText.destroy()
    @selectButton.sprite.destroy()
    @cancelButton.sprite.destroy()
    @raidButton.sprite.destroy()
    @conquerButton.sprite.destroy()
    @moveButton.sprite.destroy()
    @supplyButton.sprite.destroy()
    @slider.destroy()
    @slideText.destroy()

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
      @hexSprites[key].destroy()
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
        @hexSprites[key] = new HexSprite(cell, @texture, x, y, @innerStage,@highlightCallback, @selectCallback, @cancelCallback, @raidCallback, @conquerCallback, @moveCallback, @supplyCallback)
      @hexSprites[key].update(steps)
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
    # if @mouseDown
      # @dragging = true
      # if @lastDrag?
        ##update grid to window mapping, so we know where to draw new hexs
        # @innerStage.position.x += (x - @lastDrag.x) / @outerStage.scale.x
        # @innerStage.position.y += (y - @lastDrag.y) / @outerStage.scale.y
        # @lastDrag.x = x
        # @lastDrag.y = y
      # else
        # @lastDrag = { x: x, y: y }

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
