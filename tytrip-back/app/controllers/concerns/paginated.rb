# Offset pagination: ?page=1&per_page=25 (max 100). Views render @pagination as `meta`.
module Paginated
  MAX_PER_PAGE = 100

  private
    def paginate(scope)
      per_page = params.fetch(:per_page, 25).to_i.clamp(1, MAX_PER_PAGE)
      page = [ params.fetch(:page, 1).to_i, 1 ].max
      total = scope.count
      @pagination = { page: page, per_page: per_page, total: total, total_pages: (total.to_f / per_page).ceil }
      scope.offset((page - 1) * per_page).limit(per_page)
    end
end
