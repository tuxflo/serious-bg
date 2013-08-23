# encoding: utf-8
if "1.9".respond_to?(:encoding)
  Encoding.default_external = 'UTF-8'
  Encoding.default_internal = 'UTF-8'
end

require 'rubygems'
require 'bundler'
Bundler.setup(:default)
require 'sinatra/base'
require 'stupid_formatter'
require 'yaml'
require 'builder'
require 'ruby_ext'

puts "CUSTOM"

class Serious < Sinatra::Base
  
  set :articles, Proc.new { File.join(Dir.getwd, 'articles') }
  set :pages, Proc.new { File.join(Dir.getwd, 'pages') }
  set :static, true # Required to serve static files, see http://www.sinatrarb.com/configuration.html
  set :future, true
  
  not_found do
    erb :"404"
  end
  
  before do
    headers['Cache-Control'] = "public, max-age=#{Serious.cache_timeout}"
  end
  
  helpers do
    # Helper for rendering partial _archives
    def render_archived(articles)
      render :erb, :'_archives', :locals => { :articles => articles }, :layout => false
    end

    def render_nav(articles)
      render :erb, :'_navigation', :locals => { :articles => articles }, :layout => false
    end

    def render_controls(article)
      render :erb, :"_podcast_controls", :locals => { :article => article }, :layout => false
    end

    def render_disqus(article)
      render :erb, :"_disqus", :locals => { :article => article }, :layout => false
    end

    def render_flattr(article)
      render :erb, :"_flattr", :locals => { :article => article }, :layout => false
    end
    
    def render_article(article, summary_only=false)
      render :erb, :'_article', :locals => { :article => article, :summary_only => summary_only }, :layout => !summary_only
    end
    
    def render_partial(name)
      render :erb, :"_#{name}", :layout => false
    end
  end

  # Index page
  get '/' do
    @recent = Article.all(:limit => Serious.items_on_index)
    @archived = Article.all(:limit => Serious.archived_on_index, :offset => Serious.items_on_index)
    erb :index
  end
  
  get '/atom.xml' do
    feed_size = (params.delete('feed_size') || Serious.items_in_feed).to_i
    @page = (params.delete('page') || 0).to_i    
    @articles = Article.all(
    :limit => feed_size,
    :offset => @page * feed_size
    )
    
    @current_url = request.url 
    # If our current page is filled, ther is probably a next one too
    # If it isn't, we'll serve an empty page... for now
    if @articles.size == feed_size
      parsed_uri = URI(request.url)
      parsed_uri.query = parsed_uri.query.gsub(/[?&]page=\d+/,'')
      parsed_uri.query += "&page=#{@page + 1}"
      @next_url = parsed_uri.to_s
    end
    
    builder :atom
  end

  # /podcast_feed/talk/mp3/atom.xml
  get '/podcast_feed/*/*/atom.xml' do
    feed_size = (params.delete('feed_size') || Serious.items_in_feed).to_i
    @page = (params.delete('page') || 0).to_i
    category, audio_format = params[:splat]
    @articles = Article.all(
      :audioformat => audio_format,
      :category => category,
      :limit => feed_size,
      :offset => @page * feed_size
    )
    @selected_audio_codec = audio_format
    
    @current_url = request.url 
    # If our current page is filled, ther is probably a next one too
    # If it isn't, we'll serve an empty page... for now    
    if @articles.size == feed_size
      parsed_uri = URI(request.url)
      parsed_uri.query = parsed_uri.query.gsub(/[?&]page=\d+/,'')
      parsed_uri.query += "&page=#{@page + 1}"
      @next_url = parsed_uri.to_s
    end
    
    builder :atom
  end
  
  # Specific article route
  get %r{^/(\d{4})/(\d{1,2})/(\d{1,2})/([^\/]+)} do
    halt 404 unless @article = Article.first(*params[:captures])
    render_article @article
  end
  
  # Archives route
  get %r{^/(\d{4})[/]{0,1}(\d{0,2})[/]{0,1}(\d{0,2})[/]{0,1}$} do
    selection = params[:captures].reject {|s| s.strip.length == 0 }.map {|n| n.length == 1 ? "%02d" % n : n}
    @articles = Article.find(*selection)
    @title = "Archives for #{selection.join("-")}"
    erb :archives
  end
  
  get "/archives" do
    @articles = Article.all
    @title = "Archives"
    erb :archives
  end
  
  get "/pages" do
    @articles = Page.all
    @title = "Pages"
    erb :archives
  end
  
  get "/blog/*" do
    redirect "/#{params[:splat][0]}"
  end
  
  get "/pages/:page" do
    halt 404 unless @article = Page.find(params[:page])
    render_article @article
  end
end

require 'serious/version'
require 'serious/article'
require 'serious/page'
# Set up default stupid_formatter chain
StupidFormatter.chain = [StupidFormatter::Erb, StupidFormatter::RDiscount]

# Set up defaults for app
Serious.set :root, File.join(File.dirname(__FILE__), 'site')
Serious.set :title, "Serious"
Serious.set :author, "unknown"
Serious.set :url, 'http://localhost:3000'
Serious.set :items_in_feed, 25 # Number of items to display in atom feed
Serious.set :items_on_index, 3 # Number of items to display with summary on main page
Serious.set :archived_on_index, 10 # Number of items to display small (title only) on main page
Serious.set :cache_timeout, 300
Serious.set :run, false
Serious.set :environment, :test
Serious.set :date_format, "%B %o %Y"
Serious.set :disqus, false
Serious.set :google_analytics, false
Serious.set :flattr, false
Serious.set :feed_url, '/atom.xml'