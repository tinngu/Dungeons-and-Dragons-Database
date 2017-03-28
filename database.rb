require 'dm-core'
require 'dm-migrations'
require 'dm-sqlite-adapter'
require 'data_mapper'

configure do
  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/development.db")
end

class DungDrags
  include DataMapper::Resource
  property :username, String, key: true
  property :role, String
  property :campaign_id, Integer
end

class NPC_stats
  include DataMapper::Resource

  property :NPC_ID, Integer, key:true
  property :Race, String
  property :Alignment, String
  property :Type, String
  property :Charisma, Integer
  property :Wisdom, Integer
  property :Intelligence, Integer
  property :Constitution, Integer
  property :Dexterity, Integer
  property :Strength, Integer
end

class NPC
  include DataMapper::Resource

  property :NPC_ID, Integer, key:true
  property :name, String
  property :in_Campaign, Boolean
end

class Campaign
  include DataMapper::Resource

  property :NPC_ID, Integer, key:true
  property :CID, Integer
  property :Town, String
  property :Is_Known, Boolean
end


DataMapper.finalize()

## parse CSV into database
## npcList = CSV.read('./NPCs.txt')
## npcList.each do |x|
##  NPC_stats.create(:NPC_ID => x[0], :Strength => x[1], :Dexterity => x[2], :Constitution => x[3], :Intelligence => x[4], :Wisdom => x[5], :Charisma => x[6], :Type => x[7], :Race => x[8], :Alignment => x[9])
## end
