# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  before_filter :lookup_user
#  protect_from_forgery # See ActionController::RequestForgeryProtection for details

   # Scrub sensitive parameters from your log
   filter_parameter_logging :password

  protected

  def helpers
    self.class.helpers
  end

  private

  def lookup_user
    if session[:user_id]
      @user = User.find_by_id(session[:user_id])
    end
  end

end
