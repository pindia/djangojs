class IfNode extends djangoJS.Node
  constructor: (conditionNodelists) ->
    this.conditionNodelists = conditionNodelists

  render: (context) ->
    for cn in this.conditionNodelists
      [condition, nodelist] = cn
      if condition(context)
        return nodelist.render(context)
    return ''


makeIfCondition = (expr) ->
  return (context) ->
    return (new Function("with(this){return #{expr}}")).call(context)

djangoJS.tags['if'] = (parser, token) ->
  conditionNodelists = []

  expr = token.splitContents().slice(1).join(' ')
  condition = makeIfCondition(expr)
  nodelist = parser.parse(['elif', 'else', 'endif'])
  conditionNodelists.push [condition, nodelist]
  token = parser.nextToken()

  while token.contents.substr(0, 4) == 'elif'
    expr = token.splitContents().slice(1).join(' ')
    condition = makeIfCondition(expr)
    nodelist = parser.parse(['elif', 'else', 'endif'])
    conditionNodelists.push [condition, nodelist]
    token = parser.nextToken()

  if token.contents == 'else'
    nodelist = parser.parse(['endif'])
    condition = (context) -> true
    conditionNodelists.push [condition, nodelist]
    token = parser.nextToken()

  return new IfNode(conditionNodelists)

class ForNode extends djangoJS.Node
  constructor: (loopvar, sequence, nodelistLoop, nodelistEmpty) ->
    this.loopvar = loopvar
    this.sequence = new djangoJS.Variable(sequence)
    this.nodelistLoop = nodelistLoop
    this.nodelistEmpty = nodelistEmpty

  render: (_context) ->
    context = $.extend({}, _context) # Copy context to avoid mutation at higher level
    values = this.sequence.resolve(context)
    valuesLen = values.length
    if valuesLen == 0
      return this.nodelistEmpty.render(context)
    nodelist = new djangoJS.NodeList()
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

djangoJS.tags['for'] = (parser, token) ->
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
    nodelistEmpty = new djangoJS.NodeList()
  return new ForNode(loopvar, sequence, nodelistLoop, nodelistEmpty)


class CycleNode extends djangoJS.Node
  constructor: (cyclevars) ->
    this.cyclevars = cyclevars
    this.i = 0

  render: (context) ->
    curvar = this.cyclevars[this.i % this.cyclevars.length]
    this.i += 1
    return curvar.resolve(context)

djangoJS.tags['cycle'] = (parser, token) ->
  vars = token.splitContents().slice(1)
  return new CycleNode((new djangoJS.Variable(name) for name in vars))

class CommentNode extends djangoJS.Node
  render: (context) ->
    return ''

djangoJS.tags['comment'] = (parser, token) ->
  parser.skipPast('endcomment')
  return new CommentNode()

class VerbatimNode extends djangoJS.Node
  constructor: (content) -> this.content = content
  render: (context) -> return this.content

djangoJS.tags['verbatim'] = (parser, token) ->
  nodelist = parser.parse(['endverbatim'])
  parser.nextToken()
  return new VerbatimNode(nodelist.render({}))


djangoJS.filters['escape'] = (value) ->
  return value.toString().replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')

djangoJS.filters['safe'] = (value) ->
  s = new String(value)
  s.safe = true
  return s

djangoJS.filters['default'] = (value, arg) ->
  if not value
    return arg
  return value

djangoJS.filters['lower'] = (value) -> value.toLowerCase()