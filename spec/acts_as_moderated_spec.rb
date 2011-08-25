require File.dirname(__FILE__) + '/spec_helper'

describe ModerationRecord do
   before(:each) do
     @moderator = User.create
   end

   it "should create an association for the moderator" do
     User.new.moderation_records.should be_empty
   end

   it "should allow the user to specify a number of fields of a model to observe" do
     Story.moderated_attributes.should == [:body]
     Review.moderated_attributes.should == [:body, :title]
   end

   it "should moderate the entire record if a collection of fields are not supplied" do
     @report = Report.new(:title => 'bar', :body => 'foo')
     lambda do
       @report.save!
     end.should change(ModerationRecord, :count).by(1)
   end

   it "should not save a moderation record for records that had nil columns but are now blank" do
     @report = Report.new(:title => '', :body => '')
       lambda do
         @report.save!
       end.should_not change(ModerationRecord, :count)
   end

   it "should determine if a record has been rejected by a moderator" do
     @report = Report.new(:title => 'bar', :body => 'foo')
       lambda do
         @report.save!
       end.should change(ModerationRecord, :count).by(1)
       @report.failed_moderation.should be_false
       @report.marked_spam_by_moderator(@moderator, { :reason => "this content is spam" })
       @report.failed_moderation.should be_true

       # Sleep here so we ensure we get different time stamps
       sleep 1

       # Saving new changes will remove the rejected state
       @report.update_attributes(:body =>'fooo bar baz')
       @report.failed_moderation.should be_false
   end

   it "should keep a serialized hash of changes made to the record" do
     @report = Report.new(:title => 'bar', :body => 'foo')
      lambda do
        @report.save!
      end.should change(ModerationRecord, :count).by(1)
      @report.moderation_records.first.inspected_attributes.should == { "body" => [nil, "foo"], "title" => [nil, "bar"] }
      @report.update_attribute(:body, 'bar')
      @report.moderation_records(true).first.inspected_attributes.should == { "body" => ["foo", "bar"] }

      # updating it to the same attribute should not change the inspected attributes
      @report.update_attribute(:body, 'bar')
      @report.moderation_records(true).first.inspected_attributes.should == { "body" => ["foo", "bar"] }
   end

   it "should only create a moderation record if there are changes" do
     @report = Report.new(:title => 'bar', :body => 'foo')
     lambda do
       @report.save!
     end.should change(ModerationRecord, :count).by(1)
     @m = @report.moderation_records.first
     @m.update_attribute(:decision, 'Spam')

     lambda do
       @report.save!
     end.should_not change(ModerationRecord, :count).by(1)

     @post = Post.new(:body => 'foo')
     lambda do
       @post.save!
     end.should change(ModerationRecord, :count).by(1)
     @m = @post.moderation_records.first
     @m.update_attribute(:decision, 'Spam')
     lambda do
       @post.save!
     end.should_not change(ModerationRecord, :count).by(1)
   end

   it "should create or update a moderation record even if there are no changes when the :always_moderate option is set to true" do
     ModeratedPost.moderated_options.should  == { :always_moderate => true }
     @post = ModeratedPost.new(:title => 'bar', :body => 'foo')
     lambda do
       @post.save!
     end.should change(ModerationRecord, :count).by(1)
     @m = @post.moderation_records.first
     @m.update_attribute(:decision, 'Spam')
     lambda do
       @post.save!
     end.should change(ModerationRecord, :count).by(1)
   end

   it "should only create a moderation record if fields being moderated change" do
     @post = Post.new(:body => 'foo')
     lambda do
       @post.save!
     end.should change(ModerationRecord, :count).by(1)
     @m = @post.moderation_records.first
     @m.update_attribute(:decision, 'Spam')

     # Normally editing an approved record would create a new ModerationRecord, but in this case
     # it won't because we are editing a column not being moderated
     lambda do
       @post.update_attribute(:title, 'foo')
     end.should_not change(ModerationRecord, :count).by(1)

     @post2 = Post.new(:title => 'foo')
     lambda do
       @post2.save!
     end.should_not change(ModerationRecord, :count).by(1)
   end

   ModerationRecord.states.each_with_index do |l, i|
     it "should allow a record to be set to '#{l}'" do
       @m = ModerationRecord.new
       @m.state = l
       @m.state.should == l
       @m.state = i
       assert_equal l, @m.state
     end
   end

   it "should create a new moderation record for records that are saved but were previously approved" do
     @story = Story.new(:body => 'foo')
     @story.moderated.should be_false
     lambda do
       @story.save!
     end.should change(ModerationRecord, :count).by(1)
     @story.reload.moderated.should be_true
     @m = @story.moderation_records.first
     @m.update_attribute(:decision, 'Spam')
   end

  context "when being moderated" do
    it "should not generate a new record when a moderator saves a change" do
      @story = Story.create!(:body => 'foo')
      @m = @story.moderation_records.first
      @m.update_attribute(:decision, 'Spam')

      @story.skip_moderation = true
      @story.body = "bar"
      lambda do
        @story.save!
      end.should_not change(ModerationRecord, :count).by(1)
    end

    it "should allow the moderated record to specify an optional 'after_moderated' callback" do
      @story = Story.new(:body => 'foo')
      @story.moderated.should be_false
      lambda do
        @story.save!
      end.should change(ModerationRecord, :count).by(1)
      @story.reload.moderated.should be_true

      # Posts doesn't have an after_moderated callback
      @post = Post.new(:body => 'bar')
      @post.moderated.should be_false
      lambda do
        @post.save!
      end.should change(ModerationRecord, :count).by(1)
      @post.reload.moderated.should be_false
    end

    it "should allow the moderated record to specify an optional 'after_rejection' callback" do
      @story = Story.new(:body => 'foo')
      lambda do
        @story.save!
      end.should change(ModerationRecord, :count).by(1)
      @story.reload.rejected.should be_false

      @story.marked_spam_by_moderator(@moderator)
      @story.reload.rejected.should be_true

      # Posts doesn't have an after_moderated callback
      @post = Post.new(:body => 'bar')
      @post.moderated.should be_false
      lambda do
        @post.save!
      end.should change(ModerationRecord, :count).by(1)
      @post.marked_spam_by_moderator(@moderator)
      @post.reload.rejected.should be_false
    end

    it "should move new record to the bottom of the stack" do
      @story = Story.create(:body => 'foo')
      sleep 1
      @story2 = Story.create(:body => 'bar')
      ModerationRecord.queue.all.should == @story.moderation_records + @story2.moderation_records
    end

    it "should should move opened records to the bottom of the stack if they are modified" do
      @story = Story.create(:body => 'foo')
      sleep 1
      @story2 = Story.create(:body => 'bar')
      ModerationRecord.queue.all.should == @story.moderation_records + @story2.moderation_records
      sleep 1
      @story.body = "baz"
      @story.save!
      ModerationRecord.queue.all.should == @story2.moderation_records(true) + @story.moderation_records(true)

      @story.moderation_records.first.flag!

      # This should send @story to the stack but since it's flagged it will remain at the top of the queue.
      @story.update_attribute(:body, 'baz')
      ModerationRecord.queue.all.should == @story.moderation_records(true) + @story2.moderation_records(true)

      # Now that both records are flagged the ordering defaults back to updated_at
      @story2.moderation_records.first.flag!
      sleep 1
      @story.update_attribute(:body, 'bar')
      ModerationRecord.queue.all.should == @story2.moderation_records(true) + @story.moderation_records(true)
    end

    # Test the dynamically created moderator methods: 
    # "marked_approved_by_moderator", "marked_spam_by_moderator", "marked_scam_by_moderator", "marked_inappropriate_by_moderator"
    ModerationRecord.decisions.each do |l|
      it "should allow a moderator to decide a record is '#{l}'" do
        @p = Post.create!(:body => 'foo')
        @p2 = Post.create!(:body => 'foo')
        @p3 = Post.create!(:body => 'foo')
        lambda do
          @p.send("marked_#{l.downcase.underscore}_by_moderator", @moderator)
          @p2.send("marked_#{l.downcase.underscore}_by_moderator", @moderator, { :reason => "this content is #{l}" })
          @p3.send("marked_#{l.downcase.underscore}_by_moderator", @moderator, { :reason => "this should not have been flagged", :state => 'Invalid' })
        end.should_not change(ModerationRecord, :count).by(2)
        @p.moderation_records.first.decision.should == l
        @p2.moderation_records.first.decision.should == l
        @p2.moderation_records.first.reason.should == "this content is #{l}"
        @p3.moderation_records.first.state.should == "Invalid"
      end
    end
  end
end
