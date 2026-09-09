raise 'Enable DEMO_ENABLED in a development environment first.' unless AppConfig.demo.enabled
user=User.find_by!(email:AppConfig.demo.email)
run=SimulationRun.find_or_create_by!(user:user) { |r| r.clock_at=Time.current }
requested=ARGV.first || 'all'
actions=requested=='all' ? %w[image replies reaction evaluate approve dispatch feedback finish distribute repeat revive] : [requested]
actions.each do |name|
  raise "Unknown action. Choose #{SimulationProcessor::ACTIONS.keys.join(', ')} or all." unless SimulationProcessor::ACTIONS.key?(name)
  action=run.simulation_actions.create!(action_name:name)
  SimulationActionJob.perform_now(action.id)
  action.reload
  puts "#{name.ljust(12)} #{action.status.ljust(7)} #{action.result}"
  raise "Stopped after #{name}. Inspect the curator's simulation page." unless action.status=='done'
end
puts "Current exhibit: #{run.reload.entry&.sid || '(candidate observing)'}"
