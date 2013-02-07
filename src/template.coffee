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

smartSplitRe = /\S+|(?:"|')[^"]+(?:'|")/g


TOKEN_TEXT = 0
TOKEN_VAR = 1
TOKEN_BLOCK = 2
TOKEN_COMMENT = 3

markSafe = (string) ->
  s = new String(string)
  s.safe = true
  return s

class Token
  constructor: (type, contents) ->
    this.type = type
    this.contents = contents

  splitContents: ->
    return this.contents.match(smartSplitRe)

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
    if inTag and tokenString.substr(0, 2) == BLOCK_TAG_START
      blockContent = tokenString.slice(2, -2).trim()
      if this.verbatim and blockContent == 'endverbatim'
        this.verbatim = false
    if inTag and not this.verbatim
      if tokenString.substr(0, 2) == VARIABLE_TAG_START
        token = new Token(TOKEN_VAR, tokenString.slice(2, -2).trim())
      else if tokenString.substr(0, 2) == BLOCK_TAG_START
        if blockContent == 'verbatim'
          this.verbatim = true
        token = new Token(TOKEN_BLOCK, tokenString.slice(2, -2).trim())
      else if tokenString.substr(0, 2) == COMMENT_TAG_START
        token = new Token(TOKEN_COMMENT, '')
    else
      token = new Token(TOKEN_TEXT, tokenString)
    return token

globalTags = {}
globalFilters = {}

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
        nodelist.push result

    return nodelist

  nextToken: ->
    return this.tokens.shift()

  skipPast: (endTag) ->
    while this.tokens.length > 0
      token = this.nextToken()
      if token.type == TOKEN_BLOCK and token.contents == endTag
        return
    throw "unclosed block tag '#{endTag}'"



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

class Variable
  constructor: (name) ->
    this.name = name
    if this.name.match('[0-9]+')
      value = parseInt(this.name)
      this.resolve = (context) -> return value
    if this.name[0] == '"' or this.name[0] == "'" # Literal "variable"
      value = markSafe(this.name.slice(1, -1))
      this.resolve = (context) -> return value
    else
      this.bits = this.name.split('.')

  resolve: (context) ->
    c = context
    for bit in this.bits
      c = c[bit]
      if c is undefined
        return undefined
    return c

filterRe = /([^|]+)|(?:\|(\w+)(?:\:([\S\.]+))?)/g

class FilterExpression
  constructor: (expr) ->
    this.filters = []
    this.filterArgs = []
    filterRe.lastIndex = 0
    upto = 0
    bits = filterRe.exec(expr)
    while bits
      if bits[1]
        this.variable = new Variable(bits[0])
      else if bits[2]
        if bits[2] not of globalFilters
          throw "invalid filter '#{bits[2]}'"
        this.filters.push globalFilters[bits[2]]
        this.filterArgs.push if bits[3] then new Variable(bits[3]) else null
      upto = filterRe.lastIndex
      bits = filterRe.exec(expr)
    if upto != expr.length
      throw "failed to parse remainder '#{expr.slice(filterRe.lastIndex)}' of filter expression"
    if not this.variable
      throw "empty variable expression"

  resolve: (context) ->
    value = this.variable.resolve(context)
    for i in [0...this.filters.length]
      arg = this.filterArgs[i]?.resolve(context)
      value = this.filters[i](value, arg)
    return value

class Node

class TextNode extends Node
  constructor: (s) ->
    this.s = s

  render: (context) ->
    return this.s

class VariableNode extends Node
  constructor: (expr) ->
    this.expr = new FilterExpression(expr)

  render: (context) ->
    value = this.expr.resolve(context)
    if not value.safe
      value = globalFilters.escape(value)
    return value

simpleTag = (fn) ->
  return (parser, token) ->
    bits = token.splitContents()
    args = (new FilterExpression(bit) for bit in bits.slice(1))
    return {
      render: (context) ->
        return fn.apply(null, [context].concat(arg.resolve(context) for arg in args))
    }

inclusionTag = (subTemplate, fn) ->
  return (parser, token) ->
    bits = token.splitContents()
    args = (new FilterExpression(bit) for bit in bits.slice(1))
    return {
      render: (context) ->
        subContext = fn.apply(null, [context].concat(arg.resolve(context) for arg in args))
        return subTemplate.render(subContext)
    }

assignmentTag = (fn) ->
  return (parser, token) ->
    bits = token.splitContents()
    if bits[bits.length - 2] != 'as'
      throw 'Invalid assignment tag invocation, expected {% <tag> <args..> as <var> %}'
    varname = bits[bits.length - 1]
    args = (new FilterExpression(bit) for bit in bits.slice(1, -2))
    return {
    render: (context) ->
      val = fn.apply(null, [context].concat(arg.resolve(context) for arg in args))
      context[varname] = val
      return ''
    }

window.Templar =
  Template: Template
  Variable: Variable
  FilterExpression: FilterExpression
  Token: Token
  Node: Node
  NodeList: NodeList
  tags: globalTags
  filters: globalFilters
  simpleTag: simpleTag
  inclusionTag: inclusionTag
  assignmentTag: assignmentTag