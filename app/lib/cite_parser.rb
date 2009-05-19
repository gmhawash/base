# encoding: UTF-8
class CiteParser
  Templates = [
    '_author_, "_title_," _periodical_ (_publication-state_: _publisher_, _primary-date_)',
    '_author_, "_title_," _periodical_ (_publication-state_: _primary-date_)',
    '_author_, "_title_," _periodical_ (_primary-date_)',
    '_author_, _title_, _usjournal_ (_publication-state_: _publisher_, _primary-date_)',
    '_author_, _title_, _usjournal_ (_publication-state_: _primary-date_)',
    '_author_, _title_, _usjournal_ (_primary-date_)',
    '_author_, "_title_" (_publication-state_: _publisher_, _primary-date_)',
    '_author_, "_title_" (_publication-state_: _primary-date_)',
    '_author_, "_title_" (_primary-date_)',
    '_author_, _title_ (_publication-state_: _publisher_, _primary-date_)',
    '_author_, _title_ (_publication-state_: _primary-date_)',
    '_author_, _title_ (_primary-date_)',    
    ].map { |t|
      [t + ', _reference-number_', t]
    }.flatten.map { |t|
      [t + ', _pageref_', t + ': _pageref_', t + ' _pageref_', t]
    }.flatten.map { |t|
      [t + ', available online at _url_', t]
    }.flatten
    
    initial = /[A-Z]\./
    name_token = /(?:De|Mc|Mac|La)?[A-Z][a-zé]+/
    first_name_segment = /\b(?:#{name_token}(?:-#{name_token})?|[A-Z]\.|US)/
    name_segment = /\b(?:#{name_token}(?:-#{name_token})?|[A-Z]\.|US|on|of|for|et al\.)/
    author       = /(?:#{first_name_segment} )(?:\s*#{name_segment})*/
  
  Regexps = {
    'author'   => /#{author}(?:, #{author})*(?:,? and #{author})?(?:, eds?.)?/,
    'title'     => /[A-Z][^\s"(\n]*\s[^"(\n]+/,
    'periodical'   => /[^(\n]+/,
    'usjournal'   => /(?:(?:US |U\.S\. )?Department of Justice, (?:National|Bureau))[^(\n]+/,
    'publication_state'  => /[^:)\n]+/,
    'publisher' => /.+?/,
    'primary_date'      => /(?:(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Dec)[a-z]*\s*(?:\d+(?:\s*\-\s*\d+)?\s*,)?)?\s*\d{4}/,
    'pageref'   => /(?:\d+\s*[,-]\s*)*\d+/,
    'reference_number'    => /(?:NIH [\d\-]+|NCJ \d+)/,
    'url'       => /\S+[^\.\s]/,
  }
  
  Matchers = Templates.map {|t|
    labels = []
    
    r = Regexp.quote(t).gsub(/_[^_]+_/) do |str|
      s = str[1..-2].gsub('\-', '_') 
      labels << s
      raise "No regexp: #{s}" unless Regexps[s]
      "(#{Regexps[s]})"
    end
    
    lambda { |s| 
      if m = /#{r}/.match(s)
        h = Hash[*labels.zip(m[1..labels.length]).flatten]
        h['periodical'] = h.delete('usjournal') if h.has_key?('usjournal')
        
        if h.keys.length > 3 || m[0] =~ /"/ || (h['author'] && h['author'] =~ /US Department/)
          [m[0], h]
        else
          []
        end
      else
        []
      end
    }
  }

  def self.parse(s)
    Matchers.map { |m| m[s] }.compact.sort_by(&:length).reverse.first
  end
  
  def self.split_sentences(body)
    body.gsub!('et al.','et al~')
    body.gsub!(/\b(ibid|yrs|seq|vols?|eds?|no|v|pp?|tit|doc)\./,'\1~')
    body.gsub!(/\b([A-Z][^\s\.]*)\./, '\1~')
    body.gsub!(/(\d)\.(\d)/, '\1~\2')
    body.gsub!('."','".')
    body.gsub!('.)', ').')
    body.gsub!(' . ', ' ~ ')
    body.gsub!('.§', '~§')
    while body.gsub!(/(Available (?:online )?at )([^ \.]+)\./i, '\1\2~'); end
    body.gsub!(/\. Available online at/, '~ Available online at')
    while body.gsub!(/\b(http|www)([:\/~a-z0-9_\-]*)\./i,'\1\2~'); end
    
    body.split(/\s*([;\.]+)\s*/).map { |s| s.gsub('~', '.')}
  end
end

