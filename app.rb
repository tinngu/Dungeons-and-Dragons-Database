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

get '/admin' do
  halt(401, 'Not Authorized') unless session[:role] == 'Admin'
  erb :admin
end

get '/player' do
  halt(401, 'Not Authorized') unless (session[:role] == 'Admin' || session[:role] == 'Player')
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
  halt(401, 'Not Authorized') unless (session[:role] == 'Admin')
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
  halt(401, 'Not Authorized') unless session[:role] == 'Admin'
  db = SQLite3::Database.new("development.db")
  @dataArray = db.execute("select username from dung_drags")
  db.close
  erb :dataView
end

post '/login' do
  user = DungDrags.get(params[:username])
  if user.nil?
    redirect '/login'
  else
    if user[:role].casecmp('Admin') == 0
      session[:role] = 'Admin'
      session[:name] = user[:username]
      session[:cid] = user[:campaign_id]
      redirect to('/admin')

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

post '/uploadUsers' do
  halt(401, 'Not Authorized') unless session[:role] == 'Admin'

  begin
    File.open(params['file_source'][:filename], 'wb') do |f|
      f.write(params['file_source'][:tempfile].read)
    end

    file_name = params['file_source'][:filename].to_s

    original = File.open(file_name, 'r') { |file| file.readlines }
    blankless = original.reject{ |line| line.match(/^$/) }

    File.open(file_name, 'w') do |file|
      blankless.each { |line| file.puts line }
    end

    userList = CSV.read(file_name)
    userList.each do |x|
      password = x[1].to_s
      DungDrags.create(:username => x[0], :password => password, :role => x[2])
    end
    File.delete(params['file_source'][:filename].to_s)
  rescue
    puts 'Error: Invalid file upload'
  end

  redirect '/admin'
end

#Used for extracting zip files
def extract_zip(file, destination)
  FileUtils.mkdir_p(destination)

  Zip::File.open(file) do |zip_file|
    zip_file.each { |f|
      f_path=File.join(destination, f.name)
      FileUtils.mkdir_p(File.dirname(f_path))
      zip_file.extract(f, f_path) unless File.exist?(f_path)
    }
  end
end

post '/uploadWebsites' do
  halt(401, 'Not Authorized') unless session[:role] == 'Admin'
  begin
    File.open(params['file_source'][:filename], 'wb') do |f|
      f.write(params['file_source'][:tempfile].read)
    end
    file_name = params['file_source'][:filename].to_s
    file_name = URI.encode(file_name)
    destination = './public/files/'
    extract_zip(file_name, destination)
    File.delete(file_name)
    redirect '/displayWebsites'

  rescue Exception => error
    puts error.message
    puts error.backtrace.inspect
    redirect '/admin'
  end

end

post '/exportCSV' do
  halt(401, 'Not Authorized') unless session[:role] == 'Admin'
  begin
    @votingData = DungDrags.all #Stores all data into variable
    @csv = CSV.generate do |csv| #Generates CSV format
      @votingData.each {|x|
        csv << ["#{x.username.to_s}","#{x.first_Pick.to_s}","#{x.second_Pick.to_s}","#{x.third_Pick.to_s}"]
      }
    end
    @dataArray = CSV.parse(@csv) #Convert CSV to an array

    File.open('VotingData.csv','wb'){ |x| #Export CSV using the above array
      x << @dataArray.map(&:to_csv).join
    }

    send_file('VotingData.csv', :filename => 'VotingData.csv', :type => 'application/csv')
    File.delete('VotingData.csv')

    puts '****** CSV file was successfully exported ******'
  rescue
    puts '****** CSV was unsuccessful in export ******'

  end

  redirect '/admin'
end


get '/user/:username' do
  begin
    @user = DungDrags.get(params[:username])
    halt(401, 'Invalid User Access!') unless (session[:name].casecmp(@user.username) == 0)

    #You use save to persist changes made to a loaded resource and
    # you use update when you want to immediately persist changes
    # without changing resource's state to 'dirty'.
    @user.save
    erb :querypage
  rescue
    puts '****** TEST FLAG!! ******'
    @user = DungDrags.get(params[:username])
    erb :home
  end


end
