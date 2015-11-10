# essentials
express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io')(server)

# the game
HexProtocol = require('./public/hex_core.js').HexProtocol
HexServer = require('./public/hex_server.js').HexServer
hexServer = new HexServer()

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
  protocol = hexServer.addClient(socket)
  socket.on(HexProtocol.CHANNEL, (data) -> protocol.receive(data[0], data[1]))
  socket.on('disconnect', (data) ->
    console.log('client disconnected!')
    hexServer.removeClient(protocol)
  )
)

# start the server
server.listen(8080, () -> console.log('server started!'))

# start the game
steps = 100
setInterval((() -> hexServer.update(steps)), steps)
