# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base

  include AuthenticatedSystem

  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => 'fe1924bac06f3b8a2448e78b30b12a60'

  # See ActionController::Base for details
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password").
  filter_parameter_logging :password

  def initialize_filter

    @user = current_web_user.user if logged_in?
    @filter=Hash.new
    @map_index = 0

    @filter[:post_limit] = 22
    @filter[:author_id] = nil?
    @filter[:category_list] = Array.new;
    @filter[:searchterms] = ""
    @filter[:rating_from] = 0
    @filter[:rating_to]=  5
    @filter[:price_from]=0
    @filter[:price_to]=500
    @filter[:radius]= 50
    @filter[:show_unmapped]=false

    #set widgets
    unless params[:blog_entry].nil? then
      if params[:blog_entry][:sliders].nil? == false
        session[:sliders] =  params[:blog_entry][:sliders] == "true"
      end

      if params[:blog_entry][:map].nil? == false
        session[:map] = params[:blog_entry][:map] == "true"
      end

      if params[:user][:post_limit] then
        @filter[:post_limit] = params[:user][:post_limit]
      end

    else
      session[:sliders] = false
      session[:map] = false
    end

    use_sliders = session[:sliders]
    #prepare filters for sliders
    if use_sliders
      @filter[:price_from]=params[:blog_entry][:price_from] unless params[:blog_entry][:price_from].nil?
      @filter[:price_to]=params[:blog_entry][:price_to] unless params[:blog_entry][:price_to].nil?

      @filter[:rating_from] = params[:blog_entry][:search_rating_from] unless params[:blog_entry][:search_rating_from].nil?
      @filter[:rating_to]= params[:blog_entry][:search_rating_to] unless params[:blog_entry][:search_rating_to].nil?

      @filter[:radius] = params[:blog_entry][:radius] unless params[:blog_entry][:radius].nil?
    end


    if logged_in?
      @filter[:show_unmapped] = params[:user][:show_unmapped] == "on" if params[:user]
      @filter[:show_unmapped] = true if params[:user].nil?
    else
      @filter[:show_unmapped] = false;
    end

    if logged_in?
      if params[:user]
        @show_friends_only = params[:user][:show_friends_only] == "1"
        current_web_user.user.show_friends_only = @show_friends_only
        current_web_user.user.save(false)
      else
        @show_friends_only = current_web_user.user.show_friends_only
      end
    end


    @search_category_list, @search_from_input_box, @search_by_author, @search_by_author_url, @search_by_location,
            @search_by_what_where_url, @default_logged_in_search = false

    @search_by_location = (params[:entry_location] ||  params[:default_location]) && (params[:blog_entry].nil?)
    @search_by_author = (params[:blog_entry] && params[:blog_entry][:author_id] != "")
    @search_by_author_url = (params[:author] && params[:blog_entry].nil? )
    @search_by_what_where_url = params[:category_list] && params[:entry_location] && (params[:blog_entry].nil?)
    @default_logged_in_search = @search_by_author_url && ( logged_in? && current_web_user.login == params[:author] )
    @search_from_input_box =  params[:blog_entry][:search] if params[:blog_entry] && params[:blog_entry][:search]
    @search_category_list = !@search_from_input_box && (params[:category_list] || ( params[:blog_entry] && params[:blog_entry][:category_list] != "" ))

    # Set default location
    @address = session[:geo_location].full_address if session[:geo_location]
    @address = User.default_location unless @address
    if params[:default_location] && params[:default_location] != "" || params[:entry_location]
      unless @address = params[:entry_location]
        @address = params[:default_location]
      end
    else
      @address = current_web_user.user.address if logged_in? && @default_logged_in_search
    end
    session[:geo_location] = BlogEntry.geocode(@address)


  end

  # Only search routine. All variations handled inside this app wide method.

  def get_results_by_what

    initialize_filter

    cond = String.new
    if (@search_category_list || @search_from_input_box || @search_by_what_where_url) &&
            !(@search_by_author || @search_by_author_url)

      #did one click a tag?
      if @search_category_list
        @filter[:category_list] = params[:blog_entry][:category_list] if params[:blog_entry]
        @filter[:searchterms] = @filter[:category_list] = params[:category_list] if params[:category_list] &&( params[:blog_entry].nil? ||params[:blog_entry][:category_list]=="")
      else
        #prepare search input, look at things tagged with search terms as well
        @filter[:category_list] =  params[:blog_entry][:search].split(',')
        @filter[:category_list].each{|item| item = item.strip} if @filter[:category_list].size  > 1
        @filter[:searchterms] = params[:blog_entry][:search].strip unless params[:blog_entry][:search].nil?
      end

      #the second one is for tagged by searching
      @messages, @messages2 = Array.new
      if @search_from_input_box
        cond = "1=1 "
      elsif @search_category_list
        cond = "1=1 "
      end

      #conditions for distance, no unmapped being supported here
      cond = cond + "AND (" + BlogEntry.distance_sql(session[:geo_location], :miles, :sphere) << "<= #{@filter[:radius]}" + ")"
      distcond = cond

      cond = cond + %Q{ AND lower(what) LIKE '%#{@filter[:searchterms].downcase.gsub(/[.,']/, '%')}%' }  if  @filter[:searchterms]

      @messages = BlogEntry.find :all, :conditions => cond, :order => 'blog_entries.created_at desc', :limit => @filter[:post_limit], :include =>[:user, :categories, :ratings]

      # but you also need to check tags because not only is the what a good candidate, the tags are there for search too
      @filter[:category_list] = params[:category_list] if params[:category_list]

      # wait input box overrides tag search
      @filter[:category_list] = params[:blog_entry][:search] if params[:blog_entry]&& params[:blog_entry][:search]!= ""

      @messages2 = BlogEntry.find_tagged_with @filter[:category_list], {:on=> :categories, :conditions=> distcond,  :order => 'blog_entries.created_at desc', :limit => @filter[:post_limit], :include =>[:user, :ratings] }

      @messages2 = @messages2.find_all{|m| m.distance_to(session[:geo_location]) <= @filter[:radius].to_f || ( @filter[:show_unmapped] && m.lat.nil?)}

      @filter[:searchterms]  = @filter[:category_list]
      @messages.concat(@messages2) if @messages2

      @messages = @messages.uniq
      #search by author (only possible through tag)
    elsif @search_by_author  || @search_by_author_url  && !@default_logged_in_search
      if params[:blog_entry].nil? && params[:author]
        params[:blog_entry]=Hash.new
        if author=  User.find_by_name(params[:author])
          params[:blog_entry][:author_id] = author.id
          @filter[:author_id] = author.id
        end
      end

      @filter[:post_limit] = 500 if logged_in?
      @messages =BlogEntry.find :all, :conditions => {:user_id => params[:blog_entry][:author_id]}, :order => 'blog_entries.created_at desc', :include =>[:user, :ratings], :limit => @filter[:post_limit]

    elsif @search_by_location || @default_logged_in_search
      get_initial_messages
    else
      #fallback
      get_initial_messages
    end

    if session[:sliders]==true
      @messages = @messages.find_all{|m| m.rating >=@filter[:rating_from].to_f && m.rating <= @filter[:rating_to].to_f }
      @messages = @messages.find_all{|m| m.price|| 0  >= @filter[:price_from].to_f && m.price||0 <= @filter[:price_to].to_f }
    end


    finish_search

  end

  def show_message
    initialize_filter
    @messages = [BlogEntry.find(params[:post_id]) ]
    finish_search
  end

  def get_results_by_where_who_or_id
    initialize_filter
    get_initial_messages
  end

  def get_initial_messages

    cond=BlogEntry.distance_sql(session[:geo_location], :miles, :sphere) << "<= #{@filter[:radius]}"
    #cond = cond + " OR blog_entries.lat is null " if @filter[:show_unmapped]
    @messages = BlogEntry.find :all,
                               :conditions => cond,
                               :limit=>@filter[:post_limit],
                               :order => 'blog_entries.created_at desc', :include =>[:user, :categories,  :ratings]

    radius_step=1
    while @messages.reject{|x| x.lat.nil?}.empty? || radius_step==5
      cond=BlogEntry.distance_sql(session[:geo_location], :miles, :sphere) << "<= #{@filter[:radius]+25*radius_step}"
      #cond = cond + " OR blog_entries.lat is null " if @filter[:show_unmapped]
      @messages = BlogEntry.find :all,
                                 :conditions => cond,
                                 :limit=>@filter[:post_limit],
                                 :order => 'blog_entries.created_at desc', :include =>[:user, :categories,  :ratings]
      radius_step=radius_step+5
    end
    finish_search
  end

  protected

  def finish_search

    if (logged_in? && @show_friends_only == true)
      @messages = @messages.find_all{ |m| @user.subscriptions.collect{|s|s.friend_id}.insert(0, @user.id).include?(m.user_id) }
    end

    @messages.compact
    @messages =  @messages.sort_by{|m| m.created_at}.reverse!
    @location = "#{session[:geo_location].lat},#{session[:geo_location].lng}" if session[:geo_location]&&session[:geo_location].lat
    @mapmessages = @messages.reject{|m| m.lat.nil? || m.price.nil?}
    @mapmessages = @mapmessages[0..99] if @mapmessages.size > 99


    if @mapmessages.empty?
      if @search_by_what_where_url then
        flash[:error] = " #{session[:geo_location].full_address } has no deals reported nearby yet. <br/>
                            You can get the ball rolling by spreading the word, post a deal! <br/> "
      end
      if @search_by_author || @search_by_author_url then
        flash[:error] = " this user doesnt have any posts mappable to this location  <br/> "
      end
      if @search_from_input_box  then
        flash[:error] = " I couldnt find anything with those search terms. Please try something else  <br/> "
      end
    end

    if @messages.empty?
      if session[:sliders]==true
        flash[:error]<< "<em>(your advanced filters may be too restrictive)</em><br/>"
      end
      if (logged_in? && @show_friends_only == true )
        flash[:error]<<"<em>( you may have to look outside of your favorite users )</em><br/>"
      end
      if (logged_in? && @filter[:show_unmapped]==false)
        flash[:error]<<"<em>( at least nothing within #{@filter[:radius]} miles of #{session[:geo_location].full_address })</em><br/>"
      end
    end

  end

  def update_current_user_ranking
    if logged_in?
      current_web_user.user.rated = User.rate(current_web_user.user);
      current_web_user.user.ranked = User.rank(current_web_user.user.rated);
      current_web_user.user.save(false)
    end
  end

  def update_active_user_ranking
    users = BlogEntry.find(:all, :select => 'DISTINCT user_id as id', :conditions =>['created_at > ?', Time.now - 60*60*24*180], :limit => 500)
    users.each{|ur| u= User.find(ur.id); u.rated = User.rate(u); u.ranked = User.rank(u.rated); u.save(false);}
  end

  def safe_get_tweets
    begin
      tweets = Twitter.get_tweets
      Twitter.create_blog_entries(tweets) if tweets
    rescue
      nil
    end

  end

  protected

  def prepare_tag_clouds
    @tag_counts = BlogEntry.category_counts(:limit => 48, :order => "count DESC, id DESC", :at_least => 18)
    #@tag_counts = @tag_counts.sort_by{|tag| tag.name.downcase }
    @active_users = User.find_active
  end



end