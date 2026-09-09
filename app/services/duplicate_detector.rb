class DuplicateDetector
  Result = Data.define(:entry, :status, :confidence, :method, :distance)
  def self.call(content:)
    exact=ShitEntry.joins(:content).where(contents:{fingerprint:content.fingerprint}).order(:id).first
    return Result.new(entry:canonical(exact),status:'confirmed',confidence:1.0,method:'sha256',distance:0) if exact
    return empty unless AppConfig.features.phash && content.image? && content.assets.any?
    best=nil
    ShitEntry.unmerged.joins(:content).where(contents:{kind:'image'}).includes(content: :assets).order(id: :desc).limit(AppConfig.duplicate.scan_limit).each do |entry|
      a=content.assets.to_a;b=entry.content.assets.to_a
      next unless a.length==b.length && a.zip(b).all? { |x,y| x.phash.present? && y.phash.present? }
      distances=a.zip(b).map { |x,y| Media::PerceptualHash.distance(x.phash,y.phash) }
      distance=distances.max
      next if distance>AppConfig.duplicate.possible_threshold
      aspect_matches=a.zip(b).all? { |x,y| ((x.width.to_f/x.height)-(y.width.to_f/y.height)).abs<=AppConfig.duplicate.aspect_tolerance }
      status=distance<=AppConfig.duplicate.phash_threshold && aspect_matches ? 'confirmed' : 'possible'
      result=Result.new(entry:entry,status:status,confidence:(1-distance/64.0).round(4),method:'phash',distance:distance)
      best=result if best.nil? || distance<best.distance
    end
    if best
      match=DuplicateMatch.find_or_initialize_by(content:content,shit_entry:best.entry)
      # A curator's rejection is retained so later scans do not silently re-merge it.
      return empty if match.persisted? && match.status=='rejected'
      match.update!(method:best.method,status:best.status,confidence:best.confidence,distance:best.distance)
    end
    best || empty
  end
  def self.canonical(entry)
    seen=[]
    while entry&.merged_into_id
      raise ArgumentError,'检测到合并循环' if seen.include?(entry.id)
      seen << entry.id;entry=entry.merged_into
    end
    entry
  end
  def self.empty = Result.new(entry:nil,status:nil,confidence:0,method:nil,distance:nil)
end
