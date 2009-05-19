require 'yaml'
def import_survey(ii)
  
  return if ii.survey_response.maybe.strip.blank?

  item_version = ItemVersion.find_by_title(fix(ii.title))
  puts "Importing survey: " + item_version.title
  item_version.survey.maybe.destroy
  
  template = ContentPage.find_by_slug(ii.survey_type.downcase)
  
  u = User.find_by_email(item_version.contacts.first.maybe.email.maybe.downcase)
  
  puts "Found user #{u.maybe.name}"
  
  survey = Survey.new(:user_id           => u.maybe.id || 1,
                      :survey            => template.current_version,
                      :program_example   => item_version,
                      :status            => 'approved')

  survey.survey_data.map_item = item_version
  survey.survey_data.map_contact = item_version.contacts.first if !item_version.contacts.empty? 
  
  item_version.save!
  
  response = YAML.load ii.survey_response

  f = File.open(RAILS_ROOT + '/db/import/infonet_smerf/' + ii.survey_type.downcase + '.yml')
  yaml = YAML.load f
  
  survey_data = SurveyData.new(nil, template.body, template, survey.user.id)
  pages = Nokogiri::HTML.fragment(template.body).xpath('.//group')
  pages.each_with_index do |page, i|
    survey_data.questions(page).each do |q|
      question_id = q.attributes[:code].to_s
      question_type = q.attributes[:type].to_sym

      answers = survey_data.answers(q.text)

      answers.select { |a| a.attributes[:type] == 'textfield' }.each do |a|
        survey.response[question_id + ':' + a.attributes[:code]] = response[a.attributes[:code]].to_s
      end
      
      case question_type
      when :textfield, :textbox then  survey.response[question_id] = response[question_id] if response[question_id] 
      when :singlechoice        then  survey.response[question_id] = response[question_id] if response[question_id]
      when :multiplechoice      then
        response[question_id].each do |r|
          survey.response["#{question_id}:#{r[0]}"] = '1'
        end if response[question_id]
      end
    end 
  end 

  survey.save!
end


namespace :import do
  
  desc "Imports Infonet content"
  task :infonet => :environment do
    class InfonetItem < ActiveRecord::Base
      set_table_name "items"
      establish_connection(
        :adapter  => "mysql",
        :host     => "localhost",
        :username => "root",
        :database => "csg_infonet_development"
        )
    end

    class InfonetUser < ActiveRecord::Base
      set_table_name "users"
      
      establish_connection(
        :adapter  => "mysql",
        :host     => "localhost",
        :username => "root",
        :database => "csg_infonet_development"
        )
    end

    class InfonetRegisteredUser < ActiveRecord::Base
      set_table_name "registered_users"
      
      establish_connection(
        :adapter  => "mysql",
        :host     => "localhost",
        :username => "root",
        :database => "csg_infonet_development"
        )
    end
    
    Item.transaction do 
      InfonetUser.all.each do |user|
        u = User.find_or_create_by_email(user.email.strip)
        u.name = [user.first_name, user.last_name].reject(&:blank?).join(' ')
        u[:password] = user.password
        u[:password_salt] = 'tlover_lexip'
        u.activated = true
        u.admin = user.is_admin
        u.save(false)
      end

      InfonetRegisteredUser.all.each do |user|
        u = User.find_or_create_by_email(user.email_address.strip)
        u.name = [user.first_name, user.last_name].reject(&:blank?).join(' ')
        u.admin = false
        u.activated = true
        u[:password] = user.password_hash
        u[:password_salt] = user.password_salt
        u.save(false)
      end
      
      Survey.delete_all
      Item.delete_all("website='infonet'")
      
      count = 0
  
      InfonetItem.find(:all).each do |ii|
        type = case ii.data_type.singularize
               when 'Research' then 'Publication'
               when 'Page'     then 'ContentPage'
               when '', nil    then 'Publication'
               else ii.data_type.singularize
               end

        cpi = type.constantize.new(
          :created_by_id             => 1,
          :version_notes             => "Imported from Infonet",
          :website                   => 'infonet',
          :title                     => fix(ii.title),
          :author                    => fix(ii.authors),
          :body                      => fix(ii.content),
          :summary                   => fix(ii.description),
          :extra                     => fix(ii.extra).gsub("\n", "<br />\n"),
          #:source                    => ii.source,
          :url                       => ii.url || '',
          :publicly_viewable         => !!ii.published,
          :primary_date              => ii.item_date.to_s,
          #:slug                      => ii.slug, 
          #:full_title                => ii.full_title,
          :parent_id                 =>  ii.original_item_id
          #:created_at                => ii.created_at,
          #:updated_at                => ii.updated_at,
          #:publication_authors       => ii.publication_authors,
          #:publication_source        => ii.publication_source,
          #:publication_state         => ii.publication_state,
          #:publication_free          => ii.publication_free,
          #:legislative_body          => ii.legislation_description
          #:legislation_scope         => ii.legislation_scope,
          #:legislation_status        => ii.legislation_status,
          #:newsletter_callout        => ii.newsletter_callout,
          #:program_organization      => ii.program_organization,
          #:program_scope             => ii.program_scope,
          #:program_established       => ii.program_established,
          #:program_outcome           => ii.program_outcome,
          #:policy_statement_blurb    => ii.policy_statement_blurb,
        )
        
        
        count += 1
       
        cpi.id = ii.id

        states = YAML.load(ii.states).map(&:strip).reject(&:blank?).map { |s| s.split(/\W+/) }.flatten
        state_names = states.map { |s| s == 'National' ? 'Nationwide' : STATES[s.upcase] }
        tags = Tag.find_all_by_name(state_names)
        raise "State mismatch: #{states.inspect} / #{state_names.inspect} / #{tags.inspect}" unless states.length == state_names.length && states.length == tags.length
        
        if !ii.category.blank?
          main_tag = Tag.find_by_name(ii.category)
          
          cpi.tags = [main_tag]
          content = [ii.title, ii.description, ii.content, ii.extra].join('/').downcase
          case ii.category
          when 'Law Enforcement'
            if content =~ /\bcit\b/ || content.include?('crisis intervention team')
              cpi.tags << Tag.find_by_name('Crisis Intervention Team')
            end
          when 'Courts'
            if content =~ /\bmhc\b/ || content.include?('mental health court')
              cpi.tags << Tag.find_by_name('Mental Health Court')
            end
          end
        end
        
        cpi.slug = cpi.generate_slug
        
        if cpi.slug == 'about'
          cpi.slug = 'about_infonet'
        end
        
        i = 0;
        cpi.slug = cpi.generate_slug + '_' + (i += 1).to_s while Item.find_by_slug(cpi.slug)

        puts "#{count} #{ii.id} #{cpi.slug}"

        cpi.save!
        
        if cx = create_contact(ii)
          cpi.contacts << cx
        end
      end
     
      parent_survey = ContentPage.find_by_slug('surveys')
      parent_survey.current_version.body = parent_survey.current_version.extra 

      parent_survey.current_version.body +=  <<EOF
      <survey_list status='available' ><h3>Available surveys</h3></survey_list>
      <survey_list status='new' ><h3>Surveys in progress</h3></survey_list>
      <survey_list status='submitted' ><h3>Surveys submitted for review</h3></survey_list>
      <survey_list status='complete' ><h3>Completed surveys</h3></survey_list>
      <survey_list status='update' ><h3>Surveys waiting for update</h3></survey_list>
      <survey_list status='approved' ><h3>Approved surveys</h3></survey_list>
