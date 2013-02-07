class IfNode extends Templar.Node
  constructor: (conditionNodelists) ->
    this.conditionNodelists = conditionNodelists

  render: (context) ->
    for cn in this.conditionNodelists
      [condition, nodelist] = cn
      if condition(context)
        return nodelist.render(context)
    return ''

operators =
  '==': '=='
  '!=': '!='
  '>=': '>='
  '<=': '<='
  '>': '>'
  '<': '<'
  'and': '&&'
  'or': '||'
  'not': '!'

Templar.parseIfTokens = (tokens) ->
  s = []
  for token in tokens
    if token of operators
      s.push operators[token]
    else
      token = token.replace(/\'/g, "\\'") # Prevent quote injection
      s.push "(new Templar.FilterExpression('#{token}').resolve(context))"
  return new Function("context=arguments[0]; return " + s.join(''))

Templar.tags['if'] = (parser, token) ->
  conditionNodelists = []

  expr = token.splitContents().slice(1)
  condition = Templar.parseIfTokens(expr)
  nodelist = parser.parse(['elif', 'else', 'endif'])
  conditionNodelists.push [condition, nodelist]
  token = parser.nextToken()

  while token.contents.substr(0, 4) == 'elif'
    expr = token.splitContents().slice(1)
    condition = Templar.parseIfTokens(expr)
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

class BlockNode extends Templar.Node
  constructor:  (name, nodelist) ->
    this.name = name
    this.nodelist = nodelist

  addToContext: (context) ->
    if this.name of context._block
      context._block[this.name].push this
    else
      context._block[this.name] = [this]

  render: (context) ->
    if '_block' not of context
      result = this.nodelist.render(context)
    else
      console.log context._block[this.name]
      block = context._block[this.name].pop()
      console.log block
      result = block.nodelist.render(context)
      while context._block[this.name].length
        block = context._block[this.name].pop()
        result = block.nodelist.render(context)
    return result

Templar.tags['block'] = (parser, token) ->
  name = token.splitContents()[1]
  nodelist = parser.parse(['endblock'])
  token = parser.nextToken()
  return new BlockNode(name, nodelist)


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