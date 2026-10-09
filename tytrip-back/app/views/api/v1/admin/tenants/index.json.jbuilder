json.data @tenants, partial: "api/v1/admin/tenants/tenant", as: :tenant, member_counts: @member_counts
json.partial! "api/v1/shared/pagination", pagination: @pagination
