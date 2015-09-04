require_dependency 'application_controller'
require_dependency 'projects_controller'

module RedmineProjectsTable::Patches::ProjectsControllerPatch
  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable
      alias_method_chain :index, :table
    end
  end

  module ClassMethods
  end

  module InstanceMethods
    def index_with_table
      retrieve_self_query
      sort_init(
        @query.sort_criteria.empty? ? [%w(id desc)] : @query.sort_criteria)
      sort_update(@query.sortable_columns)
      @query.sort_criteria = sort_criteria.to_a

      if @query.valid?
        case params[:format]
        when 'xml', 'json'
          @offset, @limit = api_offset_and_limit
          @query.column_names = %w(project)
        when 'atom'
          @limit = Setting.feeds_limit.to_i
        else
          @limit = per_page_option
        end

        @project_count = @query.project_count
        @project_pages = Redmine::Pagination::Paginator.new(
          @project_count,
          @limit, params['page'])
        @offset ||= @project_pages.offset
        @projects = @query.projects(order: sort_clause,
                                    offset: @offset,
                                    limit: @limit)
        @project_count_by_group = @query.project_count_by_group

        respond_to do |format|
          format.html
          format.api
          format.atom {
            render_feed(@projects, title: "#{Setting.app_title}:" \
                                          "#{l(:label_project_latest)}")
          }
        end
      else
        respond_to do |format|
          format.html
          format.api { render_validation_errors(@query) }
          format.atom { render nothing: true }
        end
      end
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end
end

ProjectsController.send :include,
       RedmineProjectsTable::Patches::ProjectsControllerPatch

class ProjectsController
  default_search_scope :projects
  rescue_from Query::StatementInvalid, with: :query_statement_invalid
  include QueriesHelper
  helper :sort
  include SortHelper
end
