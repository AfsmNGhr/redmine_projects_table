require 'redmine'
require 'redmine_org_projects_table/patches/projects_controller_patch'

Redmine::Plugin.register :redmine_org_projects_table do
  name 'Redmine Org projects table'
  author 'Ermolaev Alexsey'
  description 'Table projects with customizable and searchable fields ...'
  author_url 'mailto:afay.zangetsu@gmail.com'
  version '0.1'
  requires_redmine version_or_higher: '3.0.0'
  requires_redmine_plugin :redmine_base_deface, version_or_higher: '0.0.1'
end
