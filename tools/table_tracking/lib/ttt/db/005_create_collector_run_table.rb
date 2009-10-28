require 'rubygems'
require 'activerecord'
require 'ttt/collector'

class CreateCollectorRunTable < ActiveRecord::Migration
  def self.up
    create_table :collector_runs do |t|
      t.string :collector, :limit => 25
      t.timestamp :last_run
    end
    add_index :collector_runs, :collector, :unique => true
    TTT::Collector.load_all
    TTT::Collector.each do |k,v|
      TTT::CollectorRun.new(:collector => k.stat.to_s).save!
    end
  end
  def self.down
    drop_table :collector_runs
  end
end
