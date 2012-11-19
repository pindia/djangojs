
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

Extending
---------

DjangoJS exports the two objects `djangoJS.tags` and `djangoJS.filters` that allow you to define new tags and filters.

### Filters

A filter is a simple function that takes either one or two arguments. The first argument is the value to be filtered, and the second is the argument passed to the filter, if applicable. Register a filter by assigning to `djangoJS.filters`:

```javascript
djangoJS.filters['truncate'] = function(value, length){
    return value.substr(0, length);
};
djangoJS.filters['lower'] = function(value){
    return value.toLowerCase();
};
```

### Simple tags

A simple tag is a tag that simply takes a number of arguments and returns a string after doing some processing. To register a simple tag, start by writing a function that takes the full template context and any tag arguments, and returns the value to insert. Then pass this function to `djangoJS.simpleTag`, and assign the result to `djangoJS.tags`:

```javascript
djangoJS.tags['current_time'] = djangoJS.simpleTag(function(context, timeFormat){
    return moment().format(timeFormat);
});
```

Assuming [Moment.js](http://momentjs.com/) is available, this tag can be used like:

    {% current_time 'MMMM Do YYYY, h:mm:ss a' %}

and would output something like:

    November 18th 2012, 5:01:53 pm

Note that unlike variables, the output of simple tags is not subject to auto-escaping.

### Inclusion tags

An inclusion tag is a tag that takes a number of arguments and renders *another* template, inserting the full result into the original template.  To register an inclusion tag, start by creating the sub-template that will be rendered. Then write a function that takes the full original template context and any tag arguments, and returns a context object that will be used as the context for the sub-template. Then pass the template and function to `djangoJS.inclusionTag`, and assign the result to `djangoJS.tags`:

```javascript
var friendListTemplate = new djangoJS.Template('{% for friend in friends %}{{friend.name}}{% endfor %}');
djangoJS.tags['friend_list'] = djangoJS.inclusionTag(friendListTemplate, function(context, friends){
    return {friends: friends};
});
```

Now, assuming the current template has the `friends` variable defined in its context, this tag can be used like:

    {% friend_list friends %}

The inclusion tag will pass the value of `friends` through to the sub-template, render it, and insert the result into the original template. In this example the function simply passed `friends` through as-is, but it is free to do any sort of processing on the arguments. For example, we could take advantage of having direct access to the template context to eliminate the `friends` argument:

```javascript
djangoJS.tags['friend_list'] = djangoJS.inclusionTag(friendListTemplate, function(context){
    return {friends: context.friends};
});
```

The tag could now be called simply as:

    {% friend_list %}

However, this makes the tag much less flexible, since it assumes the existence of a context variable with the exact name  `friends`. It is generally better for a tag to accept arguments rather than inspect the context, although the option is there for the case of an unwieldy number of arguments.

### Assignment tags

An assignment tag is just like a simple tag, except that instead of outputting the computed result it stores it into another context variable. An assignment tag is created with  `djangoJS.assignmentTag`, and assigned to `djangoJS.tags`:

```javascript
djangoJS.tags['get_current_time'] = djangoJS.assignmentTag(function(context, timeFormat){
    return moment().format(timeFormat);
});
```

Assuming [Moment.js](http://momentjs.com/) is available, this tag can be used like:

    {% get_current_time 'MMMM Do YYYY, h:mm:ss a' as the_time %}
    The current time is {{the_time}}.

and would output something like:

    The current time is November 18th 2012, 5:01:53 pm.

### Raw tags

Up until now, we've been able to take advantage of convenience wrappers to register tags. But to make a more complex tag like the built-in `if` and `for` tags, we have to drop down a level of abstraction.

Internally, template processing is a two-step process. In the compilation step, the raw template string is translated into a series of `Node` objects, corresponding to tags, variables, and bits of raw text. Block tag `Node` objects have child nodes corresponding to the nodes contained within them. Then, in the rendering step, each `Node` determines what it should render, and parent nodes get to determine whether their child nodes should render zero times (`comment`, `if`), one time (`if`), or multiple times (`for`).

Writing a raw tag is a similarly two-step process. First, define a Node class that knows how to render itself, then write a compilation function that initializes and returns an instance of your Node class given the template parser state and a token corresponding to your tag invocation. Finally, assign your compilation function directly to `djangoJS.tags`.

Let's see what the `current_time` tag looks like as a raw tag:

```javascript
function CurrentTimeNode(timeFormat){
    this.render = function(context){
        return moment().format(timeFormat);
    };
}
djangoJS.tags['current-time'] = function(parser, token){
    var bits = token.splitContents();
    var timeFormat = bits[1];
    return new CurrentTimeNode(timeFormat);
};
```

Just like the simple tag, this can be invoked as

    {% current_time 'MMMM Do YYYY, h:mm:ss a' %}

The `Node` object returned by the compilation function is required to have a single method `render(context)`, which returns the text to be inserted given a context. The compilation function generates this node using methods of its arguments `parser` and `token`:

