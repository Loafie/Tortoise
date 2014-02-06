## (C) Uri Wilensky. https://github.com/NetLogo/NetLogo

#@# Value wrappers: ID, NLColor, XCor, YCor, PenMode
#@# Englishify this junk!
#@# Fatten up those arrows!
#@# Abolish postfix control flow (e.g. `3 if true`)
#@# Loops on numerical ranges should be Lodasherized
#@# Apply type signature to all methods
#@# Kill "amount" and "a" and "t" as varnames
#@# I hate `array[..]`.  It clones, but cryptically
#@# Names of private members should be preceded with underscores

#@# Links inherit `turtleBuiltins`, and `linkBuiltins` contain a bunch of crazy placeholder variables that don't actually mean anything --JAB (2/6/14)
turtleBuiltins = ["id", "color", "heading", "xcor", "ycor", "shape", "label", "labelcolor", "breed", "hidden", "size", "pensize", "penmode"]
patchBuiltins = ["pxcor", "pycor", "pcolor", "plabel", "plabelcolor"]
linkBuiltins = ["end1", "end2", "lcolor", "llabel", "llabelcolor", "lhidden", "lbreed", "thickness", "lshape", "tiemode"]
linkExtras = ["size", "heading", "midpointx", "midpointy"]

class NetLogoException
  constructor: (@message) ->
class DeathInterrupt    extends NetLogoException
class TopologyInterrupt extends NetLogoException
class StopInterrupt     extends NetLogoException

Updates = []

Nobody = {
  toString: -> "nobody"
}

AgentKind = {
  Observer: {}
  Turtle: {}
  Patch: {}
  Link: {}
}

Comparator = {

  NOT_EQUALS: {}

  EQUALS:       { toInt: 0 }
  GREATER_THAN: { toInt: 1 }  #@# Should inherit from `NOT_EQUALS`
  LESS_THAN:    { toInt: -1 } #@# Should inherit from `NOT_EQUALS`

  numericCompare: (x, y) ->
    if x < y
      @LESS_THAN
    else if x > y
      @GREATER_THAN
    else
      @EQUALS

}

#@# Replace with Lodash's equivalents
Utilities = {
  isArray:    (x) -> Array.isArray(x)
  isBoolean:  (x) -> typeof(x) is "boolean"
  isFunction: (x) -> typeof(x) is "function"
  isNumber:   (x) -> typeof(x) is "number"
  isObject:   (x) -> typeof(x) is "object"
  isString:   (x) -> typeof(x) is "string"
}

notImplemented = (name, defaultValue = {}) ->
  if console? and console.warn? then console.warn("The `#{name}` primitive has not yet been implemented.")
  -> defaultValue

ColorModel = {
  COLOR_MAX: 140
  baseColors: ->
    for i in [0..13]
      i * 10 + 5
  wrapColor: (c) ->
    if typeIsArray(c)
      c
    else
      modColor = c % @COLOR_MAX
      if modColor >= 0
        modColor
      else
        @COLOR_MAX + modColor
}

collectUpdates = ->
  result =
    if (Updates.length == 0)
      [turtles: {}, patches: {}]
    else
      Updates
  Updates = [{turtles: {}, patches: {}, links: {}, observer: {}, world: {}}]
  result

# gross hack - ST 1/25/13
#@# Rename to "seppuku", polymorphize properly!
died = (agent) ->
  if agent instanceof Turtle
    Updates[0].turtles[agent.id] = WHO: -1
  else if agent instanceof Link
    Updates[0].links[agent.id] = WHO: -1
  return

noop = (vars...) ->

#@# Make an `Update` class that always has turtles, links, and patches
#@# Vassal: { id: ID, companion: { trackedKeys: Set }, registerUpdate: Array[String -> Value] }
#@# Overlord: { updates: Array[Update], flushUpdates: Unit, collectUpdates: Array[Update] }
updated = (obj, vars...) ->
  update = Updates[0]
  if obj instanceof Turtle
    agents = update.turtles
  else if obj instanceof Patch
    agents = update.patches
  else if obj instanceof Link
    agents = update.links
  agentUpdate = agents[obj.id] or {}

  # Receiving updates for a turtle that's about to die means the turtle was
  # reborn, so we revive it in the update - BH 1/13/2014
  if agentUpdate['WHO'] < 0
    delete agentUpdate['WHO']

  # is there some less simpleminded way we could build this? surely there
  # must be. my CoffeeScript fu is stoppable - ST 1/24/13
  # Possible strategy. For variables with -, just replace it with a _ instead
  # of concatenating the words. For variables with a ?, replace it with _p or
  # something. For variables that need some kind of accessor, make the variable
  # that has the NetLogo name refer to the same thing that the NetLogo variable
  # does and make a different variable that refers to the thing you want in js.
  # For example, turtle.breed should refer to the breed name and
  # turtle._breed should point to the actual breed object.
  # BH 1/13/2014
  for v in vars #@# Create a mapper from engine names to view names
    switch v
      when "xcor"
        agentUpdate["XCOR"] = obj.xcor()
      when "ycor"
        agentUpdate["YCOR"] = obj.ycor()
      when "id"
        agentUpdate[if obj instanceof Link then "ID" else "WHO"] = obj[v]
      when "plabelcolor"
        agentUpdate["PLABEL-COLOR"] = obj[v]
      when "breed"
        agentUpdate["BREED"] = obj[v].name
      when "labelcolor"
        agentUpdate["LABEL-COLOR"] = obj[v]
      when "pensize"
        agentUpdate["PEN-SIZE"] = obj[v]
      when "penmode"
        agentUpdate["PEN-MODE"] = obj[v]
      when "hidden"
        agentUpdate["HIDDEN?"] = obj[v]
      when "tiemode"
        agentUpdate["TIE-MODE"] = obj[v]
      when "end1"
        agentUpdate["END1"] = obj[v].id
      when "end2"
        agentUpdate["END2"] = obj[v].id
      when "label"
        agentUpdate["LABEL"] = obj[v].toString()
      when "plabel"
        agentUpdate["PLABEL"] = obj[v].toString()
      else
        agentUpdate[v.toUpperCase()] = obj[v]
  agents[obj.id] = agentUpdate
  return

Call = (fn, args...) ->
  try fn(args...)
  catch e
    if not (e instanceof StopInterrupt)
      throw e

