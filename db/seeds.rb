require_relative 'seeds/archive_seed'

if AppConfig.demo.seed
  ArchiveSeed.call
else
  puts 'SEED_DEMO=false: no fictional records created.'
end
