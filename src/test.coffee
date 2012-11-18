$ ->

  $('#render').click ->
    template = $('#template').val()
    context = $('#context').val()
    localStorage.setItem('template', template)
    localStorage.setItem('context', context)

    try
      l = new djangoJS.Template(template)
      $('#output').val(l.render(JSON.parse(context)))
    catch e
      console.log e
      console.log $('#output').val(e.toString())

  template = localStorage.getItem('template')
  if template
    $('#template').val(template)
  context = localStorage.getItem('context')
  if context
    $('#context').val(context)
    $('#render').click()
