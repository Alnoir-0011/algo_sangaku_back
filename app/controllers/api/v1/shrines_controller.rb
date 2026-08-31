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
          sangaku_counts = Sangaku.where(shrine_id: shrines.map(&:id)).group(:shrine_id).count
          render json: ShrineSerializer.new(shrines, params: { sangaku_counts: sangaku_counts }).serializable_hash.to_json, status: :ok
        else
          render_400(nil, "invalid params")
        end
      end

      def show
        shrine = Shrine.find(params[:id])
        sangaku_counts = { shrine.id => shrine.sangakus.count }
        render json: ShrineSerializer.new(shrine, params: { sangaku_counts: sangaku_counts }).serializable_hash.to_json, status: :ok
      end
    end
  end
end
