class AdminController < ApplicationController
  before_filter :check_logged_in_as_admin

#  def auto_complete_for_search_tags
#    x = params[:search][:tags].split(',').map(&:strip)
#    first = x[0..-2].join(', ')
#    first += ', ' unless first.blank?
#    
#    @tags = Tag.all.select { |i| i.name =~ /#{x.last}/i }
#    render :inline => "<%= content_tag(:ul, @tags.map { |org| content_tag(:li, h('#{first}' + org.name)) }) %>"
#  end
#  
#  def admin_index
#    @results = search_for('Item, IssueArea', params[:search])
#  end
#  
  protected
  
#  def search_for(finder, params)
#     remove old searches...
#    params ||= {}
#    @results = Search.search(finder, params[:website], params[:keyword], params[:tags], false, false, 5.minutes.ago)
#  end   
#  
  private
  def check_logged_in_as_admin
    if (params[:action] =~ /admin/) 
      if !@user || !@user.admin?
        flash[:notice] = "Please log in"
        session[:return_to] = request.request_uri
        redirect_to '/login'
        return false
      end
    end
    return true
  end
  
end