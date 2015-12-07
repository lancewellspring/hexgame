{HexVersion} = require('./hex_version.js')
{HexCore} = require('./hex_core.js')
{HexPlayer} = require('./hex_core.js')
{HexProtocol} = require('./hex_core.js')
{UnitCell} = require('./hex_core.js')

# the game server code
class HexServer extends HexCore

  constructor: () ->
    try
      super()
      @clients = []
    catch ex
      console.log(ex.stack)

  update: (steps) ->
    try
      super(steps)
      @_sync(null, steps, null)
      # send out subsets of actions to individual players
      for client in @clients
        # TODO: properly fix this error:
        #   TypeError: Cannot call method 'sync' of undefined
        #     at HexServer.update (/home/hex/common/app/public/hex_server.js:34:29)
        #     at null.<anonymous> (/home/hex/common/app/index.js:45:22)
        #     at wrapper [as _onTimeout] (timers.js:252:14)
        #     at Timer.listOnTimeout [as ontimeout] (timers.js:110:15)
        client?.sync(steps)
    catch ex
      console.log(ex)
      process.exit(1)
    return

  addClient: (socket) ->
    try
      send = (type, data) -> socket.emit(HexProtocol.CHANNEL, [type, data])
      protocol = new HexProtocol(this, send)
      @clients.push(protocol)
      console.log("#{@clients.length} connections")
      return protocol
    catch ex
      console.log(ex.stack)
    return

  removeClient: (protocol) ->
    try
      if protocol in @clients
        @clients.splice(@clients.indexOf(protocol), 1)
        if protocol.player?
          #remove this player's hex from server and all other players
          actions = []
          for h in protocol.player.hexs
            action = ['hex', null, h.key, 0, 0]
            @updatePlayers(h, action)
          console.log("#{protocol.player.name} has left the game.")
          delete @players[protocol.player.id]
    catch ex
      console.log(ex.stack)
    return

    console.log("#{@clients.length} connections")

  _load: (protocol, state) ->
    console.log('a naughty client just sent the `load` command')

  _sync: (protocol, steps, actions) ->
    if protocol?
      console.log('a naughty client just sent the `sync` command')
    else
      super(protocol, steps, actions)
      
  showPlayerAdjacentHexs: (player, protocol, hex) ->
    #TODO: this often sends 'show' for hexs that the player can actually already see, improve performance?
    hexs = @grid.getAdjacentHexs(hex)
    for h in hexs
      if h? and h.owner != player
        action = ['hex', h?.owner?.id, h.key, h.units, h.stepCount]
        protocol.actions.push(action)
    return

  _playerStart: (protocol, playerName) ->
    try
      console.log("#{playerName} has joined the game!")
      #send all current players to new player
      for id, player of @players
        protocol.playerJoined(player.name, id, player.color)
      #give hex to player
      hex = @grid.getRandomStartingHex()
      player = new HexPlayer(playerName, null, null, protocol)
      protocol.player = player
      @players[player.id] = player
      hex.setOwner(player)
      player.addHex(hex)
      action = ['hex', player.id, hex.key, 0, 0]
      protocol.actions.push(action)
      #immediately notify all clients of new player
      for client in @clients
        client.playerJoined(playerName, player.id, player.color)
        
      #temporary code to show player all hexs
      # for k,h of @grid.hexs
        # if h != hex
          # action = ['hex', h?.owner?.id, h.key, h.units, h.stepCount]
          # protocol.actions.push(action)
      @showPlayerAdjacentHexs(player, protocol, hex)
    catch ex
      console.log(ex.stack)
    return
      
  #update all players that can see the actions (including the sending player)
  updatePlayers: (hex, action) ->
    for id, p of @players
      if hex in p.hexs
        p.protocol.actions.push(action)
      else
        for h in p.hexs
          #TODO: there is likely a faster way to do this, not sure if its eating up much cpu tho.
          adjacent = @grid.getAdjacentHexs(h)
          if hex in adjacent
            p.protocol.actions.push(action)
            break
    return
    
  unitsArrive: (unitCell) =>
    try
      console.log("units arrived at " + unitCell.destination.key)
      super(unitCell)
      action = []
      key = unitCell.destination.key
      hex = @grid.hexs[key]
      taken = false
      newUnitCount = 0
      #decide if the units reinforce or attack, and if attack is successful
      if unitCell.owner == hex.owner
        #reinforce
        newUnitCount = hex.units + unitCell.units
        hex.units = newUnitCount
        action = ['hex', unitCell.owner.id, hex.key, newUnitCount, hex.stepCount]
      else if unitCell.units > hex.units
        #successful attack
        taken = true
        #change owner
        if hex.owner?
          hex.own.removeHex(hex)
        unitCell.owner.addHex(hex)
        hex.setOwner(unitCell.owner)
        #change unit count
        newUnitCount = unitCell.units - hex.units
        hex.units = newUnitCount
        action = ['hex', unitCell.owner.id, hex.key, newUnitCount, hex.stepCount]
      else
        #unsuccessful attack
        newUnitCount = hex.units - unitCell.units
        hex.units = newUnitCount
        action = ['hex', hex.owner.id, hex.key, newUnitCount, hex.stepCount]
      @updatePlayers(hex, action)
      if taken
        @showPlayerAdjacentHexs(unitCell.owner, unitCell.owner.protocol, hex)
    catch ex
      console.log(ex.stack)
    return
    
  _sendUnits: (id, fromkey, tokey, units) ->
    try
      console.log("moving/attacking " + units + " units to " + tokey + " from " + fromkey + ".")
      #update server with actions
      player = @players[id]
      fromHex = @grid.hexs[fromkey]
      #TODO: this should fix the negative units problem, but still need to figure out how the client is sending messages that was causing hte negative untis
      if fromHex.units - units < 0
        console.log("fromHex only has " + fromHex.units + " units.")
        return
      fromHex.units = fromHex.units-units
      fromAction = ['hex', id, fromHex.key, fromHex.units, fromHex.stepCount]
      @updatePlayers(fromHex, fromAction)
      
      toHex = @grid.hexs[tokey]
      duration = Math.sqrt(Math.pow(toHex.q - fromHex.q, 2) + Math.pow(toHex.r - fromHex.r, 2)) * 1000
      moveAction = ['move', player.id, fromHex.key, units, 0, duration, toHex.key]
      player.protocol.actions.push(moveAction)
      
      @startUnitMove(player, units, duration, fromHex, toHex)
    catch ex
      console.log(ex.stack)
    return

  _chat: (protocol, message) ->
    try
      # ignore spoofed messages
      if not protocol.player?
        return
      # message formatting
      console.log("[chat] #{protocol.player.name}: #{message}")
      formatted = "<b>#{protocol.player.name}:</b> #{message}"
      # don't queue it with the other actions, relay it to everyone immediately
      for client in @clients
        client.chat(formatted)
    catch ex
      console.log(ex.stack)
    return

(window ? {}).HexServer = exports.HexServer = HexServer
