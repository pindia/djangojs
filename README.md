
Templar
========

Templar is an implementation of the [Django template language](https://docs.djangoproject.com/en/1.4/topics/templates/) in JavaScript.
As with Django templates, it is not possible to embed raw JavaScript code into templates, but it is easy to extend with custom template tags and filters.

### Usage

```javascript
>>> var template = new Templar.Template('{{variable}}');
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

Templar exports the two objects `Templar.tags` and `Templar.filters` that allow you to define new tags and filters.

### Filters

A filter is a simple function that takes either one or two arguments. The first argument is the value to be filtered, and the second is the argument passed to the filter, if applicable. Register a filter by assigning to `Templar.filters`:

```javascript
Templar.filters['truncate'] = function(value, length){
    return value.substr(0, length);
};
Templar.filters['lower'] = function(value){
    return value.toLowerCase();
};
```

### Simple tags

A simple tag is a tag that simply takes a number of arguments and returns a string after doing some processing. To register a simple tag, start by writing a function that takes the full template context and any tag arguments, and returns the value to insert. Then pass this function to `Templar.simpleTag`, and assign the result to `Templar.tags`:

```javascript
Templar.tags['current_time'] = Templar.simpleTag(function(context, timeFormat){
    return moment().format(timeFormat);
});
```

Assuming [Moment.js](http://momentjs.com/) is available, this tag can be used like:

    {% current_time 'MMMM Do YYYY, h:mm:ss a' %}

and would output something like:

    November 18th 2012, 5:01:53 pm

Note that unlike variables, the output of simple tags is not subject to auto-escaping.

### Inclusion tags

An inclusion tag is a tag that takes a number of arguments and renders *another* template, inserting the full result into the original template.  To register an inclusion tag, start by creating the sub-template that will be rendered. Then write a function that takes the full original template context and any tag arguments, and returns a context object that will be used as the context for the sub-template. Then pass the template and function to `Templar.inclusionTag`, and assign the result to `Templar.tags`:

```javascript
var friendListTemplate = new Templar.Template('{% for friend in friends %}{{friend.name}}{% endfor %}');
Templar.tags['friend_list'] = Templar.inclusionTag(friendListTemplate, function(context, friends){
    return {friends: friends};
});
```

Now, assuming the current template has the `friends` variable defined in its context, this tag can be used like:

    {% friend_list friends %}

The inclusion tag will pass the value of `friends` through to the sub-template, render it, and insert the result into the original template. In this example the function simply passed `friends` through as-is, but it is free to do any sort of processing on the arguments. For example, we could take advantage of having direct access to the template context to eliminate the `friends` argument:

```javascript
Templar.tags['friend_list'] = Templar.inclusionTag(friendListTemplate, function(context){
    return {friends: context.friends};
});
```

The tag could now be called simply as:

    {% friend_list %}

However, this makes the tag much less flexible, since it assumes the existence of a context variable with the exact name  `friends`. It is generally better for a tag to accept arguments rather than inspect the context, although the option is there for the case of an unwieldy number of arguments.

### Assignment tags

An assignment tag is just like a simple tag, except that instead of outputting the computed result it stores it into another context variable. An assignment tag is created with  `Templar.assignmentTag`, and assigned to `Templar.tags`:

```javascript
Templar.tags['get_current_time'] = Templar.assignmentTag(function(context, timeFormat){
    return moment().format(timeFormat);
});
```

Assuming [Moment.js](http://momentjs.com/) is available, this tag can be used like:

    {% get_current_time 'MMMM Do YYYY, h:mm:ss a' as the_time %}
    The current time is {{the_time}}.

and would output something like:

    The current time is November 18th 2012, 5:01:53 pm.

Note that because the value of assignment tags are output with normal variables, they are subject to auto-escaping.

### Raw tags

Up until now, we've been able to take advantage of convenience wrappers to register tags. But to make a more complex tag like the built-in `if` and `for` tags, we have to drop down a level of abstraction.

Internally, template processing is a two-step process. In the compilation step, the raw template string is translated into a series of `Node` objects, corresponding to tags, variables, and bits of raw text. Block tag `Node` objects have child nodes corresponding to the nodes contained within them. Then, in the rendering step, each `Node` determines what it should render, and parent nodes get to determine whether their child nodes should render zero times (`comment`, `if`), one time (`if`), or multiple times (`for`).

Writing a raw tag is a similarly two-step process. First, define a Node class that knows how to render itself, then write a compilation function that initializes and returns an instance of your Node class given the template parser state and a token corresponding to your tag invocation. Finally, assign your compilation function directly to `Templar.tags`.

Let's see what the `current_time` tag looks like as a raw tag:

```javascript
function CurrentTimeNode(timeFormat){
    var expr = new Templar.FilterExpression(timeFormat);
    this.render = function(context){
        return moment().format(expr.resolve(context));
    };
}
Templar.tags['current_time'] = function(parser, token){
    var bits = token.splitContents();
    var timeFormat = bits[1];
    return new CurrentTimeNode(timeFormat);
};
```

Just like the simple tag, this can be invoked as

    {% current_time 'MMMM Do YYYY, h:mm:ss a' %}

The `Node` object returned by the compilation function is required to have a single method `render(context)`, which returns the text to be inserted given a context. The compilation function generates a node using methods of the `token` argument:

* `token.contents`: The raw contents of the tag invocation, including the tag name but not including the tag delimiters. In this example `"current_time 'MMMM Do YYYY, h:mm:ss a'"`.
* `token.splitContents()`: The contents of the tag, split on spaces not enclosed in quotes. Use this instead of `token.contents.split(' ')`. In this example `["current_time", "'MMMM Do YYYY, h:mm:ss a'"]`.

The compilation function splits out the argument to `current_time` and passes it to the node as `timeFormat`. The node constructor then creates a `FilterExpression` from the format. This object is responsible for resolving the expression into a value at render time. In the case of a literal string it simply returns the string, but if the argument was a variable it would be looked up in the context. And in both cases, any filters applied are parsed at compile time and executed at run time.

Clearly this example is more elegant as a simple tag. Let's look at an example that must be done this way: a tag `{% upper %}...{% endupper %}` that transforms its contents to uppercase.

```javascript
function UpperNode(nodelist){
    this.render = function(context){
        return nodelist.render(context).toUpperCase();
    };
}
Templar.tags['upper'] = function(parser, token){
    var nodelist = parser.parse(['endupper']);
    parser.nextToken()
    return new UpperNode(nodelist);
}
```

Here the compilation function is using methods of the `parser` argument:

* `parser.parse(endTags)`: Parses nodes until one of the tags specified in the endTags array is encountered, returning a `NodeList` of all nodes parsed. Leaves the end tag in the parser.
* `parser.nextToken()`: Parses the next token and returns it.
* `parser.skipPast(endTag)`: Parses nodes until the specified endTag, throwing away the result. Differs from `parse` in that it will not choke on invalid or unbalanced tags.

The compilation function first uses `parse` to parse until the `endupper` tag. This leaves the `endupper` tag in the parser, so `nextToken` clears it out. In some cases the token would need to be saved and examined to distinguish between different close tags, but here it is not necessary. The `UpperNode` is passed the nodelist consisting of the block body.

The `UpperNode` itself simply renders its child nodelist normally, then calls `toUpperCase()` on it before returning it.

