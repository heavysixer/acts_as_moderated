$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../rspec/lib')

require 'rubygems'
require 'active_record'
gem 'sqlite3-ruby'

require File.dirname(__FILE__) + '/../init'
require 'spec'
  
ActiveRecord::Base.logger = Logger.new("#{RAILS_ROOT}/tmp/moderated.log")
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => "#{RAILS_ROOT}/tmp/moderated.sqlite")
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do

  create_table :moderation_records, :force => true do |t|
    t.integer :recordable_id
    t.string  :recordable_type
    t.integer :state_id, :default => 0, :allow_nil => false
    t.integer :decision_id, :default => 0, :allow_nil => false
    t.boolean :flagged, :default => false, :allow_nil => false
    t.integer :moderator_id
    t.string  :reason
    t.text    :inspected_attributes
    t.boolean :rejected, :default => false, :allow_nil => false

    t.timestamps
  end
  add_index :moderation_records, [:recordable_id, :recordable_type]
  add_index :moderation_records, :state_id
  add_index :moderation_records, :decision_id
  add_index :moderation_records, :moderator_id
  add_index :moderation_records, :flagged
  add_index :moderation_records, :rejected

  create_table :stories, :force => true do |table|
    table.string :body
    table.boolean :moderated, :default => false, :allow_nil => false
    table.boolean :rejected, :default => false, :allow_nil => false
    table.timestamps
  end

  create_table :reviews, :force => true do |table|
    table.string :body
    table.string :title
    table.boolean :moderated, :default => false, :allow_nil => false
    table.timestamps
  end

  create_table :reports, :force => true do |table|
    table.string :body
    table.string :title
    table.boolean :moderated, :default => false, :allow_nil => false
    table.timestamps
  end

  create_table :posts, :force => true do |table|
    table.string :title
    table.string :body
    table.boolean :moderated, :default => false, :allow_nil => false
    table.boolean :rejected, :default => false, :allow_nil => false
    table.string  :type
    table.timestamps
  end

  create_table :moderated_posts, :force => true do |table|
    table.string :title
    table.string :body
    table.boolean :moderated, :default => false, :allow_nil => false
    table.boolean :rejected, :default => false, :allow_nil => false
    table.string  :type
    table.timestamps
  end

  create_table :users, :force => true do |table|
    table.string :name
    table.timestamps
  end

end

class User < ActiveRecord::Base
  acts_as_moderator
end

class Report < ActiveRecord::Base
  acts_as_moderated
end

class Review < ActiveRecord::Base
  acts_as_moderated :body, :title
end

class Story < ActiveRecord::Base
  acts_as_moderated :body

  def after_moderated(moderation_record)
    update_attribute(:moderated, true)
  end

  def after_rejection(moderation_record)
    update_attribute(:rejected, true)
  end
end

class Post < ActiveRecord::Base
  acts_as_moderated 'body'
end

class ModeratedPost < ActiveRecord::Base
  acts_as_moderated 'body','title', { :always_moderate => true }
end