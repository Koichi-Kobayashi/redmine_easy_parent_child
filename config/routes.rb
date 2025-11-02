# Plugin's routes
RedmineApp::Application.routes.draw do
  get 'projects/:project_id/issues/easy_parent_child', :to => 'easy_parent_childs#show', :as => 'project_easy_parent_child'
  get 'issues/easy_parent_child', :to => 'easy_parent_childs#show'
  post 'projects/:project_id/easy_parent_childs/update_relations', :to => 'easy_parent_childs#update_relations', :as => 'update_easy_parent_child_relations'
  post 'projects/:project_id/easy_parent_childs/disconnect_relation', :to => 'easy_parent_childs#disconnect_relation', :as => 'disconnect_easy_parent_child_relation'
end
