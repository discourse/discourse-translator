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
    return false if !user_group_allow_translate?

    locale = post.detected_locale
    return false if locale.nil?

    # I18n.locale is a symbol e.g. :en_GB
    detected_lang = locale.to_s.sub("-", "_")
    detected_lang != I18n.locale.to_s &&
      "DiscourseTranslator::#{SiteSetting.translator}".constantize.language_supported?(
        detected_lang,
      )
  end
end
