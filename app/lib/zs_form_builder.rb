class ZsFormBuilder < ActionView::Helpers::FormBuilder
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::RecordIdentificationHelper
  include ActionView::Helpers::PrototypeHelper
  include ActionView::Helpers::JavaScriptHelper
  include ActionView::Helpers::UrlHelper
  include ActionController::UrlWriter
  
  def file_field_with_label(name, label=nil, options = { })
    with_label('file', name, label, options) do |name, options|
      file_field_without_label(name, options)
    end
  end

  def state_field(name, label=nil, options = { })
    with_label('state', name, label, options) do |name, options|
      text_field_without_label(name, options)
    end
  end

  def date_field(name, label=nil, options = { })
    with_label('date', name, label, options) do |name, options|
      text_field_without_label(name, options)
    end
  end

  def text_area_with_label(name, label=nil, options={})
    options[:rows] ||= 5
    options[:cols] ||= 80
    with_label('text', name, label, options) do |name, options|
      text_area_without_label(name, options.merge('onclick' => 'new ResizingTextArea(this)'))
    end
  end

  def check_box_group(group_name, tags)
    content_tag(:div,
      tags.map { |name, value, checked|
        id = dom_id(object, group_name + '_' + value.to_s)
        element_name = dom_class(object) + '[' + group_name + '][]'
        content_tag(:label,
          content_tag(:input,nil,
                      :type => "checkbox", :value => value, :name => element_name,
                      :checked => if checked then "checked" end, :id => id) +
            " " + name, :class => 'boolean field')
      }.join(" "),
      :class => "check_box_group")
  end

  def check_box_with_label(name, label=nil, options={}, checked_value = '1', unchecked_value = '0')
    with_label('boolean', name, label || default_label(name) + '?', options) do |name, options|
      check_box_without_label(name, options, checked_value, unchecked_value)
    end
  end


  def select_with_label(name, label=nil, *args)
    options = args.extract_options!
    with_label('select', name, label, options) do |name, options|
      args << options
      select_without_label(name, *args)
    end
  end

  def text_field_with_label(name, label=nil, options = {})
    with_label('string', name, label, options) do |name, options|
      text_field_without_label(name, options)
    end
  end
  
  def integer_field(name, label=nil, options = {})
    with_label('integer', name, label, options) do |name, options| 
      text_field_without_label(name, options)
    end
  end
    
  def password_field_with_label(name, label=nil, options = {})
      with_label('password', name, label, options) do |name, options| password_field_without_label(name, options) end
  end

  def default_label(sym)
    sym.to_s.humanize
  end

  def tag_edit_field(name, label=nil, options = {})

    with_label('tags', name, label, options) do |name, options|
      text_field_with_auto_complete name, options.merge({ :autocomplete  => "off" })
    end
  end
  
  def submit_with_container(*args)
    content_tag(:div, submit_without_container(*args), :class => 'submit field')
  end
    
  def with_label(type, name, string = nil, options={}, &block)
    
    string ||= options.delete(:label) || default_label(name)
    label_options = { :for => options[:id] }
    label_options[:index] = options[:index] if options.has_key?(:index)
    
    content_tag(:div, label(name, string, label_options) + yield(name, options), :class => type + ' field')
  end
  
  alias_method_chain :submit, :container
  alias_method_chain :select, :label
  alias_method_chain :check_box, :label
  alias_method_chain :text_area, :label
  alias_method_chain :text_field, :label
  alias_method_chain :password_field, :label
  alias_method_chain :file_field, :label
end
