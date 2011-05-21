class InitialSchema < ActiveRecord::Migration
  def self.up
    create_table "downloads", :force => true do |t|
      t.integer  "episode_id"
      t.string   "remote_ip"
      t.datetime "created_at"
      t.datetime "updated_at"
    end

    create_table "episodes", :force => true do |t|
      t.string   "title"
      t.string   "download_link"
      t.string   "discuss_link"
      t.string   "duration"
      t.text     "description"
      t.integer  "sequence"
      t.integer  "size"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.datetime "published_at"
    end

    create_table "testimonials", :force => true do |t|
      t.string   "title"
      t.text     "body"
      t.datetime "created_at"
      t.datetime "updated_at"
    end
  end

  def self.down
  end
end
