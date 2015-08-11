require_dependency 'application_controller'
require_dependency 'projects_controller'
require_dependency 'sort_helper'

module RedmineOrgProjectsTable::Patches::ProjectsControllerPatch
  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable
      helper :sort
      include SortHelper
      alias_method_chain :index, :table
    end
  end

  module ClassMethods
  end

  module InstanceMethods
    def index_with_table
      @custom_fields = ProjectCustomField.all
      @status = params[:status] || 1
      scope = Project.visible.status(@status).sorted
      scope = scope.like(params[:name]) if params[:name].present?

      respond_to do |format|
        format.html {
          @projects = scope.to_a
        }
        format.api {
          @project_count = scope.count
          @offset, @limit = api_offset_and_limit
          @projects = scope.offset(@offset).limit(@limit).to_a
        }
        format.atom {
          projects = scope.reorder(:created_on => :desc).limit(Setting.feeds_limit.to_i).to_a
          render_feed(projects, :title => "#{Setting.app_title}: #{l(:label_project_latest)}")
        }
      end
    end
  end
end

ProjectsController.send :include,
       RedmineOrgProjectsTable::Patches::ProjectsControllerPatch
