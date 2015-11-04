# the game server code
class ServerLogic

  constructor: (@core, send) ->
    @protocol = new HexProtocol(this, send)
    @actions = []

  update: (steps) ->
    @core._sync(steps, @actions)
    @protocol.sync(steps, @actions)
    @actions = []

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
    for h in hexs
      @actions.push(['show', playerName, h.x, h.y])

  _attack: (gameData) ->
    @actions.push(['take'] + gameData)
    #show adjacent hexs to player
    playerName = gameData[0]
    hex = @core.grid[gameData[1]][gameData[2]]
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

# networking helper
send = (type, data) -> io.emit(HexProtocol.CHANNEL, [type, data])

# the game
HexCore = require('./public/game_core.js').HexCore
HexProtocol = require('./public/game_protocol.js').HexProtocol
core = new HexCore()
serverLogic = new ServerLogic(core, send)

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
  socket.on('disconnect', (data) ->
    console.log('client disconnected!')
  )
  # the really important stuff
  sendPrivate = (type, data) -> socket.emit(HexProtocol.CHANNEL, [type, data])
  socket.on(HexProtocol.CHANNEL, (data) -> serverLogic.protocol.receive(data[0], data[1]))
  #new HexProtocol(null, sendPrivate).load(core._save()) #no longer want to send whole state to client
)

# start the server
server.listen(8080, () -> console.log('server started!'))

# start the game
steps = 100
setInterval((() -> serverLogic.update(steps)), steps)
