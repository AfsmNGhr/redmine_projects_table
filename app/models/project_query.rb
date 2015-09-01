class ProjectQuery < Query
  self.queried_class = Project

  self.available_columns = [
    QueryColumn.new(:id, sortable: "#{Project.table_name}.id",
                    default_order: 'desc', caption: '#', frozen: true),
    QueryColumn.new(:project, sortable: "#{Project.table_name}.name",
                    groupable: true),
    QueryColumn.new(:parent, sortable: [ "#{Project.table_name}.parent_id",
                                         "#{Project.table_name}.lft ASC" ],
                    default_order: 'desc', caption: :field_parent_project),
    QueryColumn.new(:status, sortable: "#{Project.table_name}.status",
                    groupable: true),
    QueryColumn.new(:description, inline: false),
    QueryColumn.new(:created_on, sortable: "#{Project.table_name}.created_on",
                    default_order: 'desc'),
    QueryColumn.new(:updated_on, sortable: "#{Project.table_name}.updated_on",
                    default_order: 'desc'),
    QueryColumn.new(:domains, sortable: "#{Domain.table_name}.name",
                    groupable: true, caption: :label_domain_plural),
    QueryColumn.new(:organizations, sortable: "#{Organization.table_name}.name",
                    groupable: true, caption: :label_organization_plural)
  ]

  scope :visible, lambda {|*args|
    user = args.shift || User.current
    base = Project.allowed_to_condition(user, :view_projects, *args)
    scope = joins("LEFT OUTER JOIN #{Project.table_name} " +
                  " ON #{table_name}.project_id = #{Project.table_name}.id").
            where("#{table_name}.project_id IS NULL OR (#{base})")

    if user.admin?
      scope.where("#{table_name}.visibility <> ? OR #{table_name}.user_id = ?", VISIBILITY_PRIVATE, user.id)
    elsif user.memberships.any?
      scope.where("#{table_name}.visibility = ?" +
        " OR (#{table_name}.visibility = ? AND #{table_name}.id IN (" +
          "SELECT DISTINCT q.id FROM #{table_name} q" +
          " INNER JOIN #{table_name_prefix}queries_roles#{table_name_suffix} qr on qr.query_id = q.id" +
          " INNER JOIN #{MemberRole.table_name} mr ON mr.role_id = qr.role_id" +
          " INNER JOIN #{Member.table_name} m ON m.id = mr.member_id AND m.user_id = ?" +
          " WHERE q.project_id IS NULL OR q.project_id = m.project_id))" +
        " OR #{table_name}.user_id = ?",
        VISIBILITY_PUBLIC, VISIBILITY_ROLES, user.id, user.id)
    elsif user.logged?
      scope.where("#{table_name}.visibility = ? OR #{table_name}.user_id = ?", VISIBILITY_PUBLIC, user.id)
    else
      scope.where("#{table_name}.visibility = ?", VISIBILITY_PUBLIC)
    end
  }

  def initialize(attributes=nil, *args)
    super attributes
    self.filters ||= { 'status_id' => { operator: 'o', values: [''] } }
  end

  # Returns true if the query is visible to +user+ or the current user.
  def visible?(user=User.current)
    return true if user.admin?
    return false unless project.nil? ||
                        user.allowed_to?(:view_projects, project)
    case visibility
    when VISIBILITY_PUBLIC
      true
    when VISIBILITY_ROLES
      if project
        (user.roles_for_project(project) & roles).any?
      else
        Member.where(user_id: user.id).joins(:roles).
          where(member_roles: { role_id: roles.map(&:id) }).any?
      end
    else
      user == self.user
    end
  end

  def is_private?
    visibility == VISIBILITY_PRIVATE
  end

  def is_public?
    !is_private?
  end

  def project_count
    Project.visible.joins(:domains, :organizations).where(statement).count
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  # Returns the project count by group or nil if query is not grouped
  def project_count_by_group
    r = nil
    if grouped?
      begin
        # Rails3 will raise an (unexpected) RecordNotFound
        # if there's only a nil group value
        r = Project.visible.
          joins(:domains).
          where(statement).
          joins(joins_for_order_statement(group_by_statement)).
          group(group_by_statement).
          count
      rescue ActiveRecord::RecordNotFound
        r = { nil: project_count }
      end
      c = group_by_column
      if c.is_a?(QueryCustomFieldColumn)
        r = r.keys.
            inject({}) { |h, k| h[c.custom_field.cast_value(k)] = r[k]; h }
      end
    end
    r
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def available_columns
    return @available_columns if @available_columns
    @available_columns = self.class.available_columns.dup
    @available_columns += ProjectCustomField.visible.
                         collect { |cf| QueryCustomFieldColumn.new(cf) }

    # with time_entries ...
    # if User.current.allowed_to?(:view_time_entries, project, global: true)
    #   index = nil
    #   @available_columns.each_with_index {
    #     |column, i| index = i if column.name == :estimated_hours }
    #   index = (index ? index + 1 : -1)
    #   # insert the column after estimated_hours or at the end
    #   @available_columns.
    #     insert index, QueryColumn.new(
    #              :spent_hours,
    #              sortable: "COALESCE((SELECT SUM(hours) " +
    #              " FROM #{TimeEntry.table_name} " +
    #              " WHERE #{TimeEntry.table_name}.issue_id = " +
    #              " #{Issue.table_name}.id), 0) ",
    #              default_order: 'desc',
    #              caption: :label_spent_time )
    #   @available_columns.
    #     insert index+1, QueryColumn.new(
    #              :total_spent_hours,
    #              sortable: "COALESCE((SELECT SUM(hours) " +
    #              " FROM #{TimeEntry.table_name} " +
    #              " JOIN #{Issue.table_name} subtasks " +
    #              " ON subtasks.id = #{TimeEntry.table_name}.issue_id" +
    #              " WHERE subtasks.root_id = #{Issue.table_name}.root_id " +
    #              " AND subtasks.lft >= #{Issue.table_name}.lft " +
    #              " AND subtasks.rgt <= #{Issue.table_name}.rgt), 0)",
    #              default_order: 'desc',
    #              caption: :label_total_spent_time )
    # end

    disabled_fields = Tracker.disabled_core_fields(trackers).
                      map { |field| field.sub(/_id$/, '') }
    @available_columns.reject! { |column|
      disabled_fields.include?(column.name.to_s)
    }

    @available_columns
  end

  def projects(options={})
    order_option = [ group_by_sort_order, options[:order] ].
                   flatten.reject(&:blank?)

    scope = Project.visible.
            joins(:domains).
            where(statement).
            includes(([:domains, :organizations] +
                      (options[:include] || [])).uniq).
            where(options[:conditions]).
            order(order_option).
            joins(joins_for_order_statement(order_option.join(','))).
            limit(options[:limit]).
            offset(options[:offset])

    scope = scope.preload(:custom_values)
    projects = scope.to_a
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end
end
