require 'gv/version'
require 'ffi'

module GV

  module LibCGraph
    extend FFI::Library

    ffi_lib 'cgraph'

    class AGraph < FFI::AutoPointer
      def self.release(ptr)
        LibCGraph.agclose(ptr) unless ptr.null?
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
  private_constant :LibCGraph

  module LibGVC
    extend FFI::Library
    ffi_lib 'gvc'

    typedef :pointer, :gvc

    attach_function :gvContext, [], :pointer
    attach_function :gvFreeLayout, [:gvc, LibCGraph::AGraph], :int
    attach_function :gvLayout, [:gvc, LibCGraph::AGraph, :string], :int

    attach_function :gvRenderFilename, [:gvc, LibCGraph::AGraph, :string, :string], :int
    attach_function :gvRenderData, [:gvc, LibCGraph::AGraph, :string, :pointer, :pointer], :int
    attach_function :gvFreeRenderData, [:pointer], :void
  end
  private_constant :LibGVC

  class Component
    # @!visibility private
    @@gvc = LibGVC.gvContext()

    # @return [Graph, SubGraph] the graph this component belongs to
    attr_reader :graph

    # Creates an HTML label
    # @param string [String] the HTML to parse
    # @return [Object] a HTML label
    def html(string)
      ptr = LibCGraph.agstrdup_html(graph.ptr, string)
      string = ptr.read_string
      LibCGraph.agstrfree graph.ptr, ptr

      string
    end

    def hash
      ptr.hash
    end

    def ==(other)
      other.is_a?(Component) && ptr == other.ptr
    end

    alias :eql? :== 

    # @return [String] the component's name
    def name
      LibCGraph.agnameof ptr
    end

    # Sets an attribute
    # @param attr [Symbol, String] attribute name
    # @see http://www.graphviz.org/doc/info/attrs.html Node, Edge and Graph Attributes
    # @param value [Object] attribute value
    def []=(attr, value)
      LibCGraph.agsafeset(ptr, attr.to_s, value.to_s, "")
    end

    # Retrieves the value of an attribute
    # @param attr [Symbol, String] attribute name
    # @see http://www.graphviz.org/doc/info/attrs.html Node, Edge and Graph Attributes
    # @return [Object] the attribute value
    def [](attr)
      LibCGraph.agget(ptr, attr.to_s)
    end

    protected
    attr_reader :ptr
  end

  class Node < Component
    def initialize(graph, name_or_ptr)
      @graph = graph
      case name_or_ptr
      when String
        @ptr = LibCGraph.agnode(graph.ptr, name_or_ptr, 1)
      else
        @ptr = name_or_ptr
      end
    end
  end

  class Edge < Component
    def initialize(graph, name, tail, head)
      @graph = graph

      @ptr = LibCGraph.agedge(graph.ptr, tail.ptr, head.ptr, name, 1)
    end

    # @return [Node] the head node of the edge
    def head
      Node.new @graph, LibCGraph.aghead(ptr)
    end

    # @return [Node] the tail node of the edge
    def tail
      Node.new @graph, LibCGraph.agtail(ptr)
    end
  end

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
      LibCGraph.agisdirected(ptr) == 1
    end

    # @return whether this graph is strict
    def strict?
      LibCGraph.agisstrict(ptr) == 1
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

  class SubGraph < BaseGraph
    def initialize(graph, name)
      @graph = graph
      @ptr = LibCGraph.agsubg(graph.ptr, name, 1)
    end
  end

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
                    when [:directed, :normal] then LibCGraph.Agdirected
                    when [:undirected, :normal] then LibCGraph.Agundirected
                    when [:directed, :strict] then LibCGraph.Agstrictdirected
                    when [:undirected, :strict] then LibCGraph.Agstrictundirected
                    else
                      raise ArgumentError, "invalid graph type #{[type, strictness]}"
                    end

        graph = new(LibCGraph.agopen(name, ag_type, FFI::Pointer::NULL))

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
        new LibCGraph.agmemread(data)
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
      LibGVC.gvLayout(@@gvc, ptr, layout.to_s)
      LibGVC.gvRenderFilename(@@gvc, ptr, format.to_s, filename);
      LibGVC.gvFreeLayout(@@gvc, ptr)

      nil
    end

    # Renders the graph to an image and returns the result as a string
    # @param format [String] the image format to use, e.g. 'svg', 'pdf' etc.
    # @param layout [String] the layout to use, e.g. 'dot' or 'neato' etc.
    # @return [String] the rendered graph in the given format
    def render(format = 'png', layout = 'dot')
      LibGVC.gvLayout(@@gvc, ptr, layout.to_s)

      data_ptr = FFI::MemoryPointer.new(:pointer, 1)
      len_ptr = FFI::MemoryPointer.new(:int, 1)

      LibGVC.gvRenderData(@@gvc, ptr, format.to_s, data_ptr, len_ptr);
      len = len_ptr.read_uint
      data_ptr = data_ptr.read_pointer
      
      data = data_ptr.read_string len

      LibGVC.gvFreeRenderData(data_ptr)
      LibGVC.gvFreeLayout(@@gvc, ptr)

      data
    end
  end
end
