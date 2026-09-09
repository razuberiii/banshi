class ClaimsController < ApplicationController
  before_action :require_login
  def index = @claims=current_user.claim_tokens.order(created_at: :desc).limit(10)
  def create
    @claim,@token=ClaimIssuer.call(user:current_user)
    render :show,status: :created
  end
  def show
    @claim=current_user.claim_tokens.find(params[:id]);@token=nil
  end
end
