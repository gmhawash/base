class SurveyItem
  attr_accessor :attributes, :body, :text

  def initialize (node)
    self.text = node
    self.attributes = {}

    node.attributes.each do |k, v|
       self.attributes[k.to_sym] = v.to_s
    end

    self.body = node.xpath('./span')
    self.body =  node.text if self.body.text.strip.blank?
  end
end

class SurveyData
  attr_accessor :attributes, :body, :item, :user, :survey

  def initialize(attributes, body, item, user, survey=nil)
    self.attributes = attributes
    self.body = body
    self.item = item
    self.user = user
    self.survey = survey
  end
  
  def unanswered_required_questions
    parsed_body.xpath('.//question').select do |q|
      q.get_attribute('required') && !response.any? {|k, v| k.split(':')[0] == q.get_attribute('code')  && !v.strip.blank?}
    end

  end
  
  def page_number (question)
    question.xpath('./ancestor::group').xpath('./preceding-sibling::*').length + 1
  end
  
  def response
    self.survey ||= Survey.find_all_by_survey_id_and_user_id(self.item.id, self.user.id, :conditions => "status='new' OR status='update'").first
    self.survey.maybe.response || {}
  end
  
  def parsed_body
    @node ||= Nokogiri::HTML.fragment("<div>#{body}</div>")
  end

  def pages
    parsed_body.xpath('.//group')
  end

  def build_items (nodes)
    nodes.map do |n|
      SurveyItem.new(n)
    end
  end

  def questions (page)
    build_items page.xpath('./question')
  end

  def answers(question)
    build_items question.xpath('.//answer')
  end

  def current_page(index)
    index ||= 1
    pages[index - 1]
  end
  
  def page_count
    pages.length
  end
  
  def question_key(title)
    if @keys.blank?
      @keys = {}
      pages.map do |p|
        questions(p).map do |q|

          question_id = q.attributes[:code].to_s
          question_type = q.attributes[:type].to_sym
          field_name = "#{question_id}"

          case question_type
          when :textfield, :textbox then  @keys.merge!({q.body.inner_html => field_name})
          when :singlechoice        then  @keys.merge!({q.body.inner_html => question_id})
          end
        end
      end
    end

    @keys[title]
  end

  def answer_text(key, subkey, value)
    node =  if subkey.blank?
              pages.xpath(".//question[@code='#{key}']//answer").first
            else
              pages.xpath(".//question[@code='#{key}']//answer[@code='#{subkey}']").first
            end

    raise [key, subkey].inspect + pages.xpath(".//question[@code='#{key}']//answer").inspect if node.nil?

    text = ''
    type = ''
    value = node['value']

    if node
      if node.parent.name == 'answer'
        text = node.parent.text
        type = node['type'] || node.parent['type'] || node.parent.parent['type']
      else
        text = node.text
        type = node['type'] || node.parent['type']
      end
    end

    value = case type
            when 'textfield' then value.to_s
            when 'textbox', 'multiplechoice', 'singlechoice'   then text
            end

    return type, value
  end

  def question_title(key)
    code = key.split(':')[0]
    node = pages.xpath("./question[@code='#{code}']")
    node.xpath('./span').text || node.inner_html
  end
  
  def method_missing(action, *args)   
    response[question_key(action.to_s.humanize.titleize)]    
  end
  
  def map_item
    hash = [
      [:title,   response[self.question_key('Program Name')]],
      [:summary, response[self.question_key('Briefly (in 2–3 sentences) describe your program')]]
    ]
    
    Hash[*hash.select { |k,v| !v.blank? }.flatten]
  end

  def map_item=(item)
    response[self.question_key('Program Name')] = item.title
    response[self.question_key('Briefly (in 2–3 sentences) describe your program')] = item.summary

    if contact = item.contacts.first
      response[self.question_key('Job Title')]            = contact.title
      response[self.question_key('Organization URL')]     = contact.organization_url
      response[self.question_key('First name')]           = contact.first
      response[self.question_key('Last name')]            = contact.last
      response[self.question_key('Phone')]                = contact.phone
      response[self.question_key('Email')]                = contact.email
      response[self.question_key('Address')]              = contact.address
      response[self.question_key('City')]                 = contact.city
      response[self.question_key('State')]                = contact.state
      response[self.question_key('Zip Code')]             = contact.zip
    end
  end

  def map_contact
    { :title            => response[self.question_key('Job Title')] || '',
      :organization_url => response[self.question_key('Organization URL')] || '',
      :first            => response[self.question_key('First name')] || '',
      :last             => response[self.question_key('Last name')] || '',
      :phone            => response[self.question_key('Phone')] || '',
      :email            => response[self.question_key('Email')] || '',
      :address          => response[self.question_key('Address')] || '',
      :city             => response[self.question_key('City')] || '',
      :state            => response[self.question_key('State')] || '',
      :zip              => response[self.question_key('Zip Code')] || ''
    }
  end
end

