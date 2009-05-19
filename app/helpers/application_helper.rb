# Methods added to this helper will be available to all templates in the application.
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  Infinity = 1.0/0
  require 'nokogiri'
  
  def headline_for_class(klass)
    klass.respond_to?(:headline) ? klass.headline : klass.to_s.underscore.humanize.pluralize
  end
  
  def admin?
    @user && @user.admin?
  end

  def choose_snippet(reference)
    if @user && @user.admin?
      link_to("[edit]", edit_snippet_reference_path(reference, :params => { :come_back_to => url_for(nil)}))
    else
      ""
    end
  end

  def default_snippet
    if @user && @user.admin?
      "(put a snippet here!)"
    end
  end

  def snippet_for(name)
    reference = SnippetReference.find_or_create_by_name(name)

    if reference.is_a?(SnippetReference)
      content_tag(:div, reference.snippet.maybe.body || default_snippet, :class => 'snippet', :id => name) + choose_snippet(reference)
    end
  end

  def breadcrumb_for (item)
    breadcrumb = []

    p = item.parent

    while p do
      url = p.expected_url 
      breadcrumb.unshift(content_tag(:a, p.title, :href => url))
      p = p.parent
    end

    content_tag(:div, breadcrumb.join(' > '), :class => 'breadcrumb')
  end

  def extract_template_sections(file)
    return [] if file.blank?
    if f = File.open("templates/#{file}")
      text = f.read
      return [] if text.blank?

      if dom = Nokogiri::HTML.fragment(text)
        x = dom.xpath('.//section').map do |nr|
          nr.attributes["name"].to_s
        end
      end
    else
      raise "Couldn't open file #{file}"
    end
  end
  
  def custom_tags
    def load_custom_tags
      Dir.open(RAILS_ROOT + '/app/views/tags').
        grep(/^_/).
        map { |f| f.gsub(/^_([^\.]+).*/,'\1') }
    end
    @custom_tags ||= load_custom_tags
  end

  def fixup_content(text, vars = {})
    return "" if text.blank?
    
    if dom = Nokogiri::HTML.fragment("<div>#{text}</div>")
      dom.xpath('.//*[' + custom_tags.map { |t| "name()='#{t}'" }.join(' or ') + ']').each do |node|
        # if the affected node was contained in another node, reprocessing it will have no effect.
        # nodes are always processed in linear order of appearance (i.e. depth-first search order)
        # and unlinking a node (swapping it out) causes its children to be reparented -- the dom is 
        # no longer their ancestor.

        next unless node.ancestors.reject(&:nil?).last == dom

        hash = {}
	
        node.attributes.each do |k, v| 
          hash[k.to_sym] = v.to_s 
        end

        text = render(:partial => '/tags/' + node.name.to_s, :locals => vars.merge({ :attributes => hash, :node => node, :body => node.inner_html}) )

        t = Nokogiri::HTML.fragment('<div>' + fixup_content(text) + '</div>')
        t.children.first.children.each do |c|
          node.add_previous_sibling(c)
        end
        node.unlink
      end

      dom.children.first.inner_html
    else
      ""
    end
  end
  

  def current_class(text)
    if @item && @item.ancestors.detect { |a| text =~ /['"]#{Regexp.quote(a.expected_url)}['"?#]/ }
      'current'
    else
      ''
    end
  end
  
  def nav_menu(list)
    menu_content = ''
    list.each_with_index do |item,index|
      position_class = (index > 0 ? (index == list.size-1 ? 'last ' : '') : 'first ')
      item_class = "#{position_class}#{current_class(item)}".strip
      
      menu_content << "\n" << content_tag(:li, item, :class => (item_class.blank? ? nil : item_class))
    end
    
    content_tag(:ul, menu_content, :class => 'nav')
  end
  
  def sub_nav_menu(name, list)
    link_to(name,'#') + 
      content_tag(:ul,
      maybe(list) { |l| l.map { |i| content_tag(:li, i, :class => current_class(i)) }.join("") } || "",
      :class => 'subnav')
  end
  
  def children_for (item)
    content_tag(:ul,
      item.children.map do |c|
        content_tag(:li, content_tag(:a, c.title, :href => "/admin/contents/#{c.id}"))
      end.join("")
    )
  end

  # Creates previous/next navigation controls for the given item.
  def prev_next_navigation_for(item,nav_id=false)
    nav = String.new
    
    if item.previous_sibling
      nav << link_to('&lt;', item.previous_sibling.expected_url)
    else
      nav << "&lt;"
    end
    
    nav << ' '
    
    if item.next_sibling
      nav << link_to('&gt;', item.next_sibling.expected_url)
    else
      nav << "&gt;"
    end
    
    content_tag(:div, nav,:id => nav_id, :class => 'nav_np')
  end

  # Recursively constructs a nested list of a given item's descendants
  #
  # ==== Options
  #
  # * <tt>:list_type</tt> - The type of list of construct, either <tt>:ul</tt> (default), <tt>:ol</tt>, or <tt>:dl</tt>.
  # * <tt>:max_depth</tt> - Limits the depth of recursion.
  # * <tt>:labeled</tt> - Choose to display the labeled version of each item's title.
  #
  def descendants_for (item, options = {}, current_depth = 0)
    options.reverse_merge!(:list_type => :ul, :max_depth => Infinity, :labeled => false)
    current_depth += 1

    raise(ArgumentError, "Invalid :list_type") unless [:ul,:ol,:dl].include?(options[:list_type])

    item.public_children.partition_by(&:class).map { |klass, items|
      content_tag(options[:list_type],
        items.map { |child|
          child_content = link_to(fixup_content(options[:labeled] ? child.labeled_title : child.title), child.expected_url)
          unless child.children.empty? || current_depth >= options[:max_depth]
            child_content += "\n" + descendants_for(child, options, current_depth)
          end
          
          if options[:list_type] == :dl
            content_tag(:dt, child.position_label + '.') + content_tag(:dd, child_content)
          else
            content_tag(:li, child_content)
          end
        }.join("\n"),
        :class => klass.name.downcase
      )
    }.join("\n")
  end

  def form_for(*args, &block)
    options = args.extract_options!
    record = args.first

    if record.is_a?(ActiveRecord::Base)
      if record.new_record?
        options[:url] = url_for(:action => 'create')
        options[:method] = 'post'
      else
        options[:url] = url_for(:action => 'update', :id => record)
        options[:method] = 'put'
      end
    end

    args << options.merge({ :builder => ZsFormBuilder })
    concat('<div class="form">')
    super(*args, &block)
    concat('</div>')
  end
  
  def fields_for(*args, &block)
    options = args.extract_options!
    args << options.merge({ :builder => ZsFormBuilder })
    super(*args, &block)
  end

  def show_page(object, *css_classes, &block)
    classes = (['show_page'] + css_classes.flatten).reject(&:blank?).join(' ')
    concat("<div><dl class=\"#{classes}\">")
    show_fields(object, &block)
    concat('</dl></div>')
  end

  def show_fields(object, &block)
    yield ShowPageBuilder.new(object)
  end

  def controller_name
    @controller.controller_name.singularize
  end

  def tab_group(id, &block)
    concat('<ul class="control_tabs" id="' + id + '">')
    tabs = []
    yield tabs # this is purely an OUT parameter
    concat('</ul>')
    tabs.each_with_index do |tabblock, i|
      concat("<div class='control_tabs' id='tab_#{i+1}'>")
      
      if i < tabs.length - 1
        concat("<div style='text-align: right'>Next page: <a href='#' class='#{id}_next'>#{tabs[i+1][0]}</a></div>")
      end
      
      tabblock[1].call()
      concat("</div>")
    end
    concat javascript_tag(<<-EOS)
var #{id} = new Control.Tabs('#{id}'); 
$$('.#{id}_next').each(function(i) { 
  i.observe('click', function(e) { 
    this.next(); 
    Event.stop(e); 
  }.bindAsEventListener(#{id}));
});
    EOS
  end
  
  def tab_content(tabs, label, longlabel, &block)
    tabs << [longlabel, block] # this block doesn't execute until the end of tab_group
    concat("<li><a href='#tab_#{ tabs.length }'><span>#{ label }</span></a></li>")
  end
  
  def paginate_results(url, per_page, items)
    concat(items.length.to_s + " results")
    
    page = params['page'].maybe.to_i || 1

    if items && items.length > 0
      this_page = items[((page-1) * per_page) .. (page * per_page) - 1]
      if this_page && this_page.length > 0
          
        pages = (items.length.to_f / per_page).ceil
        concat('<br /> Page ') 
  
        if page > 6
          concat(link_to("1", :action => :show, :params => params.merge({ :url => url.gsub(/^\//,''), :page => 1 })))
          concat(' . . .')
        end
  
        if page > 1
          concat(link_to("&lt;--", :action => :show, :params => params.merge({ :url => url.gsub(/^\//,''), :page => page - 1 })))
        end
  
        [page - 5, 1].max.upto(page-1) do |p|
          concat(" ")
          concat(link_to(p.to_s, :action => :show, :params => params.merge({ :url => url.gsub(/^\//,''), :page => p })))
          concat(" ")
        end
  
        concat(" ")
        concat(page.to_s)
        concat(" ")
  
        (page + 1).upto([page + 5, pages].min) do |p|
          concat(" ")
          concat(link_to(p.to_s, :action => :show, :params => params.merge({ :url => url.gsub(/^\//,''), :page => p })))
          concat(" ")
        end
  
        if page < pages
          concat(" ")
          concat(link_to("--&gt;", :action => :show, :params => params.merge({ :url => url.gsub(/^\//,''), :page => page + 1 })))
          concat(" ")
        end
  
        if page < pages - 5
          concat(' . . . ')
          concat(link_to(pages.to_s, :action => :show, :params => params.merge({ :url => url.gsub(/^\//,''), :page => pages })))
          concat(" ")
        end
      
        yield((page-1) * per_page, this_page)
      end
    end
  end
end

