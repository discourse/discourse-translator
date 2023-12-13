# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSerializer do
  let(:post) { Fabricate(:post) }

  before do
    SiteSetting.translator_enabled = true
    Jobs.run_later!
  end

  shared_examples "detected_lang_does_not_match_user_locale" do
    describe "when post detected lang does not match user's locale" do
      before do
        post_with_user.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "ja"
        post_with_user.save
      end

      it { expect(serializer.can_translate).to eq(true) }
    end
  end

  shared_examples "detected_lang_match_user_locale" do
    describe "when post detected lang matches user's locale" do
      before do
        post_with_user.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "en"
        post_with_user.save
      end

      it { expect(serializer.can_translate).to eq(false) }
    end
  end

  describe "#can_translate" do
    describe "logged in user" do
      let(:user) do
        user = Fabricate(:user, locale: "en")
        user.group_users << Fabricate(:group_user, user: user, group: Group[:trust_level_1])
        user
      end
      let(:serializer) { PostSerializer.new(post_with_user, scope: Guardian.new(user)) }
      let(:post_with_user) { Fabricate(:post, user: user) }

      describe "when poster is in a allowlisted group" do
        before do
          SiteSetting.restrict_translation_by_poster_group =
            "#{User.find(post_with_user.user_id).groups.first.id}"
        end

        include_examples "detected_lang_does_not_match_user_locale"
        include_examples "detected_lang_match_user_locale"
      end

      describe "when poster is not in a allowlisted group" do
        before do
          SiteSetting.restrict_translation_by_poster_group = "#{Group[:trust_level_4]}"
          post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "ja"
          post.save
        end

        it { expect(serializer.can_translate).to eq(false) }
      end

      describe "when user is in a allowlisted group" do
        before do
          SiteSetting.restrict_translation_by_group = "#{user.groups.first.id}|not_in_the_list"
        end
        include_examples "detected_lang_does_not_match_user_locale"
        include_examples "detected_lang_match_user_locale"
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

    describe "when user is not logged in" do
      let(:serializer) { PostSerializer.new(post, scope: Guardian.new) }
      before do
        post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "ja"
        post.save
        SiteSetting.restrict_translation_by_group = "11|not_in_the_list"
      end

      it "should not translate" do
        expect(serializer.can_translate).to eq(false)
      end
    end
  end
end
