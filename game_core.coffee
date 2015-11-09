class HexCell

  constructor: (@x, @y) ->
    @color = 0xffffff
    @owner = null
    @units = 0

  update: (steps) ->

  setOwner: (player) ->
    @owner = player
    @color = player.color

  #TODO: update save/load for new changes
  _save: () ->
    return [@index, @color, @speed, @angle]

  _load: (state) ->
    [@index, @color, @speed, @angle] = state


class Grid

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
    indices = [[0, -1], [0, 1], [-1, 0], [1, 0]]
    if hex.y % 2 == 0
      indices.push([-1, 1], [-1, -1])
    else
      indices.push([1, 1], [1, -1])
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

class Player
  @playerCount = 0
  constructor: (@name, @id, @color, @protocol) ->
    if @color == null or @color is undefined
      @color = Math.floor(Math.random() * (1 << 24)) | 0x282828
    if @id == null or @id is undefined
      @id = Player.playerCount++
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

  @setColor: (index, color) -> ['color', [index, color]]
  @setSpeed: (index, speed) -> ['speed', [index, speed]]

  constructor: (@playerName) ->
    @thisPlayer = null
    @grid = new Grid()
    @grid.getAdjacentHexs(@grid.hexs[2][3])
    @currentStep = @limitStep = 0
    @limitActions = []
    @cells = []
    @players = {}

  #updates things which are constantly changing (ie unit production)
  update: (steps) ->
    steps = Math.min(steps, @limitStep - @currentStep)
    if steps == 0
      console.log('lagging')
      return false
    for cell in @cells
      cell.update(steps)
    @currentStep += steps
    return true

  #TODO: need to update save/load for latest changes
  _save: () ->
    console.log('saved state')
    cellData = (cell._save() for cell in @cells)
    return [@currentStep, @limitStep, @limitMoves, cellData]

  _load: (protocol, state) ->
    [@currentStep, @limitStep, @limitMoves, cellData] = state
    for [cell, data] in _.zip(@cells, cellData)
      cell._load(data)
    console.log('loaded state')

  #syncs actions of players to eachother (and self)
  _sync: (protocol, steps, actions) ->
    if @limitStep > @currentStep
      @update(@limitStep - @currentStep)
    if @limitActions.length > 0
      console.log("#{@limitActions.length} moves in last #{@currentStep} steps")
    for action in @limitActions
      console.log(action)
      [type, playerId, x, y] = action
      hex = @grid.hexs[x][y]
      if playerId?
        #TODO: assert playerId of @players
        player = @players[playerId]
      switch type
        when 'hex'
          #TODO: logic to decide if this hex was taken from current player, and if so, hide it.
          if hex.owner?
            hex.owner.removeHex(hex)
          if playerId?
            hex.setOwner(player)
            player.addHex(hex)
          if not (hex in @cells)
            @cells.push(hex)
        when 'take'
          console.log("Received old 'take' action")
          # if hex.owner != null
            # hex.owner.removeHex(hex)
          # player.addHex(hex)
          # hex.setOwner(player)
          # if not (hex in @cells)
            # @cells.push(hex)
        when 'show'
          console.log("Received old 'show' action")
          # if not (hex in @cells)
            # hex.color = color
            # @cells.push(hex)
        else
          console.log("ignored action [#{type}]")

    @currentStep = 0
    @limitStep = steps
    @limitActions = actions
    
  _playerJoined: (name, id, color) ->
    console.log("playerJoined: #{name} #{id}")
    @players[id] = new Player(name, id, color, null)
    if name == @playerName
      @thisPlayer = @players[id]

  # called whenever a chat message is received
  _chat: (protocol, message) ->
    # TODO: this should be organized better
    if @_print?
      @_print(message)
      
  sendAttack: (protocol, x, y) ->
    protocol.attack([@thisPlayer.id, x, y])

# public interface
(exports ? window).HexCore = HexCore
(exports ? window).Player = Player
