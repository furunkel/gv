# GV

Ruby bindings for libgvc (Graphviz) using FFI.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gv'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install gv

## Usage

### Create new graph:
```ruby
require 'gv'

graph = GV::Graph.open 'g'
graph.edge 'e', graph.node('A'), graph.node('B', shape: 'polygon')

# render to string
graph.render 'png'

# or to a file
graph.write 'result.png'
```

#### Result 
![resilt](/spec/render.png)
  
### Load existing graph from `.dot` file:
```ruby
require 'gv'

graph = GV::Graph.load File.open('g.dot')

# render graph
graph.render
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/gv/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
