# Copyright (C) 2009 Pascal Rettig.

class Editor::PublicationController < ParagraphController
  
  # Editor for galleries
  # editor_header "Publication Paragraphs"
  

#                                                         
   editor_for :create, :name => 'Entry Create Form', :features => ['publication_entry_create_form'], :hidden => true,
             :inputs =>  [ [ :entry_id, 'Entry Identifier', :integer ] ]
   editor_for :view, :name => 'Entry Display Form', :features => ['publication_entry_display_form'], :hidden => true,
              :inputs =>  [ [ :entry_id, 'Entry Identifier', :integer ], [:entry_offset, 'Entry Offset', :integer ]]
   editor_for :list, :name => 'Entry List', :features => ['publication_entry_list'], :hidden => true
   
   editor_for :edit, :name => 'Entry Edit', 
              :features => ['publication_entry_edit'],
              :inputs => [ [ :entry_id, 'Entry ID', :integer ] ],
              :hidden => true
              
   editor_for :admin_list, :name => 'Entry Admin List', :features => ['publication_entry_admin_list'], :hidden => true
  
  def create
   @publication = @paragraph.content_publication
    
   @options = CreateOptions.new(params[:pub] || @paragraph.data || {})
   @options.additional_vars(@publication.filter_variables)
   return if handle_paragraph_update(@options)
  
   @pages = SiteNode.page_options()
  end
  
  class CreateOptions < HashModel
      default_options :redirect_page => nil, :options => []
      validates_presence_of  :redirect_page
      integer_options :redirect_page
  end


  def edit
   @publication = @paragraph.content_publication
   
   @options = EditOptions.new(params[:pub] || @paragraph.data || {})
   @options.additional_vars(@publication.filter_variables)
   
   return if handle_paragraph_update(@options)

   @pages = [['No Return Page', nil ]] + SiteNode.page_options()
  end
  
  class EditOptions < HashModel
      default_options :return_page => nil, :options => [], :entry_id => nil, :allow_entry_creation => false
      
      boolean_options :allow_entry_creation
      integer_options :return_page,:entry_id
  end
  
  def view
  
   @publication = @paragraph.content_publication
   
   @options = EditOptions.new(params[:pub] || @paragraph.data || {})
   
   @options.additional_vars(@publication.filter_variables)
   

      
    return if handle_paragraph_update(@options)
    
    @pages = [['No Return Page'.t, nil ]] + SiteNode.page_options()
    
    data_model =@publication.content_model.content_model 
    # Only display a select box if the pub is < 
    @entries = [['Use Page Connection as ID'.t,nil ], ['Use page connection as ID or display first'.t,-4], ['Use page connection as URL'.t,-5],['Display random entry'.t,-1], ['Use referrer, otherwise random'.t,-2], ['Use referrer, otherwise blank'.t,-3]]
    if data_model.count < 50
      @entries +=  data_model.select_options
    end
  end
  
  
  
  def admin_list
   @publication = @paragraph.content_publication
  
   @options = AdminListOptions.new(params[:pub] || @paragraph.data || {})
   @options.additional_vars(@publication.filter_variables)
   
   return if handle_paragraph_update(@options)
   
   @pages = [['No Edit Page', nil ]] + SiteNode.page_options()
  end
  
  class AdminListOptions < HashModel
      default_options :edit_page => nil
      integer_options :edit_page
  end
  
  def list
     @publication = @paragraph.content_publication
 
  
     @options = ListOptions.new(params[:list] || @paragraph.data || {})
     @options.additional_vars(@publication.filter_variables)
     
     return if handle_paragraph_update(@options)
     
     @pages = [['No Detail Page', nil ]] + SiteNode.page_options()
  end
  
  class ListOptions < HashModel
      default_options :detail_page => nil, :tags => []
      integer_options :detail_page
  end
  
  
end
