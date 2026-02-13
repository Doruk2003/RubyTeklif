module Roles
  ADMIN = "admin"
  MANAGER = "manager"
  OPERATOR = "operator"
  VIEWER = "viewer"

  # Legacy roles kept for backward compatibility during transition.
  SALES = "sales"
  FINANCE = "finance"
  HR = "hr"

  ASSIGNABLE_ROLES = [ADMIN, MANAGER, OPERATOR, VIEWER].freeze
  LEGACY_ROLES = [SALES, FINANCE, HR].freeze
  ACCEPTED_ROLES = (ASSIGNABLE_ROLES + LEGACY_ROLES).freeze

  ASSIGNABLE_ROLE_OPTIONS = [
    ["Admin", ADMIN],
    ["Manager", MANAGER],
    ["Operator", OPERATOR],
    ["Viewer", VIEWER]
  ].freeze

  def self.admin?(role)
    role.to_s == ADMIN
  end

  def self.catalog_manage?(role)
    [ADMIN, MANAGER, OPERATOR, SALES].include?(role.to_s)
  end

  def self.finance_manage?(role)
    [ADMIN, MANAGER, FINANCE].include?(role.to_s)
  end

  def self.role_badge_class(role)
    case role.to_s
    when ADMIN
      "bg-slate-800 text-white"
    when MANAGER
      "bg-indigo-100 text-indigo-800"
    when OPERATOR
      "bg-sky-100 text-sky-800"
    when VIEWER
      "bg-slate-200 text-slate-700"
    when SALES
      "bg-sky-100 text-sky-800"
    when FINANCE
      "bg-emerald-100 text-emerald-800"
    when HR
      "bg-amber-100 text-amber-800"
    else
      "bg-slate-100 text-slate-700"
    end
  end
end
