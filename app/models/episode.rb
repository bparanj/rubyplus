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

end
