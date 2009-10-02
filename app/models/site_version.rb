# Copyright (C) 2009 Pascal Rettig.



class SiteVersion < DomainModel


  has_many :site_nodes,:order => 'lft'

  def self.default
    self.find(:first,:order => 'id') || self.create(:name => 'Default')
  end

  def root_node
    @root_node ||= self.site_nodes.find(:first,:conditions => 'parent_id IS NULL')

    unless @root_node
      @root_node = site_nodes.create(:node_type => 'R', :title => '')
      home_page = site_nodes.create(:node_type => 'P')
      home_page.move_to_child_of(@root_node)
    end

    
    @root_node
  end

  alias_method :root, :root_node

   # get a nested structure with 1 DB call
  def nested_pages(closed = [])
    page_hash = {self.root_node.id => self.root_node }

    nds = self.site_nodes.find(:all,
                               :conditions => [ 'lft > ?',self.root_node.lft],
                               :order => 'lft',
                               :include => :site_node_modifiers)
    nds.each do |nd|
      nd.closed = true if closed.include?(nd.id)
      page_hash[nd.parent_id].child_cache << nd 
      page_hash[nd.id] = nd
    end

    @root_node
  end
end
