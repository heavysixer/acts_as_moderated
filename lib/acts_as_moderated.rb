module Humansized
  module Acts #:nodoc: all
    module Moderated
      def self.included(klass)
        klass.module_eval do
          attr_accessor :skip_moderation
          attr_accessor :moderated_attribute_changes
        end
        klass.extend ClassMethods
      end

      module ClassMethods
        def acts_as_moderated(*attributes)
          has_many :moderation_records, :as => :recordable, :dependent => :destroy

          @moderated_attributes = []
          @moderated_options = { :always_moderate => false }
          @moderated_options.merge!(attributes.last.is_a?(Hash) ? attributes.pop : {})
          attributes

          attributes.each { |attribute| @moderated_attributes << attribute.to_sym }

          ModerationRecord.decisions.each do |kind|
            define_method("marked_#{kind.downcase.underscore}_by_moderator".to_sym, proc { |*args| marked_by_moderator(kind, *args) })
          end

          named_scope :failed_moderation,  lambda { |a| moderation_query(a, true) }
          named_scope :passed_moderation,  lambda { |a| moderation_query(a, false) }

          include Humansized::Acts::Moderated::InstanceMethods
          alias_method_chain :after_save, :content_moderation
        end

        # Associate the created moderation ticket with an account to manage it.
        def acts_as_moderator
          has_many :moderation_records, :foreign_key => :moderator_id

          ::ModerationRecord.class_eval "belongs_to :moderator, :class_name => '#{name}'"
        end

        def moderated_attributes
          if self.base_class == self
            Array(@moderated_attributes)
          else
            self.base_class.moderated_attributes if @moderated_attributes.nil?
          end
        end

        def moderated_options
          if self.base_class == self
            @moderated_options
          else
            self.base_class.moderated_options if @moderated_options.nil?
          end
        end

        # This method creates a nested scope that returns all unmoderated records and records that either passed
        # or failed moderation based on the params.

        # FIXME: I would like to do this in a single query using sub-queries with MySQL but it appears MySQL won't support
        # a LIMIT option inside a subquery if the main query uses IN()
        def moderation_query(a, bool)
          records = [a].flatten
          return {} if records.empty?
          conditions = ['']
          moderated_record_ids = []
          unmoderated_records = []
          records.each do |n|
            nid = ModerationRecord.first(:select => 'id', :conditions => { :recordable_id => n.id, :recordable_type => n.class.to_s }, :order => 'created_at DESC')
            if nid
              moderated_record_ids << ModerationRecord.first(:select => 'id', :conditions => { :recordable_id => n.id, :recordable_type => n.class.to_s }, :order => 'created_at DESC')
            else
              unmoderated_records << n
            end
          end

          unless unmoderated_records.empty?
            conditions[0] += "#{unmoderated_records.first.class.to_s.tableize}.id IN (?)"
            conditions += [unmoderated_records.map{ |x| x.id }]
          end

          unless moderated_record_ids.empty?
            moderated_record_ids = moderated_record_ids.compact.map{ |x| x.id }
            conditions[0] += " OR "  unless conditions[0].blank?
            conditions[0] += "(moderation_records.rejected = ? AND moderation_records.id in (?))"
            conditions += [bool, moderated_record_ids]
          end

          { :conditions => conditions, :include => [:moderation_records] }
        end
      end

      module InstanceMethods

        def failed_moderation
          rejected = false
          unless new_record? || self.moderation_records(true).empty?
            rejected = self.moderation_records.last.rejected?
          end
          rejected
        end

        def marked_by_moderator(kind, *opts)
          moderator = opts[0]
          opts = opts[1] || {}
          opts.merge!({ :decision => kind, :rejected => true, :moderator_id => moderator.id })
          ModerationRecord.create_for(self, opts)
        end

        def after_save_with_content_moderation(*args)
          self.moderated_attribute_changes = changes.dup

          # Delete keys we don't want to moderate anyway.
          self.moderated_attribute_changes.delete_if{ |k,v| [:id, :updated_at, :created_at].include?(k.to_sym) }

          # Delete changes that were nil but are now blank.
          # This is useful for when optional fields of new records are saved wtih no content.
          self.moderated_attribute_changes.delete_if{ |k,v| v == [nil,'']}

          # If no attributes are supplied then the entire record is moderated otherwise moderate only the supplied columns.
          unless self.class.base_class.moderated_attributes.empty?
            self.moderated_attribute_changes.delete_if{ |k,v| !self.class.base_class.moderated_attributes.include?(k.to_sym) }
          end
          ModerationRecord.create_for(self) unless skip_moderation
          after_save_without_content_moderation(*args)
        end
      end
    end
  end
end
