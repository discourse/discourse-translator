# frozen_string_literal: true

module DiscourseTranslator
  module TopicViewSerializerExtension
    def posts
      if SiteSetting.translator_enabled?
        posts_query = object.posts.includes(:content_locale)
        # this is kind of a micro-optimization.
        # we do not want to eager load translations if the user is using the site's language.
        # we will only load them if the user is using a different language that is supported by the site.
        if SiteSetting.experimental_inline_translation && !LocaleMatcher.user_locale_is_default? &&
             LocaleMatcher.user_locale_in_target_languages?
          posts_query =
            posts_query.includes(:translations).where(
              translations: {
                locale: InlineTranslation.effective_locale.to_s.gsub("_", "-"),
              },
            )
        end
        object.instance_variable_set(:@posts, posts_query)
      end
      super
    end
  end
end
