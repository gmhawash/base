namespace :import do
  
  desc "Imports Consensus Project content"
  task :cp => :environment do

    
    Item.connection.execute "select setval('items_id_seq'::regclass, (select max(id) from items)::bigint)"

    
    ImportPath = "#{RAILS_ROOT}/db/import/cp_data"
    AllFiles   = Dir.entries(ImportPath)
    WebsiteId  = 'consensus'

    Content = { 
      'about'       => %w(consensus-project justice-center project-funders partners contact-us job-openings),
      'issue-areas' => %w(law-enforcement courts corrections victims jail-diversion other-issues),
      'updates'     => %w(announcements-and-events features newsletters media-coverage),
      'resources'   => %w(research fact-sheets publications press-room government-affairs),
    }
    
    Front = [
      ['acknowledgments',                'Acknowledgments',               []],
      ['executive-summary',              'Executive Summary',             []],
      ['law-enforcement-advisory-board', 'Law Enforcement Advisory Board',[]],
      ['courts-advisory-board',          'Courts Advisory Board',         []],
      ['corrections-advisory-board',     'Corrections Advisory Board',    []],
      ['mental-health-advisory-board',   'Mental Health Advisory Board',  []],
      ['intro',                   'Introduction',
        [['about-problem',     'About the Problem'     ],
        ['reasons-for-hope',  'Reasons for Hope'      ],
        ['how-to-use-report', 'How to Use this Report'],
        ['getting-started',   'Getting Started'       ],
        ['next-steps',        'Next Steps'            ]]]]
      
    Chapters    = [
      ['Chapter I',    1..1], 
      ['Chapter II',   2..6,   'Chapter II Conclusion'],
      ['Chapter III',  7..16,  'Chapter III Conclusion'],
      ['Chapter IV',   17..23], 
      ['Chapter V',    24..26], 
      ['Chapter VI',   27..34], 
      ['Chapter VII',  35..43], 
      ['Chapter VIII', 44..46] 
    ]

    Back = [
      ['glossary',           'Glossary'],
      ['programscited',      'Programs Cited'],
      ['federal-benefits',   'An Explanation of Federal Medicaid and Disability Program Rules'],
      ['project-history',    'Project History / Methodology'],
      ['steering-committee', 'Steering Committee'],
      ['bibliography',       'Bibliography']
    ]
    
    count       = 0
 
    def parse(file)
      text = ""
      reading = false
      File.read("#{ImportPath}/#{file}").each do |line|
        if line.include?("BEGIN SLAVE")
          reading = true
        elsif line.include?("END SLAVE")
          reading = false
        end
        if reading
          text << line
        end
      end      
      
      text.gsub!('<p class=MsoFootnoteText<a', '<p class=MsoFootnoteText><a')
      text.gsub!(/color="([^">]+)>/, 'color="\1">')
      Nokogiri::HTML.fragment(text)
    end
      
    def fix_footnotes(element)
      element.xpath('.//a[contains(@name, "_ftnref")]').each do |link|
        puts "Found link: #{link}"
        ref = element.xpath('.//a[@name="'+link['href'].to_s.gsub(/^#/,'')+'"]').first
        puts "Found ref: #{ref}"

        p = ref.parent
        if p.parent.name == 'div' && '#_' + p.parent['id'].to_s == link['href']
          p = p.parent
        end
        
        note = fix(p.inner_html.strip.gsub(/<a href="#_ftnref.*?<\/a>/,''))
        
        note.gsub!(/<span[^>]+>/,'')
        note.gsub!('</span>','')
        
        puts "Found note: #{note}"
        link.swap('<footnote>' + note + '</footnote>')
        ref.parent.swap('')
      end
      
      element.xpath('.//span[@class="MsoFootnoteReference"]').each do |s|
        s.swap(s.inner_html)
      end
      
      raise 'Unswapped footnote in ' + element.to_xml if element.to_xml =~ /\[\d+\]/
      
      element
    end

    def fix(text)
      text.gsub("\r","\n").gsub(/\n\n+/,"\r").gsub("\n", " ").gsub("\r","\n\n").strip
    end

    def import_front_or_back(type, file, title, position, parent)
      puts "#{file} --"
      
      body = fix_footnotes(parse(file))
      body = body.search('div.MsoBodyText').first

      full_title = body.search('span.chapterhead').first.inner_html
                                                           
      body.search('property').each do |s| s.swap('') end
      body.search('span.chapterhead').each do |s| s.swap('') end
      body.search('span.chaptersub').each do |s| s.swap('<h2>' + s.inner_html + '</h2>') end
                 
      rc = type.create!(
        :created_by_id     => 1,
        :version_notes     => "Imported from CP",
        :parent            => parent,
        :website           => WebsiteId,
        :title             => title,
        :slug              => file,
        :full_title        => full_title,
        :body              => body.to_xml,
        :summary           => "",
        :position          => position,
        :position_label    => "",
        :publicly_viewable => true)
    end

    def import_content_page(file, parent, position)
      puts "#{file} --"
            
      body = fix_footnotes(parse(file))

      if title_table = body.search('table tr td nobr').first
        title = title_table.inner_html
        title_table.parent.parent.parent.remove
      elsif title_table = body.search('table tr td.topic-head').first
        title = title_table.inner_html
        title_table.parent.parent.remove
      end
      
      body.search('span.chaptersub').each do |s| s.swap('<h2>' + s.inner_html + '</h2>') end

      title = file.gsub('-', ' ').titleize if title.blank?
      
      rc = ContentPage.create!(
        :created_by_id     => 1,
        :version_notes     => "Imported from CP",
        :parent            => parent,
        :website           => WebsiteId,
        :title             => title,
        :slug              => file,
        :body              => body.to_xml,
        :summary           => "",
        :position          => position,
        :position_label    => "",
        :publicly_viewable => true)
    end
    
    def import_chapter(file, position, parent)
      puts "#{file} --"        

      body = fix_footnotes(parse(file))
      body = body.xpath('.//div[@class="MsoBodyText"]').first

      label = file
      title = fix(body.search('span.chapterhead').first.inner_html.split(/:/, 2).last.sub(/^(&nbsp;|\s|\xA0)*/,''))

      body.search('property').each do |s| s.swap('') end
      body.search('span.chapterhead').each do |s| s.swap('') end
                 
      rc = ReportChapter.create!(
        :created_by_id => 1,
        :version_notes => "Imported from CP",
        :parent    => parent,
        :website   => WebsiteId,
        :title     => fix(title),
        :slug      => 'ch-' + label.split(' ')[1],
        :summary   => fix(body.search('p').first.inner_html),
        :position  => position,
        :position_label => label,
        :publicly_viewable => true)

      ReportChapterSection.create!(
        :created_by_id => 1,
        :version_notes => "Imported from CP",
        :parent        => rc,
        :website       => WebsiteId,
        :title         => fix(title),
        :slug          => 'chapter-' + label.split(' ')[1],
        :body          => fix(body.to_xml),
        :position      => 0,
        :position_label=> 'Introduction',
        :publicly_viewable => true
      )
      return rc
    end

    def import_conclusion(file, position, chapter)
      conclusion_text = fix_footnotes(parse(file))
      
      conclusion_text = conclusion_text.search('.//div[@class="MsoBodyText"]').first
      conclusion_text.search('span.chapterhead').each do |s| s.swap('') end

      slug = if chapter.position_label == 'Chapter III' then 'chapterIII-conclusion' else 'chapter-II-conclusion' end
      
      ReportChapterSection.create!(
        :created_by_id => 1,
        :version_notes => "Imported from CP",
        :parent        => chapter,
        :website       => WebsiteId,
        :title         => chapter.title,
        :slug          => slug,
        :body          => fix(conclusion_text.to_xml),
        :position      => position,
        :position_label=> 'Conclusion',
        :publicly_viewable => true
      )
    end

    def import_policy_statement(policy_number, position, parent)
      pn = "%02d" % policy_number
      ps_file = AllFiles.select{|f| f =~ /ps#{pn}-/ }.first
      body = fix_footnotes(parse(ps_file))

      recommendations, sidebar = body.xpath('.//table/tr/td[@class="T1"]')
      
      sidebar.xpath('.//p[@class="Sidebartitle"]').each do |p|
        p.swap('<h3>' + p.inner_html + '</h3>')
      end

      exceptions = body.xpath('.//div[@class="MsoBodyText"]/*').
        reject { |e| e['class'].to_s.split(' ').any? { |c| ['MsoBodyText','BodyTextbullet','example'].include?(c) } }.
        reject { |e| e.name == 'table' && !e.xpath('.//td[@class="bignumber"]').empty? }.
        reject { |e| e.name == 'table' && !e.xpath('.//td[@class="T1"]').empty? }.
        reject { |e| e.name == 'text' }.reject { |e| e.name == 'comment' }.
        reject { |e| e.name == 'hr' && e['size'] == '1' }.
        reject { |e| e.name == 'div' && e['id'].to_s.start_with?('ftn') && e.inner_html.strip == '' }
      
      
      raise exceptions.inspect unless exceptions.empty?
      
      ps = ReportPolicyStatement.create!(
        :created_by_id => 1,
        :version_notes => "Imported from CP",
        :parent   => parent,
        :website  => WebsiteId,
        :slug     => ps_file,
        :title    => fix(body.search('td.Policystate-title2').last.inner_html),
        :summary  => fix(body.search('p.Policystate-text2').first.inner_html),
        :body     => fix(body.xpath('.//div[@class="MsoBodyText"]/*[starts-with(@class, "MsoBodyText") or @class="BodyTextbullet" or @class="example"]').map(&:to_xml).join('')),
        :callout  => if !sidebar.text.gsub(/[\s\xA0]/, '').blank? then fix(sidebar.to_xml) else '' end,
        :position => position,
        :position_label => policy_number.to_s,
        :publicly_viewable  => true)

          
      rcs = []

      recommendations.children.each do |c|
        if c.name == 'table'
          rcs << [c]
        else
          rcs[-1] << c if rcs.length > 0
        end
      end
      
      rcs.each_with_index do |pair, ri|
        table, texts = pair.first, pair[1..-1]
        import_recommendation(table, texts, ri, ps)
      end
      
      puts "PS #{policy_number} title: [#{ps.title}]"
    end

    def import_recommendation(table, texts, position, parent)
      texts = texts.inject([]) { |m, i| 
        if i['class'].to_s == 'Recommendexampletitle'
          p = Nokogiri::XML::Node.new('div', i.document)
          p['class'] = 'example'
          
          i.name = 'h4'
          i.delete('class')
          
          p.add_child(i)
          
          m + [p]
        elsif i['class'].to_s == 'Recommendexampletext' && m[-1]['class'] == 'example'
          i.delete('class')
          m[-1].add_child(i)
          m
        elsif((i.name == "text" && !i.text.strip.blank?) || i.name != "text")   
          m + [i]
        else
          m
        end
      }
      
      position_label = table.xpath('./tr[position()=1]/td[position()=1]').first.inner_html.gsub(/\W/,'')
      title = fix(table.xpath('./tr[position()=1]/td[position()=3]').first.inner_html)
      
      r = ReportRecommendation.create!(
        :created_by_id => 1,
        :version_notes => "Imported from CP",
        :parent   => parent,
        :website  => WebsiteId,
        :title    => title,
        :slug     => 'recommendation-' + position_label,
        :body     => fix(texts.map(&:to_xml).join('')),
        :position => position,
        :position_label => position_label,
        :publicly_viewable => true)
  
      puts "        #{position} #{r.id}: #{r.title[0,50]}"
    end
    
    Item.transaction do
      Item.delete_all("website='#{WebsiteId}'")

      Content.each do |area, pages|
        page = ContentPage.create!(
          :created_by_id => 1,
          :version_notes => "Imported from CP",
          :slug    => area,
          :title   => area.sub('-', ' ').titleize,
          :website => WebsiteId,
          :publicly_viewable => true)
        
        pages.each_with_index do |file, i|
          import_content_page(file, page, i)
        end
      end
      
      report = Report.create!(
        :created_by_id => 1,
        :version_notes => "Imported from CP",
        :slug    => 'the_report',
        :title   => 'The Report',
        :website => WebsiteId,
        :publicly_viewable => true)

      c = 0
      Front.each do |file, title, subfront|
        section = import_front_or_back(ReportFrontMatter,file, title, c += 1, report)

        subfront.each_with_index do |pair, si|
          file, title = pair
          import_front_or_back(ReportFrontMatter,file, title, c += 1, section)
        end
      end
      
      Chapters.each do |file, policy_numbers, conclusion| 
        chapter = import_chapter(file, c += 1, report)

        if conclusion
          import_conclusion(conclusion, policy_numbers.to_a.length + 2, chapter)
        end
        
        puts "Chapter #{file} title: [#{chapter.title}]"
        
        policy_numbers.each do |policy_number|
          import_policy_statement(policy_number, policy_number - policy_numbers.first + 1, chapter)
        end
      end
      
      appendix = ReportAppendix.create!(
        :created_by_id => 1,
        :version_notes => "Imported from CP",
        :position => c += 1,
        :parent  => report, 
        :slug    => 'appendix',
        :title   => 'Appendix',
        :website => WebsiteId,
        :publicly_viewable => true)

      Back.each do |file, title|
        section = import_front_or_back(ReportAppendix, file, title, c += 1, appendix)
      end
    end
    
    ps_by_title = ReportPolicyStatement.find(:all, :conditions => { :website => WebsiteId }).map { |ps| 
      t = Regexp.quote(ps.labeled_title.gsub(/(\xA0|&nbsp;|&#xA0;|\s)+/i, ' ').strip).
        gsub('\\ ', ' ').gsub(/\ *([:\/,])\ */, '\1').
        gsub(/(?!^)\ *\b(?!$)/, '([\xA0\s]|&nbsp;|&#xA0;)*')
      
      [t , ps] 
    }
    
    ReportBase.find(:all, :conditions => { :website => WebsiteId }).each do |rb|
      cv = rb.active_version
      
      [:body, :summary, :extra].each do |sym|
        s = cv.send(sym)
        x = s + ''

        ps_by_title.each do |title, ps|
          s = s.gsub(/(#{title})/i, '<a href="'+ps.expected_url+'">\1</a>')
        end
        
        cv.send("#{sym}=", s)
      end
      
      cv.save!
    end
    
    puts "#{Item.find_all_by_website(WebsiteId).size} items imported."
  end 
 
end

