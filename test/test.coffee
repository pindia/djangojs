renderTemplate = (template, context={}) ->
  t = new djangoJS.Template(template)
  return t.render(context)

equalIgnoreSpace = (a, b, msg=undefined) ->
  return equal(a.replace(/\s+/g, ""), b.replace(/\s+/g, ""), msg)

test 'basic use', ->
  equal(renderTemplate('{{variable}}', {variable: 42}), '42')

test 'if tag', ->
  t = new djangoJS.Template '''
    {% if i == 6 %}
      Equals 6
    {% elif i == 7 %}
      Equals 7
    {% else %}
      None of the above
    {% endif %}
  '''
  equalIgnoreSpace(t.render({i: 6}), 'Equals 6')
  equalIgnoreSpace(t.render({i: 7}), 'Equals 7')
  equalIgnoreSpace(t.render({i: 8}), 'None of the above')


test 'for tag', ->
  t = new djangoJS.Template '''
  {% for i in seq %}
      <li>{{forloop.counter}}: {{i}}</li>
  {% empty %}
    No items.
  {% endfor %}
  '''
  equalIgnoreSpace(t.render({seq: ['a', 'b', 'c']}), '<li>1: a</li><li>2: b</li><li>3: c</li>')
  equalIgnoreSpace(t.render({seq: []}), 'No items.')
  equalIgnoreSpace(t.render({}), 'No items.')
  throws ->
    new djangoJS.template '{% for i seq %}{% endfor %}'

test 'nested for tags', ->
  t = new djangoJS.Template '''
  {% for i in seq1 %}
    {% for j in seq2 %}
      {{forloop.parentloop.counter}}, {{forloop.counter}}, {{i}}, {{j}}
    {% endfor %}
  {% endfor %}
  '''
  equalIgnoreSpace(t.render({seq1: ['a', 'b'], seq2: ['c', 'd']}), '1, 1, a, c 1, 2, a, d 2, 1, b, c 2, 2, b, d')

test 'filters', ->
  t = new djangoJS.Template '{{variable|lower}}'
  equalIgnoreSpace(t.render({variable: 'Test'}), 'test')
  t = new djangoJS.Template '{{"Test"|lower}}'
  equalIgnoreSpace(t.render({}), 'test')
  t = new djangoJS.Template '{{variable|default:"test"}}'
  equalIgnoreSpace(t.render({variable: 'Test'}), 'Test')
  equalIgnoreSpace(t.render({}), 'test')

test 'auto-escaping', ->
  t = new djangoJS.Template '{{variable}}'
  equalIgnoreSpace(t.render({variable: '<b>hi</b>'}), '&lt;b&gt;hi&lt;/b&gt;', 'automatic escape')
  t = new djangoJS.Template '{{variable|safe}}'
  equalIgnoreSpace(t.render({variable: '<b>hi</b>'}), '<b>hi</b>', 'automatic escape suppressed')
  t = new djangoJS.Template('{{"<b>hi</b>"}}')
  equalIgnoreSpace(t.render({}), '<b>hi</b>', 'literal string not affected')

test 'simple tag', ->
  djangoJS.tags['say_hello'] = djangoJS.simpleTag (context, name) ->
    return "Hello, #{name}!"
  equalIgnoreSpace(renderTemplate("{% say_hello 'World' %}"), 'Hello, World!')
  equalIgnoreSpace(renderTemplate("{% say_hello language %}", {language: 'Django'}), 'Hello, Django!')

test 'inclusion tag', ->
  t = new djangoJS.Template 'Hello, {{name}}!'
  djangoJS.tags['say_hello'] = djangoJS.inclusionTag t, (context, name) ->
    return {name: name}
  equalIgnoreSpace(renderTemplate("{% say_hello 'World' %}"), 'Hello, World!')
  equalIgnoreSpace(renderTemplate("{% say_hello language %}", {language: 'Django'}), 'Hello, Django!')

test 'assignment tag', ->
  djangoJS.tags['get_hello'] = djangoJS.assignmentTag (context, name) ->
    return "Hello, #{name}!"
  equalIgnoreSpace(renderTemplate("{% get_hello 'World' as greeting %}{{greeting}}"), 'Hello, World!')
  equalIgnoreSpace(renderTemplate("{% get_hello language as greeting %}{{greeting}}", {language: 'Django'}), 'Hello, Django!')