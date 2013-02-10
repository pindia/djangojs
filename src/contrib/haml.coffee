hamlIdentifierRegexp = /^%([a-zA-Z0-9]+)*/
hamlModifierRegexp = /#([a-zA-Z0-9-]+)|\.([a-zA-Z0-9-]+)|\(([^\]\[]+)\)| (.+)/g

Templar.translateHaml = (text) ->
  indentStack = []
  tagStack = []
  output = []
  for line in text.split('\n')
    if line.trim().length == 0
      continue
    # Calculate indentation
    indent = 0
    for i in [0...line.length]
      if line[i] == ' '
        indent += 1
      else
        break
    # Close tags as appropriate for unindent
    while indent <= indentStack[indentStack.length-1]
      output.push "</#{tagStack.pop()}>"
      indentStack.pop()
    line = line.trim()
    if line[0] == '%'
      tagName = hamlIdentifierRegexp.exec(line)[1]
    else if line[0] in ['.', '#']
      tagName = 'div'
    else if line[0] == '\\'
      output.push line.slice(1)
      continue
    else
      output.push line
      continue
    attrs = {}
    attrsString = ''
    content = ''
    while m = hamlModifierRegexp.exec(line)
      if m[1]? # id
        attrs.id = m[1]
      if m[2]? # class
        if attrs.class?
          attrs.class += ' ' + m[2]
        else
          attrs.class = m[2]
      if m[3]?
        attrsString = m[3]
      if m[4]? # text
        content = m[4]
    attrsString += ("#{key}=\"#{attrs[key]}\"" for key of attrs).join(' ')
    console.log attrsString
    output.push "<#{tagName} #{attrsString}>"
    if content?
      output.push content
    tagStack.push tagName
    indentStack.push indent

  while tagStack.length # Close all unclosed tags
    output.push "</#{tagStack.pop()}>"
  return output.join('\n')