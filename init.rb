require 'redmine'

ActionDispatch::Callbacks.to_prepare do
  require 'redmine_projects_table/patches/projects_controller_patch'
  require 'redmine_projects_table/patches/projects_helper_patch'
  ActionView::Base.send(:include, ProjectsTableHelper)
end

Redmine::Plugin.register :redmine_projects_table do
  name 'Redmine projects table'
  author 'Ermolaev Alexsey'
  description 'Table projects with customizable and searchable fields ...'
  author_url 'mailto:afay.zangetsu@gmail.com'
  version '0.2'
  requires_redmine version_or_higher: '3.0.0'
end
