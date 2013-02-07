class IfNode extends Templar.Node
  constructor: (conditionNodelists) ->
    this.conditionNodelists = conditionNodelists

  render: (context) ->
    for cn in this.conditionNodelists
      [condition, nodelist] = cn
      if condition(context)
        return nodelist.render(context)
    return ''

Literal = (value) ->
  this.expr = new Templar.FilterExpression(value)
  this.nud = (parser) ->
    return this
  this.eval = (context) ->
    return this.expr.resolve(context)
  return this

makeInfix = (bp, f) ->
  return ->
    this.lbp = bp
    this.led = (parser, left) ->
      this.left = left
      this.right = parser.expression(bp)
      return this
    this.eval = (context) ->
      return f(this.left.eval(context), this.right.eval(context))
    return this

makePrefix = (bp, f) ->
  return ->
    this.lbp = bp
    this.nud = (parser) ->
      this.left = parser.expression(bp)
      return this
    this.eval = (context) ->
      return f(this.left.eval(context))
    return this

operators =
  '==':  makeInfix(10, (a, b) -> a == b)
  '!=':  makeInfix( 10, (a, b) -> a != b)
  '>':   makeInfix( 10, (a, b) -> a > b)
  '>=':  makeInfix( 10, (a, b) -> a >= b)
  '<':   makeInfix( 10, (a, b) -> a < b)
  '<=':  makeInfix( 10, (a, b) -> a <= b)
  'not': makePrefix( 8, (a) -> not a)
  'and': makeInfix(  7, (a, b) -> a and b)
  'or':  makeInfix(  6, (a, b) -> a or b)

translateToken = (t) ->
  if t of operators
    return new operators[t]
  else
    return new Literal(t)

Templar.parseIfTokens = (tokens) ->
  tokens = (translateToken(t) for t in tokens)
  tokens.push
    lbp: 0
  console.log tokens
  parser =
    expression: (rbp) ->
      t = this.current
      this.current = tokens.shift()
      left = t.nud(this)
      console.log left
      while rbp < this.current.lbp
        t = this.current
        this.current = tokens.shift()
        left = t.led(this, left)
        console.log left
      return left
  parser.current = tokens[0]
  tokens.shift()
  return parser.expression(0)

Templar.tags['if'] = (parser, token) ->
  conditionNodelists = []

  expr = token.splitContents().slice(1)
  condition = do (expr) -> (context) -> Templar.parseIfTokens(expr).eval(context)
  nodelist = parser.parse(['elif', 'else', 'endif'])
  conditionNodelists.push [condition, nodelist]
  token = parser.nextToken()

  while token.contents.substr(0, 4) == 'elif'
    expr = token.splitContents().slice(1)
    condition = do (expr) -> (context) -> Templar.parseIfTokens(expr).eval(context)
    nodelist = parser.parse(['elif', 'else', 'endif'])
    conditionNodelists.push [condition, nodelist]
    token = parser.nextToken()

  if token.contents == 'else'
    nodelist = parser.parse(['endif'])
    condition = (context) -> true
    conditionNodelists.push [condition, nodelist]
    token = parser.nextToken()

  return new IfNode(conditionNodelists)

class ForNode extends Templar.Node
  constructor: (loopvar, sequence, nodelistLoop, nodelistEmpty) ->
    this.loopvar = loopvar
    this.sequence = new Templar.Variable(sequence)
    this.nodelistLoop = nodelistLoop
    this.nodelistEmpty = nodelistEmpty

  render: (_context) ->
    context = $.extend({}, _context) # Copy context to avoid mutation at higher level
    values = this.sequence.resolve(context)
    if not values?
      return this.nodelistEmpty.render(context)
    valuesLen = values.length
    if valuesLen == 0
      return this.nodelistEmpty.render(context)
    nodelist = new Templar.NodeList()
    loopDict = {}
    if 'forloop' of context
      loopDict['parentloop'] = context['forloop']
    context['forloop'] = loopDict
    for i in [0...valuesLen]
      loopDict['counter0'] = i
      loopDict['counter'] = i + 1
      loopDict['revcounter'] = valuesLen - i
      loopDict['revcounter0'] = valuesLen - i - 1
      loopDict['first'] = i == 0
      loopDict['last'] = i == valuesLen - 1
      context[this.loopvar] = values[i]
      for node in this.nodelistLoop._list
        nodelist.push node.render(context)
    return nodelist.render(context)

Templar.tags['for'] = (parser, token) ->
  bits = token.contents.split(' ')
  loopvar = bits[1]
  if bits[2] != 'in'
    throw "for tag must follow format 'for <loopvar> in <seq>'"
  sequence = bits[3]
  nodelistLoop = parser.parse(['empty', 'endfor'])
  token = parser.nextToken()
  if token.contents == 'empty'
    nodelistEmpty = parser.parse(['endfor'])
    token = parser.nextToken()
  else
    nodelistEmpty = new Templar.NodeList()
  return new ForNode(loopvar, sequence, nodelistLoop, nodelistEmpty)


class CycleNode extends Templar.Node
  constructor: (cyclevars) ->
    this.cyclevars = cyclevars
    this.i = 0

  render: (context) ->
    curvar = this.cyclevars[this.i % this.cyclevars.length]
    this.i += 1
    return curvar.resolve(context)

Templar.tags['cycle'] = (parser, token) ->
  vars = token.splitContents().slice(1)
  return new CycleNode((new Templar.Variable(name) for name in vars))

class CommentNode extends Templar.Node
  render: (context) ->
    return ''

Templar.tags['comment'] = (parser, token) ->
  parser.skipPast('endcomment')
  return new CommentNode()

class VerbatimNode extends Templar.Node
  constructor: (content) -> this.content = content
  render: (context) -> return this.content

Templar.tags['verbatim'] = (parser, token) ->
  nodelist = parser.parse(['endverbatim'])
  parser.nextToken()
  return new VerbatimNode(nodelist.render({}))

class FilterNode extends Templar.Node
  constructor: (expr, nodelist) ->
    this.expr = expr
    this.nodelist = nodelist

  render: (context) ->
    output = this.nodelist.render(context)
    context['_var'] = output
    return this.expr.resolve(context)

Templar.tags['filter'] = (parser, token) ->
  bits = token.contents.split(' ')
  expr = new Templar.FilterExpression("_var|#{bits[1]}")
  nodelist = parser.parse(['endfilter'])
  parser.nextToken()
  return new FilterNode(expr, nodelist)


Templar.filters['escape'] = (value) ->
  return value.toString().replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')

Templar.filters['safe'] = (value) ->
  s = new String(value)
  s.safe = true
  return s

Templar.filters['default'] = (value, arg) ->
  if not value
    return arg
  return value

Templar.filters['pluralize'] = (value, arg='s') ->
  bits = arg.split(',')
  if value == 1
    if bits.length > 1
      return bits[0]
    return ''
  if bits.length > 1
    return bits[1]
  if bits.length == 1
    return bits[0]

Templar.filters['yesno'] = (value, arg='yes,no') ->
  bits = arg.split(',')
  if not value?
    if bits[2]
      return bits[2]
    return bits[1]
  if value
    return bits[0]
  return bits[1]

Templar.filters['upper'] = (value) ->
  return value.toUpperCase()
Templar.filters['lower'] = (value) ->
  return value.toLowerCase()