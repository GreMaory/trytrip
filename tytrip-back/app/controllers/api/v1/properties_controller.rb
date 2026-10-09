module Api
  module V1
    class PropertiesController < BaseController
      before_action -> { authorize!("properties.read") }, only: %i[index show]
      before_action -> { authorize!("properties.manage") }, except: %i[index show]
      before_action :set_property, except: %i[index create]

      def index
        scope = Lodging::Property.includes(:units).order(:name)
        scope = scope.where(status: params[:status].presence || "active") unless params[:status] == "all"
        scope = scope.where("name ILIKE ?", "%#{Lodging::Property.sanitize_sql_like(params[:q])}%") if params[:q].present?
        @properties = paginate(scope)
      end

      def show
      end

      def create
        @property = Lodging::Property.new(property_params)
        Lodging::Property.transaction do
          @property.save!
          # Most properties are rented as a whole: create their first unit.
          @property.units.create!(params.fetch(:unit, {}).permit(*UnitsController::ATTRIBUTES).with_defaults(name: @property.name))
        end
        audit!("property.created", subject: @property)
        render :show, status: :created
      end

      def update
        @property.update!(property_params)
        audit!("property.updated", subject: @property, metadata: { fields: @property.saved_changes.keys - %w[updated_at] })
        render :show
      end

      def destroy
        @property.update!(status: :archived)
        audit!("property.archived", subject: @property)
        head :no_content
      end

      private
        def set_property
          @property = Lodging::Property.includes(:units).find(params[:id])
        end

        def property_params
          params.expect(property: [
            :name, :property_type, :status, :description, :address_line1, :address_line2, :postal_code, :city,
            :country_code, :latitude, :longitude, :time_zone, :check_in_time, :check_out_time, :house_rules,
            :access_instructions, amenities: []
          ])
        end
    end
  end
end
