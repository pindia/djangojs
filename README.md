
DjangoJS
========

DjangoJS is an implementation of the [Django template language](https://docs.djangoproject.com/en/1.4/topics/templates/) in JavaScript.
As with Django templates, it is not possible to embed raw JavaScript code into templates, but it is easy to extend with custom template tags and filters.

### Usage

```javascript
>>> var template = new djangoJS.Template('{{variable}}');
>>> var context = {variable: 42};
>>> template.render(context);
"42"
```

Templates
---------

A template is a string which contains **variables**, which get replaced with values when the template is rendered, and **tags**, which control the logic of the template.

Below is an example template that illustrates the basics:

```django

{% if message %}
    <h1>{{message|upper}}</h1>
{% endif %}

{% for friend in friends %}
    {{friend.name}}: {{friend.online|yesno:'online,offline'}}
{% empty %}
    No friends found.
{% endfor %}

```

### Variables

Insert a variable into the template with the syntax `{{variable}}`. When the template engine encounters a variable, it looks up its name in the context object passed to the `Template` object's `render` method.

Variable names can consist of alphanumeric characters and underscores, but variable names starting with an underscore are reserved for internal use. Dot-separated variable names like `variable.foo` can be used to look up attributes of subobjects of the context object. If the value of a variable is a function, the function will be called with no arguments.

Note that variables are *not* arbitrary JavaScript expressions. Variables cannot be used to look up attributes from the global scope, call functions with arguments, or evaluate arithmetic expressions.

### Filters

You can modify variables for display using **filters**.

Apply a filter to a variable with the syntax `{{name|lower}}`. That displays the value of the variable `name` passed through the `lower` filter, which converts string to lowercase.

Some filters take arguments with the syntax `{{name|default:"nobody"}}`. The `default` filter displays the value passed through it unless it is empty or false, in which case is displays its argument.

Multiple filters can be chained, with the output of one filter applied to the next. `{{name|lower|default:"nobody"}}` will convert `name` to lowercase, or display `nobody` if it is empty.

### Automatic Escaping

To protect against [Cross-site scripting](http://en.wikipedia.org/wiki/Cross-site_scripting) attacks, all template variables are automatically HTML-escaped before being output. This means that the template:

    Hello, {{name}}
    
rendered with the value of `name` being `<script>alert('hello')</script>` will be rendered as:

    Hello, &lt;script&gt;alert(&#39;hello&#39;)&lt;/script&gt;
    
preventing the user from injecting JavaScript into the rendered document. To disable this behavior, mark the variable as safe using the `safe` template filter:

    Hello, {{name|safe}}
    
`safe` should be the last filter in the sequence, because any further modification to the string marked safe will remove the marking.