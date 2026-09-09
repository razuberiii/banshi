class ClaimIssuer
  def self.call(user:)
    token="CLAIM-#{SecureRandom.alphanumeric(AppConfig.claim.token_length).upcase}"
    record=user.claim_tokens.create!(token_digest:Digest::SHA256.hexdigest(token),expires_at:Time.current+AppConfig.claim.ttl)
    AuditLog.create!(user:user,category:'claim',action:'issued',details:{claim_id:record.id})
    [record,token]
  end
end
