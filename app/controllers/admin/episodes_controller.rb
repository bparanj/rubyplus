class Admin::EpisodesController < AdminController
  before_filter :authenticate
  
  def index
    @episodes = Episode.latest
  end

  def show
    @episode = Episode.find(params[:id])
  end

  def new
    @episode = Episode.new
  end

  def edit
    @episode = Episode.find(params[:id])
    @tags = @episode.tag_list
  end

  def create
    @episode = Episode.new(params[:episode])
    tag(params[:tags])

    if @episode.save
      flash[:notice] = 'Episode was successfully created.'
      redirect_to admin_episodes_url
    else
      render :action => "new" 
    end
  end

  def update
    @episode = Episode.find(params[:id])
    tag(params[:tags])

    if @episode.update_attributes(params[:episode])
      flash[:notice] = 'Episode was successfully updated.'
      redirect_to admin_episodes_url
    else
      render :action => "edit" 
    end
  end

  def destroy
    @episode = Episode.find(params[:id])
    @episode.destroy

    redirect_to admin_episodes_url
  end

  private

  def tag(key_words)
    @episode.tag_list = key_words
  end
end
