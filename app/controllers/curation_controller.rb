class CurationController < ApplicationController
  before_action :require_curator
  def index
    entries=ShitEntry.unmerged
    entries=params[:q].present? ? entries.where(sid:params[:q].to_s.strip.upcase) : entries.where(safety_level:'RED')
    @entries=entries.includes(:first_group).order(created_at: :desc).limit(30)
    @candidates=Candidate.pending.includes(:group,content: :assets).order(created_at: :desc).limit(10)
    @reports=Report.where(status:'open').includes(:shit_entry,:user).order(created_at: :desc).limit(30)
    @merges=EntryMerge.order(created_at: :desc).includes(:source,:target).limit(20)
    @uncertain=Delivery.where(status:'uncertain').includes(:shit_entry,:group).order(updated_at: :desc).limit(20)
    @errors=SystemError.order(created_at: :desc).limit(10)
  end
  def health
    ActiveRecord::Base.connection.select_value('SELECT 1')
    render json:{database:'connected',jobs_pending:GoodJob::Job.where(finished_at:nil).count,events_pending:InternalEvent.where(status:%w[pending failed]).count,uncertain_deliveries:Delivery.where(status:'uncertain').count}
  end
  def review
    entry=ShitEntry.find_by!(sid:params[:sid])
    SafetyEvaluator.mark!(entry:entry,level:params[:level],tags:Array(params[:tags]).reject(&:blank?),visibility:params[:visibility],reason:params[:reason],user:current_user,source:'manual')
    entry.update!(title:params[:title],summary:params[:summary]) if params.key?(:title)
    redirect_to curation_path,notice:"#{entry.sid} 的安全档案已更新。"
  rescue ArgumentError,ActiveRecord::RecordInvalid=>e
    redirect_to curation_path,alert:e.message
  end
  def moderate_candidate
    CandidateModeration.call(candidate:Candidate.find(params[:id]),user:current_user,status:params[:status],reason:params[:reason])
    redirect_to curation_path,notice:'候选处理结果已记录。'
  rescue ArgumentError=>e
    redirect_to curation_path,alert:e.message
  end
  def resolve_report
    report=Report.find(params[:id])
    ReportService.resolve!(report:report,reviewer:current_user,status:params[:status],resolution:params[:resolution])
    redirect_to curation_path,notice:'处理结果已写入举报回执。'
  rescue ArgumentError,ActiveRecord::RecordInvalid=>e
    redirect_to curation_path,alert:e.message
  end
  def merge
    source=ShitEntry.find_by!(sid:params[:sid]);target=ShitEntry.find_by!(sid:params[:target_sid])
    EntryMergeService.merge!(source:source,target:target,user:current_user,reason:params[:reason])
    redirect_to curation_path,notice:'条目已合并，原编号保留为跳转入口。'
  rescue ArgumentError=>e
    redirect_to curation_path,alert:e.message
  end
  def revert
    EntryMergeService.revert!(merge:EntryMerge.find(params[:id]),user:current_user)
    redirect_to curation_path,notice:'错误合并已拆回，安全状态没有自动降低。'
  rescue ArgumentError=>e
    redirect_to curation_path,alert:e.message
  end
  def hide_asset
    asset=Asset.find(params[:id]);asset.update!(visibility:'hidden')
    AuditLog.create!(user:current_user,category:'safety',action:'asset_hidden',details:{asset_id:asset.id})
    redirect_to curation_path,notice:'资源已下架，原始元数据继续保留。'
  end
  def redact_asset
    original=Asset.find(params[:id]);file=params[:replacement]
    raise ArgumentError,'请选择完成打码的图片' unless file.respond_to?(:read)
    raise ArgumentError,'图片过大' if file.size>AppConfig.napcat.max_media_bytes
    replacement=Media::ContentIngestor.store(bytes:file.read)
    raise ArgumentError,'打码图不能与原图相同' if replacement==original
    Asset.transaction do
      replacement.update!(original_asset:original,visibility:'visible')
      original.attachments.update_all(asset_id:replacement.id,role:'redacted')
      ForwardNode.where(asset:original).update_all(asset_id:replacement.id)
      original.update!(visibility:'hidden')
      AuditLog.create!(user:current_user,category:'safety',action:'asset_redacted',details:{original_id:original.id,replacement_id:replacement.id})
    end
    redirect_to curation_path,notice:'已替换为打码图。条目仍需单独完成安全审核。'
  rescue ArgumentError=>e
    redirect_to curation_path,alert:e.message
  end
end
