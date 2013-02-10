hamlIdentifierRegexp = /^%?([a-zA-Z0-9]+)*/
hamlModifierRegexp = /#([a-zA-Z0-9-]+)|\.([a-zA-Z0-9-]+)|\[([^\]\[]+)\]| (.+)/g

Array.prototype.peek = ->
  return this[this.length-1]

this.performTranslateHaml = (text) ->
  indentStack = []
  elemStack = []
  for line in text.split('\n')
    if line.trim().length == 0
      continue
    indent = 0
    for i in [0...line.length]
      if line[i] == ' '
        indent += 1
      else
        break
    line = line.trim()
    if line[0] == '/'
      continue
    # Determine tag name
    tagName = hamlIdentifierRegexp.exec(line)[1]
    if not tagName?
      tagName = 'div'
    # Create element
    elem = $(document.createElement(tagName))
    # Apply modifiers
    hamlModifierRegexp.lastIndex = 0
    while true
      m = hamlModifierRegexp.exec(line)
      if not m?
        break
      if m[1]? # #id
        elem.attr('id', m[1])
      if m[2]? # .class
        elem.addClass(m[2])
      if m[3]? # [attr=value]
        comps = m[3].split('=')
        attr = comps[0]
        value = comps.slice(1).join('=')
        elem.attr(attr, value)
      if m[4]? # (space)Text
        elem.html(m[4])
    # Insert element into correct position
    #console.log indent, indentStack
    #console.log elemStack
    if elemStack.length == 0
      elemStack.push elem
      indentStack.push indent
    else if indent == indentStack.peek()
      #console.log 'insert', elem, 'after', elemStack.peek()
      elemStack.peek().after(elem)
      elemStack.pop()
      elemStack.push(elem)
    else if indent > indentStack.peek()
      #console.log 'insert', elem, 'in', elemStack.peek()
      elemStack.peek().append(elem)
      indentStack.push indent
      elemStack.push elem
    else # Unindent
      while indent < indentStack.peek() # Pop until correct indent level reached
        indentStack.pop()
        elemStack.pop()
      #console.log 'insert', elem, 'after', elemStack.peek()
      elemStack.peek().after(elem)
      elemStack.pop()
      elemStack.push(elem)

  return $('<div></div>').append(elemStack[0]).html()