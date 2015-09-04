# coding: utf-8
module ProjectsTableHelper
  def issue_links(project)
    {
      all: {
        caption: Project.where(id: project.id).joins(:issues).count,
        class: 'issues-all',
        label: l(:label_issues_all),
        path: "/issues?utf8=✓&set_filter=1&f[]=status_id&op[status_id]=*&f[]=project_id&op[project_id]==&v[project_id][]=#{project.id}",
        id: "projects-table-issues-all-#{project.id}"
      },

      close: {
        caption: Project.where(id: project.id).joins(:issues).
          where("issues.status_id IN" +
                "(SELECT id FROM issue_statuses WHERE is_closed=?)", true).count,
        class: 'issues-close',
        label: l(:label_issues_close),
        path: "/issues?utf8=✓&set_filter=1&f[]=status_id&op[status_id]=c&f[]=project_id&op[project_id]==&v[project_id][]=#{project.id}",
        id: "projects-table-issues-close-#{project.id}"
      },

      open: {
        caption: Project.where(id: project.id).joins(:issues).
          where("issues.status_id IN" +
                "(SELECT id FROM issue_statuses WHERE is_closed=?)", false).count,
        class: 'issues-open',
        label: l(:label_issues_open),
        path: "/issues?utf8=✓&set_filter=1&f[]=status_id&op[status_id]=o&f[]=project_id&op[project_id]==&v[project_id][]=#{project.id}",
        id: "projects-table-issues-open-#{project.id}"
      },

      add: {
        caption: 'add',
        class: 'material-icons',
        label: l(:label_issue_new),
        path: new_project_issue_path(project),
        id: "projects-table-issue-add-#{project.id}"
      }
    }
  end

  def issues_column(project, column=[], links=issue_links(project))
    links.keys.each do |key|
      column << issue_node(links[key])
    end
    column.empty? ? nil : column.join("\n").html_safe
  end

  def issue_node(link)
    link_to (content_tag(:span, link[:caption], class: link[:class]) +
             (content_tag(:span, link[:label], class: 'mdl-tooltip',
                          for: link[:id]))), link[:path], id: link[:id]
  end

  def organizations_column(project, column=[])
    project.organizations.each do |org|
      column << organization_node(org, project)
    end
    column.empty? ? nil : column.join(', ').html_safe
  end

  def organization_node(org, project)
    roles = org.organization_roles.map { |r| r.role.name }.compact.uniq
    if roles.empty?
      content_tag(:span, content_tag(:span, (link_to_organization org)))
    else
      content_tag(:span) do
        link_to (content_tag(:span, org.fullname) +
                 (content_tag(:span, roles.join('<br>').html_safe, class: 'mdl-tooltip',
                              for: "org-table-project-#{project.id}-organization-#{org.id}"))),
                organization_path(org),
                id: "org-table-project-#{project.id}-organization-#{org.id}"
      end
    end
  end

  def domains_column(project, column=[])
    project.domains.each do |domain|
      column << domain_node(domain)
    end
    column.empty? ? nil : column.join(', ').html_safe
  end

  def domain_node(domain)
    link_to domain.name, domain_path(domain)
  end

  def project_list(projects, &block)
    ancestors = []
    projects.each do |project|
      while (ancestors.any? && !project.is_descendant_of?(ancestors.last))
        ancestors.pop
      end
      yield project, ancestors.size
      ancestors << project unless project.leaf?
    end
  end

  def grouped_project_list(projects, query, project_count_by_group, &block)
    previous_group, first = false, true
    project_tree(projects) do |project, level|
      group_name = group_count = nil
      if query.grouped? && (
           (group = query.group_by_column.value(project)) !=
           previous_group || first)
        if group.blank? && group != false
          group_name = "(#{l(:label_blank_value)})"
        else
          group_name = column_content(query.group_by_column, project)
        end
        group_name ||= ''
        group_count = project_count_by_group[group]
      end
      yield project, level, group_name, group_count
      previous_group, first = group, false
    end
  end

  def project_column_content(column, project)
    value = column.value_object(project)
    if value.is_a?(Array) ||
       (value.is_a?(ActiveRecord::Relation) && column.name != :issues)
      value.collect do |v|
        project_column_value(column, project, v)
      end.compact.join(', ').html_safe
    else
      project_column_value(column, project, value)
    end
  end

  def project_column_value(column, project, value)
    case column.name
    when :id, :name
      link_to value, project_path(project)
    when :parent
      if value
        value.visible? ? link_to_project(value) : "##{value.id}"
      else
        ''
      end
    when :description
      if project.description?
        content_tag(:span,
                    textilizable(project, :description), class: 'wiki')
      else
        ''
      end
    when :issues
      issues_column(project)
    when :domains
      domain_node(value)
    when :organizations
      organization_node(value, project)
    else
      format_object(value)
    end
  end
end
