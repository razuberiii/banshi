class DemoController < ApplicationController
  before_action :require_login
  before_action { raise ActiveRecord::RecordNotFound unless AppConfig.demo.enabled }
  def index
    return unless allowed_simulator?
    @run=SimulationRun.find_or_create_by!(user:current_user) { |r|r.clock_at=Time.current }
    @candidate=@run.candidate;@entry=@run.entry
    @actions=@run.simulation_actions.order(id: :desc).limit(12)
    @pending=@actions.any? { |a|%w[queued running].include?(a.status) }
    @groups=Group.order(:id)
  end
  def create
    action_name=params[:action_name].to_s
    return head :bad_request unless SimulationProcessor::ACTIONS.key?(action_name)
    return unless action_name=='claim' || allowed_simulator?
    run=SimulationRun.find_or_create_by!(user:current_user) { |r|r.clock_at=Time.current }
    values=params.permit(:group_id,:transporter_id,:token).to_h
    values['token_digest']=Digest::SHA256.hexdigest(values.delete('token')) if values['token'].present?
    action=run.simulation_actions.create!(action_name:action_name,parameters:values)
    SimulationActionJob.perform_later(action.id)
    redirect_to current_user.curator? ? demo_path : claims_path,notice:'操作已排队，后台执行后会显示结果。'
  end
  private
  def allowed_simulator?
    return true if current_user.curator?
    render plain:'实验室仅向演示馆务账号开放。',status: :forbidden
    false
  end
end
