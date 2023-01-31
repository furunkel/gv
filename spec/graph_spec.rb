require_relative 'spec_helper'
require 'tmpdir'

include GV

describe Graph do
  describe :open do
    it 'creates a new graph' do
      graph = Graph.open 'test'
      assert graph.directed?
      refute graph.strict?

      graph = Graph.open 'test', :directed, :strict
      assert graph.strict?
      assert graph.directed?
    end

    it 'takes a block' do
      Graph.open 'test' do |g|
        assert g.directed?
        refute g.strict?
      end
    end
  end

  describe :load do
    it 'loads graph from file' do
      f = lambda do |filename|
        graph = Graph.load filename
        assert graph.directed?
        refute graph.strict?
        assert_equal 'g', graph.name
      end

      filename = File.join(__dir__, 'simple_graph.dot')
      file = File.open filename
      f.call file
      file.close

      f.call File.read(filename)
    end
  end

  describe :node do
    before do
      @graph = Graph.open 'test'
    end

    it 'creates a new node' do
      assert_kind_of Node, @graph.node('test')
    end

    it 'sets given attributes' do
      assert_equal 'green', @graph.node('test', color: 'green')[:color]
    end
  end

  describe :sub_graph do
    before do
      @graph = Graph.open 'test'
    end

    it 'creates a new sub graph' do
      assert_kind_of SubGraph, @graph.sub_graph('test')
    end

    it 'sets given attributes' do
      assert_equal 'green', @graph.sub_graph('test', color: 'green')[:color]
    end

    it 'takes a block' do
      graph = @graph.sub_graph('test') do |g|
        g[:color] = 'green'
      end
      assert_equal 'green', graph[:color]
    end
  end

  describe :edge do
    before do
      @graph = Graph.open 'test'
      @head = @graph.node 'head'
      @tail = @graph.node 'tail'
    end

    it 'creates a new edge' do
      assert_kind_of Edge, @graph.edge('test', @tail, @head)
    end

    it 'sets given attributes' do
      assert_equal 'green', @graph.edge('test', @tail, @head, color: 'green')[:color]
    end
  end

  describe :save do
    it 'renders the graph to the given filename' do
      graph = Graph.open 'test'
      graph.edge 'e', graph.node('A'), graph.node('B')
      Tempfile.create(%w(gv_test .png)) do |file|
        graph.save file.path
        assert_equal true, File.file?(file.path)
      end
    end
  end

  describe :render do
    it 'renders the graph to a string' do
      graph = Graph.open 'test'
      graph.edge 'e', graph.node('A'),
                 graph.node('B', shape: 'polygon',
                                 label: graph.html('<b>bold</b>'))

      data = graph.render

      graph = nil
      GC.start
      assert_kind_of String, data

      File.write 'spec/render.png', data
    end
  end
end

describe Edge do
  before do
    @graph = Graph.open 'test'
    @head = @graph.node 'head'
    @tail = @graph.node 'tail'
    @edge = Edge.new @graph, 'test', @tail, @head
  end

  it 'gives access to head and tail' do
    assert_equal @head, @edge.head
    assert_equal @tail, @edge.tail
  end

  it 'gives access to name' do
    assert_equal 'test', @edge.name
  end

  it 'gives access to attributes' do
    assert_nil @edge[:color]
    @edge[:color] = 'green'
    assert_equal 'green', @edge[:color]
  end
end
