HexCore = require('./hex_core.js').HexCore
HexPlayer = require('./hex_core.js').HexPlayer
HexProtocol = require('./hex_core.js').HexProtocol

class HexClient extends HexCore

  constructor: (@playerName, @renderer, socket) ->
    super()
    @thisPlayer = null
    @cells = []
    #setup click callback
    @renderer.hexSpriteClick = @sendAttack

    @protocol = new HexProtocol(this, (type, data) =>
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
    @renderer.autoScroll()

  sendAttack: (x, y) =>
    @protocol.attack([@thisPlayer.id, x, y])

  sendChat: (msg) ->
    @protocol.chat(msg)

  _playerJoined: (name, id, color) ->
    console.log("playerJoined: #{name} #{id}")
    @players[id] = new HexPlayer(name, id, color, null)
    if name == @playerName
      @thisPlayer = @players[id]

  # called whenever a chat message is received
  _chat: (protocol, message) ->
    # TODO: this should be organized better
    if @_print?
      @_print(message)

# public interface
(window ? {}).HexClient = exports.HexClient = HexClient
