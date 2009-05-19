# encoding = UTF-8

def fix(text)
  ( text.to_s.
    gsub('&#146;', '&rsquo;').
    gsub(/\xC2\xB0\xC3\xBF\xC3\x92/,'-').
    gsub(/\xC2\xA1\xC3\x98\xC3\xB1/,'&ndash;').
    gsub(/\xC3\xA2\xE2\x82\xAC/, '&ndash;').
    gsub(/\xC3\x90\xC2\xA9/, 'é').
    gsub(/\xC3\x82/, '"').
    gsub(/\xE9/,'é').
    gsub(/\x82/, 'é').
    gsub(/\xA1/, 'í'))
end

def create_contact(i)
  contact_fields = %w(contact_first contact_last contact_address contact_city contact_state contact_zip contact_email contact_phone
                      contact_fax contact_title contact_organization contact_organization_url contact_public contact_notes)

  if i.attributes.values_at(*contact_fields).reject(&:blank?).empty?
    return nil
  else
    contact = Contact.new
    contact_fields.each do |c|
      contact[c.gsub(/^contact_/, '')] = i[c] unless i[c].blank?        
    end
    contact.created_at = i.created_at
    contact.save!
    
    return contact
  end
end

namespace :import do  
  desc "Imports RPC content"
  task :rpc => :environment do

    type_transformation = {
      'Part' =>    ReportPart,
      'Chapter' => ReportChapter,
      'PolicyStatement'   => ReportPolicyStatement,
      'ResearchHighlight' => ReportResearchHighlight,
      'Recommendation'    => ReportRecommendation,
      'ProgramExample'    => Program,
    }

    column_transformations = 
      %w(id title slug body summary parent_id created_at primary_date 
          publication_free legislation_scope legislation_status
          program_organization program_scope program_outcome 
          publication_state).map { |c| [c.to_sym, [c]] }
    column_transformations +=          
      [  [:position_label,   ['report_position_label']],
          [:callout,         ['policy_statement_blurb', 'newsletter_callout']],
          [:position,         %w(position page_position report_position)],
          [:full_title,       %w(report_display_title legislation_full_title publication_full_title)],
          [:author,           %w(publication_authors author)],
          [:periodical,       %w(publication_source)],
          [:url,              %w(publication_url legislation_url program_url)],
          [:legislative_body, %w(legislation_legislative_body)],
          [:primary_date,     %w(program_established primary_date)]]

    class RpcItem < ActiveRecord::Base
      set_table_name 'items'
      
      establish_connection(
        :adapter  => "mysql",
        :host     => "localhost",
        :username => "root",
        :database => "juice_development"
        )
      
      def self.inheritance_column
        ''
      end
    end

    def replace_with_citation(body)
      sentences = CiteParser.split_sentences(body)

      sentences = sentences.map do |s|
        p = CiteParser.parse(s)
        if !p.empty?
          pageref = p.last.delete('pageref')
          
          np = Publication.new(p.last)
          np.publicly_viewable = true
          np.created_by_id = 1
          
          np.slug = np.generate_slug('FN_')
          puts np.slug

          if c = Publication.find_by_slug(np.slug)
            np.attributes.each do |k, v|
              c[k] = v if c[k].blank? || v.to_s.length > c[k].to_s.length
            end
            c.save!
          else
            np.save!
            c = np
          end

          s.sub(p.first, '<citation to="' + c.slug + '"' + 
            if pageref then ' pages="' + pageref + '"' else "" end +
              '/>')
        else
          s
        end
      end

      sentences.join('') 
    end

    require 'nokogiri'

    Item.transaction do 
      Item.connection.execute 'SET CONSTRAINTS ALL DEFERRED'
      
      Item.connection.execute "DELETE FROM items WHERE website='reentry'"

      Tag.find_or_create_by_name_and_category('Homepage Snippet', 'Content')
      
      rpc_items = RpcItem.all

      maxid = rpc_items.map(&:id).max
      Item.connection.execute "select setval('items_id_seq'::regclass, numeric_larger(#{maxid}, (select max(id) from items))::bigint)"
      Item.connection.execute "select setval('item_versions_id_seq'::regclass, (select max(id) from item_versions)::bigint)"

      report = Report.create!(
        :created_by_id => 1,
        'title' => 'The Report', 
        :slug => 'Report',
        :website => 'reentry',
        'publicly_viewable' => true,
        'exclude_from_search' => true)      
        
      gvt = ContentPage.create!(
        :created_by_id => 1,
        :title => 'Government Affairs', 
        :exclude_from_search => true, 
        :website => 'reentry');

      STDERR.puts "Report ID: #{report.id}"

      rpc_items.each do |i|

        tags = []
        if i[:type] == 'Jcpublication'
          i[:type] = 'Publication'
          tags << 'Justice Center'      
        end


        #  | file                         | varchar(255) | YES  |     | NULL    |                |
        #  | file_label                   | varchar(255) | YES  |     | NULL    |                |

        obj = (type_transformation[i[:type]] || i[:type].constantize).new(
          :website => 'reentry')
        
        obj.publicly_viewable = i.publicly_viewable
        obj.slug  = i.slug
        obj.created_by_id = 1
        obj.version_notes = "Imported from RPC"
        obj.publication_free = i.publication_free

        if i[:type] == 'IssueArea'
          obj.title = fix i.title

          if i.search_page_show_alt_layout
            body = Nokogiri::HTML.fragment(fix(i.search_page_alt_body))

            obj.template = 'four_boxes'

            obj.extra = <<-BODY
