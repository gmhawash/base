class Notifier < ActionMailer::Base
  def account_confirmation(user, host)
    recipients   user.name_and_email
    subject      "Activate your #{ host } account"
    from         "deliveries@" + host.gsub(/^www./,'')
    body         :user => user, :host => host
    content_type "text/plain"
  end
  
  def password_reset(user, host)
    recipients   user.name_and_email
    subject      "Reset your #{ host } password"
    from         "deliveries@" + host.gsub(/^www./,'')
    body         :user => user, :host => host
    content_type "text/plain"
  end
  
  def invite_survey(name, email, host, new_body=nil)
    recipients   email
    subject      "Update your survey"
    from         "deliveries@" + host.gsub(/^www./,'')
    body         :new_body => new_body, :name => name, :host => host
    content_type "text/plain"
  end
end
