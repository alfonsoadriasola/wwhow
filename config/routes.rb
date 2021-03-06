ActionController::Routing::Routes.draw do |map|
  
  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.login '/login', :controller => 'sessions', :action => 'new'
  map.register '/register', :controller => 'web_users', :action => 'create'
  map.signup '/signup', :controller => 'web_users', :action => 'new'
  map.activate '/activate/:activation_code', :controller => 'web_users', :action => 'activate', :activation_code => nil  
  map.forgot_password '/forgot_password', :controller => 'web_users', :action => 'forgot_password'
  map.after_forgot_password '/after_forgot_password', :controller => 'web_users', :action => 'after_forgot_password'
  map.reset_password '/reset_password/:code', :controller => 'web_users', :action => 'reset_password'
  map.about '/about', :controller => 'common', :action => 'about'
  map.help  '/help' , :controller => 'common', :action => 'help'
  map.tos   '/tos', :controller =>  'common', :action => 'tos'
  map.privacy '/privacy', :controller => 'common', :action => 'privacy'
  map.locations '/locations', :controller => 'common', :action => 'locations'
  map.site_map  '/sitemap.xml', :controller => 'common', :action => 'sitemap'

  map.resources :web_users
  map.resource  :session
  map.resources :users
 
  # The priority is based upon order of creation: first created -> highest priority.
  # Named routes
  map.connect 'who/:author', :controller => 'listings', :action => 'search'

  map.connect 'where/:entry_location', :controller => 'listings', :action => 'search'
  map.connect 'what/:category_list', :controller => 'listings', :action => 'search'
  map.connect 'what/:category_list/where/:entry_location', :controller => 'listings', :action => 'search'
  
  map.connect 'find/:post_id', :controller => 'listings', :action => 'show'

  map.connect 'merchants/', :controller => 'listings', :action =>'index', :merchants => 'true'
  map.connect 'merchants/where/:entry_location', :controller => 'listings', :action => 'search' , :merchants => 'true'
  map.connect 'merchants/what/:category_list', :controller => 'listings', :action => 'search'  , :merchants => 'true'
  map.connect 'merchants/what/:category_list/where/:entry_location', :controller => 'listings', :action => 'search'   , :merchants => 'true'

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
  map.root :controller => "listings"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.

  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'

  map.connect '*anything', :controller => 'common', :action => 'malformed'  
  map.error ':common',  :controller => 'common',  :action => 'malformed'  

end
