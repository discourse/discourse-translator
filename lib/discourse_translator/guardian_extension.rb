# frozen_string_literal: true
module DiscourseTranslator::GuardianExtension
  def user_group_allowed?
    authorized_groups = SiteSetting.restrict_translation_by_group.split("|").map(&:to_i)

    user_groups = current_user.groups.pluck :id
    authorized = authorized_groups.intersection user_groups
    !authorized.empty?
  end
end
