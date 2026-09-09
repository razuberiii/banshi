class ApplicationController < ActionController::Base
  helper_method :current_user, :signed_in?
  before_action :set_common_headers
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  def current_user = @current_user ||= User.find_by(id:session[:user_id])
  def signed_in? = current_user.present?
  private
  def require_login
    redirect_to login_path, alert:'先领一张入馆证，再继续。' unless signed_in?
  end
  def require_curator
    return redirect_to(login_path,alert:'请先登录馆务账号。') unless signed_in?
    render plain:'此处仅向馆务维护者开放。',status: :forbidden unless current_user.curator?
  end
  def not_found
    render 'shared/not_found',status: :not_found
  end
  def set_common_headers
    response.headers['X-Content-Type-Options']='nosniff'
    response.headers['Referrer-Policy']='strict-origin-when-cross-origin'
    response.headers['Content-Security-Policy']="default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'self'"
  end
  def page_number = [params[:page].to_i,1].max
end
