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
    @renderer.selectHexCallback = (hexSprite) => @selectHex(hexSprite)
    @renderer.unitsSelectCallback = (hexSprite, units) => @unitsSelect(hexSprite, units)
    @renderer.unitsCancelCallback = (hexSprite) => @unitsCancel(hexSprite)

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
  
  _sync: (protocol, steps, actions) ->
    super(protocol, steps, actions)
    for action in @limitActions
      console.log(action)
      [type, id, hexKey, units, stepCount, duration, toHexKey] = action
      hex = @grid.hexs[hexKey]
      player = null
      if id?
        #TODO: assert id of @players
        player = @players[id]
      switch type
        when 'hex'
          hex.units = units
          hex.stepCount = stepCount
          @updateHex(hex, player)
        when 'move'
          @startUnitMove(player, units, duration, hex, @grid.hexs[toHexKey])
        else
          console.log("ignored action [#{type}]")
    @limitActions = actions

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
    
  selectHex: (hexSprite) ->
    clickedCell = @grid.hexs[hexSprite.key]
    if clickedCell == @selectedCell
      @selectedCell.unitsSelected = 0
      hexSprite.select()
    else if @selectedCell?.unitsSelected > 0
      console.log("send units")
      @protocol.sendUnits(@thisPlayer.id, @selectedCell.key, clickedCell.key, @selectedCell.unitsSelected)
      @selectedCell.unitsSelected = 0
      @selectedCell = null
    else if clickedCell.owner == @thisPlayer
      @selectedCell = clickedCell
      @selectedCell.unitsSelected = 0
      hexSprite.select()
      @renderer.autoPan(hexSprite.sprite.position.x, hexSprite.sprite.position.y)
    
  unitsSelect: (hexSprite, units) ->
    clickedCell = @grid.hexs[hexSprite.key]
    if clickedCell == @selectedCell
      @selectedCell.unitsSelected = units
    
  unitsCancel: (hexSprite) ->
    @selectedCell.unitsSelected = 0
    @selectedCell = null
    clickedCell = @grid.hexs[hexSprite.key]
    clickedCell.unitsSelected = 0
      
  startUnitMove: (player, units, duration, fromHex, toHex) ->
    super(player, units, duration, fromHex, toHex)
    hexs = []
    for k in fromHex.hex_linedraw(toHex)
      hexs.push(@grid.hexs[k])
    @renderer.startUnitAnimation(player, hexs, units, duration)

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
