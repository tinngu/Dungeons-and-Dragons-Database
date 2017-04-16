require 'rubygems'
require 'sinatra'
require 'csv'
require 'dm-validations'
require 'zip'
require 'uri'
require 'sqlite3'
# ---------------------------------------For the database-----------------------
require 'dm-core'
require 'dm-migrations'
require 'dm-sqlite-adapter'
require 'data_mapper'
require './database'

configure do
  enable :sessions
end

get '/' do
  erb :home
end

get '/login' do
  erb :login
end

get '/logout' do
  session.clear
  redirect to ('/')
end

get '/search' do
  halt(401, 'Not Authorized') unless session[:role] == 'DM'
  erb :search
end

get '/searchResults' do
  halt(401, 'Not Authorized') unless session[:role] == 'DM'
  db = SQLite3::Database.new('development.db')
  if params[:Race] == 'Any' && params[:Type] == 'Any' && params[:Alignment] == 'Any'
    @results = search_by_stats(params[:Stat], params[:Operator], params[:Value])
  elsif params[:Race] == 'Any' && params[:Alignment] != 'Any' && params[:Type] != 'Any'
    @results = search_any_race(params[:Type], params[:Alignment],
                               params[:Stat], params[:Operator], params[:Value])
  elsif params[:Type] == 'Any' && params[:Race] != 'Any' && params[:Type] != 'Any'
    @results = search_any_type(params[:Race], params[:Alignment],
                               params[:Stat], params[:Operator], params[:Value])
  elsif params[:Alignment] == 'Any' && params[:Race] != 'Any' && params[:Type] != 'Any'
    @results = search_any_alignment(params[:Race], params[:Type],
                                    params[:Stat], params[:Operator], params[:Value])
  elsif params[:Race] == 'Any' && params[:Type] == 'Any' && params[:Alignment] !='Any'
    @results = search_any_race_type(params[:Alignment], params[:Stat],
                                    params[:Operator], params[:Value])
  elsif params[:Race] == 'Any' && params[:Alignment] == 'Any' && params[:Type] != 'Any'
    @results = search_any_race_alignment(params[:Type], params[:Stat],
                                         params[:Operator], params[:Value])
  elsif params[:Type] == 'Any' && params[:Alignment] == 'Any' && params[:Race] != 'Any'
    @results = search_any_type_alignment(params[:Race], params[:Stat],
                                         params[:Operator], params[:Value])
  else @results = search_all(params[:Race], params[:Type], params[:Alignment],
                             params[:Stat], params[:Operator], params[:Value])
  end
  session[:searchResults] = @results
 erb :searchResults
end

