#--
# Copyright (c) 2007 Really Simple llc
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'rubygems'
require 'open-uri'
require 'fastercsv'
require 'mechanize'
require 'ftools'
require 'ruby-debug'

current_dir = File.dirname(__FILE__)
require current_dir + '/../lib/extensions/hpricot'
require current_dir + '/../lib/extensions/enumerable'
require current_dir + '/../lib/extensions/string'
require current_dir + '/../lib/extensions/mixins'
require current_dir + '/../lib/extensions/mechanize'

Hpricot.buffer_size = 462144


# the scraper collects items, processes them if need be, and writes them.
# collecting the items and writing them are both delegated to other classes.
# The scraper's job is basically shuttling data from the scraped pages to the writer.
# If any actions need to be performed on all items, it should be done by the scraper.
# It's like the controller in an MVC framework.
class Scraper
  include HdocHandler
  include UrlHandler
  
  attr_accessor :domain, 
    :indexes, 
    :attributes, 
    :item_address_selector, 
    :items, 
    :writer, 
    :combined_attributes, 
    :parse_item_address, 
    :agent,
    :pagination,
    :indexed_item_container_selector,
    :item_index
  
  def initialize(options = {})
    self.domain = options[:domain]
    self.item_address_selector = options[:item_address_selector]
    self.indexes = options[:indexes] || []
    self.attributes = options[:attributes] || []
    self.items = options[:items] || []
    self.combined_attributes = []
    self.parse_item_address = options[:parse_item_address] if options[:parse_item_address]
    initialize_writer # I don't see why the writer is being initlized here.
    self.agent = WWW::Mechanize.new
    self.agent.pluggable_parser.html = UntouchedHtmlParser
    self.pagination = options[:pagination]
    self.indexed_item_container_selector = IndexedItemContainerSelector.new(options[:indexed_item_container_selector])
  end
  
  #setup writer - defaults to csv, DP-centric
  def initialize_writer
    self.configure_writer(
      :type => 'csv', 
      :header => ["Name", "Manufacturer", "Website", "Lead Time", "Description", "Category Code", "Applicable Uses", "Default Image URL", "Attachments"]
      # csv << [p[:name], p[:manufacturer], p[:website], p[:lead_time], p[:description], p[:category_code], p[:applicable_uses], p[:default_image_url], *p[:attachments]]
    ) 
  end
  
  def configure_writer(configuration)
    @writer = ResultWriter.new(configuration)
  end
  
  def write
    @writer.write(@items)
  end
  
  def collect_items
    @indexes.each{|index|
      index.collect_items
      new_items = index.items
      @items = @items + new_items if new_items
    }
    @items.flatten!
    if @items.size < 1
      puts "Warning: no items were collected!"
    end
    return @items
  end
  
  def add_attribute(options ={}, &b)
    if block_given?
      options[:value_block] = b
    end
    @attributes << Attribute.new(options)
    @attributes.last
  end
  
  # Will add all attributes to the to_attribute
  # Must allow for "sets" of combined attributes to be created so that you can call it multiple times per a scrape
  def combine_attributes(to_attribute, *attributes)
    # Update Self
    self.combined_attributes << [to_attribute, attributes].flatten
    # Update Indexes
    @indexes.each{|i|
      i.combined_attributes << [to_attribute, attributes].flatten
    }
  end

  def add_index(options = {})
    options[:domain] ||= self.domain
    options[:agent] ||= self.agent
    options[:item_address_selector] ||= self.item_address_selector
    options[:parse_item_address] ||= self.parse_item_address
    options[:attributes] ||= @attributes
    options[:pagination] ||= self.pagination
    options[:combined_attributes] ||= self.combined_attributes
    options[:scraper] = self
    if options[:indexed_item_container_selector]
      options[:indexed_item_container_selector] = IndexedItemContainerSelector.new(options[:indexed_item_container_selector])
    else
      options[:indexed_item_container_selector] = self.indexed_item_container_selector
    end
    @indexes << Index.new(options)
    @indexes.last
  end
  
  # merge duplicates - needs to toss out items with duplicate URL's and specify which
  # attributes to merge.
  # assumes that fields to merge are all arrays.
  def merge_duplicate_items(field_to_detect_duplicates_on, *fields_to_merge)
    duplicate_items = items.method_values_with_multiple_instances(field_to_detect_duplicates_on)
    merged_items = {}
    duplicate_items.each do |item|
      unless merged_items[item[field_to_detect_duplicates_on]]
        merged_items[item[field_to_detect_duplicates_on]] = item 
      else
        fields_to_merge.each{|field_to_merge| merged_items[item[field_to_detect_duplicates_on]][field_to_merge] |= item[field_to_merge]}
      end
    end
    self.items = self.items - duplicate_items + merged_items.values
  end
  
  def notify
    `growlnotify -n Scraper -m Scrape complete`
  end

  class Attribute
    include HdocHandler
    include UrlHandler
    # varies by: behavior for finding info, behavior for processing info
    # name needs to be visible to the writer
    # page specifies finding behavior further by specifying where to look - on the item page or on the item's index page
    # selector specifies finding behavior - lets attribute know to use hpricot
    # value is a static value
    
    # decided to use :selector AND :value, because both make sense in their own context and neither
    # makes sense in the other's context.  When you're dealing with an hpricot selector
    # you want to call it a selector - value implies "this is the value of the attribute which will be written",
    # which isn't close to the truth. Likewise, when you have a static value, it doesn't make
    # sense to call it a "selector" because you're not selecting anything.
    
    # Does it make sense to have a StaticAttribute and HpricotAttribute class? This works for now
    # but may want to refactor into sep. classes if we add more "types"
    attr_accessor :name, :page, :selector, :value, :value_block

    def initialize(options)
      self.name = options[:name]
      self.selector = options[:selector]
      self.value = options[:value]
      self.page = options[:page] || :item
      self.value_block = options[:value_block]
    end
    
    def item_setup(item)
      @item = item
      set_hdoc
    end
    
    # maybe should call this item_doc?
    def set_hdoc
      case page
      when :item
        @hdoc = @item.doc
      when :index
        @hdoc = @item.index_container_doc
      end
    end
    
    def value_for_item(item)
      item_setup(item)
                                                                                                                                                 
      value = case self.type
        when :static: static_value
        when :hpricot: hpricot_value # make sure your value_block deals with hpricot elements
      end
      
      get_spider_attribute_value(value)
    end
    
    def type
      return :hpricot if self.selector
      return :static if self.value
    end
    
    def static_value
      if self.value_block
        self.value_block.call(self.value)
      else
        self.value
      end
    end
    
    # can return an array of h_elements or an array of strings
    def hpricot_value
      (self.value_block ?
        h_elements.collect{|value| value_block.call(value)} :
        h_elements.collect{|value| value.inner_text}
      ).delete_if {|i| !i}
      # self.value_block ? h_elements.collect{|value| value_block.call(value)} : h_elements.collect{|value| value.inner_text}
    end
    
    # for scrape_value
    # can also be used outside of Scraper#collect_items , but user will need to
    # call item_setup first
    def h_elements
      elements = select_h_elements
      elements.flatten
    end
    
    def select_h_elements
      elements = []
      if selector.is_a?(Array)
        for s in selector
          elements << (@hdoc/s)
        end
      else
        elements << (@hdoc/selector)
      end
      elements.flatten
    end
    
    def indexed?
      page == :index
    end
    
    # most likely will be used outside of collect_items
    def h_element
      h_elements.first
    end
    
    def get_spider_attribute_value(values)
      # "spider attributes" need to visit another page to get the final value
      # this is not foolproof - what happens when you get a URL that doesn't actually exist, for example?
      # Does this even make sense? Should we instead just add an index to an index?
      if @spider_attribute
        #values must be urls, so "parent" attribute must return URL's
        values.to_a.collect! do |value|
          url = full_url_from_current_path(value, @item[:url])
          hdoc = get_hdoc(url, @item.parent.agent)
          spider_item = @item.clone
          spider_item.doc = hdoc
          @spider_attribute.value_for_item(spider_item)
        end
        values.flatten
      else
        values
      end
    end
    
    def domain
      @item[:domain]
    end

    def add_spider_attribute(options ={}, &b)
      if block_given?
        options[:value_block] = b
      end
      @spider_attribute = Attribute.new(options)      
    end

    
    # Helper Methods for Parsing hPricot Values
    def get_img_src(&b)
      img_src = Proc.new{|e| 
        src = e.get_attribute("src")
        block_given? ? b.call(src) : src
      }
      self.value_block = img_src
    end
    
    def get_a_href(&b)
      a_href = Proc.new{|e|
        href = e.get_attribute("href")
        block_given? ? b.call(href) : href
      }
      self.value_block = a_href
    end
    
    def clean_text(&b)
      just_txt = Proc.new{|e|
        txt = e.clean_text
        block_given? ? b.call(txt) : txt
      }
      self.value_block = just_txt
    end
    
    def just_text(&b)
      just_txt = Proc.new{|e|
        if e
          txt = e.just_text
          block_given? ? b.call(txt) : txt
        end
      }
      self.value_block = just_txt
    end
  end
  
  # util methods
  def indexed?
    self.page.to_s == 'index'
  end
