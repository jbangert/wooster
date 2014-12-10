require 'byebug'
module Wooster::Policy
  module Helpers
    def allow
      ->(x) { true}
    end
    def either(*args)
      # case args.size
      # when 1:
      #        args[0]
      #   else:
      #     ->(x){args[0] 
      # end
      ->(x) {args.any?{|fun| self.instance_exec x,&fun}}
    end
  end
class Builder
    @registry = {}
    
    def self.registry
	    @registry
    end

    def self.define(&block)
	    definition_proxy = DefinitionProxy.new
	    definition_proxy.instance_eval(&block)	
    end

end
def self.build(&block)
  Builder.define &block
end
class DefinitionProxy
  include Helpers
    def permissions(permissions_class, &block)
	    permissions = Permissions.new(permissions_class)
	    permissions.instance_eval(&block)
    end
end


class Permissions # < BasicObject
  include Helpers
  def initialize(klass)
    @klass = klass
  end
  def record(*args)
    case args[0]
    when ::Symbol
      type, block = *args
      #byebug
      @klass.class_variable_get(:@@wooster_records)[type] << block
    when ::Proc
      [:read, :write, :delete, :create].each {|type| record type, args[0] }
    else
      raise ArgumentError 
    end
  end
  def read( block)
    record(:read,block)
  end
  def delete( block)
    record(:delete,block)
  end
  def create( block)
    record(:create,block)
  end
  def write(block)
    record(:write,block)
  end

  def field(name,type,block)
    fields = @klass.class_variable_get(:@@wooster_field)
    fields[name.to_s][type] << block
  end
  def field_read(name, block)
    field name,:read, block
  end
  def field_write(name, block)
    field  name,:write, block
  end
  def field_readwrite(name, block)
    field  name,:read, block
    field  name,:write, block
  end
end

end