#@# Extends: `Agent`, `Vassal`, `CanTalkToPatches`
class Turtle
  vars: [] #@# You are the bane of your own existence
  _xcor: 0
  _ycor: 0
  _links: []
  constructor: (@color = 0, @heading = 0, xcor = 0, ycor = 0, breed = Breeds.get("TURTLES"), @label = "", @labelcolor = 9.9, @hidden = false, @size = 1.0, @pensize = 1.0, @penmode = "up") ->
    @_xcor = xcor
    @_ycor = ycor
    @breedVars = {} #@# Can be outside the constructor
    @updateBreed(breed)
    @vars = (x for x in TurtlesOwn.vars) #@# Can be outside the constructor
    @getPatchHere().arrive(this)
  updateBreed: (breed) ->
    if @breed
      @breed.remove(@)
    @breed = breed
    breed.add(@)
    @shape = @breed.shape()
    if(@breed != Breeds.get("TURTLES"))
      Breeds.get("TURTLES").add(this)
      for x in @breed.vars
        if(@breedVars[x] == undefined) #@# Simplify
          @breedVars[x] = 0
  xcor: -> @_xcor
  setXcor: (newX) ->
    originPatch = @getPatchHere()
    @_xcor = world.topology().wrapX(newX)
    if originPatch != @getPatchHere()
      originPatch.leave(this)
      @getPatchHere().arrive(this)
    @refreshLinks()
  ycor: -> @_ycor
  setYcor: (newY) ->
    originPatch = @getPatchHere()
    @_ycor = world.topology().wrapY(newY)
    if originPatch != @getPatchHere()
      originPatch.leave(this)
      @getPatchHere().arrive(this)
    @refreshLinks()
  setBreed: (breed) ->
    @updateBreed(breed)
    updated(this, "breed")
    updated(this, "shape")
  toString: -> "(" + @breed.singular + " " + @id + ")" #@# Interpolate
  keepHeadingInRange: ->
    if (@heading < 0 || @heading >= 360) #@# Rewrite comparison with fun comparator syntax
      @heading = ((@heading % 360) + 360) % 360
    return
  canMove: (amount) -> @patchAhead(amount) != Nobody
  distanceXY: (x, y) -> world.topology().distanceXY(@xcor(), @ycor(), x, y)
  distance: (agent) -> world.topology().distance(@xcor(), @ycor(), agent)
  towardsXY: (x, y) -> world.topology().towards(@xcor(), @ycor(), x, y)
  towards: (agent) ->
    if(agent instanceof Turtle)
      world.topology().towards(@xcor(), @ycor(), agent.xcor(), agent.ycor())
    else if (agent instanceof Patch)
      world.topology().towards(@xcor(), @ycor(), agent.pxcor, agent.pycor)
  faceXY: (x, y) ->
    if(x != @xcor() or y != @ycor())
      @heading = world.topology().towards(@xcor(), @ycor(), x, y)
      updated(this, "heading")
  face: (agent) ->
    if(agent instanceof Turtle)
      @faceXY(agent.xcor(), agent.ycor())
    else if (agent instanceof Patch)
      @faceXY(agent.pxcor, agent.pycor)
  inRadius: (agents, radius) ->
    world.topology().inRadius(this, @xcor(), @ycor(), agents, radius)
  patchAt: (dx, dy) ->
    try
      world.getPatchAt(
        world.topology().wrapX(@xcor() + dx),
        world.topology().wrapY(@ycor() + dy))
    catch error
      if error instanceof TopologyInterrupt then Nobody else throw error
  turtlesAt: (dx, dy) ->
    @patchAt(dx, dy).turtlesHere()
  connectedLinks: (directed, isSource) ->
    me = this #@# Wath?
    if directed
      new Agents(world.links().items.map((l) -> #@# Could this code be noisier?
        if (l.directed and l.end1 == me and isSource) or (l.directed and l.end2 == me and !isSource)
          l
        else
          null).filter((o) -> o != null), Breeds.get("LINKS"), AgentKind.Link) #@# I bet this comparison is wrong somehow...
    else
      new Agents(world.links().items.map((l) ->
        if (!l.directed and l.end1 == me) or (!l.directed and l.end2 == me)
          l
        else
          null).filter((o) -> o != null), Breeds.get("LINKS"), AgentKind.Link)
  refreshLinks: ->
    if @_links.length > 0
      l.updateEndRelatedVars() for l in (@connectedLinks(true, true).items) #@# Srsly?
      l.updateEndRelatedVars() for l in (@connectedLinks(true, false).items)
      l.updateEndRelatedVars() for l in (@connectedLinks(false, false).items)
  linkNeighbors: (directed, isSource) ->
    me = this #@# WTF, stop!
    if directed
      new Agents(world.links().items.map((l) -> #@# Noisy, noisy nonsense
        if l.directed and l.end1 == me and isSource
          l.end2
        else if l.directed and l.end2 == me and !isSource
          l.end1
        else
          null).filter((o) -> o != null), Breeds.get("TURTLES"), AgentKind.Turtle)
    else
      new Agents(world.links().items.map((l) ->
        if !l.directed and l.end1 == me
          l.end2
        else if !l.directed and l.end2 == me
          l.end1
        else
          null).filter((o) -> o != null), Breeds.get("TURTLES"), AgentKind.Turtle)
  isLinkNeighbor: (directed, isSource, other) -> #@# Other WHAT?
    @linkNeighbors(directed, isSource).items.filter((o) -> o == other).length > 0 #@# `_(derp).some(f)`
  findLinkViaNeighbor: (directed, isSource, other) -> #@# Other WHAT?
    me = this #@# No.
    links = [] #@# Bad
    if directed
      links = world.links().items.map((l) -> #@# Noisy
        if ((l.directed and l.end1 == me and l.end2 == other and isSource) or (l.directed and l.end1 == other and l.end2 == me and !isSource))
          l
        else
          null).filter((o) -> o != null)
    else
      throw new NetLogoException("LINKS is a directed breed.") if world.unbreededLinksAreDirected
      links = world.links().items.map((l) ->
        if ((!l.directed and l.end1 == me and l.end2 == other) or (!l.directed and l.end2 == me and l.end1 == other))
          l
        else
          null).filter((o) -> o != null)
    if links.length == 0 then Nobody else links[0] #@# Code above is, thus, lame

  otherEnd: -> if this == AgentSet.myself().end1 then AgentSet.myself().end2 else AgentSet.myself().end1
  patchRightAndAhead: (angle, amount) ->
    heading = @heading + angle #@# Mutation is for bad people
    if (heading < 0 || heading >= 360) #@# Use cool comparator style
      heading = ((heading % 360) + 360) % 360
    try
      newX = world.topology().wrapX(@xcor() + amount * Trig.sin(heading))
      newY = world.topology().wrapY(@ycor() + amount * Trig.cos(heading))
      return world.getPatchAt(newX, newY) #@# Unnecessary `return`
    catch error
      if error instanceof TopologyInterrupt then Nobody else throw error
  patchLeftAndAhead: (angle, amount) ->
    @patchRightAndAhead(-angle, amount)
  patchAhead: (amount) ->
    @patchRightAndAhead(0, amount)
  fd: (amount) ->
    if amount > 0
      while amount >= 1 and @jump(1) #@# Possible point of improvement
        amount -= 1
      @jump(amount)
    else if amount < 0
      while amount <= -1 and @jump(-1)
        amount += 1
      @jump(amount)
    return
  jump: (amount) ->
    if @canMove(amount)
      @setXcor(@xcor() + amount * Trig.sin(@heading))
      @setYcor(@ycor() + amount * Trig.cos(@heading))
      updated(this, "xcor", "ycor")
      return true
    return false #@# Orly?
  dx: ->
    Trig.sin(@heading)
  dy: ->
    Trig.cos(@heading)
  right: (amount) ->
    @heading += amount
    @keepHeadingInRange()
    updated(this, "heading") #@# Why do all of these function calls manage updates for themselves?  Why am I dreaming of an `Updater` monad?
    return
  setXY: (x, y) ->
    origXcor = @xcor()
    origYcor = @ycor()
    try
      @setXcor(x)
      @setYcor(y)
    catch error
      @setXcor(origXcor)
      @setYcor(origYcor)
      if error instanceof TopologyInterrupt
        throw new TopologyInterrupt("The point [ #{x} , #{y} ] is outside of the boundaries of the world and wrapping is not permitted in one or both directions.")
      else
        throw error
    updated(this, "xcor", "ycor")
    return
  hideTurtle: (flag) -> #@# Varname
    @hidden = flag
    updated(this, "hidden")
    return
  isBreed: (breedName) ->
    @breed.name.toUpperCase() == breedName.toUpperCase()
  die: ->
    @breed.remove(@)
    if (@id != -1)
      world.removeTurtle(@id)
      died(this)
      for l in world.links().items
        try
          l.die() if (l.end1.id == @id or l.end2.id == @id)
        catch error
          throw error if !(error instanceof DeathInterrupt)
      @id = -1
      @getPatchHere().leave(this)
    throw new DeathInterrupt("Call only from inside an askAgent block")
  getTurtleVariable: (n) -> #@# Obviously, we're awful people and this can be improved
    if (n < turtleBuiltins.length)
      if(n == 3) #xcor
        @xcor()
      else if(n == 4) #ycor
        @ycor()
      else if(n == 8) #breed
        world.turtlesOfBreed(@breed.name) #@# Seems weird that I should need to do this...?
      else
        this[turtleBuiltins[n]]
    else
      @vars[n - turtleBuiltins.length]
  setTurtleVariable: (n, v) -> #@# Here we go again!
    if (n < turtleBuiltins.length)
      if n is 1 # color
        this[turtleBuiltins[n]] = ColorModel.wrapColor(v)
      else if(n == 3) #xcor
        @setXcor(v)
      else if(n == 4) #ycor
        @setYcor(v)
      else
        if (n == 5)  # shape
          v = v.toLowerCase()
        this[turtleBuiltins[n]] = v
        if (n == 2)  # heading
          @keepHeadingInRange()
      updated(this, turtleBuiltins[n])
    else
      @vars[n - turtleBuiltins.length] = v
  getBreedVariable: (n) -> @breedVars[n]
  setBreedVariable: (n, v) -> @breedVars[n] = v
  getPatchHere: -> world.getPatchAt(@xcor(), @ycor())
  getPatchVariable: (n)    -> @getPatchHere().getPatchVariable(n)
  setPatchVariable: (n, v) -> @getPatchHere().setPatchVariable(n, v)
  getNeighbors: -> @getPatchHere().getNeighbors()
  getNeighbors4: -> @getPatchHere().getNeighbors4()
  turtlesHere: -> @getPatchHere().turtlesHere()
  breedHere: (breedName) -> @getPatchHere().breedHere(breedName)
  hatch: (n, breedName) ->
    breed = if breedName then Breeds.get(breedName) else @breed
    newTurtles = [] #@# Functional style or GTFO
    if n > 0
      for num in [0...n] #@# Nice unused variable; Lodash it!
        t = new Turtle(@color, @heading, @xcor(), @ycor(), breed, @label, @labelcolor, @hidden, @size, @pensize, @penmode) #@# Sounds like we ought have some cloning system
        for v in [0..TurtlesOwn.vars.length]
          t.setTurtleVariable(turtleBuiltins.length + v, @getTurtleVariable(turtleBuiltins.length + v))
        newTurtles.push(world.createTurtle(t))
    new Agents(newTurtles, breed, AgentKind.Turtle)
  moveTo: (agent) ->
    if (agent instanceof Turtle) #@# Checks for `Turtle`ism or `Patch`ism (etc.) should be on some `Agent` object
      @setXY(agent.xcor(), agent.ycor())
    else if(agent instanceof Patch)
      @setXY(agent.pxcor, agent.pycor)
  watchme: ->
    world.watch(this) #@# Nice try; use `@`

  penDown: ->
    @penmode = "down"
    updated(this, "penmode")
    return
  penUp: ->
    @penmode = "up"
    updated(this, "penmode")
    return

  _removeLink: (l) ->
    @_links.splice(@_links.indexOf(l)) #@# Surely there's a more-coherent way to write this

  compare: (x) ->
    if x instanceof Turtle
      Comparator.numericCompare(@id, x.id)
    else
      Comparator.NOT_EQUALS


#@# CanTalkToPatches: { getPatchVariable(Int): Any, setPatchVariable(Int, Any): Unit }
#@# Extends `CanTalkToPatches`, `Agent`, `Vassal`
class Patch
  vars: []
  constructor: (@id, @pxcor, @pycor, @pcolor = 0.0, @plabel = "", @plabelcolor = 9.9) ->
    @vars = (x for x in PatchesOwn.vars) #@# Why put either of these two things in the constructor?
    @turtles = []
  toString: -> "(patch " + @pxcor + " " + @pycor + ")" #@# Interpolate
  getPatchVariable: (n) ->
    if (n < patchBuiltins.length)
      this[patchBuiltins[n]]
    else
      @vars[n - patchBuiltins.length]
  setPatchVariable: (n, v) ->
    if (n < patchBuiltins.length)
      if patchBuiltins[n] is "pcolor"
        newV = ColorModel.wrapColor(v)
        if newV != 0
          world.patchesAllBlack(false)
        this[patchBuiltins[n]] = newV
      else if patchBuiltins[n] is "plabel"
        if v is ""
          if this.plabel isnt ""
            world.patchesWithLabels(world._patchesWithLabels - 1)
        else
          if this.plabel is ""
            world.patchesWithLabels(world._patchesWithLabels + 1)
        this.plabel = v
      else
        this[patchBuiltins[n]] = v
      updated(this, patchBuiltins[n])
    else
      @vars[n - patchBuiltins.length] = v
  leave: (t) -> @turtles.splice(@turtles.indexOf(t, 0), 1) #@# WTF is `t`?
  arrive: (t) -> #@# WTF is `t`?
    @turtles.push(t)
  distanceXY: (x, y) -> world.topology().distanceXY(@pxcor, @pycor, x, y)
  towardsXY: (x, y) -> world.topology().towards(@pxcor, @pycor, x, y)
  distance: (agent) -> world.topology().distance(@pxcor, @pycor, agent)
  turtlesHere: -> new Agents(@turtles[..], Breeds.get("TURTLES"), AgentKind.Turtle) #@# What do the two dots even mean here...?
  getNeighbors: -> world.getNeighbors(@pxcor, @pycor) # world.getTopology().getNeighbors(this) #@# I _love_ commented-out code!
  getNeighbors4: -> world.getNeighbors4(@pxcor, @pycor) # world.getTopology().getNeighbors(this)
  sprout: (n, breedName) ->
    breed = if("" == breedName) then Breeds.get("TURTLES") else Breeds.get(breedName) #@# This conditional is begging for a bug
    newTurtles = []
    if n > 0
      for num in [0...n]
        newTurtles.push(world.createTurtle(new Turtle(5 + 10 * Random.nextInt(14), Random.nextInt(360), @pxcor, @pycor, breed))) #@# Moar clarity, plox
    new Agents(newTurtles, breed, AgentKind.Turtle)
  breedHere: (breedName) ->
    breed = Breeds.get(breedName)
    new Agents(t for t in @turtles when t.breed == breed, breed, AgentKind.Turtle) #@# Just use Lodash, you jackalope
  turtlesAt: (dx, dy) ->
    @patchAt(dx, dy).turtlesHere()
  patchAt: (dx, dy) ->
    try
      newX = world.topology().wrapX(@pxcor + dx)
      newY = world.topology().wrapY(@pycor + dy)
      return world.getPatchAt(newX, newY) #@# Unnecessary `return`
    catch error
      if error instanceof TopologyInterrupt then Nobody else throw error
  watchme: ->
    world.watch(this) #@# `@`

  inRadius: (agents, radius) ->
    world.topology().inRadius(this, @pxcor, @pycor, agents, radius)

  compare: (x) ->
    Comparator.numericCompare(@id, x.id)


Links =
  compare: (a, b) -> #@# Heinous
    if (a == b)
      0
    else if a.id is -1 and b.id is -1
      0
    else if(a.end1.id < b.end1.id)
      -1
    else if(a.end1.id > b.end1.id)
      1
    else if(a.end2.id < b.end2.id)
      -1
    else if(a.end2.id > b.end2.id)
      1
    else if(a.breed == b.breed)
      0
    else if(a.breed == Breeds.get("LINKS"))
      -1
    else if(b.breed == Breeds.get("LINKS"))
      1
    else
      throw new Error("We have yet to implement link breed comparison")

