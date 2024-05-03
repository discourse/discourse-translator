# frozen_string_literal: true
module DiscourseTranslator::GuardianExtension
  def user_group_allow_translate?
    !!current_user&.in_any_groups?(SiteSetting.restrict_translation_by_group_map)
  end

  def poster_group_allow_translate?(post)
    return false if !current_user
    return true if SiteSetting.restrict_translation_by_poster_group_map.empty?
    !!post.user.in_any_groups?(SiteSetting.restrict_translation_by_poster_group_map)
  end
end
