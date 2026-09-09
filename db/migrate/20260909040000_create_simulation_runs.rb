class CreateSimulationRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :simulation_runs do |t|
      t.references :user, null:false,foreign_key:true,index:{unique:true}
      t.datetime :clock_at,null:false
      t.jsonb :state,null:false,default:{}
      t.timestamps
    end
    create_table :simulation_actions do |t|
      t.references :simulation_run,null:false,foreign_key:true
      t.string :action_name,null:false
      t.jsonb :parameters,null:false,default:{}
      t.string :status,null:false,default:'queued'
      t.text :result
      t.timestamps
    end
    add_index :simulation_actions,[:status,:created_at]
  end
end
