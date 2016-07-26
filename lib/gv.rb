require 'gv/version'
require 'ffi'

module GV
  module Libcgraph
    extend FFI::Library

    ffi_lib 'cgraph'

    class AGraph < FFI::AutoPointer
      def self.release(ptr)
        Libcgraph.agclose(ptr) unless ptr.null?
      end
    end

    typedef :pointer, :ag_node
    typedef :pointer, :ag_edge

    attach_function :agmemread, [:string], AGraph
    attach_function :agopen, [:string, :long, :pointer], AGraph
    attach_function :agclose, [AGraph], :int

    attach_variable :Agundirected, :long
    attach_variable :Agstrictundirected, :long
    attach_variable :Agdirected, :long
    attach_variable :Agstrictdirected, :long

    attach_function :agnode, [AGraph, :string, :int], :ag_node
    attach_function :agedge, [AGraph, :ag_node, :ag_node, :string, :int], :ag_edge
    attach_function :agsubg, [AGraph, :string, :int], :pointer

    attach_function :agnameof, [:pointer], :string
    attach_function :agraphof, [:pointer], :pointer

    attach_function :agtail, [:ag_edge], :ag_node
    attach_function :aghead, [:ag_edge], :ag_node
    attach_function :agget, [:pointer, :string], :string

    attach_function :agsafeset, [:pointer, :string, :string, :string], :pointer
    attach_function :agstrdup_html, [AGraph, :string], :pointer
    attach_function :agstrfree, [AGraph, :pointer], :int

    attach_function :agisdirected, [AGraph], :int
    attach_function :agisstrict, [AGraph], :int
  end
  private_constant :Libcgraph

  module Libgvc
    extend FFI::Library
    ffi_lib 'gvc'

    typedef :pointer, :gvc

    attach_function :gvContext, [], :pointer
    attach_function :gvFreeLayout, [:gvc, Libcgraph::AGraph], :int
    attach_function :gvLayout, [:gvc, Libcgraph::AGraph, :string], :int

    attach_function :gvRenderFilename, [:gvc, Libcgraph::AGraph, :string, :string], :int
    attach_function :gvRenderData, [:gvc, Libcgraph::AGraph, :string, :pointer, :pointer], :int
    attach_function :gvFreeRenderData, [:pointer], :void
  end
  private_constant :Libgvc

  # Common super-class for edges, nodes and graphs
  class Component
    # @!visibility private
    @@gvc = Libgvc.gvContext

    # @return [Graph, SubGraph] the graph this component belongs to
    attr_reader :graph

    # Creates an HTML label
    # @param string [String] the HTML to parse
    # @return [Object] a HTML label
    def html(string)
      ptr = Libcgraph.agstrdup_html(graph.ptr, string)
      string = ptr.read_string
      Libcgraph.agstrfree graph.ptr, ptr

      string
    end

    def hash
      ptr.hash
    end

    def ==(other)
      other.is_a?(Component) && ptr == other.ptr
    end

    alias eql? ==

    # @return [String] the component's name
    def name
      Libcgraph.agnameof ptr
    end

    # Sets an attribute
    # @param attr [Symbol, String] attribute name
    # @see http://www.graphviz.org/doc/info/attrs.html Node, Edge and Graph Attributes
    # @param value [Object] attribute value
    def []=(attr, value)
      Libcgraph.agsafeset(ptr, attr.to_s, value.to_s, "")
    end

    # Retrieves the value of an attribute
    # @param attr [Symbol, String] attribute name
    # @see http://www.graphviz.org/doc/info/attrs.html Node, Edge and Graph Attributes
    # @return [Object] the attribute value
    def [](attr)
      Libcgraph.agget(ptr, attr.to_s)
    end

    protected
    attr_reader :ptr
  end

  # Represents a node in the graph
  class Node < Component
    def initialize(graph, name_or_ptr)
      @graph = graph
      @ptr =
        case name_or_ptr
        when String
          Libcgraph.agnode(graph.ptr, name_or_ptr, 1)
        else
          name_or_ptr
        end
    end
  end

  # Represents a connection between nodes
  class Edge < Component
    def initialize(graph, name, tail, head)
      @graph = graph

      @ptr = Libcgraph.agedge(graph.ptr, tail.ptr, head.ptr, name, 1)
    end

    # @return [Node] the head node of the edge
    def head
      Node.new @graph, Libcgraph.aghead(ptr)
    end

    # @return [Node] the tail node of the edge
    def tail
      Node.new @graph, Libcgraph.agtail(ptr)
    end
  end

  # Common super-class for graphs and sub-graphs
  class BaseGraph < Component

    # Creates a new node
    # @param name [String] the name (identifier) of the node
    # @param attrs [Hash{String, Symbol => Object}] the attributes 
    # to associate with this node
    # @see http://www.graphviz.org/doc/info/attrs.html Node, Edge and Graph Attributes
    # @return [Node] the newly created node
    def node(name, attrs = {})
      component Node, [name], attrs
    end

    # Creates a new edge
    # @param name [String] the name (identifier) of the edge
    # @param tail [Node] the edge's tail node
    # @param head [Node] the edge's head node
    # @param attrs [Hash{String, Symbol => Object}] the attributes
    # to associate with this edge
    # @see http://www.graphviz.org/doc/info/attrs.html Node, Edge and Graph Attributes
    # @return [Edge] the newly created edge
    def edge(name, tail, head, attrs = {})
      component Edge, [name, tail, head], attrs
    end

    # Creates a new sub-graph
    # @param name [String] the name (identifier) of the sub-graph
    # @param attrs [Hash{String, Symbol => Object}] the attributes
    # to associate with this sub-graph
    # @see http://www.graphviz.org/doc/info/attrs.html Node, Edge and Graph Attributes
    # @return [SubGraph] the newly created sub-graph
    def sub_graph(name, attrs = {})
      graph = component SubGraph, [name], attrs
      yield graph if block_given?

      graph
    end

    # @return whether this graph is directed
    def directed?
      Libcgraph.agisdirected(ptr) == 1
    end

    # @return whether this graph is strict
    def strict?
      Libcgraph.agisstrict(ptr) == 1
    end

    private

    def component(klass, args, attrs = {})
      comp = klass.new self, *args

      attrs.each do |attr, value|
        comp[attr] = value
      end

      comp
    end

  end

  # Represents a sub-graph
  class SubGraph < BaseGraph
    def initialize(graph, name)
      @graph = graph
      @ptr = Libcgraph.agsubg(graph.ptr, name, 1)
    end
  end

  # Represents a toplevel graph
  class Graph < BaseGraph

    class << self
      private :new

      # Creates a new graph
      # @param type [:directed, :undirected] the graphs type
      # @param strictness [:strict, :normal] the graphs strict type
      # @see http://www.graphviz.org/doc/info/attrs.html Node, Edge and Graph Attributes
      # @yieldparam graph [Graph] the newly created graph
      # @return [Graph] the newly created graph
      def open(name, type = :directed, strictness = :normal)
        ag_type = case [type, strictness]
                  when [:directed, :normal] then
                    Libcgraph.Agdirected
                  when [:undirected, :normal] then
                    Libcgraph.Agundirected
                  when [:directed, :strict] then
                    Libcgraph.Agstrictdirected
                  when [:undirected, :strict] then
                    Libcgraph.Agstrictundirected
                  else
                    raise ArgumentError, "invalid graph type #{[type, strictness]}"
                  end

        graph = new(Libcgraph.agopen(name, ag_type, FFI::Pointer::NULL))

        if block_given?
          yield graph
        end

        graph
      end

      # Loads a graph from a string of file
      # @param io [IO, String] the resource to load from
      # @return the newly loaded graph
      def load(io)
        data = if io.is_a? String
                 io
               else
                 io.read
               end
        new Libcgraph.agmemread(data)
      end
    end

    def initialize(ptr)
      @ptr = ptr
    end

    def graph
      self
    end

    # Renders the graph to an images and saves the result to a file
    # @param filename [String] the filename
    # @param format [String] the image format to use, e.g. 'svg', 'pdf' etc.
    # @param layout [String] the layout to use, e.g. 'dot' or 'neato' etc.
    # @return [nil]
    def save(filename, format = 'png', layout = 'dot')
      Libgvc.gvLayout(@@gvc, ptr, layout.to_s)
      Libgvc.gvRenderFilename(@@gvc, ptr, format.to_s, filename);
      Libgvc.gvFreeLayout(@@gvc, ptr)

      nil
    end

    # Renders the graph to an image and returns the result as a string
    # @param format [String] the image format to use, e.g. 'svg', 'pdf' etc.
    # @param layout [String] the layout to use, e.g. 'dot' or 'neato' etc.
    # @return [String] the rendered graph in the given format
    def render(format = 'png', layout = 'dot')
      Libgvc.gvLayout(@@gvc, ptr, layout.to_s)

      data_ptr = FFI::MemoryPointer.new(:pointer, 1)
      len_ptr = FFI::MemoryPointer.new(:int, 1)

      Libgvc.gvRenderData(@@gvc, ptr, format.to_s, data_ptr, len_ptr)
      len = len_ptr.read_uint
      data_ptr = data_ptr.read_pointer

      data = data_ptr.read_string len

      Libgvc.gvFreeRenderData(data_ptr)
      Libgvc.gvFreeLayout(@@gvc, ptr)

      data
    end
  end
end
