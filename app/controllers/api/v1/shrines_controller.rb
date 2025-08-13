module Api
  module V1
    class ShrinesController < BaseController
      skip_before_action :authenticate, only: %i[index show]

      def index
        shrines = if params[:searchType] == "Map"
                    Shrine.search_by_bounds(params[:lowLat], params[:highLat], params[:lowLng], params[:highLng])
        elsif params[:searchType] == "List"
                    Shrine.search_by_location(params[:lat], params[:lng])
        else
                    nil
        end

        if shrines
          render json: ShrineSerializer.new(shrines).serializable_hash.to_json, status: :ok
        else
          render_400(nil, "invalid params")
        end
      end

      def show
        shrine = Shrine.find(params[:id])
        render json: ShrineSerializer.new(shrine).serializable_hash.to_json, status: :ok
      end
    end
  end
end
