# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'spec/autorun'
require 'spec/rails'

Spec::Runner.configure do |config|
  # If you're not using ActiveRecord you should remove these
  # lines, delete config/database.yml and disable :active_record
  # in your config/boot.rb
  config.use_transactional_fixtures = false # Modified for 2.3.2
  config.use_instantiated_fixtures  = false
  config.fixture_path = RAILS_ROOT + '/spec/fixtures/'

  # == Fixtures
  #
  # You can declare fixtures for each example_group like this:
  #   describe "...." do
  #     fixtures :table_a, :table_b
  #
  # Alternatively, if you prefer to declare them only once, you can
  # do so right here. Just uncomment the next line and replace the fixture
  # names with your fixtures.
  #
  # config.global_fixtures = :table_a, :table_b
  #
  # If you declare global fixtures, be aware that they will be declared
  # for all of your examples, even those that don't use them.
  #
  # You can also declare which fixtures to use (for example fixtures for test/fixtures):
  #
  # config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
  #
  # == Mock Framework
  #
  # RSpec uses it's own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  #
  # == Notes
  # 
  # For more information take a look at Spec::Runner::Configuration and Spec::Runner
end


# http://gensym.org/2007/10/18/rspec-on-rails-tip-weaning-myself-off-of-fixtures
# Wean ourselves off of fixtures
# Call this within the description (e.g., after the describe block) to remove everything from the associated class or table
# Changed so that we're modifying DomainModel tables

def reset_domain_tables(*tables)
  callback = lambda do 
    DomainModel.connection.reconnect! if !DomainModel.connection.active?
    tables.each do |table|
      DomainModel.connection.execute("TRUNCATE #{table.is_a?(Symbol) ? table.to_s.tableize : table}") unless %w(component_schemas).include?(table)
    end
  end
  before_each_parts << callback
end

ActiveSupport::TestCase.fixture_path = RAILS_ROOT + '/spec/fixtures/'


# Custom Matchers
class HandleActiveTableMatcher
  def initialize(table_name,&block)
    @table_name = table_name
    @block = block
    @error_msgs = []
  end
  
  def matches?(controller,&block)
    @block ||= block # Could be passed in via the match func instead of initialization

    @controller = controller
    
    @cols = controller.send("#{@table_name}_columns",{})
    
    # Go through each column
    @cols.each do |header|
      # Try a search
      if header.is_searchable?
        args = HashWithIndifferentAccess.new({ @table_name => { header.field_hash => header.dummy_search, :display => { header.field_hash => 1 } } })
        begin
          @block.call(args)
        rescue Mysql::Error, ActiveRecord::StatementInvalid  => e
          @error_msgs << "Error searching on '#{header.field}' (#{e.to_s})"
        end
      end
      
      if header.is_orderable?
        begin
          @block.call(args)
        rescue Mysql::Error, ActiveRecord::StatementInvalid  => e
          @error_msgs << "Error ordering on '#{header.field}' (#{e.to_s})"
        end
      end
    end
    
    @error_msgs.length == 0
  end
  
  def description
    "handle active table #{@table_name}"
  end
  
  def failure_message
    " active table #{@table_name} did not operate properly: " + @error_msgs.join(",")
  end
end

def handle_active_table(table_name,&block)
  HandleActiveTableMatcher.new(table_name,&block)
end


module RspecRendererExtensions
 def renderer_feature_data=(val); @renderer_feature_data = val; end
 def renderer_feature_data; @renderer_feature_data; end
 
 def should_render_feature(feature_name)
   renderer = self
   expt = renderer.should_receive("#{feature_name}_feature") do |*feature_data|
     if feature_data.length == 0
      renderer.renderer_feature_data = renderer.instance_variable_hash
     else
      renderer.renderer_feature_data = feature_data[0]
     end
     "WEBIVA FEATURE OUTPUT"
   end
   expt
 end


end

