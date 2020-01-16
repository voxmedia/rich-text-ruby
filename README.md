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

