class KnowledgebaseController < ApplicationController
  unloadable

  #Authorize against global permissions defined in init.rb
  before_filter :authorize_global, :except => [:index, :show]
  before_filter :authorize_global, :only   => [:index, :show], :unless => :allow_anonymous_access?

  rescue_from ActionView::MissingTemplate, :with => :force_404
  rescue_from ActiveRecord::RecordNotFound, :with => :force_404

  def index
    begin
      summary_limit = Setting['plugin_redmine_knowledgebase']['knowledgebase_summary_limit'].to_i
    rescue
      summary_limit = 5
    end

    @categories = KbCategory.find(:all)
    @articles_newest   = KbArticle.find(:all, :limit => summary_limit, :order => 'created_at DESC')
    @articles_updated  = KbArticle.find(:all, :limit => summary_limit, :conditions => ['created_at <> updated_at'], :order => 'updated_at DESC')

    #FIXME the following method still requires ALL records to be loaded before being filtered.

    @articles_popular = KbArticle.find_by_sql("select * from kb_articles inner join (select viewed_id,count(viewer_id) from viewings group by viewed_id order by count desc) as viewings on (viewings.viewed_id = kb_articles.id) limit #{summary_limit}")
    @articles_toprated = KbArticle.find_by_sql("select * from kb_articles inner join (select rated_id,rating from ratings order by rating desc)as ratings on (ratings.rated_id = kb_articles.id) limit #{summary_limit}")


    @tags = KbArticle.tag_counts

    #For default search
    project = Project.first(:order => 'id')
    kbarticle = KbArticle.first(:order => 'project_id')
    if (project ? project.id : 0) != (kbarticle ? kbarticle.project_id : 0)
      KbArticle.update_all :project_id => Project.first(:order => 'id').id
    end
  end

  def search
    @categories = []
    @articles = []
    @search_word = URI.decode(params[:q].to_s)
    search_word = "%" + URI.decode(params[:q].to_s) + "%"
    if @search_word.present?
      @categories = KbCategory.where(["title like ? or description like ?", search_word, search_word])
      @articles = KbArticle.where(["title like ? or summary like ? or content like ?", search_word, search_word, search_word])
    end
  end

#########
protected
#########

  def is_user_logged_in
    if !User.current.logged?
      render_403
    end
  end

  def allow_anonymous_access?
    Setting['plugin_redmine_knowledgebase']['knowledgebase_anonymous_access'].to_i == 1
  end

#######
private
#######

  def force_404
    render_404
  end

end

