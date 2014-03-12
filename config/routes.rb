ScalarmStorageManager::Application.routes.draw do
  get '/status' => 'log_bank#status'

  put 'experiment/:experiment_id/simulation/:simulation_id' => 'log_bank#put_simulation_output'
  get 'experiment/:experiment_id/simulation/:simulation_id' => 'log_bank#get_simulation_output'
  delete 'experiment/:experiment_id/simulation/:simulation_id' => 'log_bank#delete_simulation_output'

  get 'experiment/:experiment_id/from/:start_id/to/:to_id' => 'log_bank#get_experiment_output'
  delete 'experiment/:experiment_id/from/:start_id/to/:to_id' => 'log_bank#delete_experiment_output'

  put 'experiment/:experiment_id/simulation/:simulation_id/stdout' => 'log_bank#put_simulation_stdout'
  get 'experiment/:experiment_id/simulation/:simulation_id/stdout' => 'log_bank#get_simulation_stdout'
  delete 'experiment/:experiment_id/simulation/:simulation_id/stdout' => 'log_bank#delete_simulation_stdout'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
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

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end
  
  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
