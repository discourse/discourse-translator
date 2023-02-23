# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSerializer do
  let(:post) { Fabricate(:post) }
  let!(:user) do
    user = Fabricate(:user, locale: "en")
    user.group_users << Fabricate(:group_user, user: user, group: Group[:trust_level_1])
    user
  end
  let(:serializer) { PostSerializer.new(post, scope: Guardian.new(user)) }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.queue_jobs = true
  end

  describe "#can_translate" do
    describe "when user is in a allowlisted group"
    before do
      SiteSetting.restrict_translation_by_group =
        "#{Group.find_by(name: user.groups.first.name).id}|not_in_the_list"
    end
    describe "when post detected lang does not match user's locale" do
      before do
        post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "ja"
        post.save
      end

      it { expect(serializer.can_translate).to eq(true) }
    end

    describe "when post detected lang matches user's locale" do
      before do
        post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "en"
        post.save
      end
      it { expect(serializer.can_translate).to eq(false) }
    end
  end

  describe "when user is not in a allowlisted group" do
    before do
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "ja"
      post.save
      SiteSetting.restrict_translation_by_group = "not_in_the_list"
    end

    it "should not translate even if the post detected lang does not match the user's locale" do
      expect(serializer.can_translate).to eq(false)
    end
  end
end
