class MediaController < ApplicationController
  def show
    asset=Asset.find(params[:id])
    entry_scope=ShitEntry.where(content_id:asset.attachments.select(:content_id))
    raise ActiveRecord::RecordNotFound unless asset.visibility=='visible' && (current_user&.curator? || entry_scope.merge(ShitEntry.publicly_visible).exists?)
    response.headers['Cache-Control']='private, no-store'
    response.headers['Content-Security-Policy']="default-src 'none'; sandbox"
    send_data Storage::Registry.current.read(key:asset.storage_key),type:asset.content_type,disposition:'inline',filename:"archive-#{asset.id}.#{asset.content_type.split('/').last}"
  rescue Storage::Adapter::NotFound
    raise ActiveRecord::RecordNotFound
  end
end