end

class Item < Hash
  include HdocHandler
  include UrlHandler
  # item_index refers to which item out of all the items currently being collected this is
  # parent refers to the Index which has "found" this item.
  attr_accessor :parent, :doc, :url, :index_container_doc
  def initialize(options)
    @parent = options[:parent]
    @url = options[:url]
    hdoc = Hpricot(options[:doc])
    @doc = hdoc.at("scraper-file")
    @index_container_doc  = hdoc.at("scraper-index")
    @attributes = options[:attributes]
    @combined_attributes= options[:combined_attributes]
    populate_fields
  end
  
  def populate_fields
    # First take out all attributes that are not in the combined_attribute field
    attributes = @attributes.reject{|a| @combined_attributes.flatten.include?(a.name)}
    
    self[:url] = @url  # DP-centric
    
    attributes.flatten.each_with_index do |attribute, attribute_index|
      self[attribute.name.to_sym] = attribute.value_for_item(self)
    end
    
    # Now process the combined_attributes
    # Combined attributes are nested sets [[:description, :designed_by, :dimensions], [:name, :style, :line]]
    # Each of those sets is an attribute to combine
    # Take the first combined attribute and make that what we are using
    # It then reverse the array and adds the other attributes to it.
    for combined_attribute in @combined_attributes
      to_attribute = @attributes.flatten.reject{|a| !combined_attribute[0].to_s.include?(a.name.to_s)}
      from_attributes = @attributes.flatten.reject{|a| !combined_attribute[0..-1].flatten.include?(a.name)}
      val = from_attributes.reverse[0..-1].collect{|a| a.value_for_item(self)}
      if @attributes.size >= 1 && @combined_attributes.size >= 1
        self[to_attribute[0].name.to_sym] =  (to_attribute[0].value.is_a?(Array) || to_attribute[0].selector.is_a?(Array)) ? val : val.join("\n") 
      end
    end if @combined_attributes.size >= 1 && @attributes.size >= 1
  end
  
  # this is necessary for method_values_with_multiple_instances to work
  # I don't like that this has the potential for name conflicts with Hash's
  # default methods.  Could cause mysterious bugs.
  
  # Access hash keys using a '.'
  
  # What happens if the key is an instance method of hash?
  # 
  #   h = {'clear' => a, 'foggy' => 2 }
  #   h.clear   # ?
  def method_missing(m, *args)
    method_name = m.to_s
    if method_name[-1] == ?=
      self[method_name[0..-2].to_sym] = args[0]
    else             
      self.fetch(method_name.to_sym)
    end
  end
