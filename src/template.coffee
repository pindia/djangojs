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
    console.log tokenString, inTag
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

template = '''
{% if condition == 5 %}
  <li>{{variable}}</li>
{% endif %}
'''

l = new Lexer(template)
console.log l.tokenize()