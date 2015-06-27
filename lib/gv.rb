require 'gv/version'
require 'ffi'

module GV

  module FFI
    extend ::FFI::Library

    ffi_lib 'gvc', 'cgraph', 'cgraph'

    class AGraph < ::FFI::ManagedStruct
      # dummy layout, only ever used by reference
      layout :_1, :int,
             :_2, :int

      def self.release(ptr)
        FFI.agclose(ptr) unless ptr.null?
      end
    end

    typedef :pointer, :gvc
    typedef :pointer, :ag_node
    typedef :pointer, :ag_edge

    attach_function :gvContext, [], :pointer
    attach_function :gvFreeLayout, [:gvc, AGraph.by_ref], :int
    attach_function :gvLayout, [:gvc, AGraph.by_ref, :string], :int

    attach_function :gvRenderFilename, [:gvc, AGraph.by_ref, :string, :string], :int
    attach_function :gvRenderData, [:gvc, AGraph.by_ref, :string, :pointer, :pointer], :int
    attach_function :gvFreeRenderData, [:pointer], :void

    attach_function :agmemread, [:string], AGraph.by_ref
    attach_function :agopen, [:string, :long, :pointer], AGraph.by_ref
    attach_function :agclose, [AGraph.by_ref], :int

    attach_variable :Agundirected, :long
    attach_variable :Agstrictundirected, :long
    attach_variable :Agdirected, :long
    attach_variable :Agstrictdirected, :long

    attach_function :agnode, [AGraph.by_ref, :string, :int], :ag_node
    attach_function :agedge, [AGraph.by_ref, :ag_node, :ag_node, :string, :int], :ag_edge
    attach_function :agsubg, [AGraph.by_ref, :string, :int], :pointer

    attach_function :agnameof, [:pointer], :string
    attach_function :agraphof, [:pointer], :pointer

    attach_function :agtail, [:ag_edge], :ag_node
    attach_function :aghead, [:ag_edge], :ag_node
    attach_function :agget, [:pointer, :string], :string

    attach_function :agsafeset, [:pointer, :string, :string, :string], :pointer
    attach_function :agstrdup_html, [AGraph.by_ref, :string], :pointer
    attach_function :agstrfree, [AGraph.by_ref, :pointer], :int

    attach_function :agisdirected, [AGraph.by_ref], :int
    attach_function :agisstrict, [AGraph.by_ref], :int
  end

  class Component
    @@gvc = FFI.gvContext()

    attr_reader :graph

    def html(string)
      ptr = FFI.agstrdup_html(graph.ptr, string)
      string = ptr.read_string
      FFI.agstrfree graph.ptr, ptr

      string
    end

    def hash
      ptr.hash
    end

    def ==(other)
      other.is_a?(Component) && ptr == other.ptr
    end

    alias :eql? :== 

    def name
      FFI.agnameof ptr
    end

    def []=(attr, value)
      FFI.agsafeset(ptr, attr.to_s, value.to_s, "")
    end

    def [](attr)
      FFI.agget(ptr, attr.to_s)
    end

    protected
    attr_reader :ptr
  end

  class Node < Component
    def initialize(graph, name_or_ptr)
      @graph = graph
      case name_or_ptr
      when String
        @ptr = FFI.agnode(graph.ptr, name_or_ptr, 1)
      else
        @ptr = name_or_ptr
      end
    end
  end

  class Edge < Component
    def initialize(graph, name, tail, head)
      @graph = graph

      @ptr = FFI.agedge(graph.ptr, tail.ptr, head.ptr, name, 1)
    end

    def head
      Node.new @graph, FFI.aghead(ptr)
    end

    def tail
      Node.new @graph, FFI.agtail(ptr)
    end
  end

  class BaseGraph < Component

    def node(name, attrs = {})
      component Node, [name], attrs
    end

    def edge(name, tail, head, attrs = {})
      component Edge, [name, tail, head], attrs
    end

    def sub_graph(name, attrs = {})
      graph = component SubGraph, [name], attrs
      yield graph if block_given?

      graph
    end

    def directed?
      FFI.agisdirected(ptr) == 1
    end

    def strict?
      FFI.agisstrict(ptr) == 1
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
      @ptr = FFI.agsubg(graph.ptr, name, 1)
    end
  end

  class Graph < BaseGraph

    class << self
      private :new
      def open(name, type = :directed, strict = :normal)
        ag_type = case [type, strict]
                    when [:directed, :normal] then FFI.Agdirected
                    when [:undirected, :normal] then FFI.Agundirected
                    when [:directed, :strict] then FFI.Agstrictdirected
                    when [:undirected, :strict] then FFI.Agstrictundirected
                    else
                      raise ArgumentError, "invalid graph type #{[type, strict]}"
                    end

        graph = new(FFI.agopen(name, ag_type, ::FFI::Pointer::NULL))

        if block_given?
          yield graph
        end

        graph
      end

      def load(io)
        data = if io.is_a? String
          io
        else
          io.read
        end
        new FFI.agmemread(data)
      end
    end

    def initialize(ptr)
      @ptr = ptr
    end

    def graph
      self
    end

    def write(filename, format = 'png', layout = 'dot')
      FFI.gvLayout(@@gvc, ptr, layout.to_s)
      FFI.gvRenderFilename(@@gvc, ptr, format.to_s, filename);
      FFI.gvFreeLayout(@@gvc, ptr)
    end

    def render(format = 'png', layout = 'dot')
      FFI.gvLayout(@@gvc, ptr, layout.to_s)

      data_ptr = ::FFI::MemoryPointer.new(:pointer, 1)
      len_ptr = ::FFI::MemoryPointer.new(:int, 1)

      FFI.gvRenderData(@@gvc, ptr, format.to_s, data_ptr, len_ptr);
      len = len_ptr.read_uint
      data_ptr = data_ptr.read_pointer
      
      data = data_ptr.read_string_length len

      FFI.gvFreeRenderData(data_ptr)
      FFI.gvFreeLayout(@@gvc, ptr)

      data
    end
  end
end
