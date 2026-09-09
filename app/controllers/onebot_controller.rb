class OnebotController < ActionController::API
  def create
    return head :not_found unless AppConfig.napcat.enabled
    expected=AppConfig.napcat.webhook_token
    supplied=request.headers['Authorization'].to_s.delete_prefix('Bearer ')
    return head :unauthorized if expected.blank? || !ActiveSupport::SecurityUtils.secure_compare(supplied,expected)
    connection=BotConnection.find(params[:connection_id])
    payload=params.permit!.to_h.except('controller','action','connection_id')
    return head :bad_request unless payload['self_id'].to_s==connection.bot_account.external_id
    records=Events::Ingestor.call(payload:payload,connection:connection)
    render json:{accepted:true,events:records.map(&:event_id)},status: :accepted
  end
end
