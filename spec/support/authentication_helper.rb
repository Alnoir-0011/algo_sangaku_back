module AuthenticationHelper
  def authenticate_stub(user)
    @_current_user = user
    allow_any_instance_of(Api::V1::BaseController).to receive(:authenticate).and_return(@_current_user)
    allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(@_current_user)
  end
end
