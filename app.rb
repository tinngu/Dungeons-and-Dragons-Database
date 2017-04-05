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

get '/dm' do
  halt(401, 'Not Authorized') unless session[:role] == 'DM'
  erb :dm
end

get '/player' do
  halt(401, 'Not Authorized') unless (session[:role] == 'DM' || session[:role] == 'Player')
  @currentUser = session[:name]
  cid = session[:cid]
  db = SQLite3::Database.new("development.db")
  # only show npcs known to player
  if session[:cid] > 0
    @results = db.execute("select n.name,c.town from campaigns c, npcs n
    where c.npc_id = n.npc_id and c.is_known = 't' and c.cid = (?)", cid)
  else # show all npcs in any campaign to admin
    @results = db.execute('select n.name,c.town from campaigns c, npcs n
    where c.npc_id = n.npc_id')
  end
  db.close
  erb :player
end

get '/database' do
  halt(401, 'Not Authorized') unless (session[:role] == 'DM')
  @currentUser = session[:name]
  cid = session[:cid]
  db = SQLite3::Database.new("development.db")

  if session[:cid] == 0
    @results0 = db.execute('select * from npcs')
    @results1 = db.execute('select * from campaigns')
    @results2 = db.execute('select * from npc_stats')
  end
  db.close
  erb :database
end

get '/dataView' do
  halt(401, 'Not Authorized') unless session[:role] == 'DM'
  db = SQLite3::Database.new("development.db")
  @dataArray = db.execute('select username, role, campaign_id from dung_drags')
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
    db.execute('insert into npcs values(?,?,?)', [newID, params[:Name], 'f'])
    # add into npc_stats table
    db.execute('insert into npc_stats values(?,?,?,?,?,?,?,?,?,?)',
               [newID, params[:Race], params[:Alignment], params[:Type],
                params[:Charisma], params[:Wisdom], params[:Intelligence],
                params[:Constitution], params[:Dexterity], params[:Strength]])
    db.close
  end
  redirect '/dm'
end
