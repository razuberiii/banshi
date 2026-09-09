class ClaimVerifier
  Result=Data.define(:success,:reason)
  def self.call(token:nil,digest:nil,group:,sender_external_id:,adapter:,mentions_bot:)
    return Result.new(success:false,reason:'需要 @机器人') unless mentions_bot
    digest ||= Digest::SHA256.hexdigest(token.to_s)
    return Result.new(success:false,reason:'认领码无效') unless digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/)
    record=ClaimToken.find_by(token_digest:digest)
    return Result.new(success:false,reason:'认领码无效') unless record
    record.with_lock do
      return Result.new(success:false,reason:'认领码已使用或已过期') if record.used_at || record.expires_at<=Time.current || record.attempts>=AppConfig.claim.max_attempts
      record.increment!(:attempts)
      # Never trust a role supplied inside an incoming message payload.
      role=adapter.get_group_member_info(group_external_id:group.external_id,user_external_id:sender_external_id).fetch('role')
      unless %w[owner admin].include?(role)
        AuditLog.create!(user:record.user,group:group,category:'claim',action:'denied',details:{claim_id:record.id,reason:'role'})
        return Result.new(success:false,reason:'只有群主或管理员可以认领')
      end
      record.update!(group:group,used_at:Time.current)
      management=GroupManagement.find_or_initialize_by(user:record.user,group:group)
      management.update!(verified_role:role,verified_at:Time.current)
      AuditLog.create!(user:record.user,group:group,category:'claim',action:'verified',details:{claim_id:record.id,role:role})
      Result.new(success:true,reason:'认领成功')
    end
  rescue KeyError,ActiveRecord::RecordNotFound,Adapters::OneBotAdapter::RemoteError
    AuditLog.create!(user:record&.user,group:group,category:'claim',action:'denied',details:{reason:'role_unavailable'})
    Result.new(success:false,reason:'无法核验群成员权限')
  end
end
