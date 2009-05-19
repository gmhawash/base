class ShowPageBuilder
  instance_methods.each { |meth| undef_method(meth) unless meth =~ /\A__/ }
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::JavaScriptHelper

  def initialize(object)
    @object = object
  end

  protected
  def extract_format(attr_name)
    def format_for_object(object, attr_name)
      f = object.column_for_attribute(attr_name).maybe.sql_type
      if (!f)
        d = object.class.delegated_to(attr_name)
        f = case d
        when Symbol then format_for_object(object.send(d), attr_name)
        when Class  then d.column_for_attribute(attr_name).maybe.sql_type
        else attr_name.to_s.singularize
        end
      end
      f
    end
    
    f = format_for_object(@object, attr_name)
    case f
    when /character varying/: 'string'
    when /varchar/          : 'string'
    when /numeric/          : 'decimal'
    when /int/              : 'integer'
    when /bool/             : 'boolean'
    when /tag/              : 'tag'
    else                      f
    end
  end

  def row_contents(attr_name, label = nil, format = nil)
    label ||= attr_name.to_s.humanize
    format ||= extract_format(attr_name)
    value = @object.send(attr_name)
    label = value if /tag/.match(format.to_s)
    formatted_row(label, value, format, attr_name)
  end
  
  def formatted_row(label, value, format, attr_name)
    value = apply_formatting(format, value)

    value = yield(value) if block_given?

    value = '&nbsp;'     if value.blank?

    label = label + '?' if /bool/.match(format.to_s)

    "<dt class='#{format.to_s} #{attr_name.to_s}'>#{label.to_s}</dt><dd>#{value}</dd>"    
  end
  public

  def apply_formatting(format, value)
    case format.to_s
    when 'boolean'  then value ? 'Yes' : 'No'
    when 'currency' then '$%.02f' % value
    when 'grams'    then html_escape(value.to_s) + ' g'
    when 'file'     then "<a href='#{value}'>#{value}</a>"
    when 'tag'      then 'Yes'
    when 'highlight_html' 
      ::Uv.parse( value.strip, "xhtml", "html", false, "iplastic").gsub("\n", '<br />')
    else                 html_escape(value)
    end
  end

  def show_attribute(attr_name, label = nil, format = nil)
    row_contents(attr_name, label, format)
  end
  
  def show_value(label, value, format, attr_name)
    formatted_row(label, value, format, attr_name)
  end

  def hidden_attribute(attr_name, label = nil)
    content = row_contents(attr_name, label)
    content_tag(:div, content, :class => 'show_page_row hidden')
  end
  alias :hidden :hidden_attribute

  def method_missing(meth, *args, &block)
    if @object.respond_to?(meth)
      show_attribute(meth, *args, &block)
    else
      super
    end
  end
end
