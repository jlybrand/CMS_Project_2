require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'secret'
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
    render_markdown(content)
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
  # file_path = root + "/data/" + params[:filename]
   file_path = File.join(data_path, params[:filename])

  @filename = params[:filename]
  @content = File.read(file_path)
  erb :edit
end

post "/:filename" do
  # file_path = root + "/data/" + params[:filename]
  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end
