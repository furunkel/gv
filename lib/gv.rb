require "gv/version"

module GV
  module FFI
    extend ::FFI::Library

    ffi_lib 'gvc', 'cgraph', 'cgraph'

    attach_function :gvContext, [], :pointer
    attach_function :gvFreeLayout, [:pointer, :pointer], :int
    attach_function :gvLayout, [:pointer, :pointer, :string], :int

    attach_function :gvRenderFilename, [:pointer, :pointer, :string, :string], :int
    attach_function :gvRenderData, [:pointer, :pointer, :string, :buffer_inout, :pointer, :uint], :int
    attach_function :gvFreeRenderData, [:pointer]

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
end
