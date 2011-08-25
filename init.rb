require 'acts_as_moderated'
ActiveRecord::Base.send(:include, Humansized::Acts::Moderated)

