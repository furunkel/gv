require_relative 'spec_helper'

include GV

describe Graph do
  describe :open do
    it "creates a new graph" do
      graph = Graph.open 'test'
      graph.directed?.must_equal true
      graph.strict?.must_equal false

      graph = Graph.open 'test', :directed, :strict
      graph.strict?.must_equal true
      graph.directed?.must_equal true
    end

    it "takes a block" do
      graph = Graph.open 'test' do |g|
        g.directed?.must_equal true
        g.strict?.must_equal false
      end
    end
  end

  describe :load do
    it "loads graph from file" do
      f = lambda do |f|
        graph = Graph.load f
        graph.directed?.must_equal true
        graph.strict?.must_equal false
        graph.name.must_equal 'g'
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

    it "creates a new node" do
      @graph.node('test').must_be_kind_of Node
    end

    it "sets given attributes" do
      @graph.node('test', color: 'green')[:color].must_equal 'green'
    end
  end

  describe :sub_graph do
    before do
      @graph = Graph.open 'test'
    end

    it "creates a new sub graph" do
      @graph.sub_graph('test').must_be_kind_of SubGraph
    end

    it "sets given attributes" do
      @graph.sub_graph('test', color: 'green')[:color].must_equal 'green'
    end

    it "takes a block" do
      graph = @graph.sub_graph('test') do |g|
        g[:color] = 'green'
      end
      graph[:color].must_equal 'green'
    end
  end


  describe :edge do
    before do
      @graph = Graph.open 'test'
      @head = @graph.node 'head'
      @tail = @graph.node 'tail'
    end

    it "creates a new edge" do
      @graph.edge('test', @tail, @head).must_be_kind_of Edge
    end

    it "sets given attributes" do
      @graph.edge('test', @tail, @head, color: 'green')[:color].must_equal 'green'
    end
  end

  describe :write do
    it "renders the graph to the given filename" do
      graph = Graph.open 'test'
      graph.edge 'e', graph.node('A'), graph.node('B')
      filename = File.join Dir.tmpdir, Dir::Tmpname.make_tmpname(['gv_test', '.png'], nil)
      graph.write filename
      File.file?(filename).must_equal true 
      File.unlink filename
    end
  end

  describe :render do
    it "renders the graph to a string" do
      graph = Graph.open 'test'
      graph.edge 'e', graph.node('A'), graph.node('B', shape: 'polygon', label: graph.html('<b>bold</b>'))
      data = graph.render

      graph = nil
      GC.start
      data.must_be_kind_of String

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
    @edge.head.must_equal @head
    @edge.tail.must_equal @tail
  end

  it 'gives access to name' do
    @edge.name.must_equal 'test'
  end

  it 'gives access to attributes' do
    @edge[:color].must_equal nil
    @edge[:color] = 'green'
    @edge[:color].must_equal 'green'
  end
end