class Link
  vars: []
  color: 5
  label: ""
  labelcolor: 9.9
  hidden: false
  shape: "default"
  thickness: 0
  tiemode: "none"
  xcor: -> #@# WHAT?! x2
  ycor: ->
  constructor: (@id, @directed, @end1, @end2) ->
    @breed = Breeds.get("LINKS")
    @breed.add(@)
    @end1._links.push(this)
    @end2._links.push(this)
    @updateEndRelatedVars()
    @vars = (x for x in LinksOwn.vars)
  getLinkVariable: (n) ->
    if (n < linkBuiltins.length)
      this[linkBuiltins[n]]
    else
      @vars[n - linkBuiltins.length]
  setLinkVariable: (n, v) ->
    if (n < linkBuiltins.length)
      newV =
        if linkBuiltins[n] is "lcolor"
          ColorModel.wrapColor(v)
        else
          v
      this[linkBuiltins[n]] = newV
      updated(this, linkBuiltins[n])
    else
      @vars[n - linkBuiltins.length] = v
  die: ->
    @breed.remove(@)
    if (@id != -1)
      @end1._removeLink(this)
      @end2._removeLink(this)
      world.removeLink(@id)
      died(this)
      @id = -1
    throw new DeathInterrupt("Call only from inside an askAgent block")
  getTurtleVariable: (n) -> this[turtleBuiltins[n]]
  setTurtleVariable: (n, v) ->
    newV =
      if turtleBuiltins[n] is "color"
        ColorModel.wrapColor(v)
      else
        v
    this[turtleBuiltins[n]] = newV
    updated(this, turtleBuiltins[n])
  bothEnds: -> new Agents([@end1, @end2], Breeds.get("TURTLES"), AgentKind.Turtle)
  otherEnd: -> if @end1 == AgentSet.myself() then @end2 else @end1
  updateEndRelatedVars: ->
    @heading = world.topology().towards(@end1.xcor(), @end1.ycor(), @end2.xcor(), @end2.ycor())
    @size = world.topology().distanceXY(@end1.xcor(), @end1.ycor(), @end2.xcor(), @end2.ycor())
    @midpointx = world.topology().midpointx(@end1.xcor(), @end2.xcor())
    @midpointy = world.topology().midpointy(@end1.ycor(), @end2.ycor())
    updated(this, linkExtras...)
  toString: -> "(" + @breed.singular + " " + @end1.id + " " + @end2.id + ")" #@# Interpolate

  compare: (x) -> #@# Unify with `Links.compare`
    switch Links.compare(this, x)
      when -1 then Comparator.LESS_THAN
      when  0 then Comparator.EQUALS
      when  1 then Comparator.GREATER_THAN
      else throw new Exception("Boom")


class WorldLinks

  _links: mori.sorted_set_by(Links.compare)

  # Side-effecting ops
  insert: (l)    -> @_links = mori.conj(@_links, l); this
  remove: (link) -> @_links = mori.disj(@_links, link); this

  # Pure ops
  find:   (pred) -> mori.first(mori.filter(pred, @_links)) # Mori's `filter` is lazy, so it's all cool --JAB (3/26/14)
  isEmpty:       -> mori.is_empty(@_links)
  toArray:       -> mori.clj_to_js(@_links)


class World

  # any variables used in the constructor should come
  # before the constructor, else they get overwritten after it.
  _nextLinkId: 0
  _nextTurtleId: 0
  _turtles: []
  _turtlesById: {}
  _patches: []
  _links: new WorldLinks()
  _topology: null
  _ticks: -1
  _timer: Date.now()
  _patchesAllBlack: true
  _patchesWithLabels: 0

  constructor: (@minPxcor, @maxPxcor, @minPycor, @maxPycor, @patchSize, @wrappingAllowedInX, @wrappingAllowedInY, turtleShapeList, linkShapeList, @interfaceGlobalCount) ->
    Breeds.reset()
    AgentSet.reset()
    @perspective = 0 #@# Out of constructor
    @targetAgent = null #@# Out of constructor
    collectUpdates()
    Updates.push(
      {
        world: {
          0: {
            worldWidth: Math.abs(@minPxcor - @maxPxcor) + 1,
            worldHeight: Math.abs(@minPycor - @maxPycor) + 1,
            minPxcor: @minPxcor,
            minPycor: @minPycor,
            maxPxcor: @maxPxcor,
            maxPycor: @maxPycor,
            linkBreeds: "XXX IMPLEMENT ME",
            linkShapeList: linkShapeList,
            patchSize: @patchSize,
            patchesAllBlack: @_patchesAllBlack,
            patchesWithLabels: @_patchesWithLabels
            ticks: @_ticks,
            turtleBreeds: "XXX IMPLEMENT ME",
            turtleShapeList: turtleShapeList,
            unbreededLinksAreDirected: false
            wrappingAllowedInX: @wrappingAllowedInX,
            wrappingAllowedInY: @wrappingAllowedInY
          }
        }
      })
    @updatePerspective()
    @resize(@minPxcor, @maxPxcor, @minPycor, @maxPycor)
  createPatches: ->
    nested =
      for y in [@maxPycor..@minPycor] #@# Just build the damn matrix
        for x in [@minPxcor..@maxPxcor]
          new Patch((@width() * (@maxPycor - y)) + x - @minPxcor, x, y)
    # http://stackoverflow.com/questions/4631525/concatenating-an-array-of-arrays-in-coffeescript
    @_patches = [].concat nested... #@# I don't know what this mean, nor what that comment above is, so it's automatically awful
    for p in @_patches
      updated(p, "pxcor", "pycor", "pcolor", "plabel", "plabelcolor")
  topology: -> @_topology
  links: () ->
    new Agents(@_links.toArray(), Breeds.get("LINKS"), AgentKind.Link) #@# How about we just provide `LinkSet`, `PatchSet`, and `TurtleSet` as shorthand with intelligent defaults?
  turtles: () -> new Agents(@_turtles, Breeds.get("TURTLES"), AgentKind.Turtle)
  turtlesOfBreed: (breedName) ->
    breed = Breeds.get(breedName)
    new Agents(breed.members, breed, AgentKind.Turtle)
  patches: -> new Agents(@_patches, Breeds.get("PATCHES"), AgentKind.Patch)
  resetTimer: ->
    @_timer = Date.now()
  resetTicks: ->
    @_ticks = 0
    Updates.push( world: { 0: { ticks: @_ticks } } ) #@# The fact that `Updates.push` is ever done manually seems fundamentally wrong to me
  clearTicks: ->
    @_ticks = -1
    Updates.push( world: { 0: { ticks: @_ticks } } )
  resize: (minPxcor, maxPxcor, minPycor, maxPycor) ->

    if(minPxcor > 0 || maxPxcor < 0 || minPycor > 0 || maxPycor < 0)
      throw new NetLogoException("You must include the point (0, 0) in the world.")

    # For some reason, JVM NetLogo doesn't restart `who` ordering after `resize-world`; even the test for this is existentially confused. --JAB (4/3/14)
    oldNextTId = @_nextTurtleId
    @clearTurtles()
    @_nextTurtleId = oldNextTId

    @minPxcor = minPxcor
    @maxPxcor = maxPxcor
    @minPycor = minPycor
    @maxPycor = maxPycor
    if(@wrappingAllowedInX && @wrappingAllowedInY)
      @_topology = new Torus(@minPxcor, @maxPxcor, @minPycor, @maxPycor) #@# FP a-go-go
    else if(@wrappingAllowedInX)
      @_topology = new VertCylinder(@minPxcor, @maxPxcor, @minPycor, @maxPycor)
    else if(@wrappingAllowedInY)
      @_topology = new HorzCylinder(@minPxcor, @maxPxcor, @minPycor, @maxPycor)
    else
      @_topology = new Box(@minPxcor, @maxPxcor, @minPycor, @maxPycor)
    @createPatches()
    @patchesAllBlack(true)
    @patchesWithLabels(0)
    Updates.push(
      world: {
        0: {
          worldWidth: Math.abs(@minPxcor - @maxPxcor) + 1,
          worldHeight: Math.abs(@minPycor - @maxPycor) + 1,
          minPxcor: @minPxcor,
          minPycor: @minPycor,
          maxPxcor: @maxPxcor,
          maxPycor: @maxPycor
        }
      }
    )
    return

  tick: ->
    if(@_ticks == -1)
      throw new NetLogoException("The tick counter has not been started yet. Use RESET-TICKS.")
    @_ticks++
    Updates.push( world: { 0: { ticks: @_ticks } } )
  tickAdvance: (n) ->
    if(@_ticks == -1)
      throw new NetLogoException("The tick counter has not been started yet. Use RESET-TICKS.")
    if(n < 0)
      throw new NetLogoException("Cannot advance the tick counter by a negative amount.")
    @_ticks += n
    Updates.push( world: { 0: { ticks: @_ticks } } )
  timer: ->
    (Date.now() - @_timer) / 1000
  ticks: ->
    if(@_ticks == -1)
      throw new NetLogoException("The tick counter has not been started yet. Use RESET-TICKS.")
    @_ticks
  # TODO: this needs to support all topologies
  width: () -> 1 + @maxPxcor - @minPxcor
  height: () -> 1 + @maxPycor - @minPycor
  getPatchAt: (x, y) ->
    trueX  = (x - @minPxcor) % @width()  + @minPxcor # Handle negative coordinates and wrapping
    trueY  = (y - @minPycor) % @height() + @minPycor
    index  = (@maxPycor - StrictMath.round(trueY)) * @width() + (StrictMath.round(trueX) - @minPxcor)
    @_patches[index]
  getTurtle: (id) -> @_turtlesById[id] or Nobody
  getTurtleOfBreed: (breedName, id) ->
    turtle = @getTurtle(id)
    if turtle.breed.name.toUpperCase() == breedName.toUpperCase() then turtle else Nobody
  removeLink: (id) ->
    link = @_links.find((l) -> l.id is id)
    @_links = @_links.remove(link)
    if @_links.isEmpty()
      @unbreededLinksAreDirected = false
      Updates.push({ world: { 0: { unbreededLinksAreDirected: false } } })
    return
  removeTurtle: (id) -> #@# Having two different collections of turtles to manage seems avoidable
    turtle = @_turtlesById[id]
    @_turtles.splice(@_turtles.indexOf(turtle), 1)
    delete @_turtlesById[id]
  patchesAllBlack: (val) -> #@# Varname
    @_patchesAllBlack = val
    Updates.push( world: { 0: { patchesAllBlack: @_patchesAllBlack }})
  patchesWithLabels: (val) ->
    @_patchesWithLabels = val
    Updates.push( world: { 0: { patchesWithLabels: @_patchesWithLabels }})
  clearAll: ->
    Globals.clear(@interfaceGlobalCount)
    @clearTurtles()
    @createPatches()
    @_nextLinkId = 0
    @patchesAllBlack(true)
    @patchesWithLabels(0)
    @clearTicks()
    return
  clearTurtles: ->
    # We iterate through a copy of the array since it will be modified during
    # iteration.
    # A more efficient (but less readable) way of doing this is to iterate
    # backwards through the array.
    #@# I don't know what you're blathering about, but if it needs this comment, it can probably be written better
    for t in @turtles().items[..]
      try
        t.die()
      catch error
        throw error if !(error instanceof DeathInterrupt)
    @_nextTurtleId = 0
    return
  clearPatches: ->
    for p in @patches().items #@# Oh, yeah?
      p.setPatchVariable(2, 0)   # 2 = pcolor
      p.setPatchVariable(3, "")    # 3 = plabel
      p.setPatchVariable(4, 9.9)   # 4 = plabel-color
      for i in [patchBuiltins.size...p.vars.length]
        p.setPatchVariable(i, 0)
    @patchesAllBlack(true)
    @patchesWithLabels(0)
    return
  createTurtle: (t) ->
    t.id = @_nextTurtleId++ #@# Why are we managing IDs at this level of the code?
    updated(t, turtleBuiltins...)
    @_turtles.push(t)
    @_turtlesById[t.id] = t
    t
  ###
  #@# We shouldn't be looking up links in the tree everytime we create a link; JVM NL uses 2 `LinkedHashMap[Turtle, Buffer[Link]]`s (to, from) --JAB (2/7/14)
  #@# The return of `Nobody` followed by clients `filter`ing against it screams "flatMap!" --JAB (2/7/14)
  ###
  createLink: (directed, from, to) ->
    if(from.id < to.id or directed) #@# FP FTW
      end1 = from
      end2 = to
    else
      end1 = to
      end2 = from
    if Nobody == @getLink(end1.id, end2.id)
      l = new Link(@_nextLinkId++, directed, end1, end2) #@# Managing IDs for yourself!
      updated(l, linkBuiltins...)
      updated(l, linkExtras...)
      updated(l, turtleBuiltins.slice(1)...) #@# See, this update nonsense is awful
      @_links.insert(l)
      l
    else
      Nobody
  createOrderedTurtles: (n, breedName) -> #@# Clarity is a good thing
    newTurtles = []
    if n > 0
      for num in [0...n]
        newTurtles.push(@createTurtle(new Turtle((10 * num + 5) % 140, (360 * num) / n, 0, 0, Breeds.get(breedName))))
    new Agents(newTurtles, Breeds.get(breedName), AgentKind.Turtle)
  createTurtles: (n, breedName) -> #@# Clarity is still good
    newTurtles = []
    if n > 0
      for num in [0...n]
        newTurtles.push(@createTurtle(new Turtle(5 + 10 * Random.nextInt(14), Random.nextInt(360), 0, 0, Breeds.get(breedName))))
    new Agents(newTurtles, Breeds.get(breedName), AgentKind.Turtle)
  getNeighbors: (pxcor, pycor) -> @topology().getNeighbors(pxcor, pycor)
  getNeighbors4: (pxcor, pycor) -> @topology().getNeighbors4(pxcor, pycor)
  createDirectedLink: (from, to) ->
    @unbreededLinksAreDirected = true
    Updates.push({ world: { 0: { unbreededLinksAreDirected: true } } })
    @createLink(true, from, to)
  createDirectedLinks: (source, others) -> #@# Clarity
    @unbreededLinksAreDirected = true
    Updates.push({ world: { 0: { unbreededLinksAreDirected: true } } })
    new Agents((@createLink(true, source, t) for t in others.items).filter((o) -> o != Nobody), Breeds.get("LINKS"), AgentKind.Link)
  createReverseDirectedLinks: (source, others) -> #@# Clarity
    @unbreededLinksAreDirected = true
    Updates.push({ world: { 0: { unbreededLinksAreDirected: true } } })
    new Agents((@createLink(true, t, source) for t in others.items).filter((o) -> o != Nobody), Breeds.get("LINKS"), AgentKind.Link)
  createUndirectedLink: (source, other) ->
    @createLink(false, source, other)
  createUndirectedLinks: (source, others) -> #@# Clarity
    new Agents((@createLink(false, source, t) for t in others.items).filter((o) -> o != Nobody), Breeds.get("LINKS"), AgentKind.Link)
  getLink: (fromId, toId) ->
    link = @_links.find((l) -> l.end1.id is fromId and l.end2.id is toId)
    if link?
      link
    else
      Nobody
  updatePerspective: ->
    Updates.push({ observer: { 0: { perspective: @perspective, targetAgent: @targetAgent } } })
  watch: (agent) ->
    @perspective = 3
    agentKind = 0
    agentId = -1
    if(agent instanceof Turtle)
      agentKind = 1
      agentId = agent.id
    else if(agent instanceof Patch)
      agentKind = 2
      agentId = agent.id
    @targetAgent = [agentKind, agentId]
    @updatePerspective()
  resetPerspective: ->
    @perspective = 0
    @targetAgent = null
    @updatePerspective()

