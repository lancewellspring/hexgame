{HexVersion} = require('./hex_version.js')
{HexCore} = require('./hex_core.js')
{HexPlayer} = require('./hex_core.js')
{HexProtocol} = require('./hex_core.js')

class HexClient extends HexCore

  constructor: (@playerName, @renderer, socket) ->
    super()
    @thisPlayer = null
    @selectedCell = null
    @cells = []
    #setup click callbacks
    #@renderer.hexSpriteClick = (hexSprite) => @hexClick(hexSprite)
    @renderer.selectCallback = (hexSprite) => @selectHex(hexSprite)
    @renderer.highlightCallback = (hexSprite) => @highlightHex(hexSprite)
    @renderer.cancelCallback = (hexSprite) => @cancelHex(hexSprite)
    @renderer.raidCallback = (hexSprite, units) => @raidHex(hexSprite, units)
    @renderer.conquerCallback = (hexSprite, units) => @conquerHex(hexSprite, units)
    @renderer.moveCallback = (hexSprite, units) => @moveUnits(hexSprite, units)
    @renderer.supplyCallback = (hexSprite, units) => @supplyHex(hexSprite, units)

    @protocol = new HexProtocol(this, (type, data) ->
      socket.emit(HexProtocol.CHANNEL, [type, data])
    )

    socket.on(HexProtocol.CHANNEL, (data) =>
      @protocol.receive(data[0], data[1])
    )

    @protocol.playerStart(@playerName)

  update: (steps) ->
    steps = Math.min(steps, @limitStep - @currentStep)
    if steps == 0
      return false
    for cell in @cells
      cell.update(steps)
    @currentStep += steps
  
    # if super
      # return false
    # for cell in @cells
      # cell.update(steps)
    # return true

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
      @update(steps)
      @renderer.update(steps, @cells)
    @renderer.animate()

  updateHex: (hex, player) ->
    #check if this hex was taken from @thisPlayer.  if so, recalculate the sight of @thisPlayer (after hex is updated with new owner).
    loseHex = (hex.owner == @thisPlayer and player != @thisPlayer)
    console.log("hex owner:#{hex.owner?.name}\ntaking player: #{player?.name}")
    super(hex, player)
    if loseHex
      console.log("hex owner:#{hex.owner?.name}\ntaking player: #{player?.name}")
      visible = []
      for myhex in @thisPlayer.hexs
        visible.push(myhex)
        for adj in @grid.getAdjacentHexs(myhex)
          visible.push(adj)
      check = @grid.getAdjacentHexs(hex)
      check.push(hex)
      for h in check
        if not (h in visible)
          index = @cells.indexOf(h)
          @cells.splice(index, 1)
          @renderer.removeHex(h)
    else if not (hex in @cells)
      @cells.push(hex)
      
  # setSelectedHex: (hex, hexSprite) ->
    # if @selectedHex?
      # @selectedHex.sprite.deselect()
    # @selectedHex = hex
    # @selectedHex.sprite = hexSprite
    # hexSprite.select()
    # @renderer.autoPan(hexSprite.sprite.position.x, hexSprite.sprite.position.y)
    
  selectHex: (hexSprite) ->
    console.log("select")
    clickedCell = @grid.hexs[hexSprite.gridx][hexSprite.gridy]
    if @selectedCell?
      @selectedCell.sprite.deselect()
    @selectedCell = clickedCell
    @selectedCell.sprite = hexSprite
    hexSprite.select()
    @renderer.autoPan(hexSprite.sprite.position.x, hexSprite.sprite.position.y)
    
  highlightHex: (hexSprite) ->
    console.log("highlight")
    highlighedCell = @grid.hexs[hexSprite.gridx][hexSprite.gridy]
    if @selectedCell == null and highlighedCell.owner == @thisPlayer
      hexSprite.showSelect()
    else if @selectedCell == null or highlighedCell == @selectedCell
      return #do nothing
    else if highlighedCell.owner == @thisPlayer
      hexSprite.showAllied(@selectedCell)
    else if @selectedCell.isAdjacent(highlighedCell)
      hexSprite.showEnemy(@selectedCell)
      
  cancelHex: (hexSprite) ->
    console.log("cancel")
    clickedCell = @grid.hexs[hexSprite.gridx][hexSprite.gridy]
    if clickedCell == @selectedCell
      @selectedCell = null
      hexSprite.deselect()
    else
      hexSprite.cancelAction()
      
  raidHex: (hexSprite, units) ->
    raidedCell = @grid.hexs[hexSprite.gridx][hexSprite.gridy]
    @cancelHex(@selectedCell.sprite)
    console.log("raid")
      
  conquerHex: (hexSprite, units) ->
    console.log("conquer")
    clickedCell = @grid.hexs[hexSprite.gridx][hexSprite.gridy]
    @protocol.attack([@thisPlayer.id, @selectedCell.x, @selectedCell.y, clickedCell.x, clickedCell.y, units])
    @cancelHex(@selectedCell.sprite)
      
  moveUnits: (hexSprite, units) ->
    console.log("move")
    clickedCell = @grid.hexs[hexSprite.gridx][hexSprite.gridy]
    @protocol.moveUnits(@thisPlayer.id, @selectedCell.x, @selectedCell.y, clickedCell.x, clickedCell.y, units)
    @cancelHex(@selectedCell.sprite)
      
  supplyHex: (hexSprite, units) ->
    console.log("supply")
    @cancelHex(@selectedCell.sprite)

  # hexClick: (hexSprite) ->
    # clickedHex = @grid.hexs[hexSprite.gridx][hexSprite.gridy]
    # if @selectedHex?
      ##decide whether to change selected hex, move units, or attack
      # if @selectedHex == clickedHex
        # @selectedHex = null
        # hexSprite.deselect()
      # else if @selectedHex.owner == @thisPlayer and @selectedHex.isAdjacent(clickedHex)
        # if clickedHex.owner == @thisPlayer
          # @protocol.moveUnits(@thisPlayer.id, @selectedHex.x, @selectedHex.y, clickedHex.x, clickedHex.y, Math.floor(@selectedHex.units/2))
        # else
          # @protocol.attack([@thisPlayer.id, @selectedHex.x, @selectedHex.y, clickedHex.x, clickedHex.y])
      # else
        # @setSelectedHex(clickedHex, hexSprite)
    # else
      # @setSelectedHex(clickedHex, hexSprite)

  sendChat: (msg) ->
    @protocol.chat(msg)

  # TODO: put this utility function somewhere better
  _cssColor = (color) -> '#' + ('00000' + color.toString(16)).slice(-6)

  _playerJoined: (name, id, color) ->
    console.log("playerJoined: #{name} #{id}")
    @players[id] = new HexPlayer(name, id, color, null)
    if name == @playerName
      @thisPlayer = @players[id]
    else
      if @_print?
        col = _cssColor(color)
        @_print("&lt;<span style=\"font-weight: bold;color:#{col}\">#{name}</span> joined the game.&gt;")

  _playerLeft: (id) ->
    console.log("playerLeft: #{id}")
    if id not of @players
      return
    player = @players[id]
    delete @players[id]
    if not player?
      return
    if @_print?
      col = _cssColor(player.color)
      @_print("&lt;<span style=\"font-weight: bold;color:#{col}\">#{player.name}</span> left the game.&gt;")

  # called whenever a chat message is received
  _chat: (protocol, message) ->
    # TODO: this should be organized better
    if @_print?
      @_print(message)

# public interface
(window ? {}).HexClient = exports.HexClient = HexClient