end


# the sole purpose of the index is to return a collection of items. It's the scraper's job
# to do something with the collection.
class Index < Scraper
  attr_accessor :path, :doc, :item_urls, :item_address_selector, :item_address_parser, :pagination, :scraper, :indexed_item_container_selector

  def initialize(options = {})
    self.scraper = options[:scraper]
    self.domain = options[:domain]
    self.item_address_selector = options[:item_address_selector]
    self.parse_item_address = options[:parse_item_address]
    self.path = full_url_from_current_path(options[:path]) if options[:path]
    self.attributes = options[:attributes].clone
    self.combined_attributes = options[:combined_attributes].clone
    self.pagination = options[:pagination]
    self.agent = options[:agent]
    self.indexed_item_container_selector = options[:indexed_item_container_selector]
    
    # need to store path with doc for indexed + paginated products
    if self.pagination && !options[:doc]
      if pagination[:selector]
        first_page = get_hdoc(self.path, self.agent)
        pages = (first_page/pagination[:selector]).collect do |e| 
          e.get_attribute("href")
        end.push(self.path).flatten.uniq.collect do |i| 
          [get_hdoc(full_url_from_current_path(i), self.agent), i]
        end
        self.doc = pages
      end
    elsif options[:doc]
      self.doc = options[:doc]
    else
      self.doc = [[get_hdoc(self.path, self.agent), self.path]]
    end
  
    @index_attributes = []
    @remove_urls = []
    @add_urls = []
    @replace_urls = {}
    @filenames = []
  end
  
  # what happens when dealing with indexed attributes?
  def remove_item_url(p)
    @remove_urls << full_url_from_current_path(p, self.path)
  end
  
  def add_item_url(p)
    @add_urls << full_url_from_current_path(p, self.path)
  end
  
  def replace_item_url(url_to_replace, replacement)
    url_to_replace = full_url_from_current_path(url_to_replace, self.path)
    replacement = full_url_from_current_path(replacement, self.path)
    @replace_urls[url_to_replace] = replacement
  end
  
  def add_attribute(options ={}, &b)
    if block_given?
      options[:value_block] = b
    end
    @attributes << Attribute.new(options)
    @attributes.last
  end
  
  def collect_items
    initialize_collection
    create_local_item_files
    create_items
  end
  
  # figure out if this is indexed or not; if it has individual pages or not; what the item url's are
  def initialize_collection
    set_item_urls
  end

  def has_indexed_attributes?
    return @has_indexed_attributes unless @has_indexed_attributes.nil?
    if self.attributes.detect{|a|a.indexed?}
      @has_indexed_attributes = true 
    else
      @has_indexed_attributes = false
    end
  end
  
  def has_item_pages?
    return @has_item_pages unless @has_item_pages.nil?
    if self.item_address_selector
      @has_item_pages = true 
    else
      @has_item_pages = false
    end
  end

  #Dealing with item URL's
  def set_item_urls
    if item_address_selector
      set_item_urls_with_link_selector
    else
      set_item_urls_without_link_selector
    end
  end
  
  def set_item_urls_with_link_selector
    if self.doc.is_a?(Array) #is it always an array?
      @item_urls = []
      get_item_urls_from_index_pages
    end
    
    replace_and_remove_urls
    @item_urls = (@item_urls + @add_urls).flatten.collect{|url|url.strip}.uniq
  end
  
  def get_item_urls_from_index_pages
    for index_doc in self.doc #need to make this more explicitly about pagination
      index_doc = index_doc.first #FIXME refactor 
      if parse_item_address
        # item_address must be defined in the scraper
        if parse_item_address.is_a? Proc
          @item_urls << (index_doc/self.item_address_selector).collect { |e| full_url_from_current_path(parse_item_address.call(e), self.path) }
        else
          puts "============ WARNING !!!!! ===================="
          puts "parse_item_address must be a proc."
        end
      else
        @item_urls << (index_doc/self.item_address_selector).collect{|u| full_url_from_current_path(u.get_attribute("href"), self.path)}
      end
    end
  end
  
  def replace_and_remove_urls
    replace_urls
    remove_urls
  end
  
  def replace_urls
    unless @replace_urls.empty?
      @item_urls.collect!{ |item_url| @replace_urls[item_url] ? @replace_urls[item_url] : item_url }
    end
  end
  
  def remove_urls
    #need to have "placeholders" for indexed attributes
    unless @remove_urls.empty?
      @item_urls.collect!{ |item_url| @remove_urls.index(item_url) ? 'skip' : item_url}
    end
  end
  
  
  def set_item_urls_without_link_selector
    @item_urls = []
  end
  
  # collection continued
  def create_local_item_files
    download_item_pages if has_item_pages?
    add_index_containers if has_indexed_attributes?
  end
  
  def download_item_pages
    @item_urls.each_with_index do |item_url, index|
      @filenames << download_item_page(item_url, agent, index) # @filenames used to associated indexed attributes with data
    end
  end
  
  # need a good way to make sure that the index info isn't added every single time
  # currently works by checking to see if the item pages were just downloaded
  # if they were, they don't have index info, so that's added
  # how to make sure correct page url is associated?
  def add_index_containers
    index_item_containers = []
    for index_doc in self.doc
      #this path has to travel a REALLY circuitous route
      path = index_doc[1]
      doc = File.read("pages/#{url_to_file_name(full_url_from_current_path(path))}")
      index_item_containers = index_item_containers + self.indexed_item_container_selector.get_item_containers(doc, path)
    end
    
    if has_item_pages?
      return unless @item_pages_just_downloaded
      @filenames.each_with_index do |file, index|
        File.open(file, 'a+'){|f| f.puts "\n#{index_item_containers[index].first}"}
      end
    else
      index_item_containers.each_with_index do |index_item_container, index|
        #check to see that file exists
        filename = get_filename(self.path, index)
        unless File.exists? filename
          data = file_meta_data(index_item_container[1]) + "\n" + index_item_container.first
          File.open(filename, 'a+'){|f| f.puts data}
        end
        
        @filenames << filename
      end
    end
  end
  
  # file handling
  def download_item_page(url, agent, index)
    filename = get_filename(url, index)
    # change this to check for url_to_file_name part and to possibly rename if necessary
    unless File.exists? filename
      @item_pages_just_downloaded = true
      puts "Downloading #{url}"
      hdoc = download_hdoc(url, agent)
      hdoc = file_meta_data(url) + "\n" + hdoc.parser.to_html
      File.open(filename, 'w+') do |f|
        f.puts "<scraper-file>"
        f.puts hdoc
        f.puts "</scraper-file>"
      end
    end
    filename
  end
  
  def get_filename(url, index)
    if !File.exists? 'pages'
      File.makedirs 'pages'
    end
    index = self.scraper.items.size + index
    index = index.to_s.rjust(8, '0')
    filename_url = url_to_file_name(url)
    filename = "pages/#{index}-#{filename_url}"
  end
  
  def file_meta_data(url)
    "<!--
