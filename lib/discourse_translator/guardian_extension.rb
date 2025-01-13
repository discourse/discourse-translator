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

    # we will deal with strings (not syms) when comparing locales below
    detected_lang =
      post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD].to_s.sub("-", "_")
    return false if detected_lang.blank?

    locale_without_region = I18n.locale.to_s.split("_").first
    site_locale =
      (
        if SiteSetting.normalize_language_variants_map.include?(locale_without_region)
          locale_without_region
        else
          I18n.locale.to_s
        end
      )
    detected_lang != site_locale &&
      "DiscourseTranslator::#{SiteSetting.translator}".constantize.language_supported?(
        detected_lang,
        site_locale,
      )
  end
end
