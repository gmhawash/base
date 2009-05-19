ActionController::Routing::Routes.draw do |map|
  map.resources :presentations

  [:users, :messages, :ratings, :services].each do |c|
    map.resources c
 
    {:create    => [:post, ''], 
     :destroy   => [:delete, '/:id'], 
     :update    => [:put, '/:id'],
     :show      => [:get, '/:id'],
     :new       => [:get, '/new'],
     :index     => [:get, ''],
     :edit      => [:get, '/:id/edit']
    }.each do |k,v|
      map.connect "/admin/#{c.to_s}#{v[1]}", :controller => c.to_s, :action => "admin_#{k}",  :conditions => { :method => v[0] }
    end
  end
    
  
  map.connect 'login', :controller => 'account', :action => 'login'
  map.connect 'logout', :controller => 'account', :action => 'logout'

  map.connect 'account/:action',       :controller => 'account'
  map.connect 'account/:action/:code', :controller => 'account'

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing the them or commenting them out if you're using named routes and resources.
  map.connect '*url', :controller => 'presentations', :action => 'show'

end
