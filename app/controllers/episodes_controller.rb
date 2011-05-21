class EpisodesController < ApplicationController
  def index
    @page_title = "Ten Recent Episodes of Ruby and Rails Screencasts"
    @meta_description = "Ruby and Rails screencasts containing practical tips, tricks and tutorials for software developers."

    @episodes = Episode.all
  end

  def show
    @episode = Episode.find(params[:id])
    @page_title = "#{@episode.title}"
  end

  def destroy
    raise "You cannot destroy episodes"  
  end


  def download
    episode = Episode.find(params[:id])

    track_download(episode)                             
    redirect_to episode.download_link
  end

  def privacy
    render  :layout => false 
  end

  private

  def track_download(episode)
    episode.downloads.create(:episode_id => episode.id, :remote_ip => request.remote_ip)
  end
end