get '/dm' do
  halt(401, 'Not Authorized') unless session[:role] == 'DM'
  cid = session[:cid]
  db = SQLite3::Database.new('development.db')
  @remove_pool = db.execute('select n.npc_id from campaigns c, npcs n, npc_stats ns
   where c.npc_id = n.npc_id and n.npc_id = ns.npc_id and c.cid = ?', cid)
  @add_pool = db.execute('select n.npc_id from campaigns c, npcs n, npc_stats ns
   except select n.npc_id from campaigns c, npcs n, npc_stats ns
   where c.npc_id = n.npc_id and n.npc_id = ns.npc_id and c.cid = ?', cid)
  @unknown_pool = db.execute("select npc_id from campaigns
  where is_known='false' and cid = ?", cid)
  db.close
  @remove_pool = @remove_pool.flatten
  @add_pool = @add_pool.flatten
  @unknown_pool = @unknown_pool.flatten
  erb :dm
end

get '/addPlayer' do
  db = SQLite3::Database.new('development.db')
  @cids = db.execute("select campaign_id from dung_drags where role = 'DM'")
  @cids = @cids.flatten
  erb :addPlayer
end

get '/addDM' do
  erb :addDM
end


get '/successPage' do
  db = SQLite3::Database.new('development.db')
  @results = db.execute('select role, username, campaign_id
                             from dung_drags order by rowid desc limit 1')
  db.close
  erb :successPage
end

get '/player' do
  halt(401, 'Not Authorized') unless session[:role] == 'DM' || session[:role] == 'Player'
  cid = session[:cid]
  db = SQLite3::Database.new('development.db')
  # only show npcs known to player for the campaign they are in
  if session[:role] == 'Player'
    @results = db.execute("
    select n.name,c.town, n.type, n.race
    from campaigns c, npcs n
    where c.npc_id = n.npc_id
    and c.is_known = 'true' and c.cid = ?", cid)
  end
  if session[:role] == 'DM' # show all npcs in campaign DM is in charge of
    @results = db.execute('select n.name,c.town, n.type, n.race
    from campaigns c, npcs n
    where c.npc_id = n.npc_id
    and  c.cid = ?', cid)
  end
  db.close
  erb :player
end

get '/database' do
  halt(401, 'Not Authorized') unless (session[:role] == 'DM')
  db = SQLite3::Database.new("development.db")

  @results0 = db.execute('select * from npcs')
  @results1 = db.execute('select * from campaigns')
  @results2 = db.execute('select * from npc_stats')
  db.close
  erb :database
end

get '/dataView' do
  halt(401, 'Not Authorized') unless session[:role] == 'DM'
  db = SQLite3::Database.new('development.db')
  # get player/dm info
  @dataArray = db.execute('select username, role from dung_drags
                               where campaign_id = ?', session[:cid])
  # get npc info for campaign DM is in charge of
  @npcs = db.execute('select n.npc_id, n.name, n.race, ns.alignment, n.type,
  ns.charisma, ns.wisdom, ns. intelligence,
  ns.constitution, ns. dexterity, ns.strength, c.town, c.is_known
  from npcs n, npc_stats ns, campaigns c
  where n.npc_id = ns.npc_id and c.npc_id = n.npc_id and c.cid = ?',
                     session[:cid])
  db.close
  erb :dataView
end

post '/login' do
  user = DungDrags.get(params[:username])
  if user.nil?
    redirect '/login'
  else
    if user[:role].casecmp('DM') == 0
      session[:role] = 'DM'
      session[:name] = user[:username]
      session[:cid] = user[:campaign_id]
      redirect to('/dm')

    elsif user[:role].casecmp('Player') == 0
      session[:role] = 'Player'
      session[:name] = user[:username]
      session[:cid] = user[:campaign_id]
      redirect to('/player')

    else
      redirect '/login'
      end
    end
end


post '/addNPC' do
  halt(401, 'Not Authorized') unless session[:role] == 'DM'
  begin
    db = SQLite3::Database.new('development.db')
    db.type_translation = true
    # get highest npc id and increment by 1 to get new ID
    newID = db.get_first_value('select max(npc_id) from npcs')
    newID += 1
    # add into npcs table
    db.execute('insert into npcs values(?,?,?,?)',
               [newID, params[:Name], params[:Race], params[:Type]])
    # add into npc_stats table
    db.execute('insert into npc_stats values(?,?,?,?,?,?,?,?)',
               [newID, params[:Alignment], params[:Charisma],
                params[:Wisdom], params[:Intelligence],
                params[:Constitution], params[:Dexterity], params[:Strength]])
    db.close
  end
  redirect '/dm'
end

post '/addPlayer' do
  begin
    # insert new player into database
    db = SQLite3::Database.new('development.db')
    db.execute("insert into dung_drags values(?,?,'Player',?)",
               [params[:USERNAME], params[:PASSWORD], params[:CID]])
    db.close
  end
  redirect '/successPage'
end

post '/addDM' do
  begin
    # automatically assign a new campaign ID to DM by incrementing largest campaign_id by 1
    db = SQLite3::Database.new('development.db')
    newCID = db.get_first_value("select max(campaign_id) from dung_drags
                                     where role = 'DM'")
    newCID += 1
    # insert new DM into database
    db.execute("insert into dung_drags values(?,?,'DM',?)",
               [params[:USERNAME], params[:PASSWORD], newCID])
    db.close
  end
  redirect '/successPage'
end

post '/add2Camp' do
  db = SQLite3::Database.new('development.db')
  db.execute("
  INSERT INTO campaigns (npc_id, cid, town, is_known)
  VALUES (?, ?, ?, 'false' )",
             [params[:npc_id], session[:cid], params[:town]])
  db.close
  redirect '/dm'
end

post '/remNPC' do
  begin
    db = SQLite3::Database.new('development.db')
    db.execute('DELETE from campaigns WHERE npc_id=?', params[:npc_id])
  end
  redirect '/dm'
end

post '/makeKnown' do
  db = SQLite3::Database.new('development.db')
  db.execute("update campaigns set is_known = 'true'
                  where npc_id = ? and cid = ?",
             [params[:npc_id], session[:cid]])
  redirect '/dm'
end

post '/searchNPC' do
  query = params.map { |key, value| "#{key}=#{value}" }.join("&")
  redirect to("/searchResults?#{query}")
end

def search_all(race, type, alignment, stat, operator, value)
  db = SQLite3::Database.new('development.db')
  results = db.execute("select n.npc_id, n.name, n.race, n.type, s.alignment,
                            s.strength, s.dexterity, s.constitution,
                            s.intelligence, s.wisdom, s.charisma
                            from npcs n, npc_stats s where n.race = ? AND
                            n.type = ? AND s.Alignment = ?
                            AND n.npc_id = s.npc_id
                            AND #{stat} #{operator} #{value}",
                       [race, type, alignment])
end

def search_any_race(type, alignment, stat, operator, value)
  db = SQLite3::Database.new('development.db')
  results = db.execute("select n.npc_id, n.name, n.race, n.type, s.alignment,
                            s.strength, s.dexterity, s.constitution,
                            s.intelligence, s.wisdom, s.charisma
                            from npcs n, npc_stats s where
                            n.type = ? AND s.Alignment = ?
                            AND n.npc_id = s.npc_id
                            AND #{stat} #{operator} #{value}",
                       [type, alignment])
end

def search_any_type(race, alignment, stat, operator, value)
  db = SQLite3::Database.new('development.db')
  results = db.execute("select n.npc_id, n.name, n.race, n.type, s.alignment,
                            s.strength, s.dexterity, s.constitution,
                            s.intelligence, s.wisdom, s.charisma
                            from npcs n, npc_stats s where n.race = ?
                            AND s.Alignment = ?
                            AND n.npc_id = s.npc_id
                            AND #{stat} #{operator} #{value}",
                       [race, alignment])
end

def search_any_alignment(race, type, stat, operator, value)
  db = SQLite3::Database.new('development.db')
  results = db.execute("select n.npc_id, n.name, n.race, n.type, s.alignment,
                            s.strength, s.dexterity, s.constitution,
                            s.intelligence, s.wisdom, s.charisma
                            from npcs n, npc_stats s where n.race = ? AND
                            n.type = ? AND n.npc_id = s.npc_id
                            AND #{stat} #{operator} #{value}",
                       [race, type])
end

def search_by_stats(stat, operator, value)
  db = SQLite3::Database.new('development.db')
  results = db.execute("select n.npc_id, n.name, n.race, n.type, s.alignment,
                            s.strength, s.dexterity, s.constitution,
                            s.intelligence, s.wisdom, s.charisma
                            from npcs n, npc_stats s where n.npc_id = s.npc_id
                            AND #{stat} #{operator} #{value}")
end

def search_any_race_type(alignment, stat, operator, value)
  db = SQLite3::Database.new('development.db')
  results = db.execute("select n.npc_id, n.name, n.race, n.type, s.alignment,
                            s.strength, s.dexterity, s.constitution,
                            s.intelligence, s.wisdom, s.charisma
                            from npcs n, npc_stats s where
                            s.Alignment = ? AND n.npc_id = s.npc_id
                            AND #{stat} #{operator} #{value}",
                       [alignment])
end

def search_any_race_alignment(type, stat, operator, value)
  db = SQLite3::Database.new('development.db')
  results = db.execute("select n.npc_id, n.name, n.race, n.type, s.alignment,
                            s.strength, s.dexterity, s.constitution,
                            s.intelligence, s.wisdom, s.charisma
                            from npcs n, npc_stats s where
                            n.type = ? AND n.npc_id = s.npc_id
                            AND #{stat} #{operator} #{value}",
                       [type])
end

def search_any_type_alignment(race, stat, operator, value)
  db = SQLite3::Database.new('development.db')
  results = db.execute("select n.npc_id, n.name, n.race, n.type, s.alignment,
                            s.strength, s.dexterity, s.constitution,
                            s.intelligence, s.wisdom, s.charisma
                            from npcs n, npc_stats s where n.race = ?
                            AND n.npc_id = s.npc_id
                            AND #{stat} #{operator} #{value}",
                       [race])
end
