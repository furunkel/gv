require "gv/version"

module GV

  module FFI
    extend ::FFI::Library

    ffi_lib 'gvc', 'cgraph', 'cgraph'

    attach_function :gvContext, [], :pointer
    attach_function :gvFreeLayout, [:pointer, :pointer], :int
    attach_function :gvLayout, [:pointer, :pointer, :string], :int

    attach_function :gvRenderFilename, [:pointer, :pointer, :string, :string], :int
    attach_function :gvRenderData, [:pointer, :pointer, :string, :pointer, :pointer, :uint], :int
    attach_function :gvFreeRenderData, [:pointer]
    attach_function :gvParseArgs, [:pointer, :int, :pointer]

    attach_function :agmemread, [:string], :pointer
    attach_function :agopen, [:string, :int, :pointer], :pointer
    attach_function :agclose, [:pointer], :int

    attach_variable :Agundirected, :long
    attach_variable :Agstrictundirected, :long
    attach_variable :Agdirected, :long
    attach_variable :Astrictdirected, :long

    attach_function :agnode, [:pointer, :string, :int], :pointer
    attach_function :agedge, [:pointer, :pointer, :pointer, :string, :int], :pointer
    attach_function :agsubg, [:pointer, :string, :int], :pointer

    attach_function :agnameof, [:pointer], :string
    attach_function :agraphof, [:pointer], :pointer

    attach_function :agtail, [:pointer], :pointer
    attach_function :aghead, [:pointer], :pointer
    attach_function :agget, [:pointer, :string], :string

    attach_function :agsafeset, [:pointer, :string, :string, :string], :pointer
    attach_function :agstrdup_html, [:pointer, :string], :string
    attach_function :agstrfree, [:pointer, :string], :int
  end

  class Component
    @@gv_context = FFI.gvContext()

    attr_reader :graph

    def assert_open!
      raise RuntimeError, 'graph closed' unless graph.open?
    end

    def hash
      ptr.hash
    end

    def eql?(other)
      ptr.eql? other
    end

    alias :== :eql?

    def name
      assert_open!

      FFI.agnameof ptr
    end

    def []=(attr, value)
      assert_open!

      FFI.agsafeset(ptr, attr.to_s, value.to_s, "")
    end

    protected
    attr_reader :ptr
  end

  class Node < Component

    def initialize(graph, name)
      @graph = graph

      assert_open!
      @ptr = FFI.agnode(graph.ag_graph, name, 1)
    end
  end

  class Edge < Component

    def initialize(graph, name, tail, head)
      @graph = graph

      assert_open!
      @ptr = FFI.agedge(graph.ptr, tail.ptr, head.ptr, name, 1)
    end

    def head
      assert_open!

      Node.new FFI.aghead(ptr)
    end

    def tail
      assert_open!

      Node.new FFI.agtail(ptr)
    end
  end

  class SubGraph < Component
    def initialize(graph, name)
      @graph = graph
      @ptr = FFI.agsubg(graph.ptr, name, 1)
    end

    def node(name, attrs = {})
      node = Node.new self, name
      attrs.each do |attr, value|
        node[attr] = value
      end

      node
    end

    def edge(name, tail, head, attrs = {})
      edge = Edge.new self, tail, head

      attrs.each do |attr, value|
        edge[attr] = value
      end

      edge
    end
  end

  class Graph < SubGraph
    def initialize(name, type = :direct, strict = :normal)
      ag_type = case [type, strict]
                   when [:directed, :normal] then FFI.Agdirected
                   when [:undirected, :normal] then FFI.Agundirected
                   when [:directed, :strict] then FFI.Agstrictdirected
                   when [:undirected, :strict] then FFI.Agstrictundirected
                   else
                     raise ArgumentError, "invalid graph type"
                  end

      @ptr = FFI.agopen(name, ag_type, FFI::Pointer::NULL)
      @open = true
    end

    def graph
      self
    end

    def open?
      @open
    end

    def close!
      if open?
        FFI.agclose(ptr)
        @open = false
        true
      end
      false
    end

    def render(layout = 'dot', format = 'png')
      assert_open!

      FFI.gvLayout(@@gv_context, ptr, layout.to_s)

      data_ptr = FFI::MemoryPointer.new(:pointer, 1)
      len_ptr = FFI::MemoryPointer.new(:int, 1)

      FFI.gvRenderData(@@gv_context, ptr, format.to_s, data_ptr, len_ptr);
      len = len_ptr.read_uint
      data_ptr = data_ptr.read_pointer
      
      data = data_ptr.read_string_length len

      FFI.gvFreeRenderData(data_ptr)
      FFI.gvFreeLayout(@@gv_context, ptr)
    end
  end
end
