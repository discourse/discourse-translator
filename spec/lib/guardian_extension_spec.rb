# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::GuardianExtension do
  shared_examples "post_group_allowed" do
    it "returns true when the post was made by an user in a allowlisted group" do
      SiteSetting.restrict_translation_by_poster_group = "#{Group[:trust_level_1].id}"

      expect(guardian.post_group_allowed?(post)).to eq(true)
    end

    it "returns true when no group has selected in settings" do
      SiteSetting.restrict_translation_by_poster_group = ""

      expect(guardian.post_group_allowed?(post)).to eq(true)
    end
  end

  shared_examples "post_group_not_allowed" do
    it "returns true when the post was made by an user not in a allowlisted group" do
      SiteSetting.restrict_translation_by_poster_group = "#{Group[:trust_level_4].id}"

      expect(guardian.post_group_allowed?(post)).to eq(false)
    end
  end

  describe "anon user" do
    let!(:guardian) { Guardian.new }
    let(:post) { Fabricate(:post) }
    describe "#user_group_allowed?" do
      it "returns false when the user is not logged in" do
        SiteSetting.restrict_translation_by_group = "not_in_the_list"

        expect(guardian.user_group_allowed?).to eq(false)
      end
    end

    describe "#post_group_allowed?" do
      include_examples "post_group_not_allowed"
    end

    describe "#authorized?" do
      it "returns false with authorized groups" do
        expect(guardian.authorized?(nil, ["authorized_group"])).to eq(false)
      end
    end
  end

  describe "logged in user" do
    let(:user) do
      user = Fabricate(:user)
      user.group_users << Fabricate(:group_user, user: user, group: Group[:trust_level_1])
      user
    end
    let(:guardian) { Guardian.new(user) }
    let(:post) { Fabricate(:post, user: user) }

    describe "#user_group_allowed?" do
      it "returns true when the user is in a allowlisted group" do
        SiteSetting.restrict_translation_by_group =
          "#{Group.find_by(name: user.groups.first.name).id}|not_in_the_list"

        expect(guardian.user_group_allowed?).to eq(true)
      end

      it "returns false when the user is not in a allowlisted group" do
        SiteSetting.restrict_translation_by_group = "not_in_the_list"

        expect(guardian.user_group_allowed?).to eq(false)
      end
    end

    describe "#post_group_allowed?" do
      include_examples "post_group_allowed"
      include_examples "post_group_not_allowed"
    end

    describe "#authorized?" do
      it "returns true with user in autorized groups" do
        expect(guardian.authorized? user, [Group[:trust_level_1].id]).to eq(true)
      end

      it "returns false with user not in autoried groups" do
        expect(guardian.authorized? user, ["not_in_the_list"]).to eq(false)
      end
    end
  end
end
