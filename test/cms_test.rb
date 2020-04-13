ENV["RACk_ENV"] = "test" # This value is used by various parts of Sinatra and Rack to know if the code is being tested, and in the case of Sinatra, to determine whether it will start a web server or not (we don't want it to if we're running tests):

require "minitest/autorun"
require "rack/test"    # gives us access to Rack::Test helper methods. rack/test does not come built in with Sinatra, so we'll need to add the rack-test gem to our Gemfile.
require "fileutils"

require_relative "../cms"


class CMS < Minitest::Test
  include Rack::Test::Methods # access to a bunch of useful testing helper methods. These methods expect a method called `app` to exist and return an instance of a Rack application when called.

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def tear_down
    FileUtils.rm_rf(data_path)
  end

  #  This method creates empty files by default, but an optional second parameter allows the contents of the file to be passed in:
  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
   create_document "about.md"
   create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_text_document
    create_document "history.txt", "Ruby 0.95 released"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_viewing_markdown_document
    create_document "about.md", "# Ruby is"
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is</h1>"
  end

  def test_document_not_found
    get "/no_file.txt"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "no_file.txt does not exist."

    get "/"
    refute_includes last_response.body, "no_file.txt does not exist."
  end

  def test_editing_file
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_file
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
end
