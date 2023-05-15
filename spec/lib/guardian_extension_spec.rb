# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::GuardianExtension do
  describe "#user_group_allowed?" do
    let!(:user) do
      user = Fabricate(:user)
      user.group_users << Fabricate(:group_user, user: user, group: Group[:trust_level_1])
      user
    end
    let!(:guardian) { Guardian.new(user) }

    it "returns true when the user is in a allowlisted group" do
      SiteSetting.restrict_translation_by_group =
        "#{Group.find_by(name: user.groups.first.name).id}|not_in_the_list"

      expect(guardian.user_group_allowed?).to eq(true)
    end

    it "returns false when the user is not in a allowlisted group" do
      SiteSetting.restrict_translation_by_group = "not_in_the_list"

      expect(guardian.user_group_allowed?).to eq(false)
    end

    it "returns false when the user is not logged in" do
      SiteSetting.restrict_translation_by_group = "not_in_the_list"
      non_logged_guardian = Guardian.new
      expect(non_logged_guardian.user_group_allowed?).to eq(false)
    end
  end
end
