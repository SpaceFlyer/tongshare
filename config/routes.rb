Tongshare::Application.routes.draw do

  get "app/renren/signin"
  get "app/renren/callback"

  get "private/get_diff"

  match "thankful" => "thankful#index"

  match "about" => "about#index"
  get "greeting/create"
  get "greeting/index"

  get "friendship/add_or_remove"
  get "friendship/show"

  get "profile/index"
  get "profile/show"
  get "profile/select"

  get "search/index"
  get "search/add_members"
  post "search/add_members"
  get "search/box"
  post "search/box"
  match "search/user/:keyword" => "search#user"
  match "search/location/:keyword" => "search#location"
  match "search/public_user/:keyword" => "search#public_user"
  match "search/public_group/:keyword" => "search#public_group"
#  get "search/user"
#  post "search/user"
#  get "search/location"
#  post "search/location"
#  get "search/public_user"
#  post "search/public_user"
#  get "search/public_group"
#  post "search/public_group"

  get "public/get_diff"
  match "public/user/:user_id" => "public#show_public_user"
  match "public/group/:group_id" => "public#show_public_group"
  match "public/location/:location" => "public#show_location"

  get "curriculum/upload"
  get "curriculum/save"
  post "curriculum/save"

  get "acceptance/create"
  get "acceptance/destroy"
  get "acceptance/deny"
  get "acceptance/accept"
  get "acceptance/exit"

  post "auth/confirm"

  get "thuauth/auth_with_xls_and_get_name"
  post "thuauth/auth_with_xls_and_get_name"

  devise_for :users, :controllers => {
    :registrations => "registrations_extended", 
    :sessions => "sessions_extended",
    :confirmations => "confirmations_extended"
    }

#  resources :oauth_consumers do
#    get :callback, :on => :member
#  end

  get "home/index"

  #get "temp/view"
  #get "temp/cal"

  get "sharings/add_members"
  post "sharings/add_members"

  get "groups/add_members"
  post "groups/add_members"
  get "groups/add_members"
  post "groups/set_members"

  resources :groups
  resources :events
  resources :sharings
  resources :acceptances


  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "home#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
