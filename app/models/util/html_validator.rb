# Copyright (C) 2009 Pascal Rettig.

#require 'tidy'

require 'xml' 

# Utility class to validate html (with or without cms: tags)
class Util::HtmlValidator

  

  def initialize(html)
    @html = html
  end
  
  def valid?
    self.validate if !@errors.is_a?(Array)
    !@errors || @errors.length == 0
  end
  
  attr_reader :errors
  
  def validate
    @errors = []

# Tidy provided much better error messages, but also segfaulted constantly...    
#    Tidy.path = "/usr/lib/libtidy.so"
#    tidy = Tidy.new(:input_xml => true)
#    tidy.clean(@html)
#    @errors = tidy.errors
    parser = XML::Parser.string("<feature xmlns:cms='http://www.webiva.org/cms'>#{@html}</feature>")
    msgs = []
    XML::Error.set_handler { |msg| msgs << msg }
    begin
      parser.parse
    rescue Exception => e
      @errors = msgs.map { |e| e.to_s }
      @errors = @errors.select { |err| !(err =~ /Entity \'(.*)' not defined/) }
      @errors = nil if @errors.length == 0
    end
    @errors
  end

end
