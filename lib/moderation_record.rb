# == Schema Info
#
# Table name: moderation_records
#
#  id                   :integer(4)      not null, primary key
#  moderator_id         :integer(4)
#  recordable_id        :integer(4)
#  state_id             :integer(4)
#  decision_id          :integer(4)
#  reason               :string(255)
#  recordable_type      :string(255)
#  flagged              :boolean
#  inspected_attributes :text
#  created_at           :datetime
#  updated_at           :datetime

class ModerationRecord < ActiveRecord::Base

  # When acts_as_moderator is added to a user class then the belongs_to :moderator assocation is dynamically
  # added to this class at runtime.
  belongs_to :recordable, :polymorphic => true
  validates_presence_of :recordable_type
  validates_presence_of :recordable_id
  validates_presence_of :moderator_id, :unless => Proc.new { |attributes| attributes.state_id.zero? }

  @@states = ['New', 'Closed', 'Invalid']
  cattr_reader :states

  @@decisions = ['Spam', 'Scam', 'Inappropriate']
  cattr_reader :decisions

  named_scope :available, :conditions => { :state_id => 0, :rejected => false }
  named_scope :rejected, :conditions => { :rejected => true }
  named_scope :queue, :order => ['flagged DESC, updated_at ASC']

  after_create :callback_moderated
  after_save   :callback_moderated_decision
  serialize :inspected_attributes

  def callback_moderated
    if recordable.respond_to?(:after_moderated)
      recordable.send(:after_moderated, self)
    end
  end

  def callback_moderated_decision

    # Only make the callback for records that are initally rejected.
    if changes['rejected'] && changes['rejected'][0] == false && changes['rejected'][1] == true
      if recordable.respond_to?(:after_rejection)
        recordable.send(:after_rejection, self)
      end
    end
  end

  def state
    ModerationRecord.states[state_id] if state_id
  end

  def state=(c = nil)
    self.state_id = label_to_id(@@states, c)
  end

  def flag!
    self.update_attribute(:flagged, true)
  end

  def unflag!
    self.update_attribute(:flagged, false)
  end

  def decision
    ModerationRecord.decisions[decision_id] if decision_id
  end

  def decision=(c = nil)
    self.state = "Closed"
    self.rejected = true
    self.decision_id = label_to_id(@@decisions, c)
  end

  class << self
    def create_for(record, opts = {})
      @r = nil
      options = { :state => 0 }.merge(opts)

      if (!record.moderated_attribute_changes.nil? && !record.moderated_attribute_changes.empty?) || record.class.moderated_options[:always_moderate] == true
        @r = begin
          r = available.find(:first, :conditions => { :recordable_id => record.id, :recordable_type => record.class.to_s })

          # We want to create a new moderation record if there is no previous record
          raise ActiveRecord::RecordNotFound unless r
          r
        rescue ActiveRecord::RecordNotFound
          new(:recordable_type => record.class.to_s, :recordable_id => record.id)
        end

        unless record.moderated_attribute_changes.nil? || record.moderated_attribute_changes.empty?
          [:reason, :rejected, :moderator_id, :decision].each do |k|
            @r.send("#{k.to_s}=", options[k]) if options[k]
          end
          @r.state = options[:state]
          @r.inspected_attributes = record.moderated_attribute_changes
        end

        # Force this because there may be no changes made to the record
        @r.updated_at = Time.now unless @r.new_record?
        @r.save!
      end
      @r
    end

  end

  private
  def label_to_id(arr, num = nil)
    result = nil
    if num.class == String && arr.include?(num.titleize)
      result = arr.rindex(num.titleize)
    end

    if num.class == Fixnum && arr.size > num && num > -1
      result = num
    end
    result
  end
end
