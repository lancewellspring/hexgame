class HexCell

  constructor: (@x, @y) ->
    @color = 0xffffff
    @owner = null
    @units = 0
    @stepCount = 0

  update: (steps) ->
    if @owner?
      @stepCount += steps
      if @stepCount >= 5000 and @units < 100
        @units += 1
        @stepCount -= 5000

  setOwner: (player) ->
    @owner = player
    @color = player.color
    
  isAdjacent: (other) ->
    indices = HexGrid.adjacentIndices
    if @y % 2 == 0
      indices = indices.concat(HexGrid.evenRowIndices)
    else
      indices = indices.concat(HexGrid.oddRowIndices)
    for i in indices
      [x, y] = i
      if @x + x == other.x and @y + y == other.y
        return true
    return false

class HexGrid

  @adjacentIndices = [[0, -1], [0, 1], [-1, 0], [1, 0]]
  @evenRowIndices = [[-1, 1], [-1, -1]]
  @oddRowIndices = [[1, 1], [1, -1]]

  constructor: () ->
    @width = 10
    @height = 10
    @hexs = []
    for i in [0...@width]
      @hexs.push([])
      for j in [0...@height]
        @hexs[i].push(new HexCell(i, j))

  getAdjacentHexs: (hex) ->
    neighbors = []
    indices = HexGrid.adjacentIndices
    if hex.y % 2 == 0
      indices = indices.concat(HexGrid.evenRowIndices)
    else
      indices = indices.concat(HexGrid.oddRowIndices)
    for i in indices
      [x, y] = i
      x += hex.x
      y += hex.y
      if x >= 0 and x < @width and y >= 0 and y < @height
        neighbors.push(@hexs[x][y])
    return neighbors

  getAdjacentPlayers: (hex) ->
    players = []
    for n in @getAdjacentHexs(hex)
      players.push(n.owner)
    return players;

  hasAdjacentPlayers: (hex) ->
    players = @getAdjacentPlayers(hex)
    for player in players
      if player != null and player != hex.owner
        return true
    return false

  getRandomStartingHex: () ->
    hex = null
    #TODO: Hacky way to give any random hex to player if there are no hexs w/o neighbors
    i = 0
    while hex == null or hex.owner != null or @hasAdjacentPlayers(hex)
      hex = @hexs[Math.floor(Math.random() * @width)][Math.floor(Math.random() * @height)]
      i+= 1
      if i > 100
        break
    return hex

class HexProtocol

  @CHANNEL = 'hex'

  constructor: (@handler, @send) ->
    @actions = []

  # parse received data and call the appropriate handler function
  receive: (type, data) ->
    switch type
      when 'load'
        [state] = data
        @handler._load(this, state)
      when 'sync'
        [steps, actions] = data
        @handler._sync(this, steps, actions)
      when 'playerStart'
        [@playerName] = data
        @handler._playerStart(this, @playerName)
      when 'attack'
        [gameData] = data
        @handler._attack(this, gameData)
      when 'chat'
        [message] = data
        @handler._chat(this, message)
      when 'playerJoined'
        [name, id, color] = data
        @handler._playerJoined(name, id, color)
      when 'playerLeft'
        [id] = data
        @handler._playerLeft(id)
      when 'transferUnits'
        [id, fromx, fromy, tox, toy, units] = data
        @handler._transferUnits(id, fromx, fromy, tox, toy, units)
      else
        console.log("ignored command [#{type}]")

  # sever -> client: initial game state
  load: (state) ->
    @send('load', [state])

  # sever -> client: incremental game updates
  sync: (steps) ->
    @send('sync', [steps, @actions])
    @actions = []

  # sever -> client: let other clients know of joining player
  playerJoined: (name, id, color) ->
    @send('playerJoined', [name, id, color])

  # sever -> client: let other clients know of leaving player
  playerLeft: (id) ->
    @send('playerLeft', [id])

  # client -> server: attempt player start
  playerStart: (@playerName) ->
    @send('playerStart', [@playerName])

  # client -> server: attempt player attack
  attack: (gameData) ->
    @send('attack', [gameData])
    
  transferUnits: (id, fromx, fromy, tox, toy, units) ->
    @send('transferUnits', [id, fromx, fromy, tox, toy, units])

  # bidirectional: broadcast a chat message
  chat: (message) ->
    @send('chat', [message])

class HexPlayer

  @playerCount = 0

  _getRandomColor = () ->
    # helpers to build random colors
    rand = (a, b) -> a + Math.floor(Math.random() * (b - a))
    randColor = (a, b) -> (rand(a, b) << 16) | (rand(a, b) << 8) | rand(a, b)
    # start with lighter and darker colors
    [lights, darks] = [randColor(0x90, 0xe0), randColor(0x10, 0x70)]
    # avoid shades of grey by mixing light and dark channels
    channel = 0xff << (rand(0, 3) * 8)
    inverter = rand(-1, 1)
    mask = channel ^ inverter
    # mix the channels with a vector mask (SIMD ftw)
    return (lights & mask) | (darks & ~mask)

  constructor: (@name, @id, @color, @protocol) ->
    @color = @color ? _getRandomColor()
    if not @id?
      @id = HexPlayer.playerCount++
    @hexs = []

  update: (steps) ->
    for hex in @hexs
      hex.update(steps)

  addHex: (hex) ->
    @hexs.push(hex)

  removeHex: (hex) ->
    index = @hexs.indexOf(hex)
    #TODO: assert index >= 0
    this.hexs.splice(index, 1)

class HexCore

  constructor: () ->
    @grid = new HexGrid()
    @currentStep = @limitStep = 0
    @limitActions = []
    @players = {}

  #updates things which are constantly changing (ie unit production)
  update: (steps) ->
    steps = Math.min(steps, @limitStep - @currentStep)
    if steps == 0
      return false
    for k, p of @players
      p.update(steps)
    @currentStep += steps
    return true

  updateHex: (hex, player) ->
    if hex.owner?
      hex.owner.removeHex(hex)
    if player?
      hex.setOwner(player)
      player.addHex(hex)

  #syncs actions of players to eachother (and self)
  _sync: (protocol, steps, actions) ->
    if @limitStep > @currentStep
      @update(@limitStep - @currentStep)
    if @limitActions.length > 0
      console.log("#{@limitActions.length} moves in last #{@currentStep} steps")
    for action in @limitActions
      console.log(action)
      [type, playerId, x, y, units, stepCount] = action
      hex = @grid.hexs[x][y]
      hex.units = units
      hex.stepCount = stepCount
      player = null
      if playerId?
        #TODO: assert playerId of @players
        player = @players[playerId]
      switch type
        when 'hex'
          @updateHex(hex, player)
        when 'take'
          console.log("Received old 'take' action")
        when 'show'
          console.log("Received old 'show' action")
        else
          console.log("ignored action [#{type}]")
    @currentStep = 0
    @limitStep = steps
    @limitActions = actions

# public interface
(window ? {}).HexCore = exports.HexCore = HexCore
(window ? {}).HexPlayer = exports.HexPlayer = HexPlayer
(window ? {}).HexProtocol = exports.HexProtocol = HexProtocol
