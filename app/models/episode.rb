class Episode < ActiveRecord::Base
  has_many :downloads
  
  acts_as_taggable_on :tags
  
  def self.recent(number)
    find(:all, :conditions => ['published_at <= ?', Time.now], :order => "sequence DESC", :limit => number)
  end
  
  def self.latest
    find(:all, :order => "sequence DESC", :limit => 5)
  end
  
  def self.get_all
    find(:all, :order => "sequence DESC" )
  end

  def to_param
    "#{id}-#{title.gsub(/[^a-z1-9]+/i, '-')}.html"
  end
end
