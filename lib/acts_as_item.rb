module ActiveRecord
  module Acts
    module Item
      def self.included(base)
        base.extend(ClassMethods)
      end
      
      module ClassMethods
        def acts_as_item
          extend  ActiveRecord::Acts::Item::SingletonMethods
          include ActiveRecord::Acts::Item::InstanceMethods
          include ActionView::Helpers::TagHelper
          
          before_validation_on_create :initialize_slug
          has_and_belongs_to_many :tags
  
          report_column :publicly_viewable, :type => :boolean
          report_column :slug_link, :type => :link, :data_proc => lambda { |i|
            u = i.expected_url 
            text = u.length > 27 ? '...' + u.reverse[0..26].reverse : u 
            [text, u, { :title => u }] 
          }
          
          named_scope :tagged_with, lambda { |tag_list|
            { :conditions => { :id =>  ids_for_tags(tag_list) } }
          }
          
          named_scope :public, { :conditions => 'publicly_viewable' }
    
          named_scope :searchable, { :conditions => { :exclude_from_search => false } }
        end
      end
      
      module SingletonMethods
        def topical_search(public, params)
          search = searchable
          search = search.public if public
          search = search.tagged_with([params[:select_state].strip]) if !params[:select_state].maybe.strip.blank?
          search = search.keyword(params[:keyword].strip) if !params[:keyword].maybe.strip.blank?
          search.all.sort_by { |i| i.search_score(params[:keyword].to_s) }.reverse
        end

        # Provides an interface for subclasses to provide a public-facing class name.
        def presentation_name(value=nil)
          @presentation_name ||= value || self.name
        end
        
        # Provides an interface for subclasses to provide a headline for collections of items.
        # Defaults to the plural version of the presentation name.
        def headline(value=nil)
          @headline ||= value || self.presentation_name.pluralize
        end
      end
          
      module InstanceMethods
        
        def tags_by_category(category)
          tags.select { |t| t.category == category }.map(&:name).sort.join(", ")
        end

        def expected_url
          '/' + self.class.to_s.tableize.singularize + '/' + slug
        end
        
        def ancestors
          [self]
        end
        
        def states
          tags_by_category 'states'
        end
        
        def as_search_result
          content_tag(:strong, self.class.headline.singularize + ': ') + content_tag(:a, title, :href => expected_url, :class => "title") 
        end
        
        def has_tags?(tag_list = nil)
          if (tag_list.nil?)
            !tags.empty?
          else
            tag_list.sort == tag_list.select {|tag| tags.find_by_name(tag)}.sort
          end
        end
        
        def title_snippet
          self.title.gsub(/<[^>]+>/, '')[0..20]
        end
  
        def initialize_slug
          self.slug = generate_slug if slug.blank?
        end
        
        def title_chain
          title
        end
  
        def generate_slug(prefix='')
          slug = prefix + title.gsub(/<[^>]+>/, '').to_url.gsub('-','_')
          slug = slug[0,255]
        end
        
        def related_items_for_additional_resources
          related_items.
            reject { |i| [Announcement,ContentPage,ReportBase].any? { |k| i.is_a?(k) } }.
            sort_by { |i| i.primary_date_as_date || i.created_at.to_date }.
            reverse.group_by(&:class)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::Item)
