module ApplicationHelper
  def display_published_at(episode)
    episode.published_at.strftime("%b %d, %Y")
  end
end
