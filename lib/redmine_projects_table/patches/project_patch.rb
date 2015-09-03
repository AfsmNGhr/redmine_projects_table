require_dependency 'project'

class Project
  has_many :self_queries, class_name: 'ProjectQuery', dependent: :delete_all
  has_many :organizations, through: :organization_roles
end
