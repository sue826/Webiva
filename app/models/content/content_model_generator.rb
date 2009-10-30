# Copyright (C) 2009 Pascal Rettig.



module Content::ContentModelGenerator

  def content_model
    clses = DataCache.local_cache("content_models_list") || {}
    cls = clses[self.table_name]
    return cls[0] if cls
    
    class_name = self.table_name.classify
    cls = nil
    Object.class_eval do
      # remove_const class_name if const_defined? class_name
      #cls = Class.new(ContentModelType) #
      cls = const_set(class_name.to_s, Class.new(ContentModelType))
    end

    #cls.set_class_name class_name
    
    cls.set_table_name self.table_name
    
    # Setup the fields in the model as necessary (required, validation, etc)
    self.content_model_fields.each { |fld| fld.setup_model(cls) }
    
    if !self.identifier_name.blank?
      identifier_func = <<-SRC
        def identifier_name
          @identifier_name ||= variable_replace("#{self.identifier_name.gsub('"','\\"')}",self.attributes.symbolize_keys)
        end
        SRC
        
        cls.class_eval identifier_func, __FILE__, __LINE__
      elsif self.content_model_fields.length  > 0
        identifier_func = <<-SRC
        def identifier_name
          self.send(:#{self.content_model_fields[0].field}).to_s
                  end
      SRC
      
      cls.class_eval identifier_func, __FILE__, __LINE__
    else
      identifier_func = <<-SRC
        def identifier_name
          " #" + self.id.to_s 
        end
SRC
        
      cls.class_eval identifier_func, __FILE__, __LINE__
        
    end
      
      if self.show_tags?
        cls.has_content_tags
      end
      
      self.model_generator_features.each do |feature|
        feature.model_generator(self,cls)
      end
      
      content_model_id = self.id
      if self.create_nodes?
        cls.content_node :container_type => 'ContentModel',:container_field => :content_model_id
        cls.has_one :content_node, :foreign_key => :node_id, :conditions => "node_type = " + DomainModel.connection.quote(class_name)
        cls.send(:define_method,:content_model_id) { content_model_id }
        cls.send(:define_method,:build_content_node) do 
          ContentNode.new(:node_type => class_name, :node_id => self.id)
        end
      end

      clses = DataCache.local_cache("content_models_list") || {}
      clses[self.table_name] = [ cls, class_name.to_s ]
      DataCache.put_local_cache("content_models_list", clses)
      class_name.constantize
  end


end
