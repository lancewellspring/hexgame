class UnitCell
  #represents a group of units as it travels between hexs
  constructor: (@owner, @units, @duration, @origin, @destination, @arriveCallback) ->
    @arrived = false

  update: (steps) ->
    @duration -= steps
    if @duration <= 0 and not @arrived
      @arriveCallback(this)
      @arrived = true

class HexCell

  _max_units = 100

  _generation_time = 5000

  _directions = [
    {q: 1, r: 0, s:-1}
    {q: 1, r:-1, s: 0}
    {q: 0, r:-1, s: 1}
    {q:-1, r: 0, s: 1}
    {q:-1, r: 1, s: 0}
    {q: 0, r: 1, s:-1}
  ]

  _length = (h) -> (Math.abs(h.q) + Math.abs(h.r) + Math.abs(h.s)) / 2

  _equals = (h1, h2) -> h1.q == h2.q and h1.r == h2.r and h1.s == h2.s

  _round = (h) ->
    q = Math.round(h.q)
    r = Math.round(h.r)
    s = Math.round(h.s)
    q_diff = Math.abs(q - h.q)
    r_diff = Math.abs(r - h.r)
    s_diff = Math.abs(s - h.s)
    if q_diff > r_diff and q_diff > s_diff
      q = -r - s
    else if r_diff > s_diff
      r = -q - s
    else
      s = -q - r
    return {q:q, r:r, s:s}

  _key = (h) -> h.q + "|" + h.r

  constructor: (@q, @r, @s=null) ->
    if not @s?
      @s = -@q-@r
    #offset coordinate system, for the sake of rendering and displaying coordinates to user
    @x = @q + Math.floor((@r + -1 * (@r & 1)) / 2)
    @y = @r
    @key = _key(this)
    @color = 0xffffff
    @owner = null
    @units = 0
    @stepCount = 0

  update: (steps) ->
    if @owner?
      @stepCount += steps
      while @stepCount >= _generation_time
        if @units < _max_units
          @units += 1
        @stepCount -= _generation_time

  setOwner: (player) ->
    @owner = player
    @color = if player?.color? then player.color else 0xffffff

  #hex_ functions ONLY deal with objects with q/r/s properties, they don't return a HexCell object
  hex_add: (h) ->
    return {q:@q+h.q, r:@r+h.r, s:@s+h.s}

  hex_subtract: (h) ->
    return {q:@q-h.q, r:@r-h.r, s:@s-h.s}

  #returns true if h is adjacent to this
  hex_adjacent: (h) ->
    for d in _directions
      if _equals(h, @hex_add(d))
        return true
    return false

  #returns the distance between this hex and h
  hex_distance: (h) ->
    return _length(@hex_subtract(h))

  hex_lerp: (h, t) ->
    return {q:@q + (h.q - @q) * t, r:@r + (h.r - @r) * t, s:@s + (h.s - @s) * t}

  #returns a list of keys of the hexs along a line drawn between this and h
  hex_linedraw: (h) ->
    N = @hex_distance(h)
    results = []
    step = 1.0 / Math.max(N, 1)
    for i in [0..N]
      results.push(_key(_round(@hex_lerp(h, step * i))))
    return results;

  #returns the keys of all neighbors
  getNeighborKeys: () ->
    r = []
    for d in _directions
      r.push(_key(@hex_add(d)))
    return r

class HexGrid

  constructor: () ->
    @radius = 6
    @hexs = {}
    for q in [-@radius..@radius]
      r1 = Math.max(-@radius, -q - @radius)
      r2 = Math.min(@radius, -q + @radius)
      for r in [r1..r2]
        h = new HexCell(q,r)
        @hexs[h.key] = h

  getAdjacentHexs: (hex) ->
    neighbors = []
    for k in hex.getNeighborKeys()
      if @hexs[k]?
        neighbors.push(@hexs[k])
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
    while not hex? or hex.owner != null or @hasAdjacentPlayers(hex)
      q = Math.round(Math.random() * (@radius-1))
      r = Math.round(Math.random() * (@radius-1))
      hex = @hexs[q + "|" + r]
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
      # when 'attack'
        # [gameData] = data
        # @handler._attack(this, gameData)
      when 'chat'
        [message] = data
        @handler._chat(this, message)
      when 'playerJoined'
        [name, id, color] = data
        @handler._playerJoined(name, id, color)
      when 'playerLeft'
        [id] = data
        @handler._playerLeft(id)
      when 'sendUnits'
        [id, fromKey, toKey, units] = data
        @handler._sendUnits(id, fromKey, toKey, units)
      # when 'moveUnits'
        # [id, fromx, fromy, tox, toy, units] = data
        # @handler._moveUnits(id, fromx, fromy, tox, toy, units)
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

  # client -> server: attempt unit move
  sendUnits: (id, fromKey, toKey, units) ->
    @send('sendUnits', [id, fromKey, toKey, units])

  # client -> server: attempt player attack
  # attack: (gameData) ->
    # @send('attack', [gameData])

  # client -> server: attempt unit move
  # moveUnits: (id, fromx, fromy, tox, toy, units) ->
    # @send('moveUnits', [id, fromx, fromy, tox, toy, units])

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
    @hexs.splice(index, 1)

class HexCore

  constructor: () ->
    @grid = new HexGrid()
    @currentStep = @limitStep = 0
    @limitActions = []
    @players = {}
    @unitCells = []

  #updates things which are constantly changing (ie unit production)
  update: (steps) ->
    steps = Math.min(steps, @limitStep - @currentStep)
    if steps == 0
      return false
    for k, p of @players
      p.update(steps)
    for unitCell in @unitCells
      #TODO: figure out how in the world there are undefined unitCells
      if unitCell?
        unitCell.update(steps)
    @currentStep += steps
    return true

  updateHex: (hex, player) ->
    if hex.owner?
      hex.owner.removeHex(hex)
    if player?
      player.addHex(hex)
    hex.setOwner(player)

  unitsArrive: (unitCell) =>
    console.log("core untis arrive")
    index = @unitCells.indexOf(unitCell)
    #TODO: assert index >= 0
    @unitCells.splice(index, 1)

  startUnitMove: (player, units, duration, fromHex, toHex) ->
    console.log("start move")
    unitCell = new UnitCell(player, units, duration, fromHex, toHex, @unitsArrive)
    @unitCells.push(unitCell)

  #syncs actions of players to eachother (and self)
  _sync: (protocol, steps, actions) ->
    if @limitStep > @currentStep
      @update(@limitStep - @currentStep)
    if @limitActions.length > 0
      console.log("#{@limitActions.length} moves in last #{@currentStep} steps")
    @currentStep = 0
    @limitStep = steps

# public interface
(window ? {}).HexCore = exports.HexCore = HexCore
(window ? {}).HexPlayer = exports.HexPlayer = HexPlayer
(window ? {}).HexProtocol = exports.HexProtocol = HexProtocol