Url:   #{url}
Index: #{self.path}
-->"
  end
  
  # create items
  def create_items
    @items = []
    #iterate through files
    @filenames.each do |filename|
      file = File.read(filename)
      number = /\d+/.match(filename)[0]
      item_url = get_item_url(file)
      
      puts "\n###\nScraping #{number} - #{item_url}\n###"
      
      item = Item.new(
        :parent => self,
        :url => item_url,
        :doc => file,
        :attributes => attributes,
        :combined_attributes => combined_attributes
      )
      item.each{|k,v|
        pp k.to_s.capitalize+": "+v.to_s
      }
      @items << item
    end
    
    @items
  end
  
  def get_item_url(file)
    /Url:   (.*?)$/.match(file)[1]
  end
end

class IndexedItemContainerSelector
  def initialize(selector)
    @selector = selector
    @selector_method = case @selector
    when Proc
      :proc_selector
    when String
      :hpricot_selector
    when Regexp
      :regex_selector
    end
  end
  
  def regex_selector(target)
    target.scan(@selector)
  end
  
  def hpricot_selector(target)
    Hpricot(target).search(@selector).collect{|h| h.to_s}
  end
  
  def proc_selector(target)
    @selector.call(target)
  end
  
  # target must be a string
  # originally target had to be an Hpricot object, but Hpricot changes a file's html in subtle ways
  # that makes it hard to write a regex to search it
  # returns array of strings
  def get_item_containers(target, path)
    self.send(@selector_method, target).collect{|t| ["<scraper-index>\n#{t}\n</scraper-index>", path] }
  end