# Some things are in AgentSet, others in Prims.  The distinction seems
# arbitrary/confusing.  May we should put *everything* in Prims, and
# Agents can be private.  Prims could/would/should be the
# compiler/runtime interface.  Dunno what's best.
#@# End this fence-riding nonsense ASAP

#@# Should be unified with `Agents`
AgentSet =
  count: (x) -> x.items.length
  any: (x) -> x.items.length > 0
  all: (x, f) ->
    for a in x.items #@# Lodash
      if(!@askAgent(a, f))
        return false
    true
  _self: 0 #@# Lame
  _myself: 0 #@# Lame, only used by a tiny subset of this class
  reset: ->
    @_self = 0
    @_myself = 0
  self: -> @_self
  myself: -> if @_myself != 0 then @_myself else throw new NetLogoException("There is no agent for MYSELF to refer to.") #@# I wouldn't be surprised if this is entirely avoidable
  askAgent: (a, f) -> #@# Varnames
    oldMyself = @_myself #@# All of this contextual swapping can be handled more clearly
    oldAgent = @_self
    @_myself = @_self
    @_self = a
    try
      res = f() #@# FP
    catch error
      throw error if!(error instanceof DeathInterrupt or error instanceof StopInterrupt)
    @_self = oldAgent
    @_myself = oldMyself
    res
  ask: (agentsOrAgent, shuffle, f) ->
    if(agentsOrAgent.items) #@# FP
      agents = agentsOrAgent.items
    else
      agents = [agentsOrAgent]
    iter =
      if (shuffle) #@# Fix yo' varnames, son!
        new Shufflerator(agents)
      else
        new Iterator(agents)
    while (iter.hasNext()) #@# Srsly?  Is this Java 1.4?
      a = iter.next()
      @askAgent(a, f)
    # If an asker indirectly commits suicide, the exception should propagate.  FD 11/1/2013
    if(@_self.id && @_self.id == -1) #@# Improve
      throw new DeathInterrupt
    return
  # can't call it `with`, that's taken in JavaScript. so is `filter` - ST 2/19/14
  #@# Above comment seems bogus.  Since when can you not do something in JavaScript?
  agentFilter: (agents, f) -> new Agents(a for a in agents.items when @askAgent(a, f), agents.breed, agents.kind)
  # min/MaxOneOf are copy/pasted from each other.  hard to say whether
  # DRY-ing them would be worth the possible performance impact. - ST 3/17/14
  #@# I concur; generalize this!
  maxOneOf: (agents, f) ->
   winningValue = -Number.MAX_VALUE
   winners = []
   for a in agents.items #@# I'm not sure how, but surely this can be Lodash-ified
     result = @askAgent(a, f)
     if result >= winningValue
       if result > winningValue
         winningValue = result
         winners = []
       winners.push(a)
   if winners.length == 0 #@# Nice try
     Nobody
   else
     winners[Random.nextInt(winners.length)]
  minOneOf: (agents, f) ->
   winningValue = Number.MAX_VALUE
   winners = []
   for a in agents.items
     result = @askAgent(a, f)
     if result <= winningValue
       if result < winningValue
         winningValue = result
         winners = []
       winners.push(a)
   if winners.length == 0
     Nobody
   else
     winners[Random.nextInt(winners.length)]
  of: (agentsOrAgent, f) -> #@# This is nonsense; same with `ask`.  If you're giving me something, _you_ get it into the right type first, not me!
    isagentset = agentsOrAgent.items #@# Existential check!  Come on!
    if(isagentset)
      agents = agentsOrAgent.items
    else
      agents = [agentsOrAgent]
    result = []
    iter = new Shufflerator(agents)
    while (iter.hasNext()) #@# FP.  Also, move out of the 1990s.
      a = iter.next()
      result.push(@askAgent(a, f))
    if isagentset
      result
    else
      result[0]
  oneOf: (agentsOrList) ->
    isagentset = agentsOrList.items #@# Stop this nonsense
    if(isagentset)
      l = agentsOrList.items
    else
      l = agentsOrList
    if l.length == 0 then Nobody else l[Random.nextInt(l.length)] #@# Sadness continues
  nOf: (resultSize, agentsOrList) ->
    items = agentsOrList.items #@# Existential
    if(!items)
      throw new Error("n-of not implemented on lists yet")
    new Agents( #@# Oh, FFS
      switch resultSize
        when 0
          []
        when 1
          [items[Random.nextInt(items.length)]]
        when 2
          index1 = Random.nextInt(items.length)
          index2 = Random.nextInt(items.length - 1)
          [index1, index2] = #@# Why, why, why?
            if index2 >= index1
              [index1, index2 + 1]
            else
              [index2, index1]
          [items[index1], items[index2]]
        else
          i = 0
          j = 0
          result = []
          while j < resultSize #@# Lodash it!  And why not just use the general case?
            if Random.nextInt(items.length - i) < resultSize - j
              result.push(items[i])
              j += 1
            i += 1
          result
    , agentsOrList.breed, agentsOrList.kind)
  turtlesOn: (agentsOrAgent) ->
    if(agentsOrAgent.items) #@# FP
      agents = agentsOrAgent.items
    else
      agents = [agentsOrAgent]
    turtles = [].concat (agent.turtlesHere().items for agent in agents)... #@# I don't know what's going on here, so it's probably wrong
    new Agents(turtles, Breeds.get("TURTLES"), AgentKind.Turtle)
  die: -> @_self.die()
  connectedLinks: (directed, isSource) -> @_self.connectedLinks(directed, isSource)
  linkNeighbors: (directed, isSource) -> @_self.linkNeighbors(directed, isSource)
  isLinkNeighbor: (directed, isSource) ->
    t = @_self #@# Why bother...?
    ((other) -> t.isLinkNeighbor(directed, isSource, other))
  findLinkViaNeighbor: (directed, isSource) ->
    t = @_self #@# Why bother...?
    ((other) -> t.findLinkViaNeighbor(directed, isSource, other))
  getTurtleVariable: (n)    -> @_self.getTurtleVariable(n)
  setTurtleVariable: (n, v) -> @_self.setTurtleVariable(n, v)
  getLinkVariable: (n)    -> @_self.getLinkVariable(n)
  setLinkVariable: (n, v) -> @_self.setLinkVariable(n, v)
  getBreedVariable: (n)    -> @_self.getBreedVariable(n)
  setBreedVariable: (n, v) -> @_self.setBreedVariable(n, v)
  setBreed: (agentSet) -> @_self.setBreed(agentSet.breed)
  getPatchVariable:  (n)    -> @_self.getPatchVariable(n)
  setPatchVariable:  (n, v) -> @_self.setPatchVariable(n, v)
  createLinkFrom: (other) -> world.createDirectedLink(other, @_self)
  createLinksFrom: (others) -> world.createReverseDirectedLinks(@_self, @shuffle(others))
  createLinkTo: (other) -> world.createDirectedLink(@_self, other)
  createLinksTo: (others) -> world.createDirectedLinks(@_self, @shuffle(others))
  createLinkWith: (other) -> world.createUndirectedLink(@_self, other)
  createLinksWith: (others) -> world.createUndirectedLinks(@_self, @shuffle(others))
  other: (agentSet) ->
    self = @_self
    filteredAgents = (agentSet.items.filter((o) -> o != self)) #@# Unnecessary parens everywhere!
    new Agents(filteredAgents, agentSet.breed, agentSet.kind)
  shuffle: (agents) ->
    result = []
    iter = new Shufflerator(agents.items)
    while (iter.hasNext()) #@# 1990 rears its ugly head again
      result.push(iter.next())
    new Agents(result, agents.breed, agents.kind)

