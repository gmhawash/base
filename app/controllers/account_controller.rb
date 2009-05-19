class AccountController < ApplicationController
  def logout
    reset_session
    if !request.referer || request.referer =~ /\/admin/
      redirect_to '/'
    else
      redirect_to request.referer
    end

  end
  
  def login
    if((request.referer !~ /\/log(in|out)\b/) && session[:return_to].nil?)
      session[:return_to] = request.referer 
    end
    
    if request.post?
      session[:user_id] = nil
      if u = User.authenticate(params[:login][:email].downcase, params[:login][:password])
        u.update_attributes(
          :activation_code => '',
          :last_login => Time.now())
        
        flash[:notice] = 'Welcome back, ' + u.name
        session[:user_id] = u.id
        redirect_to(session[:return_to] || '/')
        session[:return_to] = nil
      else
        u = User.find_by_email(params[:login][:email])
        if  u && !u.active?
          flash[:notice] = "Your account has not yet been activated.  Please check your email for instructions."
          redirect_to '/'
        else 
          flash[:error] = "You did not provide a valid email and password!"
          redirect_to '/login'
        end
      end
    end
  end

  def new
    if request.post?
      @user = User.new(params[:user].merge(:active => false))
      @user.generate_activation_code
      if @user.valid?
        @user.save
        Notifier.deliver_account_confirmation(@user, request.host)
        redirect_to :action => 'waiting_for_confirmation'
      else
        if @user.errors.on(:email).maybe.include?('already been taken')
          flash[:error] = "An account with this email address already exists!  If you do not remember your password, you may reset it."
        else
          flash[:error] =@user.errors.full_messages
        end
      end
    end
  end
  
  def activate
    if(params[:code] && params[:code].length >= 1 &&
      @user = User.find_by_active_and_activation_code(false, params[:code], 
        :conditions => ['activation_code_generated >= ?', Date.today - 1.week]))
      @user.update_attributes!(:active => true)
      render :template => '/account/activated'
    else
      redirect_to '/'
    end
  end
  
  def reset_password
    if(request.get? && params[:code] && params[:code].length >= 1 &&
      @user = User.find_by_active_and_activation_code(true, params[:code], 
        :conditions => ['activation_code_generated >= ?', Date.today - 1.week]))

      render :template => '/account/new_password'
    
    elsif(request.post? && params[:user])
      
      if @user = User.find_by_active_and_email(true, params[:user][:email].downcase)
        @user.generate_activation_code
        @user.save

        Notifier.deliver_password_reset(@user, request.host)
        redirect_to :action => 'waiting_for_password_reset'        
      else
        flash[:error] = 'We could not find a user with that email address!'
      end
    
    elsif(request.post? && params[:password] && params[:code].length >= 1 &&
      @user = User.find_by_active_and_activation_code(true, params[:code], 
        :conditions => ['activation_code_generated >= ?', Date.today - 1.week]))
    
      @user.update_attributes(
        :password              => params[:password][:password],
        :password_confirmation => params[:password][:password_confirmation],
        :activation_code =>'')

      if @user.valid?
        render :template => '/account/your_password_has_been_reset'
      else
        flash[:error] = @user.errors.full_messages
        render :template => '/account/new_password'
      end
      
    elsif params[:code]
      redirect_to '/'
    end
  end
end