module Spec
 module Rails
  module Example
    class ControllerExampleGroup < FunctionalExampleGroup

      def mock_editor(email = 'test@webiva.com',permissions = nil)
        # get me a client user to ignore any permission issues    
        @myself = EndUser.push_target('test@webiva.com')

        if permissions.nil?
          @myself.user_class = UserClass.client_user_class
          @myself.client_user_id = 1
          @myself.save
        else
          @myself.user_class = UserClass.domain_user_class
          @myself.save
          permissions = [ permissions ] unless permissions.is_a?(Array)
          permissions.map! { |perm| perm.to_sym } 
          
          permissions.each do |perm|
            @myself.user_class.has_role(perm)
          end
        end
    
        controller.should_receive('myself').at_least(:once).and_return(@myself)
      end
      
   
      def build_renderer_helper(user_class,site_node_path,display_module_type,data={},page_connections={},extra_attributes = {})
        display_parts = display_module_type.split("/")
        para = PageParagraph.create(:display_type => display_parts[-1], :display_module => display_parts[0..-2].join("/"),:data=>data)
        para.attributes = extra_attributes
        para.direct_set_page_connections(page_connections)
        rnd = para.renderer.new(user_class,controller,para,SiteNode.new(:node_path => site_node_path),PageRevision.new,{})
        rnd.extend(RspecRendererExtensions)
        rnd
      end
         
      def build_renderer(site_node_path,display_module_type,data={},page_connections={},extra_attributes={})
        build_renderer_helper(UserClass.default_user_class,site_node_path,display_module_type,data,page_connections,extra_attributes)
      end
      
      def build_anonymous_renderer(site_node_path,display_module_type,data={},page_connections={},extra_attributes={})
        build_renderer_helper(UserClass.anonymous_user_class,site_node_path,display_module_type,data,page_connections,extra_attributes)
      end     

      def renderer_get(rnd,args = {})
        controller.set_test_renderer(rnd)
        get :renderer_test, args
      end
      
      def renderer_post(rnd,args = {})
        controller.set_test_renderer(rnd)
        post :renderer_test, args
      end
      
   end
   
   class ViewExampleGroup < FunctionalExampleGroup
      def build_feature(feature_class)
        paragraph = mock_model(PageParagraph,:site_feature => nil, :content_publication => nil)
        renderer = mock_model(ParagraphRenderer,:get_handler_info => [])
        feature_class.classify.constantize.new(paragraph,renderer)
      end
   end   
  end
 end
end


class ParagraphOutputMatcher
  def initialize(output_type,args)
    @output_type = output_type
    @args = args
    @output_args = nil
  end
  
  def matches?(renderer)
    output  = renderer.output
    if @output_type == 'render_feature'
      renderer.renderer_feature_data == @args
    elsif @output_type == 'assign_feature_data' # break this out into a separate matcher
      if renderer.renderer_feature_data && renderer.renderer_feature_data[@args[0].to_sym] == @args[1]
        true
      else 
        @output_type_error = "mis-assigned :#{@args[0]}"
        @output_args = renderer.renderer_feature_data ? renderer.renderer_feature_data[@args[0].to_sym] : nil
        @args = @args[1]
        false
      end
    else
      if output.is_a?(ParagraphRenderer::ParagraphOutput)
        @output_args = output.render_args.clone
        @output_args.delete(:locals) if !@args[:locals]
        if @output_type == 'render'
          @output_args == @args
        else
          @output_type_error = "Renderered"
          false
        end
      elsif output.is_a?(ParagraphRenderer::ParagraphRedirect)
        @output_args = output.args
        if @output_type == 'redirect'
          @output_args == @args
        else
          @output_type_error = "Redirected"
          false
        end
      else
        @output_type_error = "Failed to output anything"
        false
      end
    end
  end
  
  def description
   "Should #{@type.humanize}"
  end
  
  def failure_message
    msg = "Does not match expected renderer output:\n"
    if @output_type_error
      msg << "Expected paragraph to #{@output_type.humanize} instead it #{@output_type_error}\n"
    end
    msg << "Expected:" 
    PP.singleline_pp(@args,msg)
    msg << "\nReceived:"
    PP.singleline_pp(@output_args,msg)
    msg
  end
end


def render_feature_data(args)
  ParagraphOutputMatcher.new('render_feature',args)
end

def render_paragraph(args)
  ParagraphOutputMatcher.new('render',args)
end

def redirect_paragraph(args)
  ParagraphOutputMatcher.new('redirect',args)
end

def assign_to_feature(elem,data)
  ParagraphOutputMatcher.new('assign_feature_data',[elem,data])
end





# Custom Matchers
class ModelInjectionAttackMatcher
  def initialize(model,test_string="<script>test();</script>",&block)
    @model = model
    @test_string = test_string
    @block = block
    @error_msgs = []
  end
  
  def matches?(feature,&block)
    @block ||= block # Could be passed in via the match func instead of initialization

    @feature = feature
    
    @columns = @model.class.columns
    
    
    # Go through each column
    @columns.each do |col|
      if [:string,:text].include?(col.type)
        @model.send("#{col.name}=",@test_string)
      end
    end
    
    @output = @block.call(@feature,@model)
    
    !@output.include?(@test_string)
  end
  
  def description
    "check for escaping of '#{@test_string}' in argument attributes"
  end
  
  def failure_message
    msg = "  '#{@test_string}' was successfully injected into the output: "
     PP.pp(@output.to_s,msg)
    msg
  end
end

def prevent_feature_injection(model,&block)
  ModelInjectionAttackMatcher.new(model,&block)
end

# No Longer available in ModelTests
def fixture_file_upload(path, mime_type = nil, binary = false)
  fixture_path = ActionController::TestCase.send(:fixture_path) if ActionController::TestCase.respond_to?(:fixture_path)
  ActionController::TestUploadedFile.new("#{fixture_path}#{path}", mime_type, binary)
end


DomainFile.root_folder
UserClass.create_built_in_classes