#@# I hate this class's name and insist that it changes, hopefully getting rolled in with `AgentSet`
class Agents
  constructor: (@items, @breed, @kind) ->
  toString: ->
    "(agentset, #{@items.length} #{@breed.name.toLowerCase()})"
  sort: ->
    if(@items.length == 0) #@# Lodash
      @items
    else if @kind is AgentKind.Turtle or @kind is AgentKind.Patch #@# Unify
      @items[..].sort((x, y) -> x.compare(y).toInt)
    else if @kind is AgentKind.Link
      @items[..].sort(Links.compare)
    else
      throw new Error("We don't know how to sort your kind here!")

#@# Why you so puny?  Why you exist?
class Iterator
  constructor: (@agents) ->
    @agents = @agents[..]
    @i = 0
  hasNext: -> @i < @agents.length
  next: ->
    result = @agents[@i]
    @i = @i + 1
    result

#@# Lame
class Shufflerator
  constructor: (@agents) ->
    @agents = @agents[..]
    @fetch()
  i: 0
  nextOne: null
  hasNext: -> @nextOne != null
  next: ->
    result = @nextOne
    @fetch()
    result
  fetch: ->
    if (@i >= @agents.length)
      @nextOne = null
    else
      if (@i < @agents.length - 1)
        r = @i + Random.nextInt(@agents.length - @i)
        @nextOne = @agents[r]
        @agents[r] = @agents[@i]
      else
        @nextOne = @agents[@i]
      @i = @i + 1 #@# It's called "@i++"
    return

#@# No more code golf
Prims =
  fd: (n) -> AgentSet.self().fd(n)
  bk: (n) -> AgentSet.self().fd(-n)
  jump: (n) -> AgentSet.self().jump(n)
  right: (n) -> AgentSet.self().right(n)
  left: (n) -> AgentSet.self().right(-n)
  setXY: (x, y) -> AgentSet.self().setXY(x, y)
  empty: (l) -> l.length == 0 #@# Seems wrong
  getNeighbors: -> AgentSet.self().getNeighbors()
  getNeighbors4: -> AgentSet.self().getNeighbors4()
  sprout: (n, breedName) -> AgentSet.self().sprout(n, breedName)
  hatch: (n, breedName) -> AgentSet.self().hatch(n, breedName)
  patch: (x, y) -> world.getPatchAt(x, y)
  randomXcor: -> world.minPxcor - 0.5 + Random.nextDouble() * (world.maxPxcor - world.minPxcor + 1)
  randomYcor: -> world.minPycor - 0.5 + Random.nextDouble() * (world.maxPycor - world.minPycor + 1)
  shadeOf: (c1, c2) -> Math.floor(c1 / 10) == Math.floor(c2 / 10) #@# Varnames
  isBreed: (breedName, x) -> if x.isBreed? and x.id != -1 then x.isBreed(breedName) else false
  equality: (a, b) -> #@# This is a cesspool for performance problems
    if a is undefined or b is undefined
      throw new Error("Checking equality on undefined is an invalid condition")

    (a is b) or ( # This code has been purposely rewritten into a crude, optimized form --JAB (3/19/14)
      if typeIsArray(a) and typeIsArray(b)
        a.length == b.length && a.every((elem, i) -> Prims.equality(elem, b[i]))
      else if (a instanceof Agents && b instanceof Agents) #@# Could be sped up to O(n) (from O(n^2)) by zipping the two arrays
        a.items.length is b.items.length and a.kind is b.kind and a.items.every((elem) -> (elem in b.items))
      else
        (a instanceof Agents and a.breed is b) or (b instanceof Agents and b.breed is a) or
          (a is Nobody and b.id is -1) or (b is Nobody and a.id is -1) or ((a instanceof Turtle or a instanceof Link) and a.compare(b) is Comparator.EQUALS)
    )

  lt: (a, b) -> #@# Bad, bad Jason
    if (Utilities.isString(a) and Utilities.isString(b)) or (Utilities.isNumber(a) and Utilities.isNumber(b))
      a < b
    else if typeof(a) is typeof(b) and a.compare? and b.compare? #@# Use a class
      a.compare(b) is Comparator.LESS_THAN
    else
      throw new Exception("Invalid operands to `lt`")

  gt: (a, b) -> #@# Jason is still bad
    if (Utilities.isString(a) and Utilities.isString(b)) or (Utilities.isNumber(a) and Utilities.isNumber(b))
      a > b
    else if typeof(a) is typeof(b) and a.compare? and b.compare? #@# Use a class
      a.compare(b) is Comparator.GREATER_THAN
    else
      throw new Exception("Invalid operands to `gt`")

  lte: (a, b) -> @lt(a, b) or @equality(a, b)
  gte: (a, b) -> @gt(a, b) or @equality(a, b)
  scaleColor: (color, number, min, max) -> #@# I don't know WTF this is, so it has to be wrong
    color = Math.floor(color / 10) * 10
    perc = 0.0
    if(min > max)
      if(number < max)
        perc = 1.0
      else if (number > min)
        perc = 0.0
      else
        tempval = min - number
        tempmax = min - max
        perc = tempval / tempmax
    else
      if(number > max)
        perc = 1.0
      else if (number < min)
        perc = 0.0
      else
        tempval = number - min
        tempmax = max - min
        perc = tempval / tempmax
    perc *= 10
    if(perc >= 9.9999)
      perc = 9.9999
    if(perc < 0)
      perc = 0
    color + perc
  random: (n) ->
    truncated =
      if n >= 0
        Math.ceil(n)
      else
        Math.floor(n)
    if truncated == 0
      0
    else if truncated > 0
      Random.nextLong(truncated)
    else
      -Random.nextLong(-truncated)
  randomFloat: (n) -> n * Random.nextDouble()
  list: (xs...) -> xs
  item: (n, xs) -> xs[n]
  first: (xs) -> xs[0]
  last: (xs) -> xs[xs.length - 1]
  fput: (x, xs) -> [x].concat(xs) #@# Lodash, son
  lput: (x, xs) -> #@# Lodash, son
    result = xs[..]
    result.push(x)
    result
  butFirst: (xs) -> xs[1..] #@# Lodash
  butLast: (xs) -> xs[0...xs.length - 1] #@# Lodash
  length: (xs) -> xs.length #@# Lodash
  _int: (n) -> if n < 0 then Math.ceil(n) else Math.floor(n) #@# WTF is this?
  mod: (a, b) -> ((a % b) + b) % b #@# WTF?
  max: (xs) -> Math.max(xs...) #@# Check Lodash on this
  min: (xs) -> Math.min(xs...) #@# Check Lodash
  mean: (xs) -> @sum(xs) / xs.length #@# Check Lodash
  sum: (xs) -> xs.reduce(((a, b) -> a + b), 0) #@# Check Lodash
  precision: (n, places) ->
    multiplier = Math.pow(10, places)
    result = Math.floor(n * multiplier + .5) / multiplier
    if places > 0
      result
    else
      Math.round(result) #@# Huh?
  reverse: (xs) -> #@# Lodash
    if typeIsArray(xs)
      xs[..].reverse()
    else if typeof(xs) == "string"
      xs.split("").reverse().join("")
    else
      throw new NetLogoException("can only reverse lists and strings")
  sort: (xs) -> #@# Seems greatly improvable
    if typeIsArray(xs)
      wrappedItems = _(xs)
      if wrappedItems.isEmpty()
        xs
      else if wrappedItems.all((x) -> Utilities.isNumber(x))
        xs[..].sort((x, y) -> Comparator.numericCompare(x, y).toInt)
      else if wrappedItems.all((x) -> Utilities.isString(x))
        xs[..].sort()
      else if wrappedItems.all((x) -> x instanceof Turtle) or wrappedItems.all((x) -> x instanceof Patch)
        xs[..].sort((x, y) -> x.compare(y).toInt)
      else if wrappedItems.all((x) -> x instanceof Link)
        xs[..].sort(Links.compare)
      else
        throw new Error("We don't know how to sort your kind here!")
    else if xs instanceof Agents
      xs.sort()
    else
      throw new NetLogoException("can only sort lists and agentsets")
  removeDuplicates: (xs) -> #@# Good use of data structures and actually trying could get this into reasonable time complexity
    if xs.length < 2
      xs
    else
      xs.filter(
        (elem, pos) -> not _(xs.slice(0, pos)).some((x) -> Prims.equality(x, elem))
      )
  outputPrint: (x) ->
    println(Dump(x))
  patchSet: (inputs...) ->
    #@# O(n^2) -- should be smarter (use hashing for contains check)
    result = []
    recurse = (inputs) ->
      for input in inputs
        if (typeIsArray(input))
          recurse(input)
        else if (input instanceof Patch)
          result.push(input)
        else if input != Nobody
          for agent in input.items
            if (!(agent in result))
              result.push(agent)
    recurse(inputs)
    new Agents(result, undefined, AgentKind.Patch) #@# A great example of why we should have a `PatchSet`
  repeat: (n, fn) ->
    for i in [0...n] #@# Unused variable, which is lame
      fn()
    return
  # not a real implementation, always just runs body - ST 4/22/14
  every: (time, fn) ->
    fn()
    return
  subtractHeadings: (h1, h2) ->
    if h1 < 0 || h1 >= 360
      h1 = (h1 % 360 + 360) % 360
    if h2 < 0 || h2 >= 360
      h2 = (h2 % 360 + 360) % 360
    diff = h1 - h2
    if diff > -180 && diff <= 180
      diff
    else if diff > 0
      diff - 360
    else
      diff + 360
  boom: ->
    throw new NetLogoException("boom!")
  member: (x, xs) ->
    if typeIsArray(xs)
      for y in xs
        if @equality(x, y)
          return true
      false
    else if Utilities.isString(x)
      xs.indexOf(x) != -1
    else  # agentset
      for a in xs.items
        if x == a
          return true
      false
  position: (x, xs) ->
    if typeIsArray(xs)
      for y, i in xs
        if @equality(x, y)
          return i
      false
    else
      result = xs.indexOf(x)
      if result is -1
        false
      else
        result
  remove: (x, xs) ->
    if typeIsArray(xs)
      result = []
      for y in xs
        if not @equality(x, y)
          result.push(y)
      result
    else
      xs.replaceAll(x, "")
  removeItem: (n, xs) ->
    if typeIsArray(xs)
      xs = xs[..]
      xs[n..n] = []
      xs
    else
      xs.slice(0, n) + xs.slice(n + 1, xs.length)
  replaceItem: (n, xs, x) ->
    if typeIsArray(xs)
      xs = xs[..]
      xs[n] = x
      xs
    else
      xs.slice(0, n) + x + xs.slice(n + 1, xs.length)
  sublist: (xs, n1, n2) ->
    xs[n1...n2]
  substring: (xs, n1, n2) ->
    xs.substr(n1, n2 - n1)
  sentence: (xs...) ->
    result = []
    for x in xs
      if typeIsArray(x)
        result.push(x...)
      else
        result.push(x)
    result
  variance: (xs) ->
    sum = 0
    count = xs.length
    for x in xs
      if Utilities.isNumber(x)
        sum += x
      else
        --count
    if count < 2
      throw new NetLogoException(
        "Can't find the variance of a list without at least two numbers")
    mean = sum / count
    squareOfDifference = 0
    for x in xs
      if Utilities.isNumber(x)
        squareOfDifference += StrictMath.pow(x - mean, 2)
    squareOfDifference / (count - 1)
  breedOn: (breedName, what) ->
    breed = Breeds.get(breedName)
    patches =
      if what instanceof Patch
        [what]
      else if what instanceof Turtle
        [what.getPatchHere()]
      else if what.items and what.kind is AgentKind.Patch
        what.items
      else if what.items and what.kind is AgentKind.Turtle
        t.getPatchHere() for t in what.items
      else
        throw new NetLogoException("unknown: " + typeof(what))
    result = []
    for p in patches
      for t in p.turtles
        if t.breed is breed
          result.push(t)
    new Agents(result, breed, AgentKind.Turtle)

