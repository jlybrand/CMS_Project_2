require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'tigers'
end

VALID_EXTENSIONS = [".txt", ".md"]

def invalid_extension?(extension)
  extension.empty? || !VALID_EXTENSIONS.include?(extension)
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def load_user_credentials
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

def session
  last_request.env["rack.session"]
end

def user_signed_in?
  session.key?(:username)
end

def require_user_login
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

# returns the correct path to where the documents will be stored based on the current environment.
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# File.expand_path("..", __FILE__) # return the path to the project folder.
# C:/Users/jalybrand/Desktop/Launch_School/RB175/CMS_Project

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path) # returns contents of file using #IOread

  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

# set filepath to C:/Users/jalybrand/Desktop/Launch_School/RB175/CMS_Project/data/name of file.txt
def file_path(filename)
   File.join(data_path, filename)
end

def file_list
  # returns array of filepaths- ["C:/Users/jalybrand/Desktop/Launch_School/RB175/CMS_Project/data/about.md", "C:/Users/jalybrand/Desktop/Launch_School/RB175/CMS_Project/data/changes.txt", "C:/Users/jalybrand/Desktop/Launch_School/RB175/CMS_Project/data/history.txt"]
    # filepaths = Dir.glob(root + "/data/*")
  pattern = File.join(data_path, "*")
  # iterates over `filepaths` and returns an array of filenames - ["about.md", "changes.txt", "history.txt"]
  Dir.glob(pattern).map { |path| File.basename(path) }
end

def create_file(filename, content = "")
  if  file_exists?(filename)
    session[:message] = "That file already exists. Please choose another name."
  else
    File.write(file_path(filename), content)
    session[:message] = "#{filename} has been created"
  end
end

def file_exists?(filename)
  file_list.include?(filename)
end

# Get a list of existing files.
get "/" do
  @files = file_list

  erb :index
end

get "/users/signup" do

  erb :signup
end

def invalid_username?(username)
  load_user_credentials.key?(username)
end

def store_credentials(username, password)
  credentials = load_user_credentials
  encrypted_password = BCrypt::Password.create(password).to_s
  credentials[username] = encrypted_password
  File.write(File.basename(credentials_path), credentials.to_yaml)
end

post '/users/signup' do
  @username = params[:username]
  password = params[:password]

  if invalid_username?(@username)
    session[:message] = "Username is in use, please choose another."
    status 422
    erb :signup
  else
    store_credentials(@username, password)
    session[:message] = "Account has been created. Please sign in to continue."
    redirect "/users/signin"
  end
end

get "/users/signin" do
  username = params[:username]

  erb :signin
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 422
    erb :signin
  end
end

get "/new" do
  require_user_login

  erb :new
end

get "/:filename" do
  if File.file?(file_path(params[:filename]))
    load_file_content(file_path(params[:filename]))
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_user_login

  @filename = params[:filename]
  @content = File.read(file_path(params[:filename]))
  erb :edit
end

post "/create" do
  require_user_login

  filename = params[:filename].to_s
  @content = params[:content]
  file_extension = File.extname(filename)

  if filename.empty?
    session[:message] = "A name is required"
    status 422
    erb :new
  elsif invalid_extension?(file_extension)
    session[:message] = "That is not a supported file extension."
    status 422
    erb :new
  else
    create_file(filename, @content)
    redirect "/"
  end
end

post "/:filename" do
  require_user_login

  File.write(file_path(params[:filename]), params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  require_user_login

  File.delete(file_path(params[:filename]))
  session[:message] = "#{params[:filename]} has been deleted."

  redirect "/"
end

post '/:filename/clone' do
  require_user_login

  @filename = params[:filename]
  @content = File.read(file_path(@filename))

  erb :new
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end
