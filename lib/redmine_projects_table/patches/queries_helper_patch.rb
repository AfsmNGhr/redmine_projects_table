module QueriesHelper
  def retrieve_self_query
    session[:query].reject! { |f| f == :filters } if session[:query]
    if !params[:query_id].blank?
      cond = 'project_id IS NULL'
      cond << " OR project_id = #{@project.id}" if @project
      @query =
        ProjectQuery.where(cond).find(params[:query_id])
      fail ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = { id: @query.id, project_id: @query.project_id }
      sort_clear
    elsif api_request? || params[:set_filter] || session[:query].nil? ||
          session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = ProjectQuery.new(name: '_')
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = { project_id: @query.project_id,
                          filters: @query.filters,
                          group_by: @query.group_by,
                          column_names: @query.column_names }
    else
      # retrieve from session
      @query = nil
      @query =
        ProjectQuery.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= ProjectQuery.new(
        name: '_', filters: session[:query][:filters],
        group_by: session[:query][:group_by],
        column_names: session[:query][:column_names])
      @query.project = @project
    end
  end
end
