require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
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

# returns the correct path to where the documents will be stored based on the current environment.
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# root = File.expand_path("..", __FILE__) # return the path to the project folder.
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

# Get a list of existing files.
get "/" do
# returns array of filepaths- ["C:/Users/jalybrand/Desktop/Launch_School/RB175/CMS_Project/data/about.md", "C:/Users/jalybrand/Desktop/Launch_School/RB175/CMS_Project/data/changes.txt", "C:/Users/jalybrand/Desktop/Launch_School/RB175/CMS_Project/data/history.txt"]
  # filepaths = Dir.glob(root + "/data/*")
  pattern = File.join(data_path, "*")
  filepaths = Dir.glob(pattern)


# iterates over `filepaths` and returns an array of filenames - ["about.md", "changes.txt", "history.txt"]
  @files = filepaths.map do |path|
    File.basename(path)
  end
  erb :index
end

get "/new" do
  require_signed_in_user
  erb :new
end

get "/:filename" do
  # file_path = root + "/data/" + params[:filename] # set filepath to C:/Users/jalybrand/Desktop/Launch_School/RB175/CMS_Project/data/name of file.txt

  file_path = File.join(data_path, params[:filename])

  if File.file?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  # file_path = root + "/data/" + params[:filename]
   file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)
  erb :edit
end

get "/users/signin" do
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

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

VALID_EXTENSIONS = [".txt", ".md"]

def valid_extension?(ext)
  return true if VALID_EXTENSIONS.include?(ext)
end

post "/create" do
  require_signed_in_user

  filename = params[:filename].to_s
  file_extension = File.extname(filename)

  if (filename.size) == 0
    session[:message] = "A name is required"
    status 422
    erb :new
  elsif file_extension.empty?
    session[:message] = "Name must include file extension"
    status 422
    erb :new
  elsif !valid_extension?(file_extension)
    session[:message] = "That is not a supported file extension."
    status 422
    erb :new
  else
    file_path = File.join(data_path, filename)

    File.write(file_path, "")
    session[:message] = "#{params[:filename]} has been created"
    redirect "/"
  end
end

post "/:filename" do
  require_signed_in_user

  # file_path = root + "/data/" + params[:filename]
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)
  session[:message] = "#{params[:filename]} has been deleted."

  redirect "/"
end