<snippet name='Footer'>#{              fix i.search_page_alt_footer                                       }</snippet>
<snippet name='Body'>#{                fix i.search_page_alt_intro                                        }</snippet>
<snippet name='Title'>#{               obj.title                                                          }</snippet>
<snippet name='Justice Center Work'>#{ body.xpath('./table/tr[position()=1]/td[position()=1]').inner_html }</snippet>
<snippet name='In The Report'>#{       body.xpath('./table/tr[position()=1]/td[position()=2]').inner_html }</snippet>
<snippet name='Reentry in Action'>#{   body.xpath('./table/tr[position()=2]/td[position()=1]').inner_html }</snippet>
<snippet name='Resources'>#{           body.xpath('./table/tr[position()=2]/td[position()=2]').inner_html }</snippet>
            BODY
          else
            obj.body = fix i.body
          end
        else
          column_transformations.each do |to, from|
            value = i.attributes.values_at(*from).reject(&:blank?).first.to_s
            obj.send("#{to}=", fix(value)) unless value.blank?
          end

          if !obj.full_title.blank?
            case obj
            when Media
              obj.publisher = obj.full_title
              obj.full_title = ''
            when Legislation
              obj.reference_number = obj.title
              obj.title = obj.full_title
              obj.full_title = ''
            end

            if obj.full_title == obj.title
              obj.full_title = ''
            end
          end

          obj.id = i.id + 10000
          if obj.is_a?(ReportPart)
            obj.parent_id = report.id
          elsif !i.parent_id.nil?
            obj.parent_id = i.parent_id.to_i + 10000
          end

          STDERR.write " -" + obj.parent_id.to_s + '- '

          notes = RpcItem.connection.select_values('SELECT body FROM notes WHERE report_item_id = ' + i.id.to_s + ' ORDER BY position ASC')
          if (!notes.empty?)
            notes.each_with_index do |body, idx|

              marked_up_body = replace_with_citation(fix(body))

              [:full_title, :body, :summary, :callout].each do |sym|
                obj.send("#{sym}=", obj.send(sym).sub(%Q{<note_ref number="#{idx + 1}"></note_ref>}, "<footnote>" + marked_up_body + "</footnote>"))
              end
            end
          end
      
          #      [:body, :summary, :full_title, :policy_statement_blurb, :newsletter_callout, :program_outcome].each do |sym|
          #        obj[sym] = replace_with_citation(obj[sym])
          #      end
          if cx = create_contact(i)
            obj.contacts << cx
          end
        end
        STDERR.write "#{obj.slug}:"

        obj.generate_slug if obj.slug.blank?

        if obj.slug == 'national_initiatives' && obj.parent_id.nil?
          obj.parent_id = gvt.id
        end
        
        sx = 0;
        if obj.is_a? Item
          obj.slug = obj.generate_slug + '_' + (sx += 1).to_s while !Item.find_by_slug_and_parent_id(obj.slug, obj.parent_id).nil? 
        end

        obj.save!

        STDERR.write "#{obj.id}, "

        if obj.respond_to? :related_items=
          obj.related_items = (obj.related_items + 
            Item.find_all_by_id(RpcItem.connection.select_values("SELECT related_item_id + 10000 from related_items WHERE item_id=#{i.id} UNION SELECT item_id from related_items WHERE related_item_id=#{i.id}"))
          ).uniq
        end

        tags += (i.states || '').split(/\s+/)
        tags = tags.map { |t| if STATES.has_key?(t) then STATES[t] else t end }
        tags += RpcItem.connection.select_values('SELECT name FROM tags INNER JOIN taggings ON tag_id = tags.id WHERE taggable_type="Item" and taggable_id=' + i.id.to_s)

        if obj.slug.start_with?('homepage_pub_snippet')
          tags << 'Homepage Snippet'
          obj.update_attributes(:publicly_viewable => true, :exclude_from_search => true)
        end
        
        obj.tags = Tag.find_all_by_name(tags)
      end
    
      ContentPage.create!(
        :created_by_id => 1,
        :slug => 'reentry',
        :website => 'reentry',
        :publicly_viewable => true,
        :exclude_from_search => true,
        :title => "Reentry Policy Council",
        :body => <<-EOP)
