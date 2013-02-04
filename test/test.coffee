renderTemplate = (template, context={}) ->
  t = new Templar.Template(template)
  return t.render(context)

equalIgnoreSpace = (a, b, msg=undefined) ->
  return equal(a.replace(/\s+/g, ""), b.replace(/\s+/g, ""), msg)

test 'basic use', ->
  equal(renderTemplate('{{variable}}', {variable: 42}), '42')

test 'if tag', ->
  t = new Templar.Template '''
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
  t = new Templar.Template '''
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
    new Templar.template '{% for i seq %}{% endfor %}'

test 'nested for tags', ->
  t = new Templar.Template '''
  {% for i in seq1 %}
    {% for j in seq2 %}
      {{forloop.parentloop.counter}}, {{forloop.counter}}, {{i}}, {{j}}
    {% endfor %}
  {% endfor %}
  '''
  equalIgnoreSpace(t.render({seq1: ['a', 'b'], seq2: ['c', 'd']}), '1, 1, a, c 1, 2, a, d 2, 1, b, c 2, 2, b, d')

test 'verbatim tag', ->
  t = new Templar.Template '''
    {% verbatim %}
      {% if x == 2 %}
        Test
      {% endif %}
    {% endverbatim %}
    {% if x == 2 %}
      Equals 2
    {% endif %}
  '''
  equalIgnoreSpace(t.render({x: 0}), '{% if x == 2 %}Test{% endif %}')
  equalIgnoreSpace(t.render({x: 2}), '{% if x == 2 %}Test{% endif %}Equals 2')

test 'filter tag', ->
  t = new Templar.Template '''
    {% filter lower %}
      Some test content {% if x == 5 %} INNER CONTENT {% endif %}
    {% endfilter %}
  '''
  equalIgnoreSpace(t.render({x: 5}), 'some test content inner content')

test 'filters', ->
  t = new Templar.Template '{{variable|lower}}'
  equalIgnoreSpace(t.render({variable: 'Test'}), 'test')
  t = new Templar.Template '{{"Test"|lower}}'
  equalIgnoreSpace(t.render({}), 'test')
  t = new Templar.Template '{{variable|default:"test"}}'
  equalIgnoreSpace(t.render({variable: 'Test'}), 'Test')
  equalIgnoreSpace(t.render({}), 'test')

test 'yesno filter', ->
  equal(renderTemplate('{{x|yesno}}', {x: true}), 'yes')
  equal(renderTemplate('{{x|yesno}}', {x: false}), 'no')
  equal(renderTemplate('{{x|yesno}}', {x: null}), 'no')
  equal(renderTemplate('{{x|yesno}}', {x: undefined}), 'no')
  equal(renderTemplate('{{x|yesno:"affirmative,negative"}}', {x: true}), 'affirmative')
  equal(renderTemplate('{{x|yesno:"affirmative,negative"}}', {x: false}), 'negative')
  equal(renderTemplate('{{x|yesno:"affirmative,negative"}}', {x: null}), 'negative')
  equal(renderTemplate('{{x|yesno:"affirmative,negative"}}', {x: undefined}), 'negative')
  equal(renderTemplate('{{x|yesno:"affirmative,negative,unknown"}}', {x: true}), 'affirmative')
  equal(renderTemplate('{{x|yesno:"affirmative,negative,unknown"}}', {x: false}), 'negative')
  equal(renderTemplate('{{x|yesno:"affirmative,negative,unknown"}}', {x: null}), 'unknown')
  equal(renderTemplate('{{x|yesno:"affirmative,negative,unknown"}}', {x: undefined}), 'unknown')

test 'pluralize filter', ->
  equal(renderTemplate('{{n}} second{{n|pluralize}}', {n: 1}), '1 second')
  equal(renderTemplate('{{n}} second{{n|pluralize}}', {n: 2}), '2 seconds')
  equal(renderTemplate('{{n}} walrus{{n|pluralize}}', {n: 1}), '1 walrus')
  equal(renderTemplate('{{n}} walrus{{n|pluralize:"es"}}', {n: 2}), '2 walruses')
  equal(renderTemplate('{{n}} {{n|pluralize:"person,people"}}', {n: 1}), '1 person')
  equal(renderTemplate('{{n}} {{n|pluralize:"person,people"}}', {n: 2}), '2 people')

test 'auto-escaping', ->
  t = new Templar.Template '{{variable}}'
  equalIgnoreSpace(t.render({variable: '<b>hi</b>'}), '&lt;b&gt;hi&lt;/b&gt;', 'automatic escape')
  t = new Templar.Template '{{variable|safe}}'
  equalIgnoreSpace(t.render({variable: '<b>hi</b>'}), '<b>hi</b>', 'automatic escape suppressed')
  t = new Templar.Template('{{"<b>hi</b>"}}')
  equalIgnoreSpace(t.render({}), '<b>hi</b>', 'literal string not affected')

test 'comments', ->
  equalIgnoreSpace(renderTemplate('Hello {# World #} Django!'), 'Hello Django!')
  equalIgnoreSpace(renderTemplate('Hello {# {% test %} {{ %} #} Django!'), 'Hello Django!')
  equalIgnoreSpace(renderTemplate('Hello {% comment %} World \n {% test %} }} {% endcomment %} Django!'), 'Hello Django!')

test 'simple tag', ->
  Templar.tags['say_hello'] = Templar.simpleTag (context, name) ->
    return "Hello, #{name}!"
  equalIgnoreSpace(renderTemplate("{% say_hello 'World' %}"), 'Hello, World!')
  equalIgnoreSpace(renderTemplate("{% say_hello language %}", {language: 'Django'}), 'Hello, Django!')

test 'inclusion tag', ->
  t = new Templar.Template 'Hello, {{name}}!'
  Templar.tags['say_hello'] = Templar.inclusionTag t, (context, name) ->
    return {name: name}
  equalIgnoreSpace(renderTemplate("{% say_hello 'World' %}"), 'Hello, World!')
  equalIgnoreSpace(renderTemplate("{% say_hello language %}", {language: 'Django'}), 'Hello, Django!')

test 'assignment tag', ->
  Templar.tags['get_hello'] = Templar.assignmentTag (context, name) ->
    return "Hello, #{name}!"
  equalIgnoreSpace(renderTemplate("{% get_hello 'World' as greeting %}{{greeting}}"), 'Hello, World!')
  equalIgnoreSpace(renderTemplate("{% get_hello language as greeting %}{{greeting}}", {language: 'Django'}), 'Hello, Django!')