module Api
  module V1
    class UnitsController < BaseController
      ATTRIBUTES = %i[name status max_guests bedrooms beds bathrooms base_rate min_stay max_stay].freeze

      before_action -> { authorize!("properties.read") }, only: :index
      before_action -> { authorize!("properties.manage") }, except: :index

      def index
        scope = Lodging::Unit.includes(:property).order(:name)
        scope = scope.where(property_id: params[:property_id]) if params[:property_id].present?
        scope = scope.active if params[:status] != "all"
        @units = scope
      end

      def create
        property = Lodging::Property.find(params.require(:property_id))
        @unit = property.units.create!(unit_params)
        audit!("unit.created", subject: @unit)
        render :show, status: :created
      end

      def update
        @unit = Lodging::Unit.find(params[:id])
        @unit.update!(unit_params)
        audit!("unit.updated", subject: @unit)
        render :show
      end

      def destroy
        unit = Lodging::Unit.find(params[:id])
        if unit.reservations.exists?
          unit.update!(status: :inactive)
        else
          unit.destroy!
        end
        audit!("unit.removed", subject: unit)
        head :no_content
      end

      private
        def unit_params
          params.expect(unit: ATTRIBUTES)
        end
    end
  end
end
