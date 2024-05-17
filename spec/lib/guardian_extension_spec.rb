# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::GuardianExtension do
  describe "anon user" do
    let!(:guardian) { Guardian.new }
    fab!(:post)

    before do
      SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:everyone]}"
      SiteSetting.restrict_translation_by_poster_group = "#{Group::AUTO_GROUPS[:everyone]}"
    end

    describe "#user_group_allow_translate?" do
      it "returns false" do
        expect(guardian.user_group_allow_translate?).to eq(false)
      end
    end

    describe "#poster_group_allow_translate?" do
      it "returns false" do
        expect(guardian.poster_group_allow_translate?(post)).to eq(false)
      end
    end
  end

  describe "logged in user" do
    fab!(:group)
    fab!(:user) { Fabricate(:user, groups: [group]) }
    fab!(:post) { Fabricate(:post, user: user) }
    let(:guardian) { Guardian.new(user) }

    describe "#user_group_allow_translate?" do
      it "returns true when the user is in restrict_translation_by_group" do
        SiteSetting.restrict_translation_by_group = "#{group.id}"

        expect(guardian.user_group_allow_translate?).to eq(true)
      end

      it "returns false when the user is not in restrict_translation_by_group" do
        SiteSetting.restrict_translation_by_group = "#{Group::AUTO_GROUPS[:moderators]}"

        expect(guardian.user_group_allow_translate?).to eq(false)
      end
    end

    describe "#poster_group_allow_translate??" do
      it "returns true when the post user is in restrict_translation_by_poster_group" do
        SiteSetting.restrict_translation_by_poster_group = "#{group.id}"

        expect(guardian.poster_group_allow_translate?(post)).to eq(true)
      end

      it "returns false when the post user is not in restrict_translation_by_poster_group" do
        SiteSetting.restrict_translation_by_poster_group = "#{Group::AUTO_GROUPS[:moderators]}"

        expect(guardian.poster_group_allow_translate?(post)).to eq(false)
      end
    end
  end
end