end

# how to specify display rules?
# kind of uses the strategy pattern
# writers take a header, collection, and footer
# specify the string that should be written from those elements in the write method
class ResultWriter
  include HdocHandler
  include UrlHandler
  
  def initialize(configuration)
    # possible options for configurations:
    # type: right now, can only be CSV
    # header: data placed before the body
    
    # would be cooler to get the class name from the type, so that one can easily create a new writer class
    if configuration[:type] == 'csv'
      @writer = CsvResultWriter.new(configuration)
    end
  end
  
  def write(collection)
    filename = File.basename($0, '.rb') + "-#{collection.size}.csv" #adds size so you can easily enter that in the bulk upload admin
    # filename.sub!(/\.\./, '')
    File.open(filename, 'w') do |f|
      f.puts @writer.write(collection)
    end
  end
end

#is it really necessary to subclass ResultWriter? ResultWriter's methods are going to be overridden
# it might even make more sense to create another class for CsvResultWriter to subclass
# this started out as a generalized csv writer, but right now I'm just keeping it specific to DP
class CsvResultWriter < ResultWriter
  def initialize(configuration)
    @header = configuration[:header]
  end
  
  #does not need to worry about opening or writing to file
  # I don't like that @header and the fields themselves are specified so far from each other
  def write(collection)
    FasterCSV.generate do |csv|
      csv << @header if @header
      collection.each{|p|
        # will be interesting to see how to specify that a field is an array and should be expanded, like *p[:attachments]
        images = p[:images].flatten if p[:images]
        # if there is a default image explicitly defined, use that, otherwise, pop the first image out of images
        # additionally, remove the default images from images if image exist - so there are no duplicates
        if p[:default_image]          
          default_image_url = p[:default_image]
          images = images-[p[:default_image]].flatten if images
        else
          default_image_url = images.shift if images
        end
        # i'm not sure that I like this happening here
        attachment_index = -1
        attachments = p[:attachments].collect{|attachment, index|
          attachment_index += 1
          "#{attachment}*#{p[:attachment_names][attachment_index]}"
        } if p[:attachment_names]
        
        attachments = images.to_a | attachments.to_a
        attachments = attachments.select{|a| a && !a.empty?}
        
        p[:tags] = p[:tags].join(", ") if p[:tags].is_a? Array
        p[:description] = p[:description].join("\n\n") if p[:description].is_a? Array
                
        csv << [p[:name], p[:manufacturer], p[:url], p[:leadtime], p[:description], p[:category], p[:tags], default_image_url, *attachments]
      }
      csv << @footer if @footer
    end
  end
end