# the game server code
class ServerLogic

  constructor: (@core) ->
    @clients = []
    @actions = []

  update: (steps) ->
    @core._sync(steps, @actions)
    for client in @clients
      client.sync(steps, @actions)
    @actions = []

  addClient: (socket) ->
    send = (type, data) -> socket.emit(HexProtocol.CHANNEL, [type, data])
    protocol = new HexProtocol(this, send)
    @clients.push(protocol)
    console.log("#{@clients.length} connections")
    return protocol

  removeClient: (protocol) ->
    if protocol in @clients
      @clients.splice(@clients.indexOf(protocol), 1)
    console.log("#{@clients.length} connections")

  _load: (state) ->
    console.log('a naughty client just sent the `load` command')

  _sync: (step) ->
    console.log('a naughty client just sent the `sync` command')

  _move: (gameData) ->
    @moves.push(gameData)

  _start: (playerName) ->
    #give hex to player
    hex = @core.grid.getRandomStartingHex()
    @core.players[playerName] = new Player(playerName)
    @actions.push(['take', playerName, hex.x, hex.y])
    #show adjacent hexs to player
    hexs = @core.grid.getAdjacentHexs(hex)
    console.log("hex: " + hex.x + " " + hex.y)
    for h in hexs
      @actions.push(['show', playerName, h.x, h.y])

  _attack: (gameData) ->
    playerName = gameData[0]
    hex = @core.grid.hexs[gameData[1]][gameData[2]]
    @actions.push(['take', playerName, hex.x, hex.y])
    #show adjacent hexs to player
    hexs = @core.grid.getAdjacentHexs(hex)
    for h in hexs
      #TODO: this often sends 'show' for hexs that the player can actually already see, improve performance?
      @actions.push(['show', playerName, h.x, h.y])
    if hex.owner?
      #TODO: need to send 'hide' action to hex.owner for the hex's he lost sight of
      return 0

# essentials
express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io')(server)

# the game
HexCore = require('./public/game_core.js').HexCore
Player = require('./public/game_core.js').Player
HexProtocol = require('./public/game_protocol.js').HexProtocol
core = new HexCore()
serverLogic = new ServerLogic(core)

# directory for static web content
app.use(express.static('public'))

# websocket connections
io.on('connection', (socket) ->
  # not really necessary, just testing stuff
  console.log('client connected!')
  socket.emit('message', 'hello from index.js!')
  socket.on('message', (data) ->
    console.log("client says: [#{data}]")
  )
  # the really important stuff
  protocol = serverLogic.addClient(socket)
  socket.on(HexProtocol.CHANNEL, (data) -> protocol.receive(data[0], data[1]))
  socket.on('disconnect', (data) ->
    console.log('client disconnected!')
    serverLogic.removeClient(protocol)
  )
)

# start the server
server.listen(8080, () -> console.log('server started!'))

# start the game
steps = 100
setInterval((() -> serverLogic.update(steps)), steps)
