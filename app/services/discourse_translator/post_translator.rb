# frozen_string_literal: true

module DiscourseTranslator
  class PostTranslator
    def self.translate(post, target_locale = I18n.locale)
      return if post.blank? || target_locale.blank?

      target_locale_sym = target_locale.to_s.sub("-", "_").to_sym

      translator = DiscourseTranslator::Provider::TranslatorProvider.get
      translated_raw = translator.translate_post!(post, target_locale_sym)

      localization =
        PostLocalization.find_or_initialize_by(post_id: post.id, locale: target_locale_sym.to_s)

      localization.raw = translated_raw
      localization.cooked = PrettyText.cook(translated_raw)
      localization.post_version = post.version
      localization.localizer_user_id = Discourse.system_user.id
      localization.save!
      localization
    end
  end
end
