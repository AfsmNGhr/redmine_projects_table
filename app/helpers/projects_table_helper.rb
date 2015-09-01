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
      column << issues_node(links[key])
    end
    column.empty? ? nil : column.join("\n").html_safe
  end

  def issues_node(link)
    link_to (content_tag(:span, link[:caption], class: link[:class]) +
             (content_tag(:span, link[:label], class: 'mdl-tooltip',
                          for: link[:id]))), link[:path], id: link[:id]
  end

  def organizations_column(project, column=[])
    project.organizations.each do |org|
      column << organizations_node(org, project)
    end
    column.empty? ? nil : column.join("\n").html_safe
  end

  def organizations_node(org, project)
    roles = org.organization_roles.map { |r| r.role.name }.compact.uniq
    if roles.empty?
      content_tag(:span, content_tag(:span, (link_to_organization org)))
    else
      content_tag(:span) do
        link_to (content_tag(:span, org.fullname) +
                 (content_tag(:span, roles.join("<br>").html_safe, class: 'mdl-tooltip',
                              for: "org-table-project-#{project.id}-organization-#{org.id}"))),
                organization_path(org),
                id: "org-table-project-#{project.id}-organization-#{org.id}"
      end
    end
  end
end