EOF
      parent_survey.current_version.extra = ''
      parent_survey.current_version.save!

      require 'yaml'
      %w(lesurvey mhcsurvey).each do |survey|
        f = File.open(RAILS_ROOT + '/db/import/infonet_smerf/' + survey + '.yml')
        yaml = YAML.load f

        body = "<survey name='#{yaml['smerfform']['name']}'>\n"
        sort_by = yaml['smerfform']['group_sort_order_field'] || 'code'
        yaml['smerfform']['groups'].sort_by { |g| g[1][sort_by] }.each_with_index do |g, i|
          body << "  <group label='#{g[0]}' code='#{g[1]['code']}' shortname='#{g[1]['shortname']}' name='#{g[1]['name']}'>\n"
          g[1]['questions'].sort_by { |q| q[1]['sort_order'].to_i }.each do |q|
            r = q[1]['required'] ? ' required="true"' : ''
            m = q[1]['mapped'] ? " mapped='#{q[1]['mapped']}'" : ''
            
            body << "    <question code='#{q[1]['code']}' type='#{q[1]['type']}'#{r}#{m}>\n"
            body << "      <span>#{fix(q[1]['question'].strip)}</span>\n"
            
            if q[1]['answers']
              q[1]['answers'].sort.each do |a|
                body << "      <answer code='#{a[1]['code']}' default='#{a[1]['default']}'>#{fix(a[1]['answer'])}"
                if a[1]['subquestions']
                  body << "\n"
                  a[1]['subquestions'].each do |sql, sq|
                    body << "      <answer type='textfield' code='#{sq['code']}'/>\n"
                  end
                  body << "      "
                end
                body << "</answer>\n"
              end
            else
              body << "      <answer/>\n"
            end
            body << "    </question>\n"
          end
          body << "  </group>\n"
        end
        body << "</survey>\n"
        
        cp = ContentPage.create!(
          :created_by_id => 1,
          :version_notes => "Imported from Infonet SMERF survey",
          :publicly_viewable => true,
          :exclude_from_search => true,
          :parent => parent_survey,
          :title => yaml['smerfform']['name'],
          :slug => survey,
          :body => body,
          :website => 'infonet')
      end

      InfonetItem.find(:all, :conditions => { :data_type => 'Programs' }, :order => 'title, id ASC').each do |ii|
        import_survey ii
      end
    end
    
  end

  task :survey => :environment do
    class InfonetItem < ActiveRecord::Base
      set_table_name "items"
      establish_connection(
        :adapter  => "mysql",
        :host     => "localhost",
        :username => "root",
        :database => "csg_infonet_development"
        )
    end
    Survey.transaction do
      InfonetItem.find(:all, :conditions => { :data_type => 'Programs' }, :order => 'title, id ASC').each do |ii|
        import_survey ii
      end
    end
  end

end