Tasks = #@# This makes me uncomfortable
  commandTask: (fn) ->
    fn.isReporter = false
    fn
  reporterTask: (fn) ->
    fn.isReporter = true
    fn
  isReporterTask: (x) ->
    typeof(x) == "function" and x.isReporter
  isCommandTask: (x) ->
    typeof(x) == "function" and not x.isReporter
  map: (fn, lists...) -> #@# Don't understand
    for i in [0...lists[0].length]
      fn(lists.map((list) -> list[i])...)
  nValues: (n, fn) -> #@# Lodash
    fn(i) for i in [0...n]
  forEach: (fn, lists...) -> #@# Don't understand
    for i in [0...lists[0].length]
      fn(lists.map((list) -> list[i])...)
    return

#@# Attach it to an `Observer` object
Globals =
  vars: []
  # compiler generates call to init, which just
  # tells the runtime how many globals there are.
  # they are all initialized to 0
  init: (n) -> @vars = (0 for x in [0...n])
  clear: (n) ->
    @vars[i] = 0 for i in [n...@vars.length]
    return
  getGlobal: (n) -> @vars[n]
  setGlobal: (n, v) -> @vars[n] = v

#@# Evil
TurtlesOwn =
  vars: []
  init: (n) -> @vars = (0 for x in [0...n])

#@# Heinous
PatchesOwn =
  vars: []
  init: (n) -> @vars = (0 for x in [0...n])

LinksOwn =
  vars: []
  init: (n) -> @vars = (0 for x in [0...n])

# like api.Dump. will need more cases. for now at least knows
# about lists and reporter tasks
Dump = (x) ->
  if (typeIsArray(x))
    "[" + (Dump(x2) for x2 in x).join(" ") + "]" #@# Interpolate
  else if (typeof(x) == "function") #@# I hate this
    if (x.isReporter)
      "(reporter task)"
    else
      "(command task)"
  else
    "" + x #@# `toString`

Trig =
  squash: (x) ->
    if (StrictMath.abs(x) < 3.2e-15)
      0
    else
      x
  sin: (degrees) -> #@# Simplifify x4
    @squash(StrictMath.sin(StrictMath.toRadians(degrees)))
  cos: (degrees) ->
    @squash(StrictMath.cos(StrictMath.toRadians(degrees)))
  unsquashedSin: (degrees) ->
    StrictMath.sin(StrictMath.toRadians(degrees))
  unsquashedCos: (degrees) ->
    StrictMath.cos(StrictMath.toRadians(degrees))
  atan: (d1, d2) ->
    throw new NetLogoException("Runtime error: atan is undefined when both inputs are zero.") if (d1 == 0 && d2 == 0) #@# Hatred
    if (d1 == 0) #@# Intensified hatred
      if (d2 > 0) then 0 else 180
    else if (d2 == 0)
      if (d1 > 0) then 90 else 270
    else (StrictMath.toDegrees(StrictMath.atan2(d1, d2)) + 360) % 360 #@# Lame style

class Breed
  constructor: (@name, @singular, @_shape = false, @members = []) -> #@# How come the default is `false`, but `Breeds.defaultBreeds` passes in `"default"`?
  shape: () -> if @_shape then @_shape else Breeds.get("TURTLES")._shape #@# Turtles, patches, and links should be easily accessed on `Breeds`
  vars: []
  add: (agent) ->
    for a, i in @members #@# Lame, unused variable
      if a.id > agent.id
        break #@# `break` means that your code is probably wrong
    @members.splice(i, 0, agent) #@# WTF does this mean?  You're all insane.  The proper solution is probably Lodash
  remove: (agent) ->
    @members.splice(@members.indexOf(agent), 1)

Breeds = {
  defaultBreeds: -> {
    TURTLES: new Breed("TURTLES", "turtle", "default"),
    LINKS: new Breed("LINKS", "link", "default")
  }
  breeds: {}
  reset: -> @breeds = @defaultBreeds()
  add: (name, singular) ->
    upperName = name.toUpperCase()
    @breeds[upperName] = new Breed(upperName, singular.toLowerCase())
  get: (name) ->
    @breeds[name.toUpperCase()]
  setDefaultShape: (agents, shape) ->
    agents.breed._shape = shape.toLowerCase() #@# Oh, yeah?  You just go and modify the private member?  Pretty cool!
}
class Topology
  # based on agent.Topology.wrap()
  wrap: (pos, min, max) ->
    if (pos >= max)
      (min + ((pos - max) % (max - min)))
    else if (pos < min)
      result = max - ((min - pos) % (max - min)) #@# FP
      if (result < max)
        result
      else
        min
    else
      pos

  getNeighbors: (pxcor, pycor) -> #@# The line's too full of nonsense
    new Agents((patch for patch in @_getNeighbors(pxcor, pycor) when patch != false), undefined, AgentKind.Patch)

  _getNeighbors: (pxcor, pycor) -> #@# Was I able to fix this in the ScalaJS version?
    if (pxcor == @maxPxcor && pxcor == @minPxcor)
      if (pycor == @maxPycor && pycor == @minPycor)
        []
      else
        [@getPatchNorth(pxcor, pycor), @getPatchSouth(pxcor, pycor)]
    else if (pycor == @maxPycor && pycor == @minPycor)
      [@getPatchEast(pxcor, pycor), @getPatchWest(pxcor, pycor)]
    else
      [@getPatchNorth(pxcor, pycor),     @getPatchEast(pxcor, pycor),
       @getPatchSouth(pxcor, pycor),     @getPatchWest(pxcor, pycor),
       @getPatchNorthEast(pxcor, pycor), @getPatchSouthEast(pxcor, pycor),
       @getPatchSouthWest(pxcor, pycor), @getPatchNorthWest(pxcor, pycor)]

  getNeighbors4: (pxcor, pycor) -> #@# Line too full
    new Agents((patch for patch in @_getNeighbors4(pxcor, pycor) when patch != false), undefined, AgentKind.Patch)

  _getNeighbors4: (pxcor, pycor) -> #@# Any improvement in ScalaJS version?
    if (pxcor == @maxPxcor && pxcor == @minPxcor)
      if (pycor == @maxPycor && pycor == @minPycor)
        []
      else
        [@getPatchNorth(pxcor, pycor), @getPatchSouth(pxcor, pycor)]
    else if (pycor == @maxPycor && pycor == @minPycor)
      [@getPatchEast(pxcor, pycor), @getPatchWest(pxcor, pycor)]
    else
      [@getPatchNorth(pxcor, pycor), @getPatchEast(pxcor, pycor),
       @getPatchSouth(pxcor, pycor), @getPatchWest(pxcor, pycor)]

  distanceXY: (x1, y1, x2, y2) -> #@# Long line
    StrictMath.sqrt(StrictMath.pow(@shortestX(x1, x2), 2) + StrictMath.pow(@shortestY(y1, y2), 2))
  distance: (x1, y1, agent) -> #@# If you're polymorphizing, you ought to just do it properly in the OO way
    if (agent instanceof Turtle)
      @distanceXY(x1, y1, agent.xcor(), agent.ycor())
    else if(agent instanceof Patch)
      @distanceXY(x1, y1, agent.pxcor, agent.pycor)

  towards: (x1, y1, x2, y2) ->
    dx = @shortestX(x1, x2)
    dy = @shortestY(y1, y2)
    if dx == 0 #@# Code of anger
      if dy >= 0 then 0 else 180
    else if dy == 0
      if dx >= 0 then 90 else 270
    else
      (270 + StrictMath.toDegrees (Math.PI + StrictMath.atan2(-dy, dx))) % 360 #@# Long line
  midpointx: (x1, x2) -> @wrap((x1 + (x1 + @shortestX(x1, x2))) / 2, world.minPxcor - 0.5, world.maxPxcor + 0.5) #@# What does this mean?  I don't know!
  midpointy: (y1, y2) -> @wrap((y1 + (y1 + @shortestY(y1, y2))) / 2, world.minPycor - 0.5, world.maxPycor + 0.5) #@# What does this mean?  I don't know!

  inRadius: (origin, x, y, agents, radius) ->
    result =
      agents.items.filter(
        (agent) =>
          [xcor, ycor] =
            if agent instanceof Turtle
              [agent.xcor(), agent.ycor()]
            else if agent instanceof Patch
              [agent.pxcor, agent.pycor]
            else
              [undefined, undefined]
          @distanceXY(xcor, ycor, x, y) <= radius
      )
    new Agents(result, agents.breed, agents.kind)

