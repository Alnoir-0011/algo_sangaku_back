module Api
  module V1
    module Admin
      class ShrinesController < BaseController
        before_action :set_shrine, only: %i[show update destroy]

        def index
          @pagy, shrines = pagy(::Shrine.all)
          render json: ::Admin::ShrineSerializer.new(shrines).serializable_hash.to_json, status: :ok
        end

        def show
          render json: ::Admin::ShrineSerializer.new(@shrine).serializable_hash.to_json, status: :ok
        end

        def create
          @shrine = ::Shrine.new(shrine_params)

          if @shrine.save
            render json: ::Admin::ShrineSerializer.new(@shrine).serializable_hash.to_json, status: :created
          else
            render_400(nil, @shrine.errors.full_messages)
          end
        end

        def update
          if @shrine.update(shrine_params)
            render json: ::Admin::ShrineSerializer.new(@shrine).serializable_hash.to_json, status: :ok
          else
            render_400(nil, @shrine.errors.full_messages)
          end
        end

        def destroy
          @shrine.destroy!
          render json: ::Admin::ShrineSerializer.new(@shrine).serializable_hash.to_json, status: :ok
        end

        private

        def set_shrine
          @shrine = ::Shrine.find(params[:id])
        end

        def shrine_params
          params.require(:shrine).permit(:name, :address, :latitude, :longitude, :place_id)
        end
      end
    end
  end
end
