Rubyplus::Application.routes.draw do

  resources :episodes do
    member do
      get 'download'
    end
  end

  namespace :admin do 
    resources :episodes, :testimonials
  end

  resources :testimonials
  
  match 'privacy' => 'episodes#privacy'
  
  root :to => 'episodes#index'
  
end