#@# Redundancy with other topologies...
class Torus extends Topology
  constructor: (@minPxcor, @maxPxcor, @minPycor, @maxPycor) ->

  wrapX: (pos) ->
    @wrap(pos, @minPxcor - 0.5, @maxPxcor + 0.5)
  wrapY: (pos) ->
    @wrap(pos, @minPycor - 0.5, @maxPycor + 0.5)
  shortestX: (x1, x2) -> #@# Seems improvable
    if(StrictMath.abs(x1 - x2) > world.width() / 2)
      (world.width() - StrictMath.abs(x1 - x2)) * (if x2 > x1 then -1 else 1)
    else
      Math.abs(x1 - x2) * (if x1 > x2 then -1 else 1)
  shortestY: (y1, y2) -> #@# Seems improvable
    if(StrictMath.abs(y1 - y2) > world.height() / 2)
      (world.height() - StrictMath.abs(y1 - y2)) * (if y2 > y1 then -1 else 1)
    else
      Math.abs(y1 - y2) * (if y1 > y2 then -1 else 1)
  diffuse: (vn, amount) -> #@# Varname
    scratch = for x in [0...world.width()] #@# Unused var
      [] #@# Weird style
    for patch in world.patches().items #@# Two loops over the same thing.  Yeah!
      scratch[patch.pxcor - @minPxcor][patch.pycor - @minPycor] = patch.getPatchVariable(vn)
    for patch in world.patches().items
      pxcor = patch.pxcor
      pycor = patch.pycor
      # We have to order the neighbors exactly how Torus.java:diffuse does them so we don't get floating discrepancies.  FD 10/19/2013
      diffusallyOrderedNeighbors =
        [@getPatchSouthWest(pxcor, pycor), @getPatchWest(pxcor, pycor),
         @getPatchNorthWest(pxcor, pycor), @getPatchSouth(pxcor, pycor),
         @getPatchNorth(pxcor, pycor), @getPatchSouthEast(pxcor, pycor),
         @getPatchEast(pxcor, pycor), @getPatchNorthEast(pxcor, pycor)]
      diffusalSum = (scratch[n.pxcor - @minPxcor][n.pycor - @minPycor] for n in diffusallyOrderedNeighbors).reduce((a, b) -> a + b) #@# Weird
      patch.setPatchVariable(vn, patch.getPatchVariable(vn) * (1.0 - amount) + (diffusalSum / 8) * amount)

  #@# I think I tried to fix all this in the ScalaJS version.  Did I succeed?  (I doubt it)
  getPatchNorth: (pxcor, pycor) ->
    if (pycor == @maxPycor)
      world.getPatchAt(pxcor, @minPycor)
    else
      world.getPatchAt(pxcor, pycor + 1)

  getPatchSouth: (pxcor, pycor) ->
    if (pycor == @minPycor)
      world.getPatchAt(pxcor, @maxPycor)
    else
      world.getPatchAt(pxcor, pycor - 1)

  getPatchEast: (pxcor, pycor) ->
    if (pxcor == @maxPxcor)
      world.getPatchAt(@minPxcor, pycor)
    else
      world.getPatchAt(pxcor + 1, pycor)

  getPatchWest: (pxcor, pycor) ->
    if (pxcor == @minPxcor)
      world.getPatchAt(@maxPxcor, pycor)
    else
      world.getPatchAt(pxcor - 1, pycor)

  getPatchNorthWest: (pxcor, pycor) ->
    if (pycor == @maxPycor)
      if (pxcor == @minPxcor)
        world.getPatchAt(@maxPxcor, @minPycor)
      else
        world.getPatchAt(pxcor - 1, @minPycor)

    else if (pxcor == @minPxcor)
      world.getPatchAt(@maxPxcor, pycor + 1)
    else
      world.getPatchAt(pxcor - 1, pycor + 1)

  getPatchSouthWest: (pxcor, pycor) ->
    if (pycor == @minPycor)
      if (pxcor == @minPxcor)
        world.getPatchAt(@maxPxcor, @maxPycor)
      else
        world.getPatchAt(pxcor - 1, @maxPycor)
    else if (pxcor == @minPxcor)
      world.getPatchAt(@maxPxcor, pycor - 1)
    else
      world.getPatchAt(pxcor - 1, pycor - 1)

  getPatchSouthEast: (pxcor, pycor) ->
    if (pycor == @minPycor)
      if (pxcor == @maxPxcor)
        world.getPatchAt(@minPxcor, @maxPycor)
      else
        world.getPatchAt(pxcor + 1, @maxPycor)
    else if (pxcor == @maxPxcor)
      world.getPatchAt(@minPxcor, pycor - 1)
    else
      world.getPatchAt(pxcor + 1, pycor - 1)

  getPatchNorthEast: (pxcor, pycor) ->
    if (pycor == @maxPycor)
      if (pxcor == @maxPxcor)
        world.getPatchAt(@minPxcor, @minPycor)
      else
        world.getPatchAt(pxcor + 1, @minPycor)
    else if (pxcor == @maxPxcor)
      world.getPatchAt(@minPxcor, pycor + 1)
    else
      world.getPatchAt(pxcor + 1, pycor + 1)

class VertCylinder extends Topology
  constructor: (@minPxcor, @maxPxcor, @minPycor, @maxPycor) ->

  shortestX: (x1, x2) -> #@# Some lameness
    if(StrictMath.abs(x1 - x2) > (1 + @maxPxcor - @minPxcor) / 2)
      (world.width() - StrictMath.abs(x1 - x2)) * (if x2 > x1 then -1 else 1)
    else
      Math.abs(x1 - x2) * (if x1 > x2 then -1 else 1)
  shortestY: (y1, y2) -> Math.abs(y1 - y2) * (if y1 > y2 then -1 else 1)
  wrapX: (pos) ->
    @wrap(pos, @minPxcor - 0.5, @maxPxcor + 0.5)
  wrapY: (pos) ->
    if(pos >= @maxPycor + 0.5 || pos <= @minPycor - 0.5) #@# Use fun comparator syntax
      throw new TopologyInterrupt ("Cannot move turtle beyond the world's edge.")
    else pos
  getPatchNorth: (pxcor, pycor) -> (pycor != @maxPycor) && world.getPatchAt(pxcor, pycor + 1)
  getPatchSouth: (pxcor, pycor) -> (pycor != @minPycor) && world.getPatchAt(pxcor, pycor - 1)
  getPatchEast: (pxcor, pycor) ->
    if (pxcor == @maxPxcor)
      world.getPatchAt(@minPxcor, pycor)
    else
      world.getPatchAt(pxcor + 1, pycor)

  getPatchWest: (pxcor, pycor) ->
    if (pxcor == @minPxcor)
      world.getPatchAt(@maxPxcor, pycor)
    else
      world.getPatchAt(pxcor - 1, pycor)

  getPatchNorthWest: (pxcor, pycor) ->
    if (pycor == @maxPycor)
      false
    else if (pxcor == @minPxcor)
      world.getPatchAt(@maxPxcor, pycor + 1)
    else
      world.getPatchAt(pxcor - 1, pycor + 1)

  getPatchSouthWest: (pxcor, pycor) ->
    if (pycor == @minPycor)
      false
    else if (pxcor == @minPxcor)
      world.getPatchAt(@maxPxcor, pycor - 1)
    else
      world.getPatchAt(pxcor - 1, pycor - 1)

  getPatchSouthEast: (pxcor, pycor) ->
    if (pycor == @minPycor)
      false
    else if (pxcor == @maxPxcor)
      world.getPatchAt(@minPxcor, pycor - 1)
    else
      world.getPatchAt(pxcor + 1, pycor - 1)

  getPatchNorthEast: (pxcor, pycor) ->
    if (pycor == @maxPycor)
      false
    else if (pxcor == @maxPxcor)
      world.getPatchAt(@minPxcor, pycor + 1)
    else
      world.getPatchAt(pxcor + 1, pycor + 1)
  diffuse: (vn, amount) -> #@# Holy guacamole!
    yy = world.height()
    xx = world.width()
    scratch = for x in [0...xx]
      for y in [0...yy]
        world.getPatchAt(x + @minPxcor, y + @minPycor).getPatchVariable(vn)
    scratch2 = for x in [0...xx]
      for y in [0...yy]
        0
    for y in [yy...(yy * 2)]
      for x in [xx...(xx * 2)]
        diffuseVal = (scratch[x - xx][y - yy] / 8) * amount
        if (y > yy && y < (yy * 2) - 1)
          scratch2[(x    ) - xx][(y    ) - yy] += scratch[x - xx][y - yy] - (8 * diffuseVal)
          scratch2[(x - 1) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x - 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x - 1) % xx][(y + 1) % yy] += diffuseVal
          scratch2[(x    ) % xx][(y + 1) % yy] += diffuseVal
          scratch2[(x    ) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y + 1) % yy] += diffuseVal
        else if (y == yy)
          scratch2[(x    ) - xx][(y    ) - yy] += scratch[x - xx][y - yy] - (5 * diffuseVal)
          scratch2[(x - 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x - 1) % xx][(y + 1) % yy] += diffuseVal
          scratch2[(x    ) % xx][(y + 1) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y + 1) % yy] += diffuseVal
        else
          scratch2[(x    ) - xx][(y    ) - yy] += scratch[x - xx][y - yy] - (5 * diffuseVal)
          scratch2[(x - 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x - 1) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x    ) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y - 1) % yy] += diffuseVal
    for y in [0...yy]
      for x in [0...xx]
        world.getPatchAt(x + @minPxcor, y + @minPycor).setPatchVariable(vn, scratch2[x][y])

class HorzCylinder extends Topology
  constructor: (@minPxcor, @maxPxcor, @minPycor, @maxPycor) ->

  shortestX: (x1, x2) -> Math.abs(x1 - x2) * (if x1 > x2 then -1 else 1) #@# Weird
  shortestY: (y1, y2) -> #@# Weird
    if(StrictMath.abs(y1 - y2) > (1 + @maxPycor - @minPycor) / 2)
      (world.height() - Math.abs(y1 - y2)) * (if y2 > y1 then -1 else 1)
    else
      Math.abs(y1 - y2) * (if y1 > y2 then -1 else 1)
  wrapX: (pos) ->
    if(pos >= @maxPxcor + 0.5 || pos <= @minPxcor - 0.5) #@# Fun comparator syntax
      throw new TopologyInterrupt ("Cannot move turtle beyond the world's edge.")
    else pos
  wrapY: (pos) ->
    @wrap(pos, @minPycor - 0.5, @maxPycor + 0.5)
  getPatchEast: (pxcor, pycor) -> (pxcor != @maxPxcor) && world.getPatchAt(pxcor + 1, pycor)
  getPatchWest: (pxcor, pycor) -> (pxcor != @minPxcor) && world.getPatchAt(pxcor - 1, pycor)
  getPatchNorth: (pxcor, pycor) ->
    if (pycor == @maxPycor)
      world.getPatchAt(pxcor, @minPycor)
    else
      world.getPatchAt(pxcor, pycor + 1)
  getPatchSouth: (pxcor, pycor) ->
    if (pycor == @minPycor)
      world.getPatchAt(pxcor, @maxPycor)
    else
      world.getPatchAt(pxcor, pycor - 1)

  getPatchNorthWest: (pxcor, pycor) ->
    if (pxcor == @minPxcor)
      false
    else if (pycor == @maxPycor)
      world.getPatchAt(pxcor - 1, @minPycor)
    else
      world.getPatchAt(pxcor - 1, pycor + 1)

  getPatchSouthWest: (pxcor, pycor) ->
    if (pxcor == @minPxcor)
      false
    else if (pycor == @minPycor)
      world.getPatchAt(pxcor - 1, @maxPycor)
    else
      world.getPatchAt(pxcor - 1, pycor - 1)

  getPatchSouthEast: (pxcor, pycor) ->
    if (pxcor == @maxPxcor)
      false
    else if (pycor == @minPycor)
      world.getPatchAt(pxcor + 1, @maxPycor)
    else
      world.getPatchAt(pxcor + 1, pycor - 1)

  getPatchNorthEast: (pxcor, pycor) ->
    if (pxcor == @maxPxcor)
      false
    else if (pycor == @maxPycor)
      world.getPatchAt(pxcor + 1, @minPycor)
    else
      world.getPatchAt(pxcor + 1, pycor + 1)
  diffuse: (vn, amount) -> #@# Dat guacamole
    yy = world.height()
    xx = world.width()
    scratch = for x in [0...xx]
      for y in [0...yy]
        world.getPatchAt(x + @minPxcor, y + @minPycor).getPatchVariable(vn)
    scratch2 = for x in [0...xx]
      for y in [0...yy]
        0
    for y in [yy...(yy * 2)]
      for x in [xx...(xx * 2)]
        diffuseVal = (scratch[x - xx][y - yy] / 8) * amount
        if (x > xx && x < (xx * 2) - 1)
          scratch2[(x    ) - xx][(y    ) - yy] += scratch[x - xx][y - yy] - (8 * diffuseVal)
          scratch2[(x - 1) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x - 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x - 1) % xx][(y + 1) % yy] += diffuseVal
          scratch2[(x    ) % xx][(y + 1) % yy] += diffuseVal
          scratch2[(x    ) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y + 1) % yy] += diffuseVal
        else if (x == xx)
          scratch2[(x    ) - xx][(y    ) - yy] += scratch[x - xx][y - yy] - (5 * diffuseVal)
          scratch2[(x    ) % xx][(y + 1) % yy] += diffuseVal
          scratch2[(x    ) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x + 1) % xx][(y + 1) % yy] += diffuseVal
        else
          scratch2[(x    ) - xx][(y    ) - yy] += scratch[x - xx][y - yy] - (5 * diffuseVal)
          scratch2[(x    ) % xx][(y + 1) % yy] += diffuseVal
          scratch2[(x    ) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x - 1) % xx][(y - 1) % yy] += diffuseVal
          scratch2[(x - 1) % xx][(y    ) % yy] += diffuseVal
          scratch2[(x - 1) % xx][(y + 1) % yy] += diffuseVal
    for y in [0...yy]
      for x in [0...xx]
        world.getPatchAt(x + @minPxcor, y + @minPycor).setPatchVariable(vn, scratch2[x][y])

