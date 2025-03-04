# frozen_string_literal: true

module DiscourseTranslator
  module TopicViewSerializerExtension
    def posts
      if SiteSetting.translator_enabled?
        posts_query = object.posts.includes(:content_locale)
        posts_query =
          posts_query.includes(:translations) if SiteSetting.experimental_inline_translation
        object.instance_variable_set(:@posts, posts_query)
      end
      super
    end
  end
end
