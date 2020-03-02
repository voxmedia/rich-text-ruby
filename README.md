# Rich Text

![tests status](https://github.com/voxmedia/rich-text-ruby/workflows/tests/badge.svg)

Ported from https://github.com/quilljs/delta, this library provides an elegant way of creating, manipulating, iterating, and transforming rich-text deltas and documents with a ruby-native API.

rich-text (aka Quill delta) is a format for representing attributed text. It aims to be intuitive and human readable with the ability to express any possible document or diff between documents.

This format is suitable for [operational transformation](https://en.wikipedia.org/wiki/Operational_transformation) and defines several functions ([`compose`](#compose), [`transform`](#transform), [`transform_position`](#transform-position), and [`diff`](#diff)) to support this use case.

For more information on the format itself, please consult the original README: https://github.com/quilljs/delta

## Docs

Please see the generated [API docs](https://www.rubydoc.info/gems/rich-text) for more details on all of the available classes and methods.

## TODO

- Implement `Delta#include?(other)`
- Finish writing tests

## Quick Example

```ruby
gandalf = RichText::Delta.new([
  { insert: 'Gandalf', attributes: { bold: true } },
  { insert: ' the ' },
  { insert: 'Grey', attributes: { color: '#ccc' } }
])
# => #<RichText::Delta [insert="Gandalf" {"bold"=>true}, insert=" the ", insert="Grey" {"color"=>"#ccc"}]>

# Keep the first 12 characters, delete the next 4, and insert a white 'White'
death = RichText::Delta.new
                       .retain(12)
                       .delete(4)
                       .insert('White', { color: '#fff' })
# => #<RichText::Delta [retain=12, delete=4, insert="White" {:color=>"#fff"}]>

gandalf.compose(death)
# => #<RichText::Delta [insert="Gandalf" {"bold"=>true}, insert=" the ", insert="White" {:color=>"#fff"}]>
```

## Operations

### Insert Operation

Insert operations have an `insert` key defined. A String value represents inserting text. Any other type represents inserting an embed (however only one level of object comparison will be performed for equality).

In both cases of text and embeds, an optional `attributes` key can be defined with an Hash to describe additonal formatting information. Formats can be changed by the [retain](#retain) operation.

```ruby
# Insert a bolded "Text"
{ insert: "Text", attributes: { bold: true } }

# Insert a link
{ insert: "Google", attributes: { link: 'https://www.google.com' } }

# Insert an embed
{
  insert: { image: 'https://octodex.github.com/images/labtocat.png' },
  attributes: { alt: "Lab Octocat" }
}

# Insert another embed
{
  insert: { video: 'https://www.youtube.com/watch?v=dMH0bHeiRNg' },
  attributes: {
    width: 420,
    height: 315
  }
}
```

### Delete Operation

Delete operations have a Number `delete` key defined representing the number of characters to delete. All embeds have a length of 1.

```ruby
# Delete the next 10 characters
{ delete: 10 }
```

### Retain Operation

Retain operations have a Number `retain` key defined representing the number of characters to keep (other libraries might use the name keep or skip). An optional `attributes` key can be defined with an Hash to describe formatting changes to the character range. A value of `null` in the `attributes` Hash represents removal of that key.

*Note: It is not necessary to retain the last characters of a document as this is implied.*

```ruby
# Keep the next 5 characters
{ retain: 5 }

# Keep and bold the next 5 characters
{ retain: 5, attributes: { bold: true } }

# Keep and unbold the next 5 characters
# More specifically, remove the bold key in the attributes Hash
# in the next 5 characters
{ retain: 5, attributes: { bold: null } }
```

## HTML Formatting

Rich-text deltas may be formatted as HTML by calling `delta.to_html`. The rendered markup will be generated based on formatting rules configured for the `RichText` module.

### Inline formats

Inline formatting rules are used to build tags for the flow of content elements.

```ruby
# Config:
RichText.configure do |c|
  c.html_default_block_format = 'p'
  c.html_inline_formats = {
    bold:        { tag: 'strong' },
    italic:      { tag: 'em' },
    br:          { tag: 'br' },
    link:        { tag: 'a', apply: ->(el, op, ctx){ el[:href] = op.attributes[:link] } }
  }
end

# Delta:
[
  { insert: "a man," },
  { insert: "\n", attributes: { br: true } },
  { insert: "a plan", attributes: { bold: true, italic: true } },
  { insert: "\n" },
  { insert: "panama\n", attributes: { link: 'https://visitpanama.com' } }
]

# HTML result:
%(
  <p>a man,<br><strong><em>a plan</em></strong></p>
  <p><a href="https://visitpanama.com">panama</a></p>
)
```

Each newline (`"\n"`) character denotes a block separation, at which time the inline flow will be wrapped in a block tag specified by `html_default_block_format`. An inline element's block wrapper maybe customized or omitted using the `block_format` setting. For soft or visible line breaks such as `br` or `hr` tags, you may assign them inline formats to render them as content flow.

```ruby
# Config:
RichText.configure do |c|
  c.html_default_block_format = 'p'
  c.html_inline_formats = {
    hr:    { tag: 'hr', block_format: false },
    code:  { tag: 'code', block_format: 'div' }
  }
end

# Delta:
[
  { insert: "sample code" },
  { insert: "\n", attributes: { hr: true } },
  { insert: "published = true", attributes: { code: true } },
  { insert: "\n" }
]

# HTML result:
%(
  <p>sample code</p>
  <hr>
  <div><code>published = true</code></div>
)
```

### Block formats

Block tags are wrapped around a flow of elements whenever a newline is encountered (unless it has an inline format). Block formats should always apply to newline (`"\n"`) inserts.

```ruby
RichText.configure do |c|
  c.html_block_formats = {
    firstheader: { tag: 'h1' },
    bullet:      { tag: 'li', parent: 'ul' },
    id:          { apply: ->(el, op, ctx){ el[:id] = op.attributes[:id] } }
  }
end

# Delta:
[
  { insert: "Blocks are fun" },
  { insert: "\n", attributes: { firstheader: true, id: 'blockfun' } },
  { insert: "item 1" },
  { insert: "\n", attributes: { bullet: true } },
  { insert: "item 2" },
  { insert: "\n", attributes: { bullet: true } }
]

# HTML result:
%(
  <h1 id="blockfun">Blocks are fun</h1>
  <ul>
    <li>item 1</li>
    <li>item 2</li>
  </ul>
)
```

Block tags may define a `parent` tag, or an array of parents. When a block has a parent, its full parent tree is constructed and/or merged with a compatible node tree that preceeds it.

### Formatting lambdas

Use `build` and `apply` lambdas to customize tag structures.

```ruby
# Config:
RichText.configure do |c|
  c.html_default_block_format = 'p'
  c.html_inline_formats = {
    image: {
      tag: 'img',
      block_format: false,
      build: ->(el, op, ctx){
        el[:src] = op.value[:image][:src]
        el.wrap('<figure/>')
        el.after(%(<figcaption>#{ op.value[:image][:caption] }</figcaption>))
        el.parent
      }
    },
    link: {
      tag: 'a',
      apply: ->(el, op, ctx){ el[:href] = op.attributes[:link] }
    }
  }
end

# Delta:
[
  { insert: { image: { src: 'https://placekitten.com/100/100', caption: 'cute' } } },
  { insert: "\n" },
  { insert: "more kittens", attributes: { link: 'https://placekitten.com' } },
  { insert: "\n" }
]

# HTML result:
%(
  <figure>
    <img src="https://placekitten.com/100/100">
    <figcaption>cute</figcaption>
  </figure>
  <p><a href="https://placekitten.com">more kittens</a></p>
)
```

A `build` lambda is called once when an element is created. The build lambda returns a customized node structure, or nil to render nothing. An `apply` lambda is called on each formatting rule applied to an element. An apply lambda does not return a value.

**Both `build` and `apply` receive the same arguments:**

- `el`: the new [Nokogiri::XML::Node](https://www.rubydoc.info/github/sparklemotion/nokogiri/Nokogiri/XML/Node) instance being rendered. Its tag type is already set by the formatting rule.
- `op`: the `RichText::Op` instance being rendered. You may references its `attributes` and `value`.
- `ctx`: an optional context object passed via `delta.to_html(context: obj)`. Providing a render context allows data to be shared across all formatting functions.
