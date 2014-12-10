module Wooster
  RecordPermissions = Struct.new(:read,:write,:create,:delete)
  FieldPermissions = Struct.new(:read, :write)
  def self.init_policy(klass)
    if klass.class_variable_defined? :@@wooster_field
     raise RuntimeError
    end
    klass.cattr_accessor :wooster_records
    klass.cattr_accessor :wooster_field
    x = Hash.new
    x.default_proc = Proc.new do |hash, key|
      hash[key] = FieldPermissions.new([],[])
    end
    klass.wooster_records = RecordPermissions.new([],[],[],[])
    klass.wooster_field = x
  end

  def self.controller_exec(block, *args)
    Thread.current[:wooster_controller].instance_exec *args,&block
  end
  def self.any_permission?(permissions, object)
    permissions.any?{|func|  Wooster.controller_exec(func,object)}  
  end
  
  class InvalidFieldWriteError < RuntimeError
  end
  class InvalidCreateError < RuntimeError
  end
  class InvalidUpdateError < RuntimeError
  end
  class InvalidDeleteError < RuntimeError
  end
end
ActiveRecord::Base.class_eval do
 
  class << self
    alias_method :old_inherited, :inherited
    def inherited(subclass)
      Wooster::init_policy(subclass)
      old_inherited(subclass)
    end
  end
  alias_method :old_bracket, :[]
  
  def [](key)
    self.send key
  end
end

ActionController::Base.class_eval do
  around_filter :wooster_wrap
  def wooster_wrap
    Thread.current[:wooster_controller] = self
    begin
      yield
    ensure
      Thread.current[:wooster_controller] = nil
    end
  end
end
ActiveModel::AttributeMethods::ClassMethods.class_eval do
    alias_method :define_attribute_methods_old, :define_attribute_methods

    def define_attribute_methods(*attrs)
      define_attribute_methods_old(*attrs)
        
      after_find do
        new_attr = Hash[]
        attributes.each {|k,v|
          #if all rules return false and more than one rule returns false -> reject
          succ = true
          default = nil
          self.class.wooster_field[k].read.each{|func|
            succ, value = Wooster.controller_exec(func,self)
            default ||= value
            if(succ)
              break
            end
          }
          if(!succ)
            new_attr[k] = default || self.class.column_defaults[k.to_s]
          end
        }
        attributes.merge! new_attr
      end
      before_create do
        unless Wooster.any_permission?(self.class.wooster_records.create,self)
          raise InvalidCreateError
        end
      end
      before_update do
        unless Wooster.any_permission?(self.class.wooster_records.update,self)
          raise InvalidCreateError
        end
      end
      before_destroy do
        ## XXXX: Hook destroy?
        unless Wooster.any_permission?(self.class.wooster_records.delete,self)
          raise InvalidDeleteError
        end
      end
      before_save do
        changes.each {|field,value|
          if false
            raise InvalidSaveError
          end
        }
      end
    end
end

ActiveRecord::Querying.module_eval {
  alias_method :find_by_sql_without_wooster, :find_by_sql
  def find_by_sql(sql,binds=[])
    find_by_sql_without_wooster(sql,binds).select{|rec| Wooster.any_permission?(wooster_records.read, rec)   }
  end
}
