# frozen_string_literal: true

module DiscourseTranslator
  module TopicViewSerializerExtension
    def posts
      if SiteSetting.translator_enabled?
        object.instance_variable_set(:@posts, object.posts.includes(:content_locale))
      end
      super
    end
  end
end
