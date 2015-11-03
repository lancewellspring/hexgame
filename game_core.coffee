class HexCell

  constructor: (@x, @y) ->
    @color = 0xffffff
    @owner = null
    @units = 0
    #@speed = 1
    #@angle = 0

  update: (steps) ->
    #@angle += @speed * steps
    
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
    indices = [0,-1, 0,1, -1,0, 1,0]
    if(hex.x % 2 == 0)
      indices += [-1, 1, 1, 1]
    else
      indices += [1, -1, -1, -1]
    for i in [0 ... indices.length] by 2
      [x, y] = a[i .. i+1]
      x += hex.x
      y += hex.y
      if x >= 0 and x < @width and y >= 0 and y < @height
        neighbors.push(@hexs[x][y])
    return neighbors
    
  getAdjacentPlayers: (hex) ->
    players = []
    for n in @getAdjacentHexs(hex)
      players.push(n.owner);
    return players;
        
  hasAdjacentPlayers: (hex) ->
    players = getAdjacentPlayers(hex)
    for player in players
      if player != null and player != hex.owner
          return true
    return false

  getRandomStartingHex: () ->
    hex = null
    while (hex == null or @hasAdjacentPlayers(hex))
        hex = @hexs[Math.floor(Math.random() * @width)][Math.floor(Math.random() * @height)]
    return hex
				
class Player

  constructor: (@name) ->
    @color = Math.floor(Math.random() * (1 << 24)) | 0x282828
    @hexs = []
    
  update: (steps) ->
    for hex in @hexs
      hex.update(steps)
      
  addHex: (hex) ->
    @hexs.push(hex)
    
  removeHex: (hex) ->
    var index = @hexs.indexOf(hex);
    #TODO: assert index >= 0
    this.hexs.splice(index, 1);

class HexCore

  @setColor: (index, color) -> ['color', [index, color]]
  @setSpeed: (index, speed) -> ['speed', [index, speed]]

  constructor: () ->
    @grid = new Grid()
    @currentStep = @limitStep = 0
    @limitMoves = []
    @cells = []#(new HexCell(i) for i in [0...3])
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

  _load: (state) ->
    [@currentStep, @limitStep, @limitMoves, cellData] = state
    for [cell, data] in _.zip(@cells, cellData)
      cell._load(data)
    console.log('loaded state')

  #syncs actions of players to eachother (and self)
  _sync: (steps, actions) ->
    if @limitStep > @currentStep
      @update(@limitStep - @currentStep)
    if @limitMoves.length > 0
      console.log("#{@limitMoves.length} moves in last #{@currentStep} steps")
    for action in actions
      [type, playerName, x, y] = action
      hex = @grid.hexs[x][y]
      switch type
        when 'take'
          player = @players[playerName]
          if hex.owner != null
            hex.owner.removeHex(hex)
          player.addHex(hex)
          hex.setOwner(player)
          @cells.push(hex)
        when 'show'
          if not hex in @cells
            @cells.push(hex)
        when 'hide'
          #TODO: figure out a way to notify the renderer to remove this hex from being displayed
        else
          console.log("ignored action [#{type}]")
      
    @currentStep = 0
    @limitStep = steps
    #TODO: Not sure I understand the purpose of @limitMoves.  Perhaps the same thing needs to be done for actions?
    @limitMoves = moves

# public interface
(exports ? window).HexCore = HexCore
