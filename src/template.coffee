# template syntax constants
FILTER_SEPARATOR = '|'
FILTER_ARGUMENT_SEPARATOR = ':'
VARIABLE_ATTRIBUTE_SEPARATOR = '.'
BLOCK_TAG_START = '{%'
BLOCK_TAG_END = '%}'
VARIABLE_TAG_START = '{{'
VARIABLE_TAG_END = '}}'
COMMENT_TAG_START = '{#'
COMMENT_TAG_END = '#}'

tagRe = new RegExp("(#{BLOCK_TAG_START}.*?#{BLOCK_TAG_END}|" +
  "#{VARIABLE_TAG_START}.*?#{VARIABLE_TAG_END}|" +
  "#{COMMENT_TAG_START}.*?#{COMMENT_TAG_END})")

TOKEN_TEXT = 0
TOKEN_VAR = 1
TOKEN_BLOCK = 2
TOKEN_COMMENT = 3

class Token
  constructor: (type, contents) ->
    this.type = type
    this.contents = contents

class Template
  constructor: (templateString) ->
    l = new Lexer(templateString)
    tokens = l.tokenize()
    p = new Parser(tokens)
    this.nodelist = p.parse()

  render: (context) ->
    return this.nodelist.render(context)


class Lexer
  constructor: (templateString) ->
    this.templateString = templateString

  tokenize: ->
    inTag = false
    result = []
    for bit in this.templateString.split(tagRe)
      if bit
        result.push this.createToken bit, inTag
      inTag = not inTag
    return result

  createToken: (tokenString, inTag) ->
    if inTag
      if tokenString.substr(0, 2) == VARIABLE_TAG_START
        token = new Token(TOKEN_VAR, tokenString.slice(2, -2).trim())
      else if tokenString.substr(0, 2) == BLOCK_TAG_START
        token = new Token(TOKEN_BLOCK, tokenString.slice(2, -2).trim())
      else if tokenString.substr(0, 2) == COMMENT_TAG_START
        token = new Token(TOKEN_COMMENT, '')
    else
      token = new Token(TOKEN_TEXT, tokenString)
    return token

globalTags = {}

class Parser
  constructor: (tokens) ->
    this.tokens = tokens
    this.tags = globalTags

  parse: (parseUntil=[]) ->
    nodelist = new NodeList()
    while this.tokens.length > 0
      token = this.nextToken()
      if token.type == TOKEN_TEXT
        nodelist.push new TextNode token.contents
      else if token.type == TOKEN_VAR
        nodelist.push new VariableNode token.contents
      else if token.type == TOKEN_BLOCK
        command = token.contents.split(' ')[0]
        if command in parseUntil
          this.tokens.unshift(token) # put token back on token list so calling code knows why it terminated
          return nodelist
        # execute callback function for this tag and append resulting node
        func = this.tags[command]
        if not func?
          throw "Invalid block tag '#{command}'"
        result = func(this, token)
        console.log result
        nodelist.push result

    return nodelist

  nextToken: ->
    return this.tokens.shift()


class NodeList
  constructor: ->
    this._list = []

  push: (node) ->
    this._list.push node

  render: (context) ->
    bits = []
    for node in this._list
      if node.render?
        bits.push node.render(context)
      else
        bits.push node
    return bits.join('')

class Node

class TextNode extends Node
  constructor: (s) ->
    this.s = s

  render: (context) ->
    return this.s

class VariableNode extends Node
  constructor: (expr) ->
    this.expr = expr

  render: (context) ->
    if this.expr of context
      return context[this.expr]
    else
      return ''

class IfNode extends Node
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

globalTags['if'] = (parser, token) ->
  conditionNodelists = []

  expr = token.contents.split(' ').slice(1).join(' ')
  condition = makeIfCondition(expr)
  nodelist = parser.parse(['elif', 'else', 'endif'])
  conditionNodelists.push [condition, nodelist]
  token = parser.nextToken()

  while token.contents.substr(0, 4) == 'elif'
    expr = token.contents.split(' ').slice(1).join(' ')
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

class ForNode extends Node
  constructor: (loopvar, sequence, nodelistLoop, nodelistEmpty) ->
    this.loopvar = loopvar
    this.sequence = sequence
    this.nodelistLoop = nodelistLoop
    this.nodelistEmpty = nodelistEmpty

  render: (_context) ->
    context = $.extend({}, _context) # Copy context to avoid mutation at higher level
    if 'forloop' of context
      context['parentloop'] = context['forloop']
    values = context[this.sequence] or []
    valuesLen = values.length
    if valuesLen == 0
      return this.nodelistEmpty.render(context)
    nodelist = new NodeList()
    loopDict = context['forloop'] = {}
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

globalTags['for'] = (parser, token) ->
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
    nodelistEmpty = new NodeList()
  return new ForNode(loopvar, sequence, nodelistLoop, nodelistEmpty)






template = '''
{% if condition > 5 %}
  {% if condition == 6 %}
    Equals 6
  {% endif %}
  <li>{{variable}}</li>
{% endif %}
<b>Always here</b>
'''

this.Template = Template