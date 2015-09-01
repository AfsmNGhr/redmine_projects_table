require_dependency 'projects_helper'

module RedmineOrgProjectsTable::Patches::ProjectsHelperPatch
  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)
    base.class_eval do
      unloadable
      alias_method_chain :render_project_action_links, :material_buttons
    end
  end

  module ClassMethods
  end

  module InstanceMethods
    def render_project_action_links_with_material_buttons
      links = []
      if User.current.allowed_to?(:add_project, nil, global: true)
        links << link_to(l(:label_project_new), new_project_path, class: 'mdl-button mdl-js-button mdl-button--raised mdl-button--colored mdl-js-ripple-effect mdl-color-text--white')
      end
      if User.current.allowed_to?(:view_issues, nil, global: true)
        links << link_to(l(:label_issue_view_all), issues_path, class: 'mdl-button mdl-js-button mdl-button--raised mdl-button--colored mdl-color--purple-400 mdl-js-ripple-effect mdl-color-text--white')
      end
      if User.current.allowed_to?(:view_time_entries, nil, global: true)
        links << link_to(l(:label_overall_spent_time), time_entries_path, class: 'mdl-button mdl-js-button mdl-button--raised mdl-button--colored mdl-color--indigo-400 mdl-js-ripple-effect mdl-color-text--white')
      end
      links << link_to(l(:label_overall_activity), activity_path, class: 'mdl-button mdl-js-button mdl-button--raised mdl-button--colored mdl-color--green-400 mdl-js-ripple-effect')
      links.join(' ').html_safe
    end
  end
end

ProjectsHelper.send :include,
                    RedmineOrgProjectsTable::Patches::ProjectsHelperPatch
