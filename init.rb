require 'redmine'

ActionDispatch::Callbacks.to_prepare do
  require 'redmine_org_projects_table/patches/projects_controller_patch'
  ActionView::Base.send(:include, OrgProjectsTableHelper)
end

Redmine::Plugin.register :redmine_org_projects_table do
  name 'Redmine Org projects table'
  author 'Ermolaev Alexsey'
  description 'Table projects with customizable and searchable fields ...'
  author_url 'mailto:afay.zangetsu@gmail.com'
  version '0.1'
  requires_redmine version_or_higher: '3.0.0'
end
