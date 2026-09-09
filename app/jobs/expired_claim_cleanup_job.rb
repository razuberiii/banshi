class ExpiredClaimCleanupJob < ApplicationJob
  def perform
    ClaimToken.where(used_at:nil).where('expires_at < ?',Time.current).delete_all
  end
end
