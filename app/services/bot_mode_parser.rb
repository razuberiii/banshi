class BotModeParser
  def self.call(card)
    normalized = card.to_s.unicode_normalize(:nfkc).strip
    key = AppConfig.modes.rules.keys.sort_by { |k| -k.length }.find { |name| normalized.include?(name) }
    result = key ? AppConfig.modes.rules.fetch(key) : { 'collect' => false, 'distribute' => false }
    { collect: result.fetch('collect') == true, distribute: result.fetch('distribute') == true }
  end
end