class Box extends Topology
  constructor: (@minPxcor, @maxPxcor, @minPycor, @maxPycor) ->

  #@# Weird x2
  shortestX: (x1, x2) -> Math.abs(x1 - x2) * (if x1 > x2 then -1 else 1)
  shortestY: (y1, y2) -> Math.abs(y1 - y2) * (if y1 > y2 then -1 else 1)
  wrapX: (pos) -> #@# Fun comparator syntax x2
    if(pos >= @maxPxcor + 0.5 || pos <= @minPxcor - 0.5)
      throw new TopologyInterrupt ("Cannot move turtle beyond the worlds edge.")
    else pos
  wrapY: (pos) ->
    if(pos >= @maxPycor + 0.5 || pos <= @minPycor - 0.5)
      throw new TopologyInterrupt ("Cannot move turtle beyond the worlds edge.")
    else pos

  getPatchNorth: (pxcor, pycor) -> (pycor != @maxPycor) && world.getPatchAt(pxcor, pycor + 1)
  getPatchSouth: (pxcor, pycor) -> (pycor != @minPycor) && world.getPatchAt(pxcor, pycor - 1)
  getPatchEast: (pxcor, pycor) -> (pxcor != @maxPxcor) && world.getPatchAt(pxcor + 1, pycor)
  getPatchWest: (pxcor, pycor) -> (pxcor != @minPxcor) && world.getPatchAt(pxcor - 1, pycor)

  getPatchNorthWest: (pxcor, pycor) -> (pycor != @maxPycor) && (pxcor != @minPxcor) && world.getPatchAt(pxcor - 1, pycor + 1)
  getPatchSouthWest: (pxcor, pycor) -> (pycor != @minPycor) && (pxcor != @minPxcor) && world.getPatchAt(pxcor - 1, pycor - 1)
  getPatchSouthEast: (pxcor, pycor) -> (pycor != @minPycor) && (pxcor != @maxPxcor) && world.getPatchAt(pxcor + 1, pycor - 1)
  getPatchNorthEast: (pxcor, pycor) -> (pycor != @maxPycor) && (pxcor != @maxPxcor) && world.getPatchAt(pxcor + 1, pycor + 1)

  diffuse: (vn, amount) -> #@# Guacy moley
    yy = world.height()
    xx = world.width()
    scratch = for x in [0...xx]
      for y in [0...yy]
        world.getPatchAt(x + @minPxcor, y + @minPycor).getPatchVariable(vn)
    scratch2 = for x in [0...xx]
      for y in [0...yy]
        0
    for y in [0...yy]
      for x in [0...xx]
        diffuseVal = (scratch[x][y] / 8) * amount
        if (y > 0 && y < yy - 1 && x > 0 && x < xx - 1)
          scratch2[x    ][y    ] += scratch[x][y] - (8 * diffuseVal)
          scratch2[x - 1][y - 1] += diffuseVal
          scratch2[x - 1][y    ] += diffuseVal
          scratch2[x - 1][y + 1] += diffuseVal
          scratch2[x    ][y + 1] += diffuseVal
          scratch2[x    ][y - 1] += diffuseVal
          scratch2[x + 1][y - 1] += diffuseVal
          scratch2[x + 1][y    ] += diffuseVal
          scratch2[x + 1][y + 1] += diffuseVal
        else if (y > 0 && y < yy - 1)
          if (x == 0)
            scratch2[x    ][y    ] += scratch[x][y] - (5 * diffuseVal)
            scratch2[x    ][y + 1] += diffuseVal
            scratch2[x    ][y - 1] += diffuseVal
            scratch2[x + 1][y - 1] += diffuseVal
            scratch2[x + 1][y    ] += diffuseVal
            scratch2[x + 1][y + 1] += diffuseVal
          else
            scratch2[x    ][y    ] += scratch[x][y] - (5 * diffuseVal)
            scratch2[x    ][y + 1] += diffuseVal
            scratch2[x    ][y - 1] += diffuseVal
            scratch2[x - 1][y - 1] += diffuseVal
            scratch2[x - 1][y    ] += diffuseVal
            scratch2[x - 1][y + 1] += diffuseVal
        else if (x > 0 && x < xx - 1)
          if (y == 0)
            scratch2[x    ][y    ] += scratch[x][y] - (5 * diffuseVal)
            scratch2[x - 1][y    ] += diffuseVal
            scratch2[x - 1][y + 1] += diffuseVal
            scratch2[x    ][y + 1] += diffuseVal
            scratch2[x + 1][y    ] += diffuseVal
            scratch2[x + 1][y + 1] += diffuseVal
          else
            scratch2[x    ][y    ] += scratch[x][y] - (5 * diffuseVal)
            scratch2[x - 1][y    ] += diffuseVal
            scratch2[x - 1][y - 1] += diffuseVal
            scratch2[x    ][y - 1] += diffuseVal
            scratch2[x + 1][y    ] += diffuseVal
            scratch2[x + 1][y - 1] += diffuseVal
        else if (x == 0)
          if (y == 0)
            scratch2[x    ][y    ] += scratch[x][y] - (3 * diffuseVal)
            scratch2[x    ][y + 1] += diffuseVal
            scratch2[x + 1][y    ] += diffuseVal
            scratch2[x + 1][y + 1] += diffuseVal
          else
            scratch2[x    ][y    ] += scratch[x][y] - (3 * diffuseVal)
            scratch2[x    ][y - 1] += diffuseVal
            scratch2[x + 1][y    ] += diffuseVal
            scratch2[x + 1][y - 1] += diffuseVal
        else if (y == 0)
          scratch2[x    ][y    ] += scratch[x][y] - (3 * diffuseVal)
          scratch2[x    ][y + 1] += diffuseVal
          scratch2[x - 1][y    ] += diffuseVal
          scratch2[x - 1][y + 1] += diffuseVal
        else
          scratch2[x    ][y    ] += scratch[x][y] - (3 * diffuseVal)
          scratch2[x    ][y - 1] += diffuseVal
          scratch2[x - 1][y    ] += diffuseVal
          scratch2[x - 1][y - 1] += diffuseVal
    for y in [0...yy]
      for x in [0...xx]
        world.getPatchAt(x + @minPxcor, y + @minPycor).setPatchVariable(vn, scratch2[x][y])

# Copied pretty much verbatim from Layouts.java
Layouts =
  #@# Okay, so... in what universe is it alright for a single function to be 120 lines long?
  layoutSpring: (nodeSet, linkSet, spr, len, rep) ->
    nodeCount = nodeSet.items.length
    if nodeCount == 0 #@# Bad
      return

    ax = []
    ay = []
    tMap = []
    degCount = (0 for i in [0...nodeCount]) #@# Unused var

    agt = []
    i = 0
    for t in AgentSet.shuffle(nodeSet).items #@# Lodash
      agt[i] = t
      tMap[t.id] = i
      ax[i] = 0.0
      ay[i] = 0.0
      i++

    for link in linkSet.items #@# Lodash
      t1 = link.end1
      t2 = link.end2
      if (tMap[t1.id] != undefined) #@# Lame x2
        t1Index = tMap[t1.id]
        degCount[t1Index]++
      if (tMap[t2.id] != undefined)
        t2Index = tMap[t2.id]
        degCount[t2Index]++

    for link in linkSet.items #@# Lodash
      dx = 0
      dy = 0
      t1 = link.end1
      t2 = link.end2
      t1Index = -1
      degCount1 = 0
      if tMap[t1.id] != undefined #@# Lame
        t1Index = tMap[t1.id]
        degCount1 = degCount[t1Index]
      t2Index = -1
      degCount2 = 0
      if tMap[t2.id] != undefined #@# Lame
        t2Index = tMap[t2.id]
        degCount2 = degCount[t2Index]
      dist = t1.distance(t2)
      # links that are connecting high degree nodes should not
      # be as springy, to help prevent "jittering" behavior
      div = (degCount1 + degCount2) / 2.0
      div = Math.max(div, 1.0)

      if dist == 0
        dx += (spr * len) / div # arbitrary x-dir push-off
      else
        f = spr * (dist - len) / div
        dx = dx + (f * (t2.xcor() - t1.xcor()) / dist)
        dy = dy + (f * (t2.ycor() - t1.ycor()) / dist)
      if t1Index != -1
        ax[t1Index] += dx
        ay[t1Index] += dy
      if t2Index != -1 #@# Surely all of this control flow can be FPified
        ax[t2Index] -= dx
        ay[t2Index] -= dy

    for i in [0...nodeCount] #@# Lodash
      t1 = agt[i]
      for j in [(i + 1)...nodeCount]
        t2 = agt[j]
        dx = 0.0
        dy = 0.0
        div = (degCount[i] + degCount[j]) / 2.0
        div = Math.max(div, 1.0)

        if (t2.xcor() == t1.xcor() && t2.ycor() == t1.ycor())
          ang = 360 * Random.nextDouble()
          dx = -(rep / div * Trig.sin(StrictMath.toRadians(ang)))
          dy = -(rep / div * Trig.cos(StrictMath.toRadians(ang)))
        else
          dist = t1.distance(t2)
          f = rep / (dist * dist) / div
          dx = -(f * (t2.xcor() - t1.xcor()) / dist)
          dy = -(f * (t2.ycor() - t1.ycor()) / dist)
        ax[i] += dx
        ay[i] += dy
        ax[j] -= dx
        ay[j] -= dy

    # we need to bump some node a small amount, in case all nodes
    # are stuck on a single line
    if (nodeCount > 1)
      perturbAmt = (world.width() + world.height()) / 1.0e10
      ax[0] += Random.nextDouble() * perturbAmt - perturbAmt / 2.0
      ay[0] += Random.nextDouble() * perturbAmt - perturbAmt / 2.0

    # try to choose something that's reasonable perceptually --
    # for temporal aliasing, don't want to jump too far on any given timestep.
    limit = (world.width() + world.height()) / 50.0

    for i in [0...nodeCount]
      t = agt[i]
      fx = ax[i]
      fy = ay[i]

      if fx > limit
        fx = limit
      else if fx < -limit
        fx = -limit

      if fy > limit
        fy = limit
      else if fy < -limit
        fy = -limit

      newx = t.xcor() + fx
      newy = t.ycor() + fy

      if newx > world.maxPxcor
        newx = world.maxPxcor
      else if newx < world.minPxcor
        newx = world.minPxcor

      if newy > world.maxPycor
        newy = world.maxPycor
      else if newy < world.minPycor
        newy = world.minPycor
      t.setXY(newx, newy)
