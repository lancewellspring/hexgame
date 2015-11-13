{HexVersion} = require('./hex_version.js')
{HexCore} = require('./hex_core.js')
{HexPlayer} = require('./hex_core.js')
{HexProtocol} = require('./hex_core.js')

class HexClient extends HexCore

  constructor: (@playerName, @renderer, socket) ->
    super()
    @thisPlayer = null
    @selectedHex = null
    @cells = []
    #setup click callback
    @renderer.hexSpriteClick = (hexSprite) => @hexClick(hexSprite)

    @protocol = new HexProtocol(this, (type, data) ->
      socket.emit(HexProtocol.CHANNEL, [type, data])
    )

    socket.on(HexProtocol.CHANNEL, (data) =>
      @protocol.receive(data[0], data[1])
    )

    @protocol.playerStart(@playerName)

  update: (steps) ->
    if super
      return false
    for cell in @cells
      cell.update(steps)
    return true

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
    loseHex = (hex?.owner == @thisPlayer and player != @thisPlayer)
    super(hex, player)
    if loseHex
      visible = []
      for myhex in @thisPlayer.hexs
        visible.push(myhex)
        for h in @grid.getAdjacentHexs(myhex)
          visible.push(h)
      check = @grid.getAdjacentHexs(hex)
      check.push(hex)
      for h in check
        if not (h in visible)
          index = @cells.indexOf(h)
          @cells.splice(index, 1)
          @renderer.removeHex(h)
    else if not (hex in @cells)
      @cells.push(hex)
      
  setSelectedHex: (hex, hexSprite) ->
    if @selectedHex?
      @selectedHex.sprite.deselect()
    @selectedHex = hex
    @selectedHex.sprite = hexSprite
    hexSprite.select()
    @renderer.autoPan(hexSprite.sprite.position.x, hexSprite.sprite.position.y)

  hexClick: (hexSprite) ->
    clickedHex = @grid.hexs[hexSprite.gridx][hexSprite.gridy]
    if @selectedHex?
      #decide whether to change selected hex, move units, or attack
      if @selectedHex == clickedHex
        @selectedHex = null
        hexSprite.deselect()
      else if @selectedHex.owner == @thisPlayer and @selectedHex.isAdjacent(clickedHex)
        if clickedHex.owner == @thisPlayer
          @protocol.transferUnits(@thisPlayer.id, @selectedHex.x, @selectedHex.y, clickedHex.x, clickedHex.y, Math.floor(@selectedHex.units/2))
        else
          @protocol.attack([@thisPlayer.id, @selectedHex.x, @selectedHex.y, clickedHex.x, clickedHex.y])
      else
        @setSelectedHex(clickedHex, hexSprite)
    else
      @setSelectedHex(clickedHex, hexSprite)

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
