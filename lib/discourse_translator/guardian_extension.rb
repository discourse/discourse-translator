# frozen_string_literal: true
module DiscourseTranslator::GuardianExtension
  def user_group_allowed?
    authorized_groups = SiteSetting.restrict_translation_by_group.split("|").map(&:to_i)

    authorized? current_user, authorized_groups
  end

  def post_group_allowed?(post)
    authorized_poster_groups =
      SiteSetting.restrict_translation_by_poster_group.split("|").map(&:to_i)
    return true if authorized_poster_groups.empty?

    poster = User.find post.user_id
    authorized? poster, authorized_poster_groups
  end

  def authorized?(user, authorized_groups)
    return false if !user

    user_groups = user.groups.pluck :id
    authorized = authorized_groups.intersection user_groups
    !authorized.empty?
  end
end