<!-- initial box must be one of: report rpc reentry -->
<homepage_boxes initial="rpc" />

<div class="striped_head homepage_bottom_half">
	<div class="float_left">
		<h2>Spotlight Announcements</h2>
    <newest_items count="2" type="Announcement" website="reentry" />
	</div>

	<div class="float_right" >
		<h2>Reentry News Clips</h2>

    <newest_items count="2" type="Media" website="reentry" />
	</div>

	<div class="clear"></div>
	<div class="float_left align_right" style="border-right: none;">
    <p class="home_page_more_link">
      <a href="/announcements">More Spotlight Announcements</a>
    </p>
  </div>    

	<div style="float: right; text-align: right;">
    <p class="home_page_more_link">
      <a href="/media">More Reentry News Clips</a>
    </p>
  </div>

	<div class="clear"></div>

	<div class="striped_gold">
		<h2>Other Justice Center Projects</h2>
		<p><a target="_blank" href="http://cjmh-infonet.org" class="bold">Criminal Justice / Mental Health InfoNet</a></p>
		<p class="homepage_summary">
			The Justice Center's online database that provides a comprehensive inventory of collaborative criminal 
			justice/mental health activity across the country.</p>
    <p><a target="_blank" href="http://consensusproject.org" class="bold">Consensus Project</a></p>
    <p class="homepage_summary">
      An unprecedented, national effort to help policymakers improve the response to people with mental illnesses in the criminal justice system.</p>
    <p><a target="_blank" href="http://justicereinvestment.org" class="bold">Justice Reinvestment</a></p>
    <p class="homepage_summary">
      A data-driven strategy for policymakers to reduce spending on corrections and increase public safety.
    </p>				
  </div>
</div>
      EOP
      
      Item.connection.execute "select setval('items_id_seq'::regclass, (select max(id) from items)::bigint)"
      Item.connection.execute "select setval('item_versions_id_seq'::regclass, (select max(id) from item_versions)::bigint)"
      
      unparented_items = Item.find(:all, :conditions => 'parent_id is not null and not exists (select 1 from items i where i.id = items.parent_id)')
      
      unparented_items.each do |i|
        j = 0
        i.slug = i.generate_slug + '_' + (j += 1).to_s while !Item.find_by_slug_and_parent_id(i.slug, nil).nil?
        i.parent = nil
        i.save!
      end
    end
  end
end

