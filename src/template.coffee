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

#tag_re = (re.compile('(%s.*?%s|%s.*?%s|%s.*?%s)' %
#(re.escape(BLOCK_TAG_START), re.escape(BLOCK_TAG_END),
#re.escape(VARIABLE_TAG_START), re.escape(VARIABLE_TAG_END),
#re.escape(COMMENT_TAG_START), re.escape(COMMENT_TAG_END))))

tokenize = (templateString) ->
  inTag = false
  result = []
  for bit in templateString.split(tagRe)
    if bit
      result.push bit
      inTag = not inTag
  return result


template = '''
{% if condition == 5 %}
  <li>{{variable}}</li>
{% endif %}
'''

console.log tokenize(template)