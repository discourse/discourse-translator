# frozen_string_literal: true
module DiscourseTranslator::GuardianExtension
  def user_group_allow_translate?
    return false if !current_user
    current_user.in_any_groups?(SiteSetting.restrict_translation_by_group_map)
  end

  def poster_group_allow_translate?(post)
    return false if !current_user
    return true if SiteSetting.restrict_translation_by_poster_group_map.empty?
    return false if post.user.nil?
    post.user.in_any_groups?(SiteSetting.restrict_translation_by_poster_group_map)
  end

  def can_detect_language?(post)
    (
      SiteSetting.restrict_translation_by_poster_group_map.empty? ||
        post&.user&.in_any_groups?(SiteSetting.restrict_translation_by_poster_group_map)
    ) && post.raw.present? && post.post_type != Post.types[:small_action]
  end

  def can_translate?(post)
    return false if post.user.bot?
    return false if !user_group_allow_translate?
    return false if post.locale_matches?(I18n.locale)

    if SiteSetting.experimental_topic_translation
      post.translation_for(I18n.locale).nil?
    else
      poster_group_allow_translate?(post)
    end
  end
end
